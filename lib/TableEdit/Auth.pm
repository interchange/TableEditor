package TableEdit::Auth;
use Dancer ':syntax';
use Dancer::Plugin::Auth::Extensible;


prefix '/';

get '/login' => sub {
	if(session('logged_in_user')){
		return to_json {
			username => session('logged_in_user'),
		};
	}
	else {
		send_error("Forbidden", 403);
		return to_json {};
	}
};

post '/login' => sub {
	my $post = from_json request->body;
    my $username = $post->{user}->{username} || '';
	my $password = $post->{user}->{password} || '';
	my $user = {};

    # removing surrounding whitespaces
    $username =~ s/^\s+//;
    $username =~ s/\s+$//;

    $password =~ s/^\s+//;
    $password =~ s/\s+$//;

    my ($success, $realm) = authenticate_user(
        $username, $password
    );
    if ($success) {
        session logged_in_user => $username;
        session logged_in_user_realm => $realm;

        $user->{username} = $username;
        $user->{roles} = user_roles;

        debug "Login successful for user $username with roles: ", join(',', user_roles);
    } else {
        # authentication failed
        debug "Login failed.";
    }

	return to_json $user;
};


post '/logout' => sub {
	# Delete user session
    session->destroy;
	return 1;
};


1;
