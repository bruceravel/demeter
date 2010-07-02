package Demeter::UI::Screen::Progress;

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
use Term::Sk;

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
has 'progress' => (is => 'rw', isa => 'Str', default => 'Elapsed: %8t %30b (%c of %m)');


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


my $counter = q{};

sub start_counter {
  my ($self, $text, $target) = @_;
  $text ||= 'Demeter is thinking';
  ($text .= "\n") if ($text !~ m{\n$});
  print $text;
  $target ||= 100;
  $counter = Term::Sk->new($self->progress, {freq => 's', base => 0, pdisp => '!'})
    or die "Error 0010: Term::Sk->new, (code $Term::Sk::errcode) $Term::Sk::errmsg";
  $counter->{target} = $target;
  $counter->{value}  = 0;
};
sub count {
  $counter->up;
};
sub stop_counter {
  $counter->close;
  $counter = q{}
};


1;

=head1 NAME

Demeter::UI::Screen::Progress - On screen indicators for lengthy operations

=head1 VERSION

This documentation refers to Demeter version 0.4.

=head1 SYNOPSIS

A spinner indicating and ongoing operation:

   $fitobject->start_spinner("Demeter is performing a fit");
    ...
   $fitobject->stop_spinner;

A counter indicating an operation of known length:

   $n = 100;
   $object->start_counter("Demeter is doing something $n times", $n);
    ...
   loop {
     $object->count;
   }
    ...
   $object->stop_counter;

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

=item C<progress>

The text string which formats the progress meter.  See L<Text::Sk> for
full details.  The default is

  Elapsed: %8t %30b (%c of %m)

This shows the elapsed time, a progress bar, and a count.

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

=item C<start_counter>

Start the counter.  This is typically called just before a time
consuming operation of a known number of steps.

   $object->start_spinner("Demeter is doing many things", 100);

The first argument is a bit of text describing what's going on.  A new
line will be appended if the text does not end in a newline.  The
second argument is the total number of steps in the operation.

=item C<count>

Update the counter.

  $object->count;

=item C<stop_counter>

Stop the counter.  This is typically called after the last step is
completed.

   $object->stop_spinner;

=back

=head1 DEPENDENCIES

Demeter's dependencies are in the F<Bundle/DemeterBundle.pm> file.
This module uses L<Term::Twiddle> to generate the indicator and
L<Term::Sk> for the counter.

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
