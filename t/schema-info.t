use strict;
use warnings;

use Test::More;
use Test::Database;

use Interchange6::Schema;
use TableEdit::SchemaInfo;

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

    $schema_info = TableEdit::SchemaInfo->new(schema => $schema);

    my $classes = $schema_info->classes;

    my $count = scalar(keys %$classes);
    my $expected_value = 44;

    ok ($count == $expected_value, "Test number of classes")
	|| diag "Number of classes: $count instead of $expected_value.";

    ok (exists $classes->{Role}, "Test for Role class.");

    # test name and label of class
    my $name = $classes->{Role}->name;
    $expected_value = 'Role';
    ok ($name eq $expected_value, "Test name of Role class.")
	|| diag "$name instead of expected_value.";

    my $label = $classes->{Role}->label;
    $expected_value = 'Role';
    ok ($label eq $expected_value, "Test label of Role class.")
	|| diag "$label instead of expected_value.";

    $expected_value = 3;

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

    my %expected = (
        roles_id => {
            label => 'Roles id',
            data_type => 'integer',
        },
        name => {
            label => 'Name',
        },
        label => {
            label => 'Label',
        },
    );

    # test column info for class
    test_columns($classes->{Role}, \%expected);

    %expected = (
        GroupPricing => {
            type => 'has_many',
            self_column => 'roles_id',
            foreign_column => 'roles_id',
        },
        Permission => {
            type => 'has_many',
            self_column => 'roles_id',
            foreign_column => 'roles_id',
        },
        UserRole => {
            type => 'has_many',
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
            label => 'Roles id',
            data_type => 'integer',
        },
        users_id => {
            is_foreign_key => 1,
            foreign_column => 'users_id',
            label => 'Users id',
            data_type => 'integer',
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

    %expected = (
        type => 'belongs_to',
        self_column => 'roles_id',
        foreign_column => 'roles_id',
    );

    test_relationship($classes->{Permission},
                      $classes->{Permission}->relationships->{Role},
                       \%expected);

    # test hashref
    my $col_info = $schema_info->column('UserRole', 'users_id');
    my $col_label = $col_info->hashref->{label};
    $expected_value = 'Users id';

    ok($col_label eq $expected_value, "Test label from hashref for column users_id")
	|| diag "$col_label instead of $expected_value.";
}

sub test_columns {
    my ($class, $expected) = @_;

    while (my ($col_name, $matches) = each %$expected) {
	my $col_obj = $schema_info->column($class->name, $col_name);

	isa_ok($col_obj, 'TableEdit::ColumnInfo');

	# test column label
	my $label = $col_obj->label;
	my $expected_value = $matches->{label} || '';

	ok($label eq $expected_value, "Test label for column $col_name")
	    || diag "$label instead of $expected_value.";

	# test column types
	my $data_type = $col_obj->data_type;
	my $display_type = $col_obj->display_type;

	$expected_value = $matches->{data_type} || 'varchar';

	ok($data_type eq $expected_value, "Test data type for column $col_name")
	    || diag "$data_type instead of $expected_value.";

	ok($display_type eq $expected_value, "Test display type for column $col_name")
	    || diag "$display_type instead of $expected_value.";
	
	# test whether column is foreign key
	my $is_fk = $col_obj->is_foreign_key;
	$expected_value = $matches->{is_foreign_key} || 0;

	ok($is_fk eq $expected_value, "Test is_foreign_key for column $col_name")
	    || diag "$is_fk instead of $expected_value.";



    if ($is_fk) {
        # test name of foreign key
        my $fk_name = $col_obj->foreign_column;
        $expected_value = $matches->{foreign_column};

        ok($fk_name eq $expected_value,
           "Test foreign_column name for column $col_name")
            || diag "$fk_name instead of $expected_value.";
    }
    }
}

sub test_relationships {
    my ($class, $expected) = @_;
    my $expected_value;
    my $name = $class->name;
    my $rels = $class->relationships;
    my @rel_names = keys %$rels;

    # test number of relationships
    my $count = scalar(keys %$rels);
    $expected_value = scalar(keys %$expected);

    ok($count == $expected_value,
       "Test number of relationships for class $name")
        || diag "$count instead of $expected_value, found: " .
            join(', ', @rel_names);

    while (my ($name, $info) = each %$expected) {
        ok(exists $rels->{$name}, "Test whether relationship $name exists.");

        test_relationship($class, $rels->{$name}, $info);
    }
}

# Tests single relationship
#
# Parameters are:
#
# class - ClassInfo object
# relationship - Relationship object
# expected - Hash reference with expected values.

sub test_relationship {
    my ($class, $relationship, $expected) = @_;
    my $class_name = $class->name;
    my $rel_name = $relationship->name;
    my $expected_value;

    # type
    my $type = $relationship->type;
    $expected_value = $expected->{type};
    ok($type eq $expected_value,
       "Test type for class $class_name and relationship $rel_name and $expected_value.")
        || diag "$type instead of $expected_value";

    # self column
    my $self_column = $relationship->self_column;
    $expected_value = $expected->{self_column};
    ok($self_column eq $expected_value,
       "Test self column for class $class_name and relationship $rel_name.")
        || diag "$self_column instead of $expected_value";

    # foreign column
    my $foreign_column = $relationship->foreign_column;
    $expected_value = $expected->{foreign_column};
    ok($foreign_column eq $expected_value,
       "Test foreign column for class $class_name and relationship $rel_name.")
        || diag "$foreign_column instead of $expected_value";
}

done_testing;
