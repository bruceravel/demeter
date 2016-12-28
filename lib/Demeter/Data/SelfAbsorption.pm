package Demeter::Data::SelfAbsorption;

=for Copyright
 .
 Copyright (c) 2006-2016 Bruce Ravel (http://bruceravel.github.io/home).
 All rights reserved.
 .
 This file is free software; you can redistribute it and/or
 modify it under the same terms as Perl itself. See The Perl
 Artistic License.
 .
 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut


use Moose::Role;

use Demeter::Constants qw($ETOK $PI);
use Chemistry::Elements qw(get_symbol);
use Chemistry::Formula qw(parse_formula);
use List::Util qw(max min);
use Xray::Absorption;
use Xray::FluorescenceEXAFS;

=for LiteratureReference (sa)
   "In your country I'm told there is an act of will called 'absorbing.'
  What is that?"
    She held her red, dripping hands away from her draperies, and
  uttered a delicious, clashing laugh. "You think I am half a man?"
    "Answer my question."
    "I'm a woman through and through, Maskull -- to the marrowbone. But
  that's not to say I have never absorbed males."
    "And that means..."
    "New strings for my harp, Maskull.  A wider range of passions, a
  stormier heart..."
    "For you, yes -- But for them?..."
    "I don't know. The victims don't describe their experiences. Probably
  unhappiness of some sort—if they still know anything."
    "This is a fearful business!" he exclaimed, regarding her
  gloomily. "One would think Ifdawn a land of devils."
                             Voyage to Arcturus
                             David Lindsay

=cut

sub sa {
  my ($self, $how, @array) = @_;
  my %hash = @array;
  if (lc($how) !~ m{booth|troger|fluo|atoms}) {
    carp("Available self absorption algorithms are Fluo, Booth, Troger, and Atoms");
    return (0, q{});
  };
  if ((lc($how) eq 'fluo') and ($self->datatype eq 'chi')) {
    carp("The fluo algorithm is applied to mu(E) data and cannot be applied to a Data object of data type chi");
    return (0, q{});
  };
  $self->dispense("process", "sa_group");
  $hash{thickness} ||= 100000;
  $hash{in}        ||= 45;
  $hash{out}       ||= 45;
  $hash{density}   ||= 1;
  my $method = 'sa_' . lc($how);
  my ($sadata, $text) = $self->$method($hash{formula}, $hash{in}, $hash{out}, $hash{density}, $hash{thickness});
  $sadata->xdi_make_clone($self, sprintf("Self-absorption corrected (%s) data", $how), 0) if (Demeter->xdi_exists);
  return ($sadata, $text);
};

sub sa_troger {
  my ($self, $formula, $angle_in, $angle_out) = @_;
  $angle_in  ||= 45;
  $angle_out ||= 45;

  my %count;
  my $ok = parse_formula($formula, \%count);
  if (not $ok) {
    carp("Could not interpret formula \"$formula\".");
    return (0, q{});
  };
  $self->_update('bft');

  my ($efluo, $line) = $self->_efluo;
  my ($barns, $amu) = (0,0);
  foreach my $el (keys(%count)) {
    $barns += Xray::Absorption -> cross_section($el, $efluo) * $count{$el};
    $amu   += Xray::Absorption -> get_atomic_weight($el) * $count{$el};
  };
  my $muf = sprintf("%.6f", $barns / $amu / 1.6607143);

  if ($muf <= 0) {
    carp("Unable to compute cross section of absorber at the fluorescence energy");
    return (0, q{});
  };

  my @k = $self->fetch_array($self->group.".k");
  my @mut = ();
  my @mua = ();
  my $abs = ucfirst( lc(get_symbol($self->bkg_z)) );
  my $amuabs = Xray::Absorption -> get_atomic_weight($abs);
  ## @mua contains the array of absorption due to the excitation
  ## process of the absorber, $muabelow subtracts off an estimate of
  ## the absorption due to lower energy processes
  my $ebelow = Xray::Absorption -> get_energy($abs, $self->fft_edge) - 200;
  my $muabelow = Xray::Absorption -> cross_section($abs, $ebelow);
  foreach my $kk (@k) {
    my ($barns, $amu) = (0,0);
    ## note that care is taken to avoid a mismatch between the edge
    ## value of the tabulation of cross sections and the measured edge
    ## energyof the data.  using $self->bkg_e0 instead would result in
    ## a kink in the corrected data at a k value corresponding to that
    ## difference
    my $e = $self->k2e($kk, 'relative') + Xray::Absorption -> get_energy($self->bkg_z, $self->fft_edge) + 0.1;
    foreach my $el (keys(%count)) {
      $barns += Xray::Absorption -> cross_section($el, $e) * $count{$el};
      $amu   += Xray::Absorption -> get_atomic_weight($el) * $count{$el};
    };
    ## 1 amu = 1.6607143 x 10^-24 gm
    push @mua, $count{$abs} * (Xray::Absorption -> cross_section($abs, $e)-$muabelow) / $amu / 1.6607143;
    push @mut, $barns / $amu / 1.6607143;
  };
  $self->place_array("s___a.mut", \@mut);
  $self->place_array("s___a.mua", \@mua);

  $self->dispense("process", "sa_troger", {angle_in  => $angle_in,
					   angle_out => $angle_out,
					   muf       => $muf,
					  });

  my $text = "Troger algorithm\n";
  $text .= $self->_summary($efluo, $line, \%count);
  @k   = $self->fetch_array('s___a.k');
  my @chi = $self->fetch_array('s___a.chi');
  my $sadata = $self->sa_group(\@k, \@chi, 'chi');
  return ($sadata, $text);
};


sub sa_booth {
  my ($self, $formula, $angle_in, $angle_out, $density, $thickness) = @_;
  $thickness ||= 100000;
  $angle_in  ||= 45;
  $angle_out ||= 45;
  $density   ||= 1;

  my %count;
  my $ok = parse_formula($formula, \%count);
  if (not $ok) {
    carp("Could not interpret formula \"$formula\".");
    return (0, q{});
  };
  $self->_update('bft');

  my ($efluo, $line) = $self->_efluo;
  my ($barns, $amu) = (0,0);
  foreach my $el (keys(%count)) {
    $barns += Xray::Absorption -> cross_section($el, $efluo) * $count{$el};
    $amu   += Xray::Absorption -> get_atomic_weight($el) * $count{$el};
  };
  my $muf = sprintf("%.6f", $density * $barns / $amu / 1.6607143);

  if ($muf <= 0) {
    carp("Unable to compute cross section of absorber at the fluorescence energy");
    return (0, q{});
  };

  my @k = $self->fetch_array($self->group.".k");
  my @mut = ();
  my @mua = ();
  my $abs = ucfirst( lc(get_symbol($self->bkg_z)) );
  my $amuabs = Xray::Absorption -> get_atomic_weight($abs);
  my $ebelow = Xray::Absorption -> get_energy($abs, $self->fft_edge) - 200;
  my $muabelow = Xray::Absorption -> cross_section($abs, $ebelow);
  foreach my $kk (@k) {
    my ($barns, $amu) = (0,0);
    ## see the note in sa_troger about energy values
    my $e = $self->k2e($kk, 'relative') + Xray::Absorption -> get_energy($self->bkg_z, $self->fft_edge) + 0.1;
    foreach my $el (keys(%count)) {
      $barns += Xray::Absorption -> cross_section($el, $e) * $count{$el};
      $amu   += Xray::Absorption -> get_atomic_weight($el) * $count{$el};
    };
    ## 1 amu = 1.6607143 x 10^-24 gm
    push @mua, $density * $count{$abs} * (Xray::Absorption -> cross_section($abs, $e)-$muabelow) / $amu / 1.6607143;
    push @mut, $density * $barns / $amu / 1.6607143;
  };
  $self->place_array("s___a.mut", \@mut);
  $self->place_array("s___a.mua", \@mua);

  $self->dispense("process", "sa_booth_pre", {angle_in  => $angle_in,
					      angle_out => $angle_out,
					      thickness => 1e-4*$thickness,
					      muf       => $muf,
					     });
  my $text = "Booth and Bridges algorithm, thickness = $thickness microns\n";
  if ($thickness/sin($PI*$angle_in/180) < Demeter->co->default('absorption', 'thick_limit')) {
    $self->dispense("process", "sa_booth_thin");
    $text .= "thin sample formula\n\n";
  } else {
    $self->dispense("process", "sa_booth_thick");
    $text .= "thick sample formula\n\n";
  };
  $text .= $self->_summary($efluo, $line, \%count);

  @k   = $self->fetch_array('s___a.k');
  my @chi = $self->fetch_array('s___a.chi');
  my $sadata = $self->sa_group(\@k, \@chi, 'chi');
  return ($sadata, $text);

};

sub sa_atoms {
  my ($self, $formula) = @_;

  my %count;
  my $ok = parse_formula($formula, \%count);
  if (not $ok) {
    carp("Could not interpret formula \"$formula\".");
    return (0, q{});
  };
  $self->_update('bft');

  my $mm_sigsqr = Xray::FluorescenceEXAFS->mcmaster($self->bkg_z, $self->fft_edge);
  my $i0_sigsqr = Xray::FluorescenceEXAFS->i_zero($self->bkg_z,  $self->fft_edge,
						  {nitrogen=>1,argon=>0,krypton=>0});
  my ($self_amp, $self_sigsqr) = Xray::FluorescenceEXAFS->self($self->bkg_z, $self->fft_edge, \%count);
  my $net_sigsqr = $self_sigsqr+$i0_sigsqr+$i0_sigsqr;

  my $text = "Atoms algorithm\n";
  $text .= $self->_summary($self->_efluo, \%count);
  $text .= $self->template("process", "sa_atoms_text",
			   {amp  => sprintf("%.2f", $self_amp),
			    ss   => sprintf("%.6f", $net_sigsqr),
			    self => sprintf("%.6f", $self_sigsqr),
			    norm => sprintf("%.6f", $mm_sigsqr),
			    i0   => sprintf("%.6f", $i0_sigsqr)});

  $self->dispense("process", "sa_atoms", {amp=>$self_amp, ss=>$net_sigsqr});
  my @k   = $self->fetch_array('s___a.k');
  my @chi = $self->fetch_array('s___a.chi');
  my $sadata = $self->sa_group(\@k, \@chi, 'chi');
  return ($sadata, $text);
};


sub sa_fluo {
  my ($self, $formula, $angle_in, $angle_out, $density) = @_;
  $angle_in  ||= 45;
  $angle_out ||= 45;
  $density   ||= 1;

  my %count;
  my $ok = parse_formula($formula, \%count);
  if (not $ok) {
    carp("Could not interpret formula \"$formula\".");
    return (0, q{});
  };
  $self->_update('bft');

  my ($efluo, $line) = $self->_efluo;

  my $eplus = $self->bkg_e0 + $self->bkg_nor1 + $self->bkg_eshift;
  my $enominal = Xray::Absorption -> get_energy($self->bkg_z, $self->fft_edge);
  ($eplus = $enominal + 10) if ($eplus < $enominal);
  my ($barns_fluo, $barns_plus) = (0,0);
  my $mue_plus = 0;

  foreach my $k (keys %count) {

    ## compute contribution to mu_total at the fluo energy
    $barns_fluo += $count{$k} * Xray::Absorption -> cross_section($k, $efluo);

    if (lc($k) eq lc(get_symbol($self->bkg_z))) {
      ## compute contribution to mu_abs at the above edge energy
      $mue_plus = $count{$k} * Xray::Absorption -> cross_section($k, $eplus);
    } else {
      ## compute contribution to mu_back at the above edge energy
      $barns_plus += $count{$k} * Xray::Absorption -> cross_section($k, $eplus);
    };
  };

  if ($mue_plus <= 0) {
    carp("Unable to compute cross section of absorber above the edge");
    return (0, q{});
  };

  my @energy = $self->fetch_array($self->group.".energy");
  my @mub = ();
  foreach my $e (@energy) {
    my $barns = 0;
    foreach my $k (keys %count) {
      next if (lc($k) eq lc(get_symbol($self->bkg_z)));
      $barns += Xray::Absorption -> cross_section($k, $e+$self->bkg_eshift) * $count{$k};
    };
    push @mub, $barns;
  };
  $self->place_array("s___a.mub", \@mub);

  $self->dispense("process", "sa_fluo", {angle_in  => $angle_in,
					 angle_out => $angle_out,
					 mut_fluo  => $barns_fluo,
					 mub_plus  => $barns_plus,
					 mue_plus  => $mue_plus,
					});
  my $maxval;
  if ($self->is_ifeffit) {
    $maxval = $self->fetch_scalar("s___a_x");
  } else {
    my @arr = $self->fetch_array("s___a.sacorr");
    $maxval = max( max(@arr), abs(min(@arr)) );
  };

  my $text = "Fluo algorithm\n";
  $text .= $self->_summary($efluo, $line, \%count);
  if ($maxval > 30) {
    $text .= "

Yikes!  This correction seems to be numerically unstable.
Among the common reasons for this are:

  1. Providing the wrong chemical formula

  2. Having data from a sample that is not in the infinitely thick
     limit (the Fluo algorithm is not valid in the thin sample limit)

  3. Not including the matrix containing the sample in the formula for
     the stoichiometry (for instance, the formula for an aqueous solution
     must include the amount of H2O relative to the sample)
";
  };
  my @e   = $self->fetch_array('s___a.energy');
  my @xmu = $self->fetch_array('s___a.sacorr');
  my $sadata = $self->sa_group(\@e, \@xmu, 'xmu');
  return ($sadata, $text);

};

sub sa_group {
  my ($self, $k, $chi, $datatype) = @_;
  my $sadata = Demeter::Data -> put($k, $chi, datatype=>$datatype);
  foreach my $att (qw(fft_kmin fft_kmax fft_dk fft_kwindow bkg_z fft_edge fft_pc
		      bft_rmin bft_rmax bft_dr bft_rwindow)) {
    $sadata->$att($self->$att);
  };
  if ($datatype eq 'xmu') {
    foreach my $att (qw(bkg_pre1 bkg_pre2 bkg_nor1 bkg_nor2 bkg_spl1 bkg_spl2 bkg_rbkg bkg_kw
			bkg_clamp1 bkg_clamp2 bkg_nnorm bkg_e0)) {
      $sadata->$att($self->$att);
    };
  };
  $sadata->name('SA  ' . $self->name);
  return $sadata;
};

sub info_depth {
  my ($self, $formula, $angle_in, $angle_out, $space) = @_;

  my %count;
  my $ok = parse_formula($formula, \%count);
  if (not $ok) {
    carp("Could not interpret formula \"$formula\".");
    return (0, q{});
  };
  my ($efluo, $line) = $self->_efluo;
  my ($barns, $amu) = (0,0);
  foreach my $el (keys %count) {
    $barns += Xray::Absorption -> cross_section($el, $efluo) * $count{$el};
    $amu   += Xray::Absorption -> get_atomic_weight($el) * $count{$el};
  };
  my $muf = sprintf("%.6f", $barns / $amu / 1.6607143);

  my @k = $self->fetch_array($self->group.".k");
  my $kmax = min($k[-1], $self->po->kmax);
  my @mut = ();
  foreach my $kk (@k) {
    my ($barns, $amu) = (0,0);
    my $e = $self->k2e($kk, 'relative') + Xray::Absorption -> get_energy($self->bkg_z, $self->fft_edge) + 0.1;
    foreach my $el (keys %count) {
      $barns += Xray::Absorption -> cross_section($el, $e) * $count{$el};
      $amu   += Xray::Absorption -> get_atomic_weight($el) * $count{$el};
    };
    ## 1 amu = 1.6607143 x 10^-24 gm
    push @mut, $barns / $amu / 1.6607143;
  };
  $self->place_array("s___a.mut", \@mut);

  $self->dispense("process", "sa_info_depth", {in  => $angle_in,
					       out => $angle_out,
					       muf => $muf,
					      });
  my @x = $self->get_array('k');
  if (lc($space) eq 'e') {
    @x = map {$self->bkg_e0 + $_**2/$ETOK} @x;
  };
  my @y = $self->fetch_array('s___a.info');
  return (\@x, \@y);
};

sub _efluo {
  my ($self) = @_;
  my $line = 'Ka1';
 SWITCH: {
    $line = 'Ka1', last SWITCH if (lc($self->fft_edge) eq 'k');
    $line = 'La1', last SWITCH if (lc($self->fft_edge) eq 'l3');
    $line = 'Lb1', last SWITCH if (lc($self->fft_edge) eq 'l2');
    $line = 'Lb3', last SWITCH if (lc($self->fft_edge) eq 'l1');
    $line = 'Ma',  last SWITCH if (lc($self->fft_edge) =~ /^m/);
  };
  return (Xray::Absorption -> get_energy($self->bkg_z, $line), $line);
};

sub _summary {
  my ($self, $efluo, $line, $rcount) = @_;
  my $ee = $self->bkg_e0;
  $ee = Xray::Absorption->get_energy($self->bkg_z, $self->fft_edge) if $ee < 10; # chi data...
  my $text = sprintf "%s %s edge, edge energy = %.1f\n", ucfirst($self->bkg_z), ucfirst($self->fft_edge), $ee;
  $text .= sprintf "Dominent fluorescence line is %s (%s), energy = %.2f\n\n",
    Xray::Absorption->get_Siegbahn_full($line), Xray::Absorption->get_IUPAC($line), $efluo;
  $text .= "  Element   number\n";
  $text .= " ---------------------\n";
  foreach my $el (sort(keys(%$rcount))) {
    $text .= sprintf("    %2s      %.3f\n", $el, $rcount->{$el});
  };
  (my $which = Xray::Absorption->current_resource) =~ s{(\..*\z)}{};
  $text .= "\n(using the $which tables)\n";
  return $text;
};



1;

=head1 NAME

Demeter::Data::SelfAbsorption - Self-absorption corrections for mu(E) data

=head1 VERSION

This documentation refers to Demeter version 0.9.26.

=head1 DESCRIPTION

This role of L<Demeter::Data> contains methods for calculating
self-absorption corrections for mu(E) data using various algorithms.

=head1 METHODS

=over 4

=item C<sa>

Compute the correction using one of the following methods:

=over 4

=item B<fluo>

This corrects mu(E) data using an algorithm developed by Bruce along
with Ed Stern and Dani Haskel.  This was first implemented by Dani
Haskel and then reimplemented into the original Athena.  It is the
only correction method here that is applied to mu(E) data.

=item B<Troger>

This is a correction to chi(k) that applies only in the thick sample limit.

=item B<Booth>

This improvement on the Troger algorithm was developed by Corwin Booth
and Bud Bridges and can applied to a sample of any thickness, although
the density of the sample must be supplied.  In the thick sample
limit, it is identical to the Troger correction.

=item B<atoms>

This correction to chi(k) computes the effects of normalization, i0,
and self absorption using L<Xray::FluorescenceEXAFS>.  It is a fairly
crude approximation and is only valid in the thick sample limit.  It
also does not consider the effect of incident or exit angle.

=back

  $data -> po -> strt_plot;
  $data -> plot('k');
  my ($sadata, $text) = $data->sa($method, formula=>$formula, in=>$angle_in
                                  out=>$angle_out, thickness=>$thickness);
  $sadata -> plot('k');
  print $text;

The method returns a reference to a Data object containing the
corrected data and a scalar containing the textual response from the
selected correction method.

The formula must be provided and must be specified using the syntax of
L<Chemistry::Formula>.  Defaults for in and out are 45 degrees an the
default for thickness is to compute in the thick sample limit.

The named arguments can appear in any order, but the first item in the
argument list must be the correction method.

=item C<info_depth>

Return arrays of wavenumber and information depth where the
information depth represents the depth from which signal is retrieved
from the sample.  Essentially, this plots the energy dependence of the
absorption length over the k-range of the data.

  my ($ref_k, $ref_info) = $data->info_depth(formula=>$formula,
                                             in=>$angle_in
                                             out=>$angle_out);

The returned values are array references.

=back

=head1 CONFIGURATION

See L<Demeter::Config> for a description of the configuration system.

=head1 REFERENCES

=over 4

=item B<Fluo algorithm>

The program documentation for Fluo can be found at Dani's web site and
includes the mathematical derivation:
L<http://www.aps.anl.gov/xfd/people/haskel/fluo.html>.

=item B<Booth Algorithm>

C. H. Booth and F. Bridges, Physica Scripta, T115, (2005) p. 202.
DOI:10.1238/Physica.Topical.115a00202 See also Corwin's web site:
L<http://lise.lbl.gov/RSXAP/>

=item B<Troger Algorithm>

L. Troger, et al., Phys. Rev., B46:6, (1992) p. 3283
DOI: 10.1103/PhysRevB.46.3283

=item B<Pfalzer Algorithm>

Another interesting approach to correcting self-absorption is
presented in P. Pfalzer et al., Phys. Rev., B60:13, (1999)
p. 9335. DOI: 10.1103/PhysRevB.60.9335

This is not implemented in Demeter because the main result
requires an integral over the solid angle subtended by the
detector. This could be implemented, but the amount of solid angle
subtended it is not something one typically writes in the lab
notebook. If anyone is really interested in having this algorithm
implemented, contact Bruce.

=item B<Atoms Algorithm>

B. Ravel, J. Synchrotron Radiat., 8:2, (2001) p. 314. DOI:
10.1107/S090904950001493X

See also the documentation for Atoms at Bruce's website for more
details about it's fluorescence correction calculations.

=item B<Elam tables of absorption coefficients>

W.T. Elam, B.Ravel, and J.R. Sieber, Radiat. Phys. Chem., 63, (2002)
p. 121-128, DOI: 10.1016/S0969-806X(01)00227-4

=back

=head1 BUGS AND LIMITATIONS

Please report problems to the Ifeffit Mailing List
(L<http://cars9.uchicago.edu/mailman/listinfo/ifeffit/>)

Patches are welcome.

=head1 AUTHOR

Bruce Ravel, L<http://bruceravel.github.io/home>

L<http://bruceravel.github.io/demeter/>

With help from Dan Olive and Corwin Booth

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2016 Bruce Ravel (L<http://bruceravel.github.io/home>). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut

