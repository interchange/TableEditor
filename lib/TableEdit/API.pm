package TableEdit::API;

use Dancer ':syntax';
use POSIX;

use Array::Utils qw(:all);
use Digest::SHA qw(sha256_hex);
use Dancer::Plugin::Ajax;
use Dancer::Plugin::DBIC qw(schema resultset rset);
use Dancer::Plugin::Auth::Extensible;
use FindBin;
use Cwd qw/realpath/;
use YAML::Tiny;
use Scalar::Util 'blessed';

use TableEdit::SchemaInfo;

my $layout = {};
my $dropdown_treshold = 100;
my $page_size = 10;
my $appdir = realpath( "$FindBin::Bin/..");

my $schema_info;

# Compile schema metadata
my $schema = {};

my $field_types;
my $menu;


hook 'before' => sub {
	 my $route_handler = shift;
        var note => 'Hi there';
        
    };

prefix '/api';
any '**' => sub {
	content_type 'application/json';
	pass;
};


get '/:class/:id/:related/list' => require_login sub {
	my $id = params->{id};
	my $class = params->{class};
	my $related = params->{related};
	my ($current_object, $data);
	
	my $relationship_info = $schema->{$class}->{relation}->{$related};
	my $relationship_class = $relationship_info->{class_name};
	# Object lookup
	$current_object = schema->resultset($class)->find($id);
	my $related_items = $current_object->$related;
	
	return '{}' unless ( defined $current_object );	
	$data->{'id'} = $id;
	$data->{'class'} = $class;
	$data->{'related_class'} = $relationship_class;
	$data->{'related_class_label'} = $schema->{$relationship_class}->{label};
	$data->{'related'} = $relationship_info;
	$data->{'related_type'} = $relationship_info->{foreign_type};
	$data->{'title'} = model_to_string($current_object);
	
	return to_json $data;
};


post '/:class/:id/:related/:related_id' => require_login sub {
	my $id = params->{id};
	my $class = params->{class};
	my $related = params->{related};
	my $related_id = params->{related_id};
	
	my $relationship_info = $schema->{$class}->{relation}->{$related};
	my $relationship_class = $relationship_info->{class_name};
	my $related_object = schema->resultset($relationship_class)->find($related_id);
	
	my $object = schema->resultset($class)->find($id);
	
	
	# Has many
	if($relationship_info->{cond}){
		my $column_name;
		for my $cond (keys %{$relationship_info->{cond}}){
			$column_name = [split('\.', "$cond")]->[-1];
			last;
		}		
		$related_object->$column_name($id);
		$related_object->update;
	}
	# Many to Many
	else {
		my $add_method = "add_to_$related"; 
		$object->$add_method($related_object);	
	}
	return 1;
};



del '/:class/:id/:related/:related_id' => require_login sub {
	my $id = params->{id};
	my $class = params->{class};
	my $related = params->{related};
	my $related_id = params->{related_id};
	my $relationship_info = $schema->{$class}->{relation}->{$related};
	my $relationship_class = $relationship_info->{class_name};
	
	my $object = schema->resultset($class)->find($id);
	my $related_object = schema->resultset($relationship_class)->find($related_id);
	
	# Has many
	if($relationship_info->{cond}){ 
		my $column_name;
		for my $cond (keys %{$relationship_info->{cond}}){
			$column_name = [split('\.', "$cond")]->[-1];
			last;
		}		
		$related_object->$column_name(undef);
		$related_object->update;
	}
	# Many to Many
	else {
		my $add_method = "remove_from_$related"; 
		$object->$add_method($related_object);	
	}

	return 1;
};


get '/:class/:id/:related/items' => require_login sub {
	my $id = params->{id};
	my $class = params->{class};
	my $related = params->{related};
	my ($current_object, $data);
	my $get_params = params('query') || {};
	
	my $relationship_info = $schema->{$class}->{relation}->{$related};
	my $relationship_class = $relationship_info->{class_name};
	# Object lookup
	$current_object = schema->resultset($class)->find($id);
	my $related_items = $current_object->$related;
	
	#return to_json '{}' unless ( defined $current_object );	
	# Related bind
	$data = grid_template_params($relationship_class, $get_params, $related_items);
	
	return to_json $data;
};


get '/:class/:related/list' => require_login sub {
	my $class = params->{class};
	my $related = params->{related};
	my $relationship_info = $schema->{$class}->{relation}->{$related};
	my $relationship_class = $relationship_info->{class_name};
	return forward "/api/$relationship_class/list"; 	
};


get '/:class/list' => require_login sub {
	my $class = params->{class};
	my $get_params = params('query');
	my $grid_params;		
	# Grid
	$grid_params = grid_template_params($class, $get_params);
	$grid_params->{'class_label'} = $schema->{$class}->{label};
	
	return to_json($grid_params, {allow_unknown => 1});
};


del '/:class' => require_login sub {
	my $id = params->{id};
	my $class = params->{class};
	my $object = schema->resultset(ucfirst($class))->find($id);
	$object->delete;
	return 1;
};


get '/menu' => sub {
	if (!$menu and eval {schema}){
		$menu = to_json [map {name=> class_label($_), url=>"#/$_/list"}, @{classes()}];
		$field_types = field_types();
		for my $class (@{classes()}){
			($schema->{$class}->{primary}) = schema->source($class)->primary_columns;
			$schema->{$class}->{label} = class_label($class);
			$schema->{$class}->{columns} = class_columns($class);
			$schema->{$class}->{column_info} = columns_static_info($class);
			$schema->{$class}->{relationships} = relationships_info($class);	
			$schema->{$class}->{attributes} = class_source($class)->resultset_attributes;	
		
			for my $related (@{$schema->{$class}->{relationships}}){
				$schema->{$class}->{relation}->{$related->{foreign}} = relationship_info($class, $related->{foreign});	
			}
		}
	}
	
	return $menu;
};


post '/:class' => require_login sub {
	my $class = params->{class};
	my $body = from_json request->body;
	my $item = $body->{item};

	my $rs = schema->resultset(ucfirst($class));
	#$rs->update_or_create( $item->{values} ); 

	return $rs->update_or_create( $item->{values} ); ;
};


get '/:class/:id' => require_login sub {
	my ($data);
	my $id = params->{id};
	my $class = params->{class};
	my $columns = columns_info($class); 
	
	$data->{fields} = $columns;

	# Object lookup
	my $object = schema->resultset(ucfirst($class))->find($id);
	my $object_data = {$object->get_columns};
	$data->{title} = model_to_string($object);
	$data->{id} = $id;
	$data->{class} = $class;
	$data->{values} = $object_data;
	add_values($columns, $object_data, $object);
	
	return to_json($data, {allow_unknown => 1});
};


get '/:class' => require_login sub {
	my (@languages, $errorMessage);
	my $class = params->{class};
	my $columns = columns_info($class, class_form_columns($class)); 
	my $relationships = $schema->{$class}->{relationships};	
	relationships_info($class);

	return to_json({ 
		fields => $columns,
		class => $class,
		class_label => $schema->{$class}->{label},
		relations => $relationships,
	}, {allow_unknown => 1}); 
};

=head1 Fuctions

=head2 model_to_string

Returns string representation of model object

=cut

sub model_to_string {
	my $object = shift;
	return $object->to_string if eval{$object->to_string};
	return "$object" unless eval{$object->result_source};
	my $class = $object->result_source->{source_name};
	my ($pk) = $object->result_source->primary_columns;
	my $id = $object->$pk;
	return "$id - ".class_label($class);
}


=head2 classes

Returns all usable classes (tables that have primary one column key, CRUD requirement)

=cut

sub classes {
	$schema_info ||= TableEdit::SchemaInfo->new(schema => schema);
    return $schema_info->classes_with_single_primary_key;
}


=head2 classes

Returns all classes that have primary key as one column (requirement)

=cut

sub class_source {
	my $class = shift;
	return schema->resultset(ucfirst($class))->result_source;
}


sub class_label {
	my $class = shift;
	my $label = class_source($class)->resultset_attributes->{label};
	return $label if $label;
	$class =~ s/_/ /g;	
	$class =~ s/(?<! )([A-Z])/ $1/g; # Add space in front of Capital leters 
	$class =~ s/^ (?=[A-Z])//; # Strip out extra starting whitespace followed by A-Z
	return $class;
}


=head2 class_columns

Returns plain array of all table columns 

=cut

sub class_columns {
	my $class = shift;
    $schema_info ||= TableEdit::SchemaInfo->new(schema => schema);
    return $schema_info->resultset($class)->columns;
}

sub class_grid_columns {
	my $class = shift;	
	return class_source($class)->resultset_attributes->{grid_columns} if class_source($class)->resultset_attributes->{grid_columns};	
	my $columns = [];
	for my $column (@{class_columns($class)}){
		my $column_info = column_info($class, $column);
		
		# Leave out inappropriate columns
		next if $column_info->{data_type} and $column_info->{data_type} eq 'text';
		next if $column_info->{size} and $column_info->{size} > 255;
		
		push $columns, $column;
	}
	return $columns; 
}

sub class_form_columns {
	my $class = shift;	
	return class_source($class)->resultset_attributes->{form_columns} if class_source($class)->resultset_attributes->{form_columns};	
	my $columns = [];
	for my $column (@{class_columns($class)}){
		#my $column_info = column_info($class, $column);
		
		# Leave out inappropriate columns
		#next if $column_info->{hidden};
		#next if $column_info->{size} and $column_info->{size} > 255;
		
		push $columns, $column;
	}
	return $columns; 
}


=head2 class_columns

Returns array of hashes with metadata for grid of all table columns 

=cut

sub grid_columns_info {
	my ($class) = @_;
	my $default_columns = [];
	my $columns = class_grid_columns($class);
	for my $col (@$columns){
		my $col_info = column_info($class, $col);
		my %col_copy = %{$col_info};

	# Cleanup for grid
		$col_copy{required} = 0 ;
		$col_copy{readonly} = 0 ;
		$col_copy{primary_key} = 0 ;

		push $default_columns, \%col_copy; 		
	}

	
	return $default_columns; 
}


=head2 class_columns

Returns array of hashes with metadata for form of all table columns 

=cut

sub columns_static_info {
	my ($class) = @_;
	my $result_source = class_source($class);
	my $columns = $result_source->columns_info; 
	my $columns_info = {};
	
	for my $relationship($result_source->relationships){
		my $relationship_info = $result_source->relationship_info($relationship);
		my $relationship_class_package = $relationship_info->{class};
		next if $relationship_info->{hidden};
		my $relationship_class = schema->class_mappings->{$relationship_class_package};
		my $count = schema->resultset($relationship_class)->count;
		
		my ($foreign_column, $column_name) = %{$relationship_info->{cond}};
		$foreign_column =~ s/foreign\.//g;
		$column_name =~ s/self\.//g;
		
		my $column_info = $columns->{$column_name};
		$relationship_info->{foreign} = $relationship;
		$relationship_info->{foreign_column} = $foreign_column;

		my $rel_type = $relationship_info->{attrs}->{accessor};
		# Belongs to or Has one
		if( $rel_type eq 'single' or $rel_type eq 'filter' ){
			$relationship_info->{foreign_type} = 'belongs_to' if $rel_type eq 'filter';
			$relationship_info->{foreign_type} = 'might_have' if $rel_type eq 'single';
			
			# Add fk column attributes
			my ($fk_column) = keys %{$relationship_info->{attrs}->{fk_columns}};
			$relationship_info = {%$relationship_info, %{$columns->{$fk_column}}} if $fk_column;
			
			# If there aren't too many related items, make a dropdown
			if ($count <= $dropdown_treshold){
				$relationship_info->{field_type} = 'dropdown';
				
				my @foreign_objects = schema->resultset($relationship_class)->all;
				$relationship_info->{options} = dropdown(\@foreign_objects, $foreign_column );
			}
			 
			column_add_info($column_name, $relationship_info, $class );
			$columns_info->{$column_name} = $relationship_info;
		}
	}
	
	my $selected_columns = class_columns($class);
	for (@$selected_columns){
		my $column_info = $columns->{$_};
		next if $column_info->{is_foreign_key} or $column_info->{hidden};
		column_add_info($_, $column_info, $class);
		
		$columns_info->{$_} = $column_info;
	} 
	
	return $columns_info;
}

sub column_info {
	my ($class, $column) = @_;

    if (exists $schema->{$class}->{column_info}->{$column}) {
        return $schema->{$class}->{column_info}->{$column};
    }
    else {
        my $column_info = columns_static_info($class);
        $schema->{$class}->{column_info}->{$column} = $column_info->{$column};
        return $column_info->{$column};
    }
}

sub columns_info {
	my ($class, $selected_columns) = @_;
	$selected_columns ||= class_columns($class); 
	my $column_info = $schema->{$class}->{column_info};
	my $columns_info = [];
	for my $column(@$selected_columns){
		my $column_info = column_info($class, $column);
		# Belongs to or Has one
		if( defined $column_info->{foreign_type} and ($column_info->{foreign_type} eq 'belongs_to' or $column_info->{foreign_type} eq 'might_have') ){
			my $count = schema->resultset($column_info->{source})->count;
			if ($count <= $dropdown_treshold){
				$column_info->{field_type} = 'dropdown';
				my @foreign_objects = schema->resultset($column_info->{source})->all;
				$column_info->{options} = dropdown(\@foreign_objects, $column_info->{foreign_column});
			}
			else {
				$column_info->{field_type} = 'varchar';
			} 
		}
		push @$columns_info, $column_info;
	}
	return $columns_info;
}


sub relationship_info {
	my ($class, $related) = @_;
	my $result_source = class_source($class);
	my $relationship_info;
	if($result_source->relationship_info($related)){
		$relationship_info = $result_source->relationship_info($related);
	}
	else {
		$relationship_info = $result_source->resultset_attributes->{many_to_many}->{$related};
		$relationship_info->{foreign_type} = 'many_to_many';
	}
	
	my $relationship_class_package = $relationship_info->{class};
	$relationship_info->{class_name} = schema->class_mappings->{$relationship_class_package};
	return $relationship_info;
}


sub relationships_info {
	my ($class) = @_;
	my $result_source = class_source($class);
	my $columns = $result_source->columns_info; 
	my $relationships = [$result_source->relationships];
	my $many_to_manys = $result_source->resultset_attributes->{many_to_many};
	my $relationships_info = [];
	
	for my $many_to_many (keys %$many_to_manys){
		my ($relationship_info);
		$relationship_info->{foreign} = $many_to_many;
		$relationship_info->{foreign_type} = 'many_to_many';
		column_add_info($many_to_many, $relationship_info, $class );
		push $relationships_info, $relationship_info;
	}
	
	for my $relationship(@$relationships){
		my $column_name;
		my $relationship_info = $result_source->relationship_info($relationship);
		my $relationship_class_package = $relationship_info->{class};
		#next unless grep $_ eq $relationship, @$selected_columns;
		next if $relationship_info->{hidden};
		my $relationship_class = schema->class_mappings->{$relationship_class_package};
		my $count = schema->resultset($relationship_class)->count;
		
		for (values $relationship_info->{cond}){
			$column_name ||= [split('\.', "$_")]->[-1];
			last;
		}
		my $column_info = $columns->{$column_name};
		$relationship_info->{foreign} = $relationship;

		my $rel_type = $relationship_info->{attrs}->{accessor};
				
		# Has many
		if( $rel_type eq 'multi' ){
			# Only tables with one PK
			my @pk = schema->source($relationship_class)->primary_columns;
			next unless scalar @pk == 1;
			
			$relationship_info->{foreign_type} = 'has_many';
			
			column_add_info($column_name, $relationship_info, $class );
			push $relationships_info, $relationship_info;
		}
		
	}
	
	return $relationships_info;
}


sub column_add_info {
	my ($column_name, $column_info, $class) = @_;
	
	return undef if $column_info->{hidden};
	
	# Coulumn calculated properties - can be overwritten in model
	$column_info->{field_type} ||= field_type($column_info);
	$column_info->{default_value} = ${$column_info->{default_value}} if ref($column_info->{default_value}) eq 'SCALAR' ;
	$column_info->{original} = undef;
	$column_info->{name} ||= $column_name; # Column database name
	$column_info->{label} ||= $column_info->{foreign} ? label($column_info->{foreign}) : label($column_name); #Human label
	$column_info->{required} ||= required_field($column_info);	
	$column_info->{primary_key} ||= 1 if $column_name eq $schema->{$class}->{primary};	  
	
}


sub required_field {
	my $field_info = shift;
	return 'required' if defined $field_info->{is_nullable} and !defined $field_info->{default_value} and $field_info->{is_nullable} == 0;
	if(defined $field_info->{foreign}){
		return undef if $field_info->{foreign_type} eq 'might_have';
		return 'required' unless defined $field_info->{is_nullable} and $field_info->{is_nullable} != 1;
	}
	return undef;
}


sub add_values {
	my ($columns_info, $values) = @_;
	for my $column_info (@$columns_info){
		$column_info->{value} =  $values->{$column_info->{name}}
	}
}


sub field_type {
	my $field = shift;
	my $data_type = $field->{data_type} || 'varchar';
	$data_type = 'varchar' unless grep( /^$data_type/, @$field_types );
	return $data_type;
}


sub field_types {
	my $dir = $appdir.'/public/views/field';
	my @types;
    opendir(DIR, $dir) or die $!;

    while (my $file = readdir(DIR)) {
        # Use a regular expression to ignore files beginning with a period
        next if ($file =~ m/^\./);
        # remove .html
        $file =~ s/\.html//;
        $file =~ s/\.htm//;
		push @types, $file;
    }
    closedir(DIR);
    return \@types;
}


sub label {
	my $field = shift;
	$field =~ s/_/ /g;	
	$field =~ s/(?<! )([A-Z])/ $1/g; # Add space in front of Capital leters 
	$field =~ s/^ (?=[A-Z])//; # Strip out extra starting whitespace followed by A-Z
	return ucfirst($field);
}


sub dropdown {
	my ($result_set, $column) = @_;
	my $items = [];
	for my $object (@$result_set){
		my $id = $object->$column;
		my $name = model_to_string($object);
		push $items, {option_label=>$name, value=>$id};
	}
	return $items;
}


sub grid_template_params {
	my ($class, $get_params, $related_items) = @_;
	my $grid_params;
	my $where ||= {};	
	# Grid
	$grid_params->{field_list} = grid_columns_info($class); 
	my $where_params = from_json $get_params->{q} if $get_params->{q};
	grid_where($grid_params->{field_list}, $where, $where_params);
	add_values($grid_params->{field_list}, $where_params);
	
	my $rs = $related_items || schema->resultset(ucfirst($class));

	my $primary_column = $schema_info->resultset($class)->primary_key;
    
	my $page = $get_params->{page} || 1;
	$page_size = $get_params->{page_size} if $get_params->{page_size};
	
	my $objects = $rs->search(
	$where,
	  {
	    page => $page,  # page to return (defaults to 1)
	    rows => $page_size, # number of results per page
	    order_by => grid_sort($get_params),	
	  },);
	my $count = $rs->search($where)->count;

	$grid_params->{rows} = grid_rows(
		[$objects->all], 
		$grid_params->{field_list} , 
		$primary_column, 
	);
	
	$grid_params->{class} = $class;
	$grid_params->{page} = $page;
	$grid_params->{pages} = ceil($count / $page_size);
	$grid_params->{count} = $count;
	$grid_params->{page_size} = $page_size;
	
	return $grid_params;
}


sub grid_sort {
	my $get_params = shift;
	my $sort = $get_params->{sort};
	$sort .= $get_params->{descending} ? ' DESC' : '' if $sort;
	return $sort;
}


sub grid_where {
	my ($columns, $where, $params, $alias) = @_;
	$alias ||= 'me';
	for my $field (@$columns) {
		# Search
		my $name = $field->{name};
		if( defined $params->{$name} and $params->{$name} ne '' ){
			if ($field->{data_type} and ($field->{data_type} eq 'text' or $field->{data_type} eq 'varchar')){
				$where->{"LOWER($alias.$name)"} = {'LIKE' => "%".lc($params->{$name})."%"};
			}
			else { #($field->{data_type} eq 'integer' or $field->{data_type} eq 'double')
				$where->{"$alias.$name"} = $params->{$name};	
			}
		}
	};
	
}


sub grid_rows {
	my ($rows, $columns_info, $primary_column, $args) = @_;
	
	my @table_rows; 
	for my $row (@$rows){
		die 'No primary column' unless $primary_column;
		my $id = $row->$primary_column;
		my $row_data = [];
		for my $column (@$columns_info){
			my $column_name = $column->{foreign} ? "$column->{foreign}" : "$column->{name}";
			my $value = $row->$column_name;
			$value = model_to_string($value) if blessed($value);
			push $row_data, {value => $value};
		}
		push @table_rows, {row => $row_data, id => $id, name => model_to_string($row) };
	}
	return \@table_rows;
}

true;
