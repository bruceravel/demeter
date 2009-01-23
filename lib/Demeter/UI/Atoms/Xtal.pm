package  Demeter::UI::Atoms::Xtal;

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

use Chemistry::Elements qw(get_Z get_name get_symbol);
use Xray::Absorption;
use Demeter::UI::Wx::PeriodicTable;

use Wx qw( :everything );
use base 'Wx::Panel';
use Wx::Event qw(EVT_BUTTON  EVT_KEY_DOWN);


sub new {
  my ($class, $page, $echoarea) = @_;
  my $self = $class->SUPER::new($page, -1, wxDefaultPosition, wxDefaultSize, wxMAXIMIZE_BOX );
  $self->{echo} = $echoarea;
  my $vbox = Wx::BoxSizer->new( wxVERTICAL );

  my $hbox = Wx::BoxSizer->new( wxHORIZONTAL );
  $self->{titlesbox}       = Wx::StaticBox->new($self, -1, 'Titles', wxDefaultPosition, wxDefaultSize);
  $self->{titlesboxsizer}  = Wx::StaticBoxSizer->new( $self->{titlesbox}, wxVERTICAL );
  $self->{titles}          = Wx::TextCtrl->new($self, -1, q{}, wxDefaultPosition, wxDefaultSize, wxTE_MULTILINE|wxHSCROLL);
  $self->{titlesboxsizer} -> Add($self->{titles}, 1, wxGROW|wxALL, 0);
  $hbox -> Add($self->{titlesboxsizer}, 1, wxGROW|wxALL, 5);
  $vbox -> Add($hbox, 1, wxGROW|wxALL);




  ## -------- lattice constant controls
  $hbox = Wx::BoxSizer->new( wxHORIZONTAL );
  $self->{latticebox}       = Wx::StaticBox->new($self, -1, 'Lattice Constants', wxDefaultPosition, wxDefaultSize);
  $self->{latticeboxsizer}  = Wx::StaticBoxSizer->new( $self->{latticebox}, wxVERTICAL );

  my $tsz = Wx::GridBagSizer->new( 6, 10 );

  my $width = 10;

  my $label = Wx::StaticText->new($self, -1, 'A', wxDefaultPosition, [$width,-1]);
  $tsz -> Add($label,Wx::GBPosition->new(0,0));
  $self->{a} = Wx::TextCtrl->new($self, -1, q{}, wxDefaultPosition, [$width*7,-1]);
  $tsz -> Add($self->{a},Wx::GBPosition->new(0,1));

  $label = Wx::StaticText->new($self, -1, 'B', wxDefaultPosition, [$width,-1]);
  $tsz -> Add($label,Wx::GBPosition->new(1,0));
  $self->{b} = Wx::TextCtrl->new($self, -1, q{}, wxDefaultPosition, [$width*7,-1]);
  $tsz -> Add($self->{b},Wx::GBPosition->new(1,1));

  $label = Wx::StaticText->new($self, -1, 'C', wxDefaultPosition, [$width,-1]);
  $tsz -> Add($label,Wx::GBPosition->new(2,0));
  $self->{c} = Wx::TextCtrl->new($self, -1, q{}, wxDefaultPosition, [$width*7,-1]);
  $tsz -> Add($self->{c},Wx::GBPosition->new(2,1));

  $label = Wx::StaticText->new($self, -1, 'α', wxDefaultPosition, [$width,-1]);
  $tsz -> Add($label,Wx::GBPosition->new(0,2));
  $self->{alpha} = Wx::TextCtrl->new($self, -1, q{}, wxDefaultPosition, [$width*7,-1]);
  $tsz -> Add($self->{alpha},Wx::GBPosition->new(0,3));

  $label = Wx::StaticText->new($self, -1, 'β', wxDefaultPosition, [$width,-1]);
  $tsz -> Add($label,Wx::GBPosition->new(1,2));
  $self->{beta} = Wx::TextCtrl->new($self, -1, q{}, wxDefaultPosition, [$width*7,-1]);
  $tsz -> Add($self->{beta},Wx::GBPosition->new(1,3));

  $label = Wx::StaticText->new($self, -1, 'γ', wxDefaultPosition, [$width,-1]);
  $tsz -> Add($label,Wx::GBPosition->new(2,2));
  $self->{gamma} = Wx::TextCtrl->new($self, -1, q{}, wxDefaultPosition, [$width*7,-1]);
  $tsz -> Add($self->{gamma},Wx::GBPosition->new(2,3));

  $self->{latticeboxsizer} -> Add($tsz, 0, wxEXPAND|wxALL, 5);
  $hbox -> Add($self->{latticeboxsizer}, 0, wxALIGN_CENTER_HORIZONTAL|wxALL, 5);
  $vbox -> Add($hbox, 0, wxGROW|wxALL);
  ## -------- end of lattice constant controls

  my $sidebox = Wx::BoxSizer->new( wxVERTICAL );
  $hbox -> Add($sidebox, 0, wxGROW|wxALL);

  $hbox = Wx::BoxSizer->new( wxHORIZONTAL );
  $sidebox -> Add($hbox, 0, wxEXPAND|wxALL, 5);
  $label = Wx::StaticText->new($self, -1, 'Edge', wxDefaultPosition, [-1,-1]);
  $hbox->Add($label, 0, wxEXPAND|wxALL, 5);
  $self->{edge} = Wx::Choice->new( $self, -1, [-1, -1], [-1, -1], ['K', 'L1', 'L2', 'L3'], );
  $hbox->Add($self->{edge}, 0, wxEXPAND|wxALL, 5);


  ## -------- R constant controls
  $self->{Rbox}       = Wx::StaticBox->new($self, -1, 'Radial distances', wxDefaultPosition, wxDefaultSize);
  $self->{Rboxsizer}  = Wx::StaticBoxSizer->new( $self->{Rbox}, wxVERTICAL );

  $tsz = Wx::GridBagSizer->new( 6, 10 );

  $width = 60;

  $label = Wx::StaticText->new($self, -1, 'Cluster size', wxDefaultPosition, [-1,-1]);
  $tsz -> Add($label,Wx::GBPosition->new(0,0));
  $self->{rmax} = Wx::TextCtrl->new($self, -1, 8.0, wxDefaultPosition, [$width,-1]);
  $tsz -> Add($self->{rmax},Wx::GBPosition->new(0,1));

  $label = Wx::StaticText->new($self, -1, 'Longest path', wxDefaultPosition, [-1,-1]);
  $tsz -> Add($label,Wx::GBPosition->new(0,2));
  $self->{rpath} = Wx::TextCtrl->new($self, -1, 5.0, wxDefaultPosition, [$width,-1]);
  $tsz -> Add($self->{rpath},Wx::GBPosition->new(0,3));

  $self->{Rboxsizer} -> Add($tsz, 0, wxEXPAND|wxALL, 5);
  $sidebox -> Add($self->{Rboxsizer}, 0, wxEXPAND|wxALL, 5);
  ## -------- end of R constant controls


  ## -------- shift constant controls
  $self->{shiftbox}       = Wx::StaticBox->new($self, -1, 'Shift vector', wxDefaultPosition, wxDefaultSize);
  $self->{shiftboxsizer}  = Wx::StaticBoxSizer->new( $self->{shiftbox}, wxVERTICAL );

  $tsz = Wx::GridBagSizer->new( 6, 10 );

  $width = 70;

  $label = Wx::StaticText->new($self, -1, 'Shift', wxDefaultPosition, [-1,-1]);
  $tsz -> Add($label,Wx::GBPosition->new(0,0));
  $self->{shift_x} = Wx::TextCtrl->new($self, -1, 0, wxDefaultPosition, [$width,-1]);
  $tsz -> Add($self->{shift_x},Wx::GBPosition->new(0,1));
  $self->{shift_y} = Wx::TextCtrl->new($self, -1, 0, wxDefaultPosition, [$width,-1]);
  $tsz -> Add($self->{shift_y},Wx::GBPosition->new(0,2));
  $self->{shift_z} = Wx::TextCtrl->new($self, -1, 0, wxDefaultPosition, [$width,-1]);
  $tsz -> Add($self->{shift_z},Wx::GBPosition->new(0,3));

  $self->{shiftboxsizer} -> Add($tsz, 0, wxEXPAND|wxALL, 5);
  $sidebox -> Add($self->{shiftboxsizer}, 0, wxEXPAND|wxALL, 5);
  ## -------- end of R constant controls



  $hbox = Wx::BoxSizer->new( wxHORIZONTAL );
  $self->{sitesbox}       = Wx::StaticBox->new($self, -1, 'Sites', wxDefaultPosition, wxDefaultSize);
  $self->{sitesboxsizer}  = Wx::StaticBoxSizer->new( $self->{sitesbox}, wxVERTICAL );
  foreach my $i (1..5) {
    $self->AddSite($i);
  };
  $hbox -> Add($self->{sitesboxsizer}, 1, wxGROW|wxALL, 5);
  $vbox -> Add($hbox, 2, wxGROW|wxALL);



  $self -> SetSizerAndFit( $vbox );
  return $self;
};

sub AddSite {
  my ($self, $i) = @_;
  my $width = 70;
  my $this = 'box'.$i;
  $self->{$this} = Wx::BoxSizer->new( wxHORIZONTAL );
  $self->{sitesboxsizer} -> Add($self->{$this}, 0, wxGROW|wxALL, 0);

  $self->{"radio$i"} = ($i == 1) ? Wx::RadioButton->new($self, -1, $i, wxDefaultPosition, wxDefaultSize, wxRB_GROUP)
    : Wx::RadioButton->new($self, -1, $i, wxDefaultPosition, wxDefaultSize);
  $self->{$this} -> Add($self->{"radio$i"}, 0, wxALL, 3);

  $self->{"element$i"} = Wx::TextCtrl->new($self, -1, q{El}, wxDefaultPosition, [30,-1]);
  $self->{$this} -> Add($self->{"element$i"}, 0, wxALL, 3);

  $self->{"x$i"} = Wx::TextCtrl->new($self, -1, q{x}, wxDefaultPosition, [$width,-1]);
  $self->{$this} -> Add($self->{"x$i"}, 0, wxALL, 3);

  $self->{"y$i"} = Wx::TextCtrl->new($self, -1, q{y}, wxDefaultPosition, [$width,-1]);
  $self->{$this} -> Add($self->{"y$i"}, 0, wxALL, 3);

  $self->{"z$i"} = Wx::TextCtrl->new($self, -1, q{z}, wxDefaultPosition, [$width,-1]);
  $self->{$this} -> Add($self->{"z$i"}, 0, wxALL, 3);

  $self->{"tag$i"} = Wx::TextCtrl->new($self, -1, q{tag}, wxDefaultPosition, [$width,-1]);
  $self->{$this} -> Add($self->{"tag$i"}, 0, wxALL, 3);

  return $self;
};

1;
