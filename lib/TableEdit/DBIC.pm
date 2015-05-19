package    # hide from PAUSE
  TableEdit::DBIC;

use strict;
use warnings;

use DBIx::Class::Relationship::Helpers;
use DBIx::Class::ResultSourceProxy::Table;
use Class::Method::Modifiers qw/install_modifier/;

# DBIx::Class::ResultSourceProxy::Table->table is almost certainly not the
# best place to add class methods - to be investigated further.

install_modifier "DBIx::Class::ResultSourceProxy::Table", "before",
  "table", sub {
    my ( $class, $table ) = @_;
    return unless $table;
    $class->mk_classdata( _table_editor_m2m_metadata => {} )
      unless $class->can('_table_editor_m2m_metadata');
  };

# add m2m metadata in DBIx::Class::Relationship::Helpers

install_modifier "DBIx::Class::Relationship::Helpers", "before",
  "many_to_many", sub {
    my ( $class, $meth, $rel, $f_rel ) = @_;
    $class->_table_editor_m2m_metadata->{$meth} =
      { local => $rel, foreign => $f_rel };
  };

1;
