package TableEdit::Routes::API;

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
use File::Path qw(make_path remove_tree);

require TableEdit::SchemaInfo;
use TableEdit::Session;
use TableEdit::Permissions;

# Global variables
my $appdir = realpath( "$FindBin::Bin/..");
my $schema_info;

prefix '/api';

# One schema_info instance per user (because of different permissions)
sub schema_info {
	my $user = logged_in_user;
	$schema_info->{$user->{user}} = TableEdit::SchemaInfo->new(
        schema => schema,
        sort => 1,
        config => config->{TableEditor},
	);
	return $schema_info->{$user->{user}};
}

any '**' => sub {
	TableEdit::Session::seen();
    
	content_type 'application/json';
	pass;
};


get '/sessions/active' => sub {
	my $active = {interval => schema_info->attr('active_users_interval') || 30};
	return to_json $active unless session('logged_in_user');
	$active->{users} = TableEdit::Session::active_sessions_besides_me;
	return to_json $active;
};


get '/:class/:id/:related/list' => require_login sub {
	my $id = param('id');
	my $class_info = schema_info->class(param('class'));
	send_error("Forbidden to read ".param('class'), 403) unless permission('read', $class_info);
	my $related = param('related');
	my $data;

	# Row lookup
	my $row = $class_info->find_with_delimiter(param('id'));
	my $rowInfo = schema_info->row($row);
	
	# Related list
	my $relationship_info = $class_info->relationship($related);
	my $relationship_class_info = schema_info->class($relationship_info->class_name);
	send_error("Forbidden to read ".$relationship_info->class_name, 403) unless permission('read', $relationship_class_info);
	
	return '{}' unless ( defined $row );	
	$data->{'id'} = $id;
	$data->{'class'} = $class_info->name;
	$data->{'class_label'} = $class_info->label;
	$data->{'related_class'} = $relationship_info->class_name;
	$data->{'related_class_label'} = $relationship_info->class->label;
	$data->{'relationship_label'} = $relationship_info->label;
	$data->{'related_type'} = $relationship_info->type;
	$data->{'related_column'} = $relationship_info->foreign_column;
	$data->{'title'} = $rowInfo->to_string;
	
	return to_json $data;
};


post '/:class/:id/:related/:related_id' => require_login sub {
	my $id = param('id');
	my $class_info = schema_info->class(param('class'));
	send_error("Forbidden to read ".param('class'), 403) unless permission('read', $class_info);
	my $related = param('related');
	my $related_id = param('related_id');
	
	my $relationship_info = $class_info->relationship($related);
	my $relationship_class_info = schema_info->class($relationship_info->class_name);
	send_error("Forbidden to read ".$relationship_info->class_name, 403) unless permission('read', $relationship_class_info);
	my $related_row = $relationship_class_info->find_with_delimiter($related_id);
	
	my $row = $class_info->find_with_delimiter(param('id'));
	
	
	# Has many
	if($relationship_info->cond){
		my $column_name;
		for my $cond (keys %{$relationship_info->cond}){
			$column_name = [split('\.', "$cond")]->[-1];
			last;
		}		
		$related_row->$column_name($id);
		$related_row->update;
	}
	# Many to Many
	else {
		my $add_method = "add_to_$related"; 
		eval {$row->$add_method($related_row)};	
		return to_json {'error' => $@->{msg}} if $@;
	}
	return to_json {'added' => 1};
};


del '/:class/:id/:related/:related_id' => require_login sub {
	my $id = param('id');
	my $class_info = schema_info->class(param('class'));
	send_error("Forbidden to read ".param('class'), 403) unless permission('read', $class_info);
	my $related = param('related');
	my $related_id = param('related_id');
	my $relationship_info = $class_info->relationship($related);
	my $relationship_class_info = schema_info->class($relationship_info->class_name);
	send_error("Forbidden to read ".$relationship_info->class_name, 403) unless permission('read', $relationship_class_info);
	
	my $row = $class_info->find_with_delimiter(param('id'));
	
	my $related_row = $relationship_class_info->find_with_delimiter($related_id);
	
	# Has many
	if($relationship_info->{cond}){ 
		my $column_name;
		for my $cond (keys %{$relationship_info->{cond}}){
			$column_name = [split('\.', "$cond")]->[-1];
			last;
		}		
		$related_row->$column_name(undef);
		$related_row->update;
	}
	# Many to Many
	else {
		my $add_method = "remove_from_$related"; 
		$row->$add_method($related_row);	
	}

	return 1;
};


get '/:class/:id/:related/items' => require_login sub {
	my $id = param('id');
	my $class_info = schema_info->class(param('class'));
	send_error("Forbidden to read ".param('class'), 403) unless permission('read', $class_info);
	my $related = param('related');
	my ($row, $data);
	my $get_params = params('query') || {};

	# row lookup
	$row = $class_info->find_with_delimiter($id);
	my $related_items = $row->$related;

	my $relationship_info = $class_info->relationship($related);
	my $relationship_class_info = schema_info->class($relationship_info->class_name);
	
	# Related bind
	$data = grid_template_params($relationship_class_info, $related_items);
	
	return to_json( $data, {allow_unknown => 1} );
};


get '/:class/:id/:related/unrelated/list' => require_login sub {
	my $id = param('id');
	my $class_info = schema_info->class(param('class'));
	send_error("Forbidden to read ".param('class'), 403) unless permission('read', $class_info);
	my $related = param('related');
	my ($row, $data);
	my $get_params = params('query') || {};

	# row lookup
	$row = $class_info->find_with_delimiter($id);
	my $related_items = $row->$related;

	my $relationship_info = $class_info->relationship($related);
	return to_json {error => 'Not a many to many relationship'} unless $relationship_info->{type} eq 'many_to_many';
	my $relationship_class_info = schema_info->class($relationship_info->class_name);
	my $inter_class_info = schema_info->class($relationship_info->{intermediate_class_name});
	my $inter_relationship_info = $inter_class_info->relationship($relationship_info->{intermediate_relation});

	my $rs = schema->resultset($relationship_info->class_name)->search({
	  $inter_relationship_info->foreign_column => { -not_in => $related_items->get_column($relationship_class_info->primary_key->[0])->as_query },
	});

	# Related bind
	$data = grid_template_params($relationship_class_info, $rs);
	
	return to_json( $data, {allow_unknown => 1} );
};


get '/:class/:related/list' => require_login sub {
	my $class_info = schema_info->class(param('class'));
	send_error("Forbidden to read ".param('class'), 403) unless permission('read', $class_info);
	my $related = param('related');
	my $relationship_info = $class_info->relationship($related);
	my $relationship_class = $relationship_info->class_name;
	return forward "/api/$relationship_class/list"; 	
};


# Class listing
get '/:class/list' => require_login sub {
	my $class_info = schema_info->class(param('class'));
	send_error("Forbidden to read ".param('class'), 403) unless permission('read', $class_info);
	my $grid_params = grid_template_params($class_info);
	
	return to_json($grid_params, {allow_unknown => 1});
};


get '/menu' => require_login sub {    
    return to_json schema_info->menu;
};


get '/:class/:column/image/:file' => require_login sub {
	my $class_info = schema_info->class(param('class'));
	my $column_info = $class_info->column(param('column'));
	my $file = param('file');
	my $path = $column_info->upload_dir;
	return send_file($path.$file);
};

post '/:class/:column/upload_image' => require_login sub {
	my $class_info = schema_info->class(param('class'));
	my $column_info = $class_info->column(param('column'));
	my $file = upload('file');
	
	# Upload dir
	my $path = $column_info->upload_dir; 
	
	# Upload image
    if($file){
		my $fileName = $file->{filename};
		
		my $dir = "$appdir/public/$path";
		make_path $dir unless (-e $dir);       
		
		if($file->copy_to($dir.$fileName)){			
			return "$fileName";
		}		
    }
	return undef;
};


get '/:class/:id' => require_login sub {
	my ($data);
	my $id = param('id');
	my $class_info = schema_info->class(param('class'));
	send_error("Forbidden to read ".param('class'), 403) unless permission('read', $class_info);

	$data->{columns} = $class_info->columns_info;

	# row lookup
	my $row = $class_info->find_with_delimiter(param('id'));
	return status '404' unless $row;
	 
	my $rowInfo = schema_info->row($row);
	$data->{title} = $rowInfo->to_string;
	$data->{id} = $id;
	$data->{class} = $class_info->name;
	$data->{values} = {$row->get_columns};
	return to_json($data, {allow_unknown => 1});
};


get '/:class' => require_login sub {
	my $class_info = schema_info->class(param('class'));
	send_error("Forbidden to read ".param('class'), 403) unless permission('read', $class_info);

	return to_json({
		columns => $class_info->form_columns_info,
		class => $class_info->name,
		class_label => $class_info->label,
		relations => $class_info->relationships_info,
	}, {allow_unknown => 1}); 
};


post '/:class' => require_login sub {
	my $class_info = schema_info->class(param('class'));
	send_error("Forbidden to update ".param('class'), 403) unless permission('update', $class_info);
	my $body = from_json request->body;
	my $item = $body->{item};

	debug "Updating item for ".$class_info->name.": ", $item;
	my $object = $class_info->resultset->update_or_create( $item->{values} );
	return to_json {} unless  $object;
	return to_json {
		name => schema_info->row($object)->to_string,
		values => {$object->get_inflated_columns},
	};
};


del '/:class' => require_login sub {
	my $id = param('id');
	my $class_info = schema_info->class(param('class'));
	send_error("Forbidden to delete ".param('class'), 403) unless permission('delete', $class_info);
	my $row = $class_info->find_with_delimiter(param('id'));

    return status '404' unless $row;

	$row->delete;
	return 1;
};

=head1 Fuctions

=head2 add_values

Adds values to column objects

=cut

sub add_values {
	my ($columns_info, $values) = @_;
	for my $column_info (@$columns_info){
		$column_info->{value} =  $values->{$column_info->{name}}
	}
}


=head2 grid_template_params

Returns data for grid view

=cut

sub grid_template_params {
	my ($class_info, $related_items) = @_;
	my $get_params = params('query');
	my $grid_params;
	# Permission subset
	my $where = $class_info->subset_conditions;	
	# Grid
	$grid_params->{column_list} = $class_info->grid_columns_info; 
	my $where_params = from_json $get_params->{q} if $get_params->{q};
	$where = grid_where($grid_params->{column_list}, $where, $where_params);
	add_values($grid_params->{column_list}, $where_params);
	
	my $rs = $related_items || $class_info->resultset;
	my $primary_key = $class_info->primary_key;
    
	my $page = $get_params->{page} || 1; 
	$class_info->page_size($get_params->{page_size}) if $get_params->{page_size};
	my $page_size = $class_info->page_size;
	
	my $rows = $rs->search(
	$where,
	  {
	    page => $page,  # page to return (defaults to 1)
	    rows => $page_size, # number of results per page
	    order_by => grid_sort($class_info, $get_params),	
	  },);
	my $count = $rs->search($where)->count;

	$grid_params->{rows} = grid_rows(
		[$rows->all], 
		$grid_params->{column_list} , 
		$primary_key,
	);
	
	$class_info->label;
	$class_info->label;
	
	$grid_params->{class} = $class_info->name;
	$grid_params->{class_label} = $class_info->label;
	$grid_params->{page} = $page;
	$grid_params->{pages} = ceil($count / $page_size);
	$grid_params->{count} = $count;
	$grid_params->{page_size} = $page_size;
	$grid_params->{page_sizes} = schema_info->page_sizes;
	$grid_params->{sort_column} = $class_info->sort_column;
	$grid_params->{sort_direction} = $class_info->sort_direction;
	
	return $grid_params;
}


=head2 grid_sort

Returns sql order by parameter.

=cut

sub grid_sort {
	my ($class_info, $get_params) = @_;
	# Direction	
	($get_params->{descending} ? $class_info->sort_direction('DESC') : $class_info->sort_direction('')) if $get_params->{sort};
	# Selected or Predefined sort
	$class_info->sort_column($get_params->{sort}) if $get_params->{sort};
	return $class_info->sort_column . " " . $class_info->sort_direction if $class_info->sort_column;	
}


=head2 grid_where

Sets sql conditions.

=cut

sub grid_where {
	my ($columns, $where, $params, $alias) = @_;
	$alias ||= 'me';
	for my $column (@$columns) {
		# Search
		my $name = $column->{name};
		if( exists $params->{$name}){
			$name = $column->{self_column} || $column->{name};
			
			if ($column->{data_type} and ($column->{data_type} eq 'text' or $column->{data_type} eq 'varchar')){
				my $sql_name = "LOWER($alias.$name)";
				delete $where->{$sql_name};
				$where->{$sql_name} = {'LIKE' => "%".lc($params->{$name})."%"} if defined $params->{$name} and $params->{$name} ne '';
			}
			else { 
				my $sql_name = "$alias.$name";
				delete $where->{$sql_name};
				$where->{$sql_name} = $params->{$name} if defined $params->{$name} and $params->{$name} ne '';	
			}
		}
	};
	return $where;
}

=head2 grid_rows

Returns a list of database records suitable for the grid display.

=cut

sub grid_rows {
	my ($rows, $columns_info, $primary_key) = @_;

	my @table_rows;
	
	for my $row (@$rows){
		die 'No primary column' unless $primary_key;
		my $rowInfo = schema_info->row($row);
		
		# unravel row
		my $row_inflated = {$row->get_columns}; #inflated_
		my $row_data = [];

		for my $column (@$columns_info){
			my $column_name = $column->{foreign} ? "$column->{foreign}" : "$column->{name}";
			my $value = $row->$column_name;
			if( index(ref $value, ref schema) == 0 ){ # If schema object
				$value = schema_info->row($value)->to_string; 
			} 
			elsif ( ref $value ) { # some other object
				$value = $row_inflated->{$column_name};
			}
			push @$row_data, {value => $value};
		}

		push @table_rows, {
            row => $row_data,
            id => $rowInfo->primary_key_string,
            name => $rowInfo->to_string,
            columns => $row_inflated,
        };
	}

	return \@table_rows;
}


true;
