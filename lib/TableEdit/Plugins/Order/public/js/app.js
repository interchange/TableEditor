'use strict';


//custom_routes['/Order/edit/:id'] = { templateUrl: '/api/plugins/Locator/public/views/speaker-form.html', controller: 'SpeakerEditCtrl' };
custom_routes['/Order/list/:type'] = { templateUrl: '/api/plugins/Order/public/views/list.html', controller: 'OrderListCtrl' };
//custom_routes['/Order/archived'] = { templateUrl: '/api/plugins/Order/public/views/list.html', controller: 'OrderListCtrl' };
custom_routes['/Order/view/:id'] = { templateUrl: '/api/plugins/Order/public/views/order.html', controller: 'OrderEditCtrl' };

var class_name = "Order";

CrudApp.factory('OrderPending', function($resource) { 
	return $resource('api/Order/pending');
});

CrudApp.factory('OrderEdit', function($resource) { 
	return $resource('api/Order/edit');
});

CrudApp.factory('Order', function($resource) { 
	return $resource('api/Order/view');
});

var OrderEditCtrl = function ($scope, $rootScope, $routeParams, $location, Order, OrderEdit) {
	$scope.data = Order.get({ 
		id: $routeParams.id}
	);

	$scope.next = function(action){
		// Delete confirmation
		if(action == 'delete'){
			if(!confirm('Are you sure you want to delete this order?')){
				return 0;
			}
		} 
		
		if($scope.data.next_order){
			OrderEdit.save({
				action: action,
				items: [$routeParams.id],
			},
			// Success
			function(data) {
				$location.path('/Order/view/'+$scope.data.next_order);	
			});
		}
		else {
			
			$location.path('/Order/list/pending');	
		}
	};
};

var OrderListCtrl = function ($scope, $rootScope, $routeParams, Item, OrderPending, Url, OrderEdit) {
	$scope.title = $routeParams.type;
	$scope.types = [{type: 'pending', label: 'Pending'}, {type: 'archived', label: 'Archived'}];
	$scope.reset = function() {
		$scope.search();
	};
	
	$scope.search = function() {  
		
		var q = {};
		if($routeParams.type == 'pending'){
			q.status = {'!=': 'archived'};
		}
		else{
			q.status = $routeParams.type;
		}
		
		$scope.data = OrderPending.get({
			class: class_name,
			q: JSON.stringify(q),
			/*
			sort: $scope.sort_column, 
			descending: $scope.sort_desc ? 1 : 0,
			page: $scope.current_page,
			page_size: $scope.data.page_size,
			*/
			},
			// Success
			function(data) {
				// Pagination
				var page_scope = 5;
				var current_page = $scope.data.page = parseInt($scope.data.page);
				var pages = $scope.data.pages = parseInt($scope.data.pages) ? parseInt($scope.data.pages) : 1;
				var from_page = (current_page - page_scope > 0) ? (current_page - page_scope) : 1;
				var to_page = (current_page + page_scope < pages) ? (current_page + page_scope) : pages;
		
				$scope.page_list = []; 
				for (var i = from_page; i <= to_page; i++) {
					$scope.page_list.push(i);
				}
			},
			// Error
			function(data) {
				alert('Error retrieving '+class_name);
			}
		);
	};
	
	$scope.check = function(target){
		$scope.checked = target; 
		switch(target) {
	    case 'all':
	    	angular.forEach($scope.data.rows, function (item) {
	            item.checked = true;
	        });
	        break;
	    case 'none':
	    	angular.forEach($scope.data.rows, function (item) {
	    		item.checked = false;
	    	});
	    	break;
	    default:
	    	angular.forEach($scope.data.rows, function (item) {
	    		if( target == item.status ){
	    			item.checked = true;
	    		}
	    	});
	        break;
	    
		}
		
	};

	
	$scope.multi = function(action){
		// Delete confirmation
		if(action == 'delete'){
			if(!confirm('Are you sure you want to delete the checked orders?')){
				return 0;
			}
		} 

		// Selected
		var selected = [];
		angular.forEach($scope.data.rows, function (item) {
    		if( item.checked == true ){
    			selected.push(item.orders_id);
    		}
    	});
		
		OrderEdit.save({
			action: action,
			items: selected,
		},
		// Success
		function(data) {
			$scope.reset();
		});
		
	};

	$scope.single = function(action, id){
		// Delete confirmation
		if(action == 'delete'){
			if(!confirm('Are you sure you want to delete this order?')){
				return 0;
			}
		} 
		
		OrderEdit.save({
			action: action,
			items: [id],
		},
		// Success
		function(data) {
			$scope.reset();
		});
	};
	
	$scope.reset();
};

/*
var SidebarCtrl = function ($scope, Menu) {
	$scope.menu = Menu.query();
};
*/