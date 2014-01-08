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

Xray::Absorption::CL - Perl interface to the Cromer-Liberman tables

=head1 SYNOPSIS

   use Xray::Absorption;
   Xray::Absorption -> load("cl");

See the documentation for Xray::Absorption for details.

=head1 DESCRIPTION

This module is inherited by the Xray::Absorption module and provides
access to the data contained in the Cromer-Liberman tables of anomalous
scattering factors and line and edge energies.

The data in this module and the Fortran code which it calls as a
shared library, referred to as "The CL Tables", was published as

  S. Brennan and P.L. Cowen, Rev. Sci. Instrum, vol 63,
  p.850 (1992)

More information about these data is available on the Web at

   http://www.slac.ssrl.stanford.edu/absorb.html.

The values for the anomalous scattering factors are calculated by
calls to the Ifeffit library by Matt Newville.

The values of edge and line energies are contained in a database file
called F<cl.db> which is generated at install time from the flat
text files of the these data.  The data is stored in a Storable
archive using "network" ordering.  This allows speedy disk and memory
access along with network and platform portability.

The required C<File::Spec>, C<Chemistry::Elements>, C<Storable> are
available from CPAN.

=cut


package Xray::Absorption::CL;

use strict;
use warnings;
use version;

use Exporter ();
use Config;
use Xray::Absorption;

use vars qw($VERSION $resource $line_rule $cl_version @ISA @EXPORT @EXPORT_OK);

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
#use Xray::Absorption::CLdata qw(cl_f1 cl_f2);
## the next two line initialize Ifeffit under perl without changing
## any ifeffit global variables
my $foo = Ifeffit::get_scalar("\&screen_echo");
Ifeffit::ifeffit("\&screen_echo = $foo\n");

use constant PI    => 4*atan2(1,1);
use constant RE    => 0.00002817938; # Classical electron radius in Angstroms
use constant HBARC => 1973.2858;     # in eV*Angstrom

my $dbfile = File::Spec->catfile($Xray::Absorption::data_dir, "cl.db");
my $r_cl     = retrieve($dbfile);

$cl_version = $$r_cl{'version'};


=head1 METHODS

The behaviour of the methods in this module is a bit different from
other modules used by C<Xray::Absorption>.  This section describes
methods which behave differently for this data resource.

=cut

sub current_resource {
  "CL.pm version $VERSION, database version $cl_version";
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
resources.  When using the CL data resource, C<$edge> can be any of
K, L1-L3, M1-M5, N1-N7, O1-O7, or P1-P3.  Line energies are not
supplied with the CL data set.  The line energies from the McMaster
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
    return (exists($$r_cl{$sym}{$edge})) ? $$r_cl{$sym}{$edge} : 0;
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
  return (exists($$r_cl{$sym}{$edge})) ? $$r_cl{$sym}{$edge} : 0;


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
  my $hash = $$r_cl{energy_list};
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
  return exists($$r_cl{$sym}{"energy_".$edge});
  ## worry about very low eneries
};


=over 4

=item C<cross_section>

Example:

   $xsec = Xray::Absorption -> cross_section($elem, $energy, $mode);

   @xsec = Xray::Absorption -> cross_section($elem, \@energy, $mode);

For this data resource, one call in list context is considerably
faster than repeated calls in scalar context.  It is well worth the
trouble of organizing your code to make a single call in list context
and store the results for later use.

This behaves slightly differently from the similar method for the
McMaster and Elam resources.  The CL tables are actually tables of
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

Because the CL tables do not include the coherent and incoherent
scattering terms, the value returned by C<get_energy> is a bit smaller
using the CL tables than using the others.

=back

=cut

sub cross_section {
  shift;
  die "cross_section takes a single energy or a reference to an array\n" if
    ($#_ > 2);
  my ($sym, $energy, $mode) = @_;
  ##print wantarray ? "array context\n" : "scalar context\n";
  $sym = lc( get_symbol($sym) );
  my $z = get_Z($sym);
  Xray::Absorption -> in_resource($sym) || return 0;
  (defined $sym) || return 0;
  ## cache this hash element
  my $hash_element = $$r_cl{$sym};
##   my $n = $#{$$r_cl{$sym}{energy}};
##   if (($energy < $$r_cl{$sym}{energy}->[0]) or
##       ($energy > $$r_cl{$sym}{energy}->[$n]) ) {
##     my $message = sprintf
##       "The CL Tables for element %s are only valid " .
## 	"between %7.4f and %7.1f eV%s",
## 	ucfirst($sym), $$r_cl{$sym}{energy}->[0],
## 	$$r_cl{$sym}{energy}->[$n], $/;
##     $Xray::Absorption::verbose and warn $message;
##     return 0;
##   };
  ## watch out for an input energy that is right at the edge
 EDGE_CHECK: foreach my $edge ("k" , "l1", "l2", "l3",
			       "m1", "m2", "m3", "m4", "m5",
			       "n1", "n2", "n3", "n4", "n5", "n6", "n7",
			       "o1", "o2", "o3", "o4", "o5", "o6", "o7",
			       "p1", "p2", "p3") {
    ##  define the dge to be 10 meV above the edge
    if ((exists $$hash_element{"energy_".$edge}) and
	(abs($energy - $$hash_element{"energy_".$edge}) < $epsilon)) {
      ($energy += 10*$epsilon);
      last EDGE_CHECK;
    };
  };

  ## fetch Cromer-Liberman values from Ifeffit.  Ifeffit requires that
  ## arrays be 2 or more elements long, so tack on a throw-away value
  my @ener;
  if (wantarray) {
    @ener = @$energy;
  } else {
    @ener = ($energy, $energy+$epsilon/10);
  };
  Ifeffit::put_array("absorption_cl.energy", \@ener);
  Ifeffit::ifeffit("f1f2(z=$z, energy=absorption_cl.energy)\n");
  my @f1 = Ifeffit::get_array("absorption_cl.f1");
  my @f2 = Ifeffit::get_array("absorption_cl.f2");
  #print join(" ", @f1), $/;
  #print join(" ", @f2), $/;

  $mode ||= "xsec";
  ($mode =~ /\b(x|f[12])/i) or $mode = "xsec";

  if ($mode =~ /\b(f2|x)/i) {
    ##my $fpp = cl_f2($z, $energy);  # using old CLdata
    if ($mode =~ /\bf2/) {
      return wantarray ? @f2 : $f2[0];
    } else {

      my $factor  = Xray::Absorption -> get_conversion($sym);
      my $weight  = Xray::Absorption -> get_atomic_weight($sym);
      my @mu;
      foreach my $i (0 .. $#ener) {
	my $lambda  = 2 * PI * HBARC / $ener[$i];
	$mu[$i] = 2*RE * $lambda * $f2[$i] * 0.6022045 * 1e8 * $factor / $weight;
      }; #                                                ^       ^
      ##                                                  |       |
      ##                              avagadro's / barn __|       |
      ##                                        angstroms -> cm __|
      ($mode =~ /\bx/) and return wantarray ? @mu : $mu[0];
      #($mode =~ /\bx/) and return $mu;
    };
  } elsif ($mode =~ /\bf1/i) {
    ##my $fp = cl_f1($z, $energy);  # using old CLdata
    return wantarray ? @f1 : $f1[0];
  };

  return 0; ## it should never get here!

};





1;

__END__


=head1 EDGE AND LINE ENERGIES

The CL data resource provides a fairly complete set of edge energies.
Any edge tabulated on the Gwyn William's Table of Electron Binding
Energies for the Elements (that's the one published by NSLS and on the
door of just about every hutch at NSLS) is in the CL data resource.
The CL data comes with the same, limited set of fluorescence energies
as McMaster.

=head1 BUGS AND THINGS TO DO

None that I know about...

=head1 AUTHOR

  Bruce Ravel, bravel AT bnl DOT gov
  http://bruceravel.github.io/demeter/

=cut
