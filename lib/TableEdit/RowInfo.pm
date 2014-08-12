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
	my $primary_key = $classInfo->primary_key;
	my $id = $self->primary_key_string;
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

sub primary_key_value {
	my $self = shift;
	my $primary_key = $self->class->primary_key;
	my $primary_key_value;
	for my $key (@$primary_key){
		$primary_key_value->{$key} = $self->row->$key;
	}
	return $primary_key_value;
}

sub primary_key_string {
	my $self = shift;
	my $delimiter = $self->class->schema->primary_key_delimiter;
	my $primary_key = $self->class->primary_key;
	my @primary_key_value;
	for my $key (@$primary_key){
		push @primary_key_value, $self->row->$key;
	}
	return join($delimiter, @primary_key_value);
}

1;
