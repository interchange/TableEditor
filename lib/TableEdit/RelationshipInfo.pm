package TableEdit::RelationshipInfo;

use Moo;
with 'MooX::Singleton';
use MooX::Types::MooseLike::Base qw/Enum InstanceOf/;

with 'TableEdit::SchemaInfo::Role::Label';

=head1 ATTRIBUTES

=head2 name

Name of this relationship.

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

=head2 class_name

Name of class where this relationship points to.

=cut

has class_name => (
    is => 'ro',
    required => 1,
);

=head2 class

Class where this relationship points to.

=cut

has class => (
    is => 'ro',
    required => 1,
    isa => InstanceOf ['TableEdit::ClassInfo'],
);

=head2 intermediate_relation

Name of second relationship that connects two tables in many_to_many relationship.

=cut

has intermediate_relation => (
    is => 'ro',
);

=head2 class_name

Name of intermediate class that connects two tables in many_to_many relationship.

=cut

has intermediate_name => (
    is => 'ro',
);

=head2 class_name

Name of intermediate class that connects two tables in many_to_many relationship.

=cut

has intermediate_class_name => (
    is => 'ro',
);

=head2 class

Intermediate class that connects two tables in many_to_many relationship.

=cut

has intermediate_class => (
    is => 'ro',
    isa => InstanceOf ['TableEdit::ClassInfo'],
);

=head2 cond

Relationship condition.

=cut

has cond => (
    is => 'ro',
);

=head2 self_column

=cut

has self_column => (
    is => 'ro',
);

=head2 foreign_column

=cut

has foreign_column => (
    is => 'ro',
);

=head2 origin_class

Returns L<TableEdit::ClassInfo> object where this relationship originates.

=cut

has origin_class => (
    is => 'ro',
    required => 1,
    isa => InstanceOf ['TableEdit::ClassInfo'],
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
    isa => InstanceOf ['DBIx::Class::ResultSet'],
    handles => {
		source => 'result_source',
    },
    default => sub{
    	my $self = shift; 
    	return $self->class->resultset
    },
);


=head2 hashref

Static and dynamic propeties about column

=cut
sub hashref {
		my $self = shift;
		
        my $foreign_column;
        $foreign_column = $self->origin_class->column($self->self_column) if $self->self_column;

		my $hash = $self->static_hashref;
		
        $hash->{options} = $foreign_column->dropdown_options if $foreign_column;
        $hash->{display_type} = $foreign_column->display_type if $foreign_column;

	    return $hash;
}


has static_hashref => (
    is => 'lazy',
    default => sub {
        my $self = shift;
        my $hash = {
            foreign_column => $self->foreign_column,
            class_name => $self->class_name, 
            hidden => $self->hidden,
            label => $self->label,
            name => $self->name,
            self_column => $self->self_column,
            type => $self->type,
            origin_class_name => $self->origin_class->name,
            origin_class_label => $self->origin_class->label,
        };
        return $hash;
    },
);


1;
