package TableEdit;
use Dancer ':syntax';

our $VERSION = '0.1';

use Dancer::Plugin::DBIC qw(schema resultset rset);
use TableEdit::Config;
use TableEdit::API;

hook 'before_template_render' => sub {
	my $tokens = shift;
	$tokens->{'site-title'} = 'Table Edit';
};

prefix '/';
get '/' => sub { return forward '/index.html'};

true;

__END__
 
=pod
 
=head1 NAME
 
Dancer - Table Edit
 
=head1 SYNOPSIS
 
Table Edit lets you edit database data. It uses L<DBIx::Class> models for database metadata. 

 
=head1 CONFIGURATION
 
You need a database and L<DBIx::Class> models for this module to work. You can 
write your own L<DBIx::Class> models, or use schema loader.


=head2 DBIx schema loader

You can use your existing DBIx schema or let schema loader make one for you.

=head2 Database config

You also have to set Dancers DBCI connection in config.yml

	plugins: 
	   DBIC:
	     default:
	        dsn: dbi:Pg:dbname=__DATABASE_NAME__;host=localhost;port=__PORT__
	        schema_class: TableEdit::Schema
	        user: __USERNAME__
	        pass: __PASSWORD__
	        options:

=head1 USE

Whit basic configuration done you can start using Table Edit. You will probably want to fine tune it a bit though.

=head1 FINE TUNE

Make sure you set all additional info below # DO NOT MODIFY THIS OR ANYTHING ABOVE! line in L<DBIx::Class> model.

For this example we will use folowing model.

	use utf8;
	package TableEdit::Schema::Result::User;
	
	use strict;
	use warnings;
	
	use base 'DBIx::Class::Core';
	
	__PACKAGE__->table("user");
	
	__PACKAGE__->add_columns(
	  "id",
	  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
	  "username",
	  { data_type => "varchar", is_nullable => 0, size => 45 },
	  "email",
	  { data_type => "varchar", is_nullable => 1, size => 90 },
	  "birthday",
	  { data_type => "timestamp with time zone", is_nullable => 1 },
	  "internal_code",
	  { data_type => "integer", is_nullable => 1 },
	  "created_date",
	  {
	    data_type     => "timestamp with time zone",
	    default_value => \"current_timestamp",
	    is_nullable   => 0,
	    original      => { default_value => \"now()" },
	  },
	);
	
	__PACKAGE__->set_primary_key("id");
	
	__PACKAGE__->belongs_to(
	  "company",
	  "TableEdit::Schema::Result::Company",
	  { id => "podjetje_id" },
	  { is_deferrable => 1, on_delete => "CASCADE", on_update => "CASCADE" },
	);
	
	__PACKAGE__->has_many(
	  "user_items",
	  "TableEdit::Schema::Result::UserItem",
	  { "foreign.approval_id" => "self.approval_id" },
	  { cascade_copy => 0, cascade_delete => 0 },
	);
		
	__PACKAGE__->many_to_many("items", "user_items", "id", {class=>"Item",});
	
	# Created by DBIx::Class::Schema::Loader v0.07033
	# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:g5NE5itWUoKXqfEKXj/8Rg
	
	
	# You can replace this text with custom code or comments, and it will be preserved on regeneration
	1;
		

=head2 Column label

You can override column label by specifying it  

	__PACKAGE__->columns_info->{fname}->{label} = 'Name';

=head2 Object / Row string representation

Row often has to be represented as string (titles, drop-down selectors, ...) so it is a good idea to 
define a custum, human redable strigification method. For example users username, his id in parentheses 
and company if he / she has one. It could be just username or something much complicated.

	use overload fallback => 1, '""' => \&to_string; 

	sub to_string {
		my $self = shift;	
		my $company = $self->company || "";
		return "$self->username ($self->id) $company";
	}

=head2 Hidden columns

Some columns are used only internaly and you never want to see them in TableEdit. You can hide them.

	__PACKAGE__->columns_info->{internal_code}->{hidden} = 1;

=head2 Readonly columns

You can set a column to be readonly

	__PACKAGE__->columns_info->{created_date}->{readonly} = 1;

=head2 Many to many

"Has many" and "belongs_to" is automaticly detected. However, many to many DBIx::Class information 
doesn't provide enough information, so you have to specify it manualy.
Only set resultset_attributes once, or it will be overwritten! 

	__PACKAGE__->resultset_attributes({ 
		many_to_many => {
			items => {class => 'TableEdit::Schema::Result::Item', where => {inactive => 'false'}},  
		},		
	});
	
=head2 Grid visible columns

Often you don't care about all columns when you browse though rows or there are simply to many. 
You can specify a list of columns that will appear on grid. 
Only set resultset_attributes once, or it will be overwritten! 

	__PACKAGE__->resultset_attributes({ 	
		grid_columns => ['approval_id', 'item_id', 'notify', 'is_approved'],
	});
	
=head2 Model name / label

You can set user friendly name of the table.

	__PACKAGE__->resultset_attributes({ 	
		label => 'Employees',
	});
	
=head2 Field data type

Fileds have basic data types based on types in db. You can override them to use differen form element.

	__PACKAGE__->columns_info->{email}->{data_type} = 'text';
	
You can also set them to use your custum widget. You create html file with the matching name in /public/views/field directory.
For example 	/public/views/field/email_widget.html
	
	__PACKAGE__->columns_info->{email}->{data_type} = 'email_widget';
	
These fied types are used on detail view and on list search. 	
	
=cut	