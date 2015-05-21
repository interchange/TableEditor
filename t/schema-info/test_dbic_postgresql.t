use strict;
use warnings;
use Test::Most;

eval "use DBD::Pg";
plan skip_all => "DBD::Pg required" if $@;

eval "use Test::PostgreSQL";
plan skip_all => "Test::PostgreSQL required" if $@;

require("t/schema-info/test_dbic.pl");
