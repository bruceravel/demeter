##  This module is copyright (c) 2000-2007 Bruce Ravel
##  <L<http://bruceravel.github.io/home>>
##  http://bruceravel.github.io/demeter/
##  http://cars9.uchicago.edu/svn/libperlxray/
##
## -------------------------------------------------------------------
##     All rights reserved. This program is free software; you can
##     redistribute it and/or modify it under the same terms as Perl
##     itself.
##
##     This program is distributed in the hope that it will be useful,
##     but WITHOUT ANY WARRANTY; without even the implied warranty of
##     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
##     Artistic License for more details.
## -------------------------------------------------------------------
######################################################################
## Time-stamp: <1999/11/19 22:07:01 bruce>
######################################################################
## Code:

=head1 NAME

Xray::Absorption::None - Fallback methods for Xray::Absorption

=head1 SYNOPSIS

   use Xray::Absorption;
   Xray::Absorption -> load("none");

See the documentation for Xray::Absorption for details.

=head1 DESCRIPTION

This module is inherited by the Xray::Absorption module and provides
access to the data contained in the 1999 Elam tables of line and edge
energies by inheriting that module.  The cross_section method is
overloaded and always returns 0 regardless of what mode is selected.

This rather strange functionality is a crude hack to benefit the ATP
mechanism used by Atoms and related programs.

=cut

package Xray::Absorption::None;

use strict;
use warnings;
use version;

use Exporter ();
use Config;
use Xray::Absorption;
use Xray::Absorption::Elam;

use vars qw($VERSION $resource $cvs_info $mucal_version @ISA @EXPORT @EXPORT_OK);

require Exporter;

@ISA = qw(Exporter AutoLoader Xray::Absorption::Elam);
#@EXPORT_OK = qw();
$VERSION = version->new("3.0.0");

sub current_resource {
  "none";
};

# sub in_resource {
#   return 1;
# };


# sub get_energy {
#   return 0;
# };

# sub next_energy {
#   return ();
# };

sub cross_section {
  shift;
  my ($sym, $energy, $mode) = @_;
  return 0;
};

1;

__END__

=head1 EDGE AND LINE ENERGIES

See L<Xray::Absorption::Elam>.

=head1 AUTHOR

  Bruce Ravel, http://bruceravel.github.io/home
  http://bruceravel.github.io/demeter/

=cut
