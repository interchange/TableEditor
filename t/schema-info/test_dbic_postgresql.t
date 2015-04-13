use strict;
use warnings;
use Test::Most;

eval "use Test::DBIx::Class";
plan skip_all => "Test::DBIx::Class required" if $@;

eval "use DBD::Pg";
plan skip_all => "DBD::Pg required" if $@;

eval "use Test::PostgreSQL";
plan skip_all => "Test::PostgreSQL required" if $@;

require("t/schema-info/test_dbic.pl");
