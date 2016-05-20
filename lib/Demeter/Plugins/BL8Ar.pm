package Demeter::Plugins::BL8Ar;  # -*- cperl -*-

use File::Copy;

use Moose;
extends 'Demeter::Plugins::FileType';

has '+is_binary'   => (default => 0);
has '+description' => (default => 'SLRI BL8 (with Ar in I0)');
has '+version'     => (default => 0.1);
has 'measurement_mode' => (is => 'rw', isa => 'Str', default => q{transmission});

my $ar_k = Xray::Absorption->get_energy('Ar', 'K') / 2;

sub is {
  my ($self) = @_;
  open(my $D, '<', $self->file) or $self->Croak("could not open " . $self->file . " as data (BL8Ar)\n");
  my $line = <$D>;
  my $is_bl8 = ($line =~ m{BL8: X-ray Absorption Spectroscopy}) ? 1 : 0;
  return 0 if not $is_bl8;
  my $is_near_ar = 0;
  while (<$D>) {
    if ($_ =~ m{\# E0 \(eV\)\s+=\s+(\d+)}) {
      $is_near_ar = 1 if (($ar_k - $1) < 200);
      last;
    };
  };
  close $D;
  return $is_near_ar;
};

sub fix {
  my ($self) = @_;

  my $file = $self->file;
  my $new = File::Spec->catfile($self->stash_folder, $self->filename);
  ($new = File::Spec->catfile($self->stash_folder, "toss")) if (length($new) > 127);
  open(my $D, '<', $file) or die "could not open $file as data (fix in BL8Ar)\n";
  open(my $N, ">", $new)  or die "could not write to $new (fix in BL8Ar)\n";

  my $format = q{};
  my $ncols = 0;
  my $nchannels = 0;
  my (@data_table, @e, @i0);
  while (<$D>) {
    next if ($_ =~ m{\A\s*\z});
    if ($_ =~ m{\A\#}) {
      print $N $_;
      if ($_ =~ m{Si Drift 4-Array}) {
	$self->measurement_mode('sidrift');
	$ncols = 10;
	$nchannels = 4;
      } elsif ($_ =~ m{Transmission-mode XAS}) {
	$self->measurement_mode('trans');
	$ncols = 6;
	$nchannels = 1;
      } elsif ($_ =~ m{Ge 13-array}i) {
	$self->measurement_mode('ge');
	$ncols = 19;
	$nchannels = 13;
      };
    } elsif ($_ =~ m{\AEnergy}) {
      1;
    } else {
      $_ =~ tr{\r}{}d;
      push @data_table, $_;
      my @list = split(" ", $_);
      push @e,  $list[0];
      push @i0, $list[3];
    };
  };
  $format = "%10.5E   " x $ncols . "\n";;

  print $N "# Energy   BraggAngle   TimeStep   I0   I1   mu";
  print $N "   SCA0   SCA1   SCA2   SCA3" if ($self->measurement_mode eq 'sidrift');
  print $N "   SCA0   SCA1   SCA2   SCA3   SCA4   SCA5   SCA6   SCA7   SCA8   SCA9   SCA10   SCA11   SCA12" if ($self->measurement_mode eq 'ge');
  print $N "\n";
  my $ar = Demeter::Data->put(\@e, \@i0, datatype=>'xanes', bkg_e0=>$ar_k,
			      bkg_pre1=>-30, bkg_pre2=>-10,
			      bkg_nor1=>10, bkg_nor2=>30, bkg_nnorm=>2,
			     );
  $ar->_update('background');
  #$ar->po->set(e_mu=>1, e_norm=>0, e_pre=>1, e_post=>1);
  #$ar->plot('E');
  #print $ar->bkg_step, $/;
  #return $new;
  my $step = $ar->bkg_step;
  foreach my $point (@data_table) {
    my @list = split(" ", $point);
    my $offset = ($list[0] > $ar_k) ? $step : 0;
    printf $N $format,
      @list[0..2], $list[3]-$offset, $list[4], $list[5]*$nchannels, @list[6..5+$nchannels];
  };
  close $N;
  close $D;

  $self->fixed($new);
  return $new;
};

sub suggest {
  my ($self, $which) = @_;
  $which ||= 'fluorescence';
  $which = 'transmission' if ($self->measurement_mode eq 'trans');
  if ($which eq 'transmission') {
    return (energy      => '$1',
	    numerator   => '$4',
	    denominator => '$5',
	    ln          =>  1,);
  } else {
    my $num = '$7+$8+$9+$10';
    $num = '$7+$8+$9+$10+$11+$12+$13+$14+$15+$16+$17+$18+$19' if ($self->measurement_mode eq 'ge');
    return (energy      => '$1',
	    numerator   => '$7+$8+$9+$10',
	    denominator => '$4',
	    ln          =>  0,);
  };
};


1;

=head1 NAME

Demeter::Plugin::BL8Ar - filetype plugin for removing the effect of Ar in I0 at SLRI BL8

=head1 VERSION

This documentation refers to Demeter version 0.9.25.

=head1 SYNOPSIS

This plugin converts attempts to remove the effect of the edge step
visible in I0 due to Ar contamination in the I0 chamber at SLRI BL8.
This removes the edge jump visible in I0 when measuring, for instance,
the Al K edge.

The Ar step is visible due to the presence of the second harmonic in
the incident beam, which is not normally filtered in any way at BL8.

=head1 METHODS

=over 4

=item C<is>

This file is identified by the string "BL8: X-ray Absorption
Spectroscopy" in the first line of the file, then by an edge energy
that is within 200 volts of the Ar K edge energy divided by 2.  (The
division by 2 is because the Ar signal is caused by the second
harmonic of the monochromator.)

=item C<fix>

Remove the step from I0, then suggest columns appropriate to the
measurement mode.

Note that column 6 is still the unaltered calculation of mu(E).  This
is left in for easy comparison between the raw and corrected measures
of mu(E).

=back

=head1 AUTHOR

  Bruce Ravel, L<http://bruceravel.github.io/home>
  http://bruceravel.github.io/demeter

=cut
