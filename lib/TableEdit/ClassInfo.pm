package TableEdit::ClassInfo;

use Dancer ':syntax';
use Moo;
use MooX::Types::MooseLike::Base qw/InstanceOf/;

require TableEdit::ColumnInfo;
require TableEdit::RelationshipInfo;
require Dancer::Plugin::DBIC;
require Class::Inspector;

with 'TableEdit::SchemaInfo::Role::ListUtils';

sub BUILDARGS {
	my $class = shift;
	my %args = @_;   
	return { 
   		name => $args{name}, 
   		schema => $args{schema}, 
   		resultset => Dancer::Plugin::DBIC::schema->resultset(ucfirst($args{name})),
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


has schema => (
    is => 'ro',
    required => 1,
    isa => InstanceOf ['TableEdit::SchemaInfo'],
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

has columns_info => (is => 'lazy');
sub _build_columns_info { 
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
		    if ($count <= $self->schema->dropdown_treshold){
				$column_info->display_type ('dropdown');
				my @foreign_rows = $rs->all;
				my $items = [];
				for my $row (@foreign_rows){
					my $rowInfo = TableEdit::RowInfo->new(row => $row, class => $column_info->relationship->{class});
					my $pk = $column_info->relationship->{class}->primary_key;
					my $id = $row->$pk;
					my $name = $rowInfo->to_string;
					push @$items, {option_label=>$name, value=>$id};
				}
				$column_info->dropdown_options($items); #(\@foreign_rows, $column_info->{foreign_column})
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
        if(
        	$rel_info->type ne 'many_to_many' and 
        	$rel_info->type ne 'has_many'
        ){
	        $rel_hash{$rel_info->self_column} = $rel_info;
        } 
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

	# Has many, might have, belongs to
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
            class => $self->schema->class($class_name),
            resultset => $resultset,
        );
    }

	# Add many to many relationships
	my $search_str = '__PACKAGE__->many_to_many(';
	my $filename = Class::Inspector->resolved_filename( $source->result_class );
	open (my $fh, "<", $filename) or die "cannot open < $filename: $!";
	while (my $row = <$fh>) {
		chomp $row;
		my $index = index $row, $search_str;
		next if $index == -1;
		my $rel_info = substr $row, $index + length($search_str), index($row, ')') - $index - length($search_str) ;
		my ($rel_name, $rel, $f_rel) = eval("($rel_info)");
		  
	    my $rel_source_name = $source->relationship_info($rel)->{source};
	    my $rel_source = $source->schema->resultset($rel_source_name)->result_source;
	  	my $class_name = $rel_source->relationship_info($f_rel)->{source};
        $class_name =~ s/\w+:://g;		  		  
        $rel_source_name =~ s/\w+:://g;		  		  
		
		$rel_hash{$rel_name} = TableEdit::RelationshipInfo->new(
            name => $rel_name,
            type => 'many_to_many',
            origin_class => $self,
            class_name => $class_name,
            class => $self->schema->class($class_name),
            intermediate_name => $rel,
            intermediate_class_name => $rel_source_name,
            intermediate_class => $self->schema->class($rel_source_name),
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

=head2 label

Returns nice string representation of class

=cut

has label => (is => 'lazy');
sub _build_label {
    my $self = shift;
	my $class = $self->name;
	my $label = config->{TableEditor}->{classes}->{$class}->{label};
	return $label if $label;
	$class =~ s/_/ /g;	
	$class =~ s/(?<! )([A-Z])/ $1/g; # Add space in front of Capital leters 
	$class =~ s/^ (?=[A-Z])//; # Strip out extra starting whitespace followed by A-Z
	return $class;
}

=head2 attributes

Return attribute value

=cut

sub attr  {
		my ($self, @path) = @_;
		my $value;
		unshift @path, 'TableEditor', 'classes', $self->name;
		my $node = config;
		for my $p (@path){
			$node = $node->{$p};
			return $node unless defined $node;
		}
		return $node;
}


=head2 grid_columns

Return array of all column names suitable for grid display.

=cut

has grid_columns => (is => 'lazy');
sub _build_grid_columns {
	my $self = shift;
    my $columns = $self->attr('grid_columns');
    return $columns if defined $columns;

    for my $column_info ($self->columns){
		# Leave out inappropriate columns
		next if $column_info->data_type and $column_info->data_type eq 'text';
		next if $column_info->size and $column_info->size > 255;
	
		push @$columns, $column_info->name;
    }

    return $columns;
}

=head2 grid_columns_info

Return array of all columns suitable for grid display with attributes.

=cut
has grid_columns_info => (is => 'lazy');
sub _build_grid_columns_info {
	my ($self) = @_;
	my $grid_columns = [];
	my $columns = $self->grid_columns;
	for my $col (@$columns){
	    my $col_info = $self->column($col)->hashref;
		my %col_copy = %{$col_info};

		# Cleanup for grid
		$col_copy{required} = 0 ;
		$col_copy{readonly} = 0 ;
		$col_copy{primary_key} = 0 ;

		push @$grid_columns, \%col_copy; 		
	}

	
	return $grid_columns; 
}

=head2 form_columns

Returns array of column names appropriate for form

=cut

has form_columns => (is => 'lazy');
sub _build_form_columns {
	my ($self) = @_;
	my $columns = $self->attr('form_columns');
    return $columns if defined $columns;

    for my $column_info ($self->columns){
		# Leave out inappropriate columns
		next if $column_info->hidden;
	
		push @$columns, $column_info->name;
    }

    return $columns;
}

=head2 form_columns_info

Returns array of column objects appropriate for form

=cut

has form_columns_info => (is => 'lazy');
sub _build_form_columns_info {
	my ($self) = @_;
	my $form_columns = [];
	my $columns = $self->form_columns;
	for my $col (@$columns){
	    my $col_info = $self->column($col)->hashref;
		my %col_copy = %{$col_info};

		# Cleanup
		#$col_copy{required} = 0 ;
		
		push @$form_columns, \%col_copy; 		
	}
	
	return $form_columns; 
}

=head2 grid_sort

Return column for default sort

=cut
has grid_sort => (is => 'lazy');
sub _bulid_grid_sort {
	my ($self) = @_;
	return $self->attr('grid_sort');
}

1;
