package Demeter::Plugins::X10C;  # -*- cperl -*-

use Moose;
use MooseX::Aliases;
use MooseX::StrictConstructor;
with 'Demeter::Tools';
with 'Demeter::Project';

use File::Basename;
use File::Copy;

has 'is_binary'   => (is => 'ro', isa => 'Bool', default => 0);
has 'description' => (is => 'ro', isa => 'Str',
		      default => "Read files from NSLS beamline X10C.");

has 'parent'      => (is => 'rw', isa => 'Any',);
has 'hash'        => (is => 'rw', isa => 'HashRef', default => sub{{}});
has 'file'        => (is => 'rw', isa => 'Str', default => q{});
has 'fixed'       => (is => 'rw', isa => 'Str', default => q{});

sub is {
  my ($self) = @_;
  open D, $self->file or die "could not open " . $self->file . " as data (X10C)\n";
  my $first = <D>;
  close D, return 0 unless (uc($first) =~ /^EXAFS/);
  my $lines = 0;
  while (<D>) {
    close D, return 1 if (uc($first) =~ /^\s+DATA START/);
    ++$lines;
    #close D, return 0 if ($lines > 40);
  };
  close D;
};


sub fix {
  my ($self) = @_;
  my ($nme, $pth, $suffix) = fileparse($self->file);
  my $new = File::Spec->catfile($self->stash_folder, $nme);
  ($new = File::Spec->catfile($self->stash_folder, "toss")) if (length($new) > 127);
  open D, $self->file or die "could not open " , $self->file . " as data (fix in X10C)\n";
  open N, ">".$new or die "could not write to $new (fix in X10C)\n";
  my $header = 1;
  my $null = chr(0).'+';
  while (<D>) {
    $_ =~ s/$null//g;		# clean up nulls
    print N "# " . $_ if $header; # comment headers
    ($header = 0), next if (uc($_) =~ /^\s+DATA START/);
    next if ($header);
    $_ =~ s/([eE][-+]\d{1,2})-/$1 -/g; # clean up 5th column
    print N $_;
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
	    denominator => '$6',
	    ln          =>  1,);
  } else {
    return ();
  };
};


1;
__END__


=head1 NAME

Demeter::Plugin::File::X10C - NSLS X10C filetype plugin

=head1 SYNOPSIS

This plugin directly files from NSLS beamline X10C

=head1 Methods

=over 4

=item C<is>

The is method is used to identify the file type, typically by some
information contained within the file.  In the case of an NSLS X10C
data, the file is recognized by the string "EXAFS" on the first line
and by the string "DATA START" several lines later.

Note that the C<is> method needs to be quick.  There may be many file
type plugins in the queue.  A file that does not meet any of the
plugin criteria will still be subjected to each plugin's C<is>
method. If C<is> is slow, Athena will be slow.


=item C<fix>

For an NSLS X10C file, the null characters are stripped from the
header, the header lines are commented out with hash characters, and
the situation of the fifth data column not being preceeded by white
space is corrected.


=back


=head1 AUTHOR

  Bruce Ravel <bravel@anl.gov>
  http://feff.phys.washington.edu/~ravel/software/exafs/
  Athena copyright (c) 2001-2006
