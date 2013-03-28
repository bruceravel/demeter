##  This module is copyright (c) 1999-2007 Bruce Ravel
##  <bravel AT bnl DOT gov>
##  http://bruceravel.github.com/demeter/
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

Xray::Absorption::Elam - Perl interface to the Elam tables

=head1 SYNOPSIS

   use Xray::Absorption;
   Xray::Absorption -> load("elam");

See the documentation for Xray::Absorption for details.

=head1 DESCRIPTION

This module is inherited by the Xray::Absorption module and provides
access to the data contained in the 1999 Elam tables of absorption
cross-sections and line and edge energies.

The data in this module, here referred to as "The Elam Tables", will
be published real soon.  The compilation of data is the work of Tim
Elam (tim.elam@nrl.navy.mil).

The data is contained in a database file called F<elam.db> which is
generated at install time from a flat text database of the Elam data.
The data is stored in a Storable archive using "network" ordering.
This allows speedy disk and memory access along with network and
platform portability.

The required C<Chemistry::Elements>, C<Math::Spline>, and
C<Math::Derivative> modules are available from CPAN.

=head1 LITERATURE REFERENCES

K-shell fluorescence yield below Z=11 from new fits in J. H. Hubbell
et. al.,  J. Chem. Phys. Ref. Data, Vol. 23, No. 2, 1994, pp. 339-364.

Fluorescence yields and Coster-Kronig transition rates for K and L
shells Krause, J. Phys. Chem. Ref. Data, Vol. 8, No. 2, 1979,
pp. 307-327.  values for wK, wL2,and f23 are from Table 1. (values for
light atoms in condensed matter) (note that this produces a large step
in f23 values at z=30, see discussion in reference section 5.3 L2
Subshell and section 7 last paragraph)

Values of wL1 for Z=85-110 and f12 for Z=72-96 from Krause were
modified as suggested by W. Jitschin, "Progress in Measurements of
L-Subshell Fluorescence, Coster-Kronig, and Auger Values", AIP
Conference Proceedings 215, X-ray and Inner-Shell Processes,
Knocxville, TN, 1990. T. A. Carlson, M. O. Krause, and S. T. Manson,
Eds. (American Institute of Physics, 1990).

Fluorescence yields and Coster-Kronig transition rates for M shells
Eugene J. McGuire, "Atomic M-Shell Coster-Kronig, Auger, and Radiative
Rates, and Fluorescence Yields for Ca-Th", Physical Review A, Vol. 5,
No. 3, March 1972, pp. 1043-1047.

Fluorescence yields and Coster-Kronig transition rates for N shells
Eugene J. McGuire, "Atomic N-shell Coster-Kronig, Auger, and Radiative
Rates and Fluorescence Yields for 38 <= Z <= 103", Physical Review A
9, No. 5, May 1974, pp. 1840-1851.  Values for Z=38 to 50 were
adjusted according to instructions on page 1845, at the end of Section
IV.a., and the last sentence of the conclusions.

Relative emission rates, fits to low-order polynomials, low-Z
extrapolations by hand and eye data from Salem, Panossian, and Krause,
Atomic Data and Nuclear Data Tables Vol. 14 No.2 August 1974,
pp. 92-109.  M shell data is from T. P. Schreiber and A. M. Wims,
X-ray Spectrometry Vol. 11, No. 2, 1982, pp. 42-45.  Small, arbitrary
intensities assigned to Mgamma and Mzeta lines.

Cross sections are in cm2/gm vs energy in eV.  Berger and
Hubbell above 1 keV, Plechaty et. al. below.

Reference: M. J. Berger and J. H. Hubbell, XCOM: Photon Cross Sections
on a Personal Computer, Publication NBSIR 87-3597, National Bureau of
Standards, Gaithersburg, MD, 1987.  Machine-readable data from
J. H. Hubbell, personal communication, Nov. 9, 1998.  The data were
updated as of May 7, 1998 (XCOM Version 2.1).

Reference: Plechaty, E. F., Cullen, D. E., and Howerton,R.J, "Tables
and Graphs of Photon Interaction Cross Sections from 0.1 keV to 100
MeV Derived from the LLL Evaluated Nuclear Data Library," Report
UCRL-50400, Vol. 6, Rev. 3, NTIS DE82-004819, Lawrence Livermore
National Laboratory, Livermore, CA. (1981).  Machine-readable data
from D. B. Brown, Naval Research Laboratory.


=cut

package Xray::Absorption::Elam;

use strict;
use warnings;
use version;

use Exporter ();
use Config;
use Xray::Absorption;

use vars qw($VERSION $resource $line_rule $elam_version @ISA @EXPORT @EXPORT_OK);

require Exporter;

@ISA = qw(Exporter AutoLoader);
# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.
@EXPORT_OK = qw();
$VERSION = version->new("3.0.0");

my $epsilon = 0.001;		# a milivolt
$line_rule = "weighted";	# "brightest"

# Preloaded methods go here.

use strict;
use Carp;
use Storable;
use Chemistry::Elements qw(get_name get_Z get_symbol);
use Math::Spline qw(spline binsearch);


use File::Spec;
my $dbfile = File::Spec->catfile($Xray::Absorption::data_dir, "elam.db");
use vars qw($r_elam);
$r_elam   = retrieve($dbfile);


$elam_version = join("", $$r_elam{'version'}, " (", $$r_elam{'date'}, ")");


=head1 METHODS

The behaviour of the C<get_energy> method in this module is a bit
different from other modules used by C<Xray::Absorption>.  This
section describes methods which behave differently for this data
resource and methods offered by this module which are not available
for other resources.

=cut



## ---- METHODS -----------------------------------------------

sub current_resource {
  "Elam.pm version $VERSION, database version $elam_version";
};

## is this element actually tabulated in these tables?
##    Xray::Absorption -> in_resource($elem) $elem can be Z, symbol, name
sub in_resource {
  shift;
  my $z = $_[0];
  $z = get_Z($z);
  (defined $z) || return 0;
  return 0 if $z < 1;
  return ( $z > 98 ) ? 0 : 1;
};

=over 4

=item C<get_energy>

Example:

   $energy = Xray::Absorption -> get_energy($elem, $edge)

This behaves similarly to the C<get_energy> method of othe resources,
except there are some differences regarding the syntax of specifying
C<$edge>.  When using the Elam data resource, C<$edge> can be any of
K, L1-L3, M1-M5, N1-N7, O1-O7, or P1-P3.  To get a fluorescence line,
you may use any Siegbahn or IUPAC symbol to specify the line.  See the
pod in C<Xray::Absorption> for details about these symbols.  You may
also specify a "generic" Siegbahn symbol, such as Kalpha.  The energy
that is returned depends on the value of an internal variable which
may be set using the C<line_toggle> method.  If the toggle is set to
"brightest", the energy of the brightest line of the class is
returned.  In the case of "Kalpha", the energy or the Kalpha1 line is
returned.  If the toggle is set to "weighted" then the intestity
weighted average energy of all lines of the class is returned.
"weighted" is the default.

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
    return (exists($$r_elam{$sym}{$edge})) ? $$r_elam{$sym}{$edge} : 0;
  };

  ## fluorescence lines
  my $sieg_edge = lc(Xray::Absorption->get_Siegbahn($edge));
  if ($sieg_edge) {
    $edge = "energy_" . $sieg_edge;
    return (exists($$r_elam{$sym}{$edge})) ? $$r_elam{$sym}{$edge} : 0;
  }

  ## non-specfic fluorescence lines
  if ($edge =~ /\b([kl])a(lpha)?\b/) {
    my $sum = 0;
    if ($line_rule eq "weighted") {
      my $origin = $$r_elam{$sym}{"energy_".$1."a1"};

      (exists($$r_elam{$sym}{"energy_".$1."a2"})) and
	($sum -= ($origin-$$r_elam{$sym}{"energy_".$1."a2"}) *
	         $$r_elam{$sym}{"intensity_".$1."a2"});

      (exists($$r_elam{$sym}{"energy_".$1."a3"})) and
	($sum -= ($origin-$$r_elam{$sym}{"energy_".$1."a3"}) *
 	         $$r_elam{$sym}{"intensity_".$1."a3"});
      $sum += $origin;

    } elsif ($line_rule eq "brightest") {
      my %intenisties =
	("energy_".$1."a1" =>
	 ($$r_elam{$sym}{"intensity_".$1."a1"} || 0),
	 "energy_".$1."a2" =>
	 ($$r_elam{$sym}{"intensity_".$1."a2"} || 0),
	 "energy_".$1."a3" =>
	 ($$r_elam{$sym}{"intensity_".$1."a3"} || 0),
	);
      my @sorted = sort {$intenisties{$b} <=> $intenisties{$a}}
      (keys %intenisties);
      $sum = $$r_elam{$sym}{$sorted[0]};

    };
    return $sum;
  };

  if ($edge =~ /([kl])b(eta)?/) {
    my $sum = 0;
    if ($line_rule eq "weighted") {

      my $origin = $$r_elam{$sym}{"energy_".$1."b1"};

      foreach my $s ("b2", "b3", "b4", "b5", "b6") {
	(exists($$r_elam{$sym}{"energy_".$1.$s})) and
	  ($sum -= ($origin-$$r_elam{$sym}{"energy_".$1.$s}) *
	            $$r_elam{$sym}{"intensity_".$1.$s});
      };
      $sum += $origin;

    } elsif ($line_rule eq "brightest") {
      my %intenisties =
	("energy_".$1."b1" =>
	 ($$r_elam{$sym}{"intensity_".$1."b1"} || 0),
	 "energy_".$1."b2" =>
	 ($$r_elam{$sym}{"intensity_".$1."b2"} || 0),
	 "energy_".$1."b3" =>
	 ($$r_elam{$sym}{"intensity_".$1."b3"} || 0),
	 "energy_".$1."b4" =>
	 ($$r_elam{$sym}{"intensity_".$1."b4"} || 0),
	 "energy_".$1."b5" =>
	 ($$r_elam{$sym}{"intensity_".$1."b5"} || 0),
	 "energy_".$1."b6" =>
	 ($$r_elam{$sym}{"intensity_".$1."b6"} || 0),
	);
      my @sorted = sort {$intenisties{$b} <=> $intenisties{$a}}
      (keys %intenisties);
      $sum = $$r_elam{$sym}{$sorted[0]};

    };
    return $sum;
  };

  if ($edge =~ /lg(amma)?\b/) {
    my $sum = 0;
    if ($line_rule eq "weighted") {

      my $origin = $$r_elam{$sym}{"energy_lg1"};

      foreach my $s ("g2", "g3", "g6") {
	(exists($$r_elam{$sym}{"energy_l".$s})) and
	  ($sum -= ($origin-$$r_elam{$sym}{"energy_l".$s}) *
	            $$r_elam{$sym}{"intensity_l".$s});
      };
      $sum += $origin;

    } elsif ($line_rule eq "brightest") {
      my %intenisties =
	("energy_lg1" =>
	 ($$r_elam{$sym}{"intensity_lg1"} || 0),
	 "energy_lg2" =>
	 ($$r_elam{$sym}{"intensity_lg2"} || 0),
	 "energy_lg3" =>
	 ($$r_elam{$sym}{"intensity_lg3"} || 0),
	 "energy_lg6" =>
	 ($$r_elam{$sym}{"intensity_lg6"} || 0),
	);
      my @sorted = sort {$intenisties{$b} <=> $intenisties{$a}}
      (keys %intenisties);
      $sum = $$r_elam{$sym}{$sorted[0]};

    };
    return $sum;
  };

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
  my $hash = $$r_elam{energy_list};
  my $key = lc($elem) . "_" . lc($edge);
  while (1) {
    my ($el, $ed, $en) = @{$$hash{$key}};
    return () unless defined $el;
    return ($el, $ed, $en) if (grep(/^$el$/i, @list));
    $key = lc($el) . "_" . lc($ed);
  };

};


=over 4

=item C<line_toggle>

Toggle the method of computing a generic fluorescence line between
"weighted" and "brightest".  This determines the response to a use of
C<get_energy> like this:

  $energy = Xray::Absorption -> line_toggle("brightest");
  $energy = Xray::Absorption -> get_energy("cu", "kalpha");
  $energy = Xray::Absorption -> line_toggle("wieghted");
  $energy = Xray::Absorption -> get_energy("cu", "kalpha");

When "weighted" is selected, this returns the intensity weighted
energy of the various Kalpha lines.  When "brightest" is chosen, this
returns the energy of the Kalpha1 line because that is the brightest
Kalpha line.  The default is "weighted".  Case does not matter for the
argument, but spelling does.  If the argument is not spelled correctly
then the calculation method is not toggled.

=back

=cut

sub line_toggle {
  shift;
  my $choice = lc($_[0]);
  ($choice eq "weighted")  and ($line_rule = "weighted");
  ($choice eq "brightest") and ($line_rule = "brightest");
};

## MN 21-May-2008 add fluorescence yield and edge jump

=over 4

=item C<fluor_yield>

Return the fluorescence yield for an atomic symbol and edge

  $fyield = Xray::Absorption -> fluor_yield("cu", "k");

The value returned is the probability of an fluorescent x-ray being emitted
for an absorption event.
Data comes from M. O. Krause, J. Phys. Chem. Ref. Data 8, 307 (1979)
Returns -1 for non-interpretable input

=back

=cut

sub fluor_yield {
  shift;
  my ($sym, $edge) = @_;
  $sym = lc( get_symbol($sym) );
  $edge = lc($edge);
  return (exists($$r_elam{$sym}{"yield_".$edge})) ? $$r_elam{$sym}{"yield_".$edge} : -1;
};

=over 4

=item C<edge_jump>

Return edge jump ratio for an atomic symbol and edge
   
  $jump = Xray::Absorption -> edge_jump("cu", "k");

The value returned is the ratio of the above-edge absorption coefficient 
to the below-edge coefficient


=back

=cut

sub edge_jump {
  shift;
  my ($sym, $edge) = @_;
  $sym = lc( get_symbol($sym) );
  $edge = lc($edge);
  return (exists($$r_elam{$sym}{"jump_".$edge})) ? $$r_elam{$sym}{"jump_".$edge} : 0;
};

=over 4

=item C<get_intesity>

Example:

   $intensity = Xray::Absorption -> get_intesity($elem, $symbol)

Get the relative amount of the line specified by $symbol for the
element $elem.  $elem can be a two letter symbol, a full name, or a Z
number.  $symbol may be either a Siegbahn or IUPAC symbol.  The
intesities are such that all lines of a type (e.g. all Kalpha lines)
have intesities which sum to 1.  If $elem or $symbol is not
recognized, then this returns 0.

=back

=cut

sub get_intensity {
  shift;
  my $el = lc( get_symbol($_[0]) );
  my $sym = lc( Xray::Absorption -> get_Siegbahn($_[1]) );
  $sym = "intensity_" . $sym;
  return exists($$r_elam{$el}{$sym}) ? $$r_elam{$el}{$sym} : 0;
};


sub data_available {
  shift;
  my ($sym, $edge) = @_;
  $sym = lc( get_symbol($sym) );
  $edge = lc($edge);
  (defined $sym) or return 0;
  Xray::Absorption -> in_resource($sym) or return 0;
  (exists($$r_elam{$sym}{"energy_".$edge})) or return 0;
  my $energy = Xray::Absorption->get_energy($sym,$edge);
  (($energy < 100) or ($energy > 1000000) ) and return 0;
  return 1;
};

=over 4

=item C<cross_section>

Example:

   $xsec = Xray::Absorption -> cross_section($elem, $energy, $mode);

   @xsec = Xray::Absorption -> cross_section($elem, \@energy, $mode);


The C<$mode> argument is different here than for the other resources.
The options are "xsec", "photo", "coherent" and "incoherent", telling
this method to return the full cross-section or just the
photoelectric, coherent, or incoherent portions.

The values for all cross-sections are computed using spline
interpolation as described in the paper by Elam, Ravel, and Siebert.

=back

=cut

sub cross_section {
  shift;
  die "cross_section takes a single energy or a reference to an array\n" if
    ($#_ > 2);
  my ($sym, $energy, $mode) = @_;
  $sym = lc( get_symbol($sym) );
  Xray::Absorption -> in_resource($sym) || return 0;
  (defined $sym) || return 0;
  ($energy > $epsilon) || return 0;
  ## cache this hash element
  my $hash_element = $$r_elam{$sym};

  my @ener;
  if (wantarray) {
    @ener = @$energy;
  } else {
    @ener = ($energy);
  };

  foreach (@ener) {
    if (($_ < 100) or ($_ > 1000000) ) {
      my $message =
	"The Elam Tables are only valid between 100 and 1,000,000 eV.$/";
      $Xray::Absorption::verbose and warn $message;
      return 0;
    };
  };

  $mode ||= "full";
  $mode = "full" if ($mode eq 'xsec');
  ($mode =~ /^[fpci]/i) or $mode = "full";

  ## watch out for an input energy that is right at the edge
 EDGE_CHECK: foreach my $edge ("k" , "l1", "l2", "l3",
			       "m1", "m2", "m3", "m4", "m5",
			       "n1", "n2", "n3", "n4", "n5", "n6", "n7",
			       "o1", "o2", "o3", "o4", "o5", "o6", "o7",
			       "p1", "p2", "p3") {
    ##  define the edge to be 10 meV above the edge
    if ((exists $$hash_element{"energy_".$edge}) and
	(abs($energy - $$hash_element{"energy_".$edge}) < $epsilon)) {
      ($energy += 10*$epsilon);
      last EDGE_CHECK;
    };
  };

  @ener = map {log($_)} @ener;

  my ($x, $y, $y2, $index, @photo, @coh, @inc);
  ## the photoabsorption portion
  if ($mode =~ /^[fp]/i) {
    $x     = $$hash_element{"photo"}{"energy"};
    $y     = $$hash_element{"photo"}{"xsec"};
    $y2    = $$hash_element{"photo"}{"second"};
    foreach (@ener) {
      $index = binsearch($x, $_);
      push @photo, spline($x, $y, $y2, $index, $_);
    };
  };

  ## the coherent portion
  if ($mode =~ /^[fc]/i) {
    $x	   = $$hash_element{"scatter"}{"energy"};
    $y	   = $$hash_element{"scatter"}{"coh"};
    $y2	   = $$hash_element{"scatter"}{"coh2"};
    foreach (@ener) {
      $index = binsearch($x, $_);
      push @coh, spline($x, $y, $y2, $index, $_);
    };
  };

  ## the incoherent portion
  if ($mode =~ /^[fi]/i) {
    $x	   = $$hash_element{"scatter"}{"energy"};
    $y	   = $$hash_element{"scatter"}{"inc"};
    $y2	   = $$hash_element{"scatter"}{"inc2"};
    foreach (@ener) {
      $index = binsearch($x, $_);
      push @inc, spline($x, $y, $y2, $index, $_);
    };
  };

  my $factor = Xray::Absorption -> get_conversion($sym);
  @photo = map {$factor*exp($_)} @photo;
  @coh   = map {$factor*exp($_)} @coh;
  @inc   = map {$factor*exp($_)} @inc;
  ($mode =~ /^f/i) and do {
    my @ret = map {$photo[$_] + $coh[$_] +$inc[$_]} (0 .. $#photo);
    return wantarray ? @ret : $ret[0];
  };
  ($mode =~ /^p/i) and return wantarray ? @photo : $photo[0];
  ($mode =~ /^c/i) and return wantarray ? @coh   : $coh[0];
  ($mode =~ /^i/i) and return wantarray ? @inc   : $inc[0];

};

1;

__END__


=head1 EDGE AND LINE ENERGIES

The Elam data resource provides a fairly complete set of edge and line
energies.  Any edge tabulated on the Gwyn William's Table of Electron
Binding Energies for the Elements (that's the one published by NSLS
and on the door of just about every hutch at NSLS) is in the Elam data
resource.  Additionally, a large but not exhaustive collection of line
energies is tabulated.  Every line in the table in the B<SYMBOLS FOR
FLUORESCENCE LINES> section of the C<Absorption.pm> pod is included in
the Elam tables.  A reasonable value for the relative line intensity
if also included in this table.  See (the elam reference) for a
discussion of which lines were included in the tables and how the
intensities were calculated.

=head1 BUGS AND THINGS TO DO

=over 4

=item *

The "weighted" option for C<get_energy> is not quite right in that it
counts in lines from different edges.  While that might be
appropriate, there is some question as to the relative weights of
lines from different edges.  So a better solution would be to only use
lines from the edge directly below the chosen energy.

=back

=head1 AUTHOR

  Bruce Ravel, bravel AT bnl DOT gov
  http://bruceravel.github.com/demeter/

=cut
