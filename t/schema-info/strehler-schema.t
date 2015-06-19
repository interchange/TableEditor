use strict;
use warnings;

use Test::Most;
use Test::Database;

use TableEdit::DBIxClassModifiers;
eval "use Strehler::Schema";
plan skip_all => "Strehler::Schema required" if $@;

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
    my $schema = Strehler::Schema->connect($testdb->connection_info);

    my $ret;

    isa_ok($schema, 'Strehler::Schema');

    $schema_info = TableEdit::SchemaInfo->new(schema => $schema,
                                              user_roles => ['tester'],
                                              config => {read => ['tester']},
                                          );

    my $classes = $schema_info->classes;

    my $count = scalar(keys %$classes);
    my $expected_value = 9;

    warn "Classes: ", join(',', keys %$classes), "\n";
    
    ok ($count == $expected_value, "Test number of classes")
        || diag "Number of classes: $count instead of $expected_value.";

    ok (exists $classes->{Description}, "Test for Description class.");

    # set sorting for Description class
    $classes->{Description}->sort(1);

    # test name and label of class
    my $name = $classes->{Description}->name;
    $expected_value = 'Description';
    ok ($name eq $expected_value, "Test name of Description class.")
        || diag "$name instead of $expected_value.";

    my $label = $classes->{Description}->label;
    $expected_value = 'Description';
    ok ($label eq $expected_value, "Test label of Description class.")
        || diag "$label instead of $expected_value.";

    # test resultset for class (from schema and from class)
    my ($rs, $rs_name);

    $expected_value = 'Strehler::Schema::Result::Description';

    $rs = $schema_info->resultset('Description');
    isa_ok($rs, 'DBIx::Class::ResultSet');

    $rs_name = $rs->result_class;
    ok ($rs_name eq $expected_value, "Test name of Description resultset.")
	|| diag "$rs_name instead of $expected_value.";

    $rs = $classes->{Description}->resultset;
    isa_ok($rs, 'DBIx::Class::ResultSet');

    $rs_name = $rs->result_class;
    ok ($rs_name eq $expected_value, "Test name of Description resultset.")
	|| diag "$rs_name instead of $expected_value.";

    $expected_value = 5;

    # retrieve columns as array
    my @cols = $classes->{Description}->columns;
    $count = scalar(@cols);
    ok ($count == $expected_value, "Test number of columns for Description resultset (array)")
        || diag "Number of columns: $count instead of $expected_value.";

    # test number of columns
    my $columns = $classes->{Description}->columns;

    $count = scalar(keys %$columns);
    ok ($count == $expected_value, "Test number of columns for Description resultset (hash)")
        || diag "Number of columns: $count instead of $expected_value.";

    # test order in array
    my @expected_order = qw/id image title description language/;
    my @order = map {$_->name} @cols;

    is_deeply(\@order, \@expected_order, "Order of columns for Description resultset (array)");

    my %expected = (
        id => {
            label => 'Roles id',
            data_type => 'integer',
            position => 1,
        },
        image => {
            label => 'Name',
            position => 2,
        },
        title => {
            label => 'Title',
            position => 3,
        },
        description => {
            label => 'Description',
            position => 4,
        },
        image => {
            label => 'Image',
            position => 5,
        },
    );
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
