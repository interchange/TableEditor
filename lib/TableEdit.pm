package TableEdit;
use Dancer ':syntax';

our $VERSION = '0.1';

use Dancer::Plugin::DBIC qw(schema resultset rset);
use TableEdit::Config;
use TableEdit::Plugins;
use TableEdit::Routes::API;
use TableEdit::Auth;

hook 'before_template_render' => sub {
	my $tokens = shift;
	$tokens->{'site-title'} = 'Table Edit';
};

prefix '/';
get '/' => sub { return forward '/index.html'};
get '/index.html' => sub { template 'index';};

=head2 get '/views/**.html'

Route which returns the views used by Angular as
templates.

We use this instead of HTML files to adjust the
URIs when the application is mounted at /myurl/.

=cut

get '/views/**.html' => sub {
    my ($view) = splat;
    my $template = join('/', @$view);

    template $template;
};

true;
