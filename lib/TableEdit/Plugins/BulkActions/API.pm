package TableEdit::Plugins::BulkActions::API;
use Dancer ':syntax';
use POSIX;
use Dancer::Plugin::DBIC qw(schema resultset rset);
use Dancer::Plugin::Auth::Extensible;
use File::Path qw(make_path remove_tree);
my $appdir = TableEdit::Config::appdir();

sub schema_info {return TableEdit::Routes::API->schema_info;}



prefix '/';
prefix '/api';

get '/bulkUploadImages/:class/:column' => sub {
	my $uploaded_images = session('uploaded_images_temp') || {};
	my $class_info = schema_info->class(param('class'));
	my $column = param('column');
	my @images;
	for my $i (keys %$uploaded_images){
		my $row = $class_info->find_with_delimiter($i);
		push @images, {
			id => $row->id,
			file => $row->$column,
		};
	}
	return to_json {images => \@images};
};

del '/bulkUploadImages/:class/:column' => sub {
	my $uploaded_images = session('uploaded_images_temp') || {};
	
	my $class_info = schema_info->class(param('class'));
	my $column = param('column');
	my $column_info = $class_info->column(param('column'));
	my $media = $class_info->find_with_delimiter(param('id'));	
	my $filename = $media->$column;
	$media->delete;
	my $path = $column_info->upload_dir; 
	my $dir = "$appdir/public/$path";
	unlink $dir.$filename;
	
	delete $uploaded_images->{param('id')};
	session 'uploaded_images_temp' => $uploaded_images;
	return to_json {images => $uploaded_images};
};


post '/bulkUploadImages/:class/:column' => sub {
	my $body = from_json request->body;

	# Add item to list
	if ($body->{add}){
		
		my $filename = $body->{filename};	
		#my $class_info = schema_info->class($body->{class});
		#my $column_info = $class_info->column($body->{column});
		my $session = session->id;
		my $uploaded_images = session('uploaded_images_temp') || {};
		$uploaded_images->{$body->{id}} = {file => $filename, id => $body->{id}};
		session 'uploaded_images_temp' => $uploaded_images;
	}
	
	return 1;
};


get '/bulkUploadImages/temp_image/:file' => require_login sub {
	my $file = param('file');
	my $session = session->id;
	
	# Upload dir
	my $path = "temp_upload/$session/";
    return send_file($path.$file);
};


get '/bulkAssign/:class/list' => require_login sub {
	my $class_info = schema_info->class(param('class'));
	send_error("Forbidden to read ".param('class'), 403) unless schema_info->permissions->permission('read', $class_info);
	
	my $rows = $class_info->resultset->search(
	{},
	  {
	    #page => $page,  # page to return (defaults to 1)
	    #rows => $page_size, # number of results per page
	    #order_by => grid_sort($class_info, $get_params),	
	  },);
	
	my @items;
	while(my $row = $rows->next){
		push @items, {$row->get_columns};
	}
	
	
	return to_json({
		items => \@items
	}
	
	, {allow_unknown => 1});
};


1;
