package TableEdit::SchemaInfo::Role::Label;

use Moo::Role;

=head1 ATTRIBUTES

=head2 label

Column label, computed from column name.

=cut

has label => (
    is => 'lazy',
);

sub _build_label {
    my $self = shift;

    if (my $label_attr = $self->attr('label')) {
        return $label_attr;
    }

    my $label = $self->name;

    $label =~ s/_/ /g;
    
    # Trim both
    $label =~ s/^\s+|\s+$//g;

    # Add space in front of capital letters.
    $label =~ s/(?<! )([A-Z])/ $1/g;

    # Strip out extra starting whitespace followed by A-Z
    $label =~ s/^ (?=[A-Z])//;

    return ucfirst($label);
};

1;

