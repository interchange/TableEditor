package TableEdit;
use Dancer ':syntax';

our $VERSION = '0.1';

use TableEdit::Admin;
use TableEdit::CRUD;
use TableEdit::Schema;
use Dancer::Plugin::DBIC qw(schema resultset rset);

hook 'before_template_render' => sub {
	my $tokens = shift;
	$tokens->{'site-title'} = 'Table Edit';
};


get '/' => sub {
    return template 'index';
};

true;
