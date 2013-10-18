package Params;

use Dancer ':syntax';
use URI::Split qw(uri_split uri_join);
 
sub toHash {
	my $params = shift;
	my %hash   = ();
	my @array;
	my $subHash;
	for my $key ( keys %{$params} ) {
		my @keyArray = _keyToArray($key);
		my $value    = $params->{$key};
		$subHash = \%hash;
		my ( $lastHash, $lastKey );
		for my $hashKey (@keyArray) {
			$subHash->{$hashKey} = () unless $subHash->{$hashKey};
			$lastHash            = $subHash;
			$lastKey             = $hashKey;
			$subHash             = \%{ $subHash->{$hashKey} };
		}
		$lastHash->{$lastKey} = $value;
	}
	return \%hash;
}


sub parseUri {
	my $uri = shift;
	
	my ($scheme, $auth, $path, $query, $frag) = uri_split($uri);
	
	my $query_params = {};
	return ($path, $query_params) unless $query;
	foreach my $token (split /[&;]/, $query) {
        my ($key, $val) = split(/=/, $token, 2);
        next unless defined $key;
        $val = (defined $val) ? $val : '';
        $key = url_decode($key);
        $val = url_decode($val);
        $query_params->{$key} = $val;
	}
	return ($path, $query_params);
}

sub url_decode {
    my $encoded = shift;
    my $clean = $encoded;
    $clean =~ tr/\+/ /;
    $clean =~ s/%([a-fA-F0-9]{2})/pack "H2", $1/eg;
    return $clean;
}

sub _keyToArray {
	my ($key) = @_;
	my @keyArray;

	unless ( index( $key, '[' ) ) {
		push( @keyArray, $key );
		return \@keyArray;
	}

	my $firstKey = substr( $key, 0, index( $key, '[' ) );
	if ($firstKey) {
		push( @keyArray, $firstKey );
	}

	while ( $key =~ /\[(.*?)\]/ ) {
		my $inside = $1;
		push( @keyArray, $inside );
		$key = substr( $key, index( $key, ']' ) + 1 );
	}

	return @keyArray;
}

1;
