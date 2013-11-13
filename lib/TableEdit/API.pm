package TableEdit::CRUD;

use Dancer ':syntax';
use POSIX;

use Array::Utils qw(:all);
use Digest::SHA qw(sha256_hex);
use Dancer::Plugin::Ajax;

use Dancer::Plugin::DBIC qw(schema resultset rset);
use DBIx::Class::ResultClass::HashRefInflator;
use DBIx::Class::Schema::Loader qw/ make_schema_at /;
use YAML::Tiny;

my $layout = {};
my $as_hash = 'DBIx::Class::ResultClass::HashRefInflator';
my $dropdown_treshold = 100;
my $page_size = 10;

prefix '/api';
any '**' => sub {
	content_type 'application/json';
	pass;
};

get '/schema' => sub {
	my $schema_info = {};
	
	my $db = config->{plugins}->{DBIC}->{default};
	if($db){
		$schema_info->{db_info} = $db;
	}

	if(eval{schema->storage->dbh}){
		if(%{schema->{class_mappings}}){
			$schema_info->{classes} = scalar keys %{schema->{class_mappings}};
		}
		else{
			# Automaticly generate schema
			make_schema_at(
			    $db->{schema_class},
			    { dump_directory => '../lib', debug => 1 },
			    [ $db->{dsn}, $db->{user}, $db->{pass} ],
			);
		}
	}
	else{
		$schema_info->{db_connection} = 0;
	}
	
	if(%{schema->{class_mappings}}){
		$schema_info->{schema} = scalar keys %{schema->{class_mappings}};
	}
	
    # Create a YAML file
    my $yaml = YAML::Tiny->new;

    # Open the config
    my $config_path = '../config.yml';
    $yaml = YAML::Tiny->read( $config_path );

    # Reading properties
    my $db = $yaml->[0]->{plugins}->{DBIC}->{default};
    $db->{dsn} = 'dbi:Pg:dbname=iro;host=localhost;port=8948';
    $db->{options} = {};
    $db->{user} = 'interch';
    $db->{pass} = '94daq2rix';
    $db->{schema_class} = 'TableEdit::Schema';

    # Save the file
    #$yaml->write( $config_path );
	
	$schema_info->{ready} = %{schema->{class_mappings}} ? 1 : 0;
	$schema_info->{db_info}->{pass} = '******';
	
	
	return to_json $schema_info;
};

get '/:class/:id/:related/list' => sub {
	my $id = params->{id};
	my $class = params->{class};
	my $related = params->{related};
	my ($current_object, $data);
	
	my $result_source = schema->resultset(ucfirst($class))->result_source;	
	my $relationship_info = $result_source->relationship_info($related) ? 
		$result_source->relationship_info($related) :
		$result_source->resultset_attributes->{many_to_many}->{$related};
	return '{}' unless ( defined $relationship_info );	
	my $relationship_class_name = $relationship_info->{class};
	my $relationship_class = schema->class_mappings->{$relationship_class_name};
	# Object lookup
	$current_object = schema->resultset($class)->find($id);
	my $related_items = $current_object->$related;
	
	return '{}' unless ( defined $current_object );	
	$data->{'id'} = $id;
	$data->{'class'} = $class;
	$data->{'related_class'} = $relationship_class;
	$data->{'table-title'} = "Search ".$relationship_class;
	$data->{'title'} = "$current_object - $relationship_class";
	
	$data->{bread_crumbs} = [{label=> ucfirst($class), link => "../list"}, {label => $data->{title}}];
	return to_json $data;
};


post '/:class/:id/:related/:related_id' => sub {
	my $id = params->{id};
	my $class = params->{class};
	my $related = params->{related};
	my $related_id = params->{related_id};
	
	my $result_source = schema->resultset(ucfirst($class))->result_source;	
	my $relationship_info = $result_source->relationship_info($related) ? 
		$result_source->relationship_info($related) :
		$result_source->resultset_attributes->{many_to_many}->{$related};
	my $relationship_class_name = $relationship_info->{class};
	my $relationship_class = schema->class_mappings->{$relationship_class_name};
	
	my $object = schema->resultset($class)->find($id);
	my $related_object = schema->resultset($relationship_class)->find($related_id);
	
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


del '/:class/:id/:related/:related_id' => sub {
	my $id = params->{id};
	my $class = params->{class};
	my $related = params->{related};
	my $related_id = params->{related_id};
	
	my $result_source = schema->resultset(ucfirst($class))->result_source;	
	my $relationship_info = $result_source->relationship_info($related) ? 
		$result_source->relationship_info($related) :
		$result_source->resultset_attributes->{many_to_many}->{$related};
	my $relationship_class_name = $relationship_info->{class};
	my $relationship_class = schema->class_mappings->{$relationship_class_name};
	
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


get '/:class/:id/:related/items' => sub {
	my $id = params->{id};
	my $class = params->{class};
	my $related = params->{related};
	my ($current_object, $data);
	my $get_params = params('query') || {};
	
	my $result_source = schema->resultset(ucfirst($class))->result_source;	
	my $relationship_info = $result_source->relationship_info($related) ? 
		$result_source->relationship_info($related) :
		$result_source->resultset_attributes->{many_to_many}->{$related};
	return '{}' unless ( defined $relationship_info );	
	my $relationship_class_name = $relationship_info->{class};
	my $relationship_class = schema->class_mappings->{$relationship_class_name};
	# Object lookup
	$current_object = schema->resultset($class)->find($id);
	my $related_items = $current_object->$related;
	
	return '{}' unless ( defined $current_object );	
	# Related bind
	$data = grid_related_template_params($relationship_class, $related_items, $get_params, \&related_actions);
	
	return to_json $data;
};


get '/:class/list' => sub {
	my $class = params->{class};
	my $get_params = params('query');
	my $grid_params;		
	# Grid
	$grid_params = grid_template_params($class, $get_params);
	
	$grid_params->{default_actions} = 1;
	$grid_params->{'grid_title'} = ucfirst($class)."s";
	
	return to_json $grid_params;
};


del '/:class' => sub {
	my $id = params->{id};
	my $class = params->{class};
	my $object = schema->resultset(ucfirst($class))->find($id);
	$object->delete;
	return 1;
};


get '/menu' => sub {
	return to_json [map {name=> class_label($_), url=>"#/$_/list"}, @{classes()}];;
};


post '/:class' => sub {
	my $class = params->{class};
	my $body = from_json request->body;
	my $item = $body->{item};

	my $rs = schema->resultset(ucfirst($class));
	$rs->update_or_create( $item ); 

	return 1;
};


get '/:class/:id' => sub {
	my ($data);
	my $id = params->{id};
	my $class = params->{class};
	my $all_columns = all_columns($class); 
	my ($columns, $relationships) = columns_and_relationships_info($class);
	
	$data->{fields} = $columns;
	$data->{pk} = $id;

	# Object lookup
	my $object = schema->resultset(ucfirst($class))->find($id);
	my $object_data = {$object->get_columns};
	$data->{title} = "$object";
	$data->{id} = $object_data->{id};
	$data->{values} = $object_data;
	add_values($columns, $object_data, $object);
	
	$data->{bread_crumbs} = [{label=> ucfirst($class), link => "../list"}, {label => $data->{title}}];
	
	return to_json $data;
};


get '/:class' => sub {
	my (@languages, $errorMessage);
	my $class = params->{class};
	my $all_columns = all_columns($class); 
	my ($columns, $relationships) = columns_and_relationships_info($class);	
	
	# Multi
	my $sub_menu = []; 
	for my $relationship(@$relationships){
		next unless $relationship->{foreign_type} and ($relationship->{foreign_type} eq 'has_many');
		push $sub_menu, $relationship;
	}

	return to_json { 
		fields => $columns,
		class => $class,
		sub_menu => $sub_menu,
		bread_crumbs => [{label=> ucfirst($class), link => "list"}, {label=> 'Add'}], 
	}; 
};


sub classes {
	my $classes = [sort values schema->{class_mappings}];
	my $classes_with_pk = [];
	for my $class (@$classes){
		my @pk = schema->source($class)->primary_columns;
		push $classes_with_pk, $class if (@pk == 1);
	}
	return $classes_with_pk;
}


sub class_label {
	my $class = shift;
	$class =~ s/(?<! )([A-Z])/ $1/g; # Search for "(?<!pattern)" in perldoc perlre 
	$class =~ s/^ (?=[A-Z])//; # Strip out extra starting whitespace followed by A-Z
	return $class;
}


sub all_columns {
	my $class = shift;		
	return [schema->resultset(ucfirst($class))->result_source->columns]; 
}


sub grid_columns_info {
	my ($class, $sort) = @_;
	my $defuault_columns = [];
	my ($columns, $relationships) = columns_and_relationships_info(
		$class, 
		schema->resultset(ucfirst($class))->result_source->resultset_attributes->{grid_columns}
	);
	for my $col (@$columns){
		unless (
			($col->{data_type} and $col->{data_type} eq 'text') or
			($col->{size} and $col->{size} > 255)
		){
			$col->{class} = 'selected' if $sort and ($sort eq $_ or $sort eq "$_ desc");
			push $defuault_columns, $col 
		};
	}
	return $defuault_columns; 
}


sub columns_and_relationships_info {
	my ($class, $simple_columns) = @_;
	my $result_source = schema->resultset(ucfirst($class))->result_source;
	my $columns = $result_source->columns_info; 
	my $relationships = [$result_source->relationships];
	my $many_to_manys = $result_source->resultset_attributes->{many_to_many};
	$simple_columns ||= all_columns($class);
	my $columns_info = [];
	my $relationships_info = [];
	
	for my $many_to_many (keys %$many_to_manys){
		my ($relationship_info);
		$relationship_info->{foreign} = $many_to_many;
		$relationship_info->{foreign_type} = 'has_many';
		column_add_info($many_to_many, $relationship_info );
		push $relationships_info, $relationship_info;
	}
	
	for my $relationship(@$relationships){
		my $column_name;
		my $relationship_info = $result_source->relationship_info($relationship);
		my $relationship_class_name = $relationship_info->{class};
		#next unless grep $_ eq $relationship, @$simple_columns;
		next if $relationship_info->{hidden};
		my $relationship_class = schema->class_mappings->{$relationship_class_name};
		my $count = schema->resultset($relationship_class)->count;
		
		for (values $relationship_info->{cond}){
			$column_name ||= [split('\.', "$_")]->[-1];
			last;
		}
		my $column_info = $columns->{$column_name};
		$relationship_info->{foreign} = $relationship;

		my $rel_type = $relationship_info->{attrs}->{accessor};
		# Belongs to
		if( $rel_type eq 'single' or $rel_type eq 'filter' ){
			$relationship_info->{foreign_type} = 'belongs_to';
			if ($count <= $dropdown_treshold){
				$relationship_info->{field_type} = 'dropdown';
				
				my @foreign_objects = schema->resultset($relationship_class)->all;
				$relationship_info->{options} = dropdown(\@foreign_objects);
			}
			else {
				$relationship_info->{field_type} = 'text_field';
			} 
			column_add_info($column_name, $relationship_info );
			push $columns_info, $relationship_info;
		}
		
		# Has many
		elsif( $rel_type eq 'multi' ){
			# Only tables with one PK
			my @pk = schema->source($relationship_class)->primary_columns;
			next unless scalar @pk == 1;
			
			$relationship_info->{foreign_type} = 'has_many';
			
			column_add_info($column_name, $relationship_info );
			push $relationships_info, $relationship_info;
		}
		
	}
	
	for (@$simple_columns){
		my $column_info = $columns->{$_};
		next if $column_info->{is_foreign_key} or $column_info->{hidden};
		column_add_info($_, $column_info);
		
		push $columns_info, $column_info;
	} 
	
	return ($columns_info, $relationships_info);
}


sub column_add_info {
	my ($column_name, $column_info) = @_;
	return undef if $column_info->{hidden};
	$column_info->{field_type} ||= field_type($column_info);
	$column_info->{default_value} = ${$column_info->{default_value}} if ref($column_info->{default_value}) eq 'SCALAR' ;
	$column_info->{original} = undef;
	$column_info->{name} ||= $column_name; # Column database name
	$column_info->{label} ||= label($column_name); #Human label
	$column_info->{$column_info->{field_type}} = 1; # For Flute containers
	$column_info->{required} ||= 'required' if defined $column_info->{is_nullable} and $column_info->{is_nullable} == 0;
	
	# Remove size info if select
	delete $column_info->{size} if $column_info->{field_type} eq 'dropdown';
			
	# Remove not null if checkbox			
	delete $column_info->{is_nullable} if $column_info->{field_type} eq 'checkbox';
			
	return undef if index($column_info->{field_type}, 'timestamp') != -1;
	
}


sub add_values {
	my ($columns_info, $values) = @_;
	
	for my $column_info (@$columns_info){
		my $value = $values->{$column_info->{name}};
		if( $column_info->{options} ){
			next unless $value;
			for my $option (@{ $column_info->{options} }){
				next unless $option->{value};
				if ($option->{value} == $value or $option->{value} eq $value){
					$option->{selected} = 'selected';
				}
			}
		}
		else {
			$column_info->{value} = $value;
		}
	}
	
}


sub field_type {
	my $field = shift;
	my $data_type = $field->{data_type};
	my $field_type = {
		boolean => 'checkbox',
		text => 'text_area',
	}; 
	return (($data_type and $field_type->{$data_type}) ? $field_type->{$data_type} : 'text_field');
}


sub label {
	my $field = shift;
	$field =~ s/_/ /g;	
	return ucfirst($field);
}


sub dropdown {
	my ($result_set, $selected) = @_;
	my $items = [{option_label=>''}];
	for my $object (@$result_set){
		my $id_column = $object->result_source->_primaries->[0];
		my $id = $object->$id_column;
		my $name = "$object";
		push $items, {option_label=>$name, value=>$id};
	}
	return $items;
}


sub clean_values {
	my $values = shift;
	for my $key (keys %$values){
		$values->{$key} = undef if $values->{$key} eq '';
	}
	
}


sub related_search_actions {
	my $id = shift;
	return [
		{name => 'Add', link => "add/$id"}, 
	]
}


sub related_actions {
	my $id = shift;
	return [
		{name => 'Remove', link => "remove/$id"}
	]
}


sub grid_actions {
	my $id = shift;
	return [
		{name => '', link => "edit/$id", css=> 'icon-pencil btn-warning'}, 
		{name => '', link => "delete/$id", css=> 'icon-remove btn-danger'}
	];
}


sub grid_template_params {
	my ($class, $get_params, $actions) = @_;
	my $template_params;
	my $where ||= {};	
	# Grid
	$template_params->{field_list} = grid_columns_info($class, $get_params->{sort});
	my $where_params = from_json $get_params->{q} if $get_params->{q};
	grid_where($template_params->{field_list}, $where, $where_params);
	add_values($template_params->{field_list}, $where_params);
	
	my $rs = schema->resultset(ucfirst($class));
	my ($primary_column) = schema->source(ucfirst($class))->primary_columns;
	my $page = $get_params->{page} || 1;
	my $sort = $get_params->{sort};
	$sort .= ' DESC' if $sort and $get_params->{descending};
	
	my $objects = $rs->search(
	$where,
	  {
	    page => $page,  # page to return (defaults to 1)
	    rows => $page_size, # number of results per page
	    order_by => $sort,
	  },);
	my $count = $rs->search($where)->count;
	  
	unless ( $count ) {
		session error => 'Sorry, no results matching your filter(s). Try altering your filters.';
	}
	
	$template_params->{rows} = grid_rows(
		[$objects->all], 
		$template_params->{field_list} , 
		$primary_column, 
		$actions || \&grid_actions,		
	);
	
	$template_params->{class} = $class;
	$template_params->{page} = $page;
	$template_params->{pages} = ceil($count / $page_size);
	$template_params->{count} = $count;
	$template_params->{page_size} = $page_size;

	return $template_params;
}


sub grid_related_template_params {
	my ($class, $related_items, $get_params, $actions) = @_;
	my $template_params;
	my $where ||= {};	
	# Grid
	my $columns_info = grid_columns_info($class, $get_params->{sort});
	grid_where($columns_info, $where, $get_params, $related_items->{attrs}->{alias});
	add_values($columns_info, $get_params);
	
	my ($primary_column) = schema->source(ucfirst($class))->primary_columns;
	my $page = $get_params->{page} || 1;
	
	my $objects = $related_items->search(	
	$where,
	  {
	    page => $get_params->{page},  # page to return (defaults to 1)
	    rows => $page_size, # number of results per page
	    order_by => $get_params->{sort},
	  }
	  ,);
	my $count = $related_items->search($where)->count;
	  
	unless ( $count ) {
		session error => 'Sorry, no results matching your filter(s). Try altering your filters.';
	}
	
	$template_params->{rows} = grid_rows(
		[$objects->all], 
		$columns_info, 
		$primary_column, 
		$actions || \&grid_actions,		
	);
	
	$template_params->{class} = $class;
	$template_params->{page} = $page;
	$template_params->{pages} = ceil($count / $page_size);
	$template_params->{count} = $count;
	$template_params->{page_size} = $page_size;
	
	return $template_params;
}


sub grid_where {
	my ($columns, $where, $params, $alias) = @_;
	$alias ||= 'me';
	for my $field (@$columns) {
		# Search
		my $name = $field->{name};
		if( $params->{$name} ){
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
	my ($rows, $columns_info, $primary_column, $actions_function, $args) = @_;
	
	my @table_rows; 
	for my $row (@$rows){
		die 'No primary column' unless $primary_column;
		my $id = $row->$primary_column;
		my $row_data = [];
		for my $column (@$columns_info){
			my $column_name = $column->{foreign} ? "$column->{foreign}" : "$column->{name}";
			my $value = $row->$column_name;
			$value = "$value" if $value;
			push $row_data, {value => $value};
		}
		my $actions = $actions_function ? $actions_function->($id) : undef;
		push @table_rows, {row => $row_data, id => $id, actions => $actions };
	}
	return \@table_rows;
}

true;