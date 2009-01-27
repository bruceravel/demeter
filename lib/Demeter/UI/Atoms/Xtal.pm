package  Demeter::UI::Atoms::Xtal::SiteList;

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

use Wx qw( :everything );
use base qw(Wx::Grid);

sub new {
  my $class = shift;
  my $this = $class->SUPER::new($_[0], -1, wxDefaultPosition, wxDefaultSize, wxVSCROLL|wxALWAYS_SHOW_SB);

  $this -> CreateGrid(10,6);
  #$this -> EnableScrolling(1,1);
  #$this -> SetScrollbars(20, 20, 50, 50);

  $this -> SetColLabelValue(0, 'Core');
  $this -> SetColSize      (0,  40);
  $this -> SetColLabelValue(1, 'El.');
  $this -> SetColSize      (1,  40);
  $this -> SetColLabelValue(2, 'x');
  $this -> SetColSize      (2,  90);
  $this -> SetColLabelValue(3, 'y');
  $this -> SetColSize      (3,  90);
  $this -> SetColLabelValue(4, 'z');
  $this -> SetColSize      (4,  90);
  $this -> SetColLabelValue(5, 'Tag');
  $this -> SetColSize      (5,  50);
  #$this -> SetColLabelValue(6,  q{});
  #$this -> SetColSize      (6,  20);

  foreach (0 .. $this->GetNumberRows) {
    $this->AutoSizeRow($_, 1);
    $this->SetReadOnly( $_, 6, 1 );
  };

  return $this;
};


package  Demeter::UI::Atoms::Xtal;


use Chemistry::Elements qw(get_Z get_name get_symbol);
use Xray::Absorption;
#use Demeter::UI::Wx::GridTable;

use Wx qw( :everything );
use base 'Wx::Panel';
use Wx::Grid;
use Wx::Event qw(EVT_BUTTON  EVT_KEY_DOWN EVT_TOOL_ENTER EVT_ENTER_WINDOW EVT_LEAVE_WINDOW);

my %hints = (
	     titles  => "Text describing this structure which also be used as title lines in the Feff calculation",
	     a	     => "The value of the A lattice constant in Ångstroms",
	     b	     => "The value of the B lattice constant in Ångstroms",
	     c	     => "The value of the C lattice constant in Ångstroms",
	     alpha   => "The value of the alpha lattice angle (between B and C) in degrees",
	     beta    => "The value of the beta lattice angle (between A and C) in degrees",
	     gamma   => "The value of the gamma lattice angle (between A and B) in degrees",
	     rmax    => "The size of the cluster of atoms in Ångstroms",
	     rpath   => "The maximum path length in Feff's path expansion, in Ångstroms",
	     shift_x => "The x-coordinate of the vector for recentering this crystal",
	     shift_y => "The y-coordinate of the vector for recentering this crystal",
	     shift_z => "The z-coordinate of the vector for recentering this crystal",
	     edge    => "The absorption edge to use in the Feff calculation",

	     open    => "Open an Atoms input file or a CIF file",
	     save    => "Save an atoms input file from these crystallographic data",
	     exec    => "Generate input data for Feff from these crystallographic data",
	     add     => "Add another site to the list of sites",

	     radio   => "Select this site as the absorbing atom in the Feff calculation",
	     element => "The element occupying this unique crystallographic site",
	     x       => "The x-coordinate of this unique crystallographic site",
	     y       => "The x-coordinate of this unique crystallographic site",
	     z       => "The x-coordinate of this unique crystallographic site",
	     tag     => "A short string identifying this unique crystallographic site",
	     del     => "Click this button to remove this crystallographic site",
	    );

sub new {
  my ($class, $page, $statusbar) = @_;
  my $self = $class->SUPER::new($page, -1, wxDefaultPosition, wxDefaultSize, wxMAXIMIZE_BOX );
  $self->{statusbar} = $statusbar;
  my $vbox = Wx::BoxSizer->new( wxVERTICAL );

  my $hbox = Wx::BoxSizer->new( wxHORIZONTAL );
  $self->{titlesbox}       = Wx::StaticBox->new($self, -1, 'Titles', wxDefaultPosition, wxDefaultSize);
  $self->{titlesboxsizer}  = Wx::StaticBoxSizer->new( $self->{titlesbox}, wxVERTICAL );
  $self->{titles}          = Wx::TextCtrl->new($self, -1, q{}, wxDefaultPosition, wxDefaultSize, wxTE_MULTILINE|wxHSCROLL);
  $self->set_hint("titles");
  $self->{titlesboxsizer} -> Add($self->{titles}, 1, wxGROW|wxALL, 0);
  $hbox -> Add($self->{titlesboxsizer}, 1, wxGROW|wxALL, 5);
  $vbox -> Add($hbox, 0, wxGROW|wxALL);




  $hbox = Wx::BoxSizer->new( wxHORIZONTAL );
  my $buttonbox = Wx::BoxSizer->new( wxVERTICAL );
  $hbox -> Add($buttonbox, 1, wxGROW|wxALL, 10);

  $self->{toolbar} = Wx::ToolBar->new($self, -1, wxDefaultPosition, wxDefaultSize, wxTB_VERTICAL|wxTB_3DBUTTONS|wxTB_TEXT);
  $self->{toolbar} -> AddTool(-1, "Open file",  $self->icon("open"), wxNullBitmap, wxITEM_NORMAL, q{}, $hints{open});
  $self->{toolbar} -> AddTool(-1, "Save data",  $self->icon("save"), wxNullBitmap, wxITEM_NORMAL, q{}, $hints{save});
  $self->{toolbar} -> AddTool(-1, "Run Atoms",  $self->icon("exec"), wxNullBitmap, wxITEM_NORMAL, q{}, $hints{exec});
  $self->{toolbar} -> AddTool(-1, "Add a site", $self->icon("add"),  wxNullBitmap, wxITEM_NORMAL, q{}, $hints{add} );
  EVT_TOOL_ENTER( $self, $self->{toolbar}, \&OnToolEnter );

  $self->{toolbar} -> Realize;
  $buttonbox -> Add($self->{toolbar}, 0, wxALL, 5);

  my $sidebox = Wx::BoxSizer->new( wxVERTICAL );
  $hbox -> Add($sidebox, 3, wxGROW|wxALL);

  ## -------- lattice constant controls
  $self->{latticebox}       = Wx::StaticBox->new($self, -1, 'Lattice Constants', wxDefaultPosition, wxDefaultSize);
  $self->{latticeboxsizer}  = Wx::StaticBoxSizer->new( $self->{latticebox}, wxVERTICAL );
  my $tsz = Wx::GridBagSizer->new( 6, 10 );

  my $width = 10;

  my $label = Wx::StaticText->new($self, -1, 'A', wxDefaultPosition, [$width,-1]);
  $self->{a} = Wx::TextCtrl->new($self, -1, q{}, wxDefaultPosition, [$width*7,-1]);
  $tsz -> Add($label,    Wx::GBPosition->new(0,0));
  $tsz -> Add($self->{a},Wx::GBPosition->new(0,1));

  $label = Wx::StaticText->new($self, -1, 'B', wxDefaultPosition, [$width,-1]);
  $self->{b} = Wx::TextCtrl->new($self, -1, q{}, wxDefaultPosition, [$width*7,-1]);
  $tsz -> Add($label,    Wx::GBPosition->new(0,2));
  $tsz -> Add($self->{b},Wx::GBPosition->new(0,3));

  $label     = Wx::StaticText->new($self, -1, 'C', wxDefaultPosition, [$width,-1]);
  $self->{c} = Wx::TextCtrl->new($self, -1, q{}, wxDefaultPosition, [$width*7,-1]);
  $tsz -> Add($label,    Wx::GBPosition->new(0,4));
  $tsz -> Add($self->{c},Wx::GBPosition->new(0,5));

  $label         = Wx::StaticText->new($self, -1, 'α', wxDefaultPosition, [$width,-1]);
  $self->{alpha} = Wx::TextCtrl  ->new($self, -1, q{}, wxDefaultPosition, [$width*7,-1]);
  $tsz -> Add($label,        Wx::GBPosition->new(1,0));
  $tsz -> Add($self->{alpha},Wx::GBPosition->new(1,1));

  $label        = Wx::StaticText->new($self, -1, 'β', wxDefaultPosition, [$width,-1]);
  $self->{beta} = Wx::TextCtrl  ->new($self, -1, q{}, wxDefaultPosition, [$width*7,-1]);
  $tsz -> Add($label,        Wx::GBPosition->new(1,2));
  $tsz -> Add($self->{beta}, Wx::GBPosition->new(1,3));

  $label         = Wx::StaticText->new($self, -1, 'γ', wxDefaultPosition, [$width,-1]);
  $self->{gamma} = Wx::TextCtrl  ->new($self, -1, q{}, wxDefaultPosition, [$width*7,-1]);
  $tsz -> Add($label,        Wx::GBPosition->new(1,4));
  $tsz -> Add($self->{gamma},Wx::GBPosition->new(1,5));

  $self->{latticeboxsizer} -> Add($tsz, 0, wxEXPAND|wxALL, 5);
  $sidebox -> Add($self->{latticeboxsizer}, 0, wxGROW|wxALL, 5);
  $vbox -> Add($hbox, 0, wxGROW|wxALL);
  ## -------- end of lattice constant controls

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

  $self->set_hint($_) foreach (qw(a b c alpha beta gamma rmax rpath shift_x shift_y shift_z edge));


  $hbox = Wx::BoxSizer->new( wxHORIZONTAL );
  $self->{sitesgrid} = Demeter::UI::Atoms::Xtal::SiteList->new($self, -1);

  $hbox -> Add($self->{sitesgrid}, 1, wxGROW|wxALL, 5);
  $vbox -> Add($hbox, 1, wxGROW|wxALL, 5);

  $self -> SetSizer( $vbox );
  return $self;
};

sub icon {
  my ($self, $which) = @_;
  my $icon = File::Spec->catfile($Demeter::UI::Atoms::atoms_base, 'Atoms', 'icons', "$which.png");
  return wxNullBitmap if (not -e $icon);
  return Wx::Bitmap->new($icon, wxBITMAP_TYPE_ANY)
};

sub set_hint {
  my ($self, $w) = @_;
  (my $ww = $w) =~ s{\d+\z}{};
  EVT_ENTER_WINDOW($self->{$w}, sub{my($widg, $event) = @_; 
				    $self->OnTextCtrlEnter($widg, $event, $hints{$ww}||q{No hint!})});
  EVT_LEAVE_WINDOW($self->{$w}, sub{$self->OnTextCtrlLeave});
};

sub OnToolEnter {
  my ($self, $event) = @_;
  if ( $event->GetSelection > -1 ) {
    $self->{statusbar}->PushStatusText($self->{toolbar}->GetToolLongHelp($event->GetSelection));
  } else {
    $self->{statusbar}->PopStatusText();
  };
};
sub OnTextCtrlEnter {
  my ($self, $widget, $event, $hint) = @_;
  $self->{statusbar}->PushStatusText($hint);
};
sub OnTextCtrlLeave {
  my ($self) = @_;
  $self->{statusbar}->PopStatusText();
};


1;
