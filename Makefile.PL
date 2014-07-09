use strict;
use warnings;
use ExtUtils::MakeMaker;

# Normalize version strings like 6.30_02 to 6.3002,
# so that we can do numerical comparisons on it.
my $eumm_version = $ExtUtils::MakeMaker::VERSION;
$eumm_version =~ s/_//;

WriteMakefile(
    NAME                => 'TableEdit',
    AUTHOR              => q{YOUR NAME <youremail@example.com>},
    VERSION_FROM        => 'lib/TableEdit.pm',
    ABSTRACT            => 'YOUR APPLICATION ABSTRACT',
    ($eumm_version >= 6.3001
      ? ('LICENSE'=> 'perl')
      : ()),
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::Most' => 0,
        'Test::Database' => 0,
        'YAML'       => 0,
        'Array::Utils' => 0,
        'DBD::SQLite' => 1.38_01,
        'Dancer'     => 1.3118,
        'Dancer::Plugin::DBIC' => 0,
        'Dancer::Plugin::Auth::Extensible' => 0,
	'Template' => 0,
        'DBIx::Class::Schema::Loader' => 0,
        'Moo' => 0,
        'MooX::Types::MooseLike' => 0,
        'Plack::Handler::Starman' => 0,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'TableEdit-*' },
    test                => { TESTS => join( ' ', (glob( 't/*.t'), glob('t/*/*.t')))},
);
