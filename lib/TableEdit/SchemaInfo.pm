package TableEdit::SchemaInfo;

use Moo;
use MooX::Types::MooseLike::Base qw/InstanceOf/;

use TableEdit::ClassInfo;

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

=head2 relationships $class

Returns relationships of $class as hash reference with column name
as key and L<TableEdit::RelationshipInfo> objects as values.

=cut

sub relationships {
    my ($self, $class, $name) = @_;
    my $classes = $self->_classes;

    if (! exists $classes->{$class}) {
        die "No such class $class.";
    }

    if (wantarray) {
        my @relationships = $classes->{$class}->relationships;
        return @relationships;
    }

    return $classes->{$class}->relationships;
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

sub _build__classes {
    my $self = shift;
    my %class_hash;
    my $schema = $self->schema;
    my $candidates = [sort values %{$schema->{class_mappings}}];

    for my $class (@$candidates) {
        my $rs = $self->schema->resultset($class);
        $class_hash{$class} = TableEdit::ClassInfo->new(name => $class, resultset => $rs, sort => $self->sort);
    }

    return \%class_hash;
}

1;
