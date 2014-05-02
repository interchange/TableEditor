package TableEdit::SchemaInfo::Role::ListUtils;

use Moo::Role;

sub list_output {
    my ($self, $data, $wantarray) = @_;

    if ($wantarray) {
	if ($self->sort) {
	    return sort {$a->name cmp $b->name} values %$data;
	}
	return values %$data;
    }

    return $data;
}

1;
