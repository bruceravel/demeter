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
## Time-stamp: <16-Nov-2009 08:17:19 bruce>
######################################################################
## Code:

package Xray::Absorption::McMaster;

use strict;
use warnings;
use version;

use Exporter ();
use Config;
use Xray::Absorption;

use vars qw($VERSION $resource $mucal_version @ISA @EXPORT @EXPORT_OK);

require Exporter;

@ISA = qw(Exporter AutoLoader);
# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.
@EXPORT_OK = qw();
$VERSION = version->new("3.0.0");

use constant EPSILON => 0.001;		# a milivolt
use constant LJUMP2  => 1.41;		# the overall l2 jump factor

# Preloaded methods go here.

use strict;
use Carp;
##Storable:
use Storable;
##end Storable:
##MLDBM:
## use MLDBM qw(DB_File Storable);
## use Fcntl;
##end MLDBM:
use Chemistry::Elements qw(get_name get_Z get_symbol);


use File::Spec;
##storable:
my $dbfile = File::Spec->catfile($Xray::Absorption::data_dir, "mcmaster.db");
my $r_mcmaster = retrieve($dbfile);
##end storable:
##MLDBM:
##tie my %mcmaster, 'MLDBM', $dbfile, O_RDONLY or die $!;
##end MLDBM:
##direct read:
## my %mucal = ();
## unless (my $return = eval 'do $dbfile') {
##   warn "couldn't parse $dbfile: $@" if $@;
##   warn "couldn't do $dbfile: $! "   unless defined $return;
##   warn "couldn't run $dbfile"       unless $return;
## };
## my $r_mcmaster = \%mucal;
##end direct read:
$mucal_version = $$r_mcmaster{'version'};



## ----- make the hash needed by next_energy ------------------

##print "Getting energy list keys ...";
my @energy_list = ();
foreach my $key (keys %$r_mcmaster) {
  next if ($key eq "version");
  next if ($key eq "nu");
  ($$r_mcmaster{$key}->{energy_k})  && push @energy_list, $key . "_k" ;
  ($$r_mcmaster{$key}->{energy_l1}) && push @energy_list, $key . "_l1";
  ($$r_mcmaster{$key}->{energy_l2}) && push @energy_list, $key . "_l2";
  ($$r_mcmaster{$key}->{energy_l2}) && push @energy_list, $key . "_l3";
};


##print "$/Sorting energy list ...";
@energy_list =
  sort {
    $$r_mcmaster{shift @{[split(/_/,$a)]}}{"energy_". pop @{[split(/_/,$a)]}}
       <=>
    $$r_mcmaster{shift @{[split(/_/,$b)]}}{"energy_". pop @{[split(/_/,$b)]}}
  } @energy_list;

##print " and making energy hash$/";
#my %energy_hash = ();
while (@energy_list) {
  my $this = shift(@energy_list);
  if (@energy_list) {
    my $that = $energy_list[0];
    my ($elem, $edge) = split(/_/, $that);
    my $energy = $$r_mcmaster{$elem}{"energy_".$edge};
    $$r_mcmaster{energy_list}{$this} = [$elem, $edge, $energy];
  } else {			# taking care with last element
    $$r_mcmaster{energy_list}{$this} = [];
  };
};


## ---- METHODS -----------------------------------------------

sub current_resource {
  "McMaster.pm version $VERSION, database version $mucal_version";
};

## is this element actually tabulated in these tables?
##    Xray::Absorption -> in_resource($elem) $elem can be Z, symbol, name
sub in_resource {
  shift;
  my $z = $_[0];
  $z = get_Z($z);
  (defined $z) || return 0;
  return 0 if $z < 1;
  return ( ($z == 84) || ($z == 85) || ($z == 87) || ($z == 88) ||
	   ($z == 89) || ($z == 91) || ($z == 93) || ($z >= 95) )
    ? 0 : 1;
};



## $edge should be one of k l1 l2 l3 kalpha kbeta lalpha lbeta
##    Xray::Absorption -> get_energy($elem, $edge)
sub get_energy {
  shift;
  my ($sym,$edge) = @_;
  Xray::Absorption -> in_resource($sym) || return 0;
  $sym = lc( get_symbol($sym) );
  (defined $sym) || return 0;
  $edge = lc($edge);
  ($edge eq "k")         && ($edge = "energy_k");
  ($edge eq "l1")        && ($edge = "energy_l1");
  ($edge eq "l2")        && ($edge = "energy_l2");
  ($edge eq "l3")        && ($edge = "energy_l3");
  ($edge =~ /^m/i)       && ($edge = "energy_m");
  my $sieg_edge = lc(Xray::Absorption->get_Siegbahn($edge));
  if (($edge =~ /^ka/i) or ($sieg_edge =~ /^ka/i)) {
    ($edge = "kalpha");
  };
  if (($edge =~ /^kb/i) or ($sieg_edge =~ /^kb/i)) {
    ($edge = "kbeta");
  };
  if (($edge =~ /^la/i) or ($sieg_edge =~ /^la/i)) {
    ($edge = "lalpha");
  };
  if (($edge =~ /^lb/i) or ($sieg_edge =~ /^lb/i)) {
    ($edge = "lbeta");
  };
  return (exists($$r_mcmaster{$sym}{$edge})) ? $$r_mcmaster{$sym}{$edge} : 0;
};



##   ($next_elem, $its_edge, $its_energy) =
##      Xray::Absorption -> $next_energy($elem, $edge, @atoms);
sub next_energy {
  shift;
  my $elem = shift;		# atom in question
  my $edge = shift;		# edge in question
  my @list = @_;		# other atoms in material
  my $hash = $$r_mcmaster{energy_list};
  my $key = lc($elem) . "_" . lc($edge);
  ##   use Data::Dumper;
  ##   $Data::Dumper::Purity = 1;
  ##   print Data::Dumper->Dump([$hash], [qw(*list)]);
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
  if (get_Z($sym) < 30) {
    ($edge =~ /k|l1?/) and return 1;
    return 0;
  };
  ($edge =~ /k|l[123]?/) and return 1;
  return 0;
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

The values for all cross-sections are computed as log-log polynomials
as described in the original paper by McMaster et al.

=back

=cut

## returns 0 for an unknown symbol or for an uncataloged symbol
##    $sigma = Xray::Absorption -> cross_section($elem, $energy);
sub cross_section {
  shift;
  die "cross_section takes a single energy or a reference to an array\n" if
    ($#_ > 2);
  my ($sym, $energy, $mode) = @_;
  $sym = lc( get_symbol($sym) );
  Xray::Absorption -> in_resource($sym) || return 0;
  (defined $sym) || return 0;
  ($energy > EPSILON) || return 0;
  ## cache this hash element
  my $hash_element = $$r_mcmaster{$sym};

  my @ener;
  if (wantarray) {
    @ener = @$energy;
  } else {
    @ener = ($energy);
  };

  foreach (@ener) {
    if ( (get_Z($sym) < 30) and ($_ < $$r_mcmaster{$sym}{energy_l1}) ) {
      my $message = sprintf
	"The McMaster Tables are unreliable " .
	  "below %5.1f eV for element %s.\n",
	  $$r_mcmaster{$sym}{energy_l1}, ucfirst($sym);
      $Xray::Absorption::verbose and warn $message;
      return 0;
    };
  };

  $mode ||= "full";
  $mode = "full" if ($mode eq 'xsec');
  ($mode =~ /^[fpci]/i) or $mode = "full";


  ##print " ($coefs) ";
  ## want natural log of energy in keV
  my @lener = map {log($_/1000)} @ener;
  my (@sigma, @coh, @cih, @coefs);
  my @el = map {$_ ? log($_/1000) : 0}
    ($$hash_element{"ljump_3"},   $$hash_element{"energy_l1"},
     $$hash_element{"energy_l2"}, $$hash_element{"energy_l3"});
  $el[0] = $$hash_element{"ljump_3"}; # this one isn't a log
  ## cache log-energies for calls to get_coefs
  my %ehash;
  foreach (qw(energy_k energy_l1 energy_l2 energy_l3 energy_m)) {
    $ehash{$_} = 0;
    $$hash_element{$_} and $ehash{$_} = log($$hash_element{$_} / 1000);
  };

  ## the photelectron portion
  if ($mode =~ /^[fp]/i) {
    foreach my $e (@lener) {
      my ($en, $coefs, $warnl) = get_coefs($sym, $e, \%ehash);
      @coefs = @{$$hash_element{$coefs}};
      my $sigma = $coefs[0];
      foreach my $i (1..3) {
	$sigma += $coefs[$i] * $en**$i
      };
      #$sigma = ($sigma > EPSILON) ? exp($sigma) : 0;
      $sigma = exp($sigma);
      ## fixy-up energies in the l3-l2 or l2-l1 range
      unless ($warnl) {
      FIX_L: {
	  $sigma *= $el[0],          last FIX_L if
	    ( ($e >= $el[3]) && ($e < $el[2]) );
	  $sigma *= $el[0] * LJUMP2, last FIX_L if
	    ( ($e >= $el[2]) && ($e < $el[1]) );
	};
      };
      push @sigma, $sigma;
    };
  };

  ## the coherent portion
  if ($mode =~ /^[fc]/i) {
    @coefs = @{$$hash_element{"coherent"}};
    foreach my $e (@lener) {
      my $coh = $coefs[0];
      foreach my $i (1..3) {
	$coh += $coefs[$i] * $e**$i
      };
      #$coh = ($coh > EPSILON) ? exp($coh) : 0;
      $coh = exp($coh);
      push @coh, $coh;
    };
  };

  ## the incoherent portion
  if ($mode =~ /^[fi]/i) {
    @coefs = @{$$hash_element{"incoherent"}};
    foreach my $e (@lener) {
      my $cih = $coefs[0];
      foreach my $i (1..3) {
	$cih += $coefs[$i] * $e**$i
      };
      #$cih = ($cih > EPSILON) ? exp($cih) : 0;
      $cih = exp($cih);
      push @cih, $cih;
    };
  };

  ##print join(" ", $sigma[0]||'-', $coh[0]||'-', $cih[0]||'-'), $/;
  ($mode =~ /^f/i) and do {
    my @full = map {$sigma[$_] + $coh[$_] + $cih[$_]} (0 .. $#sigma);
    return wantarray ? @full : $full[0];
  };
  ($mode =~ /^p/i) and return wantarray ? @sigma : $sigma[0];
  ($mode =~ /^c/i) and return wantarray ? @coh   : $coh[0];
  ($mode =~ /^i/i) and return wantarray ? @cih   : $cih[0];
};


## choose the correct set of coefficients for the current energy
## also return a modified energy in case of edge energy
sub get_coefs {
  my ($sym, $energy, $rhash) = @_;
  ## watch out for an input energy that is right at the edge
 EDGE_CHECK: foreach my $edge ("energy_k", "energy_l1", "energy_l2",
			       "energy_l3", "energy_m") {
    ##  define the edge to be 10 meV above the edge
    if (abs(1000*(exp($energy) - exp($$rhash{$edge}))) < EPSILON) {
      $energy = 1000*exp($energy) + 10*EPSILON;
      $energy = log($energy/1000);
      last EDGE_CHECK;
    };
  };

  ## choose the correct set of cefficients
  my ($coefs, $warnl) = ("", 0);
 SELECT_EDGE: {
    ($energy > $$rhash{"energy_k"}) && do {
      $coefs = "a_k";
      last SELECT_EDGE;
    };
    ($energy > $$rhash{"energy_l1"}) && do {
      $coefs = "a_l";
      last SELECT_EDGE;
    };
    ($energy > $$rhash{"energy_m"}) && do {
      $coefs = "a_m";
      (get_Z($sym) < 30) && ($warnl = 1);
      last SELECT_EDGE;
    };
    $coefs = "a_n";
  };
  ##print join(" ", $$rhash{"energy_l1"}, $energy, $coefs), $/;
  return ($energy, $coefs, $warnl);
};


1;

__END__

=head1 NAME

Xray::Absorption::McMaster - Perl interface to the McMaster tables

=head1 SYNOPSIS

   use Xray::Absorption;
   Xray::Absorption -> load("mcmaster");

See the documentation for Xray::Absorption for details.

=head1 DESCRIPTION

This module is inherited by the Xray::Absorption module and provides
access to the data contained in the 1969 McMaster tables.

The data in this module, commonly referred to as "The McMaster Tables",
was originally published as

  Compilation of X-Ray Cross Sections
  W.H. McMster, N. Kerr Del Grande, J.H. Mallett, J.H. Hubbell
  National Bureau of Standards
  UCRL-50174 Section II Revision 1
  (1969)
  Available from National Technical Information Services L-3
  United States Department of Commerce

This can be a bit difficult to find.  IIT's Galvin library has kindly
made a scan of it available: http://www.gl.iit.edu/govdocs/resources/xray.html

The data is contained in a database file called F<mcmaster.db> which
is generated at install time from a flat text database of the McMster
data.  The data originally comes from F<mucal.f>, a Fortran subroutine
originally written by Dr. Pathikrit Bandhyapodhyay.

The required Chemistry::Elements module is available from CPAN in the
miscellaneous modules section.


=head1 EDGE AND LINE ENERGIES

The McMaster data resource only includes K and L 1-3 edges.  For light
elements, it provides only a single L edge energy -- that for the L1
edge.  For heavier elements it provides a single M energy, the energy
of the M1 edge.  It only supplies four generic fluorescence line
energies, Kalpha, Kbeta, Lalpha, and Lbeta.  In each case the energy
provided is the energy of the brightest line of that sort.

=head1 BUGS AND THINGS TO DO

=over 4

=item *

Make sure this handles fluorescence lines which are in other
resources, but not in this resource in a sensible manner.

=item *

What happens if you call C<line_toggle> when this is loaded?  How
about when elam was loaded but then you switch to this one?

=back

=head1 AUTHOR

  Bruce Ravel, bravel AT bnl DOT gov
  http://bruceravel.github.com/demeter/

=cut

## The McMaster data is stored to disk using the MLDBM module with the
## DB_file format and Storable serializing with portable binary ordering.
## This choice allows both speed and networked applicability.  Storable
## and MLDBM are both available from CPAN.


## Local Variables:
## time-stamp-line-limit: 25
## End:
