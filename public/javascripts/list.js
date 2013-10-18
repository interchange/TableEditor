var form_selector = "form.form-search";

$(function() {
	update_grid("");
});

function update_grid(form_id){
	var form = $( form_id + " " +form_selector);
	
	form.attr('action', '#');
	form.submit(function( event ) {
		var container = $(this).closest('div.grid-container');
		$.ajax({
			url: container.attr("data-url"),
			type: "POST",
			data: $(this).serialize(),
			dataType: 'html',
			context: this,
			success: function (data) {
				container.html(data);
				update_grid("#"+container.attr('id'));
			}
		});
		event.preventDefault();
		
	})
	
	// Enter submit
	$(form_id + " " + form_selector + " " + "input").keypress(function(event) {
		var form = $(this).closest("form");
		if (event.which == 13) { // Enter key
			form.submit();
			event.preventDefault();
		}
	});
	
	// Pagination
	$(form_id + " " +".pagination a").click(function(event){
		var container = $(this).closest('div.grid-container');
		$.ajax({
			url: container.attr("data-url")+"?page="+$(this).attr("data-page"),
			type: "POST",
			data: container.find('form').serialize(),
			dataType: 'html',
			context: this,
			success: function (data) {				
				container.html(data);
				update_grid("#"+container.attr('id'));
			}
		});
		event.preventDefault();
	});
}