'use strict';

/* App Module */

var default_routes = {
	'/': { templateUrl: 'views/login.html', controller: 'StatusCtrl', public: true },
	'/404': { templateUrl: 'views/404.html', controller: 'StatusCtrl', public: true },
	'/login': { templateUrl: 'views/login.html', controller: 'LoginCtrl', public: true },
	'/status': { templateUrl: 'views/status.html', controller: 'StatusCtrl', public: true },
	'/:class/list': { templateUrl: 'views/list.html', controller: 'ListCtrl' },
	'/:class/new': { templateUrl: 'views/form.html', controller: 'CreateCtrl' },
	'/:class/edit/:id': { templateUrl: 'views/form.html', controller: 'EditCtrl' },
	'/:class/:id/new/:related': { templateUrl: 'views/form.html', controller: 'CreateRelatedCtrl' },
	'/:class/:id/:related/belongs_to': { templateUrl: 'views/related.html', controller: 'BelongsToCtrl' },
	'/:class/:id/:related/has_many': { templateUrl: 'views/many.html', controller: 'RelatedListCtrl' },
	'/:class/:id/:related/might_have': { templateUrl: 'views/loading.html', controller: 'MightHaveCtrl' },
	'/:class/:id/:related/many_to_many': { templateUrl: 'views/many.html', controller: 'RelatedListCtrl' },
};

CrudApp.directive('autoComplete', function(Autocomplete) {
    return {
        restrict: 'A',
        link: function(scope, elem, attr, ctrl) {
                    // elem is a jquery lite object if jquery is not present,
                    // but with jquery and jquery ui, it will be a full jquery object.
        	var fclass = scope.column.foreign_class;
        	var col = scope.column;
        	var item = scope.item;
        	var options;
            elem.autocomplete({
            	minLength: 2,
				source: 
					function( request, response ) {
					$.ajax({
						url: "api/"+fclass+"/autocomplete",
						column: col,
						item: item,
						dataType: "json",
						data: {
							q: request.term
						},
						success: function( data ) {
							
	                    	response( data )
						},						
					});
				},
				select: function( event, ui ) {
					item.values[col.name] = ui.item.value;
				
				}
			});
        }
    };
});

CrudApp.directive('checkUser', function ($rootScope, $location, $route, Url, Auth) {
	return {
		link: function (scope, elem, attrs, ctrl, route) {
			$rootScope.$on('$routeChangeStart', function(event, currRoute, prevRoute){
				if(!$rootScope.user && !currRoute.public){
					Auth.login.get({},
						// Success
						function(data) {
							$rootScope.user = {};
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
							$rootScope.user = null;
							$rootScope.logout();
							$location.path('login');
						}
					);
				}
				else{
					if (currRoute.public || $rootScope.user.username ) {
					}
					else {
						Url.login = $location.path();
						$location.path('/');
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

CrudApp.factory('InfoBar', ['$rootScope', '$sce', function ($rootScope, $sce) {
	var types = ['success', 'info', 'warning', 'danger'];
	var add = function (type, message) {
		if (!$rootScope.infoBar[type]) $rootScope.infoBar[type] = '';
		$rootScope.infoBar[type] += '<div>'+message+'</div>';
		window.scrollTo(0, top);
	};
	var addNext = function (type, message) {
		if (!$rootScope.infoBarNext[type]) $rootScope.infoBarNext[type] = '';
		$rootScope.infoBarNext[type] += '<div>'+message+'</div>';
	};
	var set = function (type, message) {
		$rootScope.infoBar[type] = '<div>'+message+'</div>';
	};
	var clear = function (type) {
		if(!type || type == 'all'){
			$.each(types, function( index, type ) {
				$rootScope.infoBar[type] = '';
			});
		}
		else
			$rootScope.infoBar[type] = '';
	};
	var clearAllAndLoadNext = function () {
		$.each(types, function( index, type ) {
			$rootScope.infoBar[type] = $rootScope.infoBarNext[type];
		});
		$rootScope.infoBarNext = {};
	}
	var get = function (type) {
		return $sce.trustAsHtml($rootScope.infoBar[type]);
	};

	return {
		add: add,
		addNext: addNext,
		set: set,
		get: get,
		clear: clear,
		clearAllAndLoadNext: clearAllAndLoadNext,
		types: types,
	};
}]);

CrudApp.factory('Auth', function($resource){
	return {
		login: $resource('login', {}),
		logout: $resource('logout', {}),
	};
	
});

CrudApp.factory('AuthInterceptor',['$q','$location','$rootScope', function($q,$location, $rootScope){
    return {
        response: function(response){
            if (response.status === 403) {
                console.log("Response 403");
            }
            return response || $q.when(response);
        },
        responseError: function(rejection) {
            if (rejection.status === 403) {
            	$rootScope.user = null;
                console.log("Response Error 403",rejection);
            }
            $location.path('/login');
            return $q.reject(rejection);
        }
    }
}]);

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
CrudApp.factory('ActiveUsers', function($resource) {
	return $resource('api/sessions/active',{}, {query: {isArray: false}});
});
CrudApp.factory('RelatedList', function($resource) { 
	return $resource('api/:class/:id/:related/list', { class: '@class' });
});
CrudApp.factory('UnrelatedList', function($resource) { 
	return $resource('api/:class/:id/:related/unrelated/list', { class: '@class' });
});

CrudApp.factory('ClassItem', function($resource) {
	return $resource('api/:class', { class: '@class' });
});
CrudApp.factory('Related', function($resource) {
	return $resource('api/:class/:id/:related/:relationship', { class: '@class', id: '@id', related: '@related', relationship: 'might_have'});
});

CrudApp.factory('Item', function($resource, $location, Url, ClassItem, $route, InfoBar) {
	// var root = $scope;
	return {
		read: $resource('api/:class/:id', { class: '@class', id: '@id' }),

		update: function(){
			var class_name = this.data.class;
			var class_label = this.data.class_label;
			Url.edit = null;
			var item = this.item;
			var create = this.create;
			this.form.submitted = 1;			
			InfoBar.clear();
			
			if(this.form.$invalid){
				InfoBar.add('danger', 'Form has errors!');
				return;
			}
			
			// ClassItem.item
			ClassItem.save({
				class: class_name,
				item: item,
			},
			// Success
			function(data) {
				if(data.error){
					InfoBar.add('danger', 'There has been an error saving '+class_label+'! \n'+data.error);
				}
				else {
					InfoBar.addNext('success', data.name + ' succesfuly saved!');
					var url = Url.edit || "/"+class_name+"/list";
					if (create && data.redirect_after_create == 'item') url = "/"+class_name+"/edit/"+data.id;															 
					
					$location.path(url);							
				}
			},
			// Error
			function() {
				InfoBar.add('danger', 'There has been an error saving '+class_label+'!' );
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
						function(data){
							$('#row-'+id).fadeOut();
						},
						// Error
						function(data) {
							if(data.status == 403){
								InfoBar.add('danger', 'You don\'t have permission to delete '+class_label+'!');
							}
							else {
								InfoBar.add('danger', 'There has been an error deleting '+class_label+'!');
							}
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

CrudApp.factory('Autocomplete', function($resource) {
	return $resource('api/:class/autocomplete');
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
					isArray: false,
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
	
	$routeProvider.otherwise({redirectTo: '/404'});
});

CrudApp.config(['$httpProvider',function($httpProvider) {
    //Http Intercpetor to check auth failures for xhr requests
    $httpProvider.interceptors.push('AuthInterceptor');
}]);


//Controllers



var RelatedListCtrl = function ($scope, $rootScope, $routeParams, $location, ClassItem, RelatedList,  RelatedItem, RelatedItems, Item, Url) {
	$scope.relation = $routeParams.related;
	$scope.related_item = {};
	$scope.related_item.values = {};
	$scope.sort_column = '';
	$scope.data = {};
	$scope.sort_desc = false;
	$scope.current_page = 1;
	$scope.data.page_size;
	$scope.data.page_sizes = [3,7,9, 10, 20];
	$scope.error = {};
	$scope.showRelatedClass = false;
	$scope.showRelated = function () {
		$scope.showRelatedClass = ! $scope.showRelatedClass;
	};

	$scope.item_info = RelatedList.get({
		class: $routeParams.class,
		id: $routeParams.id,
		related: $routeParams.related},
		// Success
		function(data) {
		},
		// Error
		function() {
			$scope.error.msg = 'Error retrieving '+$routeParams.related+' for '+$routeParams.class+' with id '+ $routeParams.id;
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
			$scope.error.msg = 'Error retrieving '+$routeParams.class+' info';
		}
	);

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
			$rootScope.$broadcast('relatedClassReset');
		},
		// Error
		function() {
			InfoBar.add('danger', 'Could not remove item!');
		}
		);
	};

	$scope.del = Item.delete;

	$scope.create = function () {
		Url.edit = $location.path();
		$location.path('/'+$scope.item_info.class+'/'+$scope.item_info.id+'/new/'+$routeParams.related);		
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
			sort: $scope.sort_column ? $scope.sort_column : '', 
			descending: $scope.sort_desc ? 1 : 0,
			page: $scope.current_page,
			page_size: $scope.data.page_size ? $scope.data.page_size : '',
		},
		// Success
		function(data) {
			// Pagination
			var page_scope = 5;
			var current_page = $scope.data.page = parseInt($scope.data.page);
			$scope.data.page_sizes = data.page_sizes;
			var pages = $scope.data.pages = parseInt($scope.data.pages);
			var from_page = (current_page - page_scope > 0) ? (current_page - page_scope) : 1;
			var to_page = (current_page + page_scope < pages) ? (current_page + page_scope) : pages;
			$scope.sort_column = data.sort_column;
			
			$scope.page_list = []; 
			for (var i = from_page; i <= to_page; i++) {
				$scope.page_list.push(i);
			}
		},
		// Error
		function() {
			$scope.error.msg = 'Error retrieving '+$routeParams.related+' for '+$routeParams.class+' with id '+ $routeParams.id;
		}
		);
	};

	$scope.related = Item.related_link;

	$scope.sort = function (ord) {
		if(ord.foreign_column){
			ord = ord.foreign_column;
		}
		else{
			ord = ord.name;
		}
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
	$scope.$on('relatedListReset', function(){ $scope.reset(); });
	
	$scope.reset();
	
};

var BelongsToCtrl = function ($scope, $routeParams, RelatedItem, RelatedClass, $location, ClassItem) {
	$scope.data = ClassItem.get({class: $routeParams.related});
};

var MightHaveCtrl = function ($scope, $routeParams, $location, Item, RelatedList) {
	$scope.error = {};
	
	$scope.item_info = RelatedList.get({
		class: $routeParams.class,
		id: $routeParams.id,
		related: $routeParams.related},
		// Success
		function(data) {
			$scope.item = Item.read.get({
				class: data.related_class, 
				id: data.id
				},		
				// Success
				function(data) {
					$location.path('/'+data.class+'/edit/'+data.id);
				},
				// Error
				function() {
					$location.path('/'+$routeParams.class+'/'+$routeParams.id+'/new/'+$routeParams.related);
				}
			);
		},
		// Error
		function(data) {
			$scope.error.msg = 'Error retrieving '+$routeParams.class+' with id '+ $routeParams.id;
		}
	);
};

var RelatedClassCtrl = function ($scope, $rootScope, $routeParams, RelatedItem, RelatedClass, UnrelatedList, RelatedType, InfoBar) {
	$scope.related_type = RelatedType;
	$scope.sort_column = '';
	$scope.item = {};
	$scope.item.values = {};
	$scope.data = {};
	$scope.sort_desc = false;
	$scope.current_page = 1;
	$scope.page_size;
	$scope.data.page_sizes;

	$scope.sort = function (ord) {
		if(ord.foreign_column){
			ord = ord.foreign_column;
		}
		else{
			ord = ord.name;
		}
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
		var row_id = this.row.id
		
		RelatedItem.add({
			class: $routeParams.class,
			id: $routeParams.id,
			related: $routeParams.related,
			related_id: this.row.id,
		},
		// Success
		function(data) {
			if(data.error) InfoBar.add('danger', data.error);
			$('#row-'+row_id).fadeOut();
			if(data.added) $rootScope.$broadcast('relatedListReset');			
		},
		// Error
		function(data) {
			InfoBar.add('danger', 'Could not add item!');
		}
		);
	};


	$scope.search = function() {    	

		$scope.data = UnrelatedList.get({
			class: $routeParams.class,
			id: $routeParams.id,
			related: $routeParams.related,
			q: JSON.stringify($scope.item.values),
			sort: $scope.sort_column, 
			descending: $scope.sort_desc ? 1 : 0,
			page: $scope.current_page,
			page_size: $scope.data.page_size ? $scope.data.page_size : '',
		},
		// Success
		function(data) {
			// Pagination
			var page_scope = 5;
			$scope.data.page_sizes = data.page_sizes;
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
			$scope.error.msg = 'Error retrieving '+$routeParams.related+' for '+$routeParams.class+ ' information.';
		}
		);
	};
	
	
	$scope.$on('relatedClassReset', function(){ $scope.reset(); });

	$scope.reset();
};



var StatusCtrl = function ($scope, Schema, SchemaCreate, DBConfig, InfoBar) {
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
					$scope.error.msg = 'Error retrieving status data';
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
			InfoBar.add('danger', 'Could not add item!');
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
				$scope.title = "New " + data.class_label;
				angular.forEach($scope.data.columns, function(column, key){							
					if(column.prefill){
						$scope.item.values[column.name] = column.prefill;
					}
				});
			},
			// Error
			function() {
				$scope.error.msg = 'Error retrieving '+$routeParams.class+' information';
			}
	);
	$scope.create = 1;

	$scope.save = Item.update;
};


var CreateRelatedCtrl = function ($scope, $routeParams, ClassItem, RelatedList, Item) {
	$scope.item = {};
	$scope.error = {};
	// related = $routeParams.class;
	
	$scope.item_info = RelatedList.get({
		class: $routeParams.class,
		id: $routeParams.id,
		related: $routeParams.related},
		// Success
		function(data) {
			$scope.title = "New " + data.related_class_label + " for " + data.title;
			$scope.item.values = {};
			$scope.item.values[data.related_column] = data.id;
			$scope.data = ClassItem.get({
					class: data.related_class,
				},
				// Success
				function(classData) {
					// Hide foreign key field
					angular.forEach($scope.data.columns, function(value, key){							
						if(value.name == data.related_column){
							$scope.data.columns[key].hidden = 1
						}
					});
				},
				// Error
				function(classData) {
					$scope.error.msg = 'Error retrieving '+$scope.item_info.related_class;
				}
			);
		},
		// Error
		function() {
			$scope.error.msg = 'Error retrieving '+$routeParams.related+' for '+$routeParams.class+' with id '+ $routeParams.id;
		}
	);
	

	$scope.create = 1;

	$scope.save = Item.update;
};


var EditCtrl = function ($scope, $rootScope, $routeParams, Item, ClassItem, Url, $upload) {
	$scope.error = {};
	$scope.item = Item.read.get({
			class: $routeParams.class, 
			id: $routeParams.id
		},		
		// Success
		function(data) {
		},
		// Error
		function(data) {
			$scope.error.msg = 'Error retrieving '+$routeParams.class+' with id '+$routeParams.id;
		}
	);
	$scope.data = ClassItem.get({class: $routeParams.class},
		// Success
		function(data) {
			// Pagination
			var page_scope = 5;			
			angular.forEach(data.relations, function(value, key){		
				value.foreign_id = $scope.item.values[value.self_column];
				value.id = $scope.item.id;
			});
		},
		// Error
		function(data) {
			$scope.error.msg = 'Error retrieving '+$routeParams.class+' information.';
		}
	);

	$scope.save = Item.update;
	
	var column;
	$scope.onFileSelect = function($files) {
	    //$files: an array of files selected, each file has name, size, and type.
	    for (var i = 0; i < $files.length; i++) {
	      var file = $files[i];
	      column = this.column.name;
	      
	      // File size limit
	      if ( this.column.upload_max_size && file.size > this.column.upload_max_size){
	    	  error; //TODO throw error
	      }
	      // File type limit
	      var re = /(?:\.([^.]+))?$/;
	      var ext = re.exec(file.name)[1];
	      if ( !ext || (this.column.upload_extensions && this.column.upload_extensions.indexOf(ext.toLowerCase()) == -1) ){
	    	  error; //TODO throw error
	      }
	      
	      $scope.upload = $upload.upload({
	        url: 'api/'+this.item.class+'/'+column+'/upload_image',
	        data: {myObj: $scope.myModelObj},
	        file: file, // or list of files: $files for html5 only
	      }).progress(function(evt) {
	        console.log('percent: ' + parseInt(100.0 * evt.loaded / evt.total));
	      }).success(function(data, status, headers, config) {
	        // file is uploaded successfully
	    	$scope.item.values[column] = data;
	    	1;
	      });
	      //.error(...)
	    }
	  };

	$scope.related = Item.related_link;
};


var ListCtrl = function ($scope, $rootScope, $routeParams, $location, Class, ClassItem, Item, Url, InfoBar) {
	// $scope.data = Class.get({class: $routeParams.class});
	$scope.data = {};
	$scope.data.sort_column = '';
	$scope.data.page_size;
	$scope.data.page_sizes;
	$scope.item = {};
	$scope.item.values = {};
	$scope.sort_desc = null;
	$scope.current_page = 1;
	$scope.actions = $scope.actions || 'class_list';
	$scope.error = {};

	$scope.sort = function (ord) {
		if(ord.foreign_column){
			ord = ord.foreign_column;
		}
		else{
			ord = ord.name;
		}
		if ($scope.data.sort_column == ord) { $scope.sort_desc = !$scope.sort_desc; }
		else { $scope.sort_desc = false; }
		$scope.data.sort_column = ord;
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
	$scope.$on('listReset', function(){ $scope.reset()});

	$scope.del = Item.delete;


	$scope.create = function () {
		Url.edit = $location.path();
	};

	$scope.search = function() {    	

		$scope.data = Class.get({
			class: $routeParams.class,
			q: JSON.stringify($scope.item.values),
			sort: $scope.data.sort_column ? $scope.data.sort_column : '', 
			descending: $scope.sort_desc ? 1 : 0,
			page: $scope.current_page,
			page_size: $scope.data.page_size ? $scope.data.page_size : '',
		},
		// Success
		function(data) {
			// Pagination
			var page_scope = 5;
			var current_page = $scope.data.page = parseInt($scope.data.page);
			$scope.data.page_size = data.page_size;
			$scope.data.page_sizes = data.page_sizes;
			var pages = $scope.data.pages = parseInt($scope.data.pages) ? parseInt($scope.data.pages) : 1;
			var from_page = (current_page - page_scope > 0) ? (current_page - page_scope) : 1;
			var to_page = (current_page + page_scope < pages) ? (current_page + page_scope) : pages;
			$scope.data.sort_column = data.sort_column;
			$scope.sort_desc = data.sort_direction == 'DESC' ? true : false;

			$scope.page_list = []; 
			for (var i = from_page; i <= to_page; i++) {
				$scope.page_list.push(i);
			}
		},
		// Error
		function(data) {
			if(data.status == 403){
				$scope.error.msg = 'You don\'t have permission to view '+$routeParams.class+' items.';
			}
			else {
				$scope.error.msg = 'Error retrieving '+$routeParams.class+' items.';
			}
		}
		);
	};

	$scope.reset();
};


var RootCtrl = function ($scope, $rootScope, $interval, Auth, Url, $location, Plugins, ActiveUsers, InfoBar, Menu) {
	$rootScope.infoBar = InfoBar;
	$rootScope.infoBarNext = {};
	$rootScope.menu = Menu.query(); 
	$rootScope.$on("$routeChangeStart", function(scope, next, current){
		InfoBar.clearAllAndLoadNext();
	});
	
	$rootScope.logout = function(){
		Auth.logout.save(
				{},
				// Success
				function(data) {
					$rootScope.menu = {};
					$rootScope.user = null;
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
					loadjscssfile(value.css, "css");
				});
			
			}
		
	);
	
	// Active users
	ActiveUsers.get(
			{},
			// Success
			function(inital_data){
				$rootScope.active = inital_data.users
				if(inital_data.interval > 0){
					$interval(function(){
						ActiveUsers.get({},
								function(data){
							$rootScope.active = data.users;
						});
					}, inital_data.interval*1000);
				}
			}
	);
		
}

var LoginCtrl = function ($scope, $rootScope, $timeout, Auth, Url, $location, Menu, InfoBar) {
	$scope.error = null;

	$rootScope.login = function(){
		$timeout(Auth.login.save(
				{user: {
					// Browser autofill doesn't trigger change so we have to read values with plain js
					username: document.getElementsByName("username")[0].value,
					password: document.getElementsByName("password")[0].value,
					} 
				},
				// Success
				function(data) {
					$rootScope.user = {};
					if (data.username){
						$rootScope.user.roles = data.roles;
						$rootScope.user.username = data.username;
						$rootScope.active = data.active;
						$rootScope.menu = Menu.query();
						$scope.error = null;						
						InfoBar.addNext('success', 'You are logged in as '+data.username+'!');

						if (Url.login == '/' || !Url.login ) Url.login = '/login'; // Redirect to home if last route was login 
						$location.path(Url.login);
					}
					else {
						$rootScope.user = null;
						$scope.error = 'Wrong username or password';
					}
				},
				// Error
				function(data) {
					$scope.error = 'Connection error';
					$rootScope.user = null;
				}
		));
	};


};
