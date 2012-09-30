package Demeter::Plugins::X15B;  # -*- cperl -*-

use Moose;
extends 'Demeter::Plugins::FileType';

has '+is_binary'    => (default => 1);
has '+description'  => (default => "NSLS beamline X15B");
has '+version'      => (default => 0.1);
has '+metadata_ini' => (default => File::Spec->catfile(File::Basename::dirname($INC{'Demeter.pm'}), 'Demeter', 'share', 'xdi', 'x15b.ini'));

use Const::Fast;
const my $ENERGY => 0;	# columns containing the
const my $I0     => 4;	# relevant scalars
const my $NARROW => 8;
const my $WIDE   => 9;
const my $TRANS  => 10;

sub is {
  my ($self) = @_;
  my $Ocircumflex = chr(212);
  my $nulls = chr(0).chr(0).chr(0);
  open D, $self->file or $self->Croak("could not open " . $self->file . " as data (X15B)\n");
  binmode D;
  my $first = <D>;
  close D;
  return 1 if ($first =~ /^$Ocircumflex$nulls/);
  return 0;
};

sub fix {
  my ($self) = @_;

  my $new = File::Spec->catfile($self->stash_folder, $self->filename);
  ($new = File::Spec->catfile($self->stash_folder, "toss")) if (length($new) > 127);

  my @blob = ();
  my $file = $self->file;
  ## slurp the entire binary file into an array of 4-byte floats
  do {
    local $/ = undef;
    open D, $file or die "could not read $file as data (fix in X15B)\n";
    @blob = unpack("f*", <D>);
    close D
  };
  open N, ">".$new or die "could not write to $new (fix in X15B)\n";

  ## the header is mysterious, but the project name from scanedit is
  ## in there, so pull that out as text (pack and unpack process this
  ## mysterious header as text)
  my @header = ();
  foreach (1..53) {
    push @header, shift @blob;
  };
  my $string = pack("f*", @header);
  my $project = "??";
  foreach (unpack("A*", $string)) {
    $project = "$1 $2" if (/(\w+)\s+(\d+\/\d+\/\d+)/);
  };

  print N <<EOH
# X15B  project: $project
# original file: $file
# unpacked from original data as a sequence of 4-byte floats
# --------------------------------------------------------------------
#   energy           I0          narrow        wide           trans
EOH
  ;

  ## just pull out the relevant columns.  we are only reading the
  ## energy, i0, the narrow and wide windows from the Ge detector, and
  ## the transmission ion chmaber.  All other scalars are presumed
  ## uninteresting.  The indeces of these scalars in the line are
  ## defined as constants (see above).
  while (@blob) {
    shift @blob;
    my @line = ();
    foreach (1..15) {
      push @line, shift(@blob);
    };
    ## just write out the relevant lines
    printf N " %12.4f  %12.4f  %12.4f  %12.4f  %12.4f\n",
      @line[$ENERGY, $I0, $NARROW, $WIDE, $TRANS];
  }; # loop over rows of data

  close N;
  $self->fixed($new);
  return $new;
}

sub suggest {
  my ($self, $which) = @_;
  $which ||= 'fluorescence';
  if ($which eq 'transmission') {
    return (energy      => '$1',
	    numerator   => '$2',
	    denominator => '$5',
	    ln          =>  1,);
  } else {
    return (energy      => '$1',
	    numerator   => '$3',
	    denominator => '$2',
	    ln          =>  0,);
  };
};


__PACKAGE__->meta->make_immutable;
1;
__END__


=head1 NAME

Demeter::Plugin::X15B - NSLS X15B filetype plugin

=head1 VERSION

This documentation refers to Demeter version 0.9.13.

=head1 SYNOPSIS

This plugin directly reads the binary files written by NSLS beamline
X15B.

=head1 X15B files

At X15b there is a program called x15totxt, written in Turbo Pascal by
some dude named Tim Darling.  He kindly left behind a short
explanation the format of the X15b binary data file.  It seems that
the header is 53 4-byte numbers.  Each line of data contains 16 4 byte
numbers.  Thus this file is easily unpacked and processed in four byte
bites.

The X15B file is recognized by a a four character sequence at the
beginning of the file which consists of character 212 (capital
O-circumflex in ISO 8859) followed by three nulls (character 0).

The resulting file is a well-labeled, well-formatted column data file
in a form that will work well with Athena or virtually any other
analysis or plotting program.  The columns are: energy, the I0 ion
chamber, the narrow and wide windows on the germanium detector, and
the transmission ion chamber.

=head1 AUTHOR

  Bruce Ravel <bravel@anl.gov>
  http://xafs.org/BruceRavel

=cut
