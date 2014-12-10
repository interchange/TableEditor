package TableEdit::Plugins;
use Dancer ':syntax';

use FindBin;
use Cwd qw/realpath/;
use Dancer::ModuleLoader;

my $active_plugin_list = attr('plugins');
my $plugins = [];
my $appdir = realpath( "$FindBin::Bin/..");

	for my $plugin (@$active_plugin_list){
		my $plugin_module = "TableEdit::Plugins::".$plugin."::API";
		Dancer::ModuleLoader->load($plugin_module)
        	or warn "Couldn't load $plugin_module\n";
		push @$plugins, {
			name => $plugin, 
			js => "api/plugins/$plugin/public/js/app.js",
			css => "api/plugins/$plugin/public/css/style.css"
		};
	}

prefix '/api';

get '/plugins'=> sub {
	return to_json $plugins;
};
	

# Public files related to plugin
get '/plugins/:plugin/public/**' => sub {
	my $plugin = params->{plugin}->[0];

	# Return only active plugins
	pass unless grep( /^$plugin$/, @$active_plugin_list );

	# File path
	my @splat = splat;
	@splat = @{$splat[0]};
	@splat = splice @splat, 4;
	my $file = "$appdir/lib/TableEdit/Plugins/".$plugin.'/public/'. join '/', @splat;
	
	
	return send_file($file, system_path => 1);
};

prefix '/';

get '/views/**' => sub {
	my ($splat) = splat;

	for my $plugin (@$active_plugin_list){
		my $file = "$appdir/lib/TableEdit/Plugins/".$plugin.'/public/views/'. join '/', @$splat;
		return send_file($file, system_path => 1) if (-e $file);
	}
	pass;
};

=head2 attributes

Return attribute value

=cut

sub attr  {
		my (@path) = @_;
		my $value;
		unshift @path, 'TableEditor';
		my $node = config;
		for my $p (@path){
			$node = $node->{$p};
			return $node unless defined $node;
		}
		return $node;
}

1;
