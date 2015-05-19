package TableEdit;
# ABSTRACT: Data manupulation web app

# TableEdit::DBIxClassModifiers must be loaded before DBIC schema so that CMM
# before modifiers are in place before load_{namespaces|classes} gets called.
use TableEdit::DBIxClassModifiers;

use Dancer ':syntax';

our $VERSION = '0.1';

use Dancer::Plugin::DBIC qw(schema resultset rset);
use TableEdit::Config;
use TableEdit::Plugins;
use TableEdit::Session;
use TableEdit::Routes::API;
use TableEdit::Auth;

prefix '/';

=head1 NAME

TableEdit - TableEditor main module

=cut

get '/' => sub {
    template 'index.html', {
    	base_url => config->{base_url}, 
    	plugins => TableEdit::Plugins::attr('plugins'),
    };
};


true;
