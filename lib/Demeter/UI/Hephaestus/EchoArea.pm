package Demeter::UI::Hephaestus::EchoArea;
use strict;
use warnings;
use Carp;

use Wx qw( :everything );
use Wx::Event qw(EVT_LISTBOX EVT_BUTTON EVT_KEY_DOWN);
use base 'Wx::TextCtrl';

my @buffer;

sub new {
  my ($class, $parent) = @_;
  my $self = $class->SUPER::new($parent, -1, q{}, wxDefaultPosition, wxDefaultSize, wxTE_READONLY);
  my $echo_color = Wx::Colour->new(139, 58, 58);
  $self->SetForegroundColour( $echo_color );
  #$self->SetFont( Wx::Font->new( 16, wxDEFAULT, wxNORMAL, wxBOLD, 0, "" ) );
  return $self;
};

sub echo {
  my ($self, $string) = @_;
  $self->SetValue($string);
  push @buffer, $string if $string !~ m{\A\s*\z};
};

1;

=head1 NAME

Demeter::UI::Hephaestus::EchoArea - A run-time feedback widget

=head1 VERSION

This documentation refers to Demeter version 0.2.

=head1 SYNOPSIS

An echo area an be added to a Wx application:

  my $echoarea = Demeter::UI::Hephaestus::EchoArea->new($self);
  $sizer -> Add($echoarea, 0, wxEXPAND|wxALL, 3);

The argument to the constructor method is a reference to the parent in
which this is placed.  This is used as the echo area for all
Hephaestus utilities.

=head1 DESCRIPTION

This is derived from Wx::TextCrtl and is intended to serve as an echo
area in a Wx application in much the same manner as Emacs' echo area.

=head1 CONFIGURATION


=head1 DEPENDENCIES

Demeter's dependencies are in the F<Bundle/DemeterBundle.pm> file.

=head1 BUGS AND LIMITATIONS

Please report problems to Bruce Ravel (bravel AT bnl DOT gov)

Patches are welcome.

=head1 AUTHOR

Bruce Ravel (bravel AT bnl DOT gov)

L<http://cars9.uchicago.edu/~ravel/software/>

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2008 Bruce Ravel (bravel AT bnl DOT gov). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
