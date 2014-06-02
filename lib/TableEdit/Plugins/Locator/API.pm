package TableEdit::Plugins::Locator::API;
use Dancer ':syntax';

use Dancer::Plugin::Auth::Extensible;
use Dancer::Plugin::DBIC qw(schema resultset rset);
use TableEdit::SchemaInfo;

my $schema_info;

prefix '/api';

get '/test' => sub {
	return 'Plugin active';
};

# Data validation
post '/Event' => sub {
	debug "Validating only Event ". params->{class}."...";
	my $post_data = from_json request->body;
	my $values = $post_data->{item}->{values};
	unless ($values->{organizer_phone} eq '12345') {
		return to_json {error => {organizer_phone => "Wrong phone!"}};
	}
	
	pass;
};

get '/Event' => require_login sub {
	my (@languages, $errorMessage);
	my $class = 'Event';
	$schema_info ||= TableEdit::SchemaInfo->new(schema => schema);
	my $columns = [map {$_->hashref} @{TableEdit::Routes::API::columns_info($class, TableEdit::Routes::API::class_form_columns($class))}];
	my $relationships = [map {$_->hashref} $schema_info->relationships($class)];

	return to_json({ 
		custom_information => 'this is custom!',
		fields => $columns,
		class => $class,
		class_label => $schema_info->{$class}->{label},
		relations => $relationships,
	}, {allow_unknown => 1}); 
};

1;
