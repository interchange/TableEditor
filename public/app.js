'use strict';

/* App Module */

var CrudApp = angular.module('CrudApp', ['ngResource', 'ngRoute']).
	config(function($routeProvider) {
		$routeProvider.
	     when('/', { templateUrl: 'list_grid.html', controller: 'ContainerCtrl' }).
	     when('/:class/list', { templateUrl: 'list_grid.html', controller: 'ListCtrl' }).
	     when('/:class/new', { templateUrl: 'form.html', controller: 'CreateCtrl' }).
	     otherwise({redirectTo: '/'});
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

CrudApp.factory('Class', function($resource) {
    return $resource('/api/:class/list', { class: '@class' });
});

CrudApp.factory('ClassItem', function($resource) {
	return $resource('/api/:class', { class: '@class' });
});

CrudApp.factory('Menu', function($resource) {
	return $resource('/api/menu');
});


var ContainerCtrl = function ($scope, $routeParams, $location, Class, ClassItem) {
	
}
var CreateCtrl = function ($scope, $routeParams, $location, Class, ClassItem) {
	$scope.item = {};
	$scope.data = ClassItem.get({
		class: $routeParams.class,
		
    	},
    	// Success
    	function(data) {
    		// Pagination	
    		
    	}
	);
	
	$scope.save = function(){
		//var newItem = new ClassItem;
		//newItem.values = this.item;
		//newItem.class = $routeParams.class;
		//newItem.$save();
		
		var item = this.item;
		ClassItem.item
		ClassItem.save({
			class: $routeParams.class,
			item: item,
			testAtt: 'junk'
	    	},
	    	// Success
	    	function(data) {
	    		$location.path('/'+$routeParams.class+'/list');
	    	}
		);
	}
};

var ListCtrl = function ($scope, $routeParams, $location, Class, ClassItem) {
	//$scope.data = Class.get({class: $routeParams.class});
	$scope.sort_column = '';
	$scope.data = {};
	$scope.q = {};
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
    	$scope.reset();
    };
    
    $scope.reset = function () {
        $scope.page = 1;
        $scope.items = [];
        $scope.search();

    };
    $scope.del = function () {
    	if (confirm('Do you realy want to delete '+this.row.id)){
    		var id = this.row.id;
    		ClassItem.delete(
    				{id: id, class: $routeParams.class},
    				// On success
    				function(){
    					$('#row-'+id).fadeOut();
    				}
    		);
    	}
    };
    
    $scope.search = function() {    	
    	
    	$scope.data = Class.get({
    		class: $routeParams.class,
    		q: JSON.stringify($scope.q),
    		sort: $scope.sort_column, 
    		descending: $scope.sort_desc ? 1 : 0,
			page: $scope.current_page,
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
	    	}
		);
    };
    
    $scope.reset();
};

var SidebarCtrl = function ($scope, $location, Menu) {
	$scope.menu = Menu.query();
};

