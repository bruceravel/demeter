package  Demeter::UI::Artemis::GDS;

=for Copyright
 .
 Copyright (c) 2006-2012 Bruce Ravel (bravel AT bnl DOT gov).
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

use Cwd;
use File::Spec;
use List::MoreUtils qw(uniq any);
use Scalar::Util qw(looks_like_number);

use Demeter::Constants qw($SEPARATOR);
use Const::Fast;
## 0:grab all  1:reset all  2:toggle highlight  4:import   5:export  6:discard all  8:add one
const my $GRAB	      => 0;
const my $RESET	      => 1;
const my $HIGHLIGHT   => 2;
const my $IMPORT      => 4;
const my $EXPORT      => 5;
const my $DISCARD     => 6;
const my $ADD	      => 8;
const my $PARAM_REGEX => '(guess|def|set|lguess|restrain|after|skip|penalty|merge)';

const my $GUESS	      => Wx::NewId();
const my $LGUESS      => Wx::NewId();
const my $SET	      => Wx::NewId();
const my $DEF	      => Wx::NewId();
const my $SKIP	      => Wx::NewId();
const my $AFTER	      => Wx::NewId();
const my $RESTRAIN    => Wx::NewId();
const my $PENALTY     => Wx::NewId();

use Wx qw( :everything );
use Wx::DND;
use Wx::Grid;
use base qw(Wx::Frame);
use Wx::Event qw(EVT_CLOSE EVT_ICONIZE EVT_GRID_CELL_CHANGE EVT_GRID_CELL_RIGHT_CLICK EVT_MENU
		 EVT_GRID_LABEL_LEFT_CLICK EVT_GRID_LABEL_RIGHT_CLICK EVT_GRID_RANGE_SELECT
		 EVT_GRID_SELECT_CELL EVT_GRID_CELL_CHANGE);

use Demeter::UI::Artemis::Close;
use Demeter::UI::Artemis::GDS::Restraint;
use Demeter::UI::Artemis::ShowText;
use Demeter::StrTypes qw( GDS );


my $types = [qw(guess def set lguess skip restrain after penalty merge)];

my %gridcolors = (
		  guess	   => Wx::Colour->new($Demeter::UI::Artemis::demeter->co->default('gds','guess_color'   )),
		  def	   => Wx::Colour->new($Demeter::UI::Artemis::demeter->co->default('gds','def_color'     )),
		  set	   => Wx::Colour->new($Demeter::UI::Artemis::demeter->co->default('gds','set_color'     )),
		  lguess   => Wx::Colour->new($Demeter::UI::Artemis::demeter->co->default('gds','lguess_color'  )),
		  skip	   => Wx::Colour->new($Demeter::UI::Artemis::demeter->co->default('gds','skip_color'    )),
		  restrain => Wx::Colour->new($Demeter::UI::Artemis::demeter->co->default('gds','restrain_color')),
		  after	   => Wx::Colour->new($Demeter::UI::Artemis::demeter->co->default('gds','after_color'   )),
		  penalty  => Wx::Colour->new($Demeter::UI::Artemis::demeter->co->default('gds','penalty_color' )),
		  merge	   => Wx::Colour->new($Demeter::UI::Artemis::demeter->co->default('gds','merge_color'   )),
		 );
my %explain = (#                                                                                                                V
	       guess	 => "A parameter that is varied in the fit",
	       def	 => "A parameter that is functionally dependent on guess parameter(s) \& is reevaluated throughout the fit",
	       set	 => "A parameter that is evaluated at the beginning of the fit and not varied further",
	       lguess	 => "A guess parameter that is varied independently for each data set for which it is used",
	       skip	 => "A parameter that is ignored in the fit but retained in the project",
	       restrain	 => "A parameter expressing prior knowledge of the fit model and added in quadrature to the fitting metric",
	       after	 => "A parameter that will be evaluated once the fit is finished and reported in the log file",
	       penalty	 => "A parameter that is evaluated and used as a penalty against the happiness of the fit",
	       merge	 => "A parameter from a merging of fit projects whose name poses a conflict and which much be resolved",
	      );
my %hints = (
	     grab      => "Use the best fit values from the last fit as the initial values for all guess parameters",
	     reset     => "Restore all parameters to their initial values in ".Demeter->backend_name,
	     convert   => "Change all guess parameters to set",
	     discard   => "Discard all parameters",
	     highlight => "Toggle highlighting of parameters which match a regular expression",
	     import    => "Import parameters from a text file",
	     export    => "Export parameters to a text file",
	     addgds    => "Add space for one more parameter",
	    );


sub new {
  my ($class, $parent) = @_;
  my $this = $class->SUPER::new($parent, -1, "Artemis [GDS] Guess, Def, Set parameters",
				wxDefaultPosition, [-1,-1], #[725,480],
				wxMINIMIZE_BOX|wxCAPTION|wxSYSTEM_MENU|wxCLOSE_BOX|wxRESIZE_BORDER);
  $this -> SetBackgroundColour( wxNullColour );
  $this->{statusbar} = $this->CreateStatusBar;
  $this->{statusbar} -> SetStatusText(q{});
  $this->{uptodate}  = 1;
  EVT_CLOSE($this, \&on_close);
  EVT_ICONIZE($this, \&on_close);

  my $hbox = Wx::BoxSizer->new( wxHORIZONTAL );




  my $grid = Wx::Grid->new($this, -1, wxDefaultPosition, wxDefaultSize, wxALWAYS_SHOW_SB);
  $this->{grid} = $grid;
  $this->{buffer} = q{};

  $grid -> CreateGrid(12,4,wxGridSelectRows);

  $grid -> SetColLabelValue (0, 'Type');
  $grid -> SetColSize       (0,  85);
  $grid -> SetColLabelValue (1, 'Name');
  $grid -> SetColSize       (1,  100);
  $grid -> SetColLabelValue (2, 'Math expression');
  $grid -> SetColSize       (2,  330);
  #$grid -> SetColFormatFloat(2, -1, 5);
  $grid -> SetColLabelValue (3, 'Evaluated');
  $grid -> SetColSize       (3,  150);

  $grid -> SetRowLabelSize(40);

  $grid -> SetDropTarget( Demeter::UI::Artemis::GDS::TextDropTarget->new( $grid, $this ) );

  foreach my $row (0 .. $grid->GetNumberRows) {
    $this->initialize_row($row);
  };

  my $accelerator = Wx::AcceleratorTable->new(
   					      [wxACCEL_ALT, 103, $GUESS],
   					      [wxACCEL_ALT, 115, $SET],
   					      [wxACCEL_ALT, 100, $DEF],
   					      [wxACCEL_ALT, 107, $SKIP],
   					      [wxACCEL_ALT,  97, $AFTER],
   					      [wxACCEL_ALT, 108, $LGUESS],
   					      [wxACCEL_ALT, 112, $PENALTY],
   					      [wxACCEL_ALT, 114, $RESTRAIN],
   					     );
  $grid->SetAcceleratorTable( $accelerator );

  EVT_GRID_CELL_CHANGE      ($grid,     sub{ $this->OnSetType(@_)      });
  EVT_GRID_CELL_RIGHT_CLICK ($grid,     sub{ $this->PostGridMenu(@_, 0)});
  EVT_GRID_LABEL_LEFT_CLICK ($grid,     sub{ $this->StartDrag(@_)      });
  EVT_GRID_LABEL_RIGHT_CLICK($grid,     sub{ $this->PostGridMenu(@_, 1)});
  EVT_MENU                  ($grid, -1, sub{ $this->OnGridMenu(@_)     });
  EVT_GRID_RANGE_SELECT     ($grid,     sub{ $this->OnRangeSelect(@_)  });
  EVT_GRID_SELECT_CELL      ($grid,     sub{ $this->OnRowSelect(@_)    });
  EVT_GRID_CELL_CHANGE      ($grid,     sub{ $this->OnCellChange(@_)   });

  $hbox -> Add($grid, 1, wxGROW|wxALL, 5);


  $this->{toolbar} = Wx::ToolBar->new($this, -1, wxDefaultPosition, wxDefaultSize,   wxTB_VERTICAL|wxTB_3DBUTTONS|wxTB_HORZ_LAYOUT|wxTB_TEXT);
  $this->{toolbar} -> AddTool(-1, " Use best fit", Demeter::UI::Artemis::icon("bestfit"),  wxNullBitmap, wxITEM_NORMAL, q{}, $hints{grab} );
  $this->{toolbar} -> AddTool(-1, "Reset all",     Demeter::UI::Artemis::icon("reset"),   wxNullBitmap, wxITEM_NORMAL, q{}, $hints{reset} );
  $this->{toolbar} -> AddCheckTool($HIGHLIGHT, "Highlight",   Demeter::UI::Artemis::icon("highlight"), wxNullBitmap, q{}, $hints{highlight} );
  $this->{toolbar} -> AddSeparator;
  $this->{toolbar} -> AddTool(-1, " Import GDS",   Demeter::UI::Artemis::icon("import"), wxNullBitmap, wxITEM_NORMAL, q{},  $hints{import});
  $this->{toolbar} -> AddTool(-1, " Export GDS",   Demeter::UI::Artemis::icon("export"), wxNullBitmap, wxITEM_NORMAL, q{},  $hints{export});
  $this->{toolbar} -> AddTool(-1, "Discard all",   Demeter::UI::Artemis::icon("discard"), wxNullBitmap, wxITEM_NORMAL, q{}, $hints{discard} );
  $this->{toolbar} -> AddSeparator;
  $this->{toolbar} -> AddTool(-1, "Add GDS",       Demeter::UI::Artemis::icon("addgds"),  wxNullBitmap, wxITEM_NORMAL, q{}, $hints{addgds} );
  $this->{toolbar} -> Realize;
  $hbox -> Add($this->{toolbar}, 0, wxSHAPED|wxALL, 5);

  EVT_MENU($this->{toolbar}, -1, sub{ $this->OnToolClick(@_, $grid) } );

  $this -> SetSizerAndFit( $hbox );
  my ($xx, $yy) = $this->GetSizeWH;
  $this -> SetMinSize(Wx::Size->new($xx, 1.1*$yy));
  $this -> SetMaxSize(Wx::Size->new($xx, 1.1*$yy));
  return $this;
};

sub noop {};

# sub on_close {
#   my ($self) = @_;
#   $self->Show(0);
#   $self->GetParent->{toolbar}->ToggleTool(1, 0);
# };

sub initialize_row {
  my ($parent, $row) = @_;
  $parent->{grid} -> SetCellEditor($row, 0, Wx::GridCellChoiceEditor->new($types));
  $parent->{grid} -> SetCellValue($row, 0, "guess");
  $parent->{grid} -> SetReadOnly($row, 3, 1);
  foreach my $c (0 .. $parent->{grid}->GetNumberCols) { $parent->{grid}->SetCellTextColour($row, $c, $gridcolors{guess}) };
};

######## Toolbar section ############################################################

sub OnToolClick {
  my ($parent, $toolbar, $event, $grid) = @_;
  ## 0:grab all  1:reset all  2:toggle highlight  4:import   5:export  6:discard all  8:add one
  my $which = $toolbar->GetToolPos($event->GetId); # || $event->GetId;
 SWITCH: {
    ($which == $GRAB) and do {	     # grab best fit values
      $parent->use_best_fit;
      last SWITCH;
    };

    ($which == $RESET) and do {	     # reset all
      $parent->reset_all;
      last SWITCH;
    };

    ($which == $HIGHLIGHT) and do {  # toggle highlight
      $parent->highlight;
      last SWITCH;
    };

    ($which == $IMPORT) and do {     # import from text
      $parent->import;
      last SWITCH;
    };

    ($which == $EXPORT) and do {     # export to text
      $parent->export;
      last SWITCH;
    };

    ($which == $DISCARD) and do {    # discard all
      $parent->discard_all;
      last SWITCH;
    };

    ($which == $ADD) and do {	     # add a line
      $grid->AppendRows(1,1);
      $parent->initialize_row( $grid->GetNumberRows - 1 );
      $parent->{grid}->ClearSelection;
      last SWITCH;
    };
  };
};

sub OnMenu {
  my ($self, $event) = @_;
  my $id = $event->GetId;
  print join("|", $event, $id), $/;
};


sub use_best_fit {
  my ($parent) = @_;
  my $grid = $parent->{grid};
  my $count = 0;
  foreach my $row (0 .. $grid->GetNumberRows) {
    my $type = $grid->GetCellValue($row, 0);
    next unless ($type eq 'guess');
    my $evaluated = $grid->GetCellValue($row, 3);
    next unless ($evaluated !~ m{\A\s*\z});
    $evaluated =~ s{\+/-\s*.*}{};
    $grid->SetCellValue($row, 2, $parent->display_value($evaluated));
    $grid->SetCellValue($row, 3, q{});
    ++$count;
  };
  if ($count) {
    $parent->status("Using best fit values as the new initial guesses.");
    $parent->{uptodate} = 0;
    return 1;
  };
  $parent->status("Not using best fit values -- have you done a fit yet?");
  return 0;
};

#  print join("|",  1, map {$_->group} @{ Demeter->mo->GDS }), $/;

sub reset_all {
  my ($parent, $no_ifeffit, $renew) = @_;
  $no_ifeffit ||= 0;
  $renew      ||= 0;
  my $grid = $parent->{grid};
  my @gds = ();
  foreach my $row (0 .. $grid->GetNumberRows) {
    my $name = $grid -> GetCellValue($row, 1);
    next if ($name =~ m{\A\s*\z});
    $name =~ s{\A\s+}{};
    $name =~ s{\s+\z}{};
    $grid -> SetCellValue($row, 1, $name);
    my $type = $grid -> GetCellValue($row, 0);
    my $mathexp = $grid -> GetCellValue($row, 2);
    my $thisgds;
    if ($renew or (not defined $grid->{$name})) {
      $thisgds = Demeter::GDS->new();
      $grid->SetCellValue($row, 3, q{});
    } else {
      $thisgds = $grid->{$name};
    };
    $thisgds -> set(name=>$name, gds=>$type, mathexp=>$mathexp);
    $grid->{$name} = $thisgds;
    push @gds, $thisgds;
    $thisgds->push_ifeffit if (not $no_ifeffit);
  };
  $parent->{uptodate} = 1;
  $parent->status("Reset all parameter values in ".Demeter->backend_name.".") if (not $no_ifeffit);
  return \@gds;
};


sub highlight {
  my ($parent) = @_;
  my $is_down = $parent->{toolbar}->GetToolState($HIGHLIGHT);
  ($is_down) ? $parent->set_highlight : $parent->clear_highlight;
  $parent->status("Cleared all highlights.") if not $is_down;
  return $parent;
};

sub set_highlight {
  my ($parent, $regex) = @_;
  my $grid = $parent->{grid};
  if (not $regex) {
    my $ted = Wx::TextEntryDialog->new( $parent, "Enter a regular expression", "Highlight parameters matching", q{}, wxOK|wxCANCEL, Wx::GetMousePosition);
    if ($ted->ShowModal == wxID_CANCEL) {
      $parent->status("Parameter highlighting cancelled.");
      $parent->{toolbar}->ToggleTool($HIGHLIGHT, 0);
      return;
    };
    $regex = $ted->GetValue;
    if ($regex =~ m{\A\s*\z}) {
      $parent->status("Parameter highlighting cancelled (no regular expression provided).");
      $parent->{toolbar}->ToggleTool($HIGHLIGHT, 0);
      return;
    };
  };
  my $re;
  my $is_ok = eval '$re = qr/$regex/i';
  if (not $is_ok) {
    $parent->status("Oops!  \"$regex\" is not a valid regular expression");
    $parent->{toolbar}->ToggleTool($HIGHLIGHT, 0);
    return;
  };
  $parent->clear_highlight;
  foreach my $row (0 .. $grid->GetNumberRows) {
    next if ($grid -> GetCellValue($row, 0) eq 'merge');
    my $name = $grid -> GetCellValue($row, 1);
    next if ($name =~ m{\A\s*\z});
    my $mathexp = $grid -> GetCellValue($row, 2);
    if (($name =~ $re) or ($mathexp =~ m{\b$re\b})) {
      ## set GDS object highlighted attribute to 1 -- do I *really* need to do this...
      foreach my $col (0 .. $grid->GetNumberCols) {
	$grid->SetCellBackgroundColour($row, $col, Wx::Colour->new($Demeter::UI::Artemis::demeter->co->default('gds','highlight_color')));
      };
    };
  };
  $grid -> ForceRefresh;
  $parent->status("Highlighted parameters matching /$regex/.") if $parent;
};
sub clear_highlight {
  my ($parent) = @_;
  my $grid = $parent->{grid};
  foreach my $row (0 .. $grid->GetNumberRows) {
    next if ($grid -> GetCellValue($row, 0) eq 'merge');
    map { $grid->SetCellBackgroundColour($row, $_, wxNullColour)} (0 .. 3);
  };
  $grid -> ForceRefresh;
};

sub find_next_empty_row {
  my ($parent) = @_;
  my $grid = $parent->{grid};
  my $start = $grid->GetNumberRows;
  foreach my $row (reverse(0 .. $grid->GetNumberRows)) {
    last if ($grid->GetCellValue($row, 1) or $grid->GetCellValue($row, 2));
    $start = $row;
  };
  return $start;
};

sub put_gds {
  my ($parent, $gds) = @_;
  $parent->put_param($gds->gds, $gds->name, $gds->mathexp);
  $parent->{grid} -> {$gds->name} = $gds;
  $parent->{uptodate} = 0;
};

sub put_param {
  my ($parent, $type, $name, $mathexp) = @_;
  my $grid = $parent->{grid};
  $type = 'merge' if $parent->param_present($name);
  my $start = $parent->find_next_empty_row;
  if ($start >= $grid->GetNumberRows) {
    $grid   -> AppendRows(1,1);
    $parent -> initialize_row( $grid->GetNumberRows - 1 );
  };
  $grid   -> SetCellValue($start, 0, $type);
  $grid   -> SetCellValue($start, 1, $name);
  $grid   -> SetCellValue($start, 2, $parent->display_value($mathexp));
  $parent -> tie_GDS_to_grid($start);
  $parent -> set_type($start);
};

sub param_present {
  my ($parent, $name) = @_;
  my $grid = $parent->{grid};
  foreach my $row (0 .. $grid->GetNumberRows) {
    return 1 if (lc($grid->GetCellValue($row, 1)) eq lc($name));
  };
  return 0;
};

sub display_value {
  my ($self, $string) = @_;
  my $n = Demeter->co->default("gds", "display_precision");
  my $patternf = '%.'.$n.'f';
  my $patterne = '%.'.$n.'e';
  if (looks_like_number($string)) {
    if ($string == 0) {
      return 0;
    } elsif (abs($string) > 0.00001) {
      return sprintf($patternf, $string);
    } else {
      return sprintf($patterne, $string);
    };
  } else {
    return $string;
  };
};

sub import {
  my ($parent) = @_;
  my $grid = $parent->{grid};
  my $fd = Wx::FileDialog->new( $parent, "Import parameters from a text file", cwd, q{},
				"Text file|*.txt|All files|*",
				wxFD_OPEN|wxFD_FILE_MUST_EXIST|wxFD_CHANGE_DIR|wxFD_PREVIEW,
				wxDefaultPosition);
  if ($fd -> ShowModal == wxID_CANCEL) {
    $parent->status("Parameter import aborted.")
  } else {
    my $file = File::Spec->catfile($fd->GetDirectory, $fd->GetFilename);
    my $comment = qr([!#%]);

    my $start = $parent->find_next_empty_row;

    my $count = 0;
    open(my $PARAM, $file);
    foreach my $line (<$PARAM>) {
      ++$count;
      next unless ($line =~ m{\A$PARAM_REGEX});

      if ($start >= $grid->GetNumberRows) {
	$grid   -> AppendRows(1,1);
	$parent -> initialize_row( $grid->GetNumberRows - 1 );
      };

      $line =~ s{$comment.*\z}{};	# strip comments
      $line =~ s{\s+\z}{};
      my ($gds, $name, @rest) = split(/$SEPARATOR/, $line);
      my $mathexp = join(" ", @rest);
      if (not is_GDS($gds)) {
	my $ok = Wx::MessageDialog->new($parent,
					"$gds is not a parameter type at line $count\n($gds $name = $mathexp)",
					"Bad parameter type",
					wxOK|wxICON_ERROR) -> ShowModal;
	next;
      };
      $parent->put_param($gds, $name, $mathexp);
    };
    close $PARAM;
  };

};
sub export {
  my ($parent) = @_;
  my $grid = $parent->{grid};

  my $fd = Wx::FileDialog->new( $parent, "Export parameters to a text file", cwd, q{},
				"Text file|*.txt|All files|*", wxFD_SAVE|wxFD_CHANGE_DIR, #|wxFD_OVERWRITE_PROMPT,
				wxDefaultPosition);
  if ($fd -> ShowModal == wxID_CANCEL) {
    $parent->status("Parameter export aborted.");
    return 0;
  } else {
    my $file = $fd->GetPath;
    return if $parent->overwrite_prompt($file); # work-around gtk's wxFD_OVERWRITE_PROMPT bug (5 Jan 2011)
    open(my $PARAM, '>'.$file);
    foreach my $row (0 .. $grid->GetNumberRows-1) {
      my $thisgds = $parent->tie_GDS_to_grid($row);
      next if not $thisgds;
      print $PARAM $thisgds->template("process", "gds_out");
    };
    close $PARAM;
    $parent->status("Exported parameters to \"$file\".")
  };
};

sub tie_GDS_to_grid {
  my ($parent, $row) = @_;
  my $grid = $parent->{grid};
  my $name = $grid -> GetCellValue($row, 1);
  return 0 if ($name =~ m{\A\s*\z});
  my $type = $grid -> GetCellValue($row, 0);
  my $mathexp = $grid -> GetCellValue($row, 2);
  my $thisgds = $grid->{$name} || Demeter::GDS->new(); # take care to reuse GDS objects whenever possible
  $thisgds -> set(name=>$name, gds=>$type, mathexp=>$mathexp);
  $grid->{$name} = $thisgds;
  return $thisgds;
};


sub discard_all {
  my ($parent, $force) = @_;
  my $grid = $parent->{grid};
  if (not $force) {
    my $yesno = Wx::MessageDialog->new($parent,
				       "Really throw away all parameters?",
				       "Verify action",
				       wxYES_NO|wxNO_DEFAULT|wxICON_QUESTION);
    if ($yesno->ShowModal == wxID_NO) {
      $parent->status("Not discarding parameters.");
      return 0;
    };
  };
  foreach my $row (0 .. $grid->GetNumberRows-1) {
    $parent->discard($row);
  };
  $parent->status("Discarded all parameters.")
};
sub discard {
  my ($parent, $row) = @_;
  my $grid = $parent->{grid};
  $grid -> SetCellValue($row, 0, 'guess');
  $parent->set_type($row);
  my $name = $grid->GetCellValue($row, 1);
  $grid -> SetCellValue($row, 1, q{});
  $grid -> SetCellValue($row, 2, q{});
  $grid -> SetCellValue($row, 3, q{});
  if ((exists $grid->{$name}) and ($grid->{$name} =~ m{GDS})) {
    $grid->{$name}->dispense('process', 'erase', {items=>$grid->{$name}->name});
    $grid->{$name}->DEMOLISH;
    delete $grid->{$name};
  };
};

sub OnSetType {
  my ($parent, $self, $event) = @_;
  if ($event->GetCol == 0) {
    my $row = $event->GetRow;
    $parent->set_type($row);
    $parent->{grid}->ClearSelection;
  };
};
sub set_type {
  my ($parent, $row) = @_;
  my $grid = $parent->{grid};
  my $newval = $grid->GetCellValue($row, 0);
  foreach my $c (0 .. $grid->GetNumberCols) {
    if ($newval eq 'merge') {
      $grid->SetCellBackgroundColour($row, $c, $gridcolors{merge});
      $grid->SetCellTextColour($row, $c, wxWHITE);
    } else {
      $grid->SetCellBackgroundColour($row, $c, wxNullColour);
      $grid->SetCellTextColour($row, $c, $gridcolors{$newval});
    };
  };
};

## show annotation in the status line. this is particularly useful
## after the reset all button is pressed, deleting the contents of
## column 3.  with this the annotation from the last fit is shown, so
## the previous best fit value can be known even afetr a reset
sub OnRowSelect {
  my ($parent, $self, $event) = @_;
  my $row = $event->GetRow;
  my $grid = $parent->{grid};
  my $name = $grid -> GetCellValue($row, 1);
  $event->Skip, return if not $name;
  $event->Skip, return if not defined($grid->{$name});
  $parent->{statusbar}->SetStatusText($grid->{$name}->note);
  $event->Skip;
};

sub OnCellChange {
  my ($parent, $self, $event) = @_;
  #print join("|", $parent, $self, $event), $/;
  $parent->{uptodate} = 0;
  $event->Skip;
};


######## Context menu section ############################################################

sub OnRangeSelect {
  my ($parent, $self, $event) = @_;
  return unless $event->Selecting;
  $parent->{grid}->SelectBlock($event->GetTopLeftCoords, $event->GetBottomRightCoords, 1);
  $parent->{grid}->ForceRefresh;
  $event->Skip;
};
sub PostGridMenu {
  my ($parent, $self, $event, $is_label) = @_;
  my $row = $event->GetRow;
  return if ($row < 0);
  $parent->{clicked_row} = $row;
  my $this = $self->GetCellValue($row, 1) || "current row";

  if ($is_label) {
    $parent->{grid}->ClearSelection;
    $parent->{grid}->SelectRow($row);
  };

  my @sel = grep {$parent->{grid}->IsInSelection($_,0)} (0 .. $parent->{grid}->GetNumberRows-1);
  my $which = ($#sel > 0) ? 'selected' : $this;
  @sel = sort {$a <=> $b} uniq(@sel, $row);
  $parent->{selected} = \@sel;

  my $change = Wx::Menu->new(q{});
  my $ind = 100;
  foreach my $t (@$types) {
    next if ($t eq 'merge');
    $change->Append($ind++, $t);
  };
  my $explain = Wx::Menu->new(q{});
  $ind = 200;
  foreach my $t (@$types) {
    $explain->Append($ind++, $t);
  };

  ## test for how many are selected
  my $menu = Wx::Menu->new(q{});
  $menu->Append	         (0,	    "Copy $which");        # or selected
  $menu->Append	         (1,	    "Cut $which");         # or selected
  $menu->Append	         (2,	    "Paste below $this");  # or selected
  $menu->AppendSeparator;
  $menu->Append	         (4,	    "Insert blank line above $this");
  $menu->Append	         (5,	    "Insert blank line below $this");
  $menu->AppendSeparator;
  $menu->AppendSubMenu   ($change,  "Change $which to");         # or selected
  $menu->Append	         (8,	    "Grab best fit for $which"); # or selected
  $menu->Append	         (9,	    "Build restraint from $this");
  $menu->Append	         (10,	    "Annotate $this");
  $menu->AppendSeparator;
  $menu->Append	         (12,	    "Find where $this is used");
  $menu->Append	         (13,	    "Rename $this globally");
  $menu->AppendSeparator;
  $menu->AppendSubMenu   ($explain, "Explain");
  $self->SelectRow($row, 1);

  if (($which =~ m{\A\s*\z}) or ($which eq 'current row')) {
    $menu->Enable($_,0) foreach (0, 8, 9, 10, 12, 13);
  };
  $self->PopupMenu($menu, $event->GetPosition);
};

sub OnGridMenu {
  my ($parent, $self, $event) = @_;
  my $which = $event->GetId;
  if (any {$which == $_} ($GUESS, $SET, $DEF, $LGUESS, $AFTER, $RESTRAIN, $PENALTY, $SKIP)) {
    my $t = ($which == $GUESS)    ? "guess"
          : ($which == $DEF)      ? "def"
          : ($which == $SET)      ? "set"
          : ($which == $LGUESS)   ? "lguess"
          : ($which == $SKIP)     ? "skip"
          : ($which == $AFTER)    ? "after"
          : ($which == $RESTRAIN) ? "restrain"
          : ($which == $PENALTY)  ? "penalty"
	  :                         'skip';
    $parent->change($t);
  } elsif ($which < 100) {
    ##                  0    1    2     3        4            5       6      7       8       9             10     11   12    13
    my @callbacks = qw(copy cut paste noop insert_above insert_below noop set_type grab build_restraint annotate noop find rename_global);
    my $cb = $callbacks[$which];
    $parent->$cb;
  } elsif ($which > 199) {	# explain submenu
    my $i = $which - 200;
    $parent->status($types->[$i] . ": " . $explain{$types->[$i]});
  } else {			# change type submenu
    my $i = $which - 100;
    $parent->change($types->[$i]);
  };
};

sub copy {
  my ($parent) = @_;
  my $grid = $parent->{grid};
  my @list = ();
  foreach my $r (@{ $parent->{selected} }) {
    my $name = $grid -> GetCellValue($r, 1);
    push @list, $grid->{$name};
  };
  $grid->{buffer} = \@list;
  my $s = ($#list > 0) ? q{s} : q{};
  $parent->{grid}->ClearSelection;
  $parent->status("Copied parameter$s ".join(", ", map {defined($_) and $_->name} @list));
};
sub cut {
  my ($parent) = @_;
  my $grid = $parent->{grid};
  $parent->copy;
  $parent->{grid}->ClearSelection;

  foreach my $g (@{ $grid->{buffer} }) {
    my $name = (defined $g) ? $g->name : q{};
    foreach my $r (0 .. $parent->{grid}->GetNumberRows-1) {
      next if ($name ne $grid->GetCellValue($r, 1));
      $grid->{$g->name}->dispense('process', 'erase', {items=>"\@group ".$grid->{$name}->name});
      $grid->DeleteRows($r,1,1);
      $grid->{$g->name}->DEMOLISH;
    };
  };
  while ($grid->GetNumberRows < 12) {
    $grid->AppendRows(1,1);
    $parent->initialize_row( $grid->GetNumberRows - 1 );
    $parent->{grid}->ClearSelection;
  };

  my $s = ($#{$grid->{buffer}} > 0) ? q{s} : q{};
  $parent->status("Cut parameter$s ".join(", ", map {defined($_) and $_->name} @{$grid->{buffer}}));
};


sub paste {
  my ($parent) = @_;
  my $row = $parent->{clicked_row};
  foreach my $g (@{ $parent->{grid}->{buffer} }) {
    next if not defined($g);
    my $this = $parent->insert_below;
    $parent->{grid} -> SetCellValue($this, 0, $g->gds);
    $parent->{grid} -> SetCellValue($this, 1, $g->name);
    $parent->{grid} -> SetCellValue($this, 2, $parent->display_value($g->mathexp));
    my $text = q{};
    if ($g->gds eq 'guess') {
      $text = sprintf("%.5f +/- %.5f", $g->bestfit, $g->error);
    } elsif ($g->gds =~ m{(?:after|def|penalty|restrain)}) {
      $text = sprintf("%.5f", $g->bestfit);
    } elsif ($g->gds =~ m{(?:lguess|merge|set|skip)}) {
      $text = q{};
    };
    $parent->{grid} -> SetCellValue($this, 3, $text);
    $parent->set_type($this);
  };
  $parent->{grid}->ClearSelection;
  $parent->status("perform paste");
};

sub insert_above {
  my ($parent) = @_;
  my $row = $parent->{clicked_row};
  $parent->{grid}->InsertRows($row,1,1);
  $parent->initialize_row($row);
  $parent->{grid}->ClearSelection;
  $parent->status("Inserted a row above row $row.");
  return $row;
};
sub insert_below {
  my ($parent) = @_;
  my $row = $parent->{clicked_row};
  $parent->{grid}->InsertRows($row+1,1,1);
  $parent->initialize_row($row+1);
  $parent->{grid}->ClearSelection;
  $parent->status("Inserted a row below row $row.");
  return $row+1;
};
sub grab {
  my ($parent) = @_;
  my $row = $parent->{clicked_row};
  my $type = $parent->{grid}->GetCellValue($row,0);
  my $name = $parent->{grid}->GetCellValue($row,1);
  $parent->status("Grab aborted -- $name is not a guess parameter."), return if ($type ne 'guess');
  my $bestfit = $parent->{grid}->GetCellValue($row,3);
  $parent->status("$name does not have a best fit value."), return if ($bestfit =~ m{\A\s*\z});
  $bestfit =~ s{\+/-\s*.*}{};
  $parent->{grid}->SetCellValue($row, 2, $parent->display_value($bestfit));
  $parent->{grid}->SetCellValue($row, 3, q{});
  $parent->{grid}->ClearSelection;
  $parent->{uptodate} = 0;
  $parent->status("Using $bestfit as the initial guess for $name.");
};

sub build_restraint {
  my ($parent) = @_;
  my $row = $parent->{clicked_row};
  my $target = $parent->find_next_empty_row;
  my $name = $parent->{grid}->GetCellValue($row,1);
  if ($name =~ m{\A\s*\z}) {
    $parent->status("This row does not have a named parameter.");
    return;
  };

  my $thisgds = $parent->tie_GDS_to_grid($row);
  my $restraint_builder = Demeter::UI::Artemis::GDS::Restraint->new($parent, $name);

  ##$restraint_builder->{scale}->SetValue(2000);
  ## need to somehow get appropriate values for the three parameters into the dialog

  my $result = $restraint_builder -> ShowModal;
  if ($result == wxID_CANCEL) {
    $parent->status("Building restraint cancelled.");
    return;
  };
  my $res  = "res_" . $name;
  my ($scale, $low, $high) = ($restraint_builder->{scale} -> GetValue,
			      $restraint_builder->{low}   -> GetValue,
			      $restraint_builder->{high}  -> GetValue);

  $parent->{grid}->AppendRows(1,1);
  $parent->initialize_row($target);
  $parent->{grid}->SetCellValue($target, 0, "restrain");
  $parent->{grid}->SetCellValue($target, 1, $res);
  my $string = "$scale*penalty($name, $low, $high)";
  $parent->{grid}->SetCellValue($target, 2, $string);
  $parent->{grid}->Update;
  $parent->set_type($target);
  $parent->status("Set restraint $res = $string");
  $parent->{grid}->ClearSelection;
  return $parent;
};

sub annotate {
  my ($parent) = @_;

  my $row = $parent->{clicked_row};
  my $thisgds = $parent->tie_GDS_to_grid($row);
  $parent->status("Annotation aborted -- this row does not contain a named parameter."), return if not $thisgds;
  my $name = $parent->{grid}->GetCellValue($row,1);
  my $ted = Wx::TextEntryDialog->new( $parent, "Annotate $name", "Annotate $name", q{}, wxOK|wxCANCEL, Wx::GetMousePosition);
  if ($ted->ShowModal == wxID_CANCEL) {
    $parent->status("Parameter annotation cancelled.");
    return;
  };
  my $note = $ted->GetValue;
  $thisgds->annotate($note);
  $parent->{grid}->ClearSelection;
  $parent->{statusbar}->PushStatusText("$name : $note");
};

sub find {
  my ($parent) = @_;
  my $thisrow = $parent->{clicked_row};
  my $this = $parent->{grid}->GetCellValue($thisrow,1);
  my $text = $this . " is used\n";
  my $count = 0;

  ## -------- find all GDS parameter math expressions using this parameter
  foreach my $row (0 .. $parent->{grid}->GetNumberRows-1) {
    next if ($row == $thisrow);
    my $me = $parent->{grid}->GetCellValue($row,2);
    if ($me =~ m{\b$this\b}) {
      ++$count;
      $text .= sprintf("%4d.  in the math expression for %s parameter '%s'\n",
		       $count,
		       $parent->{grid}->GetCellValue($row,0),
		       $parent->{grid}->GetCellValue($row,1));
    };
  };

  ## -------- find all path parameter math expressions using this parameter
  foreach my $f (keys %Demeter::UI::Artemis::frames) {
    next if ($f !~ m{\Adata});
    foreach my $p (0 .. $Demeter::UI::Artemis::frames{$f}->{pathlist}->GetPageCount - 1) {
      my $page = $Demeter::UI::Artemis::frames{$f}->{pathlist}->GetPage($p);
      foreach my $k (qw(s02 e0 delr sigma2 ei third fourth)) {
	my $pp = $page->{"pp_$k"}->GetValue;
	if ($pp =~ m{\b$this\b}) {
	  ++$count;
	  $text .= sprintf("%4d.  in the %s path parameter for path '%s%s'\n", 
			   $count, $k, $page->{fefflabel}->GetLabel, $page->{idlabel}->GetLabel);
	};
      };
    };
  };

  ## -------- report back
  $parent->status("$this is not used in this project"), return if ($count == 0);
  Demeter::UI::Artemis::ShowText->new($Demeter::UI::Artemis::frames{main}, $text, "Found $this") -> Show;
  $parent->{grid}->ClearSelection;
};

sub rename_global {
  my ($parent) = @_;
  my $thisrow = $parent->{clicked_row};
  my $this = $parent->{grid}->GetCellValue($thisrow,1);
  my $count = 0;

  ## -------- get new name
  my $ted = Wx::TextEntryDialog->new( $parent, "Rename $this", "Rename $this", q{}, wxOK|wxCANCEL, Wx::GetMousePosition);
  if ($ted->ShowModal == wxID_CANCEL) {
    $parent->status("Parameter renaming cancelled.");
    return;
  };
  my $newname = $ted->GetValue;

  ## -------- change this parameter's name
  $parent->{grid}->SetCellValue($thisrow,1,$newname);
  ++$count;

  ## -------- modify all GDS math expressions containing this parameter
  foreach my $row (0 .. $parent->{grid}->GetNumberRows-1) {
    next if ($row == $thisrow);
    my $me = $parent->{grid}->GetCellValue($row,2);
    if ($me =~ m{\b$this\b}) {
      $me =~ s{$this}{$newname}g;
      $parent->{grid}->SetCellValue($row,2,$me);
      ++$count;
    };
  };

  ## -------- modify all path parameter math expressions containing this parameter
  foreach my $f (keys %Demeter::UI::Artemis::frames) {
    next if ($f !~ m{\Adata});
    foreach my $p (0 .. $Demeter::UI::Artemis::frames{$f}->{pathlist}->GetPageCount - 1) {
      my $page = $Demeter::UI::Artemis::frames{$f}->{pathlist}->GetPage($p);
      foreach my $k (qw(s02 e0 delr sigma2 ei third fourth)) {
	my $pp = $page->{"pp_$k"}->GetValue;
	if ($pp =~ m{\b$this\b}) {
	  $pp =~ s{$this}{$newname}g;
	  $page->{"pp_$k"}->SetValue($pp);
	  ++$count;
	};
      };
    };
  };

  $parent->{grid}->ClearSelection;
  $parent->status("Replaced $count instances of '$this' with '$newname'");
};


sub change {
  my ($parent, $type) = @_;
  my $row = $parent->{clicked_row};

  foreach my $row (0 .. $parent->{grid}->GetNumberRows-1) {
    next if not $parent->{grid}->IsInSelection($row,0);
    $parent->{grid}->SetCellValue($row, 0, $type);
    $parent->set_type($row);
  };
  #delete $parent->{clicked_row};
  #$parent->{grid}->ClearSelection;
  return $parent;
};







######## Other functionality ############################################################

sub StartDrag {
  my ($parent, $self, $event) = @_;
  my $row = $event->GetRow;
  $event->Skip(1), return if ($row < 0);
  my $param = $self->GetCellValue($row, 1);
  $event->Skip(1), return if ($param =~ m{\A\s*\z});

  my $source = Wx::DropSource->new( $self );
  my $dragdata = Wx::TextDataObject->new($param);
  $source->SetData( $dragdata );
  $source->DoDragDrop(1);
};


sub fill_results {
  my ($this, @gds) = @_;
  my $grid = $this->{grid};
  foreach my $row (0 .. $grid->GetNumberRows) {
    next if not $grid->GetCellValue($row, 1);
    foreach my $g (@gds) {
      next if (lc($g->name) ne lc($grid->GetCellValue($row, 1)));
      my $text;
      if ($g->gds eq 'guess') {
	$text = sprintf("%.5f +/- %.5f", $g->bestfit, $g->error);
      } elsif ($g->gds =~ m{(?:after|def|penalty|restrain)}) {
	$text = sprintf("%.5f", $g->bestfit);
      } elsif ($g->gds =~ m{(?:lguess|merge|set|skip)}) {
	1;
      };
      $grid -> SetCellValue($row, 3, $text);
      $grid -> Refresh;
    };
  };
  $this->{uptodate}  = 1;
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

  return 0 if ($text eq $grid -> GetCellValue($drop, 1));

  ## text with white space
  if ($text =~ m{\s}) {
    $parent->status("guess/def/set parameters names cannot have white space ($text)");

  ## text starting with a number
  } elsif ($text =~ m{\A\d}) {
    $parent->status("guess/def/set parameters names cannot start with numbers ($text)");

  ## text with unallowed characters
  } elsif ($text =~ m{[^a-z0-9_?]}i) {
    $parent->status("guess/def/set parameters names can only use [a-z0-9_?] ($text)");

  ## parameter name already exists
  } elsif ($parent->param_present($text)) {
    my $ted = Wx::TextEntryDialog->new($parent, "Clone parameter $text as", "Clone parameter", $text, wxOK|wxCANCEL, Wx::GetMousePosition);
    if ($ted->ShowModal == wxID_CANCEL) {
      $parent->status("Canceling parameter cloning");
    };
    my $newname = $ted->GetValue;
    if ($parent->param_present($newname)) {
      $parent->status("A parameter named $text alredy exists");
      return 0;
    };
    my ($type, $mathexp);
    foreach my $row (0 .. $grid->GetNumberRows) {
      if (lc($grid->GetCellValue($row, 1)) eq lc($text)) {
	$type    = $grid->GetCellValue($row, 0);
	$mathexp = $grid->GetCellValue($row, 2);
	last;
      };
    };
    $parent->put_param($type, $newname, $mathexp);

  ## row already has a parameter in it
  } elsif ($grid -> GetCellValue($drop, 1) !~ m{\A\s*\z}) {
    my $yesno = Wx::MessageDialog->new($parent,
				       sprintf("Replace %s with %s?", $grid -> GetCellValue($drop, 1), $text),
				       "Replace parameter?",
				       wxYES_NO|wxNO_DEFAULT|wxICON_QUESTION);
    if ($yesno->ShowModal == wxID_NO) {
      return 0;
    } else {
      $grid -> SetCellValue($drop, 1, $text);
      $grid -> SetCellValue($drop, 2, 0);
      $parent->{uptodate} = 0;
      $parent->status("Dropped \"$text\" into row $rownum");
    };

  ## just drop it
  } else {
    $grid -> SetCellValue($drop, 1, $text);
    $grid -> SetCellValue($drop, 2, 0);
    $parent->{uptodate} = 0;
    $parent->status("Dropped \"$text\" into row $rownum");
  };
  return 1;
}



1;


=head1 NAME

Demeter::UI::Artemis::GDS - A Guess/Def/Set interface for Artemis

=head1 VERSION

This documentation refers to Demeter version 0.9.11.

=head1 SYNOPSIS

This module provides a simple grid-based widget for dealing with the
various kinds of GDS parameters.  Right click, context menus are
generated appropriately on the grid and a toolbar is included on the
right side of the window.

=head1 CONFIGURATION


=head1 DEPENDENCIES

Demeter's dependencies are in the F<Bundle/DemeterBundle.pm> file.

=head1 BUGS AND LIMITATIONS

=over 4

=item *

Finish functionality on context menus and toolbar, including locating
and globally changing parameters.

=back

Please report problems to Bruce Ravel (bravel AT bnl DOT gov)

Patches are welcome.

=head1 AUTHOR

Bruce Ravel (bravel AT bnl DOT gov)

L<http://cars9.uchicago.edu/~ravel/software/>

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2012 Bruce Ravel (bravel AT bnl DOT gov). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
