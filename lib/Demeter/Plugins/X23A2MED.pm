package Demeter::Plugins::X23A2MED;

use Moose;
extends 'Demeter::Plugins::FileType';

use Config::IniFiles;
use File::Basename;
use File::Copy;
use Readonly;
Readonly my $INIFILE => 'x23a2vortex.ini';
use List::MoreUtils qw(any);

has '+is_binary'   => (default => 0);
has '+description' => (default => "the NSLS X23A2 Vortex");
has '+version'     => (default => 0.1);
has 'nelements'    => (is => 'rw', isa => 'Int', default => 4);

my $demeter = Demeter->new();
has '+inifile'     => (default => File::Spec->catfile($demeter->dot_folder, $INIFILE));

if (not -e File::Spec->catfile($demeter->dot_folder, $INIFILE)) {
  my $target = File::Spec->catfile($demeter->dot_folder, $INIFILE);
  copy(File::Spec->catfile(dirname($INC{'Demeter.pm'}), 'Demeter', 'share', 'ini', $INIFILE),
       $target);
  chmod(0666, $target) if $demeter->is_windows;
};


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

  my $cfg = new Config::IniFiles( -file => $self->inifile );
  my $ch1 = $cfg->val("med", "roi1");
  my $sl1 = $cfg->val("med", "slow1");
  my $fa1 = $cfg->val("med", "fast1");
  my $seems_med = ($line =~ m{\b$ch1\b}i);
  my $is_med = (($line =~ m{\b$sl1\b}i) and ($line =~ m{\b$fa1\b}i));
  close $D;
  return ($is_x23a2 and $seems_med and $is_med);
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

  ## get the parameters for the deadtime correction from the persistent file
  my $vortexini = $self->inifile;
  confess "X23A2MED inifile $vortexini does not exist", return q{} if (not -e $vortexini);
  confess "could not read X23A2MED inifile $vortexini", return q{} if (not -r $vortexini);
  my $cfg = new Config::IniFiles( -file => $vortexini );
  my $maxel = $cfg->val('elements','n');

  ## is this the four-element or one-element vortex?
  my @represented = ();
  foreach my $i (1 .. 4) {
    push @represented, $i if any {lc($_) eq $cfg->val("med", "roi$i")} @labels;
  };
  $self->nelements($#represented+1);


  my $is_ok = 1;
  foreach my $ch (@represented) {
    $is_ok &&= any { $_ eq lc($cfg->val("med", "roi$ch") ) } @labels;
    $is_ok &&= any { $_ eq lc($cfg->val("med", "slow$ch")) } @labels;
    $is_ok &&= any { $_ eq lc($cfg->val("med", "fast$ch")) } @labels;
  };
  return 0 if not $is_ok;

  my @options = ();
  foreach my $l (@labels) {
    my $val = "v___ortex.$l";
    push @options, [$l, $val];
  };


  my @labs    = ($cfg->val('med', 'energy'), lc($cfg->val('med', 'i0')));
  my $maxints = q{};
  my $dts     = q{};
  my $time    = $cfg->val("med", "time");
  my $inttime = $cfg->val("med", "inttime");
  my @intcol  = Ifeffit::get_array("v___ortex.".lc($cfg->val("med", "intcol")));
  foreach my $ch (@represented) {
    my $deadtime = $cfg->val("med", "dt$ch");
    my @roi  = Ifeffit::get_array("v___ortex.".lc($cfg->val("med", "roi$ch" )));
    my @slow = Ifeffit::get_array("v___ortex.".lc($cfg->val("med", "slow$ch")));
    my @fast = Ifeffit::get_array("v___ortex.".lc($cfg->val("med", "fast$ch")));
    my ($max, @corr) = _correct($inttime, $time, $deadtime, \@intcol, \@roi, \@fast, \@slow);

    Ifeffit::put_array("v___ortex.corr$ch", \@corr);
    push @labs, "corr$ch";
    $maxints .= " $max";
    $dts .= " $deadtime";
  };

  push @labs, 'it'   if any {lc($_) eq 'it'}        @labels;
  push @labs, 'ir'   if any {lc($_) =~ m{\Air\z}}   @labels;
  push @labs, 'iref' if any {lc($_) =~ m{\Airef\z}} @labels;

  my $text = ($self->nelements == 1) ? "1 channel" : $self->nelements." channels";

  $command  = "\$title1 = \"<MED> Deadtime corrected MED data, " . $text . "\"\n";
  $command .= "\$title2 = \"<MED> Deadtimes (nsec):$dts\"\n";
  $command .= "\$title3 = \"<MED> Maximum iterations:$maxints\"\n";
  $command .= "write_data(file=\"$new\", \$title*, \$v___ortex_title_*, v___ortex." . join(", v___ortex.", @labs) . ")\n";
  $command .= "erase \@group v___ortex\n";
  $command .= "erase \$title1 \$v___ortex_title_*\n";
  #print $command;

  unlink $new if (-e $new);
  $demeter->dispose($command);
  undef $cfg;

  $self->fixed($new);
  return $new;
};


sub suggest {
  my ($self, $which) = @_;
  $which ||= 'fluorescence';
  if ($which eq 'transmission') {
    return (energy      => '$1',
	    numerator   => '$2',
	    denominator => ($self->nelements == 1) ? '$4' : '$7',
	    ln          =>  1,);
  } elsif ($self->nelements == 1) {
    return (energy      => '$1',
	    numerator   => '$3',
	    denominator => '$2',
	    ln          =>  0,);
  } elsif ($self->nelements == 2) {
    return (energy      => '$1',
	    numerator   => '$3+$4',
	    denominator => '$2',
	    ln          =>  0,);
  } elsif ($self->nelements == 3) {
    return (energy      => '$1',
	    numerator   => '$3+$4+$5',
	    denominator => '$2',
	    ln          =>  0,);
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
for each element of the detector.  The default deadtime (280
nanoseconds) is very good for channels 1 and 2 and quite close for
channels 3 and 4.

Once all of this information is supplied, the deadtime correction is
done point-by-point for each channel and written out to a temporary
file in the stash directory.  The columns in the stash directory are
energy, I0, the four corrected channels, It, and Ir.  It and Ir are
written out if present in the original file.  Ir can also be called
Iref.

=item C<suggest>

This method returns a list which can be used in a Demeter script
define a Data object which will correctly process the output file as
fluorescence XAS data.

=back

=head1 ADDITIONAL ATTRIBUTE

This plugin also provides the C<inifile> attribute which points at an
ini file containing the various paremeters of the deadtime correction.
This content for the ini file works with the X23A2 Vortex at the time
of this writing.

   [elements]
   n=4

   [med]
   # Channel 1: deadtimes are in nanoseconds
   dt1=280
   roi1=if1
   fast1=ifast1
   slow1=islow1
   #
   # Channel 2: deadtimes are in nanoseconds
   dt2=280
   roi2=if2
   fast2=ifast2
   slow2=islow2
   #
   # Channel 3: deadtimes are in nanoseconds
   dt3=280
   roi3=if3
   fast3=ifast3
   slow3=islow3
   #
   # Channel 4: deadtimes are in nanoseconds
   dt4=280
   roi4=if4
   fast4=ifast4
   slow4=islow4
   #
   # other columns
   i0=i0
   energy=nergy
   #
   # times
   inttime=1
   time=constant
   intcol=inttime

By deafult, the file called F<x23a2vortex.ini> in the dot folder
(F<$HOME/.horae> on unix, F<%APPDATA%\horae> on Windows).  To supply
new parameters, either overwrite that file or specify a different file
as the value of this attribute.

=head2 Deadtime correction parameters

To apply the correction algorithm, this plugin needs to know which
columns contain which data channels.  For each channel N, we need:

=over 4

=item C<dtN>

The fast channel deadtime (which Joe measured to be approximately 280
nsec for each channel) for detector N.

=item C<roiN>

The column label for the region of interest (i.e. the discriminator
window channel) for detector N.

=item C<fastN>

The column label for the fast channel (i.e. the input count
rate) for detector N.

=item C<fastN>

The column label for the slow channel (i.e. the output count
rate) for detector N.

=back

=head2 Other column labels

Additionally, the implementation of the algorithm needs to know the
column labels for:

=over

=item *

The energy column.  Oddly, Ifeffit removes the leading character from
the line in the data file containing the column labels.  So "energy"
becomes "nergy".  Go figure.

=item *

The I0 column label

=back

=head2 Integration time

The implementation of the algorithm also needs to know how integration
times were done in the measurement.

I strongly recommend that the integration time be recorded in the
file.  (that can be set in XDAC).  in that case, you set the C<intcol>
parameter to the name of the column label containing the per-point
integration time (which is called inttime) in XDAC.  If that column is
missing, then the integration time must be specified by the C<inttime>
parameters.

The C<time> parameter is set to either C<column> or C<constant> to
choose between the C<intcol> and C<inttime> options.

=head1 THE CORRECTION ALGORITHM

If the deadtime is known for a channel, that will be used to correct
the fast channel (aka input count rate, or ICR) by iteratively solving
the transcendental equation which describes the attenuation of the
fast channel due to deadtime:

   y = x*exp(-x*tau)

where tau is the deadtime, x is the actual input rate on the fast
channel, and y is the measured rate on the dast channel.  The
iterative solution encoded in the C<_correct> subroutine thus solves
point-by-point for x using a value for tau and the column containing
y.

If the deadtime is set to 0 (or negative) for a channel, then the
standard correction of the ratio of the fast and slow channels (or
ICR/OCR) will be applied to that channel.

For high count rates, the proper deadtime correction is considerably
more accurate than the standard correction.  For details see Woicik,
Ravel, Fischer, and Newburgh, J. Synchrotron Rad. (2010). 17, 409-413
http://dx.doi:org/10.1107/S0909049510009064

=head1 BUGS AND LIMITATIONS

Please report problems to Bruce Ravel (bravel AT bnl DOT gov)

Patches are welcome.

=back

=head1 AUTHORS

  Joe Woicik <woicik AT bnl DOT gov> (algorithm)
  Bruce Ravel <bravel AT bnl DOT gov> (implementation)
  http://xafs.org/BruceRavel

