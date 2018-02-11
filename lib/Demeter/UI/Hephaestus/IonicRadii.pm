package Demeter::UI::Hephaestus::IonicRadii;

=for Copyright
 .
 Copyright (c) 2006-2018 Bruce Ravel (http://bruceravel.github.io/home).
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
use Cwd;
use JSON qw(decode_json);
use Scalar::Util qw(looks_like_number);

use Wx qw( :everything );
use base 'Wx::Panel';
use Wx::Event qw(EVT_LIST_ITEM_ACTIVATED EVT_LIST_ITEM_SELECTED EVT_LISTBOX
		 EVT_BUTTON EVT_KEY_DOWN EVT_RADIOBOX EVT_FILEPICKER_CHANGED);

use Demeter::UI::Standards;
my $standards = Demeter::UI::Standards->new();
$standards -> ini(q{});

use Demeter::UI::Wx::PeriodicTable;
use Demeter::UI::Wx::SpecialCharacters qw($MU);
#use Demeter::UI::Common::ShowText;

my $ionic_radii = decode_json(Demeter->slurp(File::Spec->catfile($Demeter::UI::Hephaestus::hephaestus_base,
								 'Hephaestus', 'data', "ionic_radii.dem")));


sub new {
  my ($class, $page, $echoarea) = @_;
  my $self = $class->SUPER::new($page, -1, wxDefaultPosition, wxDefaultSize, wxMAXIMIZE_BOX );
  $self->{echo} = $echoarea;

  my $pt = Demeter::UI::Wx::PeriodicTable->new($self, sub{$self->ionicradii_get_data($_[0])}, $echoarea);
  foreach my $i (1 .. 109) {
    my $el = get_symbol($i);
    #$pt->{$el}->Disable if not $standards->element_exists($el);
  };
  $pt->{Mt}->Disable;
  my $vbox = Wx::BoxSizer->new( wxVERTICAL );
  $self->SetSizer($vbox);
  $vbox -> Add($pt, 0, wxALIGN_CENTER_HORIZONTAL|wxALL, 5);

  $vbox -> Add( 20, 10, 0, wxGROW );

  ## horizontal box for containing the rest of the controls
  my $hbox = Wx::BoxSizer->new( wxHORIZONTAL );

  # $self->{databox}       = Wx::StaticBox      -> new($self, -1, 'Standards', wxDefaultPosition, wxDefaultSize);
  # $self->{databoxsizer}  = Wx::StaticBoxSizer -> new( $self->{databox}, wxVERTICAL );
  # $self->{data}          = Wx::ListBox        -> new($self, -1, wxDefaultPosition, wxDefaultSize,
  # 						     [], wxLB_SINGLE|wxLB_ALWAYS_SB);
  # $self->{databoxsizer} -> Add($self->{data}, 1, wxEXPAND|wxALL, 0);
  # $hbox -> Add($self->{databoxsizer}, 2, wxEXPAND|wxALL, 5);
  # EVT_LISTBOX( $self, $self->{data}, sub{echo_comment(@_, $self)} );

  my $controlbox = Wx::BoxSizer->new( wxVERTICAL );
  $hbox -> Add($controlbox, 1, wxEXPAND|wxALL, 5);

  $self->{radii} = Wx::ListView->new($self, -1, wxDefaultPosition, wxDefaultSize, wxLC_REPORT|wxLC_HRULES|wxLC_SINGLE_SEL);
  $self->{radii}->InsertColumn( 0, "Ionization", wxLIST_FORMAT_LEFT, 90 );
  $self->{radii}->InsertColumn( 1, "Configuration", wxLIST_FORMAT_LEFT, 100 );
  $self->{radii}->InsertColumn( 2, "Coordination #", wxLIST_FORMAT_LEFT, 105 );
  $self->{radii}->InsertColumn( 3, "Spin state", wxLIST_FORMAT_LEFT, 75 );
  $self->{radii}->InsertColumn( 4, "Crystal radius", wxLIST_FORMAT_LEFT, 100 );
  $self->{radii}->InsertColumn( 5, "Ionic radius", wxLIST_FORMAT_LEFT, 100 );
  $self->{radii}->InsertColumn( 6, "Notes", wxLIST_FORMAT_LEFT, 70 );

  # for my $row (0 .. 1) {
  #   my $idx = $self->{radii}->InsertStringItem($row, q());
  #   $self->{radii}->SetItem( $idx, 1, q());
  #   $self->{radii}->SetItem( $idx, 2, q());
  #   $self->{radii}->SetItem( $idx, 3, q());
  #   $self->{radii}->SetItem( $idx, 4, q());
  #   $self->{radii}->SetItem( $idx, 5, q());
  #   $self->{radii}->SetItem( $idx, 6, q());
  # };

  $controlbox -> Add($self->{radii}, 1, wxGROW|wxALL, 5);

#  ION	OX. State	Elec. Config.	Coord. #	Spin State	Crystal Radius	Ionic Radius	NOTES

  my $font_size = Wx::SystemSettings::GetFont(wxSYS_DEFAULT_GUI_FONT)->GetPointSize - 2;
  my $text = Wx::StaticText->new($self, -1, 'Notes and abbreviations:  HS=high spin,  LS=low spin,  R=from r3 vs V plots,  C=calculated,  E=estimated');
  $text -> SetFont(Wx::Font->new( $font_size, wxTELETYPE, wxNORMAL, wxNORMAL, 0, "" ));
  $controlbox -> Add($text, 0, wxGROW|wxLEFT|wxRIGHT, 5);
  $text = Wx::StaticText->new($self, -1, '    ?=doubtful,  *=most reliable,  M=from metallic oxides,  A=Ahrens (1952),  P=Pauling (1960)');
  $text -> SetFont(Wx::Font->new( $font_size, wxTELETYPE, wxNORMAL, wxNORMAL, 0, "" ));
  $controlbox -> Add($text, 0, wxGROW|wxLEFT|wxRIGHT, 5);

  ## finish up
  $vbox -> Add($hbox, 1, wxEXPAND|wxALL);
  $self -> SetSizerAndFit( $vbox );

  return $self;
};

sub ionicradii_get_data {
  my ($self, $el) = @_;
  my $z = get_Z($el);
  my $row = 0;
  $self->{radii}->DeleteAllItems;
  foreach my $this (@$ionic_radii) {
    if ($this->{element} eq $el) {
      my $idx = $self->{radii}->InsertStringItem($row, join(" ", $this->{element}, $this->{ionization}));
      $self->{radii}->SetItem( $idx, 1, $this->{coordination});
      $self->{radii}->SetItem( $idx, 2, $this->{configuration});
      $self->{radii}->SetItem( $idx, 3, $this->{spin});
      $self->{radii}->SetItem( $idx, 4, $this->{crystalradius});
      $self->{radii}->SetItem( $idx, 5, $this->{ionicradius});
      $self->{radii}->SetItem( $idx, 6, $this->{notes});
      ++$row;
    };
  };
  return 1;
};

sub echo_comment {
  my ($self, $event, $parent) = @_;

};

1;
