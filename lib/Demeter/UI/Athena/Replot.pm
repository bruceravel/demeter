package Demeter::UI::Athena::Replot;

use strict;
use warnings;
use base qw( Exporter );
our @EXPORT = qw(replot $APP);

our $APP = $::app;

sub replot {
  my ($plot, $space, $how) = @_;
  $::app->plot(q{}, q{}, $space, $how), $/;
};

1;

=head1 NAME

Demeter::UI::Athena::Replot - A replotting abstraction for Athena

=head1 VERSION

This documentation refers to Demeter version 0.9.26.

=head1 SYNOPSIS

This module exports a single function which is a generalized replotter
used throughout Athena.

=head1 DEPENDENCIES

Demeter's dependencies are in the F<Build.PL> file.

=head1 BUGS AND LIMITATIONS

Please report problems to the Ifeffit Mailing List
(L<http://cars9.uchicago.edu/mailman/listinfo/ifeffit/>)

Patches are welcome.

=head1 AUTHOR

Bruce Ravel (L<http://bruceravel.github.io/home>)

L<http://bruceravel.github.io/demeter/>

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2018 Bruce Ravel (L<http://bruceravel.github.io/home>). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
