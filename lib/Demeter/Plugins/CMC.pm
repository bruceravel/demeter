package Demeter::Plugins::CMC;  # -*- cperl -*-


use Moose;
use MooseX::Aliases;
use MooseX::StrictConstructor;
with 'Demeter::Tools';
with 'Demeter::Project';

use File::Basename;
use File::Copy;

has 'is_binary'   => (is => 'ro', isa => 'Bool', default => 0);
has 'description' => (is => 'ro', isa => 'Str',
		      default => "Import data from APS 9BM (CMC-XOR).");

has 'parent'      => (is => 'rw', isa => 'Any',);
has 'hash'        => (is => 'rw', isa => 'HashRef', default => sub{{}});
has 'file'        => (is => 'rw', isa => 'Str', default => q{});
has 'fixed'       => (is => 'rw', isa => 'Str', default => q{});



sub is {
  my ($self) = @_;
  my $is_cmc = 0;
  open D, $self->file or die "could not open " . $self->file . " in CMC\n";
  my $line;
  foreach (1 .. 4) { $line = <D> };
  $is_cmc = ($line =~ /^\#C.+(?:bmexafs|9bmuser)/);
  close D;
  return $is_cmc;
};


sub fix {
  my ($self) = @_;
  my ($nme, $pth, $suffix) = fileparse($self->file);
  my $new = File::Spec->catfile($self->stash_folder, $nme);
  ($new = File::Spec->catfile($self->stash_folder, "toss")) if (length($new) > 127);
  open D, $self->file or die "could not open " . $self->file . " as data (fix in MRMED)\n";
  open N, ">".$new  or die "could not open $new in MRMED\n";

  my %keep = ();
  my %dark = ();
  my $col = 0;
  my $header = 1;
  my $column_labels = "";
  while (<D>) {
    next if /^\s*$/;		# skip blank lines
    if ($_ =~ /^#L/) {		# parse column lables line
      chomp;
      my @labels = split(" ", $_);
      shift @labels;
      foreach my $l (@labels) {
	if ($l =~ /^(energy|i[0-2]|iref|lytle|mca\d+)$/i) {
	  $keep{$col} = $l;
	  $column_labels .= " $l";
	} elsif ($l =~ /^(i[0-2]off)$/i) { # columns with offset PVs
	  $dark{$col} = $l;
	};
	++$col;
      };
      print N $_,$/;
    } elsif ($_ =~ /^#/) {	# stream other header lines
      print N $_;
    } else {			# data begins ...
      chomp;
      my @data = split(" ", $_);
      if ($header) {		# dig through the columns to match
	                        # the offset-subtracted columns with
	                        # raw signal columns
	foreach my $k (sort {$a <=> $b} keys %keep) {
	  if ($keep{$k} =~ /i\d/i) {
	    foreach my $d (keys %dark) {
	      if ($dark{$d} =~ /$keep{$k}/) {
		$dark{$keep{$k}} = ($data[$k] - $data[$d]*$data[-1]);
		$dark{$keep{$k}} /= $data[-1];
	      };
	    };
	  };
	};
	print N "#C   dark current: "; # make a header line with dark currents
	foreach my $l (sort {$a <=> $b} keys %keep) {
	  if ($keep{$l} =~ /^(i[0-2])$/i) {
	    print N ucfirst($keep{$l}), "=", $dark{$keep{$l}}, " c/s   ";
	  };
	};
	print N "$/# ---------------------------------------------$/#$column_labels$/";
	$header = 0;
      };
      foreach my $k (sort {$a <=> $b} keys %keep) {
	my $point = $data[$k];
	if ($keep{$k} =~ /^i\d$/) {
	  $point -= $dark{$keep{$k}}*$data[-1];	# subtract dark current * integration time
	};
	($point = 0) if (lc($point) eq 'nan');
	print N " ", $point;
      };
      print N $/;
    };
  };
  close D;
  close N;
  $self->fixed($new);
  return $new;
}

sub suggest {
  my ($self, $which) = @_;
  $which ||= 'transmission';
  if ($which eq 'transmission') {
    return (energy      => '$1',
	    numerator   => '$2',
	    denominator => '$3',
	    ln          =>  1,);
  } else {
    return (energy      => '$1',
	    numerator   => '$7+$8+$9+$10+$11+$13',
	    denominator => '$2',
	    ln          =>  0,);
  };
};

1;
__END__

=head1 NAME

Demeter::Plugin::CMC - filetype plugin for files from APS Sector 9

=head1 SYNOPSIS

This plugin strips the many columns not normally needed from a file
from CMC APS Sector 9 in an effort to interact with Ifeffit more
efficiently and avoid some of the pitfalls of the CMC file format.

==head1 Methods

=over 4

=item C<is>

Recognize the Sector 9 BM file by the fourth line, which starts with
the Spec #C token and identifies the user as "bmexafs".

=item C<fix>

Strip out all columns except for energy, I0, I1, I2, Lytle, and mca* and write
them to a file in the stash directory.  Remove dark current from the i*
channels.  Also fix any instances of NaN among the data (probably only in the
ill-conceived logi0i1 column, but...) and strip out any blank lines.

=back

=head1 AUTHOR

  Bruce Ravel <bravel@bnl.gov>
  http://xafs.org/BruceRavel/



