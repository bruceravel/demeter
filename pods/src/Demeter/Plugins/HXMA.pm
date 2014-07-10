package Demeter::Plugins::HXMA;  # -*- cperl -*-

use Moose;
extends 'Demeter::Plugins::FileType';

has '+is_binary'   => (default => 0);
has '+description' => (default => "the HXMA and SXRMB beamlines at the CLS");
has '+version'     => (default => 0.1);
has 'beamline'     => (is => 'rw', isa => 'Str', default => q{});

sub is {
  my ($self) = @_;
  open D, $self->file or die "could not open " . $self->file . " as data (HXMA)\n";
  my $first = <D>;
  close D, return 1 if ($first =~ m{CLS Data Acquisition});
  close D;
  return 0;
};

sub fix {
  my ($self) = @_;

  my $file = $self->file;
  my $new = File::Spec->catfile($self->stash_folder, $self->filename);
  ($new = File::Spec->catfile($self->stash_folder, "toss")) if (length($new) > 127);
  open D, $file or $self->Croak("could not open $file as data (fix in HXMA)\n");
  open N, ">".$new or die "could not write to $new (fix in HXMA)\n";

  my $first = 1;
  my $identified_file_contents = 0;

  my $found_headers = 0;
  my ($energy, $lytle, $i0, $it, $ir) = (0,0,0,0,0);
  while (<D>) {
    if ((not $found_headers) and ($_ =~ m{\"Event-ID\"})) {
      $found_headers = 1;
      my @headers = split(/\s+/, $_);
      foreach my $i (1 .. $#headers) {
   	($energy = $i-1) if ($headers[$i] =~ m{Energy:sp});
   	($lytle  = $i-1) if ($headers[$i] =~ m{mcs03:fbk});
   	($i0     = $i-1) if ($headers[$i] =~ m{mcs04:fbk});
   	($it     = $i-1) if ($headers[$i] =~ m{mcs05:fbk});
   	($ir     = $i-1) if ($headers[$i] =~ m{mcs06:fbk});
      };
      $identified_file_contents = 1;
    };

    if ($_ !~ m{^\#}) {
      my @data = split(/,?\s+/, $_);
      if ($first) {

	printf N "# %s %s demystified:\n", $self->beamline, $file;
	print N "# ", "-" x 60, $/;
	if (($self->beamline eq 'HXMA') and $identified_file_contents) {
	  print N "# Energy        I0        It        Ir        Lytle$/";
	} else {
	  print N "# energy ", join(" ", (2..$#data)), $/;
	};
	$first = 0;
      };

      if (($self->beamline eq 'HXMA') and $identified_file_contents) {
	printf N "  %s  %s  %s  %s  %s$/",
	  $data[$energy], $data[$i0], $data[$it], $data[$ir], $data[$lytle];
      } else {
	print N join(" ", @data[1..$#data]), $/;
      };
    } elsif ($_ =~ m{BL1606-B}) {
      $self->beamline('SXRMB');
    } elsif ($_ =~ m{BL1606-I}) {
      $self->beamline('HXMA');
    };
  };

  close N;
  close D;
  $self->fixed($new);
  return $new;
};

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
	    numerator   => '$5',
	    denominator => '$2',
	    ln          =>  0,);
  };
};



__PACKAGE__->meta->make_immutable;
1;
__END__

=head1 NAME

Demeter::Plugin::HXMA - Demystify files from the HXMA beamline at the CLS

=head1 VERSION

This documentation refers to Demeter version 0.9.20.

=head1 SYNOPSIS

This plugin strips the many columns not normally needed from a file
from the CLS HXMA beamline.  Most significantly, this strips the
leading 1 from every line of data, a feature which confuses Athena's
column selection dialog.  It also chooses the Energy:sp column as the
energy axis.

=head1 Methods

=over 4

=item C<is>

Recognize the HXMA file by the first line, which contains the phrase
"CLS Data Acquisition".

=item C<fix>

Strip out all columns except for energy, I0, I1, I2, and the Lytle
detector.  Also write sensible column labels to the output data file.

=back

=head1 AUTHOR

  Bruce Ravel <bravel@bnl.gov>
  http://bruceravel.github.io/demeter

