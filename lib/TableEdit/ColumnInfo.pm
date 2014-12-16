package TableEdit::ColumnInfo;

use Moo;

with 'TableEdit::SchemaInfo::Role::Config';
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
		$column_type = 'textfield' unless grep( /^$column_type/, @{$self->class->schema->column_types});
	
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

=head2 foreign_class

Class object of foreign key.

=cut

has foreign_class => (
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

sub dropdown_options {
	my $self = shift;
	
	# Belongs to or Has one
	my $foreign_type = $self->foreign_type;

	if ($foreign_type eq 'belongs_to' or $foreign_type eq 'might_have') {
	    my $rs = $self->relationship->resultset;

	    # determine number of records in foreign table
	    my $count = $rs->count;
	    my $treshold = $self->class->schema->attr('dropdown_threshold');
	    $treshold ||= 50;
	    if ($count <= $treshold){
			$self->display_type ('dropdown');
			my @foreign_rows = $rs->all;
			my @items;
			for my $row (@foreign_rows){
				my $rowInfo = TableEdit::RowInfo->new(row => $row, class => $self->relationship->{class});
				my $primary_key = $self->relationship->{class}->primary_key;
				my $id = $rowInfo->primary_key_string;
				my $name = $rowInfo->to_string;
				push @items, {option_label=>$name, value=>$id};
			}
			@items = sort { lc $a->{option_label} cmp lc $b->{option_label} } @items;

			return [@items];
	    }
	    else {
	    	$self->display_type ('autocomplete');
	    }
	}
	return undef;
}


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
		return $self->attr('hidden') if $self->attr('hidden');
		return undef;
	}
);

=head2 Read-only

Whether column is hidden or not.

=cut

has readonly => (
	is => 'lazy',
    default => sub {
		my $self = shift;
		return $self->attr('readonly') if $self->attr('readonly');
		return 1 if $self->attr('dynamic_default_on_update') or $self->attr('dynamic_default_on_create');
		return undef;
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
    	return undef unless $self->display_type eq 'image_upload' or $self->attr('upload_dir');
    	my $dir = $self->attr('upload_dir') || "upload/".$self->class->name."/".$self->name."/";
    	$dir = "$dir/" unless substr($dir, -1) eq '/'; 
    	return $dir;
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

Static and dynamic propeties about column

=cut
sub hashref {
		my $self = shift;
		
		my $hash = $self->static_hashref;
		$hash->{options} = $self->dropdown_options if $self->dropdown_options;
		
	    return $hash;
}


=head2 static_hashref

Lazy attr for all static column properties

=cut
has static_hashref => (
    is => 'lazy',
    default => sub {
		my $self = shift;
    	my $hash = $self->attrs;
		$hash->{options} = $self->dropdown_options if $self->dropdown_options;
		$hash->{data_type} = $self->data_type;
		$hash->{display_type} = $self->display_type;
		$hash->{foreign_column} = $self->foreign_column if $self->foreign_column;
		$hash->{foreign_class} = $self->foreign_class->name if $self->foreign_class;
	    $hash->{foreign_type} = $self->foreign_type if $self->foreign_type;
		$hash->{is_foreign_key} = $self->is_foreign_key if $self->is_foreign_key;
		$hash->{primary_key} = $self->is_primary if $self->is_primary;
		$hash->{readonly} = $self->readonly if $self->readonly;
		$hash->{required} = $self->required if $self->required;
		$hash->{hidden} = $self->hidden if defined $self->hidden;
		$hash->{label} = $self->label if $self->label;
		$hash->{name} = $self->name if $self->name;
		$hash->{upload_max_size} = $self->upload_max_size if defined $self->upload_max_size;
		$hash->{upload_extensions} = $self->upload_extensions if $self->upload_extensions;
		$hash->{upload_dir} = $self->upload_dir if $self->upload_dir;
	
	    return $hash;
    }
);	


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
				return 1 if $self->name eq $pk;
			}
		}
		return 1 if $self->name eq $primary_key;
		return undef;
	}
);

=head2 required

Returns 'required' if column is required

=cut
has required => (
	is => 'lazy',
    default => sub {
		my $self = shift;
		return 'required' if $self->attr('required');
		return 'required' if 
			!defined $self->default_value 
				and 
			!defined $self->attr('dynamic_default_on_update') 
				and 
			defined $self->attr('is_nullable') and $self->attr('is_nullable') == 0;
			
		if($self->is_foreign_key){
			return undef if $self->foreign_type and $self->foreign_type eq 'might_have';
			return 'required';
		}
		return undef;
    }
);


=head2 attr

Column atribute specified in config or schema 

=cut
sub attr  {
		my ($self, @path) = @_;
		my $value;

		unshift @path, 'classes', $self->class->name, 'columns', $self->name;
		my $node = $self->config;

		for my $p (@path){
			$node = $node->{$p};
			next if defined $node and ref $node eq 'hash';
		}
		return $node if defined $node;
		
		# Schema config
		$node = $self->class->resultset->result_source->resultset_attributes;
		for my $p (@path){
			$node = $node->{$p};
			next if defined $node and ref $node eq 'hash';
		}
		return $node;
		
}
=head2 attrs

All column atributes specified in config or schema 

=cut
has attrs => (
    is => 'lazy',
    default => sub {
		my ($self) = @_;
		my ($node);

		# Schema config
		my $schema_attrs = $self->class->resultset->result_source->column_info($self->name) || {};

		# Config file
		$node = $self->config;
		for my $p ('TableEditor', 'classes', $self->class->name, 'columns', $self->name){
			$node = $node->{$p};
			last unless defined $node; 
		}
		my $config_attrs = $node || {};

		return {%$schema_attrs, %$config_attrs};		
	}
);


1;
