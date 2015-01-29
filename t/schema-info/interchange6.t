use strict;
use warnings;

use Test::Most;
use Test::Database;

use Interchange6::Schema 0.070;
use TableEdit::SchemaInfo;
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
            position => 4,
        },
    );

    # test column info for class
    test_columns($classes->{Role}, \%expected);

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
    test_relationships($classes->{Role}, \%expected);

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

    test_columns($classes->{UserRole}, \%expected);

    # test relationship for Inventory class
    %expected = (
        Product => {
            type => 'belongs_to',
            self_column => 'sku',
            foreign_column => 'sku',
        },
    );

    test_relationships($classes->{Inventory}, \%expected);

    # reverse relationship
    %expected = (
        type => 'might_have',
        self_column => 'sku',
        foreign_column => 'sku',
    );

    test_relationship($classes->{Product},
                       $classes->{Product}->relationships->{Inventory},
                       \%expected);

    # test relationships for Permission class
    %expected = (
        role => {
            class_name => 'Role',
            type => 'belongs_to',
            self_column => 'roles_id',
            foreign_column => 'roles_id',
        },
    );

    test_relationships($classes->{Permission}, \%expected);

    test_columns($classes->{Tax}, {
	decimal_places => {
	    data_type => 'integer',
	    default_value => 2,
	    label => 'Decimal places',
	    position => 5,
	}
    });

    # test hashref
    my $col_info = $schema_info->column('UserRole', 'users_id');
    my $col_label = $col_info->hashref->{label};
    $expected_value = 'Users id';

    ok($col_label eq $expected_value, "Test label from hashref for column users_id")
        || diag "$col_label instead of $expected_value.";
}

sub test_columns {
    my ($class, $expected) = @_;
    my $expected_value;

    while (my ($col_name, $matches) = each %$expected) {
        my $col_obj = $schema_info->column($class->name, $col_name);

        isa_ok($col_obj, 'TableEdit::ColumnInfo');

        # test_column position
        my $pos = $col_obj->position;
        $expected_value = $matches->{position};

        ok($pos eq $expected_value, "Test position for column $col_name")
            || diag "$pos instead of $expected_value.";

        # test column label
        my $label = $col_obj->label;
        $expected_value = $matches->{label} || '';

        ok($label eq $expected_value, "Test label for column $col_name")
            || diag "$label instead of $expected_value.";

        # test column types
        my $data_type = $col_obj->data_type;
        my $display_type = $col_obj->display_type;

        $expected_value = $matches->{data_type} || 'varchar';

        ok($data_type eq $expected_value, "Test data type for column $col_name")
            || diag "$data_type instead of $expected_value.";

        ok($display_type eq $expected_value,
           "Test display type for column $col_name")
            || diag "$display_type instead of $expected_value.";

	# test default value
	my $default_value = $col_obj->default_value;
	my $expected_value = $matches->{default_value};

	if (defined $default_value || defined $expected_value) {
	    ok($default_value eq $expected_value,
	       "Test default value for column $col_name")
		|| diag "$default_value instead of $expected_value.";
	}

        # test whether column is foreign key
        my $is_fk = $col_obj->is_foreign_key;
        $expected_value = $matches->{is_foreign_key} || 0;

        ok($is_fk eq $expected_value,
           "Test is_foreign_key for column $col_name")
            || diag "$is_fk instead of $expected_value.";

        if ($is_fk) {
            # test name of foreign key
            my $fk_name = $col_obj->foreign_column;
            $expected_value = $matches->{foreign_column};

            ok($fk_name eq $expected_value,
               "Test foreign_column name for column $col_name")
                || diag "$fk_name instead of $expected_value.";

            # test type of foreign key
            my $fk_type = $col_obj->foreign_type;
            $expected_value = $matches->{foreign_type};

            ok($fk_type eq $expected_value,
               "Test foreign_type name for type $col_name")
                || diag "$fk_type instead of $expected_value.";

            # test relationship object
            my $rel = $col_obj->relationship;

            isa_ok($rel, 'TableEdit::RelationshipInfo');
        }
    }
}


done_testing;
