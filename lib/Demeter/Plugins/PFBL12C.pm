package Demeter::Plugins::PFBL12C;  # -*- cperl -*-

use Moose;
extends 'Demeter::Plugins::FileType';

has '+is_binary'   => (default => 0);
has '+description' => (default => 'Photon Factory and SPring8 XAS Beamlines');
has '+version'     => (default => 0.3);

use Demeter::Constants qw($PI);
use Const::Fast;
const my $HC      => 12398.52;	# slightly different than in D::C
#const my $HBARC   => 1973.27053324;
#const my $TWODONE => 6.2712;	# Si(111)
#const my $TWODTHR => 3.275;	# Si(311)

sub is {
  my ($self) = @_;
  open D, $self->file or $self->Croak("could not open " . $self->file . " as data (Photon Factory/SPring8)\n");
  my $line = <D>;
  close D;
  return 1 if ($line =~ m{9809\s+(?:KEK-PF|SPring-8)\s+(?:(BL\d+)|(NW\d+)|(\d+\w+\d*))});
  return 0;
};

sub fix {
  my ($self) = @_;

  my $file = $self->file;
  my $new = File::Spec->catfile($self->stash_folder, $self->filename);
  ($new = File::Spec->catfile($self->stash_folder, "toss")) if (length($new) > 127);
  open my $D, $file or die "could not open $file as data (fix in PFBL12C)\n";
  open my $N, ">".$new or die "could not write to $new (fix in PFBL12C)\n";

  my $header = 1;
  my $ddistance = 1;
  #my @offsets;
  while (<$D>) {
    next if ($_ =~ m{\A\s*\z});
    last if ($_ =~ m{});
    chomp;
    if ($header and ($_ =~ m{\A\s+offset}i)) {
      my $this = $_;
      #@offsets = split(" ", $this);
      print $N '# ', $_, $/;
      print $N '# --------------------------------------------------', $/;
      print $N '# energy_requested   energy_attained  time  i0  i1  ', $/;
      $header = 0;
    } elsif ($header) {
      my $this = $_;
      if ($this =~ m{d=\s+(\d\.\d+)\s+A}i) {
	$ddistance = $1*2;
      };
      print $N '# ', $_, $/;
    } else {
      my @list = split(" ", $_);
      $list[0] = ($HC) / ($ddistance * sin($list[0] * $PI / 180));
      $list[1] = ($HC) / ($ddistance * sin($list[1] * $PI / 180));
      my $ndet = $#list-2;
      foreach my $i (1..$ndet) {
	$list[2+$i] = $list[2+$i]; # - $offsets[2+$i];
      };
      my $pattern = "  %9.3f  %9.3f  %6.2f" . "  %12.3f" x $ndet . $/;
      printf $N $pattern, @list;
    };
  };
  close $N;
  close $D;
  $self->fixed($new);
  return $new;
};

sub suggest {
  my ($self, $which) = @_;
  $which ||= 'transmission';
  if ($which eq 'transmission') {
    return (energy      => '$2',
	    numerator   => '$4',
	    denominator => '$5',
	    ln          =>  1,);
  } else {
    return ();
  };
};

__PACKAGE__->meta->make_immutable;
1;

=head1 NAME

Demeter::Plugin::PFBL12C - filetype plugin for Photon Factory and SPring8

=head1 VERSION

This documentation refers to Demeter version 0.9.9.

=head1 SYNOPSIS

This plugin converts data recorded as a function of mono angle to data
as a function of energy.

=head1 METHODS

=over 4

=item C<is>

This file is identified by the string "KEK-PF" or "SPring-8" followed
by the beamline number in the first line of the file.

=item C<fix>

Convert the wavelength array to energy using the formula

   data.energy = 2 * pi * hbarc / 2D * sin(data.angle)

where C<hbarc=1973.27053324> is the the value in eV*angstrom units and
D is the Si(111) plane spacing.

=back

=head1 REVISIONS

=over 4

=item 0.3

Yohéi added support for data from SPring8.

=item 0.2

Thanks to 上村洋平 (Yohéi Uemura) from the Photon Factory for helping
me to refine the C<is> method to work with multiple PF XAS beamlines.

=back

=head1 AUTHOR

  Bruce Ravel <bravel@bnl.gov>
  http://xafs.org/BruceRavel

=cut
