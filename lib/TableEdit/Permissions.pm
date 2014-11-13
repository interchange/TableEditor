package TableEdit::Permissions;

use Dancer ':syntax';
use Dancer::Plugin::Auth::Extensible;
use Dancer::Plugin;

require TableEdit::Routes::API;

# Permission levels
# KEY level is granted to users with this level or levels specified in ARRAY
my $levels = {
	'read' => ['full', 'update', 'create', 'delete'], 
	'update' => ['full', 'create', 'delete'],
	'create' => ['full', ], 
	'delete' => ['full', ],
};


sub role_in {
	my ($roles) = @_;
	return undef unless logged_in_user and $roles;
	for my $my_role (@{logged_in_user->{roles}}){
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
register role_in  => \&role_in;


sub permission {
	my($level, $item, $op) = @_;
	#debug "Checking for permission $level for ".$item->name;
	my @granted_levels = ($level, @{$levels->{$level}});
	# Global
	unless(ref $item){
			
	}
	# Find by object
	else {
		# Class
		if(ref $item eq 'TableEdit::ClassInfo'){
			return 0 if role_in($item->attr('restricted'));
			for my $granted_level (@granted_levels){
				return 1 if role_in($item->attr($granted_level));
			}
		}
		# Column
		elsif(ref $item eq 'TableEdit::ColumnInfo'){
			return 0 if role_in($item->attr('restricted'));
			for my $granted_level (@granted_levels){
				return 1 if role_in($item->attr($granted_level));
			}
			return permission($level, $item->class);
		}
	}
	for my $granted_level (@granted_levels){
		my $schema_info = TableEdit::Routes::API->schema_info;
		return 1 if role_in($schema_info->attr($granted_level));
	}
	return undef;
}
register permission  => \&permission;


register_plugin for_versions => [qw(1 2)];
1;

