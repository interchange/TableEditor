package TableEdit::ColumnInfo;

use Dancer ':syntax';
use Moo;

with 'TableEdit::SchemaInfo::Role::Label';

=head1 ATTRIBUTES

=head2 name

Column name.

=cut

has name => (
    is => 'ro',
    required => 1,
);

has class => (
    is => 'ro',
    required => 1,
);


=head2 position

Position of the column in the class, starts with 1.

=cut

has position => (
    is => 'lazy',
    default => sub {
        my $self = shift;
    	return $self->attr('position'); 
    },
);

=head2 data_type

Column data type.

=cut

has data_type => (
    is => 'ro',
    required => 1,
);

=head2 column_type

Column column type.

=cut

has column_type => (
    is => 'lazy',
    default => sub {
        my $self = shift;
    	return $self->attr('column_type'); 
    },
);

=head2 display_type

Column display type.

=cut

has display_type => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my $self = shift;
		
		# Default or custom set type
		my $column_type = $self->column_type || $self->data_type;
		
		# Check if widget for this type exists or use plain text field
		$column_type = 'varchar' unless grep( /^$column_type/, TableEdit::Config::column_types );
	
		return $column_type;
    },
    trigger => sub {
		my ($self, $value) = @_;
	
		if (ref($self->{hashref}) eq 'HASH') {
		    $self->{hashref}->{display_type} = $value;
		}
    },
);

=head2 is_foreign_key

Whether column is foreign key.

=cut

has is_foreign_key => (
    is => 'ro',
    default => 0,
);

=head2 foreign_column

Column name of foreign key.

=cut

has foreign_column => (
    is => 'ro',
    default => '',
);

=head2 foreign_type

Type of foreign key.

=cut

has foreign_type => (
    is => 'ro',
    default => '',
);

=head2 dropdown_options

Options to select values from for this column.

=cut

has dropdown_options => (
    is => 'rw',
    default => '',
);

=head2 is_nullable

Whether column is nullable or not.

=cut

has is_nullable => (
    is => 'ro',
);

=head2 size

Column size

=cut

has size => (
    is => 'ro',
);

=head2 default_value

Default value for column.

=cut

has default_value => (
    is => 'ro',
);

=head2 hidden

Whether column is hidden or not.

=cut

has hidden => (
	is => 'lazy',
    default => sub {
		my $self = shift;
		return $self->attr('hidden');
	}
);

=head2 Read-only

Whether column is hidden or not.

=cut

has readonly => (
	is => 'lazy',
    default => sub {
		my $self = shift;
		return $self->attr('readonly');
	}
);

=head2 relationship

L<TableEdit::RelationshipInfo> object if column
is foreign key.

=cut

has relationship => (
    is => 'ro',
);

=head2 upload dir

Dir to save uploads to.

=cut

has upload_dir => (
    is => 'lazy',
    default => sub {
    	my $self = shift; 
    	return undef unless $self->display_type eq 'image_upload';
    	return $self->attr('upload_dir') || "images/upload/".$self->class->name."/".$self->name."/";
    }
);
=head2 upload extensions

Allowed extensions.

=cut

has upload_extensions => (
    is => 'lazy',
    default => sub {
    	my $self = shift; 
    	return [map {lc($_)} @{$self->attr('upload_extensions')}] if $self->attr('upload_extensions');
    	return undef;
    }
);
=head2 upload max size

=cut

has upload_max_size => (
    is => 'lazy',
    default => sub {
    	my $self = shift; 
    	return $self->attr('upload_max_size');
    }
);

=head2 hashref

=cut
sub hashref {
		my $self = shift;
		
		my $hash = {};
		$hash->{data_type} = $self->data_type;
		$hash->{display_type} = $self->display_type;
		$hash->{foreign_column} = $self->foreign_column if $self->foreign_column;
	    $hash->{foreign_type} = $self->foreign_type if $self->foreign_type;
		$hash->{is_foreign_key} = $self->is_foreign_key if $self->is_foreign_key;
		$hash->{is_nullable} = $self->is_nullable if $self->is_nullable;
		$hash->{readonly} = $self->readonly if $self->readonly;
		$hash->{label} = $self->label if $self->label;
		$hash->{name} = $self->name if $self->name;
		$hash->{size} = $self->size if defined $self->size;
		$hash->{upload_max_size} = $self->upload_max_size if defined $self->upload_max_size;
		$hash->{upload_extensions} = $self->upload_extensions if $self->upload_extensions;
		$hash->{upload_dir} = $self->upload_dir if $self->upload_dir;
		$hash->{options} = $self->dropdown_options if $self->dropdown_options;
	
	    return $hash;
}


=head2 is_primary

Returns 1 if column is primary key

=cut
has is_primary => (
    is => 'lazy',
    default => sub {	
		my $self = shift;
		my $primary_key = $self->class->primary_key;
		return undef unless $primary_key;
		if(ref($primary_key) eq 'ARRAY'){
			for my $pk (@$primary_key){
				return 1 if $self->name eq $primary_key;
			}
		}
		return 1 if $self->name eq $primary_key;
		return undef;
	}
);

=head2 required

Returns 'required' if column is required

=cut
sub required {
	my $self = shift;
	return 'required' if !$self->default_value and $self->is_nullable == 0;
	if($self->is_foreign_key){
		return undef if $self->foreign_type and $self->foreign_type eq 'might_have';
		return 'required' unless $self->is_nullable and $self->is_nullable != 1;
	}
	return undef;
};


=head2 attr

=cut
sub attr  {
		my ($self, @path) = @_;
		my $value;
		unshift @path, 'TableEditor', 'classes', $self->class->name, 'columns', $self->name;
		my $node = config;
		for my $p (@path){
			$node = $node->{$p};
			return $node unless defined $node;
		}
		return $node;
}


1;
