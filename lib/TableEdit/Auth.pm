package TableEdit::Auth;
use Dancer ':syntax';
use Dancer::Plugin::Auth::Extensible;
use TableEdit::Session

prefix '/';

get '/login' => sub {
	if(session('logged_in_user')){
		return to_json {
			username => session('logged_in_user'),
		};
	}
	else {
		return to_json {};
	}
};

post '/login' => sub {
	my $post = from_json request->body;
    my $username = $post->{user}->{username} || '';
	my $password = $post->{user}->{password} || '';
	my $user = {role => 'guest'};

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

        debug "Login successful for user $username.";
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


get '/sessions/active' => sub {
	return to_json TableEdit::Session::active_sessions_besides_me;
};

1;
