## Time-stamp: <2010-05-06 16:39:51 bruce>
######################################################################
##  This module is copyright (c) 1999-2010 Bruce Ravel
##  <http://bruceravel.github.io/home>
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
## Code:

package Xray::Scattering;

require Exporter;

@ISA = qw(Exporter);
@EXPORT = qw();
@EXPORT_OK = qw($resource $verbose);

use strict;
use vars qw(@ISA $VERSION $resource $verbose $data_dir);
use Carp;
use Chemistry::Elements qw(get_Z get_symbol);
use File::Spec;
use version;

$VERSION = version->new("3.0.1");

$resource = "cromermann";
$verbose = 0;


sub identify_self {
  my @caller = caller;
  use File::Basename qw(dirname);
  return dirname($caller[1]);
};

$data_dir = q{};


$data_dir = File::Spec->catfile(identify_self(), 'Scattering');

sub load {
  shift;
  $resource = $_[0] || $resource;
  $resource = lc($resource);
  @ISA = load_database('Xray::Scattering', $resource);
};

sub load_database {
  my($class,$resource) = (shift, lc(shift));
  if ($resource =~ /^cro/) {
    require Xray::Scattering::CromerMann;
    'Xray::Scattering::CromerMann';
  } elsif ($resource =~ /^waas/) {
    require Xray::Scattering::WaasKirf;
    'Xray::Scattering::WaasKirf';
  } elsif ($resource eq 'none') {
    require Xray::Scattering::None;
    'Xray::Scattering::None';
  } else {
    croak "$resource is an unknown Xray::Absorption resource";
  }
};

sub available {
  shift;
  my @list = ("Cromer-Mann", "Waasmaier-Kirfel", "None");
  return @list;
};

## what's the dot thing?
sub get_valence {
  shift;
  my ($elem, $val) = @_;
  $elem = ucfirst($elem);
  if ($val eq '.') {
    return $elem . $val
  } elsif (lc($val) eq 'va') {
    return $elem . lc($val);
  };
  $val = _nint($val);
  if ($val > 0) {
    return $elem . $val . "+";
  } elsif ($val < 0) {
    return $elem . abs($val) . "-";
  } else {
    return $elem;
  }
};


sub _nint {
  my $v = $_[0];
  my $i = int($v);
  if ($v >= 0) {
    ( ($v-$i) == 0.5 ) and (not $i % 2) and return $i+1;
    ( ($v-$i)  > 0.5 ) and return $i+1;
    return $i;
  } else {
    ( ($i-$v) == 0.5 ) and (not $i % 2) and return $i-1;
    ( ($i-$v)  > 0.5 ) and return $i-1;
    return $i;
  };
};

Xray::Scattering->load($resource);
1;
__END__


=head1 NAME

Xray::Scattering - X-ray scattering data for the elements

=head1 SYNOPSIS

  use Xray::Scattering;
  Xray::Scattering->load('CroMann');
  $fnot = Xray::Scattering->get_f($symb, $d);

  Xray::Scattering->load('WaasKirt');
  $fnot = Xray::Scattering->get_f($symb, $d);

=head1 DESCRIPTION

This module supports access to X-ray scattering data for atoms and ions.  It
is designed to be a transparent interface to scattering data from a variety of
sources.  Currently, the only sources of data are the Cromer-Mann tables from
the International Tables of Crystallography and the 1995 Waasmaier-Kirfel
tables.  More resources can be added easily.

=head1 METHODS

=over 4

=item C<available>

This method returns a list of data resources available to this module.
Currently this returns an array consisting of these strings:

  Cromer-Mann  Waasmaier-Kirfel  None

The first two are functional interfaces to those databases.  The third is a
fallback subclass which returns default values for all methods.

=item C<get_valence>

This returns the element/valence symbol in the proper form for use with other
methods.  C<$elem> is a two-letter atomic symbol, and C<$valence> is the
valence of the ion.  C<$valence> can be an integer, a float, a dot or the
string "va".

   $symbol = Xray::Scattering->get_valence($elem, $valence)

Unless the valence is a dot or the string "va", the nearest integer to
C<$valence> is used with the element symbol to construct the element/valence
symbol.  As an example, C<$symbol eq "Cu2+"> if C<$elem eq "Cu"> and
C<$valence == 2>.

=back

=head1 SUBCLASS METHODS

All the available subclasses corresponding to the data resources provide their
own versions of the following methods:

=over 4

=item C<get_f>

This function calculates the Thomson scattering for a given symbol
and d-spacing.  The Thomson scattering depends only on the momentum
transfer.  The d-spacing of the scattering planes is a closely related
quantity and is easily calculated from the crystal structure, see
L<Xtal.pm>.

  $symb = "Ce3+";
  $fnot = Xray::Scattering->get_f($symb, $d);

If the symbol cannot be found in the table, C<get_f> returns 0.  It
also returns 0 when C<$symbol> consists of whitespace or is "null" or
"nu".  If C<$symbol> is a number or the name of an element, then it
assumes you want the Thomson scattering for the neutral element.  The
absolute value of C<$d_spacing> is used by this function.

The C<None> subclass always returns 0.

If you ask for a valence state that is not in the table but for an element
whose 0+ state is in the table, this method returns the scattering factor for
the 0 valent atom.

=item C<get_coefficients>

This returns the 9 (Cromer-Mann) or 11 (Waasmaier-Kirfel) element list
containing the coefficients for the given symbol.

   @coefs = Xray::Scattering->get_coefficients($symb)

See the documents for the subclasses for the order of the coefficients.  The
None subclass always returns a list of 11 zeros.

If you ask for a valence state that is not in the table but for an element
whose 0+ state is in the table, this method returns the coefficients for
the 0 valent atom.

=item C<has>

This is a test of whether a given symbol is tabulated in the selected data
resource table.  It returns the symbol itself if found in the table or 0 if it
is not in the table.

  $symb = "Ce3+";
  $has = Xray::Scattering->has($symb);

The None subclass returns the symbol itself.

=back

=head1 AUTHOR

Bruce Ravel, L<http://bruceravel.github.io/home>

http://bruceravel.github.io/demeter

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2008 Bruce Ravel (http://bruceravel.github.io/home). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
