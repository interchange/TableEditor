use strict;
use warnings;
use Test::Most;

eval "use Test::DBIx::Class";
plan skip_all => "Test::DBIx::Class required" if $@;

require("t/schema-info/test_dbic.pl");
