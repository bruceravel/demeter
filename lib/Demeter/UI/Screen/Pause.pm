package Demeter::UI::Screen::Pause;

=for Copyright
 .
 Copyright (c) 2006-2009 Bruce Ravel (bravel AT bnl DOT gov).
 All rights reserved.
 .
 This file is free software; you can redistribute it and/or
 modify it under the same terms as Perl itself. See The Perl
 Artistic License.
 .
 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut

use Moose::Role;

use Regexp::Common;
use Readonly;
Readonly my $NUMBER => $RE{num}{real};

has 'prompt'   => (is => 'rw', isa => 'Str', default => "Hit return to continue> ");

sub pause {
  my ($self, $length) = @_;
  $length ||= -1;
  $length = -1 if ($length !~ m{$NUMBER});
  my $keypress = $length;
  if ($length > 0) {
    sleep $length;
  } else {
    print $self->prompt;
    $keypress = <STDIN>;
  };
  return $keypress;
};

1;

=head1 NAME

Demeter::UI::Screen::Pause - A generic pause method

=head1 VERSION

This documentation refers to Demeter version 0.3.

=head1 SYNOPSIS

   $fitobject->pause(-1);

=head1 DESCRIPTION

This role for a Demeter object provides some on-screen feedback for
lengthy procedures.  This role is imported when the UI mode is set to
"screen".  See L<Demeter/PRAGMATA>.  The idea is to provide a
spinny thing for the user to look at when running something time
consuming from the command line.

=head1 ATTRIBUTE

=over 4

=item C<prompt>

=back

=head1 METHODS

=over 4

=item C<pause>

   $object->pause(-1);

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

Copyright (c) 2006-2009 Bruce Ravel (bravel AT bnl DOT gov). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
