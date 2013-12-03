package TableEdit::Auth;
use Dancer ':syntax';

prefix '/';

get '/login' => sub {
	return to_json session('username') ? {username => session('username')} : {};
};

post '/login' => sub {
	my $post = from_json request->body;
	my $password = $post->{user}->{password};
	my $user = {role => 'guest'};
	if($password eq 'buzz'){
		$user->{role} = 'admin';
		$user->{username} = $post->{user}->{username};
		session username => $post->{user}->{username};
	}
	return to_json $user;
};


post '/logout' => sub {
	# Delete user session data and log him out
	session username => undef;
	return 1;
};

1;