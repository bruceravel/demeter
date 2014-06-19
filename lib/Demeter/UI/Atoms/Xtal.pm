package  Demeter::UI::Atoms::Xtal::SiteList;

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

use Wx qw( :everything );
use base qw(Wx::Grid);

sub new {
  my $class = shift;
  my $this = $class->SUPER::new($_[0], -1, wxDefaultPosition, wxDefaultSize, wxVSCROLL);

  $this -> CreateGrid(7,6);
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
  $this -> SetColSize      (5,  60);
  #$this -> SetColLabelValue(6,  q{});
  #$this -> SetColSize      (6,  30);

  $this -> SetColFormatBool(0);
  foreach my $i (0 .. $this->GetNumberRows) {
    $this -> SetCellAlignment($i, 0, wxALIGN_CENTRE, wxALIGN_CENTRE);
  };
  $this -> SetRowLabelSize(40);

  return $this;
};


package  Demeter::UI::Atoms::Xtal;

use Demeter::StrTypes qw( Element );
use Demeter::NumTypes qw( PosNum );
use Demeter::Constants qw($FEFFNOTOK);
use Demeter::UI::Wx::VerbDialog;

use Cwd;
use Chemistry::Elements qw(get_Z get_name get_symbol);
use File::Basename;
use File::Copy;
use List::MoreUtils qw(firstidx true);
use Xray::Absorption;
#use Demeter::UI::Wx::GridTable;

use Demeter::Constants qw($NUMBER $EPSILON3);
use Demeter::UI::Wx::Colours;

use Wx qw( :everything );
use base 'Wx::Panel';
use Wx::Grid;
use Wx::Event qw(EVT_CHOICE EVT_KEY_DOWN EVT_MENU EVT_TOOL_ENTER EVT_ENTER_WINDOW
		 EVT_LEAVE_WINDOW EVT_TOOL_RCLICKED EVT_TEXT_ENTER EVT_CHECKBOX EVT_BUTTON
		 EVT_GRID_CELL_LEFT_CLICK EVT_GRID_CELL_RIGHT_CLICK EVT_GRID_LABEL_RIGHT_CLICK);
use Demeter::UI::Wx::MRU;
use Demeter::UI::Wx::SpecialCharacters qw(:all);

my %hints = (
	     titles    => "Text describing this structure which also be used as title lines in the Feff calculation",
	     space     => "The space group symbol (Hermann-Maguin, Schoenflies or number)",
	     a	       => "The value of the A lattice constant in Angstroms",
	     b	       => "The value of the B lattice constant in Angstroms",
	     c	       => "The value of the C lattice constant in Angstroms",
	     alpha     => "The value of the $ALPHA lattice angle (between B and C) in degrees",
	     beta      => "The value of the $BETA lattice angle (between A and C) in degrees",
	     gamma     => "The value of the $GAMMA lattice angle (between A and B) in degrees",
	     rmax      => "The size of the cluster of atoms in Angstroms",
	     rpath     => "The maximum path length in Feff's path expansion, in Angstroms",
	     shift_x   => "The x-coordinate of the vector for recentering this crystal",
	     shift_y   => "The y-coordinate of the vector for recentering this crystal",
	     shift_z   => "The z-coordinate of the vector for recentering this crystal",
	     edge      => "The absorption edge to use in the Feff calculation",
	     template  => "Choose the output file style and the ipot selection style",
	     sitesgrid => "Hit return or tab to finish editing a cell in the sites grid",

	     open      => "Open an Atoms input file or a CIF file -- Hint: Right click for recent files",
	     save      => "Save an atoms input file from these crystallographic data",
	     exec      => "Generate input data for Feff from these crystallographic data",
	     aggregate => "Aggregate Feff calculations over all sites occupied by the same element",
	     doc       => "Show the Atoms documentation in a browser",
	     clear     => "Clear this crystal structure",
	     output    => "Write a feff.inp file or some other format",
	     add       => "Add another entry to the list of sites",

	     radio     => "Select this site as the absorbing atom in the Feff calculation",
	     element   => "The element occupying this unique crystallographic site",
	     x	       => "The x-coordinate of this unique crystallographic site",
	     y	       => "The x-coordinate of this unique crystallographic site",
	     z	       => "The x-coordinate of this unique crystallographic site",
	     tag       => "A short string identifying this unique crystallographic site",
	     del       => "Click this button to remove this crystallographic site",
	    );

my $atoms = Demeter::Atoms->new;


sub new {
  my ($class, $page, $parent) = @_;
  my $self = $class->SUPER::new($page, -1, wxDefaultPosition, wxDefaultSize, wxMAXIMIZE_BOX );
  $self -> SetBackgroundColour( $wxBGC );
  $self->{parent}    = $parent;
  $self->{statusbar} = $parent->{statusbar};
  $self->{buffered_site} = 0;
  $self->{problems}  = q{};
  $self->{used}      = 1;
  $self->{atomsobject} = $atoms;

  my $vbox = Wx::BoxSizer->new( wxVERTICAL );


  $self->{toolbar} = Wx::ToolBar->new($self, -1, wxDefaultPosition, wxDefaultSize, wxTB_HORIZONTAL|wxTB_3DBUTTONS|wxTB_TEXT);
  EVT_MENU( $self->{toolbar}, -1, sub{my ($toolbar, $event) = @_; OnToolClick($toolbar, $event, $self)} );
  $self->{toolbar} -> AddTool(-1, "Open file",  $self->icon("open"),   wxNullBitmap, wxITEM_NORMAL, q{}, $hints{open} );
  $self->{toolbar} -> AddTool(-1, "Save data",  $self->icon("save"),   wxNullBitmap, wxITEM_NORMAL, q{}, $hints{save} );
  $self->{toolbar} -> AddTool(-1, "Export",     $self->icon("output"), wxNullBitmap, wxITEM_NORMAL, q{}, $hints{output});
  $self->{toolbar} -> AddTool(-1, "Clear all",  $self->icon("empty"),  wxNullBitmap, wxITEM_NORMAL, q{}, $hints{clear});
  $self->{toolbar} -> AddSeparator;
  #$self->{toolbar} -> AddTool(-1, "Doc",  $self->icon("document"),   wxNullBitmap, wxITEM_NORMAL, q{}, $hints{doc} );
  #$self->{toolbar} -> AddSeparator;
  $self->{toolbar} -> AddTool(-1, "Run Atoms",  $self->icon("exec"),   wxNullBitmap, wxITEM_NORMAL, q{}, $hints{exec});

  my $agg;
  if ($self->{parent}->{component}) {
    $agg = $self->{toolbar} -> AddTool(-1, "Aggregate",  $self->icon("aggregate"),   wxNullBitmap, wxITEM_NORMAL, q{}, $hints{aggregate} );
  }
  EVT_TOOL_ENTER( $self, $self->{toolbar}, sub{my ($toolbar, $event) = @_; &OnToolEnter($toolbar, $event, 'toolbar')} );
  $self->{toolbar} -> Realize;
  $vbox -> Add($self->{toolbar}, 0, wxGROW|wxLEFT|wxRIGHT, 5);
  EVT_TOOL_RCLICKED($self->{toolbar}, -1, sub{my ($toolbar, $event) = @_; OnToolRightClick($toolbar, $event, $self)});
  if ($self->{parent}->{component}) {
    $self->{aggid} = $agg->GetId;
    $self->{toolbar}->EnableTool($self->{aggid},0);
  };

  my $hbox = Wx::BoxSizer->new( wxHORIZONTAL );
  $self->{titlesbox}       = Wx::StaticBox->new($self, -1, 'Titles', wxDefaultPosition, wxDefaultSize);
  $self->{titlesboxsizer}  = Wx::StaticBoxSizer->new( $self->{titlesbox}, wxVERTICAL );
  $self->{titles}          = Wx::TextCtrl->new($self, -1, q{}, wxDefaultPosition, wxDefaultSize, wxTE_MULTILINE|wxHSCROLL);
  $self->set_hint("titles");
  $self->{titlesboxsizer} -> Add($self->{titles}, 1, wxGROW|wxALL, 0);
  $hbox -> Add($self->{titlesboxsizer}, 1, wxGROW|wxALL, 5);
  $vbox -> Add($hbox, 1, wxGROW|wxALL, 0);




  $hbox = Wx::BoxSizer->new( wxHORIZONTAL );
  my $leftbox = Wx::BoxSizer->new( wxVERTICAL );
  $hbox -> Add($leftbox, 0, wxGROW|wxALL, 5);


  my $sidebox = Wx::BoxSizer->new( wxVERTICAL );
  $hbox -> Add($sidebox, 0, wxGROW|wxALL, 5);

  my $width = 10;


  ## -------- space group and edge controls
  my $spacebox = Wx::BoxSizer->new( wxVERTICAL );
  $leftbox -> Add($spacebox, 0, wxEXPAND|wxLEFT, 3);

  my $hh = Wx::BoxSizer->new( wxHORIZONTAL );
  $spacebox -> Add($hh, 1, wxEXPAND|wxALL, 1);
  my $label      = Wx::StaticText->new($self, -1, 'Name', wxDefaultPosition, [-1,-1]);
  $self->{name}  = Wx::TextCtrl  ->new($self, -1, q{}, wxDefaultPosition, [$width*7,-1], wxTE_PROCESS_ENTER);
  $hh->Add($label,        0, wxEXPAND|wxLEFT|wxRIGHT|wxTOP, 3);
  $hh->Add($self->{name}, 1, wxEXPAND|wxLEFT|wxRIGHT, 5);

  $hh = Wx::BoxSizer->new( wxHORIZONTAL );
  $spacebox -> Add($hh, 1, wxEXPAND|wxALL, 1);
  $label      = Wx::StaticText->new($self, -1, 'Space Group', wxDefaultPosition, [-1,-1]);
  $self->{space} = Wx::TextCtrl  ->new($self, -1, q{}, wxDefaultPosition, [$width*7,-1], wxTE_PROCESS_ENTER);
  $hh->Add($label,        0, wxEXPAND|wxLEFT|wxRIGHT|wxTOP, 3);
  $hh->Add($self->{space}, 1, wxEXPAND|wxLEFT|wxRIGHT, 5);

  $hh = Wx::BoxSizer->new( wxHORIZONTAL );
  $spacebox -> Add($hh, 0, wxEXPAND|wxALL, 1);
  $label        = Wx::StaticText->new($self, -1, 'Edge', wxDefaultPosition, [-1,-1]);
  $self->{edge} = Wx::Choice    ->new($self, -1, [-1, -1], [-1, -1], ['K', 'L1', 'L2', 'L3'], );
  $hh->Add($label,        0, wxEXPAND|wxLEFT|wxRIGHT|wxTOP, 3);
  $hh->Add($self->{edge}, 0, wxEXPAND|wxLEFT|wxRIGHT, 5);
  $self->{edge}->SetSelection(0);
  EVT_CHOICE($self, $self->{edge}, \&OnWidgetLeave);

  #$hh = Wx::BoxSizer->new( wxHORIZONTAL );
  #$spacebox -> Add($hh, 0, wxEXPAND|wxALL, 1);
  $label        = Wx::StaticText->new($self, -1, 'Style', wxDefaultPosition, [-1,-1]);
  $self->{template} = Wx::Choice    ->new($self, -1, [-1, -1], [-1, -1], $self->templates, );
  $hh->Add($label,            0, wxEXPAND|wxLEFT|wxRIGHT|wxTOP, 3);
  $hh->Add($self->{template}, 0, wxEXPAND|wxLEFT|wxRIGHT, 5);
  my $n = 0;
  my ($fv, $is) = (Demeter->co->default('atoms', 'feff_version'), Demeter->co->default('atoms', 'ipot_style'));
  $fv = 6;			# enforce this for now, feff85exafs is coming soon....
  if ($fv == 6) {
    Demeter->mo->template_feff('feff6');
    if ($is == 'elements') {
      $n = 0;
    } elsif ($is == 'tags') {
      $n = 1;
    } elsif ($is == 'sites') {
      $n = 2;
    };
  } else {
    Demeter->mo->template_feff('feff8');
    if ($is == 'elements') {
      $n = 3;
    } elsif ($is == 'tags') {
      $n = 4;
    } elsif ($is == 'sites') {
      $n = 5;
    };
  };
  $self->{template}->SetSelection($n);
  EVT_CHOICE($self, $self->{template}, \&OnTemplate);

  my $which = ($atoms->co->default("atoms", "ipot_style") eq 'elements') ? 'elem' : $atoms->co->default("atoms", "ipot_style");
  my $initial = "Feff" . $atoms->co->default("atoms", "feff_version") . " - " . $which;
  $self->{template}->SetSelection(firstidx {$_ eq $initial } @{ $self->templates });


  $hh = Wx::BoxSizer->new( wxHORIZONTAL ); 
  $spacebox -> Add($hh, 0, wxEXPAND|wxALL, 1);
  $self->{scf} = Wx::CheckBox->new($self, -1, "Self-consistency");
  $hh->Add($self->{scf}, 0, wxRIGHT, 5);
  $self->{scflab} = Wx::StaticText->new($self, -1, "Rscf");
  $hh->Add($self->{scflab}, 0, wxLEFT|wxRIGHT|wxTOP, 3);
  $self->{rscf} = Wx::TextCtrl->new($self, -1, $atoms->rscf, wxDefaultPosition, [$width*6,-1], wxTE_PROCESS_ENTER);
  $hh->Add($self->{rscf}, 0, wxLEFT|wxRIGHT, 5);
  $self->{$_}->Enable(0) foreach qw(scf scflab rscf);
  EVT_CHECKBOX($self, $self->{scf}, \&OnCheckBox);

  if ($self->{parent}->{component}) {
    $self->{aggbox}       = Wx::StaticBox->new($self, -1, 'Aggregate degeneracy margins', wxDefaultPosition, wxDefaultSize);
    $self->{aggboxsizer}  = Wx::StaticBoxSizer->new( $self->{aggbox}, wxVERTICAL );
    $hh = Wx::BoxSizer->new( wxHORIZONTAL );
    $self->{aggboxsizer}->Add($hh, 0, wxGROW|wxALL, 0);
    $self->{aggfuzzlab}     = Wx::StaticText->new($self, -1, "Margin:");
    $self->{aggfuzz}        = Wx::TextCtrl->new($self, -1, Demeter->co->default(qw(pathfinder fuzz)), wxDefaultPosition, [30,-1]);
    $self->{aggbetafuzzlab} = Wx::StaticText->new($self, -1, "Beta:");
    $self->{aggbetafuzz}    = Wx::TextCtrl->new($self, -1, Demeter->co->default(qw(pathfinder betafuzz)), wxDefaultPosition, [30,-1]);
    $hh->Add($self->{aggfuzzlab},     0, wxGROW|wxALL, 5);
    $hh->Add($self->{aggfuzz},        1, wxGROW|wxALL, 2);
    $hh->Add($self->{aggbetafuzzlab}, 0, wxGROW|wxALL, 5);
    $hh->Add($self->{aggbetafuzz},    1, wxGROW|wxALL, 2);
    $spacebox->Add($self->{aggboxsizer}, 0, wxEXPAND|wxALL, 1);
    $self->{$_}->Enable(0) foreach qw(aggbox aggfuzz aggfuzzlab aggbetafuzz aggbetafuzzlab);
  };

  #$spacebox->Add(1,1,1);

  $self->{addbutton} = Wx::Button->new($self, -1, "Add a site");
  $spacebox -> Add($self->{addbutton}, 0, wxGROW|wxALL|wxALIGN_BOTTOM, 0);
  EVT_BUTTON($self, $self->{addbutton}, sub{$self->AddSite(0, $self)});

  # $self->{addbar} = Wx::ToolBar->new($self, -1, wxDefaultPosition, wxDefaultSize, wxTB_VERTICAL|wxTB_3DBUTTONS|wxTB_TEXT);
  # EVT_MENU( $self->{addbar}, -1, sub{my ($toolbar, $event) = @_; AddSite($toolbar, $event, $self)} );
  # $self->{addbar} -> AddTool(-1, "Add a site", $self->icon("add"),   wxNullBitmap, wxITEM_NORMAL, q{}, $hints{add}  );
  # EVT_TOOL_ENTER( $self, $self->{addbar}, sub{my ($toolbar, $event) = @_; &OnToolEnter($toolbar, $event, 'addbar')} );
  # $self->{addbar} -> Realize;
  # $spacebox -> Add($self->{addbar}, 0, wxALL|wxALIGN_BOTTOM, 0);

  ## -------- end off space group and edge controls



  ## -------- lattice constant controls
  $self->{latticebox}       = Wx::StaticBox->new($self, -1, 'Lattice Constants', wxDefaultPosition, wxDefaultSize);
  $self->{latticeboxsizer}  = Wx::StaticBoxSizer->new( $self->{latticebox}, wxVERTICAL );
  my $tsz = Wx::GridBagSizer->new( 6, 10 );

  $label = Wx::StaticText->new($self, -1, 'A', wxDefaultPosition, [$width,-1]);
  $self->{a} = Wx::TextCtrl->new($self, -1, q{}, wxDefaultPosition, [$width*7,-1], wxTE_PROCESS_ENTER);
  $tsz -> Add($label,    Wx::GBPosition->new(0,0));
  $tsz -> Add($self->{a},Wx::GBPosition->new(0,1));

  $label = Wx::StaticText->new($self, -1, 'B', wxDefaultPosition, [$width,-1]);
  $self->{b} = Wx::TextCtrl->new($self, -1, q{}, wxDefaultPosition, [$width*7,-1], wxTE_PROCESS_ENTER);
  $tsz -> Add($label,    Wx::GBPosition->new(0,2));
  $tsz -> Add($self->{b},Wx::GBPosition->new(0,3));

  $label     = Wx::StaticText->new($self, -1, 'C', wxDefaultPosition, [$width,-1]);
  $self->{c} = Wx::TextCtrl->new($self, -1, q{}, wxDefaultPosition, [$width*7,-1], wxTE_PROCESS_ENTER);
  $tsz -> Add($label,    Wx::GBPosition->new(0,4));
  $tsz -> Add($self->{c},Wx::GBPosition->new(0,5));

  $label         = Wx::StaticText->new($self, -1, $ALPHA, wxDefaultPosition, [$width,-1]);
  $self->{alpha} = Wx::TextCtrl  ->new($self, -1, q{}, wxDefaultPosition, [$width*7,-1], wxTE_PROCESS_ENTER);
  $tsz -> Add($label,        Wx::GBPosition->new(1,0));
  $tsz -> Add($self->{alpha},Wx::GBPosition->new(1,1));

  $label        = Wx::StaticText->new($self, -1, $BETA,  wxDefaultPosition, [$width,-1]);
  $self->{beta} = Wx::TextCtrl  ->new($self, -1, q{}, wxDefaultPosition, [$width*7,-1], wxTE_PROCESS_ENTER);
  $tsz -> Add($label,        Wx::GBPosition->new(1,2));
  $tsz -> Add($self->{beta}, Wx::GBPosition->new(1,3));

  $label         = Wx::StaticText->new($self, -1, $GAMMA, wxDefaultPosition, [$width,-1]);
  $self->{gamma} = Wx::TextCtrl  ->new($self, -1, q{}, wxDefaultPosition, [$width*7,-1], wxTE_PROCESS_ENTER);
  $tsz -> Add($label,        Wx::GBPosition->new(1,4));
  $tsz -> Add($self->{gamma},Wx::GBPosition->new(1,5));

  $self->{latticeboxsizer} -> Add($tsz, 0, wxGROW|wxALL, 5);
  $sidebox -> Add($self->{latticeboxsizer}, 0, wxGROW|wxALL, 0);
  $vbox -> Add($hbox, 0, wxGROW|wxALL);
  ## -------- end of lattice constant controls


  ## -------- R constant controls
  $self->{Rbox}       = Wx::StaticBox->new($self, -1, 'Radial distances', wxDefaultPosition, wxDefaultSize);
  $self->{Rboxsizer}  = Wx::StaticBoxSizer->new( $self->{Rbox}, wxVERTICAL );

  $tsz = Wx::GridBagSizer->new( 6, 10 );

  $width = 60;

  $label = Wx::StaticText->new($self, -1, 'Cluster size', wxDefaultPosition, [-1,-1]);
  $tsz -> Add($label,Wx::GBPosition->new(0,0));
  $self->{rmax} = Wx::TextCtrl->new($self, -1, $atoms->rmax, wxDefaultPosition, [$width,-1], wxTE_PROCESS_ENTER);
  $tsz -> Add($self->{rmax},Wx::GBPosition->new(0,1));

  $label = Wx::StaticText->new($self, -1, 'Longest path', wxDefaultPosition, [-1,-1]);
  $tsz -> Add($label,Wx::GBPosition->new(0,2));
  $self->{rpath} = Wx::TextCtrl->new($self, -1, $atoms->rpath, wxDefaultPosition, [$width,-1], wxTE_PROCESS_ENTER);
  $tsz -> Add($self->{rpath},Wx::GBPosition->new(0,3));

  $self->{Rboxsizer} -> Add($tsz, 0, wxGROW|wxALL, 5);
  $sidebox -> Add($self->{Rboxsizer}, 0, wxGROW|wxALL, 0);
  ## -------- end of R constant controls


  ## -------- shift constant controls
  $self->{shiftbox}       = Wx::StaticBox->new($self, -1, 'Shift vector', wxDefaultPosition, wxDefaultSize);
  $self->{shiftboxsizer}  = Wx::StaticBoxSizer->new( $self->{shiftbox}, wxVERTICAL );

  $tsz = Wx::GridBagSizer->new( 6, 10 );

  $width = 70;

  #$label = Wx::StaticText->new($self, -1, 'Shift', wxDefaultPosition, [-1,-1]);
  #$tsz -> Add($label,Wx::GBPosition->new(0,0));
  $self->{shift_x} = Wx::TextCtrl->new($self, -1, 0, wxDefaultPosition, [$width,-1], wxTE_PROCESS_ENTER);
  $tsz -> Add($self->{shift_x},Wx::GBPosition->new(0,0));
  $self->{shift_y} = Wx::TextCtrl->new($self, -1, 0, wxDefaultPosition, [$width,-1], wxTE_PROCESS_ENTER);
  $tsz -> Add($self->{shift_y},Wx::GBPosition->new(0,1));
  $self->{shift_z} = Wx::TextCtrl->new($self, -1, 0, wxDefaultPosition, [$width,-1], wxTE_PROCESS_ENTER);
  $tsz -> Add($self->{shift_z},Wx::GBPosition->new(0,2));

  $self->{shiftboxsizer} -> Add($tsz, 0, wxGROW|wxALL, 5);
  $sidebox -> Add($self->{shiftboxsizer}, 0, wxGROW|wxALL, 0);
  ## -------- end of R constant controls

  $self->set_hint($_) foreach (qw(a b c alpha beta gamma space rmax rpath
				  shift_x shift_y shift_z edge template));

  foreach my $x (qw(a b c alpha beta gamma name space rmax rpath shift_x shift_y shift_z edge template)) {
    EVT_TEXT_ENTER($self, $self->{$x}, sub{1});
  };

  $hbox = Wx::BoxSizer->new( wxHORIZONTAL );
  $self->{sitesgrid} = Demeter::UI::Atoms::Xtal::SiteList->new($self, -1);
  EVT_GRID_CELL_LEFT_CLICK($self->{sitesgrid}, \&OnGridClick);
  EVT_GRID_CELL_RIGHT_CLICK($self->{sitesgrid}, \&PostGridMenu);
  EVT_GRID_LABEL_RIGHT_CLICK($self->{sitesgrid}, \&PostGridMenu);
  EVT_MENU($self->{sitesgrid}, -1, \&OnGridMenu);

  $hbox -> Add($self->{sitesgrid}, 1, wxGROW|wxALL|wxALIGN_CENTER_HORIZONTAL, 0);
  $vbox -> Add($hbox, 2, wxGROW|wxALL|wxALIGN_CENTER_HORIZONTAL, 5);

  $self -> SetSizer( $vbox );

  #foreach (1..10) {
  #  $self->{sitesgrid}->InsertRows($self->{sitesgrid}->GetNumberRows, 1, 1);
  #};
  return $self;
};

sub icon {
  my ($self, $which) = @_;
  my $icon = File::Spec->catfile($Demeter::UI::Atoms::atoms_base, 'Atoms', 'icons', "$which.png");
  return wxNullBitmap if (not -e $icon);
  return Wx::Bitmap->new($icon, wxBITMAP_TYPE_ANY)
};

sub templates {
  my ($self) = @_;
  return ['Feff6 - elem', 'Feff6 - tags', 'Feff6 - sites',
	  #'Feff8 - elem', 'Feff8 - tags', 'Feff8 - sites',
	 ];
};

sub set_hint {
  my ($self, $w) = @_;
  (my $ww = $w) =~ s{\d+\z}{};
  EVT_ENTER_WINDOW($self->{$w}, sub{my($widg, $event) = @_;
				    $self->OnWidgetEnter($widg, $event, $hints{$ww}||q{No hint!})});
  EVT_LEAVE_WINDOW($self->{$w}, sub{$self->OnWidgetLeave});
};

sub OnToolEnter {
  my ($self, $event, $which) = @_;
  if ( $event->GetSelection > -1 ) {
    $self->{statusbar}->SetStatusText($self->{$which}->GetToolLongHelp($event->GetSelection));
  } else {
    $self->{statusbar}->SetStatusText(q{});
  };
};
sub OnWidgetEnter {
  my ($self, $widget, $event, $hint) = @_;
  $self->{statusbar}->SetStatusText($hint);
};
sub OnWidgetLeave {
  my ($self) = @_;
  $self->{statusbar}->SetStatusText(q{});
};

sub OnTemplate {
  my ($self, $event) = @_;
  my $choice = $self->{template}->GetStringSelection;
  if ($choice =~ m{Feff8}) {
    Demeter->mo->template_feff('feff8');
    $self->{scf}->Enable(1);
    if ($self->{scf}->GetValue) {
      $self->{scflab}->Enable(1);
      $self->{rscf}->Enable(1);
    };
  } else {
    Demeter->mo->template_feff('feff6');
    $self->{scf}->Enable(0);
    $self->{scflab}->Enable(0);
    $self->{rscf}->Enable(0);
  };
  $self->{statusbar}->SetStatusText(q{});
};

sub OnCheckBox {
  my ($self, $event) = @_;
  if ($self->{scf}->GetValue) {
    $self->{scflab}->Enable(1);
    $self->{rscf}->Enable(1);
  } else {
    $self->{scflab}->Enable(0);
    $self->{rscf}->Enable(0);
  };
};

sub OnToolClick {
  my ($toolbar, $event, $self) = @_;
  ##                 Vv--order of toolbar on the screen--vV
  my @callbacks = qw(open_file save_file write_output clear_all noop run_atoms aggregate); #  document noop
  my $closure = $callbacks[$toolbar->GetToolPos($event->GetId)];
  $self->$closure;
};
sub OnToolRightClick {
  my ($toolbar, $event, $self) = @_;
  return if not ($toolbar->GetToolPos($event->GetId) == 0);
  my $dialog = Demeter::UI::Wx::MRU->new($self, 'atoms',
					 "Select a recent crystal data file",
					 "Recent crystal data files");
  $self->{parent}->status("There are no recent crystal data files."), return
    if ($dialog == -1);
  if( $dialog->ShowModal == wxID_CANCEL ) {
    $self->{parent}->status("Import canceled.");
  } else {
   $self->open_file( $dialog->GetMruSelection );
  };
};

## this overrides a click event on the core column to make those
## checkboxes work like radioboxes.  a click event elsewhere on the
## grid is passed through
sub OnGridClick {
  my ($self, $event) = @_;
  $event->Skip(1), return if ((ref($event) =~ m{Event}) and ($event->GetCol != 0));
  my $row = (ref($event) =~ m{Event}) ? $event->GetRow : $event;
  my @el;
  foreach my $rr (0 .. $self->GetNumberRows) {
    $self->SetCellValue($rr, 0, 0);
    push @el, $self->GetCellValue($rr, 1) if ($self->GetCellValue($rr, 1) !~ m{\A\s*\z});
  };
  $self->SetCellValue($row, 0, 1);
  my $nsites = true {$_ eq $self->GetCellValue($row, 1)} @el;
  if ($self->GetParent->{parent}->{component}) {
    if ($nsites > 1) {
      ## enable aggregate Feff calculation, currently soft-disabled for 0.9.19
      ## change the call to co->default to 1 once the paper is published
      $self->GetParent->{toolbar}->EnableTool($self->GetParent->{aggid},Demeter->co->default('artemis','show_aggregate'));
      $self->GetParent->{$_}->Enable(Demeter->co->default('artemis','show_aggregate'))
	foreach qw(aggbox aggfuzz aggfuzzlab aggbetafuzz aggbetafuzzlab);
    } else {
      ## disable aggregate Feff calculation
      $self->GetParent->{toolbar}->EnableTool($self->GetParent->{aggid},0);
      $self->GetParent->{$_}->Enable(0) foreach qw(aggbox aggfuzz aggfuzzlab aggbetafuzz aggbetafuzzlab);
    };
  };
};

sub PostGridMenu {
  my ($self, $event) = @_;
  my $row = $event->GetRow;
  return if ($row < 0);
  my $menu = Wx::Menu->new(q{});
  $menu->Append(0, "Copy site");
  $menu->Append(1, "Cut site");
  $menu->Append(2, "Paste site");
  $self->{selected_site} = [
			    $self->GetCellValue($row,1),
			    $self->GetCellValue($row,2),
			    $self->GetCellValue($row,3),
			    $self->GetCellValue($row,4),
			    $self->GetCellValue($row,5),
			   ];
  $self->{selected_row} = $row;
  $self->SelectRow($row);
  $self->PopupMenu($menu, $event->GetPosition);
};
sub OnGridMenu {
  my ($self, $event) = @_;
  my $which = $event->GetId;
  my $string = join(",", @{ $self->{selected_site} });
 SWITCH: {
    ($which == 0) and do {
      $self->{buffered_site} = $self->{selected_site};
      last SWITCH;
    };
    ($which == 1) and do {
      $self->{buffered_site} = $self->{selected_site};
      $self->DeleteRows($self->{selected_row}, 1, 1);
      $self->AppendRows(1,1) if ($self->GetNumberRows < 6);
      $self->SetCellAlignment($self->GetNumberRows, 0, wxALIGN_CENTRE, wxALIGN_CENTRE);
      last SWITCH;
    };
    ($which == 2) and do {
      my $r = $self->{selected_row};
      last SWITCH if not $self->{buffered_site};
      my @site = @{ $self->{buffered_site} };
      $self -> InsertRows($r, 1, 1);
      $self -> SetCellAlignment($r, 0, wxALIGN_CENTRE, wxALIGN_CENTRE);
      map { $self->SetCellValue($r, $_+1, $site[$_]) } (0 .. 4);
      last SWITCH;
    };
  };
};

sub AddSite {
  my ($toolbar, $event, $self) = @_;
  $self->{sitesgrid} -> InsertRows($self->{sitesgrid}->GetNumberRows, 1, 1);
  $self->{sitesgrid} -> SetCellAlignment($self->{sitesgrid}->GetNumberRows, 0, wxALIGN_CENTRE, wxALIGN_CENTRE);
};

sub noop {
  return 1;
};

sub open_file {
  my ($self, $file) = @_;
  $atoms->partial_occupancy(0);
  if ((not $file) or (not -e $file)) {
    my $fd = Wx::FileDialog->new( $self, "Import crystal data", cwd, q{},
				  "input and CIF files (*.inp;*.cif)|*.inp;*.cif|input file (*.inp)|*.inp|CIF file (*.cif)|*.cif|All files (*)|*",
				  wxFD_OPEN|wxFD_FILE_MUST_EXIST|wxFD_CHANGE_DIR|wxFD_PREVIEW,
				  wxDefaultPosition);
    if ($fd->ShowModal == wxID_CANCEL) {
      $self->{parent}->status("Crystal data import canceled.");
      return 0;
    };
    $file = $fd->GetPath;
  };
  if (not ($atoms->is_atoms($file) or $atoms->is_cif($file))) {
    warn "$file is not an atoms.inp or CIF file\n";
    return 0;
  };

  $self->clear_all(1);

  my $is_cif = 0;
  $is_cif = 1 if ($atoms->is_cif($file));
  if ($is_cif) {
    if (not $Demeter::STAR_Parser_exists) {
      warn "STAR::Parser is not available, so CIF files cannot be imported";
      return 0;
    };

    $atoms->cif($file);
    my @records = $atoms->open_cif;
    if ($#records) {  ## post a selection dialog for a cif file with more than one record
      my $dialog = Wx::SingleChoiceDialog->new( $self, "Choose a record from this CIF file",
						"CIF file", \@records );
      if( $dialog->ShowModal == wxID_CANCEL ) {
	$self->{parent}->status("Import canceled.");
	return 0;
      } else {
	my $which = $dialog->GetSelection||0;
	$atoms->record($which);
      };
    } else {
      $atoms->record(0);
    };
  } else {
    $atoms->file($file);
  };
  if ($atoms->partial_occupancy) {
    my $message = Wx::MessageDialog->new($self, "Atoms is unable to use crystal data which has sites of partial occupancy.  Sorry.", "Trouble", wxOK);
    $message->ShowModal;
    return 0;
  };
  my $name = basename($file, '.cif', '.inp');
  $atoms -> name($name) if not $atoms->name;
  $self->{name}->SetValue($name);
  $Demeter::UI::Atoms::frame->SetTitle("Atoms: ".$name) if defined($Demeter::UI::Atoms::frame);

  ## load values into their widgets
  my $titles = join($/, (@{ $atoms->titles }));
  $self->{titles}->SetValue($titles);

  foreach my $lc (qw(a b c)) {
    my $this = $atoms->$lc;
    $this = $atoms->a if (($lc =~ m{[bc]}) and ($atoms->$lc < $EPSILON3));
    $self->{$lc}->SetValue($this);
  };
  foreach my $lc (qw(alpha beta gamma)) {
    my $this = $self->verify_angle($lc);
    $self->{$lc}->SetValue($this);
  };
  foreach my $lc (qw(space rmax rpath)) {
    $self->{$lc}->SetValue($atoms->$lc);
  };
  my @shift = @{ $atoms->shift };
  $self->{shift_x}->SetValue($shift[0]||0);
  $self->{shift_y}->SetValue($shift[1]||0);
  $self->{shift_z}->SetValue($shift[2]||0);

  my $i = 0;
  my $corerow = 0;
  my $cell = $atoms->cell;
  my $message = "Imported crystal data from \"$file\".";
  foreach my $s (@{ $atoms->sites }) {
    $self->AddSite(0, $self) if ($i >= $self->{sitesgrid}->GetNumberRows);
    my @this = split(/\|/, $s);
    my $sym = ($atoms->element_check($this[0])) ? ucfirst(lc($this[0])) : "Nu (".$this[0].")";
    $message = sprintf("Ambiguous symbol at site %d.", $i+1) if ($sym =~ m{\ANu});
    $self->{sitesgrid}->SetCellValue($i, 1, $sym);
    $self->{sitesgrid}->SetCellValue($i, 2, $this[1]);
    $self->{sitesgrid}->SetCellValue($i, 3, $this[2]);
    $self->{sitesgrid}->SetCellValue($i, 4, $this[3]);
    $self->{sitesgrid}->SetCellValue($i, 5, $this[4]);
    if (lc($this[4]) eq lc($atoms->core)) {
      $self->{sitesgrid}->SetCellValue($i, 0, 1);
      $corerow = $i;
      if (not $atoms->edge) {
	my $z = ($sym =~ m{\ANu}) ? 0 : get_Z( $sym );
	($z > 57) ? $atoms->edge('l3') : $atoms->edge('k');
      };
    };
    ++$i;
  };
  OnGridClick($self->{sitesgrid}, $corerow);
  my $ie = firstidx {lc($_) eq lc($atoms->edge)} qw(K L1 L2 L3);
  $ie = 0 if ($ie == -1);
  $self->{edge}->SetSelection($ie);

  $atoms -> push_mru("atoms", $file) if ($file !~ m{_dem_});

  $self->{parent}->status($message);
  return 1;
};

sub get_crystal_data {
  my ($self) = @_;
  return 1 if not $self->{used};
  $self->{problems} = q{};
  my $problems = q{};
  $atoms->clear;

  my $this = $self->{space}->GetValue || q{};
  if ((not $this) and ($self->{used})) {
    print join("|", caller), $/;
    $self->{problems} = "You have not specified a space group.";
    return 0;
  };
  $atoms->space($this);
  $atoms->cell->space_group($this); # why is this necessary!!!!!  why is the trigger not being triggered?????
  $problems .= $atoms->cell->group->warning.$/ if $atoms->cell->group->warning;

  $atoms->name($self->{name}->GetValue || "Feff:".$atoms->group);
  $self->{name}->SetValue($atoms->name);

  my @titles = split(/\n/, $self->{titles}->GetValue);
  $atoms->titles(\@titles);

  foreach my $param (qw(b c)) {
    next if $self->{$param}->GetValue;
    next if (($self->{$param}->GetValue =~ m{$NUMBER}) and
	     ($self->{$param}->GetValue > 0));
    $self->{$param}->SetValue($self->{a}->GetValue);
  };
  foreach my $param (qw(rmax rpath rscf)) {
    next if is_PosNum($self->{$param}->GetValue);
    $self->{$param}->SetValue($atoms->co->default("atoms", $param));
  };

  foreach my $param (qw(a b c alpha beta gamma rmax rpath rscf)) {
    my $val = ($param =~ m{alpha|beta|gamma}) ? 90 : 0;
    $this = $self->{$param}->GetValue || $val;;
    if (is_PosNum($this)) {
      $atoms->$param($this);
    } else {
      $problems .= "\"$this\" is not a valid value for \"$param\" (should be a positive number).\n\n";
    };
  };
  $atoms->do_scf($self->{scf}->GetValue);
  foreach my $param (qw(alpha beta gamma)) {
    $self->{$param}->SetValue($self->verify_angle($param));
    $atoms->$param($self->{$param}->GetValue);
  };

  my @shift = map { $self->{$_}->GetValue || 0 } qw(shift_x shift_y shift_z);
  @shift = map { $self->number($_) } @shift;
  $problems .= "\"" . $self->{shift_x}->GetValue . "\" is not a valid value for a shift coordinate (should be a number or a simple fraction).\n\n" if ($shift[0] == -9999);
  $problems .= "\"" . $self->{shift_y}->GetValue . "\" is not a valid value for a shift coordinate (should be a number or a simple fraction).\n\n" if ($shift[1] == -9999);
  $problems .= "\"" . $self->{shift_z}->GetValue . "\" is not a valid value for a shift coordinate (should be a number or a simple fraction).\n\n" if ($shift[2] == -9999);
  $atoms->shift(\@shift);

  my $core_selected = 0;
  my $first_valid_row = -1;
  my $count_valid_row = 0;
  foreach my $row (0 .. $self->{sitesgrid}->GetNumberRows) {
    my $el   = $self->{sitesgrid}->GetCellValue($row, 1) || q{};
    next if ($el =~ m{\A\s*\z});
    ++$count_valid_row;
    my $rr = $row+1;
    $problems .= "\"$el\" is not an element symbol at site $rr\n" if not is_Element($el);;
    #warn("$el is not an element symbol at site $rr\n"), return 0 if not is_Element($el);
    ($first_valid_row = $row) if ($first_valid_row == -1);
    if ($self->{sitesgrid}->GetCellValue($row, 0)) {
      my $thistag = $self->{sitesgrid}->GetCellValue($row, 5);
      $thistag =~ s{$FEFFNOTOK}{}g; # scrub characters that will confuse Feff
      $atoms->core($thistag || $self->{sitesgrid}->GetCellValue($row, 1));
      ++$core_selected;
    };
    my $x     = $self->{sitesgrid}->GetCellValue($row, 2) || 0; $x = $self->number($x);
    my $y     = $self->{sitesgrid}->GetCellValue($row, 3) || 0; $y = $self->number($y);
    my $z     = $self->{sitesgrid}->GetCellValue($row, 4) || 0; $z = $self->number($z);
    my $tag   = $self->{sitesgrid}->GetCellValue($row, 5) || $el;
    $tag  =~ s{$FEFFNOTOK}{}g; # scrub characters that will confuse Feff
    $problems .= "\"" . $self->{sitesgrid}->GetCellValue($row, 2) . "\" is not a valid x-coordinate value for site $rr (should be a number).\n\n" if ($x == -9999);
    $problems .= "\"" . $self->{sitesgrid}->GetCellValue($row, 3) . "\" is not a valid y-coordinate value for site $rr (should be a number).\n\n" if ($y == -9999);
    $problems .= "\"" . $self->{sitesgrid}->GetCellValue($row, 4) . "\" is not a valid z-coordinate value for site $rr (should be a number).\n\n" if ($z == -9999);
    my $this = join("|", $el, $x, $y, $z, $tag);
    $atoms->push_sites($this);
  };
  $problems .= "There are no valid atom positions.\n\n" if (not $count_valid_row);
  if ($count_valid_row and not $core_selected) {	# set first site as core if core not chosen
    $atoms->core(
		 $self->{sitesgrid}->GetCellValue($first_valid_row, 5)
		 ||
		 $self->{sitesgrid}->GetCellValue($first_valid_row, 1)
		);
    $self->{sitesgrid}->SetCellValue($first_valid_row, 0, 1);
  };

  my $seems_ok = 0;
  $seems_ok = (
	            ($atoms->space)
	       and  ($#{ $atoms->sites } > -1)
	       and  ($atoms->a)
	      );
  if ($problems) {
    $self->{problems} = $problems;
    $seems_ok = 0;
    #warn($problems);
  };
  return 0 if not $seems_ok;

  $atoms->shift(\@shift);
  $atoms->populate;
  $this = (qw(K L1 L2 L3))[$self->{edge}->GetCurrentSelection] || 'K';
  $atoms->edge($this);

  return 1;
};

sub number {
  my ($self, $string) = @_;

  ## empty string
  return 0 if ($string =~ m{\A\s*\z});

  ## floating point number
  return sprintf("%9.5f", $string) if ($string =~ m{\A\s*$NUMBER\s*\z});

  ## binary operation
  if ($string =~ m{
		    \A\s*	   # leading white space
		    (?:$NUMBER)	   # a number
		    \s*		   # more white space
		    [+-/*]	   # a binary operator
		    \s*		   # more white space
		    (?:$NUMBER)	   # a second number
		    \s*\z	   # trailing whitespace
		}x) {
    my $num = eval $string;
    return sprintf("%9.5f", $num);
  };

  return -9999;
};

sub verify_angle {
  my ($self, $angle) = @_;
  my $cell    = $atoms->cell;
  my $class   = $cell->group->class;
  my $setting = $cell->group->setting;
 SWITCH: {
    (($class eq 'hexagonal') and ($setting eq 'rhombohedral')) and do {
      return $atoms->alpha;
      last SWITCH;
    };
    ($class eq 'hexagonal') and do {
      return 90  if ($angle =~ m{(?:alpha|beta)});
      return 120 if ($angle eq 'gamma');
      last SWITCH;
    };
    ($class eq 'trigonal') and do {
      return 90  if ($angle =~ m{(?:alpha|beta)});
      return 120 if ($angle eq 'gamma');
      last SWITCH;
    };
    ($class =~ m{(?:cubic|tetragonal|orthorhombic)}) and do {
      return 90 if ($atoms->$angle < $EPSILON3);
      return $atoms->$angle;
      last SWITCH;
    };
  };
  return $atoms->$angle || 0;
};

sub edge_absorber {
  my ($self) = @_;
  my $edge = (qw(K L1 L2 L3))[$self->{edge}->GetCurrentSelection];
  my $abs;
  foreach my $row (0 .. $self->{sitesgrid}->GetNumberRows) {
    ($abs = $self->{sitesgrid}->GetCellValue($row, 1)), last if $self->{sitesgrid}->GetCellValue($row, 0);
  };
  $abs = ucfirst(lc($abs));
  my $z = get_Z($abs);
  return q{} if (not $atoms->co->default("atoms", "abs_edge_check"));
  return "Measuring EXAFS of an L edge of $abs seems unusual.... Do you wish to continue?" if (($edge =~ m{L[123]}) and ($z <  60));
  return "Measuring EXAFS of a K edge of $abs seems unusual.... Do you wish to continue?"  if (($edge eq 'K')       and ($z >= 60));
  return q{};
};

sub unusable_data {
  my ($self) = @_;
  my $message = Wx::MessageDialog->new($self, $self->{problems}, "Trouble", wxOK);
  $message->ShowModal;
  $self->{parent}->status("These crystallographic data cannot be processed");
};

sub save_file {
  my ($self, $file) = @_;
  return if $self->{parent}->{atoms_disabled};
  my $seems_ok = $self->get_crystal_data;
  if ($seems_ok) {
    if (not $file) {
      my $fd = Wx::FileDialog->new( $self, "Export crystal data", cwd, q{atoms.inp},
				    "input file (*.inp)|*.inp|All files (*)|*",
				    wxFD_SAVE|wxFD_CHANGE_DIR|wxFD_OVERWRITE_PROMPT,
				    wxDefaultPosition);
      if ($fd -> ShowModal == wxID_CANCEL) {
	$self->{parent}->status("Saving crystal data aborted.");
	return 0;
      } else {
	$file = $fd->GetPath;
	# if (-e $file) {
	#   my $yesno = Demeter::UI::Wx::VerbDialog->new($self, -1,
	# 					       "Overwrite existing file \"$file\"?",
	# 					       "Overwrite file?",
	# 					       "Overwrite",
	# 					      );
	#   my $ok = $yesno->ShowModal;
	#   if ($ok == wxID_NO) {
	#     $self->{parent}->status("Not overwriting \"$file\"");
	#     return 0;
	#   };
	# };
      };
    };
  } else {
    $self->unusable_data();
    return 0;
  };

  open my $OUT, ">".$file;
  print $OUT $atoms -> Write('atoms');
  close $OUT;
  $atoms -> push_mru("atoms", $file);
  $self->{parent}->status("Saved crystal data to $file.");
  return 1;
};

sub run_atoms {
  my ($self, $is_aggregate) = @_;
  $is_aggregate = 0;
  my $seems_ok = $self->get_crystal_data;
  my $this = (@{ $self->templates })[$self->{template}->GetCurrentSelection] || 'Feff6 - tags';
  my ($template, $style) = split(/ - /, $this);
  $style = 'elements' if $style eq 'elem';
  $atoms -> ipot_style($style);
  if ($seems_ok) {
    my $busy    = Wx::BusyCursor->new();
    ## * check edge against absorber
    my $ea = $self->edge_absorber;
    if ($ea) {
      my $yesno = Wx::MessageDialog->new($self, $ea, "Continue?", wxYES_NO);
      if ($yesno->ShowModal == wxID_NO) {
	$self->{parent}->status("Aborting calculation.");
	undef $busy;
	return;
      };
    };
    ## these can be disabled by an aggregate calculation
    my $save = $atoms->co->default("atoms", "atoms_in_feff");
    $atoms->co->set_default("atoms", "atoms_in_feff", 0);
    $self->{parent}->make_page('Feff') if not $self->{parent}->{Feff};
    $self->{parent}->{Feff}->{toolbar}->Enable(1);
    $self->{parent}->{Feff}->{name}->Enable(1);
    $self->{parent}->{Feff}->{feff}->Enable(1);
    $self->{parent}->{Feff}->{feff}->SetValue($atoms -> Write($template));
    $self->{parent}->{Feff}->{name}->SetValue($atoms -> name);
    $atoms->co->set_default("atoms", "atoms_in_feff", $save);
    undef $busy;
    return if ($#{$atoms->cluster} <= 0);
    $self->{parent}->{notebook}->ChangeSelection(1) if not $is_aggregate;
  } else {
    $self->unusable_data();
  };
};

sub aggregate {
  my ($self) = @_;

  ## 0. warn about length of calculation, check rpath value
  my $text = "The aggregate Feff calculation can be quite time consuming, particularly if Rpath is large.\n\n";
  $text   .= "This calculation requires that Rmax be large enough that each Feff calculation inlcudes an example of each unique potential.\n\n";
  $text   .= sprintf("Rmax = %.3f    Rpath = %.3f\n\n", $self->{rmax}->GetValue, $self->{rpath}->GetValue);
  $text   .= "Continue with the calculation?";
  my $message = Demeter::UI::Wx::VerbDialog->new($self, -1,
						 $text,
						 "Perform aggregate Feff calculation?",
						 "Continue");
  #my $message = Wx::MessageDialog->new($self, $text, "Perform aggregate Feff calculation?", wxYES_NO);
  #$message->ShowModal;
  if ($message->ShowModal == wxID_NO) {
    $self->{parent}->status("Not performing aggregate Feff calculation.");
    return;
  };

  my $ea = $self->edge_absorber;
  if ($ea) {
    my $yesno = Wx::MessageDialog->new($self, $ea, "Continue?", wxYES_NO);
    if ($yesno->ShowModal == wxID_NO) {
      $self->{parent}->status("Aborting calculation.");
      undef $busy;
      return;
    };
  };

  ## 0.5. Write an atoms.inp and pass it along to the parts
  ## 1. set up Feff::Aggregate object, use folder created when atoms imported, feff_* folders for parts
  $self->run_atoms(1);
  my $feffobject = $self->{parent}->{Feff}->{feffobject};
  my $atomsfile = File::Spec->catfile($self->{parent}->{Feff}->{feffobject}->workspace, "atoms.inp");
  $self->save_file($atomsfile);
  #$atoms->file($atomsfile);
  my $gp = $feffobject->group;
  my $ws = $feffobject->workspace;
  #$feffobject->DEMOLISH;
  my $bigfeff = Demeter::Feff::Aggregate->new(group=>$gp, screen=>0);
  $self->{parent}->{Feff}->{feffobject} = $bigfeff;
  my $workspace = File::Spec->catfile(dirname($ws), $bigfeff->group);
  $bigfeff -> workspace($workspace);
  $bigfeff -> make_workspace;
  $bigfeff->fuzz($self->{aggfuzz}->GetValue);
  $bigfeff->betafuzz($self->{aggbetafuzz}->GetValue);

  $self->{parent}->make_page('Console') if not $self->{parent}->{Console};
  $self->{parent}->{Console}->{console}->AppendText($self->{parent}->{Feff}->now("Aggregate Feff calculation beginning at ", $bigfeff));
  my $n = (exists $Demeter::UI::Artemis::frames{main}) ? 4 : 3;
  $self->{parent}->{notebook}->ChangeSelection($n);
  $self->{parent}->{Console}->{console}->Update;
  my $start = DateTime->now( time_zone => 'floating' );
  my $busy = Wx::BusyCursor->new();
  $bigfeff->execution_wrapper(sub{$self->{parent}->{Feff}->run_and_gather(@_)});
  my ($central, $xcenter, $ycenter, $zcenter) = $atoms -> cell -> central($atoms->core);

  ## 2. Check return value of setup method, clean and bail if there is a problem
  my $ret = $bigfeff->setup($atoms, $central->element);
  if (not $ret->is_ok) {
    my $message = Wx::MessageDialog->new($self, $ret->message, "Error!", wxOK|wxICON_ERROR) -> ShowModal;
    $bigfeff->clean_workspace;
    $bigfeff->DEMOLISH;
    $self->{parent}->{notebook}->ChangeSelection(0);
    $self->{rmax}->SetFocus;
    return;
  };

  ## 3. run aggregate calculation, streaming updates to console
  $bigfeff->run;

  ## 4. Fill and disable Feff tab
  $self->{parent}->{Feff}->{toolbar}->Enable(0);
  $self->{parent}->{Feff}->{name}->Enable(0);
  $self->{parent}->{Feff}->{feff}->Enable(0);
  $self->{parent}->{Feff}->{margin}->SetValue($bigfeff->fuzz);
  $self->{parent}->{Feff}->{betafuzz}->SetValue($bigfeff->betafuzz);
  $self->{parent}->{Feff}->{margin}->Enable(0);
  $self->{parent}->{Feff}->{betafuzz}->Enable(0);

  ## 5. Labels & Fill Paths tab
  $bigfeff->name(q{agg-}.$self->{name}->GetValue);
  my $yaml = File::Spec->catfile($bigfeff->workspace, $bigfeff->group.".yaml");
  $bigfeff->freeze($yaml);

  $::app->{main}->{$self->{parent}->{fnum}}->SetLabel('Hide "' . $bigfeff->name . '"') if $self->{parent}->{component};
  $self->{name}->SetValue($bigfeff->name);
  $self->{parent}->{Feff}->{name}->SetValue($bigfeff->name);
  $self->{parent}->{Feff}->{feffobject} = $bigfeff;
  $self->{parent}->{Feff}->fill_intrp_page($bigfeff);
  $self->{parent}->{Feff}->fill_ss_page($bigfeff);
  $self->{parent}->{notebook}->ChangeSelection(2);

  ## 6. clean up and display
  #$bigfeff->clean_workspace;
  undef $busy;
};


sub document {
  $::app->document('feff');
};

sub clear_all {
  my ($self, $skip_dialog) = @_;
  return $self->_do_clear_all if (not $atoms->co->default("atoms", "do_confirm"));
  my $yesno = Demeter::UI::Wx::VerbDialog->new($self, -1,
					       "Do you really wish to discard these crystal data?",
					       "Discard?",
					       "Discard");
  if ((not $skip_dialog) and ($yesno->ShowModal == wxID_NO)) {
    $self->{parent}->status("Not discarding data.");
  } else {
    $self->_do_clear_all;
  };
  return $self;
};
sub _do_clear_all {
  my ($self) = @_;
  $atoms->clear;
  $self->{$_}->Clear foreach (qw(a b c alpha beta gamma titles space));
  $self->{$_}->SetValue(0) foreach (qw(shift_x shift_y shift_z));
  $self->{rmax}->SetValue(8);
  $self->{rpath}->SetValue(5);
  $self->{sitesgrid}->ClearGrid;
  $self->{sitesgrid}->DeleteRows(6, $self->{sitesgrid}->GetNumberRows - 6, 1);
  $self->{edge}->SetSelection(0); # foreach (qw(edge template));
  return $self;
};


sub write_output {
  my ($self) = @_;
  my $seems_ok = $self->get_crystal_data;
  if ($seems_ok) {
    my $dialog = Wx::SingleChoiceDialog->new( $self, "Output format", "Output format",
					      ["Feff6", "Feff8", "Atoms", "P1", "Spacegroup", "Absorption"]
					    );
    if( $dialog->ShowModal == wxID_CANCEL ) {
      $self->{parent}->status("Writing Atoms output canceled.");
    } else {
      my $fd = Wx::FileDialog->new( $self, "Export crystal data to a special file", cwd, q{},
				    "All files (*.*)|*.*|All files (*)|*",
				    wxFD_SAVE|wxFD_CHANGE_DIR, wxDefaultPosition);
      if ($fd -> ShowModal == wxID_CANCEL) {
	$self->{parent}->status("Saving output file aborted.")
      } else {
	my $file = $fd->GetPath;
	open my $OUT, ">".$file;
	print $OUT $atoms -> Write(lc($dialog->GetStringSelection));
	close $OUT;
	$self->{parent}->status("Wrote " . $dialog->GetStringSelection . " output to $file");
      };
    }
  } else {
    $self->unusable_data();
  };
};

1;

=head1 NAME

Demeter::UI::Atoms::Xtal - Atoms' crystal utility

=head1 VERSION

This documentation refers to Demeter version 0.9.20.

=head1 DESCRIPTION

This class is used to populate the Atoms tab in the Wx version of Atoms.

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

