package TableEdit::Config;

use Dancer ':syntax';

use Dancer::Plugin::DBIC qw(schema resultset rset);
use DBI;
use DBIx::Class::Schema::Loader qw/ make_schema_at /;
use FindBin;
use Cwd qw/realpath/;
use File::Spec;
use DateTime;
use TableEdit::ConfigSchema;
use TableEdit::DriverInfo;
use Class::Load qw/load_class/;

use Exporter 'import';
our @EXPORT_OK = qw(
  appdir column_types load_settings
);

my $appdir = config->{'appdir'};
my $SQLite = _bootstrap_config_schema();
my @column_types;
set views => "$appdir/public/views";

# Load TE settings
my $settings_file = config->{'settings_file'} || 'lib/config.yml';

load_settings($settings_file) if (-f $settings_file);

# Returns root directory for TableEditor application
sub appdir {
    return $appdir;
}

hook 'before' => sub {
	# Set schema settings
	unless (config->{plugins}->{DBIC}->{default}){
		my $db_settings = $SQLite->resultset('Db')->find('default');
		set_db({
			dbname => $db_settings->dbname,
			driver => $db_settings->driver,
			dsn_suffix => $db_settings->dsn_suffix,
			user => $db_settings->user,
			pass => $db_settings->pass,
			schema_class => $db_settings->schema_class,
		}) if $db_settings;
	}
};

prefix '/api';
any '**' => sub {
	content_type 'application/json';
	pass;
};


get '/ping' => sub {
	header('Access-Control-Allow-Origin' => '*');
	return to_json {status => 'running'};	
};


get '/create_schema' => sub {
	my $db = config->{plugins}->{DBIC}->{default};
	return to_json {make_schema_error => make_schema($db)};	
};

get '/schema' => sub {
	my $schema_info = {return => 1};
	
	# Check if DB configuration exists
	my $db = config->{plugins}->{DBIC}->{default};
	if($db){
		my $db_settings = $SQLite->resultset('Db')->find('default');

        if ($db_settings) {
            $schema_info->{db_info} = {$db_settings->get_columns};
        }
        else {
            $schema_info->{db_info} = parse_dbic_settings($db);
        }
	}
	
	# Check for DB connection
	my $db_test = eval{schema->storage->dbh};
	$schema_info->{db_connection_error} = "$@";
	
	# Check if DBIx class schema exists
	unless($schema_info->{db_connection_error}){
		if (eval{schema}){
			if(%{schema->{class_mappings}}){
				$schema_info->{schema} = scalar keys %{schema->{class_mappings}};		
			}
			# Schema doesn't exits. Try to generate it
			else {
				$schema_info->{make_schema} = 1;
				return to_json $schema_info;
				$schema_info->{schema_error} = make_schema($db);
				$schema_info->{schema_created} = $schema_info->{schema_error} ? 1 : 0;
			}
		}
		else{
			$schema_info->{make_schema} = 1;
			return to_json $schema_info;
			$schema_info->{schema_error} = make_schema($db);	
		}
	}
	else {
		$schema_info->{db_drivers} = TableEdit::DriverInfo->new->available;
	}
		
	$schema_info->{db_info}->{pass} = '******' if $schema_info->{db_info} and $schema_info->{db_info}->{pass};
	
	return to_json $schema_info;
};

post '/db-config' => sub {
	my $post = from_json request->body;
	set_db( $post->{config} );
	
	my $db_test = eval{schema->storage->dbh};
	my $error = $@;
	
	if ( $error ) {
		set plugins => {DBIC => {'default' => undef }};
		return undef if $error;
	}
	
	# Default schema
	$post->{config}->{schema_class} ||= 'TableEdit::Schema';
	
	# Save to db
	my $db = $SQLite->resultset('Db')->create({name => 'default', %{$post->{config}} });
	
	
	return to_json {db => 'configured'};
};

get '/schema/deploy' => sub {
	return to_json {deploy_errors => schema->deploy};
};

if (config->{TableEditor}->{menu_settings}->{update}) {
    load_class 'Git';

    get '/update' => sub {
        my $repo = Git->repository (Directory => $appdir);
        my @result = $repo->command('pull', '--all');
        return to_json {result => join ' ', @result};
    };

    get '/last_update' => sub {
        my $repo = Git->repository (Directory => $appdir);
        my ($commit, $author, $date, undef, @comment) = $repo->command('show', '-s', 'HEAD~0');
        #my ($commit, $author, $date, undef, @comment) = `cd $appdir; git show -s HEAD~0`;
        $commit = [split ' ',$commit]->[1];
        my $epoch_date = $repo->command('show', '-s', '--format=%ct', 'HEAD~0');

        my $nice_date = DateTime->from_epoch(epoch => $epoch_date)->dmy('.') . ' ' . DateTime->from_epoch(epoch => $epoch_date)->hms;

        return to_json {commit => $commit, author => $author, date => $nice_date, epoch => $epoch_date, comment => join '', @comment};
    };
}

sub make_schema {
	my $db = shift;
	# Automaticly generate schema
	my $schema_report = eval {
		make_schema_at(
		    config->{plugins}->{DBIC}->{default}->{schema_class},
		    { dump_directory => "$appdir/lib", debug => 1, filter_generated_code => sub{
		    	my ( $type, $class, $text ) = @_;
		    	if($type eq 'result'){
			    	return "$text"; # by TabelEdit Grega Pompe 2013
		    	}
		    	else {
		    		return $text;
		    	}
		    }},
		    [ $db->{dsn}, $db->{user}, $db->{pass} ],
		);
	};
	# Return error or empty string if successfull
	return "$@";
}


sub set_db {
	my $db_settings = shift;
	
	# Set schema settings
	if( $db_settings ){
        my $dbname = $db_settings->{dbname} || '';

        if ($db_settings->{driver} eq 'Pg') {
            $dbname = "database=$dbname";
        }

        my $dsn = join (':', ('dbi',
                              $db_settings->{driver} || '',
                              $dbname));

        if ($db_settings->{dsn_suffix}) {
            $dsn .= ";$db_settings->{dsn_suffix}";
        }

        # Our settings
        my $our_settings = {
			dsn => $dsn,
            user => $db_settings->{user} || '',
            pass => $db_settings->{pass} || '',
            schema_class => $db_settings->{schema_class}
        };

        # Retrieve current settings
        my $dbic_settings = config->{plugins}->{DBIC};

        # Merge settings
        $dbic_settings->{default} = $our_settings;

        set plugins => {DBIC => $dbic_settings};
	}
}

# heuristic for parse DSN
sub parse_dbic_settings {
    my $db = shift;

    if ($db->{dsn}) {
        my @parts = split(':', $db->{dsn});

        if (@parts == 3) {
            my @options = split(';', $parts[2]);

            for my $opt (@options) {
                if ($opt =~ /^(dbname=)(\w+)$/) {
                    $db->{dbname} = $2;
                    last;
                }
            }
        }
    }

    return $db;
}

# bootstrap config schema object
sub _bootstrap_config_schema {
    my $dbfile = "$appdir/db/config.db";
    my $schema;

    if (-f $dbfile) {
        $schema = TableEdit::ConfigSchema->connect("dbi:SQLite:$dbfile");
    }
    else {
        # create database
        my $dbh = DBI->connect("dbi:SQLite:dbname=$dbfile", '', '',
                           {PrintError => 0});

        if (! $dbh) {
            die "Failed to create ConfigSchema database $dbfile: $DBI::errstr";
        }

        $schema = TableEdit::ConfigSchema->connect("dbi:SQLite:$dbfile");

        $schema->deploy;
    }

    return $schema;
}

=head2 load_settings $path

Loads configuration file from path $path, which can be an absolute path
or a relative path starting at appdir.

=cut

sub load_settings {
    my $settings_file = shift;
    my $settings_file_path;

    if (File::Spec->file_name_is_absolute($settings_file)) {
        $settings_file_path = $settings_file;
    }
    else {
        $settings_file_path = File::Spec->catfile($appdir, $settings_file);
    }

    Dancer::Config::load_settings_from_yaml($settings_file_path);
}

sub column_types {
	my $dir = $appdir.'/public/views/column';
	return @column_types if @column_types;
    opendir(DIR, $dir) or die $!;

    while (my $file = readdir(DIR)) {
        # Use a regular expression to ignore files beginning with a period
        next if ($file =~ m/^\./);
        # remove .html
        $file =~ s/\.html//;
        $file =~ s/\.htm//;
		push @column_types, $file;
    }
    closedir(DIR);
    return @column_types;
}

1;

