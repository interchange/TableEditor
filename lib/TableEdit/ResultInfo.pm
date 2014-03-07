package TableEdit::ResultInfo;

use Moo;
use MooX::Types::MooseLike::Base qw/InstanceOf/;

# DBIx::Class::Resultset
has resultset => (
    is => 'ro',
    required => 1,
    isa => InstanceOf ['DBIx::Class::ResultSet'],
);

has columns => (
    is => 'lazy',
);

has primary_key => (
    is => 'lazy',
);

sub _build_columns {
    my ($self) = @_;

    return [$self->resultset->result_source->columns];
}

sub _build_primary_key {
    my ($self) = @_;

    my @pk = $self->resultset->result_source->primary_columns;

    if (@pk) {
        return $pk[0];
    }
}

1;

