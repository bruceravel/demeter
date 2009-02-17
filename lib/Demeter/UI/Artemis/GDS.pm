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

use strict;
use warnings;

use Wx qw( :everything );
use Wx::DND;
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
	       grab	 => "Use the best fit values from the last fit as the initial values for all guess parameters",
	       reset	 => "Restore all parameters to their initial values in Ifeffit",
	       convert	 => "Change all guess parameters to set",
	       discard	 => "Discard all parameters",
	       highlight => "Toggle highlighting of parameters which match a regular expression",
	       import	 => "Import parameters from a text file",
	       export	 => "Export parameters to a text file",
	       addgds	 => "Add space for one more parameter",
	      );


sub new {
  my ($class, $parent) = @_;
  my $this = $class->SUPER::new($parent, -1, "Artemis: Guess, Def, Set parameters",
				wxDefaultPosition, [-1,-1], #[725,480],
				wxMINIMIZE_BOX|wxCAPTION|wxSYSTEM_MENU|wxRESIZE_BORDER);
  $this->{statusbar} = $this->CreateStatusBar;
  $this->{statusbar} -> SetStatusText(q{});

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

  $grid -> SetDropTarget( Demeter::UI::Artemis::GDS::TextDropTarget->new( $grid, $this ) );

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
  $toolbar -> AddCheckTool(3, "Highlight",   Demeter::UI::Artemis::icon("highlight"), wxNullBitmap, q{}, $hints{highlight} );
  $toolbar -> AddSeparator;
  $toolbar -> AddTool(4, "Import GDS",  Demeter::UI::Artemis::icon("import"), wxNullBitmap, wxITEM_NORMAL, q{},  $hints{import});
  $toolbar -> AddTool(5, "Export GDS",  Demeter::UI::Artemis::icon("export"), wxNullBitmap, wxITEM_NORMAL, q{},  $hints{export});
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
    foreach my $c (0 .. $self->GetNumberCols) {
      if ($newval eq 'merge') {
	$self->SetCellBackgroundColour($row, $c, $gridcolors{merge});
	$self->SetCellTextColour($row, $c, wxWHITE);
      } else {
	$self->SetCellBackgroundColour($row, $c, wxNullColour);
	$self->SetCellTextColour($row, $c, $gridcolors{$newval});
      };
    };
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

  ## test for how many are selected
  my $menu = Wx::Menu->new(q{});
  $menu->Append	         (0,	    "Copy $this");        # or selected
  $menu->Append	         (1,	    "Cut $this");         # or selected
  $menu->Append	         (2,	    "Paste above $this"); # or selected
  $menu->AppendSeparator;
  $menu->Append	         (4,	    "Insert blank line above $this");
  $menu->Append	         (5,	    "Insert blank line below $this");
  $menu->AppendSeparator;
  $menu->AppendSubMenu   ($change,  "Change selected to");      # or selected
  $menu->Append	         (8,	    "Grab best fit for $this"); # or selected
  $menu->Append	         (9,	    "Build restraint from $this");
  $menu->Append	         (10,	    "Annotate $this");
  $menu->AppendSeparator;
  $menu->Append	         (12,	    "Find where $this is used");
  $menu->Append	         (13,	    "Rename $this globally");
  $self->SelectRow($row, 1);
  $self->PopupMenu($menu, $event->GetPosition);
};

sub OnGridMenu {
  my ($self, $event) = @_;
  my $which = $event->GetId;
  if ($which < 100) {
    ##                  0    1    2     3        4            5       6      7       8       9             10     11   12    13
    my @callbacks = qw(copy cut paste noop insert_above insert_below noop set_type grab build_restraint annotate noop find global);
    print $which, ":  perform ", $callbacks[$which], $/;
  } else {
    my $i = $which - 100;
    print $which, ":  change selected to ", $types->[$i], $/;
  };
};



package Demeter::UI::Artemis::GDS::TextDropTarget;

use strict;
use warnings;

use Wx qw( :everything );
use base qw(Wx::TextDropTarget);

sub new {
  my $class  = shift;
  my $grid   = shift;
  my $parent = shift;
  my $this = $class->SUPER::new( @_ );
  $this->{GRID} = $grid;
  $this->{PARENT} = $parent;
  return $this;
};

sub OnDropText {
  my ($this, $x, $y, $text) = @_;
  my $grid   = $this->{GRID};
  my $parent = $this->{PARENT};
  my $drop   = $grid->YToRow($y) - 1;
  ($drop = 0) if ($drop < 0);
  my $rownum = $drop + 1;

  #print join("|", $y, $grid->YToRow($y), $drop, $rownum), $/;
  #return 1;

  $text =~ s{\A\s+}{};		# leading and training white space
  $text =~ s{\s+\z}{};

  ## text with white space
  if ($text =~ m{\s}) {
    $parent->{statusbar}->SetStatusText("Ifeffit guess/def/set parameters names cannot have white space ($text)");

  ## text starting with a number
  } elsif ($text =~ m{\A\d}) {
    $parent->{statusbar}->SetStatusText("Ifeffit guess/def/set parameters names cannot start with numbers ($text)");

  ## text with unallowed characters
  } elsif ($text =~ m{[^a-z0-9_?]}i) {
    $parent->{statusbar}->SetStatusText("Ifeffit guess/def/set parameters names can only use [a-z0-9_?] ($text)");

  ## row already has a parameter in it
  } elsif ($grid -> GetCellValue($drop, 1) !~ m{\A\s*\z}) {
    my $yesno = Wx::MessageDialog->new($parent,
				       sprintf("Replace %s with %s?", $grid -> GetCellValue($drop, 1), $text),
				       "Replace parameter?",
				       wxYES_NO|wxNO_DEFAULT|wxICON_QUESTION);
    if ($yesno->ShowModal == wxID_NO) {
      return 1;
    } else {
      $grid -> SetCellValue($drop, 1, $text);
      $parent->{statusbar}->SetStatusText("Dropped \"$text\" into row $rownum");
    };

  ## just drop it
  } else {
   $grid -> SetCellValue($drop, 1, $text);
   $parent->{statusbar}->SetStatusText("Dropped \"$text\" into row $rownum");
 };
  return 1;
}



1;
