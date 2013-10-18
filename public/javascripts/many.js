$(document).ready(function(){
	var form = $("#related-list-grid form");
	var model_class = form.attr("data-class");
	form.attr('action', '#');
	form.submit(function( event ) {
		$.post("/grid/"+model_class, form.serialize(), function(data){
	    	$('#related-list-grid table').html(data);  // <------ Here you add rows updated on table
		});
		alert("submited!");
	})
});