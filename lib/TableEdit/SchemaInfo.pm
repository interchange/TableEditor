package TableEdit::SchemaInfo;

use Moo;
use MooX::Types::MooseLike::Base qw/InstanceOf/;

# DBIx::Class schema
has schema => (
    is => 'ro',
    required => 1,
    isa => InstanceOf ['DBIx::Class::Schema'],
);

=head2 classes_with_single_primary_key {

Returns all classes with a single primary key
in alphabetical order.

=cut

sub classes_with_single_primary_key {
    my ($self) = @_;
    my (@pk_classes);
    my $schema = $self->schema;

    my $candidates = [sort values $schema->{class_mappings}];

    for my $class (@$candidates) {
        push @pk_classes, $class if $schema->source($class)->primary_columns == 1;
    }

    return \@pk_classes;
}

1;
