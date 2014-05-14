'use strict';

alert('Plugin!');

custom_routes = {
		'/Speaker/edit/:id': { templateUrl: 'Locator/public/views/speaker-form.html', controller: 'SpeakerEditCtrl' },
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