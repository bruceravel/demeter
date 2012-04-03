package Demeter::Feff::MD::LAMMPS;
use Moose::Role;
use Moose::Util::TypeConstraints;

with 'Demeter::UI::Screen::Progress' if $Demeter::mode->ui eq 'screen';

use File::CountLines qw(count_lines);
use Chemistry::Elements qw (get_Z);
use Compress::Zlib;
use Regexp::Assemble;


sub _cluster {
  my ($self) = @_;

  $self->reading_file(1);
  open(my $H, '<', $self->file);
  my @cluster = ();
  ## snarf first line
  #- row 1: a series of 11 numbers, the last of which is the number of
  #  atoms in the model (in this case: 55488). The first ten numbers are
  #  just placeholders and don't denote anything.
  my @first = split(" ", <$H>);
  my $natoms = $first[$#first];
  my $el = q{};
  my @vec = ();

  if ($self->mo->ui eq 'screen') {
    #$self->start_spinner("Reading VASP file ".$self->file) 
    $self->progress('%30b %c of %m lines in file <Time elapsed: %8t>');
    $self->start_counter("Reading LAMMPS file ".$self->file." with $natoms atoms", int($natoms/1e3));
  };

  #   - row 19 onwards: these are the four entries you requested.
  #     Every row corresponds to one atom. The first number is the
  #     atom type, where 1=Cu and 2=Nb. The remaining three entries in
  #     every row are the x, y, and z coordinates of each atom, again
  #     in Angstroms. I've shifted the model so that the interface is
  #     at z=0. All the Cu atoms have z<0 and the Nb atoms have z>0.
  while (<$H>) {
    if (not $. % 1e3) {
      if ($self->mo->ui eq 'screen') {
	$self->count;
      } elsif (lc($self->mo->ui) eq 'wx') {
	$self->call_sentinal;
      };
    };
    next if m{\A\s*\z};
    @vec = split(" ", $_);
    next if $#vec == 2;
    $el = ($vec[0] == 1) ? 29 : 41; # generalize me!
    push @cluster, [@vec[1..3], $el];
  };
  close $H;
  $self->stop_counter if ($self->mo->ui eq 'screen');
  $self->nsteps(1);
  $self->clusters([\@cluster]);
  $self->reading_file(0);
  $self->update_file(0);
  return $self;
};

1;


=head1 NAME

Demeter::Feff::MD::LAMMPS - Role supporting LAMPPS output files

=head1 VERSION

This documentation refers to Demeter version 0.9.9.

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 NOTES ON THE LAMMPS FILE

From email with Mike Demkowicz

  The model is periodic in the interface plane and terminates in free
  surfaces in the direction normal to the interface plane. The file
  contents are:

  row 1: a series of 11 numbers, the last of which is the number of
         atoms in the model. The first ten numbers are just
         placeholders and don't denote anything.

  rows 10-12: the 3x3 matrix that describes the shape and size of the
         simulation cell. The vectors that describe the edges of the
         cell are the rows of this matrix. As you can see, the matrix
         is diagonal so the simulation cell edges are orthogonal. The
         x and y directions (first 2 entries) are parallel to the
         interface plane. The z direction (3rd entry) is normal to the
         interface plane, but since the model is not periodic in that
         direction this length is not of great importance (the actual
         bilayer thickness is about 80A). All lengths in Angstroms.

  - row 19 onwards: these are the four entries you requested. Every
         row corresponds to one atom. The first number is the atom
         type, where 1=Cu and 2=Nb. The remaining three entries in
         every row are the x, y, and z coordinates of each atom, again
         in Angstroms. I've shifted the model so that the interface is
         at z=0. All the Cu atoms have z<0 and the Nb atoms have z>0.

=head1 METHODS

=over 4

=item C<_cluster>

Fills C<clusters> attribute with a list-of-lists, each inner list
containing the cartesian coordinates and atomic species of each item
in the cluster at that time step.  The outer list is only 1 item long,
as this file does not contain a time sequence.

=back

=head1 DEPENDENCIES

Demeter's dependencies are in the F<Bundle/DemeterBundle.pm> file.

=head1 BUGS AND LIMITATIONS

Please report problems to Bruce Ravel (bravel AT bnl DOT gov)

Patches are welcome.

=head1 AUTHOR

Bruce Ravel (bravel AT bnl DOT gov)

L<http://cars9.uchicago.edu/~ravel/software/>


=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2012 Bruce Ravel (bravel AT bnl DOT gov). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut

