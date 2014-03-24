package TableEdit::DriverInfo;

use DBI;

use Moo;
use MooX::Types::MooseLike::Base qw/ArrayRef/;

=head1 NAME

TableEdit::DriverInfo - DBI driver information for Table Editor

=head1 ATTRIBUTES

=head2 skip

Standard list of drivers to be excluded from available drivers as array
reference.

Defaults to C<CSV>, C<DBM>, C<ExampleP>, C<File>, C<Gofer>, C<Proxy> and C<Sponge>.

=cut

has skip => (
    is => 'ro',
    isa => ArrayRef,
    lazy => 1,
    default => sub {[qw/CSV DBM ExampleP File Gofer Proxy Sponge/]},
);

=head2 skip_extra

Additional list of drivers to be excluded from available drivers as array
reference.

=cut

has skip_extra => (
    is => 'ro',
    isa => ArrayRef,
    default => sub {[]},
);

=head2 available

Returns list of available drivers as array reference.

=cut

has available => (
    is => 'lazy',
);

sub _build_available {
    my ($self) = @_;
    my %skip_hash = map {$_ => 1} (@{$self->skip}, @{$self->skip_extra});
    my @available;

    for my $driver (DBI->available_drivers) {
        next if $skip_hash{$driver};
        push @available, $driver;
    }

    return \@available;
}

=head1 AUTHOR

Stefan Hornburg (Racke), <racke@linuxia.de>

=head1 LICENSE AND COPYRIGHT

Copyright 2014 Stefan Hornburg (Racke) <racke@linuxia.de>.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.

=cut

1;
