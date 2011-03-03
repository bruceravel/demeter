##  This module is copyright (c) 2007, 2008 Bruce Ravel
##  <bravel AT bnl DOT gov>
##  http://cars9.uchicago.edu/~ravel/software/
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

package Xray::Absorption::Shaltout;

use strict;
use warnings;
use version;

use Exporter ();
use Config;
use strict;
use Xray::Absorption;

use vars qw($VERSION  $resource @ISA @EXPORT @EXPORT_OK);

require Exporter;

@ISA = qw(Exporter AutoLoader);
@EXPORT_OK = qw();
$VERSION = version->new("3.0.0");

use constant EPSILON => 0.001;		# a milivolt

use strict;
use Carp;
use Storable;
use Chemistry::Elements qw(get_name get_Z get_symbol);
use File::Spec;

my $dbfile = File::Spec->catfile($Xray::Absorption::data_dir, "shaltout.db");
my $r_shaltout = retrieve($dbfile);

## ----- make the hash needed by next_energy ------------------

### Getting energy list keys ...
my @energy_list = ();
foreach my $key (keys %$r_shaltout) {
  next if ($key eq "version");
  next if ($key eq "nu");
  foreach my $edge (qw(k l1 l2 l3 m1 m2 m3 m4 m5 n1 n2 n3 n4 n5 n6 n7)) {
    next if (not exists $$r_shaltout{$key}->{energy}->{$edge});
    push @energy_list, join("_", $key, $edge);
  };
};

### Sorting energy list ...
@energy_list =
  sort {
    $$r_shaltout{shift @{[split(/_/,$a)]}}{energy}{pop @{[split(/_/,$a)]}}
       <=>
    $$r_shaltout{shift @{[split(/_/,$b)]}}{energy}{pop @{[split(/_/,$b)]}}
  } @energy_list;

### and making energy hash
#use Data::Dumper;
#print Data::Dumper->Dump([\@energy_list],[qw(*energy_list)]);

#my %energy_hash = ();
while (@energy_list) {
  my $this = shift(@energy_list);
  if (@energy_list) {
    my $that = $energy_list[0];
    my ($elem, $edge) = split(/_/, $that);
    my $energy = $$r_shaltout{$elem}{energy}{$edge};
    $$r_shaltout{energy_list}{$this} = [$elem, $edge, $energy];
  } else {			# taking care with last element
    $$r_shaltout{energy_list}{$this} = [];
  };
};


## ---- METHODS -----------------------------------------------

sub current_resource {
  "Shaltout.pm version $VERSION, database version $$r_shaltout{version}";
};

## is this element actually tabulated in these tables?
##    Xray::Absorption -> in_resource($elem) $elem can be Z, symbol, name
sub in_resource {
  shift;
  my $z = $_[0];
  $z = get_Z($z);
  (defined $z) or return 0;
  return 0 if $z < 1;
  return ($z > 94) ? 0 : 1;
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
  my $sieg_edge = lc(Xray::Absorption->get_Siegbahn($edge));
  ($edge = "kalpha") if (($edge =~ m{^ka}) or ($sieg_edge =~ m{^ka}));
  ($edge = "kbeta")  if (($edge =~ m{^kb}) or ($sieg_edge =~ m{^kb}));
  ($edge = "lalpha") if (($edge =~ m{^la}) or ($sieg_edge =~ m{^la}));
  ($edge = "lbeta")  if (($edge =~ m{^lb}) or ($sieg_edge =~ m{^lb}));
  return 0 if ($edge !~ m{^\s*(?:k(?:alpha|beta)?|l(?:[123]|alpha|beta)|m[1-5]|n[1-7])\s*$});
  ##return 0 if not exists($$r_shaltout{$sym}{energy}{$edge});
  return $$r_shaltout{$sym}{energy}{$edge} || 0;
};


##   ($next_elem, $its_edge, $its_energy) =
##      Xray::Absorption -> $next_energy($elem, $edge, @atoms);
sub next_energy {
  shift;
  my $elem = shift;		# atom in question
  my $edge = shift;		# edge in question
  my @list = @_;		# other atoms in material
  my $hash = $$r_shaltout{energy_list};
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
  return 1 if exists($$r_shaltout{$sym}{energy}{$edge});
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
as described in the original paper by Shaltout et al.

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
  my $hash_element = $$r_shaltout{$sym};

  my @ener;
  if (wantarray) {
    @ener = @$energy;
  } else {
    @ener = ($energy);
  };

  foreach (@ener) {
    my $eee = Xray::Absorption -> get_energy($sym, 'l1');
    if ( (get_Z($sym) < 30) and ($_ < $eee) ) {
      my $message = sprintf
	"The Shaltout Tables are unreliable " .
	  "below %5.1f eV for element %s.\n",
	  $$r_shaltout{$sym}{energy}{l1}, ucfirst($sym);
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
    (1000,
     $$hash_element{energy}{l1},
     $$hash_element{energy}{l2},
     $$hash_element{energy}{l3}
    );
  my @em = map {$_ ? log($_/1000) : 0}
    (1000,
     $$hash_element{energy}{m1},
     $$hash_element{energy}{m2},
     $$hash_element{energy}{m3},
     $$hash_element{energy}{m4},
     $$hash_element{energy}{m5},
    );
  my @en = map {$_ ? log($_/1000) : 0}
    (1000,
     $$hash_element{energy}{n1},
     $$hash_element{energy}{n2},
     $$hash_element{energy}{n3},
     $$hash_element{energy}{n4},
     $$hash_element{energy}{n5},
     $$hash_element{energy}{n6},
     $$hash_element{energy}{n7},
    );
  ##$el[0] = $$hash_element{"ljump_3"}; # this one isn't a log
  ## cache log-energies for calls to get_coefs
  my %ehash;
  foreach (qw(k l1 l2 l3 m1 m2 m3 m4 m5 n1 n2 n3 n4 n5 n6 n7)) {
    $ehash{$_} = 0;
    $ehash{$_} = log($$hash_element{energy}{$_} / 1000) if
      (exists($$hash_element{energy}{$_}) and $$hash_element{energy}{$_});
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
      my $jump_factor = 1;
      #unless ($warnl) {

      ## l edges
      $jump_factor *= $$hash_element{jump}{l3} if
	( ($e >= $el[3]) && ($e < $el[1]) );
      $jump_factor *= $$hash_element{jump}{l2} if
	( ($e >= $el[2]) && ($e < $el[1]) );

      ## m edges
      $jump_factor *= $$hash_element{jump}{m5} if
	( ($e >= $em[5]) && ($e < $em[1]) );
      $jump_factor *= $$hash_element{jump}{m4} if
	( ($e >= $em[4]) && ($e < $em[1]) );
      $jump_factor *= $$hash_element{jump}{m3} if
	( ($e >= $em[3]) && ($e < $em[1]) );
      $jump_factor *= $$hash_element{jump}{m2} if
	( ($e >= $em[2]) && ($e < $em[1]) );

      ## n edges
      $jump_factor *= $$hash_element{jump}{m5} if
	( ($e >= $en[5]) && ($e < $en[1]) );
      $jump_factor *= $$hash_element{jump}{m4} if
	( ($e >= $en[4]) && ($e < $en[1]) );
      $jump_factor *= $$hash_element{jump}{m3} if
	( ($e >= $en[3]) && ($e < $en[1]) );
      $jump_factor *= $$hash_element{jump}{m2} if
	( ($e >= $en[2]) && ($e < $en[1]) );

      #};
      $sigma *= $jump_factor;
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
 EDGE_CHECK: foreach my $edge (qw(k l1 l2 l3 m1 m2 m3 m4 m5 n1 n2 n3 n4 n5 n6 n7)) {
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
    ($energy > $$rhash{k}) && do {
      $coefs = "a_k";
      last SELECT_EDGE;
    };
    ($energy > $$rhash{l1}) && do {
      $coefs = "a_l";
      last SELECT_EDGE;
    };
    ($energy > $$rhash{m1}) && do {
      $coefs = "a_m";
#      (get_Z($sym) < 30) && ($warnl = 1);
      last SELECT_EDGE;
    };
    $coefs = "a_n";
  };
  ##print join(" ", $$rhash{energy}{l1}, $energy, $coefs), $/;
  return ($energy, $coefs, $warnl);
};


1;

__END__

=head1 NAME

Xray::Absorption::Shaltout - Perl interface to the Shaltout tables

=head1 SYNOPSIS

   use Xray::Absorption;
   Xray::Absorption -> load("shaltout");

See the documentation for Xray::Absorption for details.

=head1 DESCRIPTION

This module is inherited by the Xray::Absorption module and provides
access to the data contained in

  Update of photoelectric absorption coefficients in the tables of McMaster
  Abdallah Shaltout, Horst Ebel, and Robert Svagera
  X-Ray Spectrometry (2006) vol. 35, p. 52-56

The data is contained in a database file called F<shaltout.db> which
is generated at install time from a flat text database of the data
which can be found at
L<http://www.ifp.tuwien.ac.at/forschung/abdallah.shaltout/> as
explained in the reference.

The required Chemistry::Elements module is available from CPAN in the
miscellaneous modules section.


=head1 EDGE AND LINE ENERGIES

The Shaltout data resource includes all K, L, M, and N edges but does
not provide any of the line energies.  An minimal set of line energies
is imported from the McMaster data resource.

=head1 BUGS AND THINGS TO DO

This module has not be tested sufficiently.

=head1 AUTHOR

  Bruce Ravel, bravel@bnl.gov
  http://cars9.uchicago.edu/~ravel/software/Absorption/

=cut

## Local Variables:
## time-stamp-line-limit: 25
## End:
