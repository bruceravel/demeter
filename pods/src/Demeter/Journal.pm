package Demeter::Journal;

=for Copyright
 .
 Copyright (c) 2006-2014 Bruce Ravel (bravel AT bnl DOT gov).
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

use autodie qw(open close);

use Moose;
extends 'Demeter';


has '+name' => (default => 'Journal');
has 'text'  => (is => 'rw', isa => 'Str',   default => q{});

sub BUILD {
  my ($self, @params) = @_;
  $self->mo->push_Journal($self);
};

sub append {
  my ($self, $more, $nl) = @_;
  $nl ||= 0;
  my $current = $self->text;
  $current .= $more;
  $current .= $/ if $nl;
  $self->text($current);
  return $self;
};

1;

=head1 NAME

Demeter::Journal - A journal object for Demeter

=head1 VERSION

This documentation refers to Demeter version 0.9.20.

=head1 SYNOPSIS

   $journal_object = Demeter::Journal -> new();
   $journal_object -> append("Something interesting");

=head1 DESCRIPTION

This very simple Demeter object carries a bit of text that intended
for use as the journal entry in an Athena or Artemis project, but
could, I suppose, be used as a text buffer in some other context.

=head1 ATTRIBUTES

There is just one attribute -- C<text> holds the textual content of
the Journal.

=head1 METHODS

Again, there is just one method -- C<append> adds a bit more text to
the C<text> attribute, optionally followed by a new line.

  $journal -> append("something interesting");
  $journal -> append("something else interesting", 1);

The first argument is the text to append to the Journal.  The second
argument, when true, appends a newline character after appending the
first argument.

=head1 SERIALIZATION AND DESERIALIZATION

Serialization is usually handled by the GUI.

=head1 CONFIGURATION AND ENVIRONMENT

See L<Demeter::Config> for a description of the configuration system.

=head1 DEPENDENCIES

Demeter's dependencies are in the F<Build.PL> file.

=head1 BUGS AND LIMITATIONS

Please report problems to the Ifeffit Mailing List
(L<http://cars9.uchicago.edu/mailman/listinfo/ifeffit/>)

Patches are welcome.

=head1 AUTHOR

Bruce Ravel (bravel AT bnl DOT gov)

L<http://bruceravel.github.io/demeter/>

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2014 Bruce Ravel (bravel AT bnl DOT gov). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
