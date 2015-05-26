package Demeter::Plugins::DUBBLE;  # -*- cperl -*-

use Moose;
extends 'Demeter::Plugins::FileType';

has '+is_binary'   => (default => 0);
has '+description' => (default => "the DUBBLE beamline at the ESRF");
has '+version'     => (default => 0.1);
has 'is_med'       => (is => 'rw', isa => 'Int', default => 0);
has '+metadata_ini' => (default => File::Spec->catfile(File::Basename::dirname($INC{'Demeter.pm'}), 'Demeter', 'share', 'xdi', 'dubble.ini'));

use Carp;
use Scalar::Util qw(looks_like_number);

use Demeter::Constants qw($PI $HBARC);
use Const::Fast;
const my $TWOD  => 2*3.13543; # Si(111) at DUBBLE
const my $NLMED => 3; # 9 MED elements, 4 per line, requires three lines

sub is {
  my ($self) = @_;
  open my $D, '<', $self->file or $self->Croak("could not open " . $self->file . " as data (DUBBLE)\n");
  my $first = <$D>;
  my $is_srs = ($first =~ m{\&SRS});
  my $is_dubble = 0;
  while (<$D>) {
    $is_dubble = ($_ =~ m{dubble});
    last if ($is_dubble or m{\A\s+\&END});
  };
  close $D;
  return ($is_srs and $is_dubble);
};



sub fix {
  my ($self) = @_;

  my $file = $self->file;
  $self->is_med($self->_is_med);

  my $new = File::Spec->catfile($self->stash_folder, $self->filename);
  ($new = File::Spec->catfile($self->stash_folder, "toss")) if (length($new) > 127);
  open D, $file or die "could not open $file as data (fix in DUBBLE)\n";
  open N, ">".$new or die "could not write to $new (fix in DUBBLE)\n";

  my $header = 1;
  while (<D>) {
    if ($header) {
      if ($_ =~ m{\A\s+\&END}) {
	$header = 0;
	print N '# ', $_;
	my $labels = '# energy      time         i0        it        if        im';
	$labels .= '             med1          med2         med3         med4         med5         med6         med7         med8         med9' if $self->is_med;
	$labels .= $/;
	print N "# -------------------$/";
	print N $labels;
	next;
      };
      print N '# ', $_;
    } else {
      last if ($_ =~ m{\A\s+END|DATA\sABORTED}i);
      chomp;
      my @line = split(" ", $_);
      my $angle = shift(@line)/1000; # millidegrees, apparently
      $angle = sprintf("%.4f", (2*$PI*$HBARC) / ($TWOD * sin($angle * $PI / 180)));
      print N join("   ", $angle, @line);
      if ($self->is_med) {
	foreach (0 .. $self->is_med-1) {
	  my $extra = <D>;
	  if (defined($extra) and ($extra !~ m{\A\s*\z})) {
	    chomp $extra;
	    print N $extra;
	  };
	};
      };
      print N $/;
    };
  };

  close N;
  close D;
  $self->fixed($new);
  return $new;
}


sub _is_med {
  my ($self) = @_;
  my $file = $self->file;
  open D, $file or die "could not open $file as data (_is_med in DUBBLE)\n";
  my @array = ();
  my $count = 0;
  while (<D>) {
    my @line = split(" ", $_);
    next if not looks_like_number($line[0]);
    next if (++$count > 41);
    push @array, $line[0];
  };
  my $first = shift @array;
  my $prev  = shift @array;
  my $updown = ($prev > $first) ? q{up} : q{down};
  foreach my $this (@array) {
    my $ud = ($this > $prev) ? q{up} : q{down};
    close D, return $NLMED if ($ud ne $updown);
  };
  close D;
  return 0;
};

sub suggest {
  my ($self, $which) = @_;
  $which ||= 'transmission';
  $which = 'fluorescence' if $self->is_med;
  if ($which eq 'transmission') {
    return (energy      => '$1',
	    numerator   => '$3',
	    denominator => '$4',
	    ln          =>  1,);
  } else {
    return (energy      => '$1',
	    numerator   => '$8+$9+$10+$11+$12+$13+$14+$15',
	    denominator => '$3',
	    ln          =>  0,);
  };
};

after 'add_metadata' => sub {
  my ($self, $data) = @_;
  return if not Demeter->xdi_exists;
  $data->xdi->set_item('Mono', 'd_spacing', $TWOD/2);
  $data->xdi->set_item('Mono', 'name',      'Si(111)');
};


__PACKAGE__->meta->make_immutable;
1;
__END__

=head1 NAME

Demeter::Plugin::DUBBLE - Import data from the DUBBLE beamline at ESRF

=head1 VERSION

This documentation refers to Demeter version 0.9.21.

=head1 SYNOPSIS

This plugin converts monochromator angle into from millidegrees to
energy and (as needed) disentanlges the confusing layout of data from
the multi-element detector, writing out a file that can easily be
imported by Athena.


=head1 Methods

=over 4

=item C<is>

Recognize the DUBBLE file by the first line, which contains the string
"&SRS", and a subsequent header line, which contains the string
"dubble".

=item C<fix>

Convert the angle column to energy and disentangle lines from the
multi-element detector for files that contain them.

The file is lexically analyzed to determine whether it contains
scalars from the multi-element detector.  DUBBLE writes MED data
spread out over four lines of text in the data file.  (Which is very
perverse!)  Data files not containing scalars from the MED do not have
these additional lines.  So a file containing MED data is recognized
by the fact that the first number on each line is not monotonically
decreasing.  This filter examines the first forty lines of data.  When
it finds the situation of the first number not being monotonically
decreasing (which it should be as data are stored as a function of
mono angle in millidegrees), the file is assumed to contain MED data
and is processed accordingly.

Note that this filter assumes that the MED data is spread out over
three additional lines.  Apparently DUBBLE uses a 9-element detector.
At most, four MED scalars are written per line, thus it takes three
additional lines to record the MED data.  Should DUBBLE ever use a
different detector, a more clever lexical analysis will be required to
determine the number of MED channels.

=back

=head1 ACKNOWLEDGMENTS

Thanks to Qingping Wu, who providing some sample transmission data
from DUBBLE, and to Eric Breynaert, who provided both some sample
fluorescence data and an example conversion script which included the
value of the monochromator lattice constant used at DUBBLE.

=head1 BUGS AND LIMITATIONS

=over 4

=item *

This plugin is fragile.  Should the mono lattice parameter or number
of MED channels change, this B<will> break.  One solution would be to
use an ini file to pass this information into the plugin, using
3.13543 and 9 MED channels as defaults.  Another option would be to do
a more sophisticated analysis in the C<_is_med> method and have the
true value be the number of subsequent lines which contain MED data.

=back

=head1 AUTHOR

  Bruce Ravel <L<http://bruceravel.github.io/home>>
  http://bruceravel.github.io/demeter
  Athena copyright (c) 2001-2015
