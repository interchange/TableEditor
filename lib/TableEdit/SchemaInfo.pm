package TableEdit::SchemaInfo;

use Moo;
use MooX::Types::MooseLike::Base qw/ArrayRef InstanceOf/;

require TableEdit::ClassInfo;
require TableEdit::RowInfo;
use TableEdit::Permissions;
use TableEdit::Plugins;

with 'TableEdit::SchemaInfo::Role::Config';
 
=head1 ATTRIBUTES

=head2 schema

L<DBIx::Class::Schema> object.

=cut

has schema => (
    is => 'ro',
    required => 1,
    isa => InstanceOf ['DBIx::Class::Schema'],
);

=head2 sort

Whether to sort output of classes and columns in list context.

=cut

has sort => (
    is => 'rw',
    default => 0,
);

has _classes => (
    is => 'lazy',
);

=head2 user_roles

List of roles which the current user belongs to.

=cut

has user_roles => (
    is => 'ro',
    isa => ArrayRef,
    default => sub {[]},
);

=head2 permissions

Returns L<TableEdit::SchemaInfo::Permissions> object for this schema.

=cut

has permissions => (
    is => 'lazy',
    isa => InstanceOf['TableEdit::Permissions'],
);

sub _build_permissions {
    my $self = shift;
    my $p = TableEdit::Permissions->new(roles => $self->user_roles,
                                        schema => $self);
    return $p;
}

=head1 METHODS

=head2 resultset $class

Returns L<DBIx::Class::ResultSet> object for $class.

=cut

sub resultset {
    my ($self, $class, $name) = @_;
    my $classes = $self->_classes;

    if (! exists $classes->{$class}) {
        die "No such class $class.";
    }

    return $classes->{$class}->resultset;
};

=head2 columns $class

Returns columns of $class as hash reference with column name
as key and L<TableEdit::ColumnInfo> objects as values.

=cut

sub columns {
    my ($self, $class, $name) = @_;
    my $classes = $self->_classes;

    if (! exists $classes->{$class}) {
        die "No such class $class.";
    }

    if (wantarray) {
        my @columns = $classes->{$class}->columns;
        return @columns;
    }

    return $classes->{$class}->columns;
};

=head2 column $class, $name

Returns L<TableEdit::ColumnInfo> object for $class and $name.

=cut

sub column {
    my ($self, $class, $name) = @_;
    my $classes = $self->_classes;

    if (! exists $classes->{$class}) {
        die "No such class $class.";
    }

    return $classes->{$class}->column($name);
};


=head2 classes

Returns available classes for this schema.

In list context, returns array which is subject to sorting
depending on sort attribute.

Otherwise, returns hash reference.

=cut

sub classes {
    my $self = shift;

    if (wantarray) {
        if ($self->sort) {
            return sort {$a->name cmp $b->name} values %{$self->_classes};
        }
        else {
            return values %{$self->_classes};
        }
    }

    return $self->_classes;
}

=head2 classes_with_single_primary_key {

Returns all classes with a single primary key
in alphabetical order.

=cut

sub classes_with_single_primary_key {
    my ($self) = @_;
    my (@primary_key_classes);
    my $schema = $self->schema;

    my $candidates = [sort values %{$schema->{class_mappings}}];

    for my $class (@$candidates) {
        push @primary_key_classes, $class if $schema->source($class)->primary_columns == 1;
    }

    return \@primary_key_classes;
}

=head2 class $name

Returns L<TableEdit::ClassInfo> object for $name.

=cut

sub class {
    my ($self, $name) = @_;
    my $classes = $self->_classes;

    if (exists $classes->{$name}) {
	return $classes->{$name};
    }
}

=head2 row $row

Returns L<TableEdit::RowInfo> object for $row.

=cut

sub row {
    my ($self, $row) = @_;
	return TableEdit::RowInfo->new(
		row => $row, 
		class => $self->class($row->result_source->source_name),
	);
}


sub _build__classes {
    my $self = shift;
    my %class_hash;
    my $schema = $self->schema;
    my $candidates = [sort values %{$schema->{class_mappings}}];

    for my $class (@$candidates) {
        my $rs = $self->schema->resultset($class);
        $class_hash{$class} = TableEdit::ClassInfo->new(
            name => $class,
            schema => $self,
            resultset => $rs,
            config => $self->config,
        );
    }

    return \%class_hash;
}

has dropdown_threshold => (
	is => 'lazy',
	default => sub { 
		my $self = shift;
		return $self->attr('dropdown_threshold') || 50 
	}
);

has menu => (
	is => 'lazy',
	default => sub { 
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

		return [sort { $a->{sort} <=> $b->{sort} } @$menu_array];
    }	
);

=head2 column_types

List of available column types for this schema.
Returns array reference.

=cut

has column_types => (
    is => 'ro',
    isa => ArrayRef,
    default => sub {[]},
);

has primary_key_delimiter  => (
	is => 'lazy',
	default => sub { 
		my $self = shift;
		return $self->attr('primary_key_delimiter') || ","; 	
	}
);

has page_sizes  => (
	is => 'lazy',
	default => sub { 
		my $self = shift;
		return $self->attr('page_sizes') || ","; 	
	}
);

=head2 attributes

Return attribute value

=cut

sub attr  {
		my ($self, @path) = @_;
		my $value;
		my $node = $self->config;

		for my $p (@path){
			$node = $node->{$p};
			return $node unless defined $node;
		}
		return $node;
}

1;
