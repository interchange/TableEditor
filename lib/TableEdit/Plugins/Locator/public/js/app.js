'use strict';


custom_routes = {
		'/Speaker/edit/:id': { templateUrl: '/api/plugins/Locator/public/views/speaker-form.html', controller: 'SpeakerEditCtrl' },
		'/Speaker/profile/:id': { templateUrl: '/api/plugins/Locator/public/views/speaker-profile.html', controller: 'SpeakerEditCtrl' },
		};

var SpeakerEditCtrl = function ($scope, $rootScope, $routeParams, Item, ClassItem, Url) {
	$scope.item = Item.read.get({
		class: 'Speaker', 
		id: $routeParams.id}
	);
	$scope.data = ClassItem.get({class: 'Speaker'});

	$scope.save = Item.update;
	$scope.related = Item.related_link;
};