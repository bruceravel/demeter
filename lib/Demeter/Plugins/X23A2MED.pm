package Demeter::Plugins::X23A2MED;

use Moose;
extends 'Demeter::Plugins::FileType';

has '+is_binary'   => (default => 0);
has '+description' => (default => "the NSLS X23A2 Vortex");
has '+version'     => (default => 0.1);

#use Demeter;
my $demeter = Demeter->new();
has 'inifile' => (is => 'rw', isa => 'Str', default => File::Spec->catfile($demeter->dot_folder, 'x23a2vortex.ini'));

use Config::IniFiles;

sub is {
  my ($self) = @_;
  open(my $D, $self->file) or die "could not open " . $self->file . " as an X23A2MED file\n";
  my $line = <$D>;
  $line = <$D>;
  my $is_x23a2 = ($line =~ m{X-23A2});
  while (<$D>) {
    last if ($_ =~ m{------+});
  };
  $line = <$D> || q{};
  my @headers = split(" ", $line);
  my $is_med = ($#headers > 6);
  close $D;
  return ($is_x23a2 and $is_med);
};

sub fix {
  my ($self) = @_;
  my $file = $self->file;
  my $new = File::Spec->catfile($self->stash_folder, $self->filename);
  ($new = File::Spec->catfile($self->stash_folder, "toss")) if (length($new) > 127);

  ## read the raw data file into Ifeffit
  my $command = "read_data(file=\"$file\", group=v___ortex)\n";
  $demeter->dispose($command);

  my @labels = split(" ", Ifeffit::get_string('$column_label'));
  my @options = ();
  foreach my $l (@labels) {
    my $val = "v___ortex.$l";
    push @options, [$l, $val];
  };

  ## get the parameters for the deadtime correction from the persistent file
  my $vortexini = $self->inifile;
  confess "X23A2MED inifile $vortexini does not exist", return q{} if (not -e $vortexini);
  confess "could not read X23A2MED inifile $vortexini", return q{} if (not -r $vortexini);
  #  open V, '>', $vortexini;
  #  print V "[elements]\nn=4\n";
  #  close V;
  #};
  my $cfg = new Config::IniFiles( -file => $vortexini );
  my $maxel = $cfg->val('elements','n');

  my @labs    = ($cfg->val('med', 'energy'), $cfg->val('med', 'i0'));
  my $maxints = q{};
  my $dts     = q{};
  my $time    = $cfg->val("med", "time");
  my $inttime = $cfg->val("med", "inttime");
  my @intcol  = Ifeffit::get_array("v___ortex.".$cfg->val("med", "intcol"));
  foreach my $ch (1 .. $maxel) {
    my $deadtime = $cfg->val("med", "dt$ch");
    my @roi  = Ifeffit::get_array("v___ortex.".$cfg->val("med", "roi$ch"));
    my @slow = Ifeffit::get_array("v___ortex.".$cfg->val("med", "slow$ch"));
    my @fast = Ifeffit::get_array("v___ortex.".$cfg->val("med", "fast$ch"));
    my ($max, @corr) = _correct($inttime, $time, $deadtime, \@intcol, \@roi, \@fast, \@slow);

    Ifeffit::put_array("v___ortex.corr$ch", \@corr);
    push @labs, "corr$ch";
    $maxints .= " $max";
    $dts .= " $deadtime";
  };

  push @labs, 'it' if grep {lc($_) eq 'it'} @labels;
  push @labs, 'ir' if grep {lc($_) eq 'ir'} @labels;

  $command  = "\$title1 = \"<MED> Deadtime corrected MED data, $maxel channels\"\n";
  $command .= "\$title2 = \"<MED> Deadtimes (nsec):$dts\"\n";
  $command .= "\$title3 = \"<MED> Maximum iterations:$maxints\"\n";
  $command .= "write_data(file=\"$new\", \$title*, \$v___ortex_title_*, v___ortex." . join(", v___ortex.", @labs) . ")\n";
  $command .= "erase \@group v___ortex\n";
  $command .= "erase \$title1 \$v___ortex_title_*\n";
  #print $command;

  unlink $new if (-e $new);
  $demeter->dispose($command);

  $self->fixed($new);
  return $new;
};


sub suggest {
  my ($self, $which) = @_;
  $which ||= 'transmission';
  if ($which eq 'fluorescence') {
    return (energy      => '$1',
	    numerator   => '$2',
	    denominator => '$7',
	    ln          =>  1,);
  } else {
    return (energy      => '$1',
	    numerator   => '$3+$4+$5+$6',
	    denominator => '$2',
	    ln          =>  0,);
  };
};

sub _correct {
  my ($int, $time, $deadtime, $rintcol, $rroi, $rfast, $rslow) = @_;
  $deadtime *= 1e-9;		# nanoseconds!
  my @corrected = ();
  my ($toto, $totn)=(0,0);
  my ($maxcount, $maxiter) = (20,0);
 LOOP: foreach my $i (0 .. $#{$rroi}) {
    if ($deadtime <= 1e-9) {	# 1 nanosecond is an unreasonable
                                # deadtime, so this accounts for
                                # numerical issues in recognizing 0
      push @corrected, $rroi->[$i] * $rfast->[$i] / $rslow->[$i];
      next LOOP;
    };
    my $test = 1;
    my $count = 0;
    ($int = $rintcol->[$i]) if ($time eq 'column');
    $toto = $rfast->[$i]/$int;
    (($totn, $test) = ($rslow->[$i],0)) if ($rfast->[$i] <= 1);
    while ($test > $deadtime) {
      $totn = ($rfast->[$i]/$int) * exp($toto*$deadtime);
      $test = ($totn-$toto) / $toto;
      $toto = $totn;
      ++$count;
      $test = 0 if ($count >= $maxcount);
      $maxiter = $count if ($count > $maxiter);
    };
    push @corrected, $rroi->[$i] * ($totn*$int/$rslow->[$i]);
  };
  #print "Maximum number of iterations: $maxiter\n";
  return ($maxiter, @corrected);
};

__PACKAGE__->meta->make_immutable;
1;

=head1 NAME

Demeter::Plugin::X23A2MED - filetype plugin for X23A2 Vortex data

=head1 SYNOPSIS

This plugin performs a deadtime correction on data recorded using the
X23A2 Vortex silicon drift detector.  It requires an ini file to
provide all the information needed to correct each channel, including
the known deadtime (in nanoseconds) for each channel and the columns
in the file containing the ROI, fast, and slow channels.

=head1 METHODS

=over 4

=item C<is>

An X23A2 file is recognized by the second comment line identifying the
beamline at which the data were collected.  An MED file is recognized
by having a large (>7) number of columns.

=item C<fix>

An ini file is used to specify the deadtime for each channel and is
prompted for the column labels for the ROI, fast, and slow channels
for each element of the detector.  The default deadtime (2.80
nanoseconds) is very good for channels 1 and 2 and quite close for
channels 3 and 4.

Once all of this information is supplied, the deadtime correction is
done point-by-point for each channel and written out to a temporary
file in the stash directory.  The columns in the stash directory are
energy, i0, the four corrected channels, It, and Ir.  It and Ir are
written out if present in the original file.

=back

=head1 ADDITIONAL ATTRIBUTE

This plugin also provides the C<inifile> attribute which points at an
ini file containing the various paremeters of the deadtime correction.
This content for the ini file works with the X23A2 Vortex at the time
of this writing.

   [elements]
   n=4

   [med]
   # deadtimes are in nanoseconds
   dt1=280
   roi1=if1
   fast1=ifast1
   slow1=islow1
   # deadtimes are in nanoseconds
   dt2=280
   roi2=if2
   fast2=ifast2
   slow2=islow2
   # deadtimes are in nanoseconds
   dt3=280
   roi3=if3
   fast3=ifast3
   slow3=islow3
   # deadtimes are in nanoseconds
   dt4=280
   roi4=if4
   fast4=ifast4
   slow4=islow4
   energy=nergy
   i0=i0
   inttime=1
   time=constant
   intcol=inttime

By deafult, the file called F<x23a2vortex.ini> in the dot folder
(F<$HOME/.horae> on unix, F<%APPDATA%\horae> on Windows).  To supply
new parameters, either overwrite that file or specify a different file
as the value of this attribute.

=head1 THE CORRECTION ALGORITHM

If the deadtime is known for a channel, that will be used to correct
the fast channel (aka input count rate, or ICR) by iteratively solving
the transcendental equation which describes the attenuation of the
fast channel due to deadtime:

   y = x*exp(-x*tau)

where tau is the deadtime, x is the actual input rate on the fast
channel, and y is the measured rate on the dast channel.  The
iterative solution encoded in the C<correct> subroutine thus solves
point-by-point for x using a value for tau and the column containing
y.

If the deadtime is set to 0 (or negative) for a channel, then the
standard correction of the ratio of the fast and slow channels (or
ICR/OCR) will be applied to that channel.

For high count rates, the proper deadtime correction is considerably
more accurate than the standard correction.  For details see the
upcoming paper by Woicik, Ravel, Fischer, Newburgh in the Journal of
Synchrotron Radiation.

=head1 BUGS AND LIMITATIONS

=over 4

=item *

Need to do error checking on ini file values.

=back

=head1 AUTHORS

  Joe Woicik <woicik@bnl.gov> (algorithm)
  Bruce Ravel <bravel@bnl.gov> (implementation)
  http://xafs.org/BruceRavel

