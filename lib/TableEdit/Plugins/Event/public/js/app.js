'use strict';


//custom_routes['/Event/edit/:id'] = { templateUrl: '/api/plugins/Locator/public/views/speaker-form.html', controller: 'SpeakerEditCtrl' };

var SpeakerEditCtrl = function ($scope, $rootScope, $routeParams, Item, ClassItem, Url) {
	$scope.item = Item.read.get({
		class: 'Speaker', 
		id: $routeParams.id}
	);
	$scope.data = ClassItem.get({class: 'Speaker'});

	$scope.save = Item.update;
	$scope.related = Item.related_link;
};

var SidebarCtrl = function ($scope, Menu) {
	$scope.menu = Menu.query();
};