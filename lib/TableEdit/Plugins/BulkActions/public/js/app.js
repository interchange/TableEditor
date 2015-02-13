'use strict';

custom_routes['/:class/:relationship/bulkImageUpload'] = { templateUrl: 'views/bulk_image_upload.html', controller: 'ImageUploadCtrl' };
custom_routes['/:class/:relationship/bulkAssign'] = { templateUrl: 'views/bulk_assign.html', controller: 'BulkAssignCtrl' };

CrudApp.directive('autoCompleteBulk', function(Autocomplete) {
    return {
        restrict: 'A',
        link: function(scope, elem, attr, ctrl) {
                    // elem is a jquery lite object if jquery is not present,
                    // but with jquery and jquery ui, it will be a full jquery object.
        	var options;
        	var fclass = scope.autocomplete_class;
            elem.autocomplete({
            	minLength: 2,
				source: 
					function( request, response ) {
					$.ajax({
						url: "api/"+scope.autocomplete_class+"/autocomplete",
						dataType: "json",
						data: {
							q: request.term
						},
						success: function( data ) {
							
	                    	response( data )
						},						
					});
				},
				select: scope.selectAutocomplete
			});
        }
    };
});


CrudApp.factory('TempImages', function($resource) { 
	return $resource('api/bulkUploadImages/temp');
});
CrudApp.factory('AssignList', function($resource) { 
	return $resource('api/bulkAssign/:class/list', { class: '@class' });
});



var BulkAssignCtrl = function ($scope, $rootScope, $routeParams, $location, $upload, Class, InfoBar, RelatedItem, ClassItem, Item, Url, UserEdit, RelatedItems,  AssignList) {
	$scope.class = $routeParams.class;
	$scope.relation;
	$scope.assigned = {};
	$scope.data = {};
	$scope.sort_desc = false;
	$scope.current_page = 1;
	$scope.data.page_size;
	
	$scope.search = function() {   
		$scope.data = Class.get({
			class: $routeParams.class,
			q: JSON.stringify({}),
			sort: '', 
			descending: 0,
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
		});
	};
	
	$scope.class_data = ClassItem.get({class: $routeParams.class},
	// Success
	function(data) {
		// Realtion
		for (var i = 0; i < data.relations.length; i++) {
		      if($routeParams.relationship == data.relations[i].name){
		    	  $scope.relation = data.relations[i];
		    	  $scope.autocomplete_class = data.relations[i].class_name;
		      }
		}
	},
	// Error
	function(data) {
		$scope.error.msg = 'Error retrieving '+$routeParams.class+' information.';
	}
	);
	
	$scope.selectAutocomplete = function( event, ui ) {
		if (!$scope.assigned[this.name]) $scope.assigned[this.name] = [];
		$scope.assigned[this.name].push({id: ui.item.value, label: ui.item.label, class: $scope.autocomplete_class});
	    $scope.assign(this.name, ui.item.value);
	    
	    
	    
	};
	
	$scope.assign = function( id, related_id ) { 
	
		RelatedItem.add({
			class: $routeParams.class,
			id: id,
			related: $routeParams.relationship,
			related_id: related_id,
		},
		// Success
		function(data) {
			if(data.error) InfoBar.add('danger', data.error);
		},
		// Error
		function(data) {
			InfoBar.add('danger', 'Could not add item!');
		}
		);
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
	
}


var ImageUploadCtrl = function ($scope, $routeParams, $upload, Class, InfoBar, ClassItem, Item, Url, UserEdit, RelatedItems,  TempImages) {
	$scope.class = $routeParams.class;
	$scope.autocomplete_class = $routeParams.class;
	$scope.assigned = {};
	$scope.data = ClassItem.get({class: $routeParams.class},
			// Success
			function(data) {
				$scope.media_class = data.bulk_image_upload[$routeParams.relationship].media_class;
				$scope.media_column = data.bulk_image_upload[$routeParams.relationship].media_column;
			},
			// Error
			function(data) {
				$scope.error.msg = 'Error retrieving '+$routeParams.class+' information.';
			}
		);

	
	$scope.refresh_media = function(){
		$scope.media = TempImages.get({
			
		});
	}

	$scope.save = Item.update;
	
	var column;
	
	//$scope.media_class = $scope.data.bulk_image_upload[$routeParams.relationship].
	$scope.onImageSelect = function($files) {		
		var media_class_name = $scope.data.bulk_image_upload[$routeParams.relationship].media_class || 'Media';
		var column = $scope.data.bulk_image_upload[$routeParams.relationship].media_column || 'file';
		
	    //$files: an array of files selected, each file has name, size, and type.
	    for (var i = 0; i < $files.length; i++) {
	      var file = $files[i];
	      
	      var filename = file.name;
	      $scope.upload = $upload.upload({
	        url: 'api/'+media_class_name+'/'+column+'/upload',
	        data: {myObj: $scope.myModelObj},
	        file: file, // or list of files: $files for html5 only	        
	      }).progress(function(evt) {
	        console.log('percent: ' + parseInt(100.0 * evt.loaded / evt.total));
	      }).success(function(savedFilename, status, headers, config) {
	    	  // file is uploaded successfully
				var media = ClassItem.save({
					class: media_class_name,
					item: {
						image_upload: 1,
						values: {
							file: savedFilename,
							label: filename,
						}
					},
				}, 
				// Success
				function(media_data) {
					if(media_data.error){
						InfoBar.add('danger', media_data.error);
					}
					else {
						TempImages.save({
							add: 1,
							filename: media_data.values.file,
							class: $scope.data.bulk_image_upload[$routeParams.relationship].media_class,
							column: $scope.data.bulk_image_upload[$routeParams.relationship].media_column, 
						});
						$scope.refresh_media();
					}
				});
			  });
				  //.error(...)
	    }
	};
	
	$scope.assign = function(filename, id){
		var media_class_name = $scope.data.bulk_image_upload[$routeParams.relationship].media_class;
		var intermediate_class_name = $scope.data.bulk_image_upload[$routeParams.relationship].intermediate_class;
		var intermediate_class_id = $scope.data.bulk_image_upload[$routeParams.relationship].intermediate_class_id;
		var intermediate_media_id = $scope.data.bulk_image_upload[$routeParams.relationship].intermediate_media_id;
		
		var media = ClassItem.save({
			class: media_class_name,
			item: {
				image_upload: 1,
				values: {
					file: filename,
				}
			},
		}, 
		// Success
		function(media_data) {
			if(media_data.error){
				InfoBar.add('danger', media_data.error);
			}
			else {
				var values = {};
				values[intermediate_class_id] = id;
				values[intermediate_media_id] = media_data.id;
				var mp = ClassItem.save({
					class: intermediate_class_name,
						item: {values: values}
						
					});
				TempImages.save({
					move: 1,
					filename: media_data.values.file,
					class: $scope.data.bulk_image_upload[$routeParams.relationship].media_class,
					column: $scope.data.bulk_image_upload[$routeParams.relationship].media_column, 
				});
					$scope.refresh_media();
			}
		});
		
	}
	  
	$scope.removeMedia = function(filename) {
		if (confirm('Do you really want to remove '+ filename + '?')){
						
			TempImages.remove({
				filename: filename				
			},
			// Success
			function(data) {
				$('#media-'+filename).fadeOut();
				$scope.refresh_media();
			},
			// Error
			function() {
				InfoBar.add('danger', 'Could not remove item!');
			});
		}  
	};
	
	$scope.selectAutocomplete = function( event, ui ) {
		if (!$scope.assigned[this.name]) $scope.assigned[this.name] = [];
		$scope.assigned[this.name].push({id: ui.item.value, label: ui.item.label, class: $scope.autocomplete_class});
	    $scope.assign(this.name, ui.item.value);
	}

		
	$scope.related = Item.related_link;
	$scope.refresh_media();
	
};