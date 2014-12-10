package TableEdit;
# ABSTRACT: Data manupulation web app
use Dancer ':syntax';

our $VERSION = '0.1';

use Dancer::Plugin::DBIC qw(schema resultset rset);
use TableEdit::Config;
use TableEdit::Plugins;
use TableEdit::Session;
use TableEdit::Routes::API;
use TableEdit::Auth;

prefix '/';

=head2 Base url

URIs when the application is mounted at /myurl/.

=cut

get '/' => sub {
    template 'index.html', {
    	base_url => config->{base_url}, 
    	plugins => TableEdit::Plugins::attr('plugins'),
    };
};


true;
