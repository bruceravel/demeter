package Demeter::UI::Wx::EchoArea;

=for Copyright
 .
 Copyright (c) 2006-2013 Bruce Ravel (bravel AT bnl DOT gov).
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

use strict;
use warnings;
use Carp;

use Wx qw( :everything );
##use Wx::Event qw(EVT_KEY_DOWN);
use base 'Wx::Panel';

my @buffer;

sub new {
  my ($class, $parent) = @_;
#  $maxlength ||= 0;
  my $self = $class->SUPER::new($parent, -1);
  my $sizer = Wx::BoxSizer->new( wxHORIZONTAL );
  $self->{prompt} = Wx::StaticText->new($self, -1, q{});
  $self->{text}   = Wx::TextCtrl($self, -1, q{}, wxDefaultPosition, wxDefaultSize, wxTE_READONLY);
  $sizer->Add($self->{prompt}, 0, wxALL, 0);
  $sizer->Add($self->{text},   1, wxALL, 0);
  $self->{prompt}->Hide;
  $self->SetSizerAndFit($sizer);
  #$self->SetFont( Wx::Font->new( 16, wxDEFAULT, wxNORMAL, wxBOLD, 0, "" ) );
  return $self;
};

sub SetStatusText {

};
sub PopStatusText {

};
sub PushStatusText {

};


sub echo {
  my ($self, $string) = @_;
  ## set default colors
  $self->SetValue($string);
  push @buffer, $string if $string !~ m{\A\s*\z};
#  if ($self->{maxlength} and ($#buffer >= $self->{maxlength})) {
#    shift @buffer;
#  };
  return $self;
};

sub buffer {
  my ($self) = @_;
  return @buffer;
};
sub buffer_as_text {
  my ($self) = @_;
  return join("\n", @buffer);
};

sub Length {
  my ($self) = @_;
  return $#buffer;
}

sub clear {
  my ($self) = @_;
  @buffer = ();
  $self->SetValue(q{});
  return $self;
};

sub Warn {
  my ($self, $string) = @_;
  ## change the colors
  $self->echo($string);
  return $self;
};

sub Error {
  my ($self, $string) = @_;
  ## change the colors
  $self->echo($string);
  return $self;
};

1;

=head1 NAME

Demeter::UI::Wx::EchoArea - A run-time feedback widget

=head1 VERSION

This documentation refers to Demeter version 0.9.18.

=head1 SYNOPSIS

An echo area an be added to a Wx application:

  my $echoarea = Demeter::UI::Wx::EchoArea->new($self);
  $sizer -> Add($echoarea, 0, wxEXPAND|wxALL, 3);

The argument to the constructor method is a reference to the parent in
which this is placed.  This is used as the echo area for all
Hephaestus utilities.

=head1 DESCRIPTION

This is derived from Wx::TextCrtl and is intended to serve as an echo
area in a Wx application in much the similar fashion as Emacs' echo
area.

=head1 METHODS

=over 4

=item C<echo>

Insert text into the echo area and push that text onto the echo buffer.

  $echoarea->echo("Hi there!");

To clear the echo area without clearing the echo buffer, give this
method an empty string:

  $echoarea->echo(q{});

This method returns the reference to the EchoArea widget.

=item C<buffer>

Return the contents of the echo buffer as an array.

  @contents = $echoarea->buffer;

=item C<buffer_as_text>

Return the contents of the echo buffer as a simply formatted text string.

  $contents = $echoarea->buffer_as_text;

=item C<Length>

Return the length of echo buffer.

  $len = $echoarea->Length

=item C<clear>

Clear the echo area and empty the echo buffer.

  $echoarea->clear;

This method returns the reference to the EchoArea widget.

=back

=head1 CONFIGURATION


=head1 DEPENDENCIES

Demeter's dependencies are in the F<Bundle/DemeterBundle.pm> file.

=head1 BUGS AND LIMITATIONS

=over 4

=item *

Artemis & Athena will require a data entry mode.  That could be done
by liftingt he readonly flag, changing the background color, and
grabbing focus until carriage return is pressed.

=item *

Need configurable text color and max length.  Need warn and error
modes and configurable colors for those.

=back

Please report problems to the Ifeffit Mailing List
(L<http://cars9.uchicago.edu/mailman/listinfo/ifeffit/>)

Patches are welcome.

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
