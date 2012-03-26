package Demeter::Plugins::Lytle;

use Moose;
extends 'Demeter::Plugins::FileType';

has '+is_binary'   => (default => 0);
has '+description' => (default => "the Lytle database file stored by encoder value");
has '+version'     => (default => 0.1);

use Demeter::Constants qw($R2D $HC);

use Scalar::Util qw(looks_like_number);
use List::MoreUtils qw(all);

sub is {
  my ($self) = @_;
  open D, $self->file or $self->Croak("could not open " . $self->file . " as data (Lytle)\n");
  my $first = <D>;
  close D;
  return 1 if ($first =~ m{\A\s*NPTS\s+NS\s+CUEDGE\s+CUHITE});
  return 0;
};

sub fix {
  my ($self) = @_;

  my $file = $self->file;
  my $new = File::Spec->catfile($self->stash_folder, $self->filename);
  ($new = File::Spec->catfile($self->stash_folder, "toss")) if (length($new) > 127);
  open D, $file or die "could not open $file as data (fix in Lytle)\n";
  open N, ">".$new or die "could not write to $new (fix in Lytle)\n";

  my ($stpdeg, $dspacing) = (0, 0);

  while (<D>) {
    chomp;
    next if (m{\A\s*\z});
    my @list = split(" ", $_);

    if ($_ =~ m{\A\s*NPTS}) {	# first two lines, snarf mono parameters
      print N "# ", $_, $/;
      my $line = <D>;
      print N "# ", $line;
      my @fields = split(" ", $line);
      ($dspacing, $stpdeg) = @fields[4,5];

    } elsif ($_ =~ m{\A\s*(?:DELTA|DELEND|SEC|OFFSETS)}) { # various headers
      print N "# ", $_, $/;

    } elsif (all {looks_like_number($_)} @list) {
      my $line   = <D>;
      $line      =~ s{(E[-+]\d+)-}{$1 -}gi;
      my @fields = split(" ", $line);
      my $steps  = shift @fields;
      my $energy = $HC / (2 * $dspacing) / sin( $steps / ($R2D * $stpdeg));
      print N join(" ", sprintf("%12.5E", $energy), @fields) . $/;

    } else { #($_ =~ m{\d{1,2}-\d{1,2}\-\d{1,2}\s*\z}) { # comment line with date at end
      #print "found it!\n";
      print N "# ", $_, $/;

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
	    numerator   => '$4',
	    denominator => '$2',
	    ln          =>  0,);
  };
};


__PACKAGE__->meta->make_immutable;
1;

=head1 NAME

Demeter::Plugin::Lytle - Import Lytle database files stored by encoder value.

=head1 SYNOPSIS

Import Lytle data of the sort that stores encoder value and requires a
transformation to energy.  See question 3 at
L<http://cars9.uchicago.edu/ifeffit/FAQ/Data_Handling>.

=head1 DESCRIPTION

This parses the header to obtain the monochromator d-spacing and the
steps per degree, then uses those values to convert the first column
-- which contains encoder values -- into energy values.  All headers
are simply commented and no attempt is made to write column labels,

The Lytle files that are processed by this plugin have headers that
look like this:

  NPTS  NS CUEDGE  CUHITE   DSPACE  STPDEG  STEPMM  START    STOP     SCALE
   480   4  84294. 200000. 1.92017   4000.   3150.  85290.  74500.    2.000
   DELTA:     50.      8.     16.     32.     46.
  DELEND:  84788.  83804.  81216.  76752.  71076.
     SEC:   2.000   2.000   2.000   2.000   2.000
  OFFSET: 1830. 1937.  366.  851.    4.    6.  137.    4.    6.   18.  641.    3.    2.    5.   61.   20.   93.  232.    0.    0.    0.    0.    0.    0.
 5% CU/CAB IN H2 AT 40C                                            7   9  6-10-83

=head1 BUGS AND LIMITATIONS

=over 4

=item *

Given that the Lytle database stores the files as unix compressed (.Z)
files, directly read compressed files using Archive::Zip

=back

=head1 AUTHOR

  Bruce Ravel <bravel@bnl.gov>
  http://xafs.org/BruceRavel/
