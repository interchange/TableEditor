package TableEdit::Config;

use Dancer ':syntax';

use Dancer::Plugin::DBIC qw(schema resultset rset);
use Dancer::Plugin::Auth::Extensible;
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

=head1 NAME

TableEdit::Config - TableEditor configuration functions and routes

=cut

my $appdir = config->{'appdir'};
my $SQLite = _bootstrap_config_schema();
my @column_types;
set views => "$appdir/public/views";

# Load TE settings
my $settings_file = config->{'settings_file'};

load_settings($settings_file) if $settings_file and (-f $settings_file);

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
			host => $db_settings->host,
			port => $db_settings->port,
            schema_dir => $db_settings->schema_dir,
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

    if (my $dir = $schema_info->{db_info}->{schema_dir}) {
        # Prepending directory with schema class modules
        # to Perl's load path
        unshift @INC, $dir;
    }

	# Check for DB connection
	my $db_test = eval{schema->storage->dbh};
	$schema_info->{db_connection_error} = "$@";
	delete $schema_info->{db_info};

	# Check if DBIx class schema exists
	unless($schema_info->{db_connection_error}){
		if (eval{schema}){
			if(%{schema->{class_mappings}}){
				$schema_info->{schema} = scalar keys %{schema->{class_mappings}};		
				$schema_info->{schema_keys} = join ', ', keys %{schema->{class_mappings}};		
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

    if (exists $schema_info->{db_info} && $schema_info->{db_info}) {
        for my $censored (qw/pass password/) {
            delete $schema_info->{db_info}->{$censored};
        }
    }

	return to_json $schema_info;
};

post '/db-config' => sub {
	my $post = from_json request->body;
	my $error;
	
	$error = 'Database type not defined!' unless $error or $post->{config}->{driver};
	$error = 'Database name not defined!' unless $error or $post->{config}->{dbname};
	$error = 'User not defined!' unless $error or $post->{config}->{user};
	
	# Default schema
	$post->{config}->{schema_class} ||= 'TableEdit::Schema';
	
	unless($error){
		set_db( $post->{config} );
		my $db_test = eval{schema->storage->dbh} ;
		$error = $@;
	}
	
	if ( $error ) {	
		set_db(undef);
		my $raw_error = $error;
		$raw_error = $error->{msg} if ref $error eq 'DBIx::Class::Exception';
		
		# Pretty errors for user	
		$error ||= $raw_error;		
		$error = 'Error' if index ($raw_error, 'The schema default is not configured') >= 0;
		$error = 'Could not connect to '.$post->{config}->{dbname} if index ($raw_error, 'DBI Connection failed: DBI connect') >= 0;
		$error = 'Access denied for user '.$post->{config}->{user} if index ($raw_error, 'Access denied for user') >= 0;
		
		return to_json {error => $error, raw_error => $raw_error};
	}
	
	# Save to db
	my $db = $SQLite->resultset('Db')->create({name => 'default', %{$post->{config}} });
	
	
	return to_json {db => 'configured'};
};

get '/schema/deploy' => sub {
	return to_json {deploy_errors => schema->deploy};
};

if (config->{TableEditor}->{menu_settings}->{update}) {
    load_class 'Git';

    get '/update' => require_login sub {
        my $repo = Git->repository (Directory => $appdir);
        my @result = $repo->command('pull', '--all');
        return to_json {result => join ' ', @result};
    };

    get '/last_update' => require_login sub {
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
		    [ $db->{dsn}, $db->{user}, $db->{password} ],
		);
	};
	# Return error or empty string if successfull
	return "$@";
}


sub set_db {
	my $db_settings = shift;
	
   	# Retrieve current settings
    my $dbic_settings = config->{plugins}->{DBIC};
	
	# Set schema settings
	if( $db_settings ){

        my $dbname = $db_settings->{dbname} || '';
        $dbname = "dbname=$dbname";
        my $dsn = join (':', ('dbi',
                              $db_settings->{driver} || '',
                              $dbname));
        
        $dsn .= ";host=$db_settings->{host}" if ($db_settings->{host});
        $dsn .= ";port=$db_settings->{port}" if ($db_settings->{port});
        $dsn .= ";$db_settings->{dsn_suffix}" if ($db_settings->{dsn_suffix});
        

        # Our settings
        my $our_settings = {
			dsn => $dsn,
            user => $db_settings->{user} || '',
            password => $db_settings->{pass} || '',
            schema_class => $db_settings->{schema_class}
        };

        # Merge settings
        $dbic_settings->{default} = $our_settings;
		debug schema->storage->connect_info([$dsn,$db_settings->{user},$db_settings->{pass},undef])
	}
	
	# Remove if error
	else {
        # Merge settings
        $dbic_settings->{default} = undef;
	}
	return $dbic_settings;
}

# heuristic for parse DSN
sub parse_dbic_settings {
    my $db = shift;

    if ($db->{dsn}) {
        my @parts = split(':', $db->{dsn});

        if (@parts == 3) {
            my @options = split(';', $parts[2]);

            for my $opt (@options) {
                if ($opt =~ /^((database|dbname)=)(\w+)$/) {
                    $db->{dbname} = $3;
                    last;
                }
            }
        }
    }

    return $db;
}

# bootstrap config schema object
sub _bootstrap_config_schema {
    my $dbfile = config->{TableEditor}->{configschema_dbfile} || "db/config.db";
    my $schema;

    $dbfile = file_path($dbfile);

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
    my $settings_file_path = file_path($settings_file);

    Dancer::Config::load_settings_from_yaml($settings_file_path);
}

=head2 file_path $file

Determines path for file.

=cut

sub file_path {
    my $file = shift;
    my $file_path;

    if (File::Spec->file_name_is_absolute($file)) {
        $file_path = $file;
    }
    else {
        $file_path = File::Spec->catfile($appdir, $file);
    }

    return $file_path;
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

