package TableEdit::SchemaInfo::Test::Relationships;

use Test::More;

use strict;
use warnings;

our @ISA = qw(Exporter);
our @EXPORT_OK = qw(test_relationships test_relationship);

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

1;
