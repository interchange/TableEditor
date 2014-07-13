package TableEdit::Config;

use Dancer ':syntax';

use Dancer::Plugin::DBIC qw(schema resultset rset);
use DBI;
use DBIx::Class::Schema::Loader qw/ make_schema_at /;
use FindBin;
use Cwd qw/realpath/;
use TableEdit::ConfigSchema;
use TableEdit::DriverInfo;

my $appdir = realpath( "$FindBin::Bin/..");
my $SQLite = _bootstrap_config_schema();
set views => "$appdir/public/views";

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
            $schema_info->{db_info} = $db;
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

1;

