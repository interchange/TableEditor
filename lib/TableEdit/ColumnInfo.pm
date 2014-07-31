package TableEdit::ColumnInfo;

use Moo;

with 'TableEdit::SchemaInfo::Role::Label';

use TableEdit::SchemaInfo;

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
    is => 'ro',
    required => 1,
);

=head2 data_type

Column data type.

=cut

has data_type => (
    is => 'ro',
    required => 1,
);

=head2 field_type

Column field type.

=cut

has field_type => (
    is => 'ro',
    required => 0,
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
		my $field_type = $self->field_type || $self->data_type;
		
		# Check if widget for this type exists or use plain text field
		$field_type = 'varchar' unless grep( /^$field_type/, TableEdit::Config::field_types );
	
		return $field_type;
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
    is => 'ro',
    default => 0,
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
    is => 'ro',
);
=head2 upload extensions

Allowed extensions.

=cut

has upload_extensions => (
    is => 'ro',
);
=head2 upload max size

=cut

has upload_max_size => (
    is => 'ro',
);

=head2 options

Options to select values from for this column.

=cut

has options => (
    is => 'rw',
    trigger => sub {
	my ($self, $value) = @_;

	if (ref($self->{hashref}) eq 'HASH') {
	    $self->{hashref}->{options} = $value;
	}
    },
);


sub hashref {
	my $self = shift;
	return $self->_as_hashref;
};


sub is_primary {
	my $self = shift;
	my $classPK = $self->class->primary_key;
	return undef unless $classPK;
	if(ref($classPK) eq 'ARRAY'){
		for my $pk (@$classPK){
			return 1 if $self->name eq $classPK;
		}
	}
	return 1 if $self->name eq $classPK;
	return undef;
};


sub required {
	my $self = shift;
	return 'required' if !$self->default_value and $self->is_nullable == 0;
	if($self->is_foreign_key){
		return undef if $self->foreign_type and $self->foreign_type eq 'might_have';
		return 'required' unless $self->is_nullable and $self->is_nullable != 1;
	}
	return undef;
};


sub dropdown_options {
	my $self = shift;
	my $result_set = [$self->class->resultset->all];
	my $column = $self->name;
	my $items = [];
	for my $object (@$result_set){
		my $id = $object->$column;
		my $name = model_to_string($object);
		push @$items, {option_label=>$name, value=>$id};
	}
	return $items;
	return $self->_as_hashref;
};


sub model_to_string {
	my $object = shift;
	return $object->to_string if eval{$object->to_string};
	return "$object" unless eval{$object->result_source};
	my $class = $object->result_source->{source_name};
	my $classInfo = TableEdit::ClassInfo->new($class);
	my ($pk) = $object->result_source->primary_columns;
	my $id = $object->$pk;
	return "$id - ".$classInfo->label;
}

sub _as_hashref {
    my $self = shift;

    my %hash = (
	data_type => $self->data_type,
	display_type => $self->display_type,
	foreign_column => $self->foreign_column,
    foreign_type => $self->foreign_type,
	hidden => $self->hidden,
	is_foreign_key => $self->is_foreign_key,
	is_nullable => $self->is_nullable,
	label => $self->label,
	name => $self->name,
	options => $self->options,
	size => $self->size,
	upload_max_size => $self->upload_max_size,
	upload_extensions => $self->upload_extensions ? [map {lc($_)} @{$self->upload_extensions}] : undef,
	upload_dir => $self->upload_dir,
    );

    return \%hash;
}

1;
