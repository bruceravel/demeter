package Demeter::Plugins::SSRLmicro;  # -*- cperl -*-

use Moose;
extends 'Demeter::Plugins::FileType';

has '+is_binary'   => (default => 0);
has '+description' => (default => "the SSRL microXAFS Data Collector 1.0");
has '+version'     => (default => 0.1);

sub is {
  my ($self) = @_;
  open D, $self->file or $self->Croak("could not open " . $self->file . " as data (SSRLmicro)\n");
  my $line = <D>;
  close D;
  my $is_ssrl  = ($line =~ m{^\s*SSRL\s+MicroEXAFS Data Collector});
  close D;
  return 1 if $is_ssrl;
  return 0;
};

sub fix {
  my ($self) = @_;
  my $new = File::Spec->catfile($self->stash_folder, $self->filename);
  ($new = File::Spec->catfile($self->stash_folder, "toss")) if (length($new) > 127);
  open D, $self->file or die "could not open " . $self->file . " as data (fix in SSRLA)\n";
  open N, ">".$new or die "could not write to $new (fix in SSRLA)\n";
  my @labels;
  my @offsets;
  my @detectors;
  my @scalars;
  my @icr;
  my ($header, $labels) = (1, 0);
  while (<D>) {
    chomp;
    if ($_ =~ /^\s*Data:/) {
      $header = 0;
      $labels++;
      next;
    };
    if (($_ =~ /^\s*$/) and $labels) { # labels end with a blank line, data follows
      (($header, $labels) = (0,0));
      ##         energy       RTC         I0
      @labels = ($labels[1], $labels[0], @labels[@detectors], @labels[@scalars]);
      print N "# ", "-"x30, $/;
      my $label_line = "# " . join(" ", @labels);
      $label_line =~ s{SCA}{S}g;
      print N $label_line, $/;
      next;
    };
    if ($labels) {
      $labels++;
      my $this = $_;
      $this =~ s/\s+$//;
      $this =~ s/\s+/_/g;
      $this =~ s/\./_/g;
      push @labels, $this;
      next if (($this =~ m{time}i) or ($this =~ m{energy}i));
      push @scalars,   $labels-2 if ($this =~ m{SCA});
      push @icr,       $labels-2 if ($this =~ m{ICR});
      push @detectors, $labels-2 if ($this !~ m{(?:ICR|SCA)});;
    } elsif ($header) {		# comment header
      if ($_ =~ /^\s*Offsets/) {
	print N "# ", $_, $/;
	my $line = <D>;
	@offsets = split(" ", $line);
	@offsets = ($offsets[1], $offsets[0], @offsets[@detectors], @offsets[@scalars]);
	print N "# ", join(" ", @offsets), $/;
      } else {
	print N "# ", $_, $/;
      };
    } else {			# data columns
      my @line = split(" ", $_);
      @line = ($line[1], $line[0], @line[@detectors], @line[@scalars]);
      my $nn = $#line+1;
      my $pattern = "%.4f  " x $nn . $/;
      #@line = map{ $line[$_] - $offsets[$_] } (0 .. $#line);
      printf N $pattern, @line;
    };
  };
  close N;
  close D;
  $self->fixed($new);
  return $new;
}

sub suggest {
  my ($self, $which) = @_;
  $which ||= 'transmission';
  if ($which eq 'transmission') {
    return (energy      => '$1',
	    numerator   => '$3',
	    denominator => '$4',
	    ln          =>  1,);
  } else {
    return (energy      => '$1',
	    numerator   => '$6',
	    denominator => '$3',
	    ln          =>  0,);
  };
};

__PACKAGE__->meta->make_immutable;
1;
__END__



=head1 NAME

Demeter::Plugin::SSRLmicro - SSRL XAFS microXAFS Data Collector filetype plugin

=head1 SYNOPSIS

This plugin directly reads the files written by Sam Webb's SSRL
MicroXAFS Data Collector 1.0.

=head1 SSRL files

This plugin comments out the header lines, constructs a column label
line out of the Data: section, moves the first column (real time
clock) to the second column, and strips out the ICR channels.

This was developed using a single example data file from the CLS HXMA
beamline.  Are other scalar channels ever saved to these files?  I do
not know.  If so, strange behavior might ensue.

=head1 AUTHOR

  Bruce Ravel <bravel@bnl.gov>
  http://xafs.org/BruceRavel

