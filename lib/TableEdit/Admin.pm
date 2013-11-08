package TableEdit::Admin;

use Dancer ':syntax';
use Dancer::Plugin::DBIC qw(schema resultset rset);

prefix '/';

hook 'before_template_render' => sub {
    my $tokens = shift;
	my $schema = schema;

    $tokens->{menu} = [map {name=> class_label($_), url=>"$_/list"}, @{classes()}];
};


# Authorization check
any qr{/admin(.*)} => sub {
	
	
	pass;
};


get '/admin' => sub {
	my (@languages, $errorMessage);
	

	debug "Admin";
	template 'admin/index', { 
		};
};


sub classes {
	my $classes = [sort values schema->{class_mappings}];
	my $classes_with_pk = [];
	for my $class (@$classes){
		my @pk = schema->source($class)->primary_columns;
		push $classes_with_pk, $class if (@pk == 1);
	}
	return $classes_with_pk;
}


sub class_label {
	my $class = shift;
	$class =~ s/(?<! )([A-Z])/ $1/g; # Search for "(?<!pattern)" in perldoc perlre 
	$class =~ s/^ (?=[A-Z])//; # Strip out extra starting whitespace followed by A-Z
	return $class;
}

true;

