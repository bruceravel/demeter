package  Demeter::UI::Artemis::GDS;

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
use Wx::Grid;
use base qw(Wx::Frame);
use Wx::Event qw(EVT_GRID_CELL_CHANGE EVT_GRID_CELL_RIGHT_CLICK EVT_GRID_LABEL_RIGHT_CLICK EVT_MENU);

my $types = [qw(guess def set skip restrain after penalty merge)];

my %gridcolors = (
		  guess	   => Wx::Colour->new($Demeter::UI::Artemis::demeter->co->default('gds','guess_color'   )),
		  def	   => Wx::Colour->new($Demeter::UI::Artemis::demeter->co->default('gds','def_color'     )),
		  set	   => Wx::Colour->new($Demeter::UI::Artemis::demeter->co->default('gds','set_color'     )),
		  skip	   => Wx::Colour->new($Demeter::UI::Artemis::demeter->co->default('gds','skip_color'    )),
		  restrain => Wx::Colour->new($Demeter::UI::Artemis::demeter->co->default('gds','restrain_color')),
		  after	   => Wx::Colour->new($Demeter::UI::Artemis::demeter->co->default('gds','after_color'   )),
		  penalty  => Wx::Colour->new($Demeter::UI::Artemis::demeter->co->default('gds','penalty_color' )),
		  merge	   => Wx::Colour->new($Demeter::UI::Artemis::demeter->co->default('gds','merge_color'   )),
		 );
  my %hints = (
	       grab	 => "Use the best fit values as rthe initial values for all guess parameters",
	       reset	 => "Restore all parameters to their initial values in Ifeffit",
	       convert	 => "Change all guess parameters to set",
	       discard	 => "Discard all parameters",
	       highlight => "Toggle highlighting of parameters which match a regular expression",
	       import	 => "Import parameters from a text file",
	       export	 => "Export parameters to a text file",
	       addgds	 => "Add space for one more parameter",
	      );


sub new {
  my $class = shift;
  my $this = $class->SUPER::new($_[0], -1, "Artemis: Guess, Def, Set parameters",
				wxDefaultPosition, [-1,-1], #[725,480],
				wxDEFAULT_FRAME_STYLE);
  my $statusbar = $this->CreateStatusBar;
  $statusbar -> SetStatusText(q{});

  my $hbox = Wx::BoxSizer->new( wxHORIZONTAL );




  my $grid = Wx::Grid->new($this, -1, wxDefaultPosition, wxDefaultSize, wxVSCROLL);

  $grid -> CreateGrid(18,4);
  #$grid -> EnableScrolling(1,1);
  #$grid -> SetScrollbars(20, 20, 50, 50);

  $grid -> SetColLabelValue(0, 'Type');
  $grid -> SetColSize      (0,  85);
  $grid -> SetColLabelValue(1, 'Name');
  $grid -> SetColSize      (1,  100);
  $grid -> SetColLabelValue(2, 'Math expression');
  $grid -> SetColSize      (2,  300);
  $grid -> SetColLabelValue(3, 'Evaluated');
  $grid -> SetColSize      (3,  80);

  $grid -> SetRowLabelSize(40);

  foreach my $row (0 .. $grid->GetNumberRows) {
    $grid -> SetCellEditor($row, 0, Wx::GridCellChoiceEditor->new($types));
    $grid -> SetCellValue($row, 0, "guess");
    $grid -> SetReadOnly($row, 3, 1);
    foreach my $c (0 .. $grid->GetNumberCols) { $grid->SetCellTextColour($row, $c, $gridcolors{guess}) };
  };
  EVT_GRID_CELL_CHANGE($grid, \&OnSetType);
  EVT_GRID_CELL_RIGHT_CLICK($grid, \&PostGridMenu);
  EVT_GRID_LABEL_RIGHT_CLICK($grid, \&PostGridMenu);
  EVT_MENU($grid, -1, \&OnGridMenu);

  $hbox -> Add($grid, 1, wxGROW|wxALL, 5);


  my $toolbar = Wx::ToolBar->new($this, -1, wxDefaultPosition, wxDefaultSize,   wxTB_VERTICAL|wxTB_3DBUTTONS|wxTB_TEXT);
  $toolbar -> AddTool(1, "Grab all",    Demeter::UI::Artemis::icon("addgds"),  wxNullBitmap, wxITEM_NORMAL, q{}, $hints{grab} );
  $toolbar -> AddTool(2, "Reset all",   Demeter::UI::Artemis::icon("reset"),   wxNullBitmap, wxITEM_NORMAL, q{}, $hints{reset} );
  #$toolbar -> AddTool(3, "Guess->set",  Demeter::UI::Artemis::icon("convert"), wxNullBitmap, wxITEM_NORMAL, q{}, $hints{convert} );
  #$toolbar -> AddSeparator;
  $toolbar -> AddCheckTool(3, "Highlight",   Demeter::UI::Artemis::icon("highlight"), wxNullBitmap, q{}, $hints{highlight} );
  $toolbar -> AddTool(4, "Import GDS",  Demeter::UI::Artemis::icon("import"), wxNullBitmap, wxITEM_NORMAL, q{},  $hints{import});
  $toolbar -> AddTool(5, "Export GDS",  Demeter::UI::Artemis::icon("export"), wxNullBitmap, wxITEM_NORMAL, q{},  $hints{export});
  $toolbar -> AddSeparator;
  $toolbar -> AddTool(6, "Discard all", Demeter::UI::Artemis::icon("discard"), wxNullBitmap, wxITEM_NORMAL, q{}, $hints{discard} );
  $toolbar -> AddSeparator;
  $toolbar -> AddTool(7, "Add GDS",     Demeter::UI::Artemis::icon("addgds"),  wxNullBitmap, wxITEM_NORMAL, q{}, $hints{addgds} );
  $toolbar -> Realize;
  $hbox -> Add($toolbar, 0, wxSHAPED|wxALL|wxALIGN_CENTER_HORIZONTAL, 5);

  $this -> SetSizerAndFit( $hbox );
  $this -> SetMinSize($this->GetSize);
  $this -> SetMaxSize($this->GetSize);
  return $this;
};

sub noop {};

sub OnSetType {
  my ($self, $event) = @_;
  if ($event->GetCol == 0) {
    my $row = $event->GetRow;
    my $newval = $self->GetCellValue($row, 0);
    foreach my $c (0 .. $self->GetNumberCols) { $self->SetCellTextColour($row, $c, $gridcolors{$newval}) };
  };
};

sub PostGridMenu {
  my ($self, $event) = @_;
  my $row = $event->GetRow;
  return if ($row < 0);
  my $this = $self->GetCellValue($row, 1) || "current row";

  my $change = Wx::Menu->new(q{});
  my $ind = 100;
  foreach my $t (@$types) {
    next if ($t eq 'merge');
    $change->Append($ind++, $t);
  };

  my $menu = Wx::Menu->new(q{});
  $menu->Append	         (0,	    "Copy $this");
  $menu->Append	         (1,	    "Cut $this");
  $menu->Append	         (2,	    "Paste above $this");
  $menu->AppendSeparator;
  $menu->Append	         (4,	    "Grab best fit for $this");
  $menu->AppendSubMenu   ($change,  "Change selected to");
  $menu->Append	         (6,	    "Build restraint from $this");
  $menu->Append	         (7,	    "Annotate $this");
  $menu->AppendSeparator;
  $menu->Append	         (9,	    "Find where $this is used");
  $menu->Append	         (10,	    "Rename $this globally");
  $self->SelectRow($row, 1);
  $self->PopupMenu($menu, $event->GetPosition);
};

sub OnGridMenu {
  my ($self, $event) = @_;
  my $which = $event->GetId;
  if ($which < 100) {
    my @callbacks = qw(copy cut paste noop grab set_type build_restraint annotate noop find global);
    print $which, ":  perform ", $callbacks[$which], $/;
  } else {
    my $i = $which - 100;
    print $which, ":  change selected to ", $types->[$i], $/;
  };
};

1;
