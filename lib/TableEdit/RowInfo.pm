package TableEdit::RowInfo;

use DBI;

use Moo;
use MooX::Types::MooseLike::Base qw/ArrayRef/;

extends 'DBIx::Class::Row';

=head1 NAME

TableEdit::RowInfo - Extended DBIx::Class::Row 

=head1 ATTRIBUTES

=cut



=head2 label

String representation of object

=cut

has id => (
    is => 'ro',
    isa => ArrayRef,
    lazy => 1,
    default => sub {[qw/CSV DBM ExampleP File Gofer Proxy Sponge/]},
);

sub model_to_string {
	my $object = shift;
	return $object->to_string if eval{$object->to_string};
	return "$object" unless eval{$object->result_source};
	my $class = $object->result_source->{source_name};
	my $classInfo = TableEdit::ClassInfo->new($class);
	my ($pk) = $object->result_source->primary_columns;
	my $id = $object->$pk;
	return "$id - ".$classInfo->label;
}


1;
