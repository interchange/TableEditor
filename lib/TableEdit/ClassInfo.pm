package TableEdit::ClassInfo;

use Moo;
use MooX::Types::MooseLike::Base qw/InstanceOf/;

require TableEdit::ColumnInfo;
require TableEdit::RelationshipInfo;
require Class::Inspector;

use TableEdit::Permissions;

with 'TableEdit::SchemaInfo::Role::Config';
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
    my $columns = $self->columns_info;

    if (exists $columns->{$name}) {
    	return $columns->{$name};
    }
    elsif ( $self->relationship($name) ) {
    	return $self->relationship($name);
    }
	else {
        die "No such columns or has_many relationship named $name.";
	}



}

has columns_info => (is => 'lazy');
sub _build_columns_info { 
    my ($self, $selected_columns) = @_;
    my $columns_info = {};
	
	$selected_columns = [$self->columns] unless $selected_columns;
	
    for my $column_info (@$selected_columns) {

		
		$columns_info->{$column_info->name} = $column_info;
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
        	$rel_info->type ne 'has_many' and
        	$rel_info->type ne 'might_have'
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

		my $column_info = TableEdit::ColumnInfo->new(
            name => $name,
            position => $column_pos{$name},
            class => $self,
            config => $self->config,
            %$info);

		next unless TableEdit::Permissions::permission('read', $column_info );

        $column_hash{$name} = $column_info;
            
    }

    return \%column_hash;
}

=head2 primary_key

Returns primary key(s) for this class.

=cut

sub primary_key {
    my $self = shift;
    my @primary_key;
    @primary_key = $self->source->primary_columns;
	return \@primary_key;    
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
        die $self->name." has no such relationship name <$name>.";
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
    my @relationship_list = $self->attr('relationships') ? @{$self->attr('relationships')} : $source->relationships;
	my $not_found_relastionships;

	# Has many, might have, belongs to
    for my $rel_name (@relationship_list){
        my $rel_info = $source->relationship_info($rel_name);

        unless ($rel_info) {$not_found_relastionships->{$rel_name} = 1; next;};
        next if $rel_info->{hidden};

        # Determine name of class this relationship points to
        my $class_name = $rel_info->{class};
        $class_name =~ s/^(.*?)::Result:://g;

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
            elsif ($rel_info->{attrs}->{is_foreign_key_constraint}) {
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
            config => $self->config,
        );
    }

	# Find and Add many to many relationships
	my $search_str = '__PACKAGE__->many_to_many('; #__PACKAGE__->many_to_many('addresses' => 'user_address', 'address');
	my $search_str_candy = 'many_to_many '; #many_to_many orderlines => "orderlines_shipping", "orderline";
	my $filename = Class::Inspector->resolved_filename( $source->result_class );
	open (my $fh, "<", $filename) or die "cannot open < $filename: $!";
	while (my $row = <$fh>) {
		chomp $row;
		my $index = index $row, $search_str;
		my $index_candy = index $row, $search_str_candy;
		next if ($index == -1 and $index_candy == -1);
		my $rel_info;
		$rel_info = substr $row, $index + length($search_str), index($row, ')') - $index - length($search_str) if $index >= 0;
		$rel_info = substr $row, $index_candy + length($search_str_candy), index($row, ';') - $index_candy - length($search_str_candy) if $index_candy >= 0;
		next unless $rel_info;
		my ($rel_name, $rel, $f_rel) = eval("($rel_info)");

	    my $rel_source_name = $source->relationship_info($rel)->{source};
	    my $rel_source = $source->schema->resultset($rel_source_name)->result_source;
	  	my $class_name = $rel_source->relationship_info($f_rel)->{source};
        $class_name =~ s/\w+:://g;		  		  
        $rel_source_name =~ s/\w+:://g;		  
        if($self->attr('relationships')){
        	next unless $not_found_relastionships->{$rel_name}; 
        }		  
		
		$rel_hash{$rel_name} = TableEdit::RelationshipInfo->new(
            name => $rel_name,
            type => 'many_to_many',
            origin_class => $self,
            class_name => $class_name,
            class => $self->schema->class($class_name),
            intermediate_name => $rel,
            intermediate_relation => $f_rel,
            intermediate_class_name => $rel_source_name,
            intermediate_class => $self->schema->class($rel_source_name),
            config => $self->config,
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

=head2 Page size

Returns number of items per page.

=cut


has page_size => (
	is => 'rw',
	default => sub {
        my $self = shift;
        my $page_size = 10;

        if (defined $self->config->{page_size}) {
            $page_size = $self->config->{page_size};
        }

        return $page_size;
	}
);

=head2 Sort column

Returns name of column to sort by.

=cut


has sort_column => (
	is => 'rw',
	default => sub{
		my $self = shift;
		return $self->attr('grid_sort');
	}
);

=head2 Sort direction

Returns '' as ascending or DESC as descending direction to sort by.

=cut


has sort_direction => (
	is => 'rw',
	default => sub{
		my $self = shift;
		return $self->attr('grid_sort_direction');
	},
);

=head2 attributes

Return attribute value

=cut

sub attr  {
		my ($self, @path) = @_;
		my $value;
		unshift @path, 'classes', $self->name;
		my $node = $self->config;

		for my $p (@path){
			$node = $node->{$p};
			next if defined $node and ref $node eq 'hash';
		}
		return $node if defined $node;
		
		# Schema config
		$node = $self->resultset->result_source->resultset_attributes;
		for my $p (@path){
			$node = $node->{$p};
			next if defined $node and ref $node eq 'hash';
		}

		return $node;
}


=head2 grid_columns

Return array of all column names suitable for grid display.

=cut

sub grid_columns {
	my $self = shift;
    my $columns = $self->attr('grid_columns');
    return $columns if defined $columns;

    for my $column_info ($self->columns){
		# Leave out inappropriate columns
		next if $column_info->data_type and $column_info->data_type eq 'text';
		next if $column_info->attr('size') and $column_info->attr('size') > 255;
	
		push @$columns, $column_info->name;
    }

    return $columns;
}

=head2 grid_columns_info

Return array of all columns suitable for grid display with attributes.

=cut

sub grid_columns_info {
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


sub form_columns {
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

sub form_columns_array {
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

sub form_columns_hash {
	my ($self) = @_;
	my $form_columns = {};
	my $columns = $self->form_columns;
	for my $col (@$columns){
	    my $col_info = $self->column($col)->hashref;
		my %col_copy = %{$col_info};

		# Cleanup
		#$col_copy{required} = 0 ;
		
		$form_columns->{$col} = \%col_copy; 		
	}
	
	return $form_columns; 
}



sub find_with_delimiter {
	my ($self, $value) = @_;
	my $primary_key = $self->primary_key;
	my $primary_key_value;
	my $delimiter = $self->schema->primary_key_delimiter;
	my @values = split $delimiter, $value;
	my $i = 0;	
	for my $value (@values){
		$primary_key_value->{$primary_key->[$i]} = $value;
		$i++;
	}
	#return $primary_key_value;
	return $self->resultset->find($primary_key_value);
	
}

has subset_conditions => (is => 'lazy'); 
sub _build_subset_conditions {
	my ($self) = @_;
	my $conditions = {};
	my $class_column_attrs = $self->attr('columns');
	for my $column (keys %$class_column_attrs){
		my $column_subset = $class_column_attrs->{$column}->{subset};
		next unless $column_subset;
		for my $condition (keys %$column_subset){
			$conditions->{$column} = $condition if role_in($column_subset->{$condition})
		}
	}
	return $conditions;
}

1;
