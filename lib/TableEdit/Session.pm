package TableEdit::Session;
use Dancer ':syntax';


my $active_sessions = {};
my $timeout = config->{active_user_timeout} || 100;

sub active_sessions {
	my $treshold = time - $timeout;
	for my $s (keys %$active_sessions)	{
		delete $active_sessions->{$s} if $active_sessions->{$s}->{'last_seen'} < $treshold;
	}
	return [values %$active_sessions];
}

sub active_sessions_besides_me {
	my @sessions;
	for my $s (@{ active_sessions() })	{
		push  @sessions, $s unless $s->{username} eq session('logged_in_user');
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

1;
