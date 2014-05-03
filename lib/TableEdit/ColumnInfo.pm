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
    }
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

=head2 foreign type

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

=head2 hidden

Whether column is hidden or not.

=cut

has hidden => (
    is => 'ro',
    default => 0,
);

has hashref => (
    is => 'lazy',
    default => sub {
	my $self = shift;
	my %hash = (
	    data_type => $self->data_type,
	    display_type => $self->display_type,
	    foreign_column => $self->foreign_column,
	    hidden => $self->hidden,
	    is_foreign_key => $self->is_foreign_key,
	    is_nullable => $self->is_nullable,
	    label => $self->label,
	    name => $self->name,
	    size => $self->size,
	);

	return \%hash;
    },
);

1;
