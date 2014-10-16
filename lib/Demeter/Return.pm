package Demeter::Return;

use Moose;

has 'status'  => (is => 'rw', isa => 'Int',  default => 1);
has 'message' => (is => 'rw', isa => 'Str',  default => q{});

sub is_ok {
  my ($self) = @_;
  return 0 if not $self->status;
  return 1;
};

1;


=head1 NAME

Demeter::Return - A simple return object

=head1 VERSION

This documentation refers to Demeter version 0.9.21.

=head1 ATTRIBUTES

=over 4

=item C<status>

A numerical status.  Evaluates to false to indicate a problem.  Also
used to return a numerical value for a successful return.

=item C<message>

A string response.  This eaither returns an exception message or
textual information about a successful return.

=back

=head1 METHODS

=over 4

=item C<is_ok>

Returns true if no problem is reported.

   my $ret = $object -> some_method;
   do {something} if $ret->is_ok;

   my $ret = $object -> some_method;
   die $ret->message if not $ret->is_ok;

=back

=head1 AUTHOR

Bruce Ravel, L<http://bruceravel.github.io/home>

L<http://bruceravel.github.io/demeter/>

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2011-2014 Bruce Ravel (L<http://bruceravel.github.io/home>). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut

