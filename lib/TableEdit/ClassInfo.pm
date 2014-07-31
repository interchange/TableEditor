package TableEdit::ClassInfo;

use Dancer ':syntax';
use Moo;
use MooX::Types::MooseLike::Base qw/InstanceOf/;

use TableEdit::ColumnInfo;
use TableEdit::RelationshipInfo;
use Dancer::Plugin::DBIC qw(schema rset);

with 'TableEdit::SchemaInfo::Role::ListUtils';

my $dropdown_treshold = config->{TableEditor}->{dropdown_treshold} || 50;

sub BUILDARGS {
	my ( $class, $name ) = @_;   
	return { 
   		name => $name, 
   		resultset => schema->resultset(ucfirst($name)),
   	};
 };
 
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
    default => 1,
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

    return $self->list_output($self->_columns, wantarray, 'position', 1);
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


sub columns_info { 
    my ($self, $selected_columns) = @_;
    my $columns_info = [];

	$selected_columns = [$self->columns] unless $selected_columns;

    for my $column_info (@$selected_columns) {

		# Belongs to or Has one
		my $foreign_type = $column_info->foreign_type;
	
		if ($foreign_type eq 'belongs_to' or $foreign_type eq 'might_have') {
		    my $rs = $column_info->relationship->resultset;
	
		    # determine number of records in foreign table
		    my $count = $rs->count;
		    if ($count <= $dropdown_treshold){
			$column_info->display_type ('dropdown');
			my @foreign_rows = $rs->all;
			$column_info->options($column_info->dropdown_options); #(\@foreign_rows, $column_info->{foreign_column})
		    }
		}
		push @$columns_info, $column_info->hashref;
    }

    return $columns_info;
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

            $info->{foreign_column} = $rel_obj->foreign_column;
            $info->{foreign_type} = $rel_obj->type;
            $info->{relationship} = $rel_obj;
        }

        $column_hash{$name} = TableEdit::ColumnInfo->new(
            name => $name,
            position => $column_pos{$name},
            class => $self,
            %$info);
    }

    return \%column_hash;
}

=head2 primary_key

Returns primary key(s) for this class.

=cut

sub primary_key {
    my $self = shift;
    my @pk;
    @pk = $self->source->primary_columns;

    if (@pk > 1) {
		return \@pk;
    }
    else {
		return $pk[0];
    }
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

=head2 relationship $name

Returns relationship name.

=cut

sub relationship {
    my ($self, $name) = @_;
    my $relationships = $self->_relationships;

    if (! exists $relationships->{$name}) {
        die "No such relationship $name.";
    }

    return $relationships->{$name};
}

sub relationships_info {
    my ($self) = @_;
	return [map {$_->hashref} $self->relationships];
}

sub _build__relationships {
    my $self = shift;
    my $source = $self->source;
    my $columns = {};
    my %rel_hash;

    for my $rel_name ($source->relationships){
        my $rel_info = $source->relationship_info($rel_name);

        next if $rel_info->{hidden};

        # Determine name of class this relationship points to
        my $class_name = $rel_info->{class};
        $class_name =~ s/\w+:://g;

        my ($foreign_column, $column_name) = %{$rel_info->{cond}};

        $foreign_column =~ s/^foreign\.//;
        $column_name =~ s/^self\.//;

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
        elsif ($rel_type eq 'filter') {
            if ($rel_info->{attrs}->{join_type} and $rel_info->{attrs}->{join_type} eq 'LEFT') {
                # example: Strehler::Schema::Result::Description
                $foreign_type = 'belongs_to';
            }
            else {
                $foreign_type = 'has_many';
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
            origin_class => $self,
            class_name => $class_name,
            resultset => $resultset,
        );
    }

    return \%rel_hash;
}

=head2 count

Returns number of records for this class.

=cut

has count => (
    is => 'lazy',
	default => sub {
	    my $self = shift;
	    return $self->resultset->count;
	}
);

has label => (
    is => 'lazy',
    default => sub {
        my $self = shift;
		my $class = $self->name;
		my $label = config->{TableEditor}->{classes}->{$class}->{label};
		return $label if $label;
		$class =~ s/_/ /g;	
		$class =~ s/(?<! )([A-Z])/ $1/g; # Add space in front of Capital leters 
		$class =~ s/^ (?=[A-Z])//; # Strip out extra starting whitespace followed by A-Z
		return $class;
    },
);

has attributes => (
    is => 'lazy',
	default => sub  {
		my $self = shift;
		return $self->resultset->result_source->resultset_attributes;
	}
);

=head2 class_grid_columns

Return array of all columns suitable for grid display.

=cut

sub class_grid_columns {
    my $self = shift;
	
    return $self->attributes->{grid_columns} if $self->attributes->{grid_columns};

    my $columns = [];

    for my $column_info ($self->columns){
		# Leave out inappropriate columns
		next if $column_info->data_type and $column_info->data_type eq 'text';
		next if $column_info->size and $column_info->size > 255;
	
		push @$columns, $column_info;
    }

    return $columns;
}


sub grid_columns_info {
	my ($self) = @_;
	my $default_columns = [];
	my $columns = $self->class_grid_columns;
	for my $col (@$columns){
	    my $col_info = $col->hashref;
		my %col_copy = %{$col_info};

		# Cleanup for grid
		$col_copy{required} = 0 ;
		$col_copy{readonly} = 0 ;
		$col_copy{primary_key} = 0 ;

		push @$default_columns, \%col_copy; 		
	}

	
	return $default_columns; 
}

1;
