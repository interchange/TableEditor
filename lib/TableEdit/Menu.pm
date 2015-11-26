package TableEdit::Menu;

use Moo;
use Types::Standard qw/InstanceOf/;

use TableEdit::Plugins;

extends 'TableEdit::SchemaInfo';

=head1 NAME

TableEdit::Menu - subclass adding menu attribute

=head1 ATTRIBUTES

=head2 menu

Returns structure to be passed to the frontend for menu display.

=cut

has menu => (
	is => 'rwp',
    lazy => 1,
    builder => '_menu_builder',
);

sub _menu_builder {
    my $self = shift;
    my $classes = $self->attr('menu_classes');

	unless($classes){
        my @classes = $self->classes();
        $classes = \@classes if @classes; 
    }

    my $class_links = {};
    for my $classInfo (@$classes){
        my $class_name = !ref($classInfo) ? $classInfo : $classInfo->name; 
        $classInfo = $self->class($class_name);
        next unless $self->permissions->permission('read', $self->class($class_name) );
        $class_links->{$classInfo->label} = {
            class => $class_name,
            name => $classInfo->label, 
            url=> join('/', '#' . $classInfo->name, 'list'),};
    }
    my $menu;
    $menu->{'Tables'} = {active => 1, sort => 100, items => [map $class_links->{$_}, sort keys %$class_links]};

    for my $plugin (TableEdit::Plugins::class_list){
        if( $plugin->can('menu')){
            $menu = $plugin->menu($menu) ;
        }
    }

    # Sort and return array
    my $menu_array;
    for my $block ( keys %$menu){
        my $block_info = $menu->{$block};
        $block_info->{title} = $block;
        push @$menu_array, $block_info;
    }
    
    # Settings menu
    if($self->attr('menu_settings') ){
    	my @items;
	    
	    # Update
	    if($self->attr('menu_settings', 'update') ){
    	 push @items, {	            
		            "name" => "Update",
		            "url" => "#update"
		         },
	    }
	    
		push @$menu_array, {
			active => 1, 
			sort => 150, 
			title => 'Settings',
			items => \@items,
		};
    }


    return [sort { $a->{sort} <=> $b->{sort} } @$menu_array];
}

1;
