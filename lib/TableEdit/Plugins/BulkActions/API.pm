package TableEdit::Plugins::BulkActions::API;
use Dancer ':syntax';
use POSIX;
use Dancer::Plugin::DBIC qw(schema resultset rset);
use Dancer::Plugin::Auth::Extensible;
use File::Path qw(make_path remove_tree);
my $appdir = TableEdit::Config::appdir();

sub schema_info {
	return TableEdit::Routes::API->schema_info;
}

prefix '/';
prefix '/api';

get '/bulkUploadImages/temp' => sub {
	my $uploaded_images = session('uploaded_images_temp') || {};
	return to_json {images => [map {{file => $_}} keys %$uploaded_images]};
};

del '/bulkUploadImages/temp' => sub {
	my $filename = param('filename');	
	my $uploaded_images = session('uploaded_images_temp') || {};
	my $session = session->id;
	
	my $path = "public/temp_upload/$session/"; 
	my $dir = "$appdir/$path";
	unlink $dir.$filename;
	
	delete $uploaded_images->{$filename};
	session 'uploaded_images_temp' => $uploaded_images;
	return to_json {images => $uploaded_images};
};


post '/bulkUploadImages/temp' => sub {
	my $body = from_json request->body;

	# Add item to list
	if ($body->{add}){
		
		my $filename = $body->{filename};	
		#my $class_info = schema_info->class($body->{class});
		#my $column_info = $class_info->column($body->{column});
		my $session = session->id;
		my $uploaded_images = session('uploaded_images_temp') || {};
		$uploaded_images->{$filename} = 1;
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

=asd
post '/bulkUploadImages/upload_image' => require_login sub {
	my $file = upload('file');
	my $session = session->id;
	
	# Upload dir
	my $path = "public/temp_upload/$session/"; 
	
	# Upload image
    if($file){
		my $fileName = $file->{filename};
		
		my $dir = "$appdir/$path";
		make_path $dir unless (-e $dir);       
		
		if($file->copy_to($dir.$fileName)){			
		    my $uploaded_images = session('uploaded_images_temp') || {};
			$uploaded_images->{$fileName} = 1;
			session 'uploaded_images_temp' => $uploaded_images;
			return "$fileName";
		}		
    }
    
	
	return undef;
};
=cut

1;
