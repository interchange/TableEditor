package TableEdit::SchemaInfo;

use Dancer ':syntax';
use Moo;
use MooX::Types::MooseLike::Base qw/InstanceOf/;

require TableEdit::ClassInfo;


my $schema = {};
sub dropdown_treshold { return config->{TableEditor}->{dropdown_treshold} || 50 };


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
    my (@pk_classes);
    my $schema = $self->schema;

    my $candidates = [sort values %{$schema->{class_mappings}}];

    for my $class (@$candidates) {
        push @pk_classes, $class if $schema->source($class)->primary_columns == 1;
    }

    return \@pk_classes;
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


sub _build__classes {
    my $self = shift;
    my %class_hash;
    my $schema = $self->schema;
    my $candidates = [sort values %{$schema->{class_mappings}}];

    for my $class (@$candidates) {
        my $rs = $self->schema->resultset($class);
        $class_hash{$class} = TableEdit::ClassInfo->new($class);
    }

    return \%class_hash;
}


sub columns_static_info {
	my ($self, $classInfo) = @_;
	my $class = $classInfo->name;
	my $columns = $classInfo->columns_info; 
	my $columns_info = {};
	

	for my $relationship($classInfo->relationships){
	    next;
		my $relationship_info = $classInfo->relationship_info($relationship);
		debug "RI for $relationship: ", $relationship_info;
		my $relationship_class_package = $relationship_info->{class};
		next if $relationship_info->{hidden};
		my $relationship_class = $self->schema->class_mappings->{$relationship_class_package};
		my $count = $self->schema->resultset($relationship_class)->count;
		
		my ($foreign_column, $column_name) = %{$relationship_info->{cond}};
		$foreign_column =~ s/foreign\.//g;
		$column_name =~ s/self\.//g;
		
		my $column_info = $columns->{$column_name};
		$relationship_info->{foreign} = $relationship;
		$relationship_info->{foreign_column} = $foreign_column;

		my $rel_type = $relationship_info->{attrs}->{accessor};
		# Belongs to or Has one
		if( $rel_type eq 'single' or $rel_type eq 'filter' ){
			$relationship_info->{foreign_type} = 'belongs_to' if $rel_type eq 'filter';
			$relationship_info->{foreign_type} = 'might_have' if $rel_type eq 'single';
			
			# Add fk column attributes
			my ($fk_column) = keys %{$relationship_info->{attrs}->{fk_columns}};
			$relationship_info = {%$relationship_info, %{$columns->{$fk_column}}} if $fk_column;
			
			# If there aren't too many related items, make a dropdown
			if ($count <= dropdown_treshold){
				$relationship_info->{display_type} = 'dropdown';
				
				my @foreign_rows = schema->resultset($relationship_class)->all;
				$relationship_info->{options} = dropdown(\@foreign_rows, $foreign_column );
			}
			 
			column_add_info($column_name, $relationship_info, $class );
			$columns_info->{$column_name} = $relationship_info;
		}
	}
	
	my @selected_columns = $classInfo->columns;

	for my $ci (@selected_columns){
	    next if $ci->is_foreign_key or $ci->hidden;
	    column_add_info($ci->name, $ci, $class);
	    $columns_info->{$ci->name} = $ci;
	}

	return $columns_info;
}


sub column_add_info {
	my ($column_name, $column_info, $class) = @_;
	
	return undef if $column_info->{hidden};
	
	# Column calculated properties - can be overwritten in model
	my $classInfo = TableEdit::ClassInfo->new($class);
	my $columnInfo = $classInfo->column($column_name);
	$column_info->{display_type} ||= $columnInfo->field_type;
	$column_info->{default_value} = $columnInfo->default_value;
	$column_info->{name} = $columnInfo->name; # Column database name
	$column_info->{label} = $columnInfo->label; #Human label $column_info->{foreign} ? label($column_info->{foreign}) : label($column_name)
	$column_info->{required} ||= $columnInfo->required;	
	$column_info->{primary_key} = $columnInfo->is_primary;	  
	
}

1;