### use this module to generate a set of class files

use DBIx::Class::Schema::Loader qw/ make_schema_at /;
make_schema_at(
    'TableEdit::Schema',
    { debug => 1,
      dump_directory => '../lib',
    },
    
    [ 'dbi:mysql:dbname=bizi;host=localhost;port=3306', 'root', 'toor'
       #{ loader_class => 'MyLoader' } # optionally
    ],
);