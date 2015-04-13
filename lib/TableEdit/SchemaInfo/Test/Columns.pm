package TableEdit::SchemaInfo::Test::Columns;

use Test::More;
use Data::Dumper;

use strict;
use warnings;

our @ISA = qw(Exporter);
our @EXPORT_OK = qw(test_columns test_column);

$Data::Dumper::Terse = 1;

sub test_columns {
    my ($class, $expected) = @_;
    my @check_columns = $class->columns;
    my %cols;

    for my $colobj (@check_columns) {
        $cols{$colobj->name} = 1;
    }

    while (my ($col_name, $matches) = each %$expected) {
        my $col_obj = $class->schema->column($class->name, $col_name);

        isa_ok($col_obj, 'TableEdit::ColumnInfo');

        test_column($col_obj, $matches);

        delete $cols{$col_name};
    }

    my $keys = scalar(keys %cols);

    ok($keys == 0, "Check for missing columns in " . $class->name)
        || diag 'Missing columns for ', $class->name, ': ', join(',', keys %cols);
}

sub test_column {
    my ($col_obj, $matches) = @_;
    my $expected_value;

    my $col_name = $col_obj->name;
    my $class_name = $col_obj->class->name;

    # test_column position
    my $pos = $col_obj->position;
    $expected_value = $matches->{position};

    ok($pos eq $expected_value, "Test position for column $col_name in class $class_name")
        || diag "$pos instead of $expected_value.";

    # test column label
    my $label = $col_obj->label;
    $expected_value = $matches->{label} || '';

    ok($label eq $expected_value, "Test label for column $col_name in class $class_name")
        || diag "$label instead of $expected_value.";

    # test column types
    my $data_type = $col_obj->data_type;
    my $display_type = $col_obj->display_type;

    $expected_value = $matches->{data_type} || 'varchar';

    ok($data_type eq $expected_value, "Test data type for column $col_name in class $class_name")
        || diag "$data_type instead of $expected_value.";

    $expected_value = $matches->{display_type} || $expected_value;

    # numeric and varchar data types maps to textfield display type
    if ($expected_value eq 'numeric' || $expected_value eq 'varchar') {
        $expected_value = 'textfield';
    }

    ok($display_type eq $expected_value,
       "Test display type for column $col_name in class $class_name")
        || diag "$display_type instead of $expected_value.";

	# test default value
	my $default_value = $col_obj->default_value;
	$expected_value = $matches->{default_value};

	if (defined $default_value || defined $expected_value) {
	    ok($default_value eq $expected_value,
	       "Test default value for column $col_name in class $class_name")
            || diag "$default_value instead of $expected_value.";
	}

    # test whether column is foreign key
    my $is_fk = $col_obj->is_foreign_key;
    $expected_value = $matches->{is_foreign_key} || 0;

    ok($is_fk eq $expected_value,
       "Test is_foreign_key for column $col_name in class $class_name")
        || diag "$is_fk instead of $expected_value.";

    if ($is_fk) {
        # test name of foreign key
        my $fk_name = $col_obj->foreign_column;
        $expected_value = $matches->{foreign_column};

        ok($fk_name eq $expected_value,
           "Test foreign_column name for column $col_name in class $class_name")
            || diag "$fk_name instead of $expected_value.";

        # test type of foreign key
        my $fk_type = $col_obj->foreign_type;
        $expected_value = $matches->{foreign_type};

        ok($fk_type eq $expected_value,
           "Test foreign_type name for type $col_name in class $class_name")
            || diag "$fk_type instead of $expected_value.";

        # test relationship object
        my $rel = $col_obj->relationship;

        isa_ok($rel, 'TableEdit::RelationshipInfo');
    }
    else {
        # test name of foreign key
        my $fk_name = $col_obj->foreign_column;
        $expected_value = $matches->{foreign_column} || '';

        ok($fk_name eq $expected_value,
           "Test foreign_column name for column $col_name in class $class_name")
            || diag "$fk_name instead of $expected_value.";

        # test type of foreign key
        my $fk_type = $col_obj->foreign_type;
        $expected_value = $matches->{foreign_type} || '';

        ok($fk_type eq $expected_value,
           "Test foreign_type name for type $col_name in class $class_name")
            || diag "$fk_type instead of $expected_value.";

        # test relationship object
        my $rel = $col_obj->relationship;

        ok(! defined $rel);
    }
}

