package Demeter::Plugins::SRS;  # -*- cperl -*-

use Moose;
extends 'Demeter::Plugins::FileType';

has '+is_binary'   => (default => 0);
has '+description' => (default => "XAS beamlines from the old SRS at Daresbury");
has '+version'     => (default => 0.1);
has 'is_med'       => (is => 'rw', isa => 'Int',  default => 0);
has 'nelements'    => (is => 'rw', isa => 'Int',  default => 0);
has 'xaxis'        => (is => 'rw', isa => 'Str',  default => 'encoder');
has 'is_dubble'    => (is => 'rw', isa => 'Bool', default => 0);

use Carp;
use Scalar::Util qw(looks_like_number);

use Demeter::Constants qw($PI $HBARC);
use Const::Fast;
const my $TWOD  => 2*3.13543; # Si(111)?
const my $NLMED => 3; # 9 MED elements, 4 per line, requires three lines

sub is {
  my ($self) = @_;
  open D, $self->file or $self->Croak("could not open " . $self->file . " as data (SRS)\n");
  my $first = <D>;
  my $is_srs = ($first =~ m{\&SRS});
  $self->is_dubble(0);
  while (<D>) {
    $self->is_dubble(1) if ($_ =~ m{dubble});
    last if m{\A\s+\&END};
  };
  close D;
  return $is_srs;
};



sub fix {
  my ($self) = @_;

  my $file = $self->file;
  $self->_parse_med;

  my $new = File::Spec->catfile($self->stash_folder, $self->filename);
  ($new = File::Spec->catfile($self->stash_folder, "toss")) if (length($new) > 127);
  open D, $file or die "could not open $file as data (fix in SRS)\n";
  open N, ">".$new or die "could not write to $new (fix in SRS)\n";

  my $header = 1;
  while (<D>) {
    if ($header) {
      if ($_ =~ m{\A\s+\&END}) {
	$header = 0;
	print N '# ', $_;
	my $labels = '# energy      time         i0        it        if        im';
	if ($self->is_med) {
	  foreach my $i (1 .. $self->nelements) {
	    $labels .= "         g$i";
	  };
	};
	$labels .= $/;
	print N "# -------------------$/";
	print N $labels;
	next;
      };
      print N '# ', $_;
    } else {
      last if ($_ =~ m{\A\s+END|DATA\sABORTED}i);
      next if ($_ =~ m{\AC});
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


sub _parse_med {
  my ($self) = @_;
  my $file = $self->file;
  open D, $file or die "could not open $file as data (_parse_med in SRS)\n";
  my @array = ();
  my @point = ();
  my $count = 0;
  while (<D>) {
    my @line = split(" ", $_);
    next if not looks_like_number($line[0]);
    if ($#line == 5) {
      last if (++$count > 6);
      push @array, [@point];
      @point = ();
    };
    push @point, @line;
  };
  close D;
  shift @array;
  if (($array[0]->[0] > $array[1]->[0]) and
      ($array[1]->[0] > $array[2]->[0]) and
      ($array[2]->[0] > $array[3]->[0]) and
      ($array[3]->[0] > $array[4]->[0])) {
    $self->xaxis('encoder');
  } else {
    $self->xaxis('energy');
  };

  my $nel = $#{$array[0]} - 5;
  if (not $nel) { # this is not MED data!
    $self->nelements(0);
    $self->is_med(0);
    return 0;
  };

  # this is MED data
  $self->nelements($nel);
  my $nlines = ($nel % 4) ? int($nel/4)+1 : $nel/4;
  $self->is_med($nlines);
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
    my $num = '$7+$8+$9';
    $num = '$7+$9+$10+$11+$12+$13+$14+$15+$16+$17+$18+$19+$24+$25+$30+$31+$32+$33' if ($self->nelements == 32);
    $num = '$8+$9+$10+$11+$12+$13+$15' if ($self->is_dubble);
    return (energy      => '$1',
	    numerator   => $num,
	    denominator => '$3',
	    ln          =>  0,);
  };
};


__PACKAGE__->meta->make_immutable;
1;
__END__

=head1 NAME

Demeter::Plugin::SRS - Import data from the XAS beamlines at the old SRS at Daresbury

=head1 VERSION

This documentation refers to Demeter version 0.9.21.

=head1 SYNOPSIS

This plugin converts monochromator angle into from millidegrees to
energy and (as needed) disentangles the confusing layout of data from
a multi-element detector, writing out a file that can easily be
imported by Athena.

=head1 Methods

=over 4

=item C<is>

Recognize the SRS file by the first line, which contains the string
"&SRS".

=item C<fix>

Convert the angle column to energy and disentangle lines from the
multi-element detector for files that contain them.

The file is lexically analyzed to determine whether it contains
scalars from the multi-element detector.  The SRS data aquisition
system writes MED data spread out over several lines of text in the
data file.  (Which is very perverse!)  The MED channels are written 4
to a line, using as many lines as necessary to write all the channels.
A 9 element detector requires 3 additional lines per data point.  A 32
element detector requires 8 additional lines.  Data files not
containing scalars from the MED do not have these additional lines.

=back

=head1 ACKNOWLEDGMENTS

Thanks to Qingping Wu, who providing some sample transmission data
from DUBBLE, and to Eric Breynaert, who provided both some sample
fluorescence data and an example conversion script which included the
value of the monochromator lattice constant used at DUBBLE.

=head1 BUGS AND LIMITATIONS

=over 4

=item *

This plugin assumes the mono lattice constant is 3.13543,
i.e. Si(111).  Should SRS data ever turn up needing another lattice
constant, that will need to become a configurable parameter.

=item *

This has been tested with 9 and 32 element data from SRS and with 9
element data from DUBBLE.

=item *

Does this still work with non-MED DUBBLE data?

=item *

Not tested against non-MED SRS data.

=item *

SRS data with C lines following the header.  I need a real example of
this sort of data -- the one I have does not appear to be XAS data.

=back

=head1 AUTHOR

  Bruce Ravel L<http://bruceravel.github.io/home>
  http://bruceravel.github.com/demeter
  Athena copyright (c) 2001-2014
