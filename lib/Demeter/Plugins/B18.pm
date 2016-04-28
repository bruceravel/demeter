package Demeter::Plugins::B18;  # -*- cperl -*-

use Moose;
extends 'Demeter::Plugins::FileType';

use Scalar::Util qw(looks_like_number);

has '+is_binary'   => (default => 0);
has '+description' => (default => "Diamond beamline B18, Core XAFS");
has '+version'     => (default => 0.1);

sub is {
  my ($self) = @_;
  open D, $self->file or $self->Croak("could not open " . $self->file . " as data (B18)\n");
  my $first = <D>;
  my $second = <D>;
  close D;
  return 0 unless (($first =~ m{Diamond}) and ($second =~ m{B18-CORE XAS}));
  return 1;
};


sub fix {
  my ($self) = @_;
  my $new = File::Spec->catfile($self->stash_folder, $self->filename);
  ($new = File::Spec->catfile($self->stash_folder, "toss")) if (length($new) > 127);
  open D, $self->file or die "could not open " , $self->file . " as data (fix in B18)\n";
  open N, ">".$new or die "could not write to $new (fix in B18)\n";
  my $header = 1;
  while (<D>) {
    if ($_ =~ m{\A\#}) {
      print N $_;
    } else {
      next if ((Demeter->is_ifeffit) and ($. % 2));
      (my $line = $_) =~ s{\t}{ }g;
      $line =~ s{\A\s+}{};
      print N $line;
    };
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
	    numerator   => '$8+$9+$10+$11+$12+$13+$14+$15+$16+$17+$18+$19+$20+$21+$22+$23+$24+$25+$26+$27+$28+$29+$30+$31+$32+$33+$34+$35+$36+$37+$38+$39+$40+$41+$42+$43',
	    denominator => '$3',
	    ln          =>  0,);
  } else {
    return ();
  };
};


__PACKAGE__->meta->make_immutable;
1;
__END__


=head1 NAME

Demeter::Plugin::B18 - Diamond B18 filetype plugin

=head1 VERSION

This documentation refers to Demeter version 0.9.25.

=head1 SYNOPSIS

This plugin rationalizes a file from B18's 36-element detector to make
importing it into Athena less painful.

=head1 Methods

=over 4

=item C<is>

The is method is used to identify the file type, typically by some
information contained within the file.  In the case of ESRF B18 data,
the file is recognized by the strings "Diamond" and "B18-CORE XAS" in
the first two line.

=item C<fix>

Remove tabs and leading spaces from the data table, filter out every
other line to make the file of an ifeffit-friendly length, and make a
good suggestion for column selection.

=back

=head1 AUTHOR

  Bruce Ravel, L<http://bruceravel.github.io/home>
  http://bruceravel.github.io/demeter/
