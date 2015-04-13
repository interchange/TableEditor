package TableEdit::SchemaInfo::Test::Relationships;

use Test::More;
use Data::Dumper;

use strict;
use warnings;

our @ISA = qw(Exporter);
our @EXPORT_OK = qw(test_relationships test_relationship);

$Data::Dumper::Terse = 1;

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
        if (ok(exists $rels->{$name}, "Test whether relationship $name exists.")) {
            test_relationship($class, $rels->{$name}, $info);
        }
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
    my ($class_name, $rel_name, $expected_value);

    # check whether class is present
    unless (isa_ok($class, 'TableEdit::ClassInfo')) {
        diag "Class missing for relationship text, expected values: ", Dumper($expected);
        return;
    }

    $class_name = $class->name;

    # check whether relationship is present
    unless (isa_ok($relationship, 'TableEdit::RelationshipInfo')) {
        diag "Relationship for class $class_name missing, expected values: ",
            Dumper($expected);
        return;
    }

    $rel_name = $relationship->name;

    # type
    my $type = $relationship->type;
    $expected_value = $expected->{type};
    ok($type eq $expected_value,
       "Test type for class $class_name and relationship $rel_name and $expected_value.")
        || diag "$type instead of $expected_value";

    # self column
    my $self_column = $relationship->self_column;
    $expected_value = $expected->{self_column};

    if ($self_column) {
        ok($self_column eq $expected_value,
           "Test self column for class $class_name and relationship $rel_name.")
            || diag "$self_column instead of $expected_value";
    }
    else {
        fail("Self column missing for class $class_name and relationship $rel_name: "
                 . Dumper($relationship->hashref));
    }

    # foreign column
    my $foreign_column = $relationship->foreign_column;
    $expected_value = $expected->{foreign_column};

    if ($foreign_column) {
        ok($foreign_column eq $expected_value,
           "Test foreign column for class $class_name and relationship $rel_name")
            || diag "$foreign_column instead of $expected_value";
    }
    else {
        fail("Foreign column missing for class $class_name and relationship $rel_name: "
                 . Dumper($relationship->hashref));
    }

	# origin class
	my $origin_class = $relationship->origin_class;
	isa_ok($origin_class, 'TableEdit::ClassInfo');

	my $origin_class_name = $origin_class->name;
	$expected_value = $class_name;

	ok($origin_class_name eq $expected_value,
       "Test origin class name for class $class_name and relationship $rel_name.")
        || diag "$origin_class_name instead of $expected_value";

    # class name
    my $rel_class_name = $relationship->class_name;
    $expected_value = $expected->{class_name} || $rel_name;

    ok($rel_class_name eq $expected_value,
       "Test name of related class for class $class_name and relationship $rel_name.")
        || diag "$rel_class_name instead of $expected_value";
}

1;
