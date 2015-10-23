package Demeter::Plugins::X23A2MED;

use Moose;
extends 'Demeter::Plugins::FileType';

#use Demeter::IniReader;
#use Config::IniFiles;
use File::Basename;
use File::Copy;
use File::CountLines qw(count_lines);
use Const::Fast;
const my $INIFILE => 'x23a2med.demeter_conf';
use List::MoreUtils qw(any);

has '+is_binary'    => (default => 0);
has '+description'  => (default => "the NSLS X23A2 Vortex");
has '+version'      => (default => 0.2);
has '+metadata_ini' => (default => File::Spec->catfile(File::Basename::dirname($INC{'Demeter.pm'}), 'Demeter', 'share', 'xdi', 'xdac.x23a2.ini'));
has 'nelements'     => (is => 'rw', isa => 'Int', default => 4);
has 'dts'           => (is => 'rw', isa => 'Str', default => q{});
has 'maxints'       => (is => 'rw', isa => 'Str', default => q{});

has '+conffile'     => (default => File::Spec->catfile(dirname($INC{'Demeter.pm'}), 'Demeter', 'Plugins', $INIFILE));

Demeter -> co -> read_config(File::Spec->catfile(dirname($INC{'Demeter.pm'}), 'Demeter', 'Plugins', $INIFILE));

sub is {
  my ($self) = @_;

  ## the header, line of dashes, and column labels constitute 18
  ## lines, multiedge gives 4 more
  return 0 if (count_lines($self->file) < 30);

  open(my $D, $self->file) or $self->Croak("could not open " . $self->file . " as an X23A2MED file\n");
  my $line = <$D>;
  $line = <$D>;
  my $is_x23a2 = ($line =~ m{X-23A2});
  while (<$D>) {
    last if ($_ =~ m{------+});
  };
  $line = <$D> || q{};
  my @headers = split(" ", $line);

  #my $cfg = new Config::IniFiles( -file => $self->inifile );
  my $enr  = Demeter->co->default("x23a2med", "energy");
  my $ch1  = Demeter->co->default("x23a2med", "roi1");
  # my $mere = Demeter->co->default("x23a2med", "multiedge_regex");
  my $sl1  = Demeter->co->default("x23a2med", "slow1");
  my $fa1  = Demeter->co->default("x23a2med", "fast1");
  my $seems_escan = ($line =~ m{$enr\b}i);
  my $seems_med = (($line =~ m{\b$ch1\b}i) or ($line =~ m{\broi\d_\d\b}i)); # hard wired multiedge labels
  my $is_med = (($line =~ m{\b$sl1\b}i) and ($line =~ m{\b$fa1\b}i));
  close $D;
  return ($is_x23a2 and $seems_escan and $seems_med and $is_med);
};

sub fix {
  my ($self) = @_;
  my $file = $self->file;
  my $new = File::Spec->catfile($self->stash_folder, $self->filename);
  ($new = File::Spec->catfile($self->stash_folder, "toss")) if (length($new) > 127);

  ## read the raw data file
  Demeter->dispense('process', 'read_group', {file=>$file, group=>Demeter->mo->throwaway_group, type=>'data'});
  my @labels = split(" ", $self->fetch_string('$column_label'));

  ## is this the four-element or one-element vortex?
  my @represented = ();
  my @edges = ();
  ##my $mere = Demeter->co->default("x23a2med", "multiedge_regex");
  my $multiedge = any { $_ =~ m{roi\d_\d} } @labels; # hard wired column labels
  foreach my $i (1 .. 4) {
    my $is_ok = 1;
    if (not $multiedge) {
      $is_ok &&= any { $_ eq lc(Demeter->co->default("x23a2med", "roi$i") ) } @labels;
    };
    $is_ok &&= any { $_ eq lc(Demeter->co->default("x23a2med", "slow$i")) } @labels;
    $is_ok &&= any { $_ eq lc(Demeter->co->default("x23a2med", "fast$i")) } @labels;
    push @represented, $i if $is_ok;
  };

  return 0 if ($#represented == -1);
  $self->nelements($#represented+1);

  my @options = ();
  foreach my $l (@labels) {
    my $val = Demeter->mo->throwaway_group.".$l";
    push @options, [$l, $val];
  };

  my $elab = Demeter->co->default('x23a2med', 'energy');
  $elab = 'energy' if (($elab eq 'nergy') and Demeter->is_larch); # ifeffit's frickin' nergy problem!
  my @labs    = ($elab, lc(Demeter->co->default('x23a2med', 'i0')));
  my (@edge1, @edge2);
  my $maxints = q{};
  my $dts     = q{};
  my $time    = Demeter->co->default("x23a2med", "time");
  my $inttime = Demeter->co->default("x23a2med", "inttime");
  my @intcol  = $self->fetch_array(Demeter->mo->throwaway_group.'.'.lc(Demeter->co->default("x23a2med", "intcol")));
  my $nosignal = 0;
  foreach my $ch (@represented) {
    my $deadtime = Demeter->co->default("x23a2med", "dt$ch");
    my @slow = $self->fetch_array(Demeter->mo->throwaway_group.'.'.lc(Demeter->co->default("x23a2med", "slow$ch")));
    my @fast = $self->fetch_array(Demeter->mo->throwaway_group.'.'.lc(Demeter->co->default("x23a2med", "fast$ch")));
    if (any {$_ == 0} @slow) {
      ++$nosignal;
      next;
    };

    my ($max, @corr);
    if (not $multiedge) {	# normal MED file
      my @roi  = $self->fetch_array(Demeter->mo->throwaway_group.'.'.lc(Demeter->co->default("x23a2med", "roi$ch" )));
      ($max, @corr) = _correct($inttime, $time, $deadtime, \@intcol, \@roi, \@fast, \@slow);
      $self->place_array(Demeter->mo->throwaway_group.".corr$ch", \@corr);
      push @labs, "corr$ch";
    } else {			# multiedge MED file
      my @roi  = $self->fetch_array(Demeter->mo->throwaway_group.'.roi1_'.$ch);
      ($max, @corr) = _correct($inttime, $time, $deadtime, \@intcol, \@roi, \@fast, \@slow);
      $self->place_array(Demeter->mo->throwaway_group.".c1_$ch", \@corr);
      push @edge1, "c1_$ch";

      @roi  = $self->fetch_array(Demeter->mo->throwaway_group.'.roi2_'.$ch);
      ($max, @corr) = _correct($inttime, $time, $deadtime, \@intcol, \@roi, \@fast, \@slow);
      $self->place_array(Demeter->mo->throwaway_group.".c2_$ch", \@corr);
      push @edge2, "c2_$ch";

    };
    $maxints .= "$max ";

    $dts .= "$deadtime ";
  };
  if ($multiedge) {
    push @labs, @edge1, @edge2;
  };
  return 0 if ($nosignal == $#represented+1);
  $self->nelements($#represented+1-$nosignal);

  push @labs, 'diamond' if any {lc($_) eq 'diamond'}   @labels;
  push @labs, 'it'      if any {lc($_) eq 'it'}        @labels;
  push @labs, 'ir'      if any {lc($_) =~ m{\Air\z}}   @labels;
  push @labs, 'iref'    if any {lc($_) =~ m{\Airef\z}} @labels;

  my $text = ($self->nelements == 1) ? "1 channel" : $self->nelements." channels";
  my $columns = join(", ".Demeter->mo->throwaway_group.".", @labs);

  $dts     =~ s{\s+\z}{};
  $maxints =~ s{\s+\z}{};
  $self->dts($dts);
  $self->maxints($maxints);
  my $command = Demeter->template('plugin', 'x23a2med', {file=>$new, columns=>$columns, text=>$text,
							  dts=>$dts, maxints=>$maxints});

  unlink $new if (-e $new);
  Demeter->dispose($command);

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

after 'add_metadata' => sub {
  my ($self, $data) = @_;
  return if not Demeter->xdi_exists;
  Demeter::Plugins::Beamlines::XDAC->is($data, $self->file);
  $data->xdi->set_item('Detector', 'if',                $self->nelements.' element Vortex silicon drift');
  $data->xdi->set_item('Detector', 'med_nchannels',     $self->nelements);
  $data->xdi->set_item('Detector', 'med_deadtime',      $self->dts);
  $data->xdi->set_item('Detector', 'med_maxiterations', $self->maxints);
};


__PACKAGE__->meta->make_immutable;
1;

=head1 NAME

Demeter::Plugin::X23A2MED - filetype plugin for X23A2 Vortex data

=head1 VERSION

This documentation refers to Demeter version 0.9.24.

=head1 SYNOPSIS

This plugin performs a deadtime correction on data recorded using the
X23A2 Vortex silicon drift detector.  Both the single-element and
four-element detectors are supported.

This plugin requires configuration to provide all the information
needed to correct each channel, including the known deadtime (in
nanoseconds) for each channel and the columns in the file containing
the ROI, fast, and slow channels.

=head1 METHODS

=over 4

=item C<is>

An X23A2 file is recognized by the second comment line identifying the
beamline at which the data were collected.  An MED file is recognized
by having a large (>7) number of columns.  Care is taken to be sure
that the file is an energy scan and has many lines of data.  Care is
not, however, taken to be sure that the I0 column does not have any
zero-valued entries.

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

Demeter ships with a demeter_conf file for configuring this plugin.

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
channel, and y is the measured rate on the fast channel.  The
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

=head1 MULTIEDGE FILES

At X23A2, we have four quad single channel analyzers, one for each
detector element of our four-element Vortex.  Each quad SCA is
modified to have the input channels tied together.  We use the fourth
output channel as the slow channel, or OCR, signal.  This is done by
setting the discriminator window over the entire energy range.  In
principle, we could record three regions of interest for each detector
element.  However, we only have enough scalar input channels to our
crate to record two ROIs, along with the slow and fast (OCR and ICR)
signals.

Recording even two channels is useful for switching between edges as
part of a measurement macro.  To this end, this plugin will recognize
when the system is configured that why by recognizing channel labels
that are different from the configured C<roiN> column labels, as
discussed above and typically C<Ifch1> through C<Ifch4>.  Currently,
this is I<hard-wired> to be

  roi1_1 roi1_2 roi1_3 roi1_4

for the ROI corresponding to one edge, and

  roi2_1 roi2_2 roi2_3 roi2_4

for the ROI corresponding to the second edge.  For example, in PbGeO3,
the C<roi1_N> might be configured to measure the Ge K alpha line while
the C<roi2_N> would then be configured for the Pb L alpha line.

When processed and presented to the user in the column selection
dialog, the corrected columns are then labeled

  c1_1 c1_2 c1_3 c1_4

and

  c2_1 c2_2 c2_3 c2_4

It is then up to the user to select the correct group of four when
importing the data.

=head1 BUGS AND LIMITATIONS

Please report problems to the Ifeffit Mailing List
(L<http://cars9.uchicago.edu/mailman/listinfo/ifeffit/>)

Patches are welcome.

=head1 AUTHORS

  Joe Woicik, NIST (algorithm)
  Bruce Ravel, L<http://bruceravel.github.io/home> (implementation)
  http://bruceravel.github.io/demeter

=cut
