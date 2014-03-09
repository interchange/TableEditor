package TableEdit;
use Dancer ':syntax';

our $VERSION = '0.1';

use Dancer::Plugin::DBIC qw(schema resultset rset);
use TableEdit::Config;
use TableEdit::API;
use TableEdit::Auth;

hook 'before_template_render' => sub {
	my $tokens = shift;
	$tokens->{'site-title'} = 'Table Edit';
};

prefix '/';
get '/' => sub { return forward '/index.html'};
get '/index.html' => sub { template 'index';};
get '/views/*.html' => sub {
    my ($view) = splat;

    template $view;
};

true;
