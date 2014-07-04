package TableEdit::Plugins::Order::API;
use Dancer ':syntax';
use POSIX;
use Dancer::Plugin::DBIC qw(schema resultset rset);

prefix '/api';


get '/Order/pending' =>  sub {
	#require TableEdit::Routes::API;
	my $class = 'Orders';
	my $get_params = params('query');
	my $grid_params;		
	# Grid
	my $where = from_json $get_params->{q} if $get_params->{q};
	
	my $rs = schema->resultset('Order');

	my $page = $get_params->{page} || 1;
	my $page_size = 20;
	
	my $objects = $rs->search(
	$where,
	  {
	    page => $page,  # page to return (defaults to 1)
	    rows => $page_size, # number of results per page
	    order_by => 'orders_id',	
	  },);
	my $count = $rs->search($where)->count;

	my $rows;
	for my $row ($objects->all){
		my $columns = {$row->get_columns};
		$columns->{items_count} = $row->orderlines->count;
		$columns->{user} = $row->user->username;
		push @$rows, $columns;
	}

	$grid_params->{rows} = $rows;
	$grid_params->{class} = $class;
	$grid_params->{page} = $page;
	$grid_params->{pages} = ceil($count / $page_size);
	$grid_params->{count} = $count;
	$grid_params->{page_size} = $page_size;
	
	return to_json($grid_params, {allow_unknown => 1});
};


get '/Order/view' => sub {
	my $id = params->{id};
	my $return;
	my $order = schema->resultset('Order')->find($id);
	my $next_order = schema->resultset('Order')->search({
		orders_id => {'>' => $id},
		status => {'!=' => 'archived'},
	},
	{
		order_by => [qw/ orders_id /]
	})->first;
	my $data = {$order->get_columns()};
	$data->{billing_address} = {$order->billing_address->get_columns} if $order->billing_address;
	$data->{shipping_address} = {$order->shipping_address->get_columns} if $order->shipping_address;
	$data->{user} = {$order->user->get_columns} if $order->user;
	$data->{items} = [map {{$_->get_columns}} $order->orderlines] if $order->orderlines;
	$return->{order} = $data;
	$return->{next_order} = $next_order->orders_id if $next_order;
	return to_json $return;
};


post '/Order/edit' => sub {
	my $body = from_json request->body;
	
	if($body->{action} eq 'delete'){
		return 1;
	}
	elsif($body->{action} eq 'ship'){
		for my $item (@{$body->{items}}){
			my $order = schema->resultset('Order')->find($item);
			$order->status('shipped');
			$order->update;
		}
		return 1;
	}
	elsif($body->{action} eq 'archive'){
		for my $item (@{$body->{items}}){
			my $order = schema->resultset('Order')->find($item);
			$order->status('archived');
			$order->update;
		}
		return 1;
	}
	
	return undef;
};


post '/:class' => sub {
	debug "Validating ". params->{class}."...";
	pass;
};

1;
