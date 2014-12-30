package Demeter::UI::Screen::Pause;

=for Copyright
 .
 Copyright (c) 2006-2015 Bruce Ravel (http://bruceravel.github.io/home).
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

use Demeter::Constants qw($NUMBER);

#use subs qw(REVERSE UNDERLINE RESET);
my $ANSIColor_exists = (eval "require Term::ANSIColor");
if ($ANSIColor_exists) {
  import Term::ANSIColor qw(:constants);
} else {
  sub REVERSE   {q{}};
  sub UNDERLINE {q{}};
  sub RESET     {q{}};
};


has 'prompt'    => (is => 'rw', isa => 'Str', default => "Hit return to continue> ");
has 'highlight' => (is => 'rw', isa => 'Str', default => 'underline',
		    trigger => sub{my ($self, $new) = @_;
				   if (lc($new) eq 'underline') {
				     $self->hl(UNDERLINE);
				   } elsif (lc($new) eq 'reverse') {
				     $self->hl(REVERSE);
				   } else {
				     $self->hl(q{});
				   };
				 },
		   );
has 'hl'        => (is => 'rw', isa => 'Str', default => UNDERLINE);

override 'pause' => sub {
  my ($self, $length) = @_;
  $length ||= -1;
  $length = -1 if ($length !~ m{$NUMBER});
  my $keypress = $length;
  if ($length > 0) {
    sleep $length;
  } else {
    print join("", $self->hl, $self->prompt, RESET);
    $keypress = <STDIN>;
  };
  return $keypress;
};

1;

=head1 NAME

Demeter::UI::Screen::Pause - A generic pause method for the screen UI

=head1 VERSION

This documentation refers to Demeter version 0.9.21.

=head1 SYNOPSIS

   $fitobject->pause(-1);

=head1 DESCRIPTION

This role for a Demeter object provides a generic and easy-to-use
pause when using the terminal.  This role is imported when the UI mode
is set to "screen".  See L<Demeter/PRAGMATA>.

Trying to use the C<pause> method without being in screen mode will do
nothing.  That is because there is a pause method in the base class
that does nothing.  That no-op gets overridden when in screen mode
with this more useful method.  Note, however, that the attributes
documented below do not exist in the base class and will return the
"Can't locate object method" error when you attempt to access them
outside of screen mode.

=head1 ATTRIBUTES

=over 4

=item C<prompt>

The text of the carriage return prompt which is displayed when not
pausing for specified amount of time.  The default is

  Hit return to continue>

If ANSI colors are available, the prompt will be displayed in reverse
colors (usually black on white).  The ANSI colors control sequences
are part of the default value of this attribute and so can be
overriden by resetting its value.

=item C<highlight>

This sets the form of highlighting of the prompt.  The possible values
are underline and reverse, which will cause the prompt text to be
either underlined or reverse video in the sense of C<Term::ANSIColor>.
Any other value for this attribute will result in no highlighting of
the prompt string.

=back

=head1 METHODS

=over 4

=item C<pause>

This pauses either for the amount of time indicated in seconds or, if
the argument is zero or negative, until the enter key is pressed.

   $object->pause(-1);

This method returns whatever string is entered before return is hit.
So this method could be used, for example, to prompt for the answer
with a question.

   $object->prompt("What is 2+2? ");
   my $answer = $object->pause;
   chomp $answer;
   if ($answer eq '4') {
      print "You're a math genius!\n";
   } else {
      print "Sigh. I don't know why I even bother....\n";
   };

=back

=head1 DEPENDENCIES

Demeter's dependencies are in the F<Build.PL> file.
This module uses L<Term::ANSIColor> if it is available.

=head1 BUGS AND LIMITATIONS

Please report problems to the Ifeffit Mailing List
(L<http://cars9.uchicago.edu/mailman/listinfo/ifeffit/>)

Patches are welcome.

=head1 AUTHOR

Bruce Ravel (L<http://bruceravel.github.io/home>)

L<http://bruceravel.github.io/demeter/>


=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2015 Bruce Ravel (http://bruceravel.github.io/home). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
