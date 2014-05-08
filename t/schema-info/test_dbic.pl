# uses Test::DBIx::Class configuration files in t/etc

BEGIN {
    use_ok( 'Test::DBIx::Class', 0.41)
      or BAIL_OUT "Cannot load Test::DBIx::Class 0.41 or above.";
}

use TableEdit::SchemaInfo;

isa_ok(Schema, 'DBIx::Class::Schema');

my $schema_info = TableEdit::SchemaInfo->new(schema => Schema);

isa_ok($schema_info, 'TableEdit::SchemaInfo');

my @classes = $schema_info->classes;
my $count = scalar(@classes);
my $expected_value = 10;

ok ($count == $expected_value, "Test number of classes")
        || diag "Number of classes: $count instead of $expected_value.";

done_testing;
