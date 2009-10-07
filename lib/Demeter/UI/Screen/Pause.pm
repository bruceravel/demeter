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


#use subs qw(REVERSE RESET);
my $ANSIColor_exists = (eval "require Term::ANSIColor");
if ($ANSIColor_exists) {
  import Term::ANSIColor qw(:constants);
} else {
  sub REVERSE {q{}};
  sub RESET   {q{}};
};


has 'prompt' => (is => 'rw', isa => 'Str', default => REVERSE."Hit return to continue> ".RESET);

override 'pause' => sub {
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

Demeter::UI::Screen::Pause - A generic pause method for the screen UI

=head1 VERSION

This documentation refers to Demeter version 0.3.

=head1 SYNOPSIS

   $fitobject->pause(-1);

=head1 DESCRIPTION

This role for a Demeter object provides a generic pause when using the
terminal.  This role is imported when the UI mode is set to "screen".
See L<Demeter/PRAGMATA>.

Trying to use the C<pause> method without being in screen mode will
cause a fatal error something like this:

  Can't locate object method "pause" via package "Demeter::Data" at merge.pl line 37.

=head1 ATTRIBUTE

=over 4

=item C<prompt>

The text of the carriage return prompt which is displayed when not
pausing for specified amount of time.  The default is

  Hit return to continue>

If ANSI colors are available, the prompt will be displayed in reverse
colors (usually black on white).  The ANSI colors control sequences
are part of the default value of this attribute and so can be
overriden by resetting its value.

=back

=head1 METHODS

=over 4

=item C<pause>

This pauses either for the amount of time indicated in seconds or, if
the argument is zero or negative, until the enter key is pressed.

   $object->pause(-1);

This method returns whatever string is entered before return is hit.
So this method could be used, for example, to prompt for the answer
to a question.

   my $answer = $object->prompt("What is 2+2? ");
   if ($answer eq '4') {
      print "You're a math genius!\n";
   } else {
      print "Sigh. I don't know why I even bother....\n";
   };

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
