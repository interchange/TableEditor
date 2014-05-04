package TableEdit::RelationshipInfo;

use Moo;
use MooX::Types::MooseLike::Base qw/Enum InstanceOf/;

with 'TableEdit::SchemaInfo::Role::Label';

=head1 ATTRIBUTES

=head2 name

Name of class.

=cut

has name => (
    is => 'ro',
    required => 1,
);

=head2 type

Type of relationship, one of:

=over 4

=item belongs_to

=item has_many

=item might_have

=item has_one

=item many_to_many

=back

=cut

has type => (
    is => 'ro',
    required => 1,
    isa => Enum['belongs_to', 'has_many', 'might_have',
                'has_one', 'many_to_many'],
);

=head2 cond

Relationship condition.

=cut

has cond => (
    is => 'ro',
    required => 1,
);

=head2 self_column

=cut

has self_column => (
    is => 'ro',
    required => 1,
);

=head2 foreign_column

=cut

has foreign_column => (
    is => 'ro',
    required => 1,
);

=head2 hidden

Whether relationship is hidden or not.

=cut

has hidden => (
    is => 'ro',
    default => 0,
);

=head2 resultset

L<DBIx::Class::ResultSet> object for this relationship.

=cut

has resultset => (
    is => 'ro',
    required => 1,
    isa => InstanceOf ['DBIx::Class::ResultSet'],
    handles => {
	source => 'result_source',
    },
);

has hashref => (
    is => 'lazy',
    default => sub {
        my $self = shift;
        my %hash = (
            foreign_column => $self->foreign_column,
            hidden => $self->hidden,
            label => $self->label,
            name => $self->name,
            self_column => $self->self_column,
        );

        return \%hash;
    },
);


1;
