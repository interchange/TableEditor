var CRUD = angular.module('CRUD', ['ngRoute']);

CRUD.controller('MainCtrl', [ '$scope', '$http',
		function MainCtrl($scope, $http) {

			$http.get('/api/Wishlist/list').success(function(data) {
				$scope.data = data;
			});

			$scope.orderProp = 'age';

		} ]);

CRUD.controller('SidebarCtrl', [ '$scope', '$http',
    function SidebarCtrl($scope, $http) {
		$http.get('/api/menu').success(function(data) {
			$scope.menu = data;
		});
} ]);
