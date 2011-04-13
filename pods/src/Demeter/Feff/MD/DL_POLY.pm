package Demeter::Feff::MD::DL_POLY;
use Moose::Role;

sub _number_of_steps {
  my ($self) = @_;
  die("File ".$self->file." does not exist\n") if (not -e $self->file);
  die("File ".$self->file." cannot be read\n") if (not -r $self->file);
  open(my $H, '<', $self->file);
  my $count = 0;
  while (<$H>) {
    ++$count if m{\Atimestep};
  }
  #print $steps, $/;
  close $H;
  $self->nsteps($count);
  return $self;
};

sub _cluster {
  my ($self) = @_;
  $self->_number_of_steps;
  open(my $H, '<', $self->file);
  my @cluster = ();
  my @all = ();
  while (<$H>) {
    if (m{\Atimestep}) {
      push @all, [@cluster] if $#cluster>0;
      $#cluster = -1;
      next;
    };
    next if not m{\APt}; # skip the three lines trailing the timestamp
    my $position = <$H>;
    my @vec = split(' ', $position);
    push @cluster, \@vec;
    <$H>;
    <$H>;
    #my $velocity = <$H>;
    #my $force    = <$H>;
    #chomp $position;
  };
  push @all, [@cluster];
  $self->clusters(\@all);
  close $H;
  return $self;
};

1;


=head1 NAME

Demeter::Feff::MD::DL_POLY - Role supporting DL_POLY HISTORY file

=head1 VERSION

This documentation refers to Demeter version 0.4.

=head1 SYNOPSIS

=head1 DESCRIPTION

This role provides support for importing data from the DL_POLY HISTORY
file, which is a format for providing the trajectory of a cluster
during a molecular dynamics simulation.  The DL_POLY website is
L<http://www.cse.scitech.ac.uk/ccg/software/DL_POLY/> and a
description of the HISTORY format is in section 5.2.1 of the User
Guide, a link to which can be found at the DL_POLY website.

The purpose of this role is to extract parse the DL_POLY HISTORY file
into the data structures expected by the rest of Demeter's histogram
subsystem.

=head1 METHODS

=over 4

=item C<_number_of_steps>

Fills the C<nsteps> attribute of the object using this role with the
number of time steps contained in the input file (contained in the
C<file> attribute).

=item C<_cluster>

Fills C<clusters> attribute with a list-of-lists, each inner list
containing the cartesian coordinates and atomic species of each item
in the cluster at that time step.  The outer list is a list of
timesteps in chronological order.

=back

=head1 DEPENDENCIES

Demeter's dependencies are in the F<Bundle/DemeterBundle.pm> file.

=head1 BUGS AND LIMITATIONS

=over 4

=item *

This currently only works for a monoatomic cluster.

=back

Please report problems to Bruce Ravel (bravel AT bnl DOT gov)

Patches are welcome.

=head1 AUTHOR

Bruce Ravel (bravel AT bnl DOT gov)

L<http://cars9.uchicago.edu/~ravel/software/>


=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2011 Bruce Ravel (bravel AT bnl DOT gov). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut

