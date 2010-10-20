package Demeter::Data::SelfAbsorption;

=for Copyright
 .
 Copyright (c) 2006-2010 Bruce Ravel (bravel AT bnl DOT gov).
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

use Chemistry::Elements qw(get_symbol);
use Chemistry::Formula qw(parse_formula);
use Xray::Absorption;

sub sa {
  my ($self, $how, @array) = @_;
  my %hash = @array;
  if (lc($how) !~ m{booth|troger|fluo|atoms}) {
    carp("Available self absorption algorithms are Fluo, Booth, Troger, and Atoms");
    return (0, q{});
  };
  $hash{thickness} ||= 100000;
  $hash{in}        ||= 45;
  $hash{out}       ||= 45;
  my $method = 'sa_' . lc($how);
  return $self->$method($hash{formula}, $hash{in}, $hash{out}, $hash{thickness});
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

  my ($efluo, $line) = $self->efluo;
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

  my @k = Ifeffit::get_array($self->group.".k");
  my @mut = ();
  my @mua = ();
  my $abs = ucfirst( lc(get_symbol($self->bkg_z)) );
  my $amuabs = Xray::Absorption -> get_atomic_weight($abs);
  foreach my $kk (@k) {
    my ($barns, $amu) = (0,0);
    my $e = $self->k2e($kk, 'relative') + Xray::Absorption -> get_energy($self->bkg_z, $self->fft_edge) + 0.1;
    foreach my $el (keys(%count)) {
      $barns += Xray::Absorption -> cross_section($el, $e) * $count{$el};
      $amu   += Xray::Absorption -> get_atomic_weight($el) * $count{$el};
    };
    ## 1 amu = 1.6607143 x 10^-24 gm
    push @mua, $count{$abs} * Xray::Absorption -> cross_section($abs, $e) / $amu / 1.6607143;
    push @mut, $barns / $amu / 1.6607143;
  };
  Ifeffit::put_array("s___a.mut", \@mut);
  Ifeffit::put_array("s___a.mua", \@mua);

  $self->dispose($self->template("process", "sa_troger", {angle_in  => $angle_in,
							  angle_out => $angle_out,
							  muf       => $muf,
							 }));

  my $text = "Troger algorithm\n";
  $text .= sprintf "Fluorescence line is %s (%s), energy = %.2f\n",
    Xray::Absorption->get_Siegbahn_full($line), Xray::Absorption->get_IUPAC($line), $efluo;
  @k   = Ifeffit::get_array('s___a.k');
  my @chi = Ifeffit::get_array('s___a.chi');
  my $sadata = $self->sa_group(\@k, \@chi);
  return ($sadata, $text);

};


sub sa_booth {
  my ($self, $formula, $angle_in, $angle_out, $thickness) = @_;
  $thickness ||= 100000;
  $angle_in  ||= 45;
  $angle_out ||= 45;

  my %count;
  my $ok = parse_formula($formula, \%count);
  if (not $ok) {
    carp("Could not interpret formula \"$formula\".");
    return (0, q{});
  };
  $self->_update('bft');

  my ($efluo, $line) = $self->efluo;
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

  my @k = Ifeffit::get_array($self->group.".k");
  my @mut = ();
  my @mua = ();
  my $abs = ucfirst( lc(get_symbol($self->bkg_z)) );
  my $amuabs = Xray::Absorption -> get_atomic_weight($abs);
  foreach my $kk (@k) {
    my ($barns, $amu) = (0,0);
    my $e = $self->k2e($kk, 'relative') + Xray::Absorption -> get_energy($self->bkg_z, $self->fft_edge) + 10.1;
    foreach my $el (keys(%count)) {
      $barns += Xray::Absorption -> cross_section($el, $e) * $count{$el};
      $amu   += Xray::Absorption -> get_atomic_weight($el) * $count{$el};
    };
    ## 1 amu = 1.6607143 x 10^-24 gm
    push @mua, $count{$abs} * Xray::Absorption -> cross_section($abs, $e) / $amu / 1.6607143;
    push @mut, $barns / $amu / 1.6607143;
  };
  Ifeffit::put_array("s___a.mut", \@mut);
  Ifeffit::put_array("s___a.mua", \@mua);

  $thickness *= 10e-4;

  $self->dispose($self->template("process", "sa_booth_pre", {angle_in  => $angle_in,
							     angle_out => $angle_out,
							     thickness => $thickness,
							     muf       => $muf,
							    }));
  my $betamin = Ifeffit::get_scalar("s___a___x");
  my $isneg = Ifeffit::get_scalar("s___a___xx");
  my $thickcheck = ($betamin < 10e-7) || ($isneg < 0);
  my $text = "Booth and Bridges algorithm, ";
  if ($thickcheck > 0.005) {	# huh????
    $self->dispose($self->template("process", "sa_booth_thick"));
    $text .= "thick sample limit\n";
  } else {
    $self->dispose($self->template("process", "sa_booth_thin"));
    $text .= "thin sample limit\n";
  };
  $text .= sprintf "Fluorescence line is %s (%s), energy = %.2f\n",
    Xray::Absorption->get_Siegbahn_full($line), Xray::Absorption->get_IUPAC($line), $efluo;

  @k   = Ifeffit::get_array('s___a.k');
  my @chi = Ifeffit::get_array('s___a.chi');
  my $sadata = $self->sa_group(\@k, \@chi);
  return ($sadata, $text);

};

sub efluo {
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

  my $answer = $self->template("process", "sa_atoms_text",
			       {amp  => sprintf("%.2f", $self_amp),
				ss   => sprintf("%.6f", $net_sigsqr),
				self => sprintf("%.6f", $self_sigsqr),
				norm => sprintf("%.6f", $mm_sigsqr),
				i0   => sprintf("%.6f", $i0_sigsqr)});

  $self->dispose($self->template("process", "sa_atoms", {amp=>$self_amp, ss=>$net_sigsqr}));
  my @k   = Ifeffit::get_array('s___a.k');
  my @chi = Ifeffit::get_array('s___a.chi');
  my $sadata = $self->sa_group(\@k, \@chi);
  return ($sadata, $answer);
};


sub sa_group {
  my ($self, $k, $chi) = @_;
  my $sadata = Demeter::Data -> put($k, $chi, datatype=>'chi');
  foreach my $att (qw(fft_kmin fft_kmax fft_dk fft_kwindow bkg_z fft_edge fft_pc
		      bft_rmin bft_rmax bft_dr bft_rwindow)) {
    $sadata->$att($self->$att);
  };
  return $sadata;
};


1;

=head1 NAME

Demeter::Data::SelfAbsorption - Self-absorption corrections for mu(E) data

=head1 VERSION

This documentation refers to Demeter version 0.4.

=head1 DESCRIPTION

This role of L<Demeter::Data> contains methods for calculating
self-absorption corrections for mu(E) data using various algorithms.

=head1 METHODS

=over 4

=item C<sa>

Compute the correction using one of the following methods:

=over 4

=item B<fluo>

This corrects mu(E) data using an algorithm first developed by Bruce
and implemented by Dani Haskel.  It is the only correction that is applied
to mu(E) data,

=item B<Troger>

This is a correction to chi(k) that applies only in the thick sample limit.

=item B<Booth>

This improvement on the Troger algorithm was developed by Booth and
Bridges and can applied to a sample of any thickness.  in the thick
sample limit, it is identical to the Troger correction.

=item B<atoms>

This correction to chi(k) computes the effects of normalization, i0,
and self absorption using L<Xray::FluorescenceEXAFS>.  It is a fairly
crude approximation and is only valid in the thick sample limit.  It
also does not consider the effect of incident or exit angle.

=back

 $data->sa($method, formula=>$formula, in=>$angle_in
           out=>$angle_out, thickness=>$thickness);

The formula must be provided and must be specified using the syntax of
L<Chemistry::Formula>.  Defaults for in and out are 45 degrees an the
default for thickness is to compute in the thick sample limit.

The named arguments can appear in any order, but the first item in the
argument list must be the correction method.

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

C. H. Booth and F. Bridges, Physica Scripta, T115, (2005) p. 202. See
also Corwin's web site: L<http://lise.lbl.gov/RSXAP/>

=item B<Troger Algorithm>

L. Troger, et al., Phys. Rev., B46:6, (1992) p. 3283

=item B<Pfalzer Algorithm>

Another interesting approach to correcting self-absorption is
presented in P. Pfalzer et al., Phys. Rev., B60:13, (1999)
p. 9335. This is not implemented in ATHENA because the main result
requires an integral over the solid angle subtended by the
detector. This could be implemented, but the amount of solid angle
subtended it is not something one typically writes in the lab
notebook. If anyone is really interested in having this algorithm
implemented, contact Bruce.

=item B<Atoms Algorithm>

B. Ravel, J. Synchrotron Radiat., 8:2, (2001) p. 314. See also the
documentation for Atoms at Bruce's website for more details about it's
fluorescence correction calculations.

=item B<Elam tables of absorption coefficients>

W.T. Elam, B.Ravel, and J.R. Sieber, Radiat. Phys. Chem., 63, (2002)
p. 121-128

=back

=head1 BUGS AND LIMITATIONS

Please report problems to Bruce Ravel (bravel AT bnl DOT gov)

Patches are welcome.

=head1 AUTHOR

Bruce Ravel (bravel AT bnl DOT gov)

L<http://cars9.uchicago.edu/~ravel/software/>

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2010 Bruce Ravel (bravel AT bnl DOT gov). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut

