### use this module to generate a set of class files

use DBIx::Class::Schema::Loader qw/ make_schema_at /;
make_schema_at(
    'TableEdit::Schema',
    { debug => 1,
      dump_directory => '../lib',
    },
    [ 'dbi:Pg:dbname=iro;host=localhost;port=5556', 'interch', '94daq2rix',
       #{ loader_class => 'MyLoader' } # optionally
    ],
);