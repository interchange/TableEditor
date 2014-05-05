package TableEdit::ClassInfo;

use Moo;
use MooX::Types::MooseLike::Base qw/InstanceOf/;

use TableEdit::ColumnInfo;
use TableEdit::RelationshipInfo;

with 'TableEdit::SchemaInfo::Role::Label';
with 'TableEdit::SchemaInfo::Role::ListUtils';

=head1 ATTRIBUTES

=head2 name

Name of class.

=cut

has name => (
    is => 'ro',
    required => 1,
);

=head2 label

Label for class.

=head2 sort

Whether to sort output of columns and relationships in list context.

=cut

has sort => (
    is => 'rw',
    default => 0,
);

=head2 resultset

L<DBIx::Class::ResultSet> object for this class.

=head2 source

L<DBIx::Class::ResultSource> object for this class.

=cut

has resultset => (
    is => 'ro',
    required => 1,
    isa => InstanceOf ['DBIx::Class::ResultSet'],
    handles => {
	source => 'result_source',
    },
);

has _columns => (
    is => 'lazy',
);

has _relationships => (
    is => 'lazy',
);

=head1 METHODS

=head2 columns

Returns columns for this class.

In list context, returns array which is subject to sorting
depending on sort attribute.

Otherwise, returns hash reference.

=cut

sub columns {
    my $self = shift;

    return $self->list_output($self->_columns, wantarray);
}

=head2 column

Returns L<TableEdit::ColumnInfo> object for column name.

=cut

sub column {
    my ($self, $name) = @_;
    my $columns = $self->_columns;

    if (! exists $columns->{$name}) {
        die "No such column $name.";
    }

    return $columns->{$name};
}

sub _build__columns {
    my $self = shift;
    my %column_hash;
    my %rel_hash;
    my @columns_order = $self->source->columns;
    my $candidates = $self->source->columns_info;

    # build relationships first
    my $rels = $self->relationships;

    while (my ($rel_name, $rel_info) = each %$rels) {
        # build hash by source column
        $rel_hash{$rel_info->self_column} = $rel_info;
    }

    # column positions
    my $pos = 1;
    my %column_pos;

    map {$column_pos{$_} = $pos++} @columns_order;

    while (my ($name, $info) = each %$candidates) {
        # check if there is a relationship for this column
        if (exists $rel_hash{$name}) {
            my $rel_obj = $rel_hash{$name};

            $info->{foreign_column} = $rel_obj->{foreign_column};
            $info->{foreign_type} = $rel_obj->{type};
            $info->{relationship} = $rel_obj;
        }

        $column_hash{$name} = TableEdit::ColumnInfo->new(
            name => $name,
            position => $column_pos{$name},
            %$info);
    }

    return \%column_hash;
}

=head2 relationships

Returns relationships for this class.

In list context, returns array which is subject to sorting
depending on sort attribute.

Otherwise, returns hash reference.

=cut

sub relationships {
    my $self = shift;

    return $self->list_output($self->_relationships, wantarray);
}

sub _build__relationships {
    my $self = shift;
    my $source = $self->source;
    my $columns = {};
    my %rel_hash;

    for my $rel_name ($source->relationships){
        my $rel_info = $source->relationship_info($rel_name);
        my $relationship_class_package = $rel_info->{class};

        next if $rel_info->{hidden};

        my ($foreign_column, $column_name) = %{$rel_info->{cond}};

        unless ($foreign_column =~ s/^foreign\.//) {
            die "no match for $foreign_column.";
        }

        unless ($column_name =~ s/^self\.//) {
            die "no match for $column_name.";
        }

        my $column_info = $columns->{$column_name};
        $rel_info->{foreign} = $rel_name;
        $rel_info->{foreign_column} = $foreign_column;

        my $rel_type = $rel_info->{attrs}->{accessor};

        my $foreign_type;

        # Type of relationship
        if ($rel_type eq 'single') {
            # try fk_columns
            if (exists $rel_info->{attrs}->{fk_columns}) {
                $foreign_type = 'belongs_to';
            }
            else {
                $foreign_type = 'might_have';
            }
        }
        elsif ($rel_type eq 'multi') {
            $foreign_type = 'has_many';
        }

	my $resultset = $source->schema->resultset($rel_info->{class});

        $rel_hash{$rel_name} = TableEdit::RelationshipInfo->new(
            name => $rel_name,
            type => $foreign_type,
            cond => $rel_info->{cond},
            self_column => $column_name,
            foreign_column => $foreign_column,
	    resultset => $resultset,
        );
    }

    return \%rel_hash;
}

=head2 count

Returns number of records for this class.

=cut

sub count {
    my $self = shift;

    return $self->resultset->count;
}

1;
