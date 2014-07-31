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

use TableEdit::SchemaInfo;
use TableEdit::Session;
use TableEdit::ClassInfo;

# Global variables
my $appdir = realpath( "$FindBin::Bin/..");
my $menu;
my $schema_info;

prefix '/api';


any '**' => sub {
    # load schema if necessary
    $schema_info ||= TableEdit::SchemaInfo->new(
        schema => schema,
        sort => 1,
	);
	TableEdit::Session::seen();
    
    debug "Route: ", request->uri;

	content_type 'application/json';
	pass;
};


get '/:class/:id/:related/list' => require_login sub {
	my $id = param('id');
	my $class_info = TableEdit::ClassInfo->new(param('class'));
	my $related = param('related');
	my ($row, $data);

	# Row lookup
	$row = $class_info->resultset->find($id);
	
	# Related list
	my $relationship_info = $class_info->relationship($related);
	my $related_items = $row->$related;
	
	return '{}' unless ( defined $row );	
	$data->{'id'} = $id;
	$data->{'class'} = $class_info->name;
	$data->{'related_class'} = $relationship_info->class_name;
	$data->{'related_class_label'} = $relationship_info->label;
	$data->{'related_type'} = $relationship_info->type;
	$data->{'title'} = row_to_string($row);
	
	return to_json $data;
};


post '/:class/:id/:related/:related_id' => require_login sub {
	my $id = param('id');
	my $class_info = TableEdit::ClassInfo->new(param('class'));
	my $related = param('related');
	my $related_id = param('related_id');
	
	my $relationship_info = $class_info->relationship($related);
	my $relationship_class_info = TableEdit::ClassInfo->new($relationship_info->class_name);
	my $related_row = $relationship_class_info->resultset->find($related_id);
	
	my $row = $class_info->resultset->find($id);
	
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
		$row->$add_method($related_row);	
	}
	return 1;
};


del '/:class/:id/:related/:related_id' => require_login sub {
	my $id = param('id');
	my $class_info = TableEdit::ClassInfo->new(param('class'));
	my $related = param('related');
	my $related_id = param('related_id');
	my $relationship_info = $class_info->relationship($related);
	my $relationship_class_info = TableEdit::ClassInfo->new($relationship_info->class_name);
	
	my $row = $class_info->resultset->find($id);
	my $related_row = $relationship_class_info->resultset->find($related_id);
	
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
	my $class_info = TableEdit::ClassInfo->new(param('class'));
	my $related = param('related');
	my ($row, $data);
	my $get_params = params('query') || {};

	my $relationship_info = $class_info->relationship($related);
	my $relationship_class_info = TableEdit::ClassInfo->new($relationship_info->class_name);

	# row lookup
	$row = $class_info->resultset->find($id);
	my $related_items = $row->$related;
	
	# Related bind
	$data = grid_template_params($relationship_class_info, $related_items);
	
	return to_json( $data, {allow_unknown => 1} );
};


get '/:class/:related/list' => require_login sub {
	my $class_info = TableEdit::ClassInfo->new(param('class'));
	my $related = param('related');
	my $relationship_info = $class_info->relationship($related);
	my $relationship_class = $relationship_info->class_name;
	return forward "/api/$relationship_class/list"; 	
};


# Class listing
get '/:class/list' => require_login sub {
	my $class_info = TableEdit::ClassInfo->new(param('class'));
	my $grid_params = grid_template_params($class_info);
	
	return to_json($grid_params, {allow_unknown => 1});
};


get '/menu' => sub {
    if (! $menu) {
        $menu = [
        	map {{name => $_->label, url=> join('/', '#' . $_->name, 'list'),}}	$schema_info->classes,
	    ]
    }
    return to_json $menu;
};


post '/:class/:field/upload_image' => require_login sub {
	my $class = param('class');
	my $class_info = TableEdit::ClassInfo->new(param('class'));
	my $field = param('field');
	my $file = upload('file');
	
	# Upload dir
	my $path = $class_info->source->{_columns}->{$field}->{upload_dir}; 
	$path ||= "images/upload/$class/$field/";
	
	# Upload image
    if($file){
		my $fileName = $file->{filename};
		
		my $dir = "$appdir/public/$path";
		mkdir $dir unless (-e $dir);       
		
		if($file->copy_to($dir.$fileName)){			
			return "/$path$fileName";
		}		
    }
	return undef;
};


get '/:class/:id' => require_login sub {
	my ($data);
	my $id = param('id');
	my $class_info = TableEdit::ClassInfo->new(param('class'));

	$data->{fields} = $class_info->columns_info;

	# row lookup
	my $row = $class_info->resultset->find($id);
	$data->{title} = row_to_string($row);
	$data->{id} = $id;
	$data->{class} = $class_info->name;
	$data->{values} = {$row->get_columns};
	return to_json($data, {allow_unknown => 1});
};


get '/:class' => require_login sub {
	my $class_info = TableEdit::ClassInfo->new(param('class'));

	return to_json({ 
		fields => $class_info->columns_info,
		class => $class_info->name,
		class_label => $class_info->label,
		relations => $class_info->relationships_info,
	}, {allow_unknown => 1}); 
};


post '/:class' => require_login sub {
	my $class_info = TableEdit::ClassInfo->new(param('class'));
	my $body = from_json request->body;
	my $item = $body->{item};

	debug "Updating item for ".$class_info->name.": ", $item;
	
	return $class_info->resultset->update_or_create( $item->{values} );
};


del '/:class' => require_login sub {
	my $id = param('id');
	my $class_info = TableEdit::ClassInfo->new(param('class'));
	my $row = $class_info->resultset->find($id);

    return status '404' unless $row;

	$row->delete;
	return 1;
};

=head1 Fuctions

=head2 row_to_string

Returns string representation of row object

=cut

sub row_to_string {
	my $row = shift;
	return $row->to_string if eval{$row->to_string};
	return "$row" unless eval{$row->result_source};
	my $class = $row->result_source->{source_name};
	my $class_info = TableEdit::ClassInfo->new($class);
	my $pk = $class_info->primary_key;
	my $id = $row->$pk;
	return "$id - ".$class_info->label;
}


sub add_values {
	my ($columns_info, $values) = @_;
	for my $column_info (@$columns_info){
		$column_info->{value} =  $values->{$column_info->{name}}
	}
}


sub grid_template_params {
	my ($class_info, $related_items) = @_;
	my $get_params = params('query');
	my $grid_params;
	my $where = {};	
	# Grid
	$grid_params->{field_list} = $class_info->grid_columns_info; 
	my $where_params = from_json $get_params->{q} if $get_params->{q};
	grid_where($grid_params->{field_list}, $where, $where_params);
	add_values($grid_params->{field_list}, $where_params);
	
	my $rs = $related_items || $class_info->resultset;

	my $primary_column = $class_info->primary_key;
    
	my $page = $get_params->{page} || 1;
	my $page_size = $get_params->{page_size} || config->{TableEditor}->{page_size};
	
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
		$grid_params->{field_list} , 
		$primary_column, 
	);
	
	$grid_params->{class} = $class_info->name;
	$grid_params->{class_label} = $class_info->label;
	$grid_params->{page} = $page;
	$grid_params->{pages} = ceil($count / $page_size);
	$grid_params->{count} = $count;
	$grid_params->{page_size} = $page_size;
	
	return $grid_params;
}


sub grid_sort {
	my ($class_info, $get_params) = @_;
	# Selected or Predefined sort
	my $sort = $get_params->{sort} || $class_info->attributes->{grid_sort};
	# Direction	
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
			else { 
				$where->{"$alias.$name"} = $params->{$name};	
			}
		}
	};
	
}

=head2 grid_rows

Returns a list of database records suitable for the grid display.

=cut

sub grid_rows {
	my ($rows, $columns_info, $primary_column, $args) = @_;

	my @table_rows;

	for my $row (@$rows){
		die 'No primary column' unless $primary_column;
		
		# unravel row
		my $row_inflated = {$row->get_inflated_columns};
		my $id = $row->$primary_column;
		my $row_data = [];

		for my $column (@$columns_info){
			my $column_name = $column->{foreign} ? "$column->{foreign}" : "$column->{name}";
			my $value = $row_inflated->{$column_name};
			$value = row_to_string($value) if blessed($value);
			push @$row_data, {value => $value};
		}

		push @table_rows, {
            row => $row_data,
            id => $id,
            name => row_to_string($row),
            columns => $row_inflated,
        };
	}

	return \@table_rows;
}


true;
