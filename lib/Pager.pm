package Pager;

use Dancer ':syntax';
use POSIX;
use Data::Dumper;
use HTML::Entities;


sub new {
	my $type = shift;
	my %params = @_;
	
	# Default values
	$params{pageSize} ||= 10;
	$params{pageScope} ||= 5;
	$params{url} ||= '';
	
	my $self = \%params;
	bless $self, 'Pager';
	
	return $self;
}

sub getHtml{
	my ($self, $currentPage, $itemsCount, $options) = @_;
	my ($links, $fromPage, $toPage);
	
	# Default values
	$currentPage ||= 0;
	$itemsCount ||= 0;
	
	# Number of pages
	my $pages = ceil($itemsCount / $self->{pageSize});			
	
	# No pagging if only one page
	return '' if $pages < 2;
	
	# URL params passed
	my $params = { %{$options->{url_params}}} if ( $options->{url_params} and ref($options->{url_params}) eq 'HASH' ); 
	
	# Scope	
	my $scope = $self->{pageScope};
	$fromPage = ($currentPage - $scope > 0) ? ($currentPage - $scope) : 1;
	$toPage = ($currentPage + $scope < $pages) ? ($currentPage + $scope) : $pages;
	
	# Previous
	if( $params ){
		$params->{page} = $currentPage-1;
		$links .= '<li class="previous"><a data-page="'.$params->{page}.'" href="'. encode_entities(request->uri_for($self->{url}, $params)) .'">Previous</a></li>' if $currentPage > 1;
	} 
	else {
		$links .= '<li class="previous"><a data-page="'.$params->{page}.'" href="'.$self->{url}.'page/'.($currentPage-1).'">Previous</a></li>' if $currentPage > 1;
	}
	
	# 1 2 3 4 
	for (my $count=$fromPage; $count <= $toPage; $count++) {
		my $selected = '';
		if($count == $currentPage){
	 		$selected = ' class="selected" ';
		}		
		if( $params ){
			$params->{page} = $count;
			$links .= '<li class="page'.$count.'link"><a data-page="'.$count.'" '.$selected.' href="'. encode_entities(request->uri_for($self->{url}, $params)) .'">'.$count.'</a></li>';
		} 
		else {
			$links .= '<li class="page'.$count.'link"><a data-page="'.$count.'" '.$selected.' href="'.$self->{url}.'page/'.$count.'">'.$count.'</a></li>';
		}
	}
	
	# Next
	if( $params ){
		$params->{page} = $currentPage+1;
		$links .= '<li class="next"><a data-page="'.$params->{page}.'" href="'. encode_entities(request->uri_for($self->{url}, $params)) .'">Next</a></li>' if $currentPage < $pages;
	} 
	else {
		$links .= '<li class="next"><a data-page="'.$params->{page}.'" href="'.$self->{url}.'page/'.($currentPage+1).'">Next</a></li>' if $currentPage < $pages;
	}
	
	# Page size
	my $pageSize = $self->{pageSize};
	if($options->{select_page_size}){
		my @pageSizeOptions = (10,20,50,100,500);
		$links .= '<form class="page-size" method="post"><select name="page_size" class="page_size">';
		for my $option (@pageSizeOptions){			
			my $selected = ($pageSize == $option) ? 'selected=selected' : '';
			$links .= "<option $selected value='$option'>$option</option>";
		}
		$links .= '</select><input type="submit" value="Set page size" /></form>';
	}
	
	return $links;	
}

sub extractPage{
	my ($splat) = shift;	
	my (@url) = split('/', $splat);
	
	# Find last "page" parameter
	my $index = scalar @url;
	--$index until ($url[$index] eq 'page' or $index < 0);
	return 1 if $index < 0;
	
	# Current page or first
	my $currentPage = $url[$index+1];
	
	return $currentPage;
}

1;
