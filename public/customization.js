'use strict';

/* App Module */
var CrudAppCustom = angular.module('CrudAppCustom', ['ngResource', 'ngRoute'])
//	.config(function($routeProvider) {
//		$routeProvider.
//	     when('/Product/edit/:id', { templateUrl: 'views/product_form.html', controller: 'ProductEditCtrl' }).
//	     otherwise({redirectTo: '/'});
//});
/*


// Controllers


var ProductEditCtrl = function ($scope, $routeParams, $location, Item, ClassItem, $rootScope) {
	$scope.item = Item.get({
		class: 'Product', 
		id: $routeParams.id}
	);
	$scope.data = ClassItem.get({
		class: 'Product',
	},
	// Success
	function(data) {
		$rootScope.breadcrumbs = data.bread_crumbs;
	}
	);
	
	$scope.save = Item.update;
	
	$scope.related = function(){
		var related = this.link.foreign;
		var type = this.link.foreign_type;
		$location.path('/Product/'+$routeParams.id+'/'+related+'/'+type);
	};
};

*/