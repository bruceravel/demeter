package Demeter::UI::Wx::PeriodicTable;

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

use strict;
use warnings;
use Carp;
use Wx qw( :everything );
use Wx::Event qw(EVT_BUTTON);

use base 'Wx::Panel';

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
		m => [ 82, 139, 139],	# metal (Dark Slate Grey)
		g => [205,   0,   0],	# gas (Red)
		s => [ 85,  26, 139],	# semi-metal (Purple)
		n => [  0, 139,   0],	# non-metal (Green)
	       );

sub new {
  my ($class, $parent, $command, $grandparent) = @_;
  my $self = $class->SUPER::new($parent, -1, wxDefaultPosition, wxDefaultSize, wxMAXIMIZE_BOX );


  my $font_size = 10;
  my $bheight = int(2.5*$font_size+1);
  my $tsz = Wx::GridBagSizer->new( 2, 2 );

  foreach my $el (@elements) {
    my $this = Wx::GBPosition->new($el->[1], $el->[2]);
    my $button = Wx::Button->new( $self, -1, $el->[0], [-1,-1], [35,$bheight], wxBU_EXACTFIT );
    $self->{$el->[0]} = $button;
    my $cell = $tsz -> Add($button, $this);
    my $which = $grandparent || $parent;
    EVT_BUTTON( $parent, $button, sub{$which->$command($el->[0])} );
    $button->SetForegroundColour( Wx::Colour->new(@{ $color_of{$el->[3]} }) );
    $button->SetFont( Wx::Font->new( $font_size, wxDEFAULT, wxNORMAL, wxBOLD, 0, "" ) );
  };
  my $label    = Wx::StaticText->new($self, -1, 'Lanthanides', [5,-1], [105,23], wxALIGN_RIGHT);
  $label      -> SetFont( Wx::Font->new( 10, wxDEFAULT, wxSLANT, wxNORMAL, 0, "" ) );
  my $position = Wx::GBPosition->new(7,0);
  my $span     = Wx::GBSpan->new(1,3);
  $tsz        -> Add($label, $position, $span);
  $label       = Wx::StaticText->new($self, -1, 'Actinides', wxDefaultPosition, [105,23], wxALIGN_RIGHT);
  $label      -> SetFont( Wx::Font->new( 10, wxDEFAULT, wxSLANT, wxNORMAL, 0, "" ) );
  $position    = Wx::GBPosition->new(8,0);
  $span        = Wx::GBSpan->new(1,3);
  $tsz        -> Add($label, $position, $span);

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

This documentation refers to Demeter version 0.3.

=head1 SYNOPSIS

A periodic table an be added to a Wx application:

  my $pt = Demeter::UI::Wx::PeriodicTable
             -> new($parent, 'method_name', $grandparent);
  $sizer -> Add($pt, 0, wxALIGN_CENTER_HORIZONTAL|wxALL, 5);

The arguments to the constructor method is a reference to the parent
in which this is placed, the name (as a string) of a method to bind
as a callback to the buttons in the table, and (optionally) the parent
of the parent.  If the grandparent is defined, the periodic table will
be packed in it, otherwise it will be packed in the $parent.  The
grandparent is used in Hephaestus when the periodic table is displayed
as a pop-up window.

The callback will be called as

  $parent->$method_name($element_selected);

That is, the element of the button pushed will be passed as the
argument of the callback.  This is a very simple mechanism that
assumes the callback method only needs the element symbol.  Any other
information needed by the callback must be in C<$parent>.

=head1 DESCRIPTION

This is a periodic table widget which can be put in a widget or used
as an element picker.  It is used by the absorption, data, and
anomalous scattering utilities as well as by the formulas utilities as
a pop-up.

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

Copyright (c) 2006-2009 Bruce Ravel (bravel AT bnl DOT gov). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
 
