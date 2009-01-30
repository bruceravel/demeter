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

  $this -> CreateGrid(6,6);
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

use Demeter;
use Demeter::StrTypes qw( Element );

use Cwd;
use Chemistry::Elements qw(get_Z get_name get_symbol);
use List::MoreUtils qw(firstidx);
use Xray::Absorption;
#use Demeter::UI::Wx::GridTable;

use Readonly;
Readonly my $EPSILON => 1e-3;

use Wx qw( :everything );
use base 'Wx::Panel';
use Wx::Grid;
use Wx::Event qw(EVT_CHOICE EVT_KEY_DOWN EVT_MENU EVT_TOOL_ENTER EVT_ENTER_WINDOW EVT_LEAVE_WINDOW);

my %hints = (
	     titles   => "Text describing this structure which also be used as title lines in the Feff calculation",
	     space    => "The space group symbol (Hermann-Maguin, Schoenflies or number)",
	     a	      => "The value of the A lattice constant in Ångstroms",
	     b	      => "The value of the B lattice constant in Ångstroms",
	     c	      => "The value of the C lattice constant in Ångstroms",
	     alpha    => "The value of the alpha lattice angle (between B and C) in degrees",
	     beta     => "The value of the beta lattice angle (between A and C) in degrees",
	     gamma    => "The value of the gamma lattice angle (between A and B) in degrees",
	     rmax     => "The size of the cluster of atoms in Ångstroms",
	     rpath    => "The maximum path length in Feff's path expansion, in Ångstroms",
	     shift_x  => "The x-coordinate of the vector for recentering this crystal",
	     shift_y  => "The y-coordinate of the vector for recentering this crystal",
	     shift_z  => "The z-coordinate of the vector for recentering this crystal",
	     edge     => "The absorption edge to use in the Feff calculation",
	     template => "Choose the output style",

	     open     => "Open an Atoms input file or a CIF file -- Hint: Right click for recent files",
	     save     => "Save an atoms input file from these crystallographic data",
	     exec     => "Generate input data for Feff from these crystallographic data",
	     clear    => "Clear this crystal structure",
	     output   => "Write a feff.inp file or some other format",
	     add      => "Add another entry to the list of sites",

	     radio    => "Select this site as the absorbing atom in the Feff calculation",
	     element  => "The element occupying this unique crystallographic site",
	     x	      => "The x-coordinate of this unique crystallographic site",
	     y	      => "The x-coordinate of this unique crystallographic site",
	     z	      => "The x-coordinate of this unique crystallographic site",
	     tag      => "A short string identifying this unique crystallographic site",
	     del      => "Click this button to remove this crystallographic site",
	    );

my $atoms = Demeter::Atoms->new;


sub new {
  my ($class, $page, $parent, $statusbar) = @_;
  my $self = $class->SUPER::new($page, -1, wxDefaultPosition, wxDefaultSize, wxMAXIMIZE_BOX );
  $self->{parent}    = $parent;
  $self->{statusbar} = $statusbar;
  my $vbox = Wx::BoxSizer->new( wxVERTICAL );


  $self->{toolbar} = Wx::ToolBar->new($self, -1, wxDefaultPosition, wxDefaultSize, wxTB_HORIZONTAL|wxTB_3DBUTTONS|wxTB_TEXT);
  EVT_MENU( $self->{toolbar}, -1, sub{my ($toolbar, $event) = @_; OnToolClick($toolbar, $event, $self)} );
  $self->{toolbar} -> AddTool(-1, "Open file",  $self->icon("open"),   wxNullBitmap, wxITEM_NORMAL, q{}, $hints{open} );
  $self->{toolbar} -> AddTool(-1, "Save data",  $self->icon("save"),   wxNullBitmap, wxITEM_NORMAL, q{}, $hints{save} );
  $self->{toolbar} -> AddTool(-1, "Export",     $self->icon("output"), wxNullBitmap, wxITEM_NORMAL, q{}, $hints{output});
  $self->{toolbar} -> AddTool(-1, "Clear all",  $self->icon("empty"),  wxNullBitmap, wxITEM_NORMAL, q{}, $hints{clear});
  $self->{toolbar} -> AddSeparator;
  $self->{toolbar} -> AddTool(-1, "Run Atoms",  $self->icon("exec"),   wxNullBitmap, wxITEM_NORMAL, q{}, $hints{exec} );
  EVT_TOOL_ENTER( $self, $self->{toolbar}, sub{my ($toolbar, $event) = @_; &OnToolEnter($toolbar, $event, 'toolbar')} );
  $self->{toolbar} -> Realize;
  $vbox -> Add($self->{toolbar}, 0, wxALL, 5);


  my $hbox = Wx::BoxSizer->new( wxHORIZONTAL );
  $self->{titlesbox}       = Wx::StaticBox->new($self, -1, 'Titles', wxDefaultPosition, wxDefaultSize);
  $self->{titlesboxsizer}  = Wx::StaticBoxSizer->new( $self->{titlesbox}, wxVERTICAL );
  $self->{titles}          = Wx::TextCtrl->new($self, -1, q{}, wxDefaultPosition, wxDefaultSize, wxTE_MULTILINE|wxHSCROLL);
  $self->set_hint("titles");
  $self->{titlesboxsizer} -> Add($self->{titles}, 1, wxGROW|wxALL, 0);
  $hbox -> Add($self->{titlesboxsizer}, 1, wxGROW|wxALL, 5);
  $vbox -> Add($hbox, 0, wxGROW|wxALL);




  $hbox = Wx::BoxSizer->new( wxHORIZONTAL );
  my $leftbox = Wx::BoxSizer->new( wxVERTICAL );
  $hbox -> Add($leftbox, 0, wxGROW|wxALL);


  my $sidebox = Wx::BoxSizer->new( wxVERTICAL );
  $hbox -> Add($sidebox, 0, wxGROW|wxALL);

  my $width = 10;


  ## -------- space group and edge controls
  my $spacebox = Wx::BoxSizer->new( wxVERTICAL );
  $leftbox -> Add($spacebox, 0, wxEXPAND|wxALL, 5);

  my $hh = Wx::BoxSizer->new( wxHORIZONTAL );
  $spacebox -> Add($hh, 0, wxEXPAND|wxALL, 5);
  my $label      = Wx::StaticText->new($self, -1, 'Space Group', wxDefaultPosition, [-1,-1]);
  $self->{space} = Wx::TextCtrl  ->new($self, -1, q{}, wxDefaultPosition, [$width*7,-1]);
  $hh->Add($label,        0, wxEXPAND|wxALL, 5);
  $hh->Add($self->{space}, 0, wxEXPAND|wxALL, 5);

  $hh = Wx::BoxSizer->new( wxHORIZONTAL );
  $spacebox -> Add($hh, 0, wxEXPAND|wxALL, 5);  $label        = Wx::StaticText->new($self, -1, 'Edge', wxDefaultPosition, [-1,-1]);
  $self->{edge} = Wx::Choice    ->new($self, -1, [-1, -1], [-1, -1], ['K', 'L1', 'L2', 'L3'], );
  $hh->Add($label,        0, wxEXPAND|wxALL, 5);
  $hh->Add($self->{edge}, 0, wxEXPAND|wxALL, 5);
  EVT_CHOICE($self, $self->{edge}, \&OnWidgetLeave);

  $hh = Wx::BoxSizer->new( wxHORIZONTAL );
  $spacebox -> Add($hh, 0, wxEXPAND|wxALL, 5);  $label        = Wx::StaticText->new($self, -1, 'Style', wxDefaultPosition, [-1,-1]);
  $self->{template} = Wx::Choice    ->new($self, -1, [-1, -1], [-1, -1], $self->templates, );
  $hh->Add($label,            0, wxEXPAND|wxALL, 5);
  $hh->Add($self->{template}, 0, wxEXPAND|wxALL, 5);
  EVT_CHOICE($self, $self->{template}, \&OnWidgetLeave);

  my $initial = "Feff" . $atoms->co->default("atoms", "feff_version") . " - " . $atoms->co->default("atoms", "ipot_style");
  $self->{template}->SetSelection(firstidx {$_ eq $initial } @{ $self->templates });

  $self->{addbar} = Wx::ToolBar->new($self, -1, wxDefaultPosition, wxDefaultSize, wxTB_VERTICAL|wxTB_3DBUTTONS|wxTB_TEXT);
  EVT_MENU( $self->{addbar}, -1, sub{my ($toolbar, $event) = @_; AddSite($toolbar, $event, $self)} );
  $self->{addbar} -> AddTool(-1, "Add a site", $self->icon("add"),   wxNullBitmap, wxITEM_NORMAL, q{}, $hints{add}  );
  EVT_TOOL_ENTER( $self, $self->{addbar}, sub{my ($toolbar, $event) = @_; &OnToolEnter($toolbar, $event, 'addbar')} );
  $self->{addbar} -> Realize;
  $spacebox -> Add($self->{addbar}, 0, wxALL|wxALIGN_BOTTOM, 5);

  ## -------- end off space group and edge controls



  ## -------- lattice constant controls
  $self->{latticebox}       = Wx::StaticBox->new($self, -1, 'Lattice Constants', wxDefaultPosition, wxDefaultSize);
  $self->{latticeboxsizer}  = Wx::StaticBoxSizer->new( $self->{latticebox}, wxVERTICAL );
  my $tsz = Wx::GridBagSizer->new( 6, 10 );

  $label = Wx::StaticText->new($self, -1, 'A', wxDefaultPosition, [$width,-1]);
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

  $self->{latticeboxsizer} -> Add($tsz, 0, wxGROW|wxALL, 5);
  $sidebox -> Add($self->{latticeboxsizer}, 0, wxGROW|wxALL, 5);
  $vbox -> Add($hbox, 0, wxGROW|wxALL);
  ## -------- end of lattice constant controls


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

  $self->{Rboxsizer} -> Add($tsz, 0, wxGROW|wxALL, 5);
  $sidebox -> Add($self->{Rboxsizer}, 0, wxGROW|wxALL, 5);
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

  $self->{shiftboxsizer} -> Add($tsz, 0, wxGROW|wxALL, 5);
  $sidebox -> Add($self->{shiftboxsizer}, 0, wxGROW|wxALL, 5);
  ## -------- end of R constant controls

  $self->set_hint($_) foreach (qw(a b c alpha beta gamma space rmax rpath shift_x shift_y shift_z edge template));


  $hbox = Wx::BoxSizer->new( wxHORIZONTAL );
  $self->{sitesgrid} = Demeter::UI::Atoms::Xtal::SiteList->new($self, -1);

  $hbox -> Add($self->{sitesgrid}, 1, wxSHAPED|wxALL|wxALIGN_CENTER_HORIZONTAL, 0);
  $vbox -> Add($hbox, 1, wxSHAPED|wxALL|wxALIGN_CENTER_HORIZONTAL, 5);

  $self -> SetSizerAndFit( $vbox );

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
  return ['Feff6 - tags', 'Feff6 - sites', 'Feff6 - elements',
	  'Feff8 - tags', 'Feff8 - sites', 'Feff8 - elements',
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

sub OnToolClick {
  my ($toolbar, $event, $self) = @_;
  ##                 Vv--order of toolbar on the screen--vV
  my @callbacks = qw(open_file save_file write_output clear_all noop run_atoms );
  my $closure = $callbacks[$toolbar->GetToolPos($event->GetId)];
  $self->$closure;
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
  my ($self) = @_;
  my $fd = Wx::FileDialog->new( $self, "Import crystal data", cwd, q{},
				"input file (*.inp)|*.inp|CIF file (*.cif)|*.cif|All files|*.*",
				wxFD_OPEN|wxFD_FILE_MUST_EXIST|wxFD_CHANGE_DIR|wxFD_PREVIEW,
				wxDefaultPosition);
  $fd -> ShowModal;
  my $file = File::Spec->catfile($fd->GetDirectory, $fd->GetFilename);
  $self->clear_all;
  $atoms->file($file);
  $atoms->populate;

  ## load values into their widgets
  my $titles = join($/, (@{ $atoms->titles }));
  $self->{titles}->SetValue($titles);

  foreach my $lc (qw(a b c)) {
    my $this = $atoms->$lc;
    $this = $atoms->a if (($lc =~ m{[bc]}) and ($atoms->$lc < $EPSILON));
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

  my $i= 0;
  my $cell = $atoms->cell;
  foreach my $s (@{ $atoms->sites }) {
    $self->AddSite(0, $self) if ($i >= $self->{sitesgrid}->GetNumberRows);
    my @this = split(/\|/, $s);
    $self->{sitesgrid}->SetCellValue($i, 1, ucfirst(lc($this[0])));
    $self->{sitesgrid}->SetCellValue($i, 2, $this[1]);
    $self->{sitesgrid}->SetCellValue($i, 3, $this[2]);
    $self->{sitesgrid}->SetCellValue($i, 4, $this[3]);
    $self->{sitesgrid}->SetCellValue($i, 5, $this[4]);
    if (lc($this[4]) eq lc($atoms->core)) {
      $self->{sitesgrid}->SetCellValue($i, 0, 1);
    };
    ++$i;
  };
  $self->{statusbar}->SetStatusText("Imported crystal data from $file.");
};

sub get_crystal_data {
  my ($self) = @_;

  $atoms->clear;

  my @titles = split(/\n/, $self->{titles}->GetValue);
  $atoms->titles(\@titles);

  my $this = $self->{space}->GetValue || q{};
  $atoms->space($this);

  foreach my $param (qw(a b c alpha beta gamma rmax rpath)) {
    $this = $self->{$param}->GetValue || 0;
    $atoms->$param($this);
  };

  my @shift = map { $self->{$_}->GetValue || 0 } qw(shift_x shift_y shift_z);
  $atoms->shift(\@shift);

  foreach my $row (0 .. $self->{sitesgrid}->GetNumberRows) {
    next if not is_Element($self->{sitesgrid}->GetCellValue($row, 1));
    $atoms->core($self->{sitesgrid}->GetCellValue($row, 5)) if $self->{sitesgrid}->GetCellValue($row, 0);
    my $this = join("|",
		    $self->{sitesgrid}->GetCellValue($row, 1),
		    $self->{sitesgrid}->GetCellValue($row, 2),
		    $self->{sitesgrid}->GetCellValue($row, 3),
		    $self->{sitesgrid}->GetCellValue($row, 4),
		    $self->{sitesgrid}->GetCellValue($row, 5),
		   );
    $atoms->push_sites($this);
  };

  my $seems_ok = 0;
  $seems_ok = (
	            ($atoms->space)
	       and  ($#{ $atoms->sites } > -1)
	       and  ($atoms->a)
	      );

  return 0 if not $seems_ok;

  $atoms->populate;
  $this = (qw(K L1 L2 L3))[$self->{edge}->GetCurrentSelection] || 'K';
  $atoms->edge($this);

  return 1;
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
      return 90 if ($atoms->$angle < $EPSILON);
      return $atoms->$angle;
      last SWITCH;
    };
  };
  return $atoms->$angle || 0;
};


sub unusable_data {
  my ($self) = @_;
  $self->{statusbar}->SetStatusText("These crystallographic data cannot be processed.");
};

sub save_file {
  my ($self) = @_;
  my $seems_ok = $self->get_crystal_data;
  if ($seems_ok) {
    my $fd = Wx::FileDialog->new( $self, "Export crystal data", cwd, q{atoms.inp},
				  "input file (*.inp)|*.inp|All files|*.*",
				  wxFD_SAVE|wxFD_CHANGE_DIR,
				  wxDefaultPosition);
    $fd -> ShowModal;
    my $file = File::Spec->catfile($fd->GetDirectory, $fd->GetFilename);
    open my $OUT, ">".$file;
    print $OUT $atoms -> Write('atoms');
    close $OUT;
    $self->{statusbar}->SetStatusText("Saved crystal data to $file.");
  } else {
    $self->unusable_data();
  };
};

sub run_atoms {
  my ($self) = @_;
  my $seems_ok = $self->get_crystal_data;
  my $this = (@{ $self->templates })[$self->{template}->GetCurrentSelection] || 'Feff6 - tags';
  my ($template, $style) = split(/ - /, $this);
  $atoms -> ipot_style($style);
  if ($seems_ok) {
    my $busy    = Wx::BusyCursor->new();
    my $save = $atoms->co->default("atoms", "atoms_in_feff");
    $atoms->co->set_default("atoms", "atoms_in_feff", 0);
    $self->{parent}->{Feff}->{feff}->SetValue($atoms -> Write($template));
    $atoms->co->set_default("atoms", "atoms_in_feff", $save);
    undef $busy;
    $self->{parent}->{notebook}->ChangeSelection(1);
  } else {
    $self->unusable_data();
  };
};

sub clear_all {
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
  my $dialog = Wx::SingleChoiceDialog->new( $self, "Output format", "Output format",
					    ["Feff6", "Feff8", "Atoms", "P1", "Symmetry", "Absorption"]
					  );
  if( $dialog->ShowModal == wxID_CANCEL ) {
    $self->{statusbar}->SetStatusText("Output cancelled.");
  } else {
    $self->{statusbar}->SetStatusText("Writing " . $dialog->GetStringSelection . " output.");
  }
};

1;

## Prompt for clear_all with a config parameter for turning prompt off
## Right-click on grid: copy, cut, paste
## Jigger interaction with boolean renderer in grid
