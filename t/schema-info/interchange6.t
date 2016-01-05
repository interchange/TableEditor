use strict;
use warnings;

use Test::Most;
use Test::Database;

use TableEdit::DBIxClassModifiers;
eval "use Interchange6::Schema 0.091";
plan skip_all => "Interchange6::Schema 0.091 required" if $@;

use TableEdit::SchemaInfo;
use TableEdit::SchemaInfo::Test::Columns qw(test_columns);
use TableEdit::SchemaInfo::Test::Relationships qw(test_relationships test_relationship);

my @all_handles = Test::Database->handles();
my @handles;
my %exclude_dbd = (CSV => 1,
                   DBM => 1,
                   SQLite2 => 1,
                   );

for my $testdb (@all_handles) {
    next if exists $exclude_dbd{$testdb->dbd};

    push @handles, $testdb;
}

my $tests = 3 * scalar(@handles);

if (! scalar(@handles)) {
    plan skip_all => 'No test database handles available';
}

my $schema_info;

for my $testdb (@handles) {
    my $driver = $testdb->dbd();

    diag "Testing with DBI driver $driver";

    my $dbh = $testdb->dbh();
    my $dbd = $testdb->dbd();

    my @connection_info = $testdb->connection_info;
    my $schema = Interchange6::Schema->connect($testdb->connection_info);

    my $ret;

    isa_ok($schema, 'Interchange6::Schema');

    $schema->deploy({add_drop_table => 1});

    $schema_info = TableEdit::SchemaInfo->new(
        schema => $schema,
        user_roles => ['tester'],
        config => {
            read => ['tester'],
        },
    );

    my $classes = $schema_info->classes;

    my $count = scalar(keys %$classes);
    my $expected_value = 49;

    ok ($count == $expected_value, "Test number of classes")
        || diag "Number of classes: $count instead of $expected_value.";

    ok (exists $classes->{Role}, "Test for Role class.");

    # set sorting for Role class
    $classes->{Role}->sort(1);

    # test name and label of class
    my $name = $classes->{Role}->name;
    $expected_value = 'Role';
    ok ($name eq $expected_value, "Test name of Role class.")
        || diag "$name instead of $expected_value.";

    my $label = $classes->{Role}->label;
    $expected_value = 'Role';
    ok ($label eq $expected_value, "Test label of Role class.")
        || diag "$label instead of $expected_value.";

    # test resultset for class (from schema and from class)
    my ($rs, $rs_name);

    $expected_value = 'Interchange6::Schema::Result::Role';

    $rs = $schema_info->resultset('Role');
    isa_ok($rs, 'DBIx::Class::ResultSet');

    $rs_name = $rs->result_class;
    ok ($rs_name eq $expected_value, "Test name of Role resultset.")
	|| diag "$rs_name instead of $expected_value.";

    $rs = $classes->{Role}->resultset;
    isa_ok($rs, 'DBIx::Class::ResultSet');

    $rs_name = $rs->result_class;
    ok ($rs_name eq $expected_value, "Test name of Role resultset.")
	|| diag "$rs_name instead of $expected_value.";

    $expected_value = 4;

    # retrieve columns as array
    my @cols = $classes->{Role}->columns;
    $count = scalar(@cols);
    ok ($count == $expected_value, "Test number of columns (array)")
        || diag "Number of columns: $count instead of $expected_value.";

    # test number of columns
    my $columns = $classes->{Role}->columns;

    $count = scalar(keys %$columns);
    ok ($count == $expected_value, "Test number of columns (hash)")
        || diag "Number of columns: $count instead of $expected_value.";

    # test order in array
    my @expected_order = qw/roles_id name label description/;
    my @order = map {$_->name} @cols;

    is_deeply(\@order, \@expected_order, "Order of columns (array)");

    my %expected = (
        roles_id => {
            label => 'Roles id',
            data_type => 'integer',
            position => 1,
        },
        name => {
            label => 'Name',
            position => 2,
        },
        label => {
            label => 'Label',
            position => 3,
        },
        description => {
            label => 'Description',
            data_type => 'text',
            position => 4,
        },
    );

    # test column info for class
    subtest "test_columns of Role" =>
      sub { test_columns( $classes->{Role}, \%expected ) };

    %expected = (
        price_modifiers => {
            class_name => 'PriceModifier',
            type => 'has_many',
            self_column => 'roles_id',
            foreign_column => 'roles_id',
        },
        permissions => {
            class_name => 'Permission',
            type => 'has_many',
            self_column => 'roles_id',
            foreign_column => 'roles_id',
        },
        user_roles => {
            class_name => 'UserRole',
            type => 'has_many',
            self_column => 'roles_id',
            foreign_column => 'roles_id',
        },
        users => {
            class_name => 'User',
            type => 'many_to_many',
            self_column => 'roles_id',
            foreign_column => 'roles_id',
        },
    );

    # test relationships
    subtest "test_relationships of Role" => sub {
        test_relationships( $classes->{Role}, \%expected );
    };

    # testing UserRole class
    @cols = $classes->{UserRole}->columns;
    $count = scalar(@cols);
    $expected_value = 2;
    ok ($count == $expected_value, "Test number of columns (array)")
        || diag "Number of columns: $count instead of $expected_value.";

    %expected = (
        roles_id => {
            is_foreign_key => 1,
            foreign_column => 'roles_id',
            foreign_type => 'belongs_to',
            label => 'Roles id',
            data_type => 'integer',
            position => 2,
        },
        users_id => {
            is_foreign_key => 1,
            foreign_column => 'users_id',
            foreign_type => 'belongs_to',
            label => 'Users id',
            data_type => 'integer',
            position => 1,
        },
    );

    subtest "test_columns of UserRole" => sub {
        test_columns( $classes->{UserRole}, \%expected );
    };

    # test relationship for Inventory class
    %expected = (
        Product => {
            type => 'belongs_to',
            self_column => 'sku',
            foreign_column => 'sku',
        },
    );

    subtest "test_relationships of Inventory" => sub {
        test_relationships( $classes->{Inventory}, \%expected );
    };

    # reverse relationship
    %expected = (
        type => 'might_have',
        self_column => 'sku',
        foreign_column => 'sku',
    );

    subtest "test_relationship of Product->Inventory" => sub {
        test_relationship( $classes->{Product},
            $classes->{Product}->relationships->{Inventory}, \%expected );
    };

    # test relationships for Permission class
    %expected = (
        role => {
            class_name => 'Role',
            type => 'belongs_to',
            self_column => 'roles_id',
            foreign_column => 'roles_id',
        },
    );

    subtest "test_relationships of Permission" => sub {
        test_relationships( $classes->{Permission}, \%expected );
    };

    subtest "test_columns of Tax" => sub {
        test_columns(
            $classes->{Tax},
            {
                taxes_id => {
                    data_type => 'integer',
                    label => 'Taxes id',
                    position => 1,
                },
                tax_name => {
                    data_type => 'varchar',
                    label => 'Tax name',
                    position => 2,
                    size => 64,
                },
                description => {
                    data_type => 'varchar',
                    label => 'Description',
                    position => 3,
                    size => 64,
                },
                percent => {
                    data_type => 'numeric',
                    label => 'Percent',
                    position => 4,
                },
                decimal_places => {
                    data_type     => 'integer',
                    default_value => 2,
                    label         => 'Decimal places',
                    position      => 5,
                },
                rounding => {
                    data_type => 'char',
                    label => 'Rounding',
                    position => 6,
                },
                valid_from => {
                    data_type => 'date',
                    label => 'Valid from',
                    position => 7,
                },
                valid_to => {
                    data_type => 'date',
                    label => 'Valid to',
                    position => 8,
                },
                country_iso_code => {
                    data_type => 'char',
                    label => 'Country iso code',
                    is_foreign_key => 1,
                    foreign_column => 'country_iso_code',
                    foreign_type => 'belongs_to',
                    position => 9,
                },
                states_id => {
                    data_type => 'integer',
                    label => 'States id',
                    is_foreign_key => 1,
                    foreign_column => 'states_id',
                    foreign_type => 'belongs_to',
                    position => 10,
                },
                created => {
                    data_type => 'datetime',
                    label => 'Created',
                    position => 11,
                },
                last_modified => {
                    data_type => 'datetime',
                    label => 'Last modified',
                    position => 12,
                },
            }
        );
    };

    # test relationships for Navigation
    %expected = (
        children => {
            class_name => 'Navigation',
            type => 'has_many',
            self_column => 'navigation_id',
            foreign_column => 'parent_id',
        },
        active_children => {
            class_name => 'Navigation',
            type => 'has_many',
            self_column => 'navigation_id',
            foreign_column => 'parent_id',
        },
        parents => {
            class_name => 'Navigation',
            type => 'has_many',
            self_column => 'parent_id',
            foreign_column => 'navigation_id',
        },
        _parent => {
            class_name => 'Navigation',
            type => 'belongs_to',
            self_column => 'parent_id',
            foreign_column => 'navigation_id',
        },
        products => {
            class_name => 'Product',
            type => 'many_to_many',
        },
        navigation_products => {
            class_name => 'NavigationProduct',
            type => 'has_many',
            self_column => 'navigation_id',
            foreign_column => 'navigation_id',
        },
        navigation_attributes => {
            class_name => 'NavigationAttribute',
            type => 'has_many',
            self_column => 'navigation_id',
            foreign_column => 'navigation_id',
        },
    );

    subtest "test_relationships of Navigation" => sub {
        test_relationships( $classes->{Navigation}, \%expected );
    };

    # test hashref
    my $col_info = $schema_info->column('UserRole', 'users_id');
    my $col_label = $col_info->hashref->{label};
    $expected_value = 'Users id';

    ok($col_label eq $expected_value, "Test label from hashref for column users_id")
        || diag "$col_label instead of $expected_value.";
}

done_testing;
