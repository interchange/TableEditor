package TableEdit::ColumnInfo;

use Moo;

with 'TableEdit::SchemaInfo::Role::Label';

=head1 ATTRIBUTES

=head2 name

Column name.

=cut

has name => (
    is => 'ro',
    required => 1,
);

=head2 position

Position of the column in the class, starts with 1.

=cut

has position => (
    is => 'ro',
    required => 1,
);

=head2 data_type

Column data type.

=cut

has data_type => (
    is => 'ro',
    required => 1,
);

=head2 display_type

Column display type.

=cut

has display_type => (
    is => 'rw',
    lazy => 1,
    default => sub {
        return $_[0]->data_type;
    },
    trigger => sub {
	my ($self, $value) = @_;

	if (ref($self->{hashref}) eq 'HASH') {
	    $self->{hashref}->{display_type} = $value;
	}
    },
);

=head2 is_foreign_key

Whether column is foreign key.

=cut

has is_foreign_key => (
    is => 'ro',
    default => 0,
);

=head2 foreign_column

Column name of foreign key.

=cut

has foreign_column => (
    is => 'ro',
    default => '',
);

=head2 foreign_type

Type of foreign key.

=cut

has foreign_type => (
    is => 'ro',
    default => '',
);

=head2 is_nullable

Whether column is nullable or not.

=cut

has is_nullable => (
    is => 'ro',
);

=head2 size

Column size

=cut

has size => (
    is => 'ro',
);

=head2 default_value

Default value for column.

=cut

has default_value => (
    is => 'ro',
);

=head2 hidden

Whether column is hidden or not.

=cut

has hidden => (
    is => 'ro',
    default => 0,
);

=head2 relationship

L<TableEdit::RelationshipInfo> object if column
is foreign key.

=cut

has relationship => (
    is => 'ro',
);

=head2 options

Options to select values from for this column.

=cut

has options => (
    is => 'rw',
    trigger => sub {
	my ($self, $value) = @_;

	if (ref($self->{hashref}) eq 'HASH') {
	    $self->{hashref}->{options} = $value;
	}
    },
);

has hashref => (
    is => 'lazy',
    default => sub {
        my $self = shift;

	return $self->_as_hashref;
    },
);

sub _as_hashref {
    my $self = shift;

    my %hash = (
	data_type => $self->data_type,
	display_type => $self->display_type,
	foreign_column => $self->foreign_column,
    foreign_type => $self->foreign_type,
	hidden => $self->hidden,
	is_foreign_key => $self->is_foreign_key,
	is_nullable => $self->is_nullable,
	label => $self->label,
	name => $self->name,
	options => $self->options,
	size => $self->size,
    );

    return \%hash;
}

1;
