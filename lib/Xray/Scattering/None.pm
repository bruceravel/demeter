## Time-stamp: <16-Nov-2009 08:17:52 bruce>
######################################################################
##  This module is copyright (c) 2005-2008 Bruce Ravel
##  <bravel AT bnl DOT gov>
##  http://bruceravel.github.io/demeter
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
## $Id: CromerMann.pm,v 1.3 1999/06/11 22:19:59 bruce Exp $
######################################################################
## Code:

package Xray::Scattering::None;

use strict;
use warnings;
use version;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);

use Chemistry::Elements qw(get_symbol);
use File::Spec;
use Storable;

require Exporter;

@ISA = qw(Exporter AutoLoader);
@EXPORT_OK = qw();
$VERSION = version->new("3.0.0");

sub tabulated {
  shift;
  my $sym = lc($_[0]);
  return ucfirst($sym);
};
{
  no warnings 'once';
  # alternate names
  *has = \ &tabulated;
};

sub get_f {
  shift;
  return 0;
};

sub get_coefficients {
  shift;
  my $sym = lc($_[0]);
  my @null = (0,0,0,0,0,0,0,0,0,0,0);
  return @null;
};



1;

__END__

=head1 NAME

Xray::Scattering::None - Fallback methods for Xray::Scattering

=head1 SYNOPSIS

  use Xray::Scattering;
  Xray::Scattering->load('None');
  $fnot = Xray::Scattering->get_f($symb, $d);

=head1 DESCRIPTION

This module provides a fallback subclass for the Xray::Scattering methods.  It
provides all the methods of the real subclasses, but returns fallback values.


=head1 METHODS

=over 4

=item C<get_f>

Retruns 0.

=item C<get_coefficients>

returns an array of 11 zeros.

=item C<has>

Always returns the symbol itself.

=back



=head1 AUTHOR

  Bruce Ravel, bravel AT bnl DOT gov
  http://bruceravel.github.io/demeter

=cut
