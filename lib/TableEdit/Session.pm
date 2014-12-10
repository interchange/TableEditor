package TableEdit::Session;
use Dancer ':syntax';


my $active_sessions = {};
my $interval = defined config->{TableEditor}->{active_users_interval} ? config->{TableEditor}->{active_users_interval} : 100;


sub active_sessions {
	my $threshold = $interval;
	for my $s (keys %$active_sessions)	{
		delete $active_sessions->{$s} if $active_sessions->{$s}->{'last_seen'} < $threshold;
	}
	return [values %$active_sessions];
}

sub active_sessions_besides_me {
	my @sessions;
	for my $s (@{ active_sessions() })	{
		push  @sessions, $s unless $s->{username} and session('logged_in_user') and $s->{username} eq session('logged_in_user');
	}
	return [@sessions];
}

sub seen {
	if( session('logged_in_user') ){
		my $id = session->read_session_id;
		$active_sessions->{$id}->{'last_seen'} = time;
		$active_sessions->{$id}->{'username'} = session('logged_in_user');
	}
}

prefix '/api';

get '/sessions/active' => sub {
	my $active = {interval => $interval};
	return to_json $active unless session('logged_in_user');
	$active->{users} = active_sessions_besides_me;
	return to_json $active;
};

1;
