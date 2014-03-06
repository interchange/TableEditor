use strict;
use warnings;

use Test::More;

use DBI;

my %dbi_map = map {$_ => 1} DBI->available_drivers;
my $active;

if ($dbi_map{mysql} && $dbi_map{SQLite}) {
    $active = 1;
    plan tests => 5;
}
else {
    $active = 0;
    plan tests => 2;
}

use_ok 'TableEdit::DriverInfo';

my $di;

$di = TableEdit::DriverInfo->new;

my $ret_norm = $di->available;

ok(ref($ret_norm) eq 'ARRAY', 'Array ref return value from available method');

exit 0 if ! $active;

ok(scalar(@$ret_norm), 'Test number of available drivers');

$di = TableEdit::DriverInfo->new(skip_extra => ['mysql']);

my $ret_skip = $di->available;

ok(ref($ret_skip) eq 'ARRAY', 'Array ref return value from available method');

ok(! grep {$_ eq 'mysql'} @$ret_skip, 'Test skip_extra attribute');
