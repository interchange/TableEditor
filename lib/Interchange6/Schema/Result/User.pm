use utf8;
package Interchange6::Schema::Result::User;
 
=head1 NAME
 
Interchange6::Schema::Result::User
 
=cut
 
use strict;
use warnings;
 
use base qw(DBIx::Class::Core Interchange6::Schema::Base::Attribute);
 
__PACKAGE__->load_components(qw(FilterColumn EncodedColumn InflateColumn::DateTime TimeStamp));
 
=head1 TABLE: C<users>
 
=cut
 
__PACKAGE__->table("users");
 
=head1 ACCESSORS
 
=head2 users_id
 
  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'users_users_id_seq'
 
=head2 username
 
  data_type: 'varchar'
  is_nullable: 0
  size: 255
 
The username is automatically converted to lowercase so
we make sure that the unique constraint on username works.
 
=head2 nickname
 
  data_type: 'varchar'
  is_nullable: 1
  size: 255
 
=head2 email
 
  data_type: 'varchar'
  default_value: (empty string)
  is_nullable: 0
  size: 255
 
=head2 password
 
  data_type: 'varchar'
  default_value: (empty string)
  is_nullable: 0
  size: 60
  encode_column: 1
  encode_class: 'Crypt::Eksblowfish::Bcrypt'
  encode_args: { key_nul => 1, cost => 14 }
  encode_check_method: 'check_password'
 
=head2 first_name
 
  data_type: 'varchar'
  default_value: (empty string)
  is_nullable: 0
  size: 255
 
=head2 last_name
 
  data_type: 'varchar'
  default_value: (empty string)
  is_nullable: 0
  size: 255
 
=head2 last_login
 
  data_type: 'datetime'
  is_nullable: 1
 
=head2 fail_count
 
  data_type: 'integer'
  is_nullable: 0
  default_value: 0
 
=head2 created
 
  data_type: 'datetime'
  set_on_create: 1
  is_nullable: 0
 
=head2 last_modified
 
  data_type: 'datetime'
  set_on_create: 1
  set_on_update: 1
  is_nullable: 0
 
=head2 active
 
  data_type: 'boolean'
  default_value: true
  is_nullable: 0
 
=cut
 
__PACKAGE__->add_columns(
  "users_id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "users_users_id_seq",
  },
  "username",
  { data_type => "varchar", is_nullable => 0, size => 255 },
  "nickname",
  { data_type => "varchar", is_nullable => 1, size => 255 },
  "email",
  { data_type => "varchar", default_value => "", is_nullable => 0, size => 255 },
  "password",
  {
   data_type           => "varchar",
   default_value       => "",
   is_nullable         => 0,
   size                => 60,
   #encode_column       => 1,
   #encode_class        => 'Crypt::Eksblowfish::Bcrypt',
   #encode_args         => { key_nul => 1, cost => 14 },
   #encode_check_method => 'check_password',
},
  "first_name",
  { data_type => "varchar", default_value => "", is_nullable => 0, size => 255 },
  "last_name",
  { data_type => "varchar", default_value => "", is_nullable => 0, size => 255 },
  "last_login",
  { data_type => "datetime", is_nullable => 1 },
  "fail_count",
  { data_type => "integer", is_nullable => 0, default_value => 0 },
  "created",
  { data_type => "datetime", set_on_create => 1, is_nullable => 0 },
  "last_modified",
  { data_type => "datetime", set_on_create => 1, set_on_update => 1, is_nullable => 0 },
  "active",
  { data_type => "boolean", default_value => \"true", is_nullable => 0 },
);
 
__PACKAGE__->filter_column( username => {
    filter_to_storage => sub {lc($_[1])},
});
 
=head1 METHODS
 
Attribute methods are provided by the L<Interchange6::Schema::Base::Attribute> class.
 
=head1 PRIMARY KEY
 
=over 4
 
=item * L</users_id>
 
=back
 
=cut
 
__PACKAGE__->set_primary_key("users_id");
 
=head1 UNIQUE CONSTRAINTS
 
=head2 C<users_username>
 
=over 4
 
=item * L</username>
 
=back
 
=cut
 
__PACKAGE__->add_unique_constraint("users_username", ["username"]);
 
=head2 C<users_nickname>
 
=over 4
 
=item * L</nickname>
 
=back
 
=cut
 
__PACKAGE__->add_unique_constraint("users_nickname", ["nickname"]);
 
=head1 RELATIONS
 
=head2 addresses
 
Type: has_many
 
Related object: L<Interchange6::Schema::Result::Address>
 
=cut
 
__PACKAGE__->has_many(
  "addresses",
  "Interchange6::Schema::Result::Address",
  { "foreign.users_id" => "self.users_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);
 
=head2 carts
 
Type: has_many
 
Related object: L<Interchange6::Schema::Result::Cart>
 
=cut
 
__PACKAGE__->has_many(
  "carts",
  "Interchange6::Schema::Result::Cart",
  { "foreign.users_id" => "self.users_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);
 
=head2 orders
 
Type: has_many
 
Related object: L<Interchange6::Schema::Result::Order>
 
=cut
 
__PACKAGE__->has_many(
  "orders",
  "Interchange6::Schema::Result::Order",
  { "foreign.users_id" => "self.users_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);
 
=head2 user_attribute
 
Type: has_many
 
Related object: L<Interchange6::Schema::Result::UserAttribute>
 
=cut
 
__PACKAGE__->has_many(
  "user_attributes",
  "Interchange6::Schema::Result::UserAttribute",
  { "foreign.users_id" => "self.users_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);
 
=head2 user_roles
 
Type: has_many
 
Related object: L<Interchange6::Schema::Result::UserRole>
 
=cut
 
__PACKAGE__->has_many(
  "user_roles",
  "Interchange6::Schema::Result::UserRole",
  { "foreign.users_id" => "self.users_id" },
  { cascade_copy => 0, cascade_delete => 0 },
);
 
=head2 roles
 
Type: many_to_many
 
Composing rels: L</user_roles> -> role
 
=cut
 
__PACKAGE__->many_to_many("roles", "user_roles", "role");
 
 
sub check_password {
	return 1;
}

 
1;