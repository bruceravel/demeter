package Demeter::ScatteringPath::Histogram;
use Moose::Role;

use Carp;
use List::Util qw(sum);
use Readonly;
Readonly my $EPSILON  => 0.00001;

sub make_histogram {
  my ($self, $rx, $ry, $common) = @_;
  my @paths = ();

  my $total = sum(@$ry);
  print $total, $/;
  my $rnot = $self->fuzzy;
  foreach my $i (0 .. $#{$rx}) {
    my $deltar = $rx->[$i] - $rnot;
    my $amp = $ry->[$i] / $total;
    my $this = Demeter::Path->new(sp     => $self,
				  delr   => $deltar,
				  n      => $amp,
				  parent => $self->feff,
				  @$common,
				 );
    $this -> make_name;
    $this -> name($this->name . " at " . sprintf("%.3f",$rx->[$i]));
    $this -> update_path(1);
    push @paths, $this;
  };

  return @paths;
};

sub histogram_from_file {
  my ($self, $fname, $xcol, $ycol, $rmin, $rmax) = @_;
  $xcol ||= 1;
  $ycol ||= 2;
  $rmin ||= 0;
  $rmax ||= 100;
  $xcol  -= 1;
  $ycol  -= 1;
  my (@x, @y);
  carp("$fname could not be imported as a histogram file"), return (\@x, \@y) if (not -e $fname);
  open(my $H, $fname);
  foreach my $line (<$H>) {
    chomp $line;
    next if ($line =~ m{\A\s*\z});
    next if ($line =~ m{\A[\#\*\%;]});
    my @list = split(" ", $line);
    next if ($list[$ycol] < $EPSILON);
    next if ($list[$xcol] < $rmin);
    next if ($list[$xcol] > $rmax);
    push @x, $list[$xcol];
    push @y, $list[$ycol];
  };
  close $H;

  return \@x, \@y;
};

sub histogram_from_function {
  my ($self, $string, $rmin, $rmax) = @_;
  my (@x, @y);
  ## use string to generate arrays in Ifeffit
  return \@x, \@y;
};

sub histogram_gamma {
  my ($self, $string, $rmin, $rmax) = @_;
  my (@x, @y);
  ## use string to generate arrays in Ifeffit
  return \@x, \@y;
};


1;
