use utf8;
package TableEdit::ConfigSchema::Result::Db;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

TableEdit::ConfigSchema::Result::Db

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<db>

=cut

__PACKAGE__->table("db");

=head1 ACCESSORS

=head2 name

  data_type: 'text'
  is_nullable: 0

=head2 schema_class

  data_type: 'text'
  is_nullable: 1

=head2 driver

  data_type: 'text'
  is_nullable: 1

=head2 dbname

  data_type: 'text'
  is_nullable: 1

=head2 dsn_suffix

  data_type: 'text'
  is_nullable: 1

=head2 options

  data_type: 'text'
  is_nullable: 1

=head2 user

  data_type: 'text'
  is_nullable: 1

=head2 pass

  data_type: 'text'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "name",
  { data_type => "text", is_nullable => 0 },
  "schema_class",
  { data_type => "text", is_nullable => 1 },
  "driver",
  { data_type => "text", is_nullable => 1 },
  "dbname",
  { data_type => "text", is_nullable => 1 },
  "dsn_suffix",
  { data_type => "text", is_nullable => 1 },
  "options",
  { data_type => "text", is_nullable => 1 },
  "user",
  { data_type => "text", is_nullable => 1 },
  "pass",
  { data_type => "text", is_nullable => 1 },
  "host",
  { data_type => "text", is_nullable => 1 },
  "port",
  { data_type => "text", is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</name>

=back

=cut

__PACKAGE__->set_primary_key("name");


# Created by DBIx::Class::Schema::Loader v0.07033 @ 2014-03-03 10:47:57
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:7A6MTbR9399vl3e0JMuETw


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
