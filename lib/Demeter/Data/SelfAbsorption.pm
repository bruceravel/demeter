package Demeter::Data::SelfAbsorption;
use Moose::Role;

use Chemistry::Elements qw(get_symbol);
use Chemistry::Formula qw(parse_formula);
use Xray::Absorption;

sub sa_booth {
  my ($self, $formula, $thickness, $angle_in, $angle_out) = @_;
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

  my $line = 'Ka1';
 SWITCH: {
    $line = 'Ka1', last SWITCH if (lc($self->fft_edge) eq 'k');
    $line = 'La1', last SWITCH if (lc($self->fft_edge) eq 'l3');
    $line = 'Lb1', last SWITCH if (lc($self->fft_edge) eq 'l2');
    $line = 'Lb3', last SWITCH if (lc($self->fft_edge) eq 'l1');
    $line = 'Ma',  last SWITCH if (lc($self->fft_edge) =~ /^m/);
  };
  my $efluo = Xray::Absorption -> get_energy($self->bkg_z, $line);

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
    my $e = $self->k2e($kk, 'absolute') + $self->bkg_eshift;
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
