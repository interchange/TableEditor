# uses Test::DBIx::Class configuration files in t/etc

BEGIN {
    use_ok( 'Strehler::Schema')
      or BAIL_OUT "Cannot load Strehler::Schema.";
}

use TableEdit::SchemaInfo;
use TableEdit::SchemaInfo::Test::Relationships qw(test_relationships);

isa_ok(Schema, 'DBIx::Class::Schema');

my $schema_info = TableEdit::SchemaInfo->new(schema => Schema);

isa_ok($schema_info, 'TableEdit::SchemaInfo');

my @classes = $schema_info->classes;
my $count = scalar(@classes);
my $expected_value = 10;

ok ($count == $expected_value, "Test number of classes")
        || diag "Number of classes: $count instead of $expected_value.";

# Test relationships
my %expected = (
    job => {
        type => 'belongs_to',
        self_column => 'fk_job_id',
        foreign_column => 'job_id',
        class_name => 'Job',
    },
    company => {
        type => 'belongs_to',
        self_column => 'fk_company_id',
        foreign_column => 'company_id',
        class_name => 'Company',
    },
    employee => {
        type => 'belongs_to',
        self_column => 'fk_employee_id',
        foreign_column => 'employee_id',
        class_name => 'Employee',
    },
);

test_relationships($schema_info->classes->{'Company::Employee'}, \%expected);

%expected = (
    phone_rs => {
        type => 'has_many',
        self_column => 'person_id',
        foreign_column => 'fk_person_id',
        class_name => 'Phone',
    },
    employee => {
        type => 'might_have',
        self_column => 'person_id',
        foreign_column => 'employee_id',
        class_name => 'Employee',
    },
    artist => {
        type => 'might_have',
        self_column => 'person_id',
        foreign_column => 'artist_id',
        class_name => 'Employee',
    },
);

test_relationships($schema_info->classes->{'Person'}, \%expected);

done_testing;
