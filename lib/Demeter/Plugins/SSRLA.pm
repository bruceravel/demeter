package Demeter::Plugins::SSRLA;  # -*- cperl -*-

use Moose;
extends 'Demeter::Plugins::FileType';

has '+is_binary' => (default => 0);
has '+description' => (default => "Read ASCII files from the SSRL XAFS Data Collector");

sub is {
  my ($self) = @_;
  my $null = chr(0);
  open D, $self->file or die "could not open " . $self->file . " as data (SSRL ASCII)\n";
  my $line = <D>;
  my $is_ssrl  = ($line =~ m{^\s*SSRL\s+EXAFS Data Collector});
  $line = <D>;
  my $is_ascii = ($line !~ m{$null});
  close D;
  return 1 if ($is_ssrl and $is_ascii);
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
  my ($header, $labels) = (1, 0);
  while (<D>) {
    chomp;
    if ($_ =~ /^\s*Data:/) {
      (($header, $labels) = (0,1));
      next;
    };
    if (($_ =~ /^\s*$/) and $labels) {
      (($header, $labels) = (0,0));
      @labels = ($labels[2], $labels[1], $labels[0], @labels[3..$#labels]);
      print N "# ", "-"x30, $/;
      print N "# ", join(" ", @labels), $/;
      next;
    };
    if ($labels) {
      my $this = $_;
      $this =~ s/\s+$//;
      $this =~ s/\s+/_/g;
      push @labels, $this;
    } elsif ($header) {		# comment header
      if ($_ =~ /^\s*Offsets/) {
	print N "# ", $_, $/;
	my $line = <D>;
	@offsets = split(" ", $line);
	@offsets = ($offsets[2], $offsets[1], $offsets[0], @offsets[3..$#offsets]);
	print N "# ", join(" ", @offsets), $/;
      } else {
	print N "# ", $_, $/;
      };
    } else {			# data columns
      my @line = split(" ", $_);
      @line = ($line[2], $line[1], $line[0], @line[3..$#line]);
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
	    numerator   => '$4',
	    denominator => '$5',
	    ln          =>  1,);
  } else {
    return (energy      => '$1',
	    numerator   => '$6',
	    denominator => '$4',
	    ln          =>  0,);
  };
};

__PACKAGE__->meta->make_immutable;
1;


=head1 NAME

Demeter::Plugin::SSRLA - SSRL XAFS Data Collector 1.3 ASCII filetype plugin

=head1 SYNOPSIS

This plugin directly reads the files written by the SSRL XAFS Data Collector.

=head1 SSRL files

This plugin comments out the header lines, constructs a column label
line out of the Data: section, moves the first column (real time
clock) to the third column, and swaps the requested and acheived
energy columns.

=head1 AUTHOR

  Bruce Ravel <bravel@bnl.gov>
  http://xafs.org/BruceRavel
