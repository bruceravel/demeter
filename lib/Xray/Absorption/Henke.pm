##  This module is copyright (c) 1999-2007 Bruce Ravel
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
## Time-stamp: <1999/05/20 15:20:00 bruce>
######################################################################
## Code:

=head1 NAME

Xray::Absorption::Henke - Perl interface to the Henke tables

=head1 SYNOPSIS

   use Xray::Absorption;
   Xray::Absorption -> load("henke");

See the documentation for Xray::Absorption for details.

=head1 DESCRIPTION

This module is inherited by the Xray::Absorption module and provides
access to the data contained in the Henke tables of anomalous
scattering factors and line and edge energies.

The data in this module, referred to as "The Henke Tables", was
published as

  B. L. Henke, E. M. Gullikson, and J. C. Davis,
  Atomic Data and Nuclear Data Tables Vol. 54 No. 2 (July 1993).

The Henke data is available on the web at
http://www-cxro.lbl.gov/optical_constants/ and more information about
the data can be obtained from Eric Gullikson <EMGullikson@lbl.gov>.

The data is contained in a database file called F<henke.db> which is
generated at install time from the flat text files of the Henke data.
The data is stored in a Storable archive using "network" ordering.
This allows speedy disk and memory access along with network and
platform portability.

The required C<File::Spec>, C<Chemistry::Elements>, C<Storable>,
modules are available from CPAN.

=cut


package Xray::Absorption::Henke;

use strict;
use warnings;
use version;

use Exporter ();
use Config;
use Xray::Absorption;

use vars qw($VERSION $resource $line_rule $henke_version @ISA @EXPORT @EXPORT_OK);

require Exporter;

@ISA = qw(Exporter AutoLoader);
# Items to export into callers namespace by default. Note: do not export
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

my $dbfile = File::Spec->catfile($Xray::Absorption::data_dir, "henke.db");
my $r_henke  = retrieve($dbfile);

$henke_version = $$r_henke{'version'};

=head1 METHODS

The behaviour of the methods in this module is a bit different from
other modules used by C<Xray::Absorption>.  This section describes
methods which behave differently for this data resource.

=cut

sub current_resource {
  "Henke.pm version $VERSION, database version $henke_version";
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
resources.  When using the Henke data resource, C<$edge> can be any of
K, L1-L3, M1-M5, N1-N7, O1-O7, or P1-P3.  Line energies are not
supplied with the Henke data set.  The line energies from the McMaster
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
    return (exists($$r_henke{$sym}{$edge})) ? $$r_henke{$sym}{$edge} : 0;
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
  return (exists($$r_henke{$sym}{$edge})) ? $$r_henke{$sym}{$edge} : 0;


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
  my $hash = $$r_henke{energy_list};
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
  return (exists($$r_henke{$sym}{"energy_".$edge}) and
	  $$r_henke{$sym}{"energy_".$edge} > 0) ;
  ## what about values for which f1 is -9999?
};



=over 4

=item C<cross_section>

Examples:

   $xsec = Xray::Absorption -> cross_section($elem, $energy, $mode);

   @xsec = Xray::Absorption -> cross_section($elem, \@energy, $mode);

This behaves slightly differently from the similar method for the
McMaster and Elam resources.  The Henke tables are actually tables of
anomalous scattering factors and do not come with coherent and
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
The options are "xsec", "f1", and "f2", telling this method to return
the cross-section or the real or imaginary anomalous scattering
factor, respectively.

The values for f1 and f2 are computed by linear interpolation of a
semi-log scale.  Care is taken to avoid the discontinuities at the
edges.

Because the Henke tables do not include the coherent and incoherent
scattering terms, the value returned by C<get_energy> may be a bit
smaller using the Henke tables than that from the McMaster tables.

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
  my $hash_element = $$r_henke{$sym};
  my $n = $#{$$r_henke{$sym}{energy}};
  my @ener;
  if (wantarray) {
    @ener = @$energy;
  } else {
    @ener = ($energy);
  };

  foreach (@ener) {
    if (($_ < $$r_henke{$sym}{energy}->[0]) or
	($_ > $$r_henke{$sym}{energy}->[$n]) ) {
      my $message = sprintf
	"The Henke Tables for element %s are only valid " .
	  "between %7.4f and %7.1f eV%s",
	  ucfirst($sym), $$r_henke{$sym}{energy}->[0],
	  $$r_henke{$sym}{energy}->[$n], $/;
      $Xray::Absorption::verbose and warn $message;
      return 0;
    };
  };


  $mode ||= "xsec";
  ($mode =~ /\b(x|f[12])/i) or $mode = "xsec";

  ## watch out for an input energy that is right at the edge
 EDGE_CHECK: foreach my $edge ("k" , "l1", "l2", "l3",
			       "m1", "m2", "m3", "m4", "m5",
			       "n1", "n2", "n3", "n4", "n5", "n6", "n7",
			       "o1", "o2", "o3", "o4", "o5", "o6", "o7",
			       "p1", "p2", "p3") {
    ## be sure the energy is more than 0.1 volt away from the edge to
    ## allow for effort-free spline interpolation.  see the henke
    ## read.me file for a the reasoning behond choosing that number
    if (exists $$hash_element{"energy_".$edge}) {
      my $diff = $energy - $$hash_element{"energy_".$edge};
      if (abs($diff) < (0.1+$epsilon)) {
	if ( $diff > 0 ) {
	  ($energy += 0.1+$epsilon);
	  last EDGE_CHECK;
	} elsif ( $diff < 0 ) {
	  ($energy -= 0.1+$epsilon);
	  last EDGE_CHECK;
	};
      };
    };
  };


  if ($mode =~ /\b(f2|x)/i) {
    ## linear interpolation of log(fpp)
    my @x = @{$$hash_element{"energy"}};
    ## my @y = map {log} @{$$hash_element{"f2"}};
    my @y = @{$$hash_element{"f2"}};
    my @fpp;
    foreach (@ener) {
      my $this = linterp(\@x, \@y, $_);
      push @fpp, exp( $this );
    };
    if ($mode =~ /\bf2/) {
      return wantarray ? @fpp : $fpp[0];
    } else {
      my $factor  = Xray::Absorption -> get_conversion($sym);
      my $weight  = Xray::Absorption -> get_atomic_weight($sym);
      my @mu;
      foreach my $i (0 .. $#ener) {
	my $lambda  = 2 * PI * HBARC / $ener[$i];
	$mu[$i] = 2*RE * $lambda * $fpp[$i] * 0.6022045 * 1e8 * $factor / $weight;
      }; #                                                ^       ^
      ##                                                  |       |
      ##                              avagadro's / barn __|       |
      ##                                        angstroms -> cm __|
      #($mode =~ /\bx/) and return wantarray ? @mu : $mu[0];
      return wantarray ? @mu : $mu[0];
    };
  } elsif ($mode =~ /\bf1/i) {
    my @x = @{$$hash_element{"energy"}};
    ## my @y = map {log} @{$$hash_element{"f1"}};
    my @y = @{$$hash_element{"f1"}};
    my @fp;
    foreach my $i (0 .. $#ener) {
      push @fp, exp( linterp(\@x, \@y, $ener[$i]) ) - $z;
    };
    return wantarray ? @fp : $fp[0];
  };

  return 0; ## it should never get here!

};


sub linterp {
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

The Henke data resource provides a fairly complete set of edge
energies.  Any edge tabulated on the Gwyn William's Table of Electron
Binding Energies for the Elements (that's the one published by NSLS
and on the door of just about every hutch at NSLS) is in the Henke
data resource.  The Henke data comes with the same, limited set of
fluorescence energies as McMaster.

=head1 BUGS AND THINGS TO DO

=over 4

=item *

It would be nice to improve the inter-/extrapolation near absorption
edges.  As it stands, these tables produce really poor DAFS output.

=back

=head1 AUTHOR

  Bruce Ravel, http://bruceravel.github.io/home
  http://bruceravel.github.io/demeter/

=cut
