##  This module is copyright (c) 1999-2007 Bruce Ravel
##  <bravel AT bnl DOT gov>
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
## Time-stamp: <1999/05/20 15:20:00 bruce>
######################################################################
## Code:

=head1 NAME

Xray::Absorption::Chantler - Perl interface to the Chantler tables

=head1 SYNOPSIS

   use Xray::Absorption;
   Xray::Absorption -> load("chantler");

See the documentation for Xray::Absorption for details.

=head1 DESCRIPTION

This module is inherited by the Xray::Absorption module and provides
access to the data contained in the Chantler tables of anomalous
scattering factors and line and edge energies.

The data in this module, referred to as "The Chantler Tables", was
published as

  C. T. Chantler
  Theoretical Form Factor, Attenuation, and Scattering Tabulation
     for Z = 1 - 92 from E = 1 - 10 eV to E = 0.4 - 1.0 MeV
  J. Phys. Chem. Ref. Data 24, 71 (1995)

This can be found on the web at

  http://physics.nist.gov/PhysRefData/FFast/Text/cover.html

The Chantler data is available on the web at

  http://physics.nist.gov/PhysRefData/FFast/html/form.html

More information can be found on the personal web page of
C.T. Chantler

  http://optics.ph.unimelb.edu.au/~chantler/home.html

The data contained in a database file called F<chantler.db> which is
generated at install time from the flat text files of the Chantler data.
The data is stored in a Storable archive using "network" ordering.
This allows speedy disk and memory access along with network and
platform portability.

The required C<File::Spec>, C<Chemistry::Elements>, and C<Storable>
modules are available from CPAN.

=cut


package Xray::Absorption::Chantler;

use strict;
use warnings;
use version;

use Exporter ();
use Config;
use Xray::Absorption;

use vars qw($VERSION $resource $line_rule $chantler_version @ISA @EXPORT @EXPORT_OK);

require Exporter;

@ISA = qw(Exporter AutoLoader);
#  Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.
@EXPORT_OK = qw();
$VERSION = version->new("3.0.0");

my $epsilon = 0.001;		# a milivolt

use strict;
use Carp;
use File::Spec;
use Storable;
use Chemistry::Elements qw(get_name get_Z get_symbol);

use constant PI    => 4*atan2(1,1);
use constant RE    => 0.00002817938; # Classical electron radius in Angstroms
use constant HBARC => 1973.2858;     # in eV*Angstrom

my $dbfile = File::Spec->catfile($Xray::Absorption::data_dir, "chantler.db");
my $r_chantler  = retrieve($dbfile);

$chantler_version = $$r_chantler{'version'};


=head1 METHODS

The behaviour of the methods in this module is a bit different from
other modules used by C<Xray::Absorption>.  This section describes
methods which behave differently for this data resource.

=cut

sub current_resource {
  "Chantler.pm version $VERSION, database version $chantler_version";
};

## is this element actually tabulated in these tables?
##    Xray::Absorption -> in_resource($elem) $elem can be Z, symbol, name
sub in_resource {
  shift;
  my $z = $_[0];
  $z = get_Z($z);
  (defined $z) || return 0;
  return 0 if $z < 1;
  return ( $z > 92 ) ? 0 : 1;
};

=over 4

=item C<get_energy>

Example:

   $energy = Xray::Absorption -> get_energy($elem, $edge);

This behaves similarly to the C<get_energy> method of the other
resources.  When using the Chantler data resource, C<$edge> can be any of
K, L1-L3, M1-M5, N1-N7, O1-O5, or P1-P3.  Line energies are not
supplied with the Chantler data set.  The line energies from the McMaster
tables are used.

=back

=cut

## $edge should be one of
##    Xray::Absorption -> get_energy($elem, $edge)
sub get_energy {
  shift;
  my ($sym,$edge) = @_;
  $sym = lc( get_symbol($sym) );
  Xray::Absorption -> in_resource($sym) || return 0;
  (defined $sym) || return 0;
  $edge = lc($edge);

  ## absorption edges
  if (($edge =~ /\b(k|l[1-3]|m[1-5]|n[1-7]|o[1-5]|p[1-3])\b/)
      and
      ($edge !~ /-\b(k|l[1-3]|m[1-5]|n[1-7]|o[1-5]|p[1-3])\b/)) {
    $edge = "energy_$edge";
    return (exists($$r_chantler{$sym}{$edge})) ? $$r_chantler{$sym}{$edge} : 0;
  };

  my $sieg_edge = lc(Xray::Absorption->get_Siegbahn($edge));
  if (($edge =~ /^ka/i) or ($sieg_edge =~ /^ka/i)) {
    ($edge = "energy_kalpha");
  };
  if (($edge =~ /^kb/i) or ($sieg_edge =~ /^kb/i)) {
    ($edge = "energy_kbeta");
  };
  if (($edge =~ /^la/i) or ($sieg_edge =~ /^la/i)) {
    ($edge = "energy_lalpha");
  };
  if (($edge =~ /^lb/i) or ($sieg_edge =~ /^lb/i)) {
    ($edge = "energy_lbeta");
  };
  return (exists($$r_chantler{$sym}{$edge})) ? $$r_chantler{$sym}{$edge} : 0;


  ## no such edge
  return 0;
};

## the list required by this method is preloaded into the database at
## install-time.
sub next_energy {
  shift;
  my $elem = shift;		# atom in question
  my $edge = shift;		# edge in question
  my @list = @_;		# other atoms in material
  my $hash = $$r_chantler{energy_list};
  my $key = lc($elem) . "_" . lc($edge);
  while (1) {
    my ($el, $ed, $en) = @{$$hash{$key}};
    return () unless defined $el;
    return ($el, $ed, $en) if (grep(/^$el$/i, @list));
    $key = lc($el) . "_" . lc($ed);
  };

};


sub data_available {
  shift;
  my ($sym, $edge) = @_;
  $sym = lc( get_symbol($sym) );
  $edge = lc($edge);
  (defined $sym) or return 0;
  Xray::Absorption -> in_resource($sym) or return 0;
  return exists($$r_chantler{$sym}{"energy_".$edge});
};


=over 4

=item C<cross_section>

Example:

   $xsec = Xray::Absorption -> cross_section($elem, $energy, $mode);

This behaves slightly differently from the similar method for the
McMaster and Elam resources.  The Chantler tables contain
anomalous scattering factors and the sum of the  coherent and
incoherent scattering cross-sections.  The photo-electric
cross-section is calculated from the imaginary part of the anomalous
scattering by the formula

     mu = 2 * r_e * lambda * conv * f_2

where, C<r_e> is the classical electron radius, lamdba is the photon
wavelength, and conv is a units conversion factor.

     r_e    = 2.817938 x 10^-15 m
     lambda = 2 pi hbar c / energy
     hbar*c = 1973.27053324 eV*Angstrom
     conv   = Avagadro / atomic weight
            = 6.022045e7 / weight in cgs

The C<$mode> argument is different here than for the other resources.
The options are "xsec", "f1", "f2", "photo", and "scatter" telling
this method to return the full cross-section cross-section, the real
or imaginary anomalous scattering factor, just the photoelectric
crosss-section, or just the coherent and incoherent scattering,
respectively.

The values for f1 and f2 are computed by linear interpolation of a
semi-log scale, as described in the literature reference.  Care is
taken to avoid the discontinuities at the edges.

=back

=cut

sub cross_section {
  shift;
  die "cross_section takes a single energy or a reference to an array\n" if
    ($#_ > 2);
  my ($sym, $energy, $mode) = @_;
  $sym = lc( get_symbol($sym) );
  my $z = get_Z($sym);
  Xray::Absorption -> in_resource($sym) || return 0;
  (defined $sym) || return 0;
  ## cache this hash element
  my $hash_element = $$r_chantler{$sym};
  my $n = $#{$$r_chantler{$sym}{energy}};
  my @ener;
  if (wantarray) {
    @ener = @$energy;
  } else {
    @ener = ($energy);
  };

  foreach (@ener) {
    if (($_ < $$r_chantler{$sym}{energy}->[0]) or
	($_ > $$r_chantler{$sym}{energy}->[$n]) ) {
      my $message = sprintf
	"The Chantler Tables for element %s are only valid " .
	  "between %7.4f and %7.1f eV%s",
	  ucfirst($sym), $$r_chantler{$sym}{energy}->[0],
	  $$r_chantler{$sym}{energy}->[$n], $/;
      $Xray::Absorption::verbose and warn $message;
      return 0;
    };
  };

  $mode ||= "xsec";
  ($mode = "scatter") if (($mode eq "coherent") or ($mode eq "incoherent"));
  ($mode =~ /\b(x|f[12]|p|s)/i) or $mode = "xsec";

  ## watch out for an input energy that is right at the edge
 EDGE_CHECK: foreach my $edge ("k" , "l1", "l2", "l3",
			       "m1", "m2", "m3", "m4", "m5",
			       "n1", "n2", "n3", "n4", "n5", "n6", "n7",
			       "o1", "o2", "o3", "o4", "o5", "o6", "o7",
			       "p1", "p2", "p3") {
    ## be sure the energy is more than 0.1 volt away from the edge to
    ## allow for effort-free spline interpolation.  see the chantler
    ## read.me file for a the reasoning behond choosing that number
    if (exists $$hash_element{"energy_".$edge}) {
      if (abs($energy - $$hash_element{"energy_".$edge}) < $epsilon) {
	($energy += 10*$epsilon);
	last EDGE_CHECK;
      };
    };
  };

  my (@fp, @fpp, @ph, @sc);
  if ($mode =~ /\b(f2|x|p)/i) {
    ## linear interpolation of log(fpp)
    my @x = @{$$hash_element{"energy"}};
    my @y = @{$$hash_element{"f2"}};
    foreach (@ener) {
      my $this = linterp(\@x, \@y, $_, $sym);
      push @fpp, exp( $this );
    };
    my $factor  = Xray::Absorption -> get_conversion($sym);
    my $weight  = Xray::Absorption -> get_atomic_weight($sym);
    foreach my $i (0 .. $#ener) {
      my $lambda  = 2 * PI * HBARC / $ener[$i];
      $ph[$i] = 2*RE * $lambda * $fpp[$i] * 0.6022045 * 1e8 * $factor / $weight;
    }; #                                                ^       ^
    ##                              avagadro's / barn __|       |
    ##                                        angstroms -> cm __|
  };
  if ($mode =~ /\bf1/i) {
    my @x = @{$$hash_element{"energy"}};
    my @y = @{$$hash_element{"f1"}};
    foreach my $i (0 .. $#ener) {
      push @fp, exp( linterp(\@x, \@y, $ener[$i], $sym) ) - $z;
    };
  };
  if ($mode =~ /\b(x|s)/i) {
    my @x = @{$$hash_element{"energy"}};
    my @y = @{$$hash_element{"scatt"}};
    foreach my $i (0 .. $#ener) {
      my $this = linterp_simple(\@x, \@y, $ener[$i]);
      $this = exp($this);
      push @sc, Xray::Absorption -> get_conversion($sym) * $this;
    };
  };

  ($mode =~ /\bf1/) and return wantarray ? @fp  : $fp[0];
  ($mode =~ /\bf2/) and return wantarray ? @fpp : $fpp[0];
  ($mode =~ /\bx/)  and do {
    my @ret = map {$ph[$_] + $sc[$_]} (0 .. $#ph);
    return wantarray ? @ret : $ret[0];
  };
  ($mode =~ /\bp/)  and return wantarray ? @ph : $ph[0];
  ($mode =~ /\bs/)  and return wantarray ? @sc : $sc[0];

  return 0; ## it should never get here!

};


## this linterp needs to know the element so that it can be sure not
## to interpolate thru an edge energy.
sub linterp {
  my ($xarray, $yarray, $x, $el) = @_;
  my $ilow   = binsearch($xarray, $x);

  my @list = ();
  foreach my $edge ("k" , "l1", "l2", "l3",
		    "m1", "m2", "m3", "m4", "m5",
		    "n1", "n2", "n3", "n4", "n5", "n6", "n7",
		    "o1", "o2", "o3", "o4", "o5", "o6", "o7",
		    "p1", "p2", "p3") {
    exists $$r_chantler{$el}{"energy_$edge"} and
      push @list, $$r_chantler{$el}{"energy_$edge"};
  };
  @list = sort @list;
  my $xlow = $xarray->[$ilow];
  my ($xabove, $xbelow) = (0,0);
 FIND: while (@list) {
    my $this = shift @list;
    if ($this > $x) {
      $xabove = $this;
      @list = ();
      last FIND;
    };
    $xbelow = $this;
  };
  my ($i1, $i2);
  if (not $xabove) {
    ($i1, $i2) = ($ilow, $ilow+1);
  } elsif ($xabove > $xarray->[$ilow+1]) {
    ($i1, $i2) = ($ilow, $ilow+1);
  } elsif (($xabove < $xarray->[$ilow+1]) and ($xabove > $x)) {
    ($i1, $i2) = ($ilow-1, $ilow);
  } elsif (($xabove < $xarray->[$ilow+1]) and ($xabove < $x)
	   and ($xabove < $xarray->[$ilow])) {
    ($i1, $i2) = ($ilow+1, $ilow+2);
  };
  my $deltax = $xarray->[$i2] - $xarray->[$i1];
  my $deltay = $yarray->[$i2] - $yarray->[$i1];
  my $span   = $x - $xarray->[$i1];
  return ( ($deltay * $span / $deltax) + $yarray->[$i1] );
};

sub linterp_simple {
  my ($xarray, $yarray, $x) = @_;
  my $ilow   = binsearch($xarray, $x);
  my $deltax = $xarray->[$ilow+1] - $xarray->[$ilow];
  my $deltay = $yarray->[$ilow+1] - $yarray->[$ilow];
  my $span   = $x - $xarray->[$ilow];
  return ( ($deltay * $span / $deltax) + $yarray->[$ilow] );
};

## Swiped from Math::Spline
sub binsearch { # binary search routine finds index just below value
  my ($x,$v)=@_;
  my ($klo,$khi)=(0,$#{$x});
  my $k;
  while (($khi-$klo)>1) {
    $k=int(($khi+$klo)/2);
    if ($x->[$k]>$v) { $khi=$k; } else { $klo=$k; }
  }
  return $klo;
}



1;

__END__


=head1 EDGE AND LINE ENERGIES

The Chantler data resource provides a fairly complete set of edge
energies.  Any edge tabulated on the Gwyn William's Table of Electron
Binding Energies for the Elements (that's the one published by NSLS
and on the door of just about every hutch at NSLS) is in the Chantler
data resource.  The Chantler data comes with the same, limited set of
fluorescence energies as McMaster.

=head1 BUGS AND THINGS TO DO

=over 4

=item *

It would be nice to improve the inter-/extrapolation near absorption
edges.  As it stands, these tables produce really poor DAFS output.

=back

=head1 AUTHOR

  Bruce Ravel, bravel AT bnl DOT gov
  http://bruceravel.github.io/demeter/

=cut
