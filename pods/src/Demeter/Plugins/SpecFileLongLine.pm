package Demeter::Plugins::SpecFileLongLine;  # -*- cperl -*-

use Moose;
extends 'Demeter::Plugins::FileType';

has '+is_binary'   => (default => 0);
has '+description' => (default => "a beamline that writes SPEC files with a long column label line");
has '+version'     => (default => 0.1);

sub is {
  my ($self) = @_;
  my $is_asf = 0;
  open D, $self->file or $self->Croak("could not open " . $self->file . " as data (SpecFileLongLine)\n");
  while (<D>) {
    last if ($_ !~ m{\A\#});
    if ($_ =~ m{\A\#L}) {
      $is_asf = 1 if length($_) > 254; # do this if the #L line exists and is very long
      last;
    };
  };
  close D;
  return $is_asf;
};

sub fix {
  my ($self) = @_;
  my $new = File::Spec->catfile($self->stash_folder, $self->filename);
  ($new = File::Spec->catfile($self->stash_folder, "toss")) if (length($new) > 127);
  open D, $self->file or die "could not open " , $self->file . " as data (fix in SpecFileLongLine)\n";
  open N, ">".$new or die "could not write to $new (fix in SpecFileLongLine)\n";
  while (<D>) {
    print N $_ if ($_ !~ m{\A\#L}); # simply copy all line except the column label line
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
	    numerator   => '$56',
	    denominator => '$57',
	    ln          =>  1,);
  } else {
    return ();
  };
};

__PACKAGE__->meta->make_immutable;
1;
__END__


=head1 NAME

Demeter::Plugins::SpecFileLongLine - Deal with SPEC files with a very long column label line

=head1 VERSION

This documentation refers to Demeter version 0.9.22.

=head1 SYNOPSIS

This plugin cleans up a SPEC file that has a column label line -- the one
with C<#L> -- that is too long for the hard-wired string length in Ifeffit.

=head1 Methods

=over 4

=item C<is>

The C<is> method is used to identify the file type by noticing a C<#L>
line that is longer than 254 characters.

=item C<fix>

This cleans up the file by simply copying every line except the
troublesome one.

=back

=head1 AUTHOR

  Bruce Ravel, L<http://bruceravel.github.io/home>
  http://bruceravel.github.io/demeter/
