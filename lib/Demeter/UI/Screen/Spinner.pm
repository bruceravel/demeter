package Demeter::UI::Screen::Spinner;

=for Copyright
 .
 Copyright (c) 2006-2010 Bruce Ravel (bravel AT bnl DOT gov).
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
use Demeter::NumTypes qw( PosNum );

use Term::Twiddle;

has 'rate'   => (is => 'rw', isa =>  PosNum,         default => 0.1);
has 'thingy' => (is => 'rw', isa => 'ArrayRef[Str]', default => sub{[
								     '   -+-   ',
								     '   [ ]   ',
								     '  [   ]  ',
								     ' [     ] ',
								     '[       ]',
								     ' [     ] ',
								     '  [   ]  ',
								     '   [ ]  ',
								     '   -+-   ',
								    ]});

my $spinner = new Term::Twiddle;

sub start_spinner {
  my ($self, $text) = @_;
  $text ||= 'Demeter is thinking ';
  print $text, " ";
  $spinner->rate($self->rate);
  $spinner->thingy($self->thingy);
  $spinner->start;
};
sub stop_spinner {
  my ($self) = @_;
  $spinner->stop;
  print $/;
};

1;

=head1 NAME

Demeter::UI::Screen::Spinner - On screen indicator for lengthy operations

=head1 VERSION

This documentation refers to Demeter version 0.3.

=head1 SYNOPSIS

   $fitobject->start_spinner("Demeter is performing a fit");
    ...
   $fitobject->stop_spinner;

=head1 DESCRIPTION

This role for a Demeter object provides some on-screen feedback for
lengthy procedures.  This role is imported when the UI mode is set to
"screen".  See L<Demeter/PRAGMATA>.  The idea is to provide a
spinny thing for the user to look at when running something time
consuming from the command line.

=head1 ATTRIBUTES

The attributes of this role take their names from parameters for
L<Term::Twiddle>.  Like all Moose attributes, their accessors take the
same names.

=over 4

=item C<thingy>

An array with the sequence of text strings comprising the spinner.
The default is a throbber that goes from S<"[      ]"> to "-+-" and
back.

=item C<rate>

The speed at which the thingy changes.  Default is 0.1.

=back

=head1 METHODS

=over 4

=item C<start_spinner>

Start the spinner.  This is typically called just before a time
consuming operation.

   $fitobject->start_spinner("Demeter is performing a fit");

The optional argument is some text to print to the screen in front of
the spinner.  This text would typically not include a new line.

=item C<stop_spinner>

Stop the spinner.  This is typically called at the end of a time
consuming operation.

   $fitobject->stop_spinner;

=back

=head1 DEPENDENCIES

Demeter's dependencies are in the F<Bundle/DemeterBundle.pm> file.
This module uses L<Term::Twiddle> to generate the indicator.

=head1 BUGS AND LIMITATIONS

=over 4

=item *

Configuring the form and rate of the twiddler would be nice.

=back

Please report problems to Bruce Ravel (bravel AT bnl DOT gov)

Patches are welcome.

=head1 AUTHOR

Bruce Ravel (bravel AT bnl DOT gov)

L<http://cars9.uchicago.edu/~ravel/software/>


=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2010 Bruce Ravel (bravel AT bnl DOT gov). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
