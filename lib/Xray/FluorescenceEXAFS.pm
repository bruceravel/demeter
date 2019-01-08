package Xray::FluorescenceEXAFS;
##  This module is copyright (c) 1998-2009, 2014-2019 Bruce Ravel
##  <L<http://bruceravel.github.io/home>>
##  http://bruceravel.github.io/demeter/

require Exporter;

use Xray::Absorption;
use Statistics::Descriptive;
use strict;
use warnings;
use version;
use Const::Fast;

const my $ETOK => 0.2624682917;

use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);

@ISA = qw(Exporter AutoLoader);

$VERSION = version->new("3.0.0");

sub mcmaster {
  my ($class, $element, $edge) = @_;
  $edge = lc($edge);
  my $emin = Xray::Absorption -> get_energy($element, $edge) + 10 ;
  my ($emax, $span, $npost) = (0, 300, 20);

  ## get energy range for above edge fit
  my %next_e = ("l1"=>"k", "l2"=>"l1", "l3"=>"l2", "m"=>"l3");
  if (exists $next_e{$edge}) {
    $emax = Xray::Absorption -> get_energy($element, $next_e{$edge}) - 10;
    $emax = (($emax - $emin) > $span) ? $emin + $span : $emax;
  } else {
    $emax = $emin + $span;
  };

  ## need to show some care with the Chantler data
  (Xray::Absorption -> current_resource() =~ /chantler/i) and
    $emin += 50;
  ($emin >= $emax) and ($emin = $emax - 20); # whatever!

  my ($bpre, $slope) = _mcmaster_pre_edge($element, $edge);
  my $delta  = ($emax - $emin)/$npost;
  my @i=(0..$npost-1);		# load the post edge energies and sigmas
  my @energy = map {$emin + $delta*$_} @i;
  ## and some more care...
  (Xray::Absorption -> current_resource() =~ /chantler/i) and do {
    shift @energy; shift @energy;
  };
  return 0 if ($bpre <= 0);
  my @sigma  = Xray::Absorption -> cross_section($element, \@energy);
  @sigma = map {$sigma[$_] - ($bpre+$energy[$_]*$slope)} (0 .. $#energy);
  ##map {printf "      %9.3f %9.3f\n", $energy[$_], $sigma[$_]} (0 .. $#energy);
  @energy    = map {$ETOK * ($_-$emin)} @energy; # convert to k
  my $any_neg = grep {$_ <= 0} @sigma;
  return 0 if $any_neg;
  @sigma     = map {log($_)} @sigma;       # take logs of xsecs

  my $stat = Statistics::Descriptive::Full->new(); # fit the post edge
  $stat -> add_data(@sigma);
  my @a = $stat -> least_squares_fit(@energy);
  return ($a[1] < 0) ? -$a[1]/2 : 0;
};

sub _mcmaster_pre_edge {
  my ($element, $edge) = @_;
  $edge = lc($edge);
  my $emin = Xray::Absorption -> get_energy($element, $edge) - 10;
  ## find the pre-edge line
  my %next_e = ("k"=>"l1", "l1"=>"l2", "l2"=>"l3", "l3"=>"m");
  my $ebelow;
  if (exists $next_e{$edge}) {
    $ebelow = Xray::Absorption -> get_energy($element, $next_e{$edge}) + 10;
    $ebelow = (($emin - $ebelow) > 100) ? $emin - 100 : $ebelow;
  } else {
    $ebelow = $emin - 100;
  };
  my $delta  = ($emin - $ebelow)/10;;
  my @i=(0..9);			# load the pre edge energies/sigmas
  my @energy = map {$ebelow + $delta*$_} @i;
  my @sigma  = Xray::Absorption -> cross_section($element, \@energy);
				#  and fit 'em
  my $pre_edge = Statistics::Descriptive::Full->new();
  $pre_edge -> add_data(@sigma);
  my ($bpre, $slope) = $pre_edge -> least_squares_fit(@energy);
  $bpre ||= 0; $slope ||= 0;
  return ($bpre, $slope);
};



sub i_zero {
  my ($class, $central, $edge, $gases) = @_;

  ##   convert from pressure percentages to number of absorbers.
  ## nitrogen is diatomic
  $gases->{nitrogen} ||= 0;
  $gases->{argon}    ||= 0;
  $gases->{krypton}  ||= 0;

  my $helium    = 1 - $gases->{nitrogen} - $gases->{argon} - $gases->{krypton};
  my $norm      = $helium + 2*$gases->{nitrogen} + $gases->{argon} + $gases->{krypton};
  my $nitrogen  = 2*$gases->{nitrogen} / $norm;
  my $argon     = $gases->{argon}      / $norm;
  my $krypton   = $gases->{krypton}    / $norm;

  my $emin = Xray::Absorption -> get_energy($central, $edge) ;
  my ($emax, $span, $npost) = (0, 500, 20);
  ## careful not to run a gas edge
  my ($el, $ed, $en) = Xray::Absorption -> next_energy($central, $edge, "ar", "n", "kr");
  if (not defined $en) {
    $emax = $emin + $span;
  } else {
    $emax = ( ($en - 10) < ($emin + $span) ) ? ($en - 10) : ($emin + $span);
  };
  ## need to show some care with the Chantler data
  (Xray::Absorption -> current_resource() =~ /chantler/i) and
    $emin += 50;
  ($emin >= $emax) and ($emin = $emax - 20); # whatever!

  my @i=(0..$npost-1);		# load the post edge energies and sigmas
  my $delta  = ($emax - $emin)/$npost;
  my @energy = map {$emin + $delta*$_} @i;
  my @s_n = Xray::Absorption -> cross_section("n",  \@energy);
  my @s_a = Xray::Absorption -> cross_section("ar", \@energy);
  my @s_k = Xray::Absorption -> cross_section("kr", \@energy);
  my @sigma  = map
  {$nitrogen*$s_n[$_] + $argon*$s_a[$_] + $krypton*$s_k[$_]} (0 .. $#energy);
  @energy    = map {$ETOK * ($_-$emin)} @energy; # convert to k
  @sigma     = map {log($_)} @sigma;       # take logs of xsecs

  my $stat = Statistics::Descriptive::Full->new(); # fit the post edge
  $stat -> add_data(@sigma);
  my @a = $stat -> least_squares_fit(@energy);
  return -$a[1]/2;
};


sub self {
  my ($class, $central, $edge, $rcount) = @_;
  my @list = keys %$rcount;

  my $emin = Xray::Absorption -> get_energy($central, $edge) ;
  my ($emax, $span, $npost) = (0, 800, 20);
  my ($el, $ed, $en) = Xray::Absorption -> next_energy($central, $edge, @list);
  if (not defined $en) {
    $emax = $emin + $span;
  } else {
    $emax = ( ($en - 10) < ($emin + $span) ) ? ($en - 10) : ($emin + $span);
  };
  ## need to show some care with the Chantler data
  (Xray::Absorption -> current_resource() =~ /chantler/i) and
    $emin += 50;
  ($emin >= $emax) and ($emin = $emax - 20); # whatever!

  ## calculate total absorption at the fluorescence energy and 10
  ## volts below the edge
  my $xmuf = 0;
  my $fline   = substr($edge, 0, 1) . "alpha";
  my $e_fluor = Xray::Absorption -> get_energy($central, $fline);
  #my $e_below = $emin - 10;
  foreach my $atom (@list) {
    $xmuf += scalar Xray::Absorption -> cross_section($atom, $e_fluor) * $$rcount{$atom};
  };

  ## load the post edge energies and sigmas
  my @i=(0..$npost-1);
  my $delta  = ($emax - $emin)/$npost;
  my @energy = map {$emin + $delta*$_} @i;

  my @sigma = ();
  foreach my $j (@i) {
    my $xmu = 0;
    my $xmu_core = 0;
    foreach my $atom (@list) {
      if (lc($atom) eq lc($central)) {
	$xmu_core += $$rcount{$atom} * Xray::Absorption -> cross_section($atom, $energy[$j]);
      } else {
	$xmu += $$rcount{$atom} * Xray::Absorption -> cross_section($atom, $energy[$j]);
      };
    };
    $sigma[$j] = ($xmuf+$xmu+$xmu_core)/($xmuf+$xmu);
  };

  @energy = map {$ETOK * ($_-$emin)} @energy; # convert to k
  @sigma  = map {log($_)} @sigma;

  my $stat = Statistics::Descriptive::Full->new(); # fit the post edge
  $stat -> add_data(@sigma);
  my @a = $stat -> least_squares_fit(@energy);
  return (exp($a[0]), -$a[1]/2);
}


{
  # alternate names
  no warnings 'once';
  *normalization  = \ &mcmaster;
  *edgestep	  = \ &mcmaster;
  *izero	  = \ &i_zero;
  *i0		  = \ &i_zero;
  *overabsorption = \ &self
};


1;
__END__

=head1 NAME

Xray::FluorescenceEXAFS - Corrections for fluorescence EXAFS data

=head1 DESCRIPTION

This provides class methods for computing corrections to fluorescence
EXAFS data due to normalization, I0, and self-absorption effects.  The
corrections are computed from x-ray absorption coefficients provided
by the Xray::Absorption package.

=head1 METHODS

Note that the values returned for all methods depend on the data
resource used.  See L<Xray::Absorption>.

=over 4

=item C<mcmaster>

This is called C<mcmaster> for historical reasons.  It calculates the
normalization correcion for a given element.

  $sigma_mm = Xray::FluorescenceEXAFS->mcmaster($element, $edge);

It takes the central atoms tag and the alphanumeric edge symbol as
arguments and returns the normalization correction in units of
Angstrom squared.

C<normalization> and C<edgestep> are aliases for this method.

=item C<i0>

This calculates the correcion due to the I0 fill gases in a
fluorescence experiment.

  $gases = {nitrogen=>$nitrogen, argon=>$argon, krypton=>$krypton};
  $sigma_i0 = Xray::FluorescenceEXAFS->i_zero($central, $edge, $gases);

It takes the central atoms tag, the alphanumeric edge symbol, and a
reference to a hash containing the volume percentages of the three
gases as arguments.  It assumes that any remaining volume is filled
with helium and it correctly accounts for the fact that nitrogen is a
diatom.  It returns the I0 correction in units of Angstrom squared.

C<i_zero> and C<izero> are aliases for this method.

=item C<self>

This calculates the correcion due to self-absorption fluorescence
experiment.  It assumes that the sample is infinately thick and that
the entry and exit angles of the photons are the same.

  $contents = {Y=>1, Ba=>2, Cu=>3, O=>7};
  ($amp_i0, $sigma_i0) = Xray::FluorescenceEXAFS->self($central, $edge, $contents);

It takes the central atoms tag, the alphanumeric edge symbol, and a
reference to a hash which counts the atoms in the unit cell.  It
returns a list whose zeroth element is the multiplicative amplitude
correction and whose first element is the sigma^2 correction in units
of Angstrom squared.

C<overabsorption> is an aliases for this method.

=back

=head1 BUGS AND LIMITATIONS

=over 4

=item *

Fourth cumulant corrections are not calculated.

=item *

Geometry and thickness effects are not included in the self absorption calculation

=back

Please report problems to the Ifeffit Mailing List
(L<http://cars9.uchicago.edu/mailman/listinfo/ifeffit/>)

Patches are welcome.

=head1 AUTHOR

Bruce Ravel, L<http://bruceravel.github.io/home>

http://bruceravel.github.io/demeter/


=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2008 Bruce Ravel (L<http://bruceravel.github.io/home>). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
