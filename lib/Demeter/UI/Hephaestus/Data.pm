package Demeter::UI::Hephaestus::Data;

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
use Chemistry::Elements qw(get_Z get_name get_symbol);

use Wx qw( :everything );
use base 'Wx::Panel';
use Wx::Event qw(EVT_LIST_ITEM_ACTIVATED EVT_LIST_ITEM_SELECTED);

use Demeter::UI::Wx::PeriodicTable;

my %kalzium;
tie %kalzium, 'Config::IniFiles', (-file=>File::Spec->catfile($Demeter::UI::Hephaestus::hephaestus_base,
							      'Hephaestus', 'data', "kalziumrc.dem"));

sub new {
  my ($class, $page, $echoarea) = @_;
  my $self = $class->SUPER::new($page, -1, wxDefaultPosition, wxDefaultSize, wxMAXIMIZE_BOX );
  $self->{echo} = $echoarea;

  my $pt = Demeter::UI::Wx::PeriodicTable->new($self, 'data_get_data');
  my $vbox = Wx::BoxSizer->new( wxVERTICAL );
  $self->SetSizer($vbox);
  $vbox -> Add($pt, 0, wxALIGN_CENTER_HORIZONTAL|wxALL, 5);

  $vbox -> Add( 20, 10, 0, wxGROW );

  ## horizontal box for containing the tables of element data
  my $hbox = Wx::BoxSizer->new( wxHORIZONTAL );
  ## -------- Element data
  $self->{databox} = Wx::StaticBox->new($self, -1, 'Element data', wxDefaultPosition, wxDefaultSize);
  $self->{databoxsizer} = Wx::StaticBoxSizer->new( $self->{databox}, wxVERTICAL );
  $self->{data} = Wx::ListCtrl->new($self, -1, wxDefaultPosition, [620,-1], wxLC_REPORT);
  $self->{data}->InsertColumn( 0, "Physical Properties", wxLIST_FORMAT_LEFT, 140 );
  $self->{data}->InsertColumn( 1, "Value", wxLIST_FORMAT_LEFT, 160);
  $self->{data}->InsertColumn( 2, "Chemical Properties", wxLIST_FORMAT_LEFT, 140 );
  $self->{data}->InsertColumn( 3, "Value", wxLIST_FORMAT_LEFT, 160 );
  $self->{data}->InsertColumn( 2, "Chemical Properties", wxLIST_FORMAT_LEFT, 140 );
  $self->{data}->InsertColumn( 3, "Value", wxLIST_FORMAT_LEFT, 160 );
  my $i = 0;
  foreach my $row ('Name', 'Number', 'Symbol', 'Atomic Weight',
		   'Atomic Radius', 'Mossbauer', q{}) {
    my $idx = $self->{data}->InsertImageStringItem($i, $row, 0);
    $self->{data}->SetItemData($idx, $i++);
    $self->{data}->SetItem( $idx, 1, q{} );
    ##$self->{data}->SetItemFont( $idx, Wx::Font->new( 10, wxDEFAULT, wxNORMAL, wxBOLD, 0, "" ) );
  };
  $i = 0;
  foreach my $row ('Orbital Configuration', 'Oxidation State',
		   'Melting Point', 'Boiling Point',
		   'Electronegativity', 'Ionization Energy',
		   '2nd Ion. Energy') {
    $self->{data}->SetItem( $i, 2, $row );
    $self->{data}->SetItem( $i++, 3, q{} );
    ##$self->{data}->SetItemFont( $idx, Wx::Font->new( 10, wxDEFAULT, wxNORMAL, wxBOLD, 0, "" ) );
  };

  $self->{databoxsizer} -> Add($self->{data}, 1, wxEXPAND|wxALL, 0);
  $hbox -> Add($self->{databoxsizer}, 1, wxEXPAND|wxALL, 5);
  EVT_LIST_ITEM_SELECTED($self->{data}, $self->{data}, sub{unselect_data(@_, $self)});

  ## finish up
  $vbox -> Add($hbox, 1, wxALIGN_CENTER_HORIZONTAL|wxALL);
  $self -> SetSizerAndFit( $vbox );

  return $self;
};

sub data_get_data {
  my ($self, $el) = @_;
  my $z = get_Z($el);
  foreach ( 0 .. $self->{data}->GetItemCount - 1 ) {
    $self->{data}->SetItemState( $_, 0, wxLIST_STATE_SELECTED );
  };
  $self->{data}->SetItem(0, 1, get_name($el));
  $self->{data}->SetItem(1, 1, $z);
  $self->{data}->SetItem(2, 1, get_symbol($el));
  $self->{data}->SetItem(3, 1, sprintf("%.3f amu",$kalzium{$z}{Weight}));
  my $radius = ($kalzium{$z}{AR}) ? sprintf("%.3f Å",$kalzium{$z}{AR}/100) : q{};
  $self->{data}->SetItem(4, 1, $radius);
  $self->{data}->SetItem(5, 1, $kalzium{$z}{Mossbauer} || q{});

  $self->{data}->SetItem(0, 3, $kalzium{$z}{Orbits} || q{});
  my $ox = ($kalzium{$z}{Ox} eq 'k.A.') ? q{} : $kalzium{$z}{Ox};
  $self->{data}->SetItem(1, 3, $ox);
  my $mp = ($kalzium{$z}{MP}) ? sprintf("%s K", $kalzium{$z}{MP}) : q{};
  $self->{data}->SetItem(2, 3, $mp);
  my $bp = ($kalzium{$z}{BP}) ? sprintf("%s K", $kalzium{$z}{BP}) : q{};
  $self->{data}->SetItem(3, 3, $bp);
  $self->{data}->SetItem(4, 3, $kalzium{$z}{EN});
  my $ie = ($kalzium{$z}{IE}) ? sprintf("%s eV", $kalzium{$z}{IE}) : q{};
  $self->{data}->SetItem(5, 3, $ie);
  my $second = ($kalzium{$z}{IE2}) ? sprintf("%s eV", $kalzium{$z}{IE2}) : q{};
  $self->{data}->SetItem(6, 3, $second);
};

sub unselect_data {
  my ($self, $event, $parent) = @_;
  foreach ( 0 .. $parent->{data}->GetItemCount - 1 ) {
    $parent->{data}->SetItemState( $_, 0, wxLIST_STATE_SELECTED );
  };
};

1;

=head1 NAME

Demeter::UI::Hephaestus::Data - Hephaestus' data utility

=head1 VERSION

This documentation refers to Demeter version 0.3.

=head1 SYNOPSIS

The contents of Hephaestus' data utility can be added to any Wx
application.

  my $page = Demeter::UI::Hephaestus::Data->new($parent,$statusbar);
  $sizer -> Add($page, 1, wxGROW|wxEXPAND|wxALL, 0);

The arguments to the constructor method are a reference to the parent
in which this is placed and a reference to a mechanism for displaying
progress and warning messages.  C<$statusbar> is the StatusBar of the
parent window.

C<$page> contains most of what is displayed in the main part of the
Hephaestus frame.  Only the label at the top is not included in
C<$page>.

=head1 DESCRIPTION

This utility uses a periodic table as the interface to chemical and
physcial data of the elements.  Clicking on an element in the periodic
table will display that element's data.

=head1 CONFIGURATION


=head1 DEPENDENCIES

Demeter's dependencies are in the F<Bundle/DemeterBundle.pm> file.

=head1 BUGS AND LIMITATIONS

=over 4

=item *

Size of the ListView widget is not chosen optimally.

=item *

More kinds of data should be included.

=back

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
