'use strict';

custom_routes['/:class/:relationship/bulkImageUpload'] = { templateUrl: 'views/bulk_image_upload.html', controller: 'ImageUploadCtrl' };

CrudApp.directive('autoCompleteBulkImageUpload', function(Autocomplete) {
    return {
        restrict: 'A',
        link: function(scope, elem, attr, ctrl) {
                    // elem is a jquery lite object if jquery is not present,
                    // but with jquery and jquery ui, it will be a full jquery object.
        	var fclass = scope.autocomplete_class;
        	var options;
            elem.autocomplete({
            	minLength: 2,
				source: 
					function( request, response ) {
					$.ajax({
						url: "api/"+fclass+"/autocomplete",
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
					if (!scope.assigned[this.name]) scope.assigned[this.name] = [];
					scope.assigned[this.name].push({id: ui.item.value, label: ui.item.label, class: fclass});
				    scope.assign(this.name, ui.item.value);
					
					
				}
			});
        }
    };
});


CrudApp.factory('TempImages', function($resource) { 
	return $resource('api/bulkUploadImages/temp');
});



var ImageUploadCtrl = function ($scope, $rootScope, $routeParams, $location, $upload, Class, InfoBar, ClassItem, Item, Url, UserEdit, RelatedItems,  TempImages) {
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

		
	$scope.related = Item.related_link;
	$scope.refresh_media();
	
};