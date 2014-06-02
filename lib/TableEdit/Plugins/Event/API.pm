package TableEdit::Plugins::Locator::API;
use Dancer ':syntax';


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

post '/:class' => sub {
	debug "Validating ". params->{class}."...";
	pass;
};

1;
