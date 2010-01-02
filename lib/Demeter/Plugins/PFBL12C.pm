package Demeter::Plugins::PFBL12C;  # -*- cperl -*-

use Moose;
use MooseX::Aliases;
use MooseX::StrictConstructor;
with 'Demeter::Tools';
with 'Demeter::Project';

use File::Basename;
use File::Copy;

use Readonly;
Readonly my $PI      => 4 * atan2 1, 1;
Readonly my $HBARC   => 1973.27053324;
Readonly my $TWODONE => 6.2712;	# Si(111)
Readonly my $TWODTHR => 3.275;	# Si(311)

has 'is_binary'   => (is => 'ro', isa => 'Bool', default => 0);
has 'description' => (is => 'ro', isa => 'Str',
		      default => "Read files from Photon Factory Beamline 12C.");

has 'parent'      => (is => 'rw', isa => 'Any',);
has 'hash'        => (is => 'rw', isa => 'HashRef', default => sub{{}});
has 'file'        => (is => 'rw', isa => 'Str', default => q{});
has 'fixed'       => (is => 'rw', isa => 'Str', default => q{});


sub is {
  my ($self) = @_;
  open D, $self->file or die "could not open " . $self->file . " as data (PFBL12C)\n";
  my $line = <D>;
  close D;
  return 1 if ($line =~ m{KEK-PF\s+BL12C});
  return 0;
};




sub fix {
  my ($self) = @_;

  my $file = $self->file;
  my ($nme, $pth, $suffix) = fileparse($self->file);
  my $new = File::Spec->catfile($self->stash_folder, $nme);
  ($new = File::Spec->catfile($self->stash_folder, "toss")) if (length($new) > 127);
  open my $D, $file or die "could not open $file as data (fix in PFBL12C)\n";
  open my $N, ">".$new or die "could not write to $new (fix in PFBL12C)\n";

  my ($header, $twod) = (1,$TWODONE);
  my @offsets;
  while (<$D>) {
    last if ($_ =~ m{});
    chomp;
    if ($header and ($_ =~ m{\A\s+offset}i)) {
      my $this = $_;
      @offsets = split(" ", $this);
      print $N '# ', $_, $/;
      print $N '# --------------------------------------------------', $/;
      print $N '# energy_requested   energy_attained  time  i0  i1  ', $/;
      $header = 0;
    } elsif ($header) {
      my $this = $_;
      if ($this =~ m{mono.+\( (\d+) \)}ix) {
	$twod = ($1 == 111) ? $TWODONE : $TWODTHR;
      };
      print $N '# ', $_, $/;
    } else {
      my @list = split(" ", $_);
      $list[0] = (2*$PI*$HBARC) / ($twod * sin($list[0] * $PI / 180));
      $list[1] = (2*$PI*$HBARC) / ($twod * sin($list[1] * $PI / 180));
      my $ndet = $#list-2;
      foreach my $i (1..$ndet) {
	$list[2+$i] = $list[2+$i] - $offsets[2+$i];
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

1;

=head1 NAME

Demeter::Plugin::Lambda - filetype plugin for Photon Factory BL12C

=head1 SYNOPSIS

This plugin converts data recorded as a function of mono angle to data
as a function of energy.


=head1 Methods

=over 4

=item C<is>

A PFBL12C file is identified by the string "KEK-PF BL12C" in the first
line of the file.


=item C<fix>

Convert the wavelength array to energy using the formula

   data.energy = 2 * pi * hbarc / 2D * sin(data.angle)

where C<hbarc=1973.27053324> is the the value in eV*angstrom units and
D is the Si(111) plane spacing.

=head1 AUTHOR

  Bruce Ravel <bravel@anl.gov>
  http://feff.phys.washington.edu/~ravel/software/exafs/
  Athena copyright (c) 2001-2006



1;
__END__

