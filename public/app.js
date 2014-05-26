'use strict';

/* App Module */

var default_routes = {
		'/login': { templateUrl: 'views/login.html', controller: 'LoginCtrl', public: true },
		'/status': { templateUrl: 'views/status.html', controller: 'StatusCtrl', public: true },
		'/:class/list': { templateUrl: 'views/list.html', controller: 'ListCtrl' },
		'/:class/new': { templateUrl: 'views/form.html', controller: 'CreateCtrl' },
		'/:class/edit/:id': { templateUrl: 'views/form.html', controller: 'EditCtrl' },
		'/:class/:id/new/:related': { templateUrl: 'views/form.html', controller: 'CreateRelatedCtrl' },
		//'/:class/:id/:related/has_many': { templateUrl: 'views/related.html', controller: 'RelatedListCtrl' },
		//'/:class/:id/:related/might_have': { templateUrl: 'views/form.html', controller: 'EditRelatedCtrl' },
		'/:class/:id/:related/has_many': { templateUrl: 'views/related.html', controller: 'RelatedListCtrl' },
		'/:class/:id/:related/might_have': { templateUrl: 'views/related.html', controller: 'RelatedListCtrl' },
		'/:class/:id/:related/many_to_many': { templateUrl: 'views/many_to_many.html', controller: 'RelatedListCtrl' },
		};

var CrudApp = angular.module('CrudApp', ['ngResource', 'ngRoute']);



CrudApp.directive('checkUser', function ($rootScope, $location, $route, Url, Auth) {
	return {
		link: function (scope, elem, attrs, ctrl, route) {
			$rootScope.$on('$routeChangeStart', function(event, currRoute, prevRoute){
				if(!$rootScope.user){
					$rootScope.user = {};
					Auth.login.get({},
							// Success
							function(data) {
						$rootScope.user.username = data.username; 
						if (currRoute.public || $rootScope.user.username ) {
						}
						else {
							Url.login = $location.path();
							$location.path('login');
						}
					},
					// Error
					function(data) {
						$location.path('login');
					}
					);
				}
				else{
					if (currRoute.public || $rootScope.user.username ) {
					}
					else {
						Url.login = $location.path();
						$location.path('login');
					}
				}
			});
		}
	};
});


CrudApp.directive('activeLink', function($location) {
	var link = function(scope, element, attrs) {
		scope.$watch(function() { return $location.path(); },
				function(path) {
			var url = element.find('a').attr('href');
			if (url) {
				url = url.substring(1);
			}
			if (path == url) {
				element.addClass("active");
			} else {
				element.removeClass('active');
			}
		});
	};
	return {
		restrict: 'A',
		link: link
	};
});
//Factories

CrudApp.factory('Auth', function($resource){
	return {
		login: $resource('login', {}, {method:'POST'}),
		logout: $resource('logout', {}, {method:'POST'}),
	};
});
CrudApp.factory('Plugins', function($resource) { 
	return $resource('api/plugins');
});


CrudApp.factory('Class', function($resource) { 
	return $resource('api/:class/list', { class: '@class' });
});
CrudApp.factory('RelatedClass', function($resource) { 
	return $resource('api/:class/:related/list', { class: '@class', related: '@related' });
});
CrudApp.factory('Schema', function($resource) { 
	return $resource('api/schema',{},{query: {isArray: false}});
});
CrudApp.factory('SchemaCreate', function($resource) { 
	return $resource('api/create_schema',{},{query: {isArray: false}});
});
CrudApp.factory('DBConfig', function($resource) { 
	return $resource('api/db-config', {}, {query: {isArray: false}});
});
CrudApp.factory('RelatedList', function($resource) { 
	return $resource('api/:class/:id/:related/list', { class: '@class' });
});

CrudApp.factory('ClassItem', function($resource) {
	return $resource('api/:class', { class: '@class' });
});
CrudApp.factory('Related', function($resource) {
	return $resource('api/:class/:id/:related/:relationship', { class: '@class', id: '@id', related: '@related', relationship: 'might_have'});
});

CrudApp.factory('Item', function($resource, $location, Url, ClassItem, $route) {
	// var root = $scope;
	return {
		read: $resource('api/:class/:id', { class: '@class', id: '@id' }),

		update: function(){
			var class_name = this.data.class;
			var class_label = this.data.class_label;
			var url = Url.edit;
			var item = this.item;
			// ClassItem.item
			ClassItem.save({
				class: class_name,
				item: item,
			},
			// Success
			function(data) {
				if(data.error){
					alert('There has been an error saving '+class_label+'! '+data.error);
				}
				else {
					$location.path(url);							
				}
			},
			// Error
			function() {
				alert('There has been an error saving '+class_label+'!');
			}
			);
		},

		delete: function () {
			if (confirm('Do you really want to delete '+this.row.name)){
				var id = this.row.id;
				var class_label = this.data.class_label;
				$location.path('/'+this.data.class+'/list');
				ClassItem.delete(
						{id: id, class: this.data.class},
						// On success
						function(){
							$('#row-'+id).fadeOut();
						},
						// Error
						function() {
							alert('There has been an error deleting '+class_label+'!');
						}
				);
			}
		},

		related_link: function(){
			var related = this.link.foreign;
			var type = this.link.foreign_type;
			$location.path('/'+this.item.class+'/'+this.item.id+'/'+related+'/'+type);
		},
	} 
});

CrudApp.factory('Menu', function($resource) {
    return $resource('api/menu');
});


CrudApp.factory("RelatedItems", function($resource){
	return $resource('api/:class/:id/:related/items', { class: '@class' });
});

CrudApp.factory("RelatedItem", function($resource){
	return $resource('api/:class/:id/:related/:related_id', 
			{ class: '@class', id: '@id', related: '@related', related_id: '@related_id' },
			{
				add: {
					method: 'POST',
				},
				remove: {
					method: 'DELETE',
				}
			});

});

CrudApp.factory('RelatedType', function () {
	return { type: "" };
});

CrudApp.factory('Url', function () {
	return { edit: "" };
});


// Routes
CrudApp.config(function($routeProvider) {
	
	angular.forEach(custom_routes, function(value, key){		
		$routeProvider.when(key, value);
	});
	angular.forEach(default_routes, function(value, key){		
		$routeProvider.when(key, value);
	});
	
	$routeProvider.otherwise({redirectTo: '/status'});
});


//Controllers



var RelatedListCtrl = function ($scope, $routeParams, $location, ClassItem, RelatedList,  RelatedItem, RelatedItems, Item, Url) {
	$scope.relation = $routeParams.related;


	$scope.item_info = RelatedList.get({
		class: $routeParams.class,
		id: $routeParams.id,
		related: $routeParams.related},
		// Success
		function(data) {
		},
		// Error
		function() {
			alert('Could not retrieve data!');
		}
	);
	$scope.item = {};
	$scope.item.values = {};


	$scope.class = ClassItem.get({
		class: $routeParams.class,
	},
	// Success
	function(data) {
	},
	// Error
	function() {
		alert('Could not retrieve data!');
	}
	);

	$scope.related_item = {};
	$scope.related_item.values = {};
	$scope.sort_column = '';
	$scope.data = {};
	$scope.sort_desc = false;
	$scope.current_page = 1;
	$scope.data.page_size = 10;




	

	$scope.remove = function(){
		var row_id = this.row.id
		RelatedItem.remove({
			class: $routeParams.class,
			id: $routeParams.id,
			related: $routeParams.related,
			related_id: this.row.id,
		},
		// Success
		function(data) {
			$('#row-'+row_id).fadeOut();
		},
		// Error
		function() {
			alert('Could not remove item!');
		}
		);
	};

	$scope.del = Item.delete;

	$scope.create = function () {
		Url.edit = $location.path();
		$location.path('/'+$scope.item_info.class+'/'+$scope.item_info.id+'/new/'+$scope.item_info.related_class);		
	};


	$scope.edit = function () {
		Url.edit = $location.path();
		var id = this.row.id;
		$location.path('/'+$scope.item_info.related_class+'/edit/'+id);		
	};


	$scope.search = function() {    	
		var query = $scope.item.values ? JSON.stringify($scope.item.values) : '';
		$scope.data = RelatedItems.get({
			class: $routeParams.class,
			id: $routeParams.id,
			related: $routeParams.related,
			q: query,
			sort: $scope.sort_column, 
			descending: $scope.sort_desc ? 1 : 0,
					page: $scope.current_page,
					page_size: $scope.data.page_size,
		},
		// Success
		function(data) {
			// Pagination
			var page_scope = 5;
			var current_page = $scope.data.page = parseInt($scope.data.page);
			var pages = $scope.data.pages = parseInt($scope.data.pages);
			var from_page = (current_page - page_scope > 0) ? (current_page - page_scope) : 1;
			var to_page = (current_page + page_scope < pages) ? (current_page + page_scope) : pages;

			$scope.page_list = []; 
			for (var i = from_page; i <= to_page; i++) {
				$scope.page_list.push(i);
			}
		},
		// Error
		function() {
			alert('Could not retrieve data!');
		}
		);
	};

	$scope.related = Item.related_link;

	$scope.sort = function (ord) {
		if ($scope.sort_column == ord) { $scope.sort_desc = !$scope.sort_desc; }
		else { $scope.sort_desc = false; }
		$scope.sort_column = ord;
		$scope.reset();
	};

	$scope.go_to_page = function (set_page) {
		$scope.current_page = parseInt(set_page);
		$scope.search();
	};
	
	$scope.reset = function () {
		$scope.current_page = 1;
		$scope.items = [];
		$scope.search();

	};
	
	$scope.reset();
	
};


var RelatedClassCtrl = function ($scope, $routeParams, RelatedItem, RelatedClass, RelatedType) {
	$scope.related_type = RelatedType;
	$scope.sort_column = '';
	$scope.item = {};
	$scope.item.values = {};
	$scope.data = {};
	$scope.sort_desc = false;
	$scope.current_page = 1;

	$scope.sort = function (ord) {
		if ($scope.sort_column == ord) { $scope.sort_desc = !$scope.sort_desc; }
		else { $scope.sort_desc = false; }
		$scope.sort_column = ord;
		$scope.reset();
	};

	$scope.go_to_page = function (set_page) {
		$scope.current_page = parseInt(set_page);
		$scope.search();
	};

	$scope.reset = function () {
		$scope.current_page = 1;
		$scope.items = [];
		$scope.search();

	};

	$scope.add = function(){

		RelatedItem.add({
			class: $routeParams.class,
			id: $routeParams.id,
			related: $routeParams.related,
			related_id: this.row.id,
		},
		// Success
		function(data) {
			$scope.reset_items();
		},
		// Error
		function() {
			alert('Could not add item!');
		}
		);
	};


	$scope.search = function() {    	

		$scope.data = RelatedClass.get({
			class: $routeParams.class,
			related: $routeParams.related,
			q: JSON.stringify($scope.item.values),
			sort: $scope.sort_column, 
			descending: $scope.sort_desc ? 1 : 0,
					page: $scope.current_page,
					page_size: $scope.data.page_size,
		},
		// Success
		function(data) {
			// Pagination
			var page_scope = 5;
			var current_page = $scope.data.page = parseInt($scope.data.page);
			var pages = $scope.data.pages = parseInt($scope.data.pages);
			var from_page = (current_page - page_scope > 0) ? (current_page - page_scope) : 1;
			var to_page = (current_page + page_scope < pages) ? (current_page + page_scope) : pages;

			$scope.page_list = []; 
			for (var i = from_page; i <= to_page; i++) {
				$scope.page_list.push(i);
			}
		},
		// Error
		function() {
			alert('Could not retrieve data!');
		}
		);
	};

	$scope.reset();
};
var RelatedItemsCtrl = function ($scope, $routeParams, $location, $rootScope, RelatedItem, RelatedItems, ClassItem, Item) {
	
	
};


var StatusCtrl = function ($scope, Schema, SchemaCreate, DBConfig) {
	check_status();
	function check_status() {
		$scope.schema = Schema.get({},
				function(data) {
			if(data.make_schema == '1'){
				SchemaCreate.get({}, 
						// Success
						function(data){
					$scope.schema.make_schema = null;
					if(data.make_schema_error){
						$scope.schema.schema_error = data.make_schema_error;
					}
					else {
						$scope.schema.schema_created = 1;
					}
				},
				// Error
				function() {
					alert('Could not retrieve data!');
				}
				);
			} 
		});
	}
	
	$scope.submit_config = function(){
		var db = $scope.db;
		DBConfig.save({		
			config: db,
		},
		// Success
		function(data) {
			check_status()
		},
		// Error
		function() {
			alert('Could not add item!');
		}
		);
	};
};


var CreateCtrl = function ($scope, $routeParams, ClassItem, Item) {
	$scope.item = {};
	$scope.item.values = {};
	$scope.data = ClassItem.get(
			{	class: $routeParams.class,   	},
			// Success
			function(data) {
				// Pagination
				;
			},
			// Error
			function() {
				alert('Could not retrieve data!');
			}
	);
	$scope.create = 1;

	$scope.save = Item.update;
};


var CreateRelatedCtrl = function ($scope, $routeParams, ClassItem, Item) {
	$scope.item = {};
	// related = $routeParams.class;
	$scope.item.values = {};
	$scope.item.values[$routeParams.field] = $routeParams.value;

	$scope.data = ClassItem.get({class: $routeParams.related,});
	$scope.create = 1;

	$scope.save = Item.update;
};

var EditRelatedCtrl = function ($scope, $routeParams, ClassItem, Item, Related) {
	$scope.item = {};

	$scope.data = ClassItem.get({class: $routeParams.related});

    $scope.item = Related.get({
		class: $routeParams.class,
		id: $routeParams.id,
		related: $routeParams.related,
        relationship: 'might_have',
    },
		// Success
		function(data) {
		},
		// Error
		function() {
			alert('Could not retrieve data!');
		}
	);

	$scope.save = Item.update;
};

var EditCtrl = function ($scope, $rootScope, $routeParams, Item, ClassItem, Url) {
	$scope.item = Item.read.get({
		class: $routeParams.class, 
		id: $routeParams.id}
	);
	$scope.data = ClassItem.get({class: $routeParams.class});

	$scope.save = Item.update;

	$scope.related = Item.related_link;
};


var ListCtrl = function ($scope, $rootScope, $routeParams, $location, Class, ClassItem, Item, Url) {
	// $scope.data = Class.get({class: $routeParams.class});
	$scope.sort_column = '';
	$scope.data = {};
	$scope.data.page_size = 10;
	$scope.item = {};
	$scope.item.values = {};
	$scope.sort_desc = false;
	$scope.current_page = 1;
	$scope.actions = 'class_list';

	$scope.sort = function (ord) {
		if ($scope.sort_column == ord) { $scope.sort_desc = !$scope.sort_desc; }
		else { $scope.sort_desc = false; }
		$scope.sort_column = ord;
		$scope.reset();
	};

	$scope.go_to_page = function (set_page) {
		$scope.current_page = parseInt(set_page);
		$scope.search();
	};

	$scope.reset = function () {
		$scope.current_page = 1;
		$scope.items = [];
		$scope.search();
	};


	$scope.del = Item.delete;


	$scope.edit = function () {
		var id = this.row.id;
		Url.edit = $location.path();
		$location.path('/'+$routeParams.class+'/edit/'+id);		
	};

	$scope.create = function () {
		Url.edit = $location.path();
	};

	$scope.search = function() {    	

		$scope.data = Class.get({
			class: $routeParams.class,
			q: JSON.stringify($scope.item.values),
			sort: $scope.sort_column, 
			descending: $scope.sort_desc ? 1 : 0,
					page: $scope.current_page,
					page_size: $scope.data.page_size,
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
			alert('Error retrieving '+$routeParams.class);
		}
		);
	};

	$scope.reset();
};


var SidebarCtrl = function ($scope, Menu) {
	$scope.menu = Menu.query();
};


var RootCtrl = function ($scope, $rootScope, Auth, Url, $location, Plugins) {
	$rootScope.logout = function(){
		Auth.logout.save(
				{},
				// Success
				function(data) {
					$rootScope.user = {};
					$location.path('/');
				}
		);
	};
	
	// Load JS from plugins
	$rootScope.javascripts = Plugins.query(
			{},
			// Success
			function(data){
				angular.forEach(data, function(value, key){							
					loadjscssfile(value.js, "js");
				});
			
			}
		
	);
}

var LoginCtrl = function ($scope, $rootScope, Auth, Url, $location) {
	$scope.user = {};
	$scope.error = null;


	$rootScope.login = function(){
		Auth.login.save(
				{user: $scope.user, smth: 1},
				// Success
				function(data) {
					$rootScope.user = {};
					if (data.username){
						$rootScope.user.role = data.role;
						$rootScope.user.username = data.username;
						$scope.error = null;
						$scope.success = 'Successfully logged in as '+data.username;
						$location.path(Url.login);
					}
					else {
						$rootScope.user = {};
						$scope.error = 'Wrong username or password';
					}
				},
				// Error
				function(data) {
					$scope.error = 'Connection error';
					$rootScope.user = {};
				}
		);
	};


};
