package Demeter::Feff::MD::Null;
use Moose::Role;

sub _number_of_steps {
  my ($self) = @_;
  die("No histogram backend was specified.\n");
};

sub _cluster {
  my ($self) = @_;
  die("No histogram backend was specified.\n");
};

1;


=head1 NAME

Demeter::Feff::MD::DL_POLY - Fallback role for Demeter's histogram subsystem

=head1 VERSION

This documentation refers to Demeter version 0.9.16.

=head1 DESCRIPTION

This role provides a way of reminding the user to specify what kind of
molecular dynamics file is being imported.

=head1 METHODS

The two standard methods for histrogram backends are provided:

=over 4

=item C<_number_of_steps>

=item C<_cluster>

=back

Both of these die with a warning about specifying a backend.

=head1 AUTHOR

Bruce Ravel (bravel AT bnl DOT gov)

L<http://bruceravel.github.com/demeter/>


=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2013 Bruce Ravel (bravel AT bnl DOT gov). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut

