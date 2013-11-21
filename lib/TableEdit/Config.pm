package TableEdit::Config;

use Dancer ':syntax';

use Dancer::Plugin::DBIC qw(schema resultset rset);
use DBIx::Class::Schema::Loader qw/ make_schema_at /;
use FindBin;
use Cwd qw/realpath/;

my $appdir = realpath( "$FindBin::Bin/..");

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
		$schema_info->{db_info} = $db;
	}
	
	# Check for DB connection
	my $db_test = eval{schema->storage->dbh};
	$schema_info->{db_connection_error} = "$@";
	
	# Check if DBIx class schema exists
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
	

	# TODO: Input db data through form 	
	if(0){
	    # Create a YAML file
	    my $yaml = YAML::Tiny->new;
	
	    # Open the config
	    my $config_path = '../config.yml';
	    $yaml = YAML::Tiny->read( $config_path );
	
	    # Reading properties
	    my $db = $yaml->[0]->{plugins}->{DBIC}->{default};
	    $db->{dsn} = 'dbi:Pg:dbname=iro;host=localhost;port=8948';
	    $db->{options} = {};
	    $db->{user} = 'interch';
	    $db->{pass} = '94daq2rix';
	    $db->{schema_class} = 'TableEdit::Schema';
	
	    # Save the file
	    #$yaml->write( $config_path );
	}
	
	$schema_info->{db_info}->{pass} = '******';
	
	return to_json $schema_info;
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
	# Return error or enpty string if successfull
	return "$@";
}

1;

