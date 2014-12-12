package TableEdit::Permissions;

use Moo;
use MooX::Types::MooseLike::Base qw/ArrayRef InstanceOf/;

has schema => (
    is => 'ro',
    required => 1,
    isa => InstanceOf['TableEdit::SchemaInfo'],
);

has roles => (
    is => 'ro',
    isa => ArrayRef,
    default => sub {[]},
);

# Permission levels
# KEY level is granted to users with this level or levels specified in ARRAY
my $levels = {
	'read' => ['full', 'update', 'create', 'delete'], 
	'update' => ['full', 'create', 'delete'],
	'create' => ['full', ], 
	'delete' => ['full', ],
};


sub role_in {
	my ($self, $roles) = @_;
    return undef if ! defined $roles;

	for my $my_role (@{$self->roles}) {
		if(ref $roles eq 'ARRAY'){
			for my $role (@$roles){
				return 1 if $role eq $my_role; 
			}
		}
		elsif(not ref $roles){
			return 1 if $roles eq $my_role; 
		}
	}
	return undef;
}


sub permission {
	my ($self, $level, $item, $op) = @_;
    #debug "Checking for permission $level for ".$item->name;
	my @granted_levels = ($level, @{$levels->{$level}});
	# Global
	unless(ref $item){
			
	}
	# Find by object
	else {
		# Class
		if(ref $item eq 'TableEdit::ClassInfo'){
			return 0 if $self->role_in($item->attr('restricted'));
			for my $granted_level (@granted_levels){
				return 1 if $self->role_in($item->attr($granted_level));
			}
		}
		# Column
		elsif(ref $item eq 'TableEdit::ColumnInfo'){
			return 0 if $self->role_in($item->attr('restricted'));
			for my $granted_level (@granted_levels){
				return 1 if $self->role_in($item->attr($granted_level));
			}
			return $self->permission($level, $item->class);
		}
	}
	for my $granted_level (@granted_levels){
		my $schema_info = $self->schema;
		return 1 if $self->role_in($schema_info->attr($granted_level));
	}
	return undef;
}

1;

