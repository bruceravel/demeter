## Time-stamp: <2011-03-10 17:24:36 bruce>
######################################################################
##  This module is copyright (c) 1999-2013 Bruce Ravel
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
## Code:

=head1 NAME

Xray::Absorption - X-ray absorption data for the elements

=head1 SYNOPSIS

   use Xray::Absorption;
   Xray::Absorption -> load("mcmaster");
   $xsec = Xray::Absorption->cross_section('Cu', 9000);

This example returns the cross section of Copper at 9000 eV using the
McMaster tables.

=head1 DESCRIPTION

This module supports access to X-ray absorption data.  It is designed
to be a transparent interface to absorption data from a variety of
sources.  Currently, the only sources of data are the 1969 McMaster
tables, the 1999 Elam tables, the 1993 Henke tables, and the 1995
Chantler tables.  The Brennan-Cowen implementation of the
Cromer-Liberman tables is available as a drop-on-top addition to this
package.  More resources can be added easily.

Information used to compute the mass energy-absorption coefficient is
taken from the tabulations of Hubbell and Seltzer:
http://physics.nist.gov/PhysRefData/XrayMassCoef/cover.html

Because this is an object-oriented approach to X-ray absorption data,
you must call subroutines as class methods rather than as subroutines:

   $xsec = Xray::Absorption->cross_section('Cu', 9000);

is correct, but

   $xsec = Xray::Absorption::cross_section('Cu', 9000);

is incorrect.  Using class methods rather than a function oriented
approach allows the user of the C<Xray::Absorption> module to I<hot
swap> absorption data resources.  For example

   foreach $resource (Xray::Absorption->available) {
     Xray::Absorption->load($resource);
     print $resource, " : ",
	   Xray::Absorption->cross_section('Cu', 9000), $/;
   };

compares the cross section of copper at 9 keV as calculated from the
all available data resources.

It is necessary to initialize C<Xray::Absorption> to use a particular
database by invoking the C<load> method.  This method establishes and
changes inheritance.

=head1  METHODS

=over 4

=item C<current_resource>

Example:

   $this = Xray::Absorption -> current_resource;

Identifies the currently selected resource.

=item C<in_resource>

Example:

   $is_there = Xray::Absorption -> in_resource($elem);

Returns true if C<$elem> is tabulated in the current resource.
C<$elem> can be a two letter symbol, the full name of the element, or
a Z number.

=item C<get_energy>

Example:

   $energy = $energy = Xray::Absorption -> get_energy($elem, $edge);

Returns the edge energy for C<$elem>.  C<$edge> is one of K, L1, L2,
L3, M1, etc.  C<$edge> may also be the Siegbahn or IUPAC symbol for a
fluorescence line.  Some data resources provide more lines than
others.  Some may provide no lines at all.  See the documentation for
each resource for which lines are available.  When either C<$elem> or
C<$edge> is an unrecognized symbol, this method returns 0.

=item C<next_energy>

Example:

   $next = Xray::Absorption -> next_energy($elem, $edge, @list);

Given a list of atomic symbols C<@list>, return a list containing the
element symbol, edge symbol, and energy in eV of the next highest edge
energy after the C<$edge> edge of C<$elem>.  This returns an empty list
if the any argument is unrecognizable.

=item C<cross_section>

Examples:

   $xsec = Xray::Absorption -> cross_section($elem, $en, $mode);

   @xsec = Xray::Absorption -> cross_section($elem, \@en, $mode);

In scalar context, return the cross section in barns/atom of C<$elem>
at C<$energy>.  In list context, return a list of cross-sections given
a reference to a list of energies.  For some data resources, list
context may be significantly faster than repeated calls in scalar
context, i.e. this

   @xsec = Xray::Absorption -> cross_section($elem, \@en, $mode);
   foreach (0 .. $#en) {
     ... do something with energy $xsec[$_] ...
   };

will be way faster than

   foreach (@en) {
     $xsec = Xray::Absorption -> cross_section($elem, $en, $mode);
     ... do something with $xsec ...
   };

The optional C<$mode> argument tells this method what kind of data to
return.  The default for all data resources is to return the cross
section, however each resource has several other option.  For example,
the McMaster tables offer along with the absorption cross section, the
coherent scattering, the incoherent scattering, or the sum of the
three contributions.  The allowed values for C<$mode> depend on the
data contained in the absorption resource currently loaded, but the
default is always to return the photoelectron cross section, or the
full cross section if the coherent and incoherent scattering portions
are included in the resource.  See the documentation for the
individual resource modules.  If C<$mode> is not given or is given
incorrectly, the full cross section is returned.

If an energy is requested which is right on an edge, all data
resources assume that you want the cross-section just above the edge.
The granularity of the comparison between the requested energy and the
edge energy is 1 milivolt, so if you want a cross-section just below
an edge, you should request an energy that is more than 1 milivolt
less than the value returned by C<get_energy>.

=item C<data_available>

Example:

   $is_there = Xray::Absorption -> data_available($elem, $edge);

Returns true if the selected resource contains sufficient data for
handling the specified element in the energy range around the
specified edge.  Returns false otherwise.

=back

=cut

package Xray::Absorption;

require Exporter;
use vars qw(@ISA $VERSION);

@ISA = qw(Exporter);
@EXPORT = qw();
@EXPORT_OK = qw($resource $verbose);

use strict;
use warnings;
use version;

use Carp;
use Chemistry::Elements qw(get_Z get_symbol);
use File::Spec;
use Storable;
use Math::Spline qw(spline);

$VERSION = version->new("3.0.1");

use vars qw($resource $verbose $data_dir);
$resource = "elam";
$verbose = 0;

my $is_windows = (($^O eq 'MSWin32') or ($^O eq 'cygwin'));
sub identify_self {
  my @caller = caller;
  use File::Basename qw(dirname);
  return dirname($caller[1]);
};

$data_dir = q{};
$data_dir = File::Spec->catfile(identify_self(), 'Absorption');

sub load {
  shift;
  $resource = $_[0] || $resource;
  $resource = lc($resource);
  @ISA = load_database('Xray::Absorption', $resource);
};

sub load_database {
  my($class,$resource) = @_;
  if ($resource eq 'mcmaster') {
    require Xray::Absorption::McMaster;
    'Xray::Absorption::McMaster';
  } elsif ($resource eq 'elam') {
    require Xray::Absorption::Elam;
    'Xray::Absorption::Elam';
  } elsif ($resource eq 'henke') {
    require Xray::Absorption::Henke;
    'Xray::Absorption::Henke';
  } elsif ($resource eq 'chantler') {
    require Xray::Absorption::Chantler;
    'Xray::Absorption::Chantler';
  } elsif ($resource eq 'cl') {
    require Xray::Absorption::CL;
    'Xray::Absorption::CL';
  } elsif ($resource eq 'shaltout') {
    require Xray::Absorption::Shaltout;
    'Xray::Absorption::Shaltout';
  } elsif ($resource eq 'none') {
    require Xray::Absorption::None;
    'Xray::Absorption::None';
  } else {
    croak "$resource is an unknown Xray::Absorption resource";
  }
};

load(1, $resource);

=over 4

=item C<available>

Example:

   @list = Xray::Absorption -> available;

Returns a list of all available data resource.

=back

=cut

#my @cl_ok = ('linux', 'irix');
#my $cl_match = join('|', @cl_ok);
my $ifeffit_exists = ($INC{'Ifeffit.pm'} or (eval "require Ifeffit"));
my $make_cl = $ifeffit_exists; #($^O =~ /$cl_match/);

sub available {
  shift;
  my @list = ("Elam", "McMaster", "Henke", "Chantler", "Shaltout", "None");
  ($make_cl) and push @list, "CL";
  return @list;
};

=over 4

=item C<scattering>

Example:

   @list = Xray::Absorption -> scattering;

Returns a list of all available data resource which contain anomalous
scattering functions.

=back

=cut

sub scattering {
  shift;
  my @list = ("Henke", "Chantler", "None");
  ($make_cl) and push @list, "CL";
  return @list;
};

=over 4

=item C<verbose>

Example:

   @list = Xray::Absorption -> verbose($arg);

Turn verbose operation on or off.  If C<$arg> evaluates to true, then
warning messages will be printed to standard error.  If C<$arg>
evaluates to false, then methods will silently return 0 when they
encounter problems.

=back

=cut

sub verbose {
  shift;
  $verbose = $_[0];
};

## This hash contains general atomic data useful to absorption
## calculations which do not depend upon which absorption data
## resource is selected.  More properties can be added.
##
## density of Chlorine from Donal O'Leary http://www.ucc.ie/
##  ucc/depts/chem/dolchem/html/elem/ELEM017.HTM
##
##                       atomic    density of   conversion factor for
##                       weight    pure mat.    barns/atoms -> cm^2/gr
my %elements = (                                       #* ==> interpolated
		'h'  => [  1.008,  0.000090,   1.674],
		'he' => [  4.003,  0.000179,   6.647],
		'li' => [  6.940,  0.534000,  11.520],
		'be' => [  9.012,  1.848000,  14.960],
		'b'  => [ 10.811,  2.340000,  17.950],
		'c'  => [ 12.010,  2.250000,  19.940],
		'n'  => [ 14.008,  0.001250,  23.260],
		'o'  => [ 16.000,  0.001429,  26.570],
		'f'  => [ 19.000,  1.108000,  31.550],
		'ne' => [ 20.183,  0.000900,  33.510],
		'na' => [ 22.997,  0.970000,  38.190],
		'mg' => [ 24.320,  1.740000,  40.380],
		'al' => [ 26.970,  2.720000,  44.780],
		'si' => [ 28.086,  2.330000,  46.630],
		'p'  => [ 30.975,  1.820000,  51.430],
		's'  => [ 32.066,  2.000000,  53.240],
		'cl' => [ 35.457,  0.003000,  58.870], # was 1.56
		'ar' => [ 39.944,  0.001784,  66.320],
		'k'  => [ 39.102,  0.862000,  64.930],
		'ca' => [ 40.080,  1.550000,  66.550],
		'sc' => [ 44.960,  2.992000,  74.650],
		'ti' => [ 47.900,  4.540000,  79.530],
		'v'  => [ 50.942,  6.110000,  84.590],
		'cr' => [ 51.996,  7.190000,  86.340],
		'mn' => [ 54.940,  7.420000,  91.220],
		'fe' => [ 55.850,  7.860000,  92.740],
		'co' => [ 58.933,  8.900000,  97.850],
		'ni' => [ 58.690,  8.900000,  97.450],
		'cu' => [ 63.540,  8.940000, 105.500],
		'zn' => [ 65.380,  7.140000, 108.600],
		'ga' => [ 69.720,  5.903000, 115.800],
		'ge' => [ 72.590,  5.323000, 120.500],
		'as' => [ 74.920,  5.730000, 124.400],
		'se' => [ 78.960,  4.790000, 131.100],
		'br' => [ 79.920,  3.120000, 132.700],
		'kr' => [ 83.800,  0.003740, 139.100],
		'rb' => [ 85.480,  1.532000, 141.900],
		'sr' => [ 87.620,  2.540000, 145.500],
		'y'  => [ 88.905,  4.405000, 147.600],
		'zr' => [ 91.220,  6.530000, 151.500],
		'nb' => [ 92.906,  8.570000, 154.300],
		'mo' => [ 95.950, 10.220000, 159.300],
		'tc' => [ 99.000, 11.500000, 164.400],
		'ru' => [101.070, 12.410000, 167.800],
		'rh' => [102.910, 12.440000, 170.900],
		'pd' => [106.400, 12.160000, 176.700],
		'ag' => [107.880, 10.500000, 179.100],
		'cd' => [112.410,  8.650000, 186.600],
		'in' => [114.820,  7.280000, 190.700],
		'sn' => [118.690,  5.760000, 197.100],
		'sb' => [121.760,  6.691000, 202.200],
		'te' => [127.600,  6.240000, 211.900],
		'i'  => [126.910,  4.940000, 210.700],
		'xe' => [131.300,  0.005900, 218.000],
		'cs' => [132.910,  1.873000, 220.700],
		'ba' => [137.360,  3.500000, 228.100],
		'la' => [138.920,  6.150000, 230.700],
		'ce' => [140.130,  6.670000, 232.700],
		'pr' => [140.920,  6.769000, 234.000],
		'nd' => [144.270,  6.960000, 239.600],
		'pm' => [147.000,  6.782000, 244.100],
		'sm' => [150.350,  7.536000, 249.600],
		'eu' => [152.000,  5.259000, 252.400],
		'gd' => [157.260,  7.950000, 261.100],
		'tb' => [158.930,  8.272000, 263.900],
		'dy' => [162.510,  8.536000, 269.800],
		'ho' => [164.940,  8.803000, 273.900],
		'er' => [167.270,  9.051000, 277.700],
		'tm' => [168.940,  9.332000, 280.500],
		'yb' => [173.040,  6.977000, 287.300],
		'lu' => [174.990,  9.842000, 290.600],
		'hf' => [178.500, 13.300000, 296.400],
		'ta' => [180.950, 16.600000, 300.500],
		'w'  => [183.920, 19.300000, 305.400],
		're' => [186.207, 20.980000, 310.600], #*
		'os' => [190.200, 22.500000, 315.800],
		'ir' => [192.200, 22.420000, 319.100],
		'pt' => [195.090, 21.370000, 323.900],
		'au' => [197.200, 19.370000, 327.400],
		'hg' => [200.610, 13.546000, 333.100],
		'tl' => [204.390, 11.860000, 339.400],
		'pb' => [207.210, 11.340000, 344.100],
		'bi' => [209.000,  9.800000, 347.000],
		'po' => [208.982,  9.300000, 353.900], #*
		'at' => [209.987,  0.000000, 360.800], #*
		'rn' => [222.000,  0.009730, 368.600],
		'fr' => [223.000,  0.000000, 372.750], #*
		'ra' => [226.025,  5.000000, 376.900], #*
		'ac' => [227.028, 10.050000, 381.050], #*
		'th' => [232.000, 11.700000, 385.200],
		'pa' => [231.036, 15.340000, 390.200], #*
		'u'  => [238.070, 19.050000, 395.300],
		'np' => [237.048, 20.210000, 396.000], #* w/d from Data Booklet
		'pu' => [239.100, 19.700000, 397.000],
	       );

## this section has the resource-independent class methods.  more can
## be added in the future.

=over 4

=item C<get_atomic_weight>

Example:

   $value = Xray::Absorption -> get_atomic_weight($elem);

Return the atomic weight of C<$elem>.

=back

=cut

sub get_atomic_weight {
  shift;
  my $sym = $_[0];
  $sym = lc( get_symbol($sym) );
  return exists($elements{$sym}) ? $elements{$sym} -> [0] : 0;
};

=over 4

=item C<get_density>

Example:

   $value = Xray::Absorption -> get_density($elem);

Return the specific gravity of the pure material of C<$elem>.

=back

=cut

sub get_density {
  shift;
  my $sym = $_[0];
  $sym = lc( get_symbol($sym) );
  return exists($elements{$sym}) ? $elements{$sym} -> [1] : 0;
};


=over 4

=item C<get_conversion>

Example:

   $value = Xray::Absorption -> get_conversion($elem);

Return the factor for converting between barns/atom and cm
squared/gram for C<$elem>.

=back

=cut

sub get_conversion {
  shift;
  my $sym = $_[0];
  $sym = lc( get_symbol($sym) );
  return exists($elements{$sym}) ? $elements{$sym} -> [2] : 0;
};


sub get_l {
  shift;
  my $z = $_[0];
  $z = &get_Z($z);
  (not $z)     and return 0;
  (defined $z) or  return 0;
  ($z <= 10)   and return 1;
  ($z <= 36)   and return 2;
  return 3;
};


## these three hashes are used to quickly convert between the Siegbahn
## and IUPAC symbols for the fluorescence lines

my %sieg2iup = ("ka1"        => "k-l3",
                "ka2"        => "k-l2",
                "ka3"        => "k-l1",
                "kb1"        => "k-m3",
                "kb2"        => "k-n2,3",
                "kb3"        => "k-m2",
                "kb4"        => "k-n4,5",
                "kb5"        => "k-m4,5",
                "lb3"        => "l1-m3",
                "lb4"        => "l1-m2",
                "lg2"        => "l1-n2",
                "lg3"        => "l1-n3",
                "lb1"        => "l2-m4",
                "ln"         => "l2-m1",
                "lg1"        => "l2-n4",
                "lg6"        => "l2-o4",
                "la1"        => "l3-m5",
                #"lb2,15"     => "l3-n4,5",
                "lb2"        => "l3-n4,5",
                "la2"        => "l3-m4",
                "lb5"        => "l3-o4,5",
                "lb6"        => "l3-n1",
                "ll"         => "l3-m1",
                "ma"         => "m5-n6,7",
                "mb"         => "m4-n6",
                "mg"         => "m3-n5",
                "mz"         => "m4,5-n6,7",
               );

my %iup2sieg = ("k-l3"       => "ka1",
		"k-l2"       => "ka2",
		"k-l1"       => "ka3",
		"k-m3"       => "kb1",
		"k-n2,3"     => "kb2",
		"k-m2"       => "kb3",
		"k-n4,5"     => "kb4",
		"k-m4,5"     => "kb5",
		"l1-m3"      => "lb3",
		"l1-m2"      => "lb4",
		"l1-n2"      => "lg2",
		"l1-n3"      => "lg3",
		"l2-m4"      => "lb1",
		"l2-m1"      => "ln" ,
		"l2-n4"      => "lg1",
		"l2-o4"      => "lg6",
		"l3-m5"      => "la1",
		"l3-n4,5"    => "lb2",
		#"l3-n4,5"    => "lb2,15",
		"l3-m4"      => "la2",
		"l3-o4,5"    => "lb5",
		"l3-n1"      => "lb6",
		"l3-m1"      => "ll",
		"m5-n6,7"    => "ma",
		"m4-n6"      => "mb",
		"m3-n5"      => "mg",
		"m4,5-n6,7"  => "mz",
	       );

my %gr2lett = ("kalpha1"    => "ka1",
               "kalpha2"    => "ka2",
               "kalpha3"    => "ka3",
               "kbeta1"     => "kb1",
               "kbeta2"     => "kb2",
               "kbeta3"     => "kb3",
               "kbeta4"     => "kb4",
               "kbeta5"     => "kb5",
               "lbeta3"     => "lb3",
               "lbeta4"     => "lb4",
               "lgamma2"    => "lg2",
               "lgamma3"    => "lg3",
               "lbeta1"     => "lb1",
               "lnu"        => "ln" ,
               "lgamma1"    => "lg1",
               "lgamma6"    => "lg6",
               "lalpha1"    => "la1",
               #"lbeta2,15"  => "lb2,15",
               "lbeta2"     => "lb2",
               "lalpha2"    => "la2",
               "lbeta5"     => "lb5",
               "lbeta6"     => "lb6",
               "ll"         => "ll",
               "malpha"     => "ma",
               "mbeta"      => "mb",
               "mgamma"     => "mg",
               "mzeta"      => "mz",
               );


=over 4

=item C<get_Siegbahn>

Example:

   $symbol = Xray::Absorption -> get_Siegbahn($sym);

Return the short Siegbahn symbol for an x-ray fluorescence line.  Thus
"Ka1", "Kalpha1", and "K-L3" all return "Ka1".  The case of the input
symbol does not matter and the symbol is returned capitalized.  White
space and underscores will be removed from the input symbol.  The
symbol "lb2,15" is translated to "lb2".  This returns 0 is C<$sym> is
not a recognizable symbol for a line.

=back

=cut

sub get_Siegbahn {
  shift;
  my $sym = $_[0];
  $sym = lc($sym);
  $sym =~ s/ //g;
  $sym =~ s/_//g;
  ($sym eq "lb2,15") and ($sym = "lb2");
  exists $sieg2iup{$sym} and return ucfirst($sym);
  exists $iup2sieg{$sym} and return ucfirst($iup2sieg{$sym});
  exists $gr2lett{$sym}  and return ucfirst($gr2lett{$sym});
  return 0;
};

=over 4

=item C<get_Siegbahn_full>

Example:

   $symbol = Xray::Absorption -> get_Siegbahn_full($sym);

Return the full Siegbahn symbol for an x-ray fluorescence line.  Thus
"Ka1", "Kalpha1", and "K-L3" all return "Kalpha1".  The case of the
input symbol does not matter and the symbol is returned capitalized.
White space and underscores will be removed from the input symbol.
This returns 0 is C<$sym> is not a recognizable symbol for a line.

=back

=cut

sub get_Siegbahn_full {
  shift;
  my $sym = Xray::Absorption->get_Siegbahn($_[0]);
  my %greek = ("a"=>"alpha", "b"=>"beta", "g"=>"gamma", "l"=>"l",
	       "n"=>"nu",    "z"=>"zeta");
  my $letters = join("", keys(%greek));
  (substr($sym, 1, 1) =~ /[$letters]/) and do {
    substr($sym, 1, 1) = $greek{substr($sym, 1, 1)};
    return $sym;
  };
  return $sym;
};

=over 4

=item C<get_IUPAC>

Example:

   $symbol = Xray::Absorption -> get_IUPAC($sym);

Return the IUPAC symbol for an x-ray fluorescence line.  Thus "Ka1",
"Kalpha1", and "K-L3" all return "K-L3".  The case of the input symbol
does not matter and the symbol is returned in all capitals.  White
space and underscores will be removed from the input symbol.  This
returns 0 is C<$sym> is not a recognizable symbol for a line.

=back

=cut

sub get_IUPAC {
  shift;
  my $sym = $_[0];
  $sym = lc($sym);
  $sym =~ s/ //g;
  $sym =~ s/_//g;
  ($sym eq "lb2,15") and ($sym = "lb2");
  exists $iup2sieg{$sym} and return uc($sym);
  exists $sieg2iup{$sym} and return uc($sieg2iup{$sym});
  exists $gr2lett{$sym}  and return uc($sieg2iup{$gr2lett{$sym}});
  return 0;
};


=over 4

=item C<get_gamma>

Example:

   $symbol = Xray::Absorption -> get_gamma($sym, $edge);

Return an approximation of the core-hole lifetime for the given atomic
symbol and edge.  This follows Feff very closely.  In fact the data
used is swiped from the setgam subroutine in Feff, which is in turn
swiped from K. Rahkonen and K. Krause, Atomic Data and Nuclear Data
Tables, Vol 14, Number 2, 1974.  The values given by this routine are
a bit different from those given by Feff since a different
interpolation is used.  For O and P edges a value of 0.1 is returned,
as in Feff.  If the arguments are not interpretable, a value of 0 is
returned.

=back

=cut

my %zhash =
  (
   'k'  => [ 0.99,  10.0, 20.0, 40.0, 50.0, 60.0,  80.0,  95.1],
   'l1' => [ 0.99,  18.0, 22.0, 35.0, 50.0, 52.0,  75.0,  95.1],
   'l2' => [ 0.99,  17.0, 28.0, 31.0, 45.0, 60.0,  80.0,  95.1],
   'l3' => [ 0.99,  17.0, 28.0, 31.0, 45.0, 60.0,  80.0,  95.1],
   'm1' => [ 0.99,  20.0, 28.0, 30.0, 36.0, 53.0,  80.0,  95.1],
   'm2' => [ 0.99,  20.0, 22.0, 30.0, 40.0, 68.0,  80.0,  95.1],
   'm3' => [ 0.99,  20.0, 22.0, 30.0, 40.0, 68.0,  80.0,  95.1],
   'm4' => [ 0.99,  36.0, 40.0, 48.0, 58.0, 76.0,  79.0,  95.1],
   'm5' => [ 0.99,  36.0, 40.0, 48.0, 58.0, 76.0,  79.0,  95.1],
   'n1' => [ 0.99,  30.0, 40.0, 47.0, 50.0, 63.0,  80.0,  95.1],
   'n2' => [ 0.99,  40.0, 42.0, 49.0, 54.0, 70.0,  87.0,  95.1],
   'n3' => [ 0.99,  40.0, 42.0, 49.0, 54.0, 70.0,  87.0,  95.1],
   'n4' => [ 0.99,  40.0, 50.0, 55.0, 60.0, 70.0,  81.0,  95.1],
   'n5' => [ 0.99,  40.0, 50.0, 55.0, 60.0, 70.0,  81.0,  95.1],
   'n6' => [ 0.99,  71.0, 73.0, 79.0, 86.0, 90.0,  95.0, 100.0],
   'n7' => [ 0.99,  71.0, 73.0, 79.0, 86.0, 90.0,  95.0, 100.0],
  );

my %gamach =
  (
   'k'  => [0.02,   0.28,  0.75,  4.8, 10.5, 21.0, 60.0, 105.0],
   'l1' => [0.07,   3.9,   3.8,   7.0,  6.0,  3.7,  8.0,  19.0],
   'l2' => [0.001,  0.12,  1.4,   0.8,  2.6,  4.1,  6.3,  10.5],
   'l3' => [0.001,  0.12,  0.55,  0.7,  2.1,  3.5,  5.4,   9.0],
   'm1' => [0.001,  1.0,   2.9,   2.2,  5.5, 10.0, 22.0,  22.0],
   'm2' => [0.001,  0.001, 0.5,   2.0,  2.6, 11.0, 15.0,  16.0],
   'm3' => [0.001,  0.001, 0.5,   2.0,  2.6, 11.0, 10.0,  10.0],
   'm4' => [0.0006, 0.09,  0.07,  0.48, 1.0,  4.0,  2.7,   4.7],
   'm5' => [0.0006, 0.09,  0.07,  0.48, 0.87, 2.2,  2.5,   4.3],
   'n1' => [0.001,  0.001, 6.2,   7.0,  3.2, 12.0, 16.0,  13.0],
   'n2' => [0.001,  0.001, 1.9,  16.0,  2.7, 13.0, 13.0,   8.0],
   'n3' => [0.001,  0.001, 1.9,  16.0,  2.7, 13.0, 13.0,   8.0],
   'n4' => [0.001,  0.001, 0.15,  0.1,  0.8,  8.0,  8.0,   5.0],
   'n5' => [0.001,  0.001, 0.15,  0.1,  0.8,  8.0,  8.0,   5.0],
   'n6' => [0.001,  0.001, 0.05,  0.22, 0.1,  0.16, 0.5,   0.9],
   'n7' => [0.001,  0.001, 0.05,  0.22, 0.1,  0.16, 0.5,   0.9]
  );

sub get_gamma {
  shift;
  my ($sym, $edge) = @_;
  my $z = &get_Z($sym);
  $z or return 0;
  $edge = lc($edge);
  ($edge =~ /\b(o[1-5]|p[1-3])\b/) and return 0.1;
  ($edge =~ /\b(k|l[1-3]|m[1-5]|n[1-7]|o[1-5]|p[1-3])\b/) or return 0;
  my $x = $zhash{$edge};
  my $y = $gamach{$edge};
  my $spline = new Math::Spline($x,$y);
  return $spline->evaluate($z);
};


=over 4

=item C<get_one_minus_g>

Example:

   $symbol = Xray::Absorption -> get_g($sym, $energy);

Return an approximation of the factor required to translate tabulated
cross-section data to the mass energy-absorption coefficient, as
described by Hubbell at
http://physics.nist.gov/PhysRefData/XrayMassCoef/cover.html.

This term, returned as C<1-g> relates the the mass attenuation
coefficient, C<mu/rho>, to the mass energy-absorption coefficient,
C<mu_en/rho>, as

    mu_en/rho = (1-g) * mu_tr/rho

where the mass energy-transfer coefficient, C<mu_tr>, is the sum of
the photoabsorption and incoherent cross-sections.  (At the energies
at which this module is applicable, other cross-sections such as
pair production can be ignored.)

So, to use this factor, compute the sum of the photoabsorption and
incoherent cross-sections at some energy and multiply by the number
this method returns.

The importance of this term depends on energy and on element.  For
nitrogen, for example, this term becomes increasingly important above
10 keV.  For argon, it is near unity up to about 30 keV.

No great care is taken to interpolate correctly around absorption
edges.  That should be considered a bug.

This method returns 1 whenever it's imput data is confusing.  That
seems safest.

=back

=cut

my $g_file = File::Spec->catfile($Xray::Absorption::data_dir, "hubbell_g.db");
use vars qw($r_one_minus_g);
$r_one_minus_g = retrieve($g_file);

sub get_one_minus_g {
  shift;
  my ($sym, $energy) = @_;
  my $z = &get_Z($sym);
  $z or return 1;
  ($z > 92) and return 1;
  ($z < 1) and return 1;
  ($energy < 1000) and return 1;

  my $e = $$r_one_minus_g[$z] -> {energy};
  my $g = $$r_one_minus_g[$z] -> {one_minus_g};
  my $spline = new Math::Spline($e,$g);
  return 1/$spline->evaluate($energy);
};



my $hash;
do {
  no warnings;
  $hash = $$Xray::Absorption::Elam::r_elam{energy_list};
};
my @k_list = ();
foreach my $key (keys %$hash) {
  next unless exists $$hash{$key}->[2];
  next unless (lc($$hash{$key}->[1]) eq 'k');
  push @k_list, $$hash{$key};
};
## and sort by increasing energy
@k_list = sort {$a->[2] <=> $b->[2]} @k_list;

sub _l_filter {
  my $elem = $_[0];
  return q{} if (get_Z($elem) > 98);
  my $en = Xray::Absorption -> get_energy($elem, 'la1') + 100;
  my $filter = q{};
  foreach (@k_list) {
    $filter = $_->[0];
    last if ($_->[2] >= $en);
  };
  my $result = get_Z($filter);
  ++$result if ($result == 36);
  return $result;
};

sub recommended_filter {
  shift;
  my ($sym) = @_;
  my $z = get_Z($sym);
  my $filter = ($z <  24) ? q{}
             : ($z == 37) ? 35     ## Kr is a stupid filter material
             : ($z <  39) ? $z - 1 ## Z-1 for V - Y
             : ($z == 45) ? 44     ## Tc is a stupid filter material
             : ($z == 56) ? 53     ## Xe is a stupid filter material
             : ($z <  57) ? $z - 2 ## Z-2 for Zr - Ba
	     : _l_filter($z);      ## K filter for heavy elements
 };


1;
__END__



=head1 SYMBOLS FOR FLUORESCENCE LINES

To specify fluorescence lines, Siegbahn or IUPAC symbols may be used.
methods are provided for converting between these notations.  The
Siegbahn notations can be in the short or full forms.  Here is a table
of all recognized symbols:

   Full Siegbahn     Short Siegbahn    IUPAC
  -------------------------------------------------
      Kalpha1            Ka1           K-L3
      Kalpha2            Ka2	       K-L2
      Kalpha3            Ka3	       K-L1
      Kbeta1             Kb1	       K-M3
      Kbeta2             Kb2	       K-N2,3
      Kbeta3             Kb3	       K-M2
      Kbeta4             Kb4	       K-N4,5
      Kbeta5             Kb5	       K-M4,5
      Lalpha1            La1	       L3-M5
      Lalpha2            La2	       L3-M4
      Lbeta1             Lb1	       L2-M4
      Lbeta2             Lb2	       L3-N4,5
      Lbeta3             Lb3	       L1-M3
      Lbeta4             Lb4	       L1-M2
      Lbeta5             Lb5	       L3-O4,5
      Lbeta6             Lb6	       L3-N1
      Lgamma1            Lg1	       L2-N4
      Lgamma2            Lg2	       L1-N2
      Lgamma3            Lg3	       L1-N3
      Lgamma6            Lg6	       L2-O4
      Ll                 Ll 	       L3-M1
      Lnu                Ln 	       L2-M1
      Malpha             Ma 	       M5-N6,7
      Mbeta              Mb 	       M4-N6
      Mgamma             Mg 	       M3-N5
      Mzeta              Mz 	       M4,5-N6,7

In addition, the symbols C<Lb2,15> and C<Lbeta2,15> are recognized as
synonyms for C<Lbeta2>.  The methods which interpret these symbols
will remove spaces and underscores from the input string.  Thus
C<K_alpha_1> and C<K a 1> will both be recognized as C<Kalpha1>.
Since hyphens are part of the IUPAC notation, C<K-alpha-1> will not be
recognized as C<Kalpha1>.  Thus use spaces or underscores if you want
to make the Siegbahn notation more legible.


=head1 ABSORPTION DATA RESOURCES

Currently, C<Xray::Absorption> has the McMaster, Elam, Henke, and
Chantler tables as its data resources.  New resources may be added
over time.  This section offers a few guidelines to anyone interested
in supplying more resources.  It does not matter how the new resource
calculates the cross section.  That is hidden behind the
object-orientedness of the C<Xray::Absorption> module.  It is
essential that the new resource take the namespace
C<Xray::Absorption::>I<Resource>, where I<Resource> is a descriptive
name, like C<McMaster> or C<Elam>.  It is essential that the new
resource supply these methods

    current_resource
    in_resource
    get_energy
    next_energy
    cross_section

and that they use the semantics described above.  All other methods
decribed in the last section are defined in F<Absorption.pm> and do
not need to be redefined in the resource modules.

New resources are welcome to define new methods particular to that
data resource in addition to the 5 required methods.

=head1 UNITS

All energies returned by the methods of C<Xray::Absorption> are in
electron volts.  All cross sections are in units of barns per atom.  A
conversion constant between that unit and cm squared per gram is
supplied by the C<get_conversion> method.  Atomic weights are in
atomic units.  Densities are given as specific gravity
(i.e. dimensionless).

=head1 BUGS AND THINGS TO DO

=over 4

=item *

Check to be sure things are properly unloaded and overloaded when
switching resources.

=item *

Test for pathelogical cases, such as elements that don't exist, that
have Z's in the hundreds, energies that are very low or very high, and
so on.

=item *

It would be nice to implement the list that is used by the
C<next_energy> method as a doubly linked list.  In that way, a
C<previous_energy> method would be trivial.

=back

=head1 AUTHOR

Bruce Ravel <bravel@bnl.gov>

http://bruceravel.github.com/demeter/

=head1 LICENCE AND COPYRIGHT

Copyright (c) 1999-2008 Bruce Ravel (bravel AT bnl DOT gov). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut


1;
