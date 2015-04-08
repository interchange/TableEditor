package TableEdit::SchemaInfo::Role::ListUtils;

use Moo::Role;

=head1 NAME

TableEdit::SchemaInfo::Role::ListUtils - Role for list utility functions

=head1 METHODS

=head2 list_output($data,$wantarray,$attribute,$numeric)

Returns array in list context, sorted according to sort
attribute and $attribute variable.

Returns hash reference otherwise.

=cut

sub list_output {
    my ($self, $data, $wantarray, $attribute, $numeric) = @_;

    if ($wantarray) {
        if ($self->sort) {
            if ($attribute) {
		if ($numeric) {
		    return sort {$a->$attribute <=> $b->$attribute} values %$data;
		}
		else {
		    return sort {$a->$attribute cmp $b->$attribute} values %$data;
		}
            }
            else {
                return sort {$a->name cmp $b->name} values %$data;
            }
        }

        return values %$data;
    }

    return $data;
}

1;
