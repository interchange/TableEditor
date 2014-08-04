package TableEdit::RowInfo;

use Dancer ':syntax';
use DBI;
use Moo;
use MooX::Types::MooseLike::Base qw/InstanceOf/;

=head1 NAME

TableEdit::RowInfo - Extended DBIx::Class::Row 

=head1 ATTRIBUTES

=cut

has row => (
    is => 'ro',
    required => 1,
    isa => InstanceOf ['DBIx::Class::Row'],
);


=head2 class

Returns L<TableEdit::ClassInfo> object that tow belongs.

=cut

has class => (
    is => 'ro',
    required => 1,
    isa => InstanceOf ['TableEdit::ClassInfo'],
);



=head2 label

String representation of object

=cut

sub to_string {
	my $self = shift;

	# Config set label
	my $row = $self->row;
	my $label = eval $self->attr('to_string') if $self->attr('to_string');
	return $label if $label;

	my $class = $self->row->result_source->{source_name};
	my $classInfo = TableEdit::ClassInfo->new(name => $class, schema => $self->class->schema);
	my ($pk) = $self->row->result_source->primary_columns;
	my $id = $self->row->$pk;
	return "$id - ".$classInfo->label;
}


=head2 attributes

=cut
sub attr  {
		my ($self, @path) = @_;
		my $value;
		my $node = config->{TableEditor}->{classes}->{$self->class->name};
		for my $p (@path){
			$node = $node->{$p};
			return $node unless defined $node;
		}
		return $node;
}

1;
