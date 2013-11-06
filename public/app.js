'use strict';

/* App Module */

var crudApp = angular.module('crudApp', [
  'ngRoute',
  'crudControllers'
]);

crudApp.config(['$routeProvider',
 function($routeProvider) {
   $routeProvider.
     when('/', {
       templateUrl: 'list_grid.html',
       controller: 'ContainerCtrl'
     }).
     when('/:class/list', {
       templateUrl: 'list_grid.html',
       controller: 'ContainerCtrl'
     }).
     otherwise({
       redirectTo: '/'
     });
 }]);

crudApp.directive('activeLink', function($location) {
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

crudApp.factory('Class', function($resource) {
    return $resource('/api/:class/list', { class: '@class' }, { update: { method: 'PUT' } });
});



/* Controllers */

var crudControllers = angular.module('crudControllers', []);


crudControllers.controller('SidebarCtrl', [ '$scope', '$http',
                                            function SidebarCtrl($scope, $http) {
	$http.get('/api/menu').success(function(data) {
		$scope.menu = data;
	});
} ]);

crudControllers.controller('ContainerCtrl', [ '$scope', '$http', '$routeParams',
    function MainCtrl($scope, $http, $routeParams) {
	
	$http.get('/api/'+$routeParams.class+'/list').success(function(data) {
		$scope.data = data;
	});
	//$scope.data = Class.query();
	$scope.class = $routeParams.class;
	
} ]);



crudControllers.controller('MainCtrl', [ '$scope', '$http',
    function MainCtrl($scope, $http) {
	/*$http.get('/api/menu').success(function(data) {
		$scope.menu = data;
	});*/
} ]);
