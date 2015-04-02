package TableEdit::Routes::API;

use Dancer ':syntax';
use POSIX;

use Digest::SHA qw(sha256_hex);
use Dancer::Plugin::Ajax;
use Dancer::Plugin::DBIC qw(schema resultset rset);
use Dancer::Plugin::Auth::Extensible;
use FindBin;
use Cwd qw/realpath/;
use YAML::Tiny;
use Scalar::Util 'blessed';
use File::Path qw(make_path remove_tree);
use Time::HiRes;

require TableEdit::SchemaInfo;
use TableEdit::Config;
use TableEdit::Menu;
use TableEdit::Session;

# Global variables
my $appdir = TableEdit::Config::appdir();
my $schema_info;

prefix '/api';

# One schema_info instance per user (because of different permissions)
sub schema_info {
	my $username = session('logged_in_user');
	$schema_info->{$username} ||= TableEdit::Menu->new(
        schema => schema,
        sort => 1,
        config => config->{TableEditor},
        user_roles => [user_roles],
        column_types => [TableEdit::Config::column_types()],
	);
	return $schema_info->{$username};
}

any '**' => sub {
	TableEdit::Session::seen();
    
	content_type 'application/json';
	pass;
};

get '/TinyMCE' => sub {
    return {} if ! logged_in_user;
	return to_json schema_info->attr('tiny_mce') || {};
};


get '/:class/:id/:related/list' => require_login sub {
	my $id = param('id');
	my $class_info = schema_info->class(param('class'));
	send_error("Forbidden to read ".param('class'), 403) unless schema_info->permissions->permission('read', $class_info);
	my $related = param('related');
	my $data;

	# Row lookup
	my $row = $class_info->find_with_delimiter(param('id'));
	my $rowInfo = schema_info->row($row);
	
	# Related list
	my $relationship_info = $class_info->relationship($related);
	my $relationship_class_info = schema_info->class($relationship_info->class_name);
	send_error("Forbidden to read ".$relationship_info->class_name, 403) unless schema_info->permissions->permission('read', $relationship_class_info);
	
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
	send_error("Forbidden to read ".param('class'), 403) unless schema_info->permissions->permission('read', $class_info);
	my $related = param('related');
	my $related_id = param('related_id');
	
	my $relationship_info = $class_info->relationship($related);
	my $relationship_class_info = schema_info->class($relationship_info->class_name);
	send_error("Forbidden to read ".$relationship_info->class_name, 403) unless schema_info->permissions->permission('read', $relationship_class_info);
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
        my %subset_values;

        # apply subset conditions from intermediate class
        while (my ($col, $value) = each %{$relationship_info->intermediate_class->subset_conditions}) {
            next if ref($value);
            $subset_values{$col} = $value;
        }

		eval {
            $row->$add_method($related_row, \%subset_values);
        };
		return to_json {'error' => $@->{msg}} if $@;
	}
	return to_json {'added' => 1};
};


del '/:class/:id/:related/:related_id' => require_login sub {
	my $id = param('id');
	my $class_info = schema_info->class(param('class'));
	send_error("Forbidden to read ".param('class'), 403) unless schema_info->permissions->permission('read', $class_info);
	my $related = param('related');
	my $related_id = param('related_id');
	my $relationship_info = $class_info->relationship($related);
	my $relationship_class_info = schema_info->class($relationship_info->class_name);
	send_error("Forbidden to read ".$relationship_info->class_name, 403) unless schema_info->permissions->permission('read', $relationship_class_info);
	
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
	send_error("Forbidden to read ".param('class'), 403) unless schema_info->permissions->permission('read', $class_info);
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
	$data->{id} = $id;
	
	return to_json( $data, {allow_unknown => 1} );
};


get '/:class/:id/:related/unrelated/list' => require_login sub {
	my $id = param('id');
	my $class_info = schema_info->class(param('class'));
	send_error("Forbidden to read ".param('class'), 403) unless schema_info->permissions->permission('read', $class_info);
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
	$data->{id} = $id;
	
	return to_json( $data, {allow_unknown => 1} );
};


get '/:class/:related/list' => require_login sub {
	my $class_info = schema_info->class(param('class'));
	send_error("Forbidden to read ".param('class'), 403) unless schema_info->permissions->permission('read', $class_info);
	my $related = param('related');
	my $relationship_info = $class_info->relationship($related);
	my $relationship_class = $relationship_info->class_name;
	return forward "/api/$relationship_class/list"; 	
};


# Class listing
get '/:class/list' => require_login sub {
	my $class_info = schema_info->class(param('class'));
	send_error("Forbidden to read ".param('class'), 403) unless schema_info->permissions->permission('read', $class_info);
	my $grid_params = grid_template_params($class_info);
	
	return to_json($grid_params, {allow_unknown => 1});
};


get '/:class/autocomplete' => require_login sub {
	my $class_info = schema_info->class(param('class'));
	send_error("Forbidden to read ".param('class'), 403) unless schema_info->permissions->permission('read', $class_info);
	
	my $search_columns = $class_info->search_columns;
	
    # lhs LIKE ?, [ bind_value ]
    my $items = $class_info->resultset->search(
        {
            [
                map {
                    \[
                        "LOWER($_) LIKE ?",
                        [ { dbic_colname => $_ }, '%' . lc param('q') . '%' ]
                     ]
                } @$search_columns

            ]
        },
        { rows => 10 }
    );
	
	my @results;
	for my $item ($items->all){
		my $rowInfo = schema_info->row($item);
		push @results, {label => $rowInfo->to_string, value => $rowInfo->primary_key_string};
	}
	
	return to_json \@results;
};


get '/menu' => require_login sub {    
    return to_json schema_info->menu;
};


get '/:class/:column/image/**' => require_login sub {
	my ($splat) = splat;
	my (undef, $class,$column, undef, @file) = @$splat;
	my $class_info = schema_info->class($class);
	my $column_info = $class_info->column($column);
	my $file = join '/', @file;
	my $path = $column_info->upload_dir;
	return send_file($path.$file);
};


get '/:class/:column/image/:fileid/:filelabel' => require_login sub {
	my $class_info = schema_info->class(param('class'));
	my $column_info = $class_info->column(param('column'));
	my $row = $class_info->find_with_delimiter(param('fileid'));
	my $file_col = $column_info->attr('file_column') || 'file';
	my $file = $row->$file_col;
	return status '404' unless $row;
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


post '/:class/:column/upload' => require_login sub {
	my $class_info = schema_info->class(param('class'));
	my $column_info = $class_info->column(param('column'));
	my $file = upload('file');
	
	
	# Upload dir
	my $path = $column_info->upload_dir; 
	
	# Upload image
    if($file){
		my $fileName = time().'-'.$file->{filename};
		
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
	send_error("Forbidden to read ".param('class'), 403) unless schema_info->permissions->permission('read', $class_info);

	$data->{columns} = $class_info->form_columns_array;
	$data->{columns_info} = $class_info->form_columns_hash;

	# row lookup
	my $row = $class_info->find_with_delimiter(param('id'));
	return status '404' unless $row;
	 
	my $rowInfo = schema_info->row($row);
	$data->{title} = $rowInfo->to_string;
	$data->{id} = $id;
	$data->{class} = $class_info->name;
	$data->{values} = $rowInfo->string_values;
	return to_json($data, {allow_unknown => 1});
};


get '/:class' => require_login sub {
	my $class_info = schema_info->class(param('class'));
	send_error("Forbidden to read ".param('class'), 403) unless schema_info->permissions->permission('read', $class_info);
	my $data = $class_info->attrs;
	$data->{columns} = $class_info->form_columns_array;
	$data->{columns_info} = $class_info->form_columns_hash;
	$data->{class} = $class_info->name;
	$data->{class_label} = $class_info->label;
	$data->{relations} = $class_info->relationships_info;
	$data->{permissions} = $class_info->permissions;
	
	return to_json($data, {allow_unknown => 1}); 
};

# Updating item

post '/:class' => require_login sub {
	my $class_info = schema_info->class(param('class'));
	send_error("Forbidden to update ".param('class'), 403) unless schema_info->permissions->permission('update', $class_info);
	my $body = from_json request->body;
	my $item = $body->{item};

    # empty strings are not allowed for some columns
    my @form_columns = @{$class_info->form_columns_array};

	# Set empty values for empty strings
    for my $col (@form_columns) {
        if (($col->{data_type} eq 'integer' or $col->{data_type} eq 'date' or $col->{data_type} eq 'datetime')
                && $col->{is_nullable}
                && defined $item->{values}->{$col->{name}}
                && length($item->{values}->{$col->{name}}) == 0
            ) {
            delete $item->{values}->{$col->{name}};
        }       
    }

	return to_json {error => 'Please fill the form.'} unless $item->{values} and %{$item->{values}};

    # add subset conditions to item values
    while (my ($col, $value) = each %{$class_info->subset_conditions}) {
        next if ref($value);
        $item->{values}->{$col} = $value;
    }
    debug "Updating item for ".$class_info->name.": ", $item;

	my $object = $class_info->resultset->update_or_create( $item->{values} );
	return to_json {error => 'Unable to save.'} unless  $object;
	my $rowInfo = schema_info->row($object);
	my $object_hash = {
		name => schema_info->row($object)->to_string,
		values => {$object->get_columns},
		id => $rowInfo->primary_key_string,
		new_redirect => $class_info->attr('new_redirect'),
	};
	return to_json ($object_hash,{allow_unknown => 1});
};


del '/:class' => require_login sub {
	my $id = param('id');
	my $class_info = schema_info->class(param('class'));
	send_error("Forbidden to delete ".param('class'), 403) unless schema_info->permissions->permission('delete', $class_info);
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

Returns data for grid view.

Parameters are:

=over 4

=item $class_info

L<TableEdit::ClassInfo> object for class.

=item $related_items

List of related items

=item $grid_rows

Subroutine to retrieve items for grid display.
Defaults to C<grid_rows> function.

=back

=cut

sub grid_template_params {
	my ($class_info, $related_items, $grid_rows) = @_;
	my $get_params = params('query');
	my $grid_params;
	# Permission subset
	my $where = {%{$class_info->subset_conditions}};	
	# Grid
	$grid_params->{column_list} = $class_info->grid_columns_info; 
	my $where_params = from_json $get_params->{q} if $get_params->{q};
	$where = grid_where($class_info, $where, $where_params);
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

	my $make_rows = $grid_rows || \&grid_rows;
	$grid_params->{rows} = $make_rows->(
		[$rows->all], 
		$grid_params->{column_list} , 
		$primary_key,
	);
	$grid_params->{class} = $class_info->name;
	$grid_params->{class_label} = $class_info->label;
	$grid_params->{permissions} = $class_info->permissions;
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
	($get_params->{descending} ? $class_info->sort_direction('-desc') : $class_info->sort_direction('-asc')) if $get_params->{sort};
	# Selected or Predefined sort
	if( $get_params->{sort} and $class_info->column($get_params->{sort})){		
		$class_info->sort_column($get_params->{sort}) ;
	}
	return {$class_info->sort_direction => $class_info->sort_column} if $class_info->sort_column;	
}


=head2 grid_where

Determines conditions for grid search.

Parameters are:

=over 4

=item $class_info

L<TableEdit::ClassInfo> object for class.

=item $where

Hashref with conditions.

=item $params

Column parameters.

=item $alias

Table alias.

=back

=cut

sub grid_where {
	my ($class_info, $where, $params, $alias) = @_;
	$alias ||= 'me';
	my @columns = $class_info->columns;
	for my $column (@columns) {
		# Search
		my $name = $column->{name};
		if( exists $params->{$name}){
			my $condition = $params->{$name};
			$name = $column->{self_column} || $column->{name};
			
			$condition = { '=' => undef } and delete $column->{data_type} if $condition eq '<null>';
			$condition = { '!=' => undef } and delete $column->{data_type} if $condition eq '<notnull>';
			my $sql_name = "$alias.$name";
			
			if ($column->{data_type} and ! ref $condition and ($column->{data_type} eq 'text' or $column->{data_type} eq 'varchar')){
				delete $where->{$sql_name};
				$where->{"LOWER($sql_name)"} = {'-like' => "%".lc $condition."%"} if defined $condition and $condition ne '';
			}
			else { 
				delete $where->{$sql_name};
				$condition = eval $condition;
				$where->{$sql_name} = $condition if defined $condition and $condition ne '';	
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
            my ($value, $rel_name, $rel_class);
            my $column_name = "$column->{name}";

			# Foreign object string
            if ($column->{foreign_column}) {
                $rel_name = $column->{relationship}->{name};
                $value = $row->$rel_name if $rel_name;
            }
            else {
            	
            	# Boolean as yes/no
            	if($column->{'display_type'} eq 'boolean' and defined $row->$column_name){
	            		$value = $row->$column_name eq '1' ? 'Yes' : 'No'; 
            	}
            	else {
	                $value = $row->$column_name;
            	}
            }

            if ( index(ref $value, ref schema) == 0 ){ # If schema object
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
