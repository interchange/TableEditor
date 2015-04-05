package TableEdit::SchemaInfo::Role::Config;

use Moo::Role;
use MooX::Types::MooseLike::Base qw/HashRef/;

=head1 NAME

TableEdit::SchemaInfo::Role::Config - Role for configuration

=head1 ATTRIBUTES

=head2 config

Hash reference with configuration.

=cut

has config => (
    is => 'ro',
    isa => sub {
        my $config = shift;

        if (ref($config) eq 'HASH'
                && exists $config->{TableEditor}) {
            Dancer::Logger::warning("Wrong input for config! " . caller);
        }

  #      Dancer::Logger::debug("Config: ", $config);
    },
    

    default => sub {{}},
);

1;
