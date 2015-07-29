package Demeter::Plugins::BM23;  # -*- cperl -*-

use Moose;
extends 'Demeter::Plugins::FileType';

use Scalar::Util qw(looks_like_number);

has '+is_binary'   => (default => 0);
has '+description' => (default => "ESRF beamline BM23");
has '+version'     => (default => 0.1);

sub is {
  my ($self) = @_;
  open D, $self->file or $self->Croak("could not open " . $self->file . " as data (BM23)\n");
  my $first = <D>;
  close D;
  return 0 unless (($first =~ m{BM23}) and ($first =~ m{E\.S\.R\.F\.}));
  return 1;
};


sub fix {
  my ($self) = @_;
  my $new = File::Spec->catfile($self->stash_folder, $self->filename);
  ($new = File::Spec->catfile($self->stash_folder, "toss")) if (length($new) > 127);
  open D, $self->file or die "could not open " , $self->file . " as data (fix in X10C)\n";
  open N, ">".$new or die "could not write to $new (fix in X10C)\n";
  my $header = 1;
  while (<D>) {
    chomp;
    next if ($_ =~ m{\-+\z});
    if ($_ =~ m{N\s+\d+}) {
      print N "# ---------------------------------", $/;
    } elsif ($_ =~ m{\A\#L}) {
      my $labels = $_;
      $labels =~ s{\#L}{\#};
      print N $labels, $/;
      $header = 0;
    } elsif ($header == 0) {
      my @list = split(" ", $_);
      next if not looks_like_number($list[0]);
      $list[0] *= 1000;
      print N join(" ", @list), $/;
    } else {
      print N $_, $/;
    }
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
    return ();
  };
};


__PACKAGE__->meta->make_immutable;
1;
__END__


=head1 NAME

Demeter::Plugin::BM23 - ESRF BM23 filetype plugin

=head1 VERSION

This documentation refers to Demeter version 0.9.22.

=head1 SYNOPSIS

This plugin cleans up the messy header from the BM23 spec file, which
has a couple of features which confuse Ifeffit's file parsing.

=head1 Methods

=over 4

=item C<is>

The is method is used to identify the file type, typically by some
information contained within the file.  In the case of ESRF BM23 data,
the file is recognized by the strings "BM23" and "E.S.R.F." on the
first line.

=item C<fix>

Clean up the header by removing extraneous lines of all dashes and by
cleaning up the lines after the final line of dashes so that Ifeffit
will properly recognize the column labels.  Also clean up the column
label line to get rid of spec's "L" tag, which confuses Ifeffit and
Athena by naming the first column "L" rather an "e_kev_".

=back

=head1 AUTHOR

  Bruce Ravel, L<http://bruceravel.github.io/home>
  http://bruceravel.github.io/demeter/
