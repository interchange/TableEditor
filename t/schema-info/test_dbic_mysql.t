use strict;
use warnings;
use Test::Most;

eval "use Test::DBIx::Class";
plan skip_all => "Test::DBIx::Class required" if $@;

eval "use DBD::mysql";
plan skip_all => "DBD::mysql required" if $@;

eval "use Test::mysqld";
plan skip_all => "Test::mysqld required" if $@;

require("t/schema-info/test_dbic.pl");
