package Demeter::UI::Wx::PeriodicTable;

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
use Chemistry::Elements qw(get_Z get_name);
use Wx qw( :everything );
use Wx::Event qw(EVT_BUTTON EVT_ENTER_WINDOW EVT_LEAVE_WINDOW);

use base 'Wx::Panel';

use constant {
  ELEMENT => 0,
  ROW     => 1,
  COL     => 2,
  PHASE   => 3,
};

#           columns: 0 -- 17    rows: 0 -- 8
#           [ symbol, row, column, phase]
my @elements = (['H',  0, 0,  'g'],
		['He', 0, 17, 'g'],
		['Li', 1, 0,  'm'],
		['Be', 1, 1,  'm'],
		['B',  1, 12, 's'],
		['C',  1, 13, 'n'],
		['N',  1, 14, 'n'],
		['O',  1, 15, 'n'],
		['F',  1, 16, 'n'],
		['Ne', 1, 17, 'g'],
		['Na', 2, 0,  'm'],
		['Mg', 2, 1,  'm'],
		['Al', 2, 12, 'm'],
		['Si', 2, 13, 's'],
		['P',  2, 14, 'n'],
		['S',  2, 15, 'n'],
		['Cl', 2, 16, 'n'],
		['Ar', 2, 17, 'g'],
		['K',  3, 0,  'm'],
		['Ca', 3, 1,  'm'],
		['Sc', 3, 2,  'm'],
		['Ti', 3, 3,  'm'],
		['V',  3, 4,  'm'],
		['Cr', 3, 5,  'm'],
		['Mn', 3, 6,  'm'],
		['Fe', 3, 7,  'm'],
		['Co', 3, 8,  'm'],
		['Ni', 3, 9,  'm'],
		['Cu', 3, 10, 'm'],
		['Zn', 3, 11, 'm'],
		['Ga', 3, 12, 'm'],
		['Ge', 3, 13, 's'],
		['As', 3, 14, 's'],
		['Se', 3, 15, 'n'],
		['Br', 3, 16, 'n'],
		['Kr', 3, 17, 'g'],
		['Rb', 4, 0,  'm'],
		['Sr', 4, 1,  'm'],
		['Y',  4, 2,  'm'],
		['Zr', 4, 3,  'm'],
		['Nb', 4, 4,  'm'],
		['Mo', 4, 5,  'm'],
		['Tc', 4, 6,  'm'],
		['Ru', 4, 7,  'm'],
		['Rh', 4, 8,  'm'],
		['Pd', 4, 9,  'm'],
		['Ag', 4, 10, 'm'],
		['Cd', 4, 11, 'm'],
		['In', 4, 12, 'm'],
		['Sn', 4, 13, 'm'],
		['Sb', 4, 14, 's'],
		['Te', 4, 15, 's'],
		['I',  4, 16, 'n'],
		['Xe', 4, 17, 'g'],
		['Cs', 5, 0,  'm'],
		['Ba', 5, 1,  'm'],
		['La', 5, 2,  'm'],
		['Ce', 7, 3,  'm'],
		['Pr', 7, 4,  'm'],
		['Nd', 7, 5,  'm'],
		['Pm', 7, 6,  'm'],
		['Sm', 7, 7,  'm'],
		['Eu', 7, 8,  'm'],
		['Gd', 7, 9,  'm'],
		['Tb', 7, 10, 'm'],
		['Dy', 7, 11, 'm'],
		['Ho', 7, 12, 'm'],
		['Er', 7, 13, 'm'],
		['Tm', 7, 14, 'm'],
		['Yb', 7, 15, 'm'],
		['Lu', 7, 16, 'm'],
		['Hf', 5, 3,  'm'],
		['Ta', 5, 4,  'm'],
		['W',  5, 5,  'm'],
		['Re', 5, 6,  'm'],
		['Os', 5, 7,  'm'],
		['Ir', 5, 8,  'm'],
		['Pt', 5, 9,  'm'],
		['Au', 5, 10, 'm'],
		['Hg', 5, 11, 'm'],
		['Tl', 5, 12, 'm'],
		['Pb', 5, 13, 'm'],
		['Bi', 5, 14, 'm'],
		['Po', 5, 15, 'm'],
		['At', 5, 16, 's'],
		['Rn', 5, 17, 'g'],
		['Fr', 6, 0,  'm'],
		['Ra', 6, 1,  'm'],
		['Ac', 6, 2,  'm'],
		['Th', 8, 3,  'm'],
		['Pa', 8, 4,  'm'],
		['U',  8, 5,  'm'],
		['Np', 8, 6,  'm'],
		['Pu', 8, 7,  'm'],
		['Am', 8, 8,  'm'],
		['Cm', 8, 9,  'm'],
		['Bk', 8, 10, 'm'],
		['Cf', 8, 11, 'm'],
		['Es', 8, 12, 'm'],
		['Fm', 8, 13, 'm'],
		['Md', 8, 14, 'm'],
		['No', 8, 15, 'm'],
		['Lr', 8, 16, 'm'],
		['Rf', 6, 3,  'm'],
		['Ha', 6, 4,  'm'],
		['Sg', 6, 5,  'm'],
		['Bh', 6, 6,  'm'],
		['Hs', 6, 7,  'm'],
		['Mt', 6, 8,  'm'],
	       );

my %color_of = (
		m => [210, 221, 239, 0],	# metal (powder blue)
		g => [234, 186, 184, 0],	# gas (Red)
		s => [238, 214, 240, 0],	# semi-metal (light purple)
		n => [213, 236, 194, 0],	# non-metal (Green)
	       );

sub new {
  my ($class, $parent, $command, $statusbar) = @_;
  my $self = $class->SUPER::new($parent, -1, wxDefaultPosition, wxDefaultSize, wxMAXIMIZE_BOX );

  my $font_size = 9;
  my $bheight = int(2.5*$font_size+3);
  my $tsz = Wx::GridBagSizer->new( 2, 2 );

  foreach my $el (@elements) {
    my $element = $el->[ELEMENT];
    my $button = Wx::Button->new( $self, -1, $element, [-1,-1], [35,-1], wxBU_EXACTFIT );
    $self->{$element} = $button;
    my $cell = $tsz -> Add($button, Wx::GBPosition->new($el->[ROW], $el->[COL]));
    EVT_BUTTON( $parent, $button, sub{&$command($element)} );
    my $text = sprintf("%s: %s, element #%d", $element, get_name($element), get_Z($element));
    EVT_ENTER_WINDOW($button, sub{$statusbar->PushStatusText($text) if $statusbar; $_[1]->Skip});
    EVT_LEAVE_WINDOW($button, sub{$statusbar->PopStatusText         if $statusbar; $_[1]->Skip});
    $button->SetFont( Wx::Font->new( $font_size, wxDEFAULT, wxNORMAL, wxBOLD, 0, "" ) );
    $button->SetBackgroundColour( Wx::Colour->new(@{ $color_of{$el->[PHASE]} }) );
  };
  my $label = Wx::StaticText->new($self, -1, 'Lanthanides', [5,-1], [105,23], wxALIGN_RIGHT);
  $label   -> SetFont( Wx::Font->new( 10, wxDEFAULT, wxSLANT, wxNORMAL, 0, "" ) );
  $tsz     -> Add($label, Wx::GBPosition->new(7,0), Wx::GBSpan->new(1,3));
  $label    = Wx::StaticText->new($self, -1, 'Actinides', wxDefaultPosition, [105,23], wxALIGN_RIGHT);
  $label   -> SetFont( Wx::Font->new( 10, wxDEFAULT, wxSLANT, wxNORMAL, 0, "" ) );
  $tsz     -> Add($label, Wx::GBPosition->new(8,0), Wx::GBSpan->new(1,3));

  # tell we want automatic layout
  $self->SetAutoLayout( 1 );
  $self->SetSizer( $tsz );
  # size the window optimally and set its minimal size
  $tsz->Fit( $self );
  $tsz->SetSizeHints( $self );

  return $self;
};


1;

=head1 NAME

Demeter::UI::Wx::PeriodicTable - A periodic table widget

=head1 VERSION

This documentation refers to Demeter version 0.9.18.

=head1 SYNOPSIS

A periodic table an be added to a Wx application:

  my $pt = Demeter::UI::Wx::PeriodicTable
             -> new($parent, $command, $sb);
  $sizer -> Add($pt, 0, wxALIGN_CENTER_HORIZONTAL|wxALL, 5);

The arguments to the constructor method is a reference to the parent
in which this is placed, the name (as a string) of a method to bind as
a callback to the buttons in the table, and (optionally) the parent of
the parent.  If the statusbar is defined, it will be used to display
mouse-over messages as the buttons in the table are visited.

The callback will be called as

  $command($element_selected);

That is, the element of the button pushed will be passed as the
argument of the callback.  This is a very simple mechanism that
assumes the callback method only needs the element symbol.

=head1 DESCRIPTION

This is a periodic table widget which can be put in a widget or used
as an element picker.  It is used by the absorption, data, and
anomalous scattering utilities in Hephaestus as well as by the
formulas utility as a pop-up.  It is also used in Artemis in the quick
first shell theory dialog.

=head1 DEPENDENCIES

Demeter's dependencies are in the F<Bundle/DemeterBundle.pm> file.

=head1 BUGS AND LIMITATIONS

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
 
