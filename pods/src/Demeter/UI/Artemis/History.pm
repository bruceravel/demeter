package  Demeter::UI::Artemis::History;

=for Copyright
 .
 Copyright (c) 2006-2016 Bruce Ravel (http://bruceravel.github.io/home).
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

use Archive::Zip qw( :ERROR_CODES :CONSTANTS );
local $Archive::Zip::UNICODE = 1;
use Cwd;
use DateTime;
use File::Basename;
use File::Copy;
use File::Copy::Recursive qw(dircopy);
use File::Path;
use File::Spec;
use List::Util qw(max);
use List::MoreUtils qw(minmax);

use Wx qw( :everything );
use Wx::Event qw(EVT_CLOSE EVT_ICONIZE EVT_LISTBOX EVT_CHECKLISTBOX EVT_BUTTON EVT_RADIOBOX
		 EVT_ENTER_WINDOW EVT_LEAVE_WINDOW EVT_CHOICE EVT_RIGHT_DOWN EVT_MENU);
use base qw(Wx::Frame);

use Demeter::UI::Artemis::Close;
##use Demeter::UI::Wx::Printing;
use Demeter::UI::Wx::Colours;

sub new {
  my ($class, $parent) = @_;
  my $this = $class->SUPER::new($parent, -1, "Artemis [History]",
				wxDefaultPosition, wxDefaultSize,
				wxMINIMIZE_BOX|wxCAPTION|wxSYSTEM_MENU|wxCLOSE_BOX);
  $this -> SetBackgroundColour( $wxBGC );
  EVT_CLOSE($this, \&on_close);
  EVT_ICONIZE($this, \&on_close);
  $this->{statusbar} = $this->CreateStatusBar;
  $this->{statusbar} -> SetStatusText(q{ });

  my $box = Wx::BoxSizer->new( wxHORIZONTAL );

  my $left = Wx::BoxSizer->new( wxVERTICAL );
  $box -> Add($left, 1, wxGROW|wxALL, 5);

  my $listbox       = Wx::StaticBox->new($this, -1, 'Fit history', wxDefaultPosition, wxDefaultSize);
  my $listboxsizer  = Wx::StaticBoxSizer->new( $listbox, wxVERTICAL );

  $this->{list} = Wx::CheckListBox->new($this, -1, wxDefaultPosition, [-1,500],
					[], wxLB_SINGLE);
  $this->{list}->{datalist} = [];
  $this->{count} =  0;
  $this->{increment} =  0;
  $listboxsizer -> Add($this->{list}, 1, wxGROW|wxALL, 0);
  $left -> Add($listboxsizer, 0, wxGROW|wxALL, 5);
  EVT_LISTBOX($this, $this->{list}, sub{OnSelect(@_)} );
  EVT_CHECKLISTBOX($this, $this->{list}, sub{OnCheck(@_), $_[1]->Skip} );
  EVT_RIGHT_DOWN($this->{list}, sub{OnRightDown(@_)} );
  EVT_MENU($this->{list}, -1, sub{ $this->OnPlotMenu(@_)    });
  $this-> mouseover('list', "Right click on the fit list for a menu of additional actions.");

  my $markbox      = Wx::StaticBox->new($this, -1, 'Mark fits', wxDefaultPosition, wxDefaultSize);
  my $markboxsizer = Wx::StaticBoxSizer->new( $markbox, wxHORIZONTAL );
  $left -> Add($markboxsizer, 0, wxGROW|wxALL, 0);


  $this->{all} = Wx::Button->new($this, -1, 'All', wxDefaultPosition, wxDefaultSize, wxBU_EXACTFIT);
  $markboxsizer -> Add($this->{all}, 1, wxALL, 0);
  $this->{none} = Wx::Button->new($this, -1, 'None', wxDefaultPosition, wxDefaultSize, wxBU_EXACTFIT);
  $markboxsizer -> Add($this->{none}, 1, wxLEFT|wxRIGHT, 2);
  $this->{regexp} = Wx::Button->new($this, -1, 'Regexp', wxDefaultPosition, wxDefaultSize, wxBU_EXACTFIT);
  $markboxsizer -> Add($this->{regexp}, 1, wxALL, 0);
  EVT_BUTTON($this, $this->{all},  sub{mark(@_, 'all')});
  $this-> mouseover('all', "Mark all fits.");
  EVT_BUTTON($this, $this->{none}, sub{mark(@_, 'none')});
  $this-> mouseover('none', "Unmark all fits.");
  EVT_BUTTON($this, $this->{regexp}, sub{mark(@_, 'regexp')});
  $this-> mouseover('regexp', "Mark by regular expression.");

  $this->{doc} = Wx::Button->new($this, wxID_ABOUT, q{}, wxDefaultPosition, wxDefaultSize);
  $left -> Add($this->{doc}, 0, wxGROW|wxLEFT, 1);
  $this->{close} = Wx::Button->new($this, wxID_CLOSE, q{}, wxDefaultPosition, wxDefaultSize);
  $left -> Add($this->{close}, 0, wxGROW|wxLEFT, 1);
  EVT_BUTTON($this, $this->{doc}, sub{$::app->document('history')});
  EVT_BUTTON($this, $this->{close}, \&on_close);
  $this-> mouseover('doc', "Show document page for history window.");
  $this-> mouseover('close', "Hide the history window.");

  my $right = Wx::BoxSizer->new( wxVERTICAL );
  $box -> Add($right, 0, wxGROW|wxALL, 5);

  my $nb  = Wx::Notebook->new($this, -1, wxDefaultPosition, wxDefaultSize, wxNB_TOP);
  $right -> Add($nb, 1, wxGROW|wxALL, 0);

  my $logpage = Wx::Panel->new($nb, -1);
  my $logbox  = Wx::BoxSizer->new( wxHORIZONTAL );
  $logpage->SetSizer($logbox);

  my $reportpage = Wx::Panel->new($nb, -1);
  my $reportbox  = Wx::BoxSizer->new( wxVERTICAL );
  $reportpage->SetSizer($reportbox);

  my $plottoolpage = Wx::ScrolledWindow->new($nb, -1, wxDefaultPosition, wxDefaultSize, wxALWAYS_SHOW_SB);
  my $plottoolbox  = Wx::BoxSizer->new( wxVERTICAL );
  $plottoolpage -> SetScrollbars(10, 8, 30, 66);
  $plottoolpage -> SetSizer($plottoolbox);
  $this->{plottool} = $plottoolpage;
  $this->{scrollbox} = $plottoolbox;

  ## -------- text box for log file
  my $vbox = Wx::BoxSizer->new( wxVERTICAL );
  $logbox -> Add($vbox, 1, wxGROW|wxALL, 5);
  $this->{log} = Wx::TextCtrl->new($logpage, -1, q{}, wxDefaultPosition, [550, -1],
				   wxTE_MULTILINE|wxTE_READONLY|wxHSCROLL|wxTE_RICH);
  $this->{log} -> SetFont( Wx::Font->new( 9, wxTELETYPE, wxNORMAL, wxNORMAL, 0, "" ) );
  $vbox -> Add($this->{log}, 1, wxGROW|wxALL, 5);

  my $hbox = Wx::BoxSizer->new( wxHORIZONTAL );
  $vbox -> Add($hbox, 0, wxGROW|wxALL, 5);

  $this->{save} = Wx::Button->new($logpage, -1, q{Save this log});
  $hbox -> Add($this->{save}, 1, wxGROW|wxRIGHT, 2);
  EVT_BUTTON($this, $this->{save}, sub{$this->savelog});
  $this-> mouseover('save', "Save this fitting log to a file.");

  # $this->{preview} = Wx::Button->new($logpage, -1, q{Log preview});
  # $hbox -> Add($this->{preview}, 1, wxGROW|wxRIGHT, 2);
  # EVT_BUTTON($this, $this->{preview}, sub{on_preview(@_, 'log')});
  # $this-> mouseover('preview', "Preview this fitting log.");

  # $this->{print} = Wx::Button->new($logpage, -1, q{Print this log});
  # $hbox -> Add($this->{print}, 1, wxGROW|wxRIGHT, 2);
  # EVT_BUTTON($this, $this->{print}, sub{on_print(@_, 'log')});
  # $this-> mouseover('print', "Print this fitting log.");


  ## -------- controls for writing reports on fits
  my $controls = Wx::BoxSizer->new( wxHORIZONTAL );
  $reportbox -> Add($controls, 0, wxGROW|wxALL, 0);
  $this->{summarize} = Wx::Button->new($reportpage, -1, "Sumarize marked fits");
  $controls->Add($this->{summarize}, 1, wxALL, 5);
  EVT_BUTTON($this, $this->{summarize}, sub{summarize(@_)});
  $this-> mouseover('summarize', "Write a short summary of each marked fit.");

  my $repbox      = Wx::StaticBox->new($reportpage, -1, 'Report on a parameter', wxDefaultPosition, wxDefaultSize);
  my $repboxsizer = Wx::StaticBoxSizer->new( $repbox, wxVERTICAL );
  $reportbox -> Add($repboxsizer, 0, wxGROW|wxALL, 5);

  $controls = Wx::BoxSizer->new( wxHORIZONTAL );
  $repboxsizer -> Add($controls, 0, wxGROW|wxALL, 5);
  my $label = Wx::StaticText->new($reportpage, -1, "Select parameter: ");
  $controls->Add($label, 0, wxTOP, 9);
  $this->{params} = Wx::Choice->new($reportpage, -1, wxDefaultPosition, wxDefaultSize, ["Statistcal parameters"]);
  $controls->Add($this->{params}, 0, wxALL, 5);
  EVT_CHOICE($this, $this->{params}, sub{write_report(@_)});
  $this-> mouseover('params', "Write and plot a report on the statistical parameters or on the chosen fitting parameter.");

  $this->{doreport} = Wx::Button->new($reportpage, -1, "Write report");
  $controls->Add($this->{doreport}, 0, wxALL, 5);
  EVT_BUTTON($this, $this->{doreport}, sub{write_report(@_)});
  $this-> mouseover('doreport', "Write and plot a report on the statistical parameters or on the chosen fitting parameter.");

  $controls = Wx::BoxSizer->new( wxHORIZONTAL );
  $repboxsizer -> Add($controls, 0, wxGROW|wxALL, 5);
  $this->{plotas} = Wx::RadioBox->new($reportpage, -1, "Plot statistics using", wxDefaultPosition, wxDefaultSize,
				      ["Reduced chi-square", "R-factor", "Happiness"],
				      1, wxRA_SPECIFY_ROWS);
  $controls->Add($this->{plotas}, 0, wxALL, 0);
  $this-> mouseover('plotas', "Specify which column will be plotted after generating a statistics report.");

  $controls = Wx::BoxSizer->new( wxHORIZONTAL );
  $repboxsizer -> Add($controls, 0, wxGROW|wxLEFT, 5);
  $this->{showy} = Wx::CheckBox->new($reportpage, -1, "Show y=0");
  $controls->Add($this->{showy}, 0, wxALL, 0);
  $this-> mouseover('showy', "Check this button to force the report plot to scale the plot such that the y axis starts at 0");

  $this->{report} = Wx::TextCtrl->new($reportpage, -1, q{}, wxDefaultPosition, [550, -1],
				   wxTE_MULTILINE|wxTE_READONLY|wxHSCROLL);
  $this->{report} -> SetFont( Wx::Font->new( 9, wxTELETYPE, wxNORMAL, wxNORMAL, 0, "" ) );
  $reportbox -> Add($this->{report}, 1, wxGROW|wxALL, 5);

  $controls = Wx::BoxSizer->new( wxHORIZONTAL );
  $reportbox -> Add($controls, 0, wxGROW|wxALL, 0);
  $this->{savereport} = Wx::Button->new($reportpage, wxID_SAVE, q{});
  $controls->Add($this->{savereport}, 1, wxALL, 5);
  EVT_BUTTON($this, $this->{savereport}, sub{$this->savereport});
  $this-> mouseover('savereport', "Save this report to a file.");

  # $this->{previewreport} = Wx::Button->new($reportpage, wxID_PREVIEW, q{});
  # $controls->Add($this->{previewreport}, 1, wxALL, 5);
  # EVT_BUTTON($this, $this->{previewreport}, sub{on_preview(@_, 'report')});
  # $this-> mouseover('previewreport', "Preview report");

  # $this->{printreport} = Wx::Button->new($reportpage, wxID_PRINT, q{});
  # $controls->Add($this->{printreport}, 1, wxALL, 5);
  # EVT_BUTTON($this, $this->{printreport}, sub{on_print(@_, 'report')});
  # $this-> mouseover('printreport', "Print report");

  ## -------- plotting tool page
  ##$plottoolbox -> Add(Wx::StaticText->new($plottoolpage, -1, "The history plotting tool is currently broken.\nIt currently fails to import old fits from project files.  Drat!"), 0, wxALL|wxALIGN_CENTER_HORIZONTAL, 5);
  $plottoolbox -> Add(Wx::StaticText->new($plottoolpage, -1, "Click on a button to transfer that fit to the plotting list."), 0, wxALL|wxALIGN_CENTER_HORIZONTAL, 5);

  $nb -> AddPage($logpage,      "Log file", 1);
  $nb -> AddPage($reportpage,   "Reports", 0);
  $nb -> AddPage($plottoolpage, "Plot tool", 0);

  $this->SetSizerAndFit($box);
  return $this;
};

sub mouseover {
  my ($self, $widget, $text) = @_;
  EVT_ENTER_WINDOW($self->{$widget}, sub{$self->{statusbar}->PushStatusText($text); $_[1]->Skip});
  EVT_LEAVE_WINDOW($self->{$widget}, sub{$self->{statusbar}->PopStatusText if ($self->{statusbar}->GetStatusText eq $text); $_[1]->Skip});
};

sub OnSelect {
  my ($self, $event) = @_;
  my $fit = $self->{list}->GetIndexedData($self->{list}->GetSelection);
  return if not defined $fit;
  if (not $fit->thawed) {
    my $busy = Wx::BusyCursor->new();
    $self->status('Unpacking fit "'.$fit->name.'"', 'wait');
    $fit->deserialize(folder=>File::Spec->catfile($::app->{main}->{project_folder}, 'fits', $fit->group));
    $self->status('Unpacked fit "'.$fit->name.'"');
    undef $busy;
  };
  $self->put_log($fit);
  $self->set_params($fit);
};
sub OnCheck {
  #print "check: ", join(" ", @_), $/;
  1;
};

use Const::Fast;
const my $FIT_RESTORE      => Wx::NewId();
const my $FIT_SAVE	   => Wx::NewId();
const my $FIT_EXPORT	   => Wx::NewId();
const my $FIT_DISCARD      => Wx::NewId();
const my $FIT_DISCARD_MANY => Wx::NewId();
const my $FIT_SHOW         => Wx::NewId();

sub OnRightDown {
  my ($self, $event) = @_;
  return if $self->IsEmpty;
  my $position  = $self->HitTest($event->GetPosition);
  $self->SetSelection($position);
  $self->GetParent->{_position} = $position; # need a way to remember where the click happened in methods called from OnPlotMenu
  ($position = $self->GetCount - 1) if ($position == -1);
  my $name = $self->GetString($position);
  my $menu = Wx::Menu->new(q{});
  $menu->Append($FIT_RESTORE, "Restore fitting model from \"$name\"");
  $menu->Append($FIT_SAVE,    "Save log file for \"$name\"");
  $menu->Append($FIT_EXPORT,  "Export \"$name\"");
  $menu->Append($FIT_DISCARD, "Discard \"$name\"");
  $menu->AppendSeparator;
  $menu->Append($FIT_DISCARD_MANY, "Discard marked fits");
  $menu->AppendSeparator;
  $menu->Append($FIT_SHOW, "Show YAML for \"$name\"");
  $self->GetParent->OnSelect;
  $self->PopupMenu($menu, $event->GetPosition);
};

sub OnPlotMenu {
  my ($self, $list, $event) = @_;
  my $id = $event->GetId;
 SWITCH: {
    ($id == $FIT_RESTORE) and do {
      $self->restore($self->{_position});
      last SWITCH;
    };
    ($id == $FIT_SAVE)    and do {
      $self->savelog($self->{_position});
      last SWITCH;
    };
    ($id == $FIT_EXPORT)  and do {
      $self->export($self->{_position});
      last SWITCH;
    };
    ($id == $FIT_DISCARD) and do {
      $self->discard($self->{_position}, 1);
      last SWITCH;
    };
    ($id == $FIT_DISCARD_MANY) and do {
      $self->discard_many;
      last SWITCH;
    };
    ($id == $FIT_SHOW) and do {
      my $thisfit = $self->{list}->GetIndexedData($self->{_position});
      my $yaml   = $thisfit->serialization;
      my $title = sprintf "YAML of Plot object (%s) [%s]", $thisfit->group, $thisfit->name;
      my $dialog = Demeter::UI::Artemis::ShowText->new($::app->{main}, $yaml, $title) -> Show;
      last SWITCH;
    };
  };
};

sub mark {
  my ($self, $event, $how) = @_; # how = all|none|marked
  my $re;
  if ($how eq 'regexp') {
    my $ted = Wx::TextEntryDialog->new( $self, "Mark fits matching this regular expression:", "Enter a regular expression", q{}, wxOK|wxCANCEL, Wx::GetMousePosition);
    if ($ted->ShowModal == wxID_CANCEL) {
      $self->status("Fit marking canceled.");
      return;
    };
    my $regex = $ted->GetValue;
    my $is_ok = eval '$re = qr/$regex/';
    if (not $is_ok) {
      $self->{PARENT}->status("Oops!  \"$regex\" is not a valid regular expression");
      return;
    };
  };
  foreach my $i (0 .. $self->{list}->GetCount-1) {
    my $onoff = 0;
    if ($how eq 'regexp') {
      $onoff = ($self->{list}->GetIndexedData($i)->name =~ m{$re}) ? 1 : $self->{list}->IsChecked($i);
    } else {
      $onoff = ($how eq 'all') ? 1 : 0;
    };
    $self->{list}->Check($i, $onoff);
  };
};


# sub on_close {
#   my ($self) = @_;
#   $self->Show(0);
#   $self->GetParent->{toolbar}->ToggleTool(3, 0);
# };

sub put_log {
  my ($self, $fit) = @_;
#  my $busy = Wx::BusyCursor -> new();
  my $log = File::Spec->catfile($::app->{main}->{project_folder}, 'fits', $fit->group, 'log');
  Demeter::UI::Artemis::LogText -> make_text($self->{log}, $log, $fit->color);
#  undef $busy;
};

sub set_params {
  my ($self, $fit) = @_;
  $self->{params}->Clear;
  $self->{params}->Append('Statistcal parameters');
  foreach my $g (sort {$a->name cmp $b->name} @{$fit->gds}) {
    $self->{params}->Append($g->name);
  };
  $self->{params}->SetStringSelection('Statistcal parameters');
};

sub mark_all_if_none {
  my ($self) = @_;
  my $count = 0;
  foreach my $i (0 .. $self->{list}->GetCount-1) {
    ++$count if $self->{list}->IsChecked($i);
  };
  $self->mark(q{}, 'all') if (not $count);
};

sub write_report {
  my ($self, $event) = @_;
  return if $self->{list}->IsEmpty;
  $self->mark_all_if_none;

  ## -------- generate report and enter it into text box
  $self->{report}->Clear;
  my $param = $self->{params}->GetStringSelection;
  (my $pp = $param) =~ s{_}{\\_}g;
  if ($param eq 'Statistcal parameters') {
    $self->{report}->AppendText(Demeter->template('report', 'report_head_stats'));
  } else {
    $self->{report}->AppendText(Demeter->template('report', 'report_head_param', {param=>$param}));
  };
  my @x = ();
  foreach my $i (0 .. $self->{list}->GetCount-1) {
    next if not $self->{list}->IsChecked($i);
    my $fit = $self->{list}->GetIndexedData($i);
    push @x, $fit->fom;
    if ($param eq 'Statistcal parameters') {
      $self->{report}->AppendText($fit->template('report', 'report_stats'));
    } else {
      my $g = $fit->fetch_gds($param);
      next if not $g;
      $fit->mo->fit($fit);
      my $toss = Demeter::GDS->new(name    => $g->[0],
				   gds     => $g->[1],
				   mathexp => $g->[2],
				   bestfit => $g->[3],
				   error   => $g->[4],
				  );
      $self->{report}->AppendText($toss->template('report', 'report_param'));
      $toss->DEMOLISH;
      $fit->mo->fit(q{});
    };
  };

  ## -------- plot!
  my ($xmin, $xmax) = minmax(@x);
  my $delta = ($xmax-$xmin)/5;
  ($xmin, $xmax) = ($xmin-$delta, $xmax+$delta);
  Demeter->po->start_plot;
  my $tempfile = Demeter->po->tempfile;
  open my $T, '>'.$tempfile;
  print $T $self->{report}->GetValue;
  close $T;
  if ($param eq 'Statistcal parameters') {
    my $col = $self->{plotas}->GetSelection + 2;
    Demeter->chart('plot', 'plot_stats', {file=>$tempfile, xmin=>$xmin, xmax=>$xmax, col=>$col, showy=>$self->{showy}->GetValue});
  } else {
    Demeter->chart('plot', 'plot_file', {file=>$tempfile, xmin=>$xmin, xmax=>$xmax, param=>$pp, showy=>$self->{showy}->GetValue});
  };
  $self->status("Reported on $param");
};

sub summarize {
  my ($self, $event) = @_;
  return if $self->{list}->IsEmpty;
  my $busy = Wx::BusyCursor->new();
  $self->mark_all_if_none;
  my $text = q{};
  foreach my $i (0 .. $self->{list}->GetCount-1) {
    next if not $self->{list}->IsChecked($i);
    my $fit = $self->{list}->GetIndexedData($i);
    if (not $fit->thawed) {
      $self->status('Unpacking fit "'.$fit->name.'"', 'wait');
      $fit->deserialize(folder=>File::Spec->catfile($::app->{main}->{project_folder}, 'fits', $fit->group));
      $self->status('Unpacked fit "'.$fit->name.'"');
    };
    $text .= $fit -> summary;
  };
  undef $busy;
  return if (not $text);
  $self->{report}->Clear;
  $self->{report}->SetValue($text)
};
sub savereport {
  my ($self, $event) = @_;
  my $fd = Wx::FileDialog->new( $self, "Save log file", cwd, "report.txt",
				"Text files (*.txt)|*.txt",
				wxFD_SAVE|wxFD_CHANGE_DIR|wxFD_OVERWRITE_PROMPT,
				wxDefaultPosition);
  if ($fd->ShowModal == wxID_CANCEL) {
    $self->status("Not saving report.");
    return;
  };
  my $fname = $fd->GetPath;
  #return if $self->overwrite_prompt($fname); # work-around gtk's wxFD_OVERWRITE_PROMPT bug (5 Jan 2011)
  open my $R, '>', $fname;
  print $R $self->{report}->GetValue;
  close $R;
  $self->status("Wrote report to '$fname'.");
};

sub restore {
  my ($self, $position) = @_;
  ($position = $self->{list}->GetSelection) if not defined ($position);
  my $busy = Wx::BusyCursor -> new();
  my $was = Demeter->mo->currentfit;
  Demeter::UI::Artemis::Project::discard_fit(\%Demeter::UI::Artemis::frames);
  my $old = $self->{list}->GetIndexedData($position);
  my $fit = $old->Clone;
  my $folder = File::Spec->catfile($Demeter::UI::Artemis::frames{main}->{project_folder}, 'fits', $old->group);
  $fit->deserialize(folder=> $folder, regenerate=>0); #$regen);
  $fit->fom($was-1);
  $fit->mo->currentfit($was-1);
  Demeter::UI::Artemis::Project::restore_fit(\%Demeter::UI::Artemis::frames, $fit, $old);
#  Demeter::UI::Artemis::Project::restore_fit(\%Demeter::UI::Artemis::frames, $fit);
  my $text = $Demeter::UI::Artemis::frames{main}->{name}->GetValue;
  $text =~ s{\d+\z}($was);
  $Demeter::UI::Artemis::frames{main}->{name}->SetValue($text);
  Demeter::UI::Artemis::update_order_file();
  undef $busy;
  $self->status("Restored ".$self->{list}->GetString($position));
};

sub discard_many {
  my ($self, $event) = @_;
  foreach my $i (reverse(0 .. $self->{list}->GetCount-1)) {
    next if not $self->{list}->IsChecked($i);
    $self->discard($i, 0);
  };
  return if not $self->{list}->GetCount;
  $self->{list}->SetSelection($self->{list}->GetCount-1);
  $self->OnSelect;
  $self->status("discarded marked fits");
};

sub discard {
  my ($self, $position, $show) = @_;
  $show ||= 0;
  ($position = $self->{list}->GetSelection) if not defined ($position);
  my $thisfit = $self->{list}->GetIndexedData($position);
  my $name = $thisfit->name;

  ## -------- remove this fit from the fit list
  if ($position == $self->{list}->GetCount-1) { # last position
    if ($show) {
      $self->{list}->SetSelection($position-1);
      $self->OnSelect;
    };
  } elsif ($self->{list}->GetCount == 1) {      # only position
    $self->{list}->SetSelection(wxNOT_FOUND);
  } else {			                # all others
    if ($show) {
      $self->{list}->SetSelection($position+1);
      $self->OnSelect;
    };
  };
  $self->{list}->DeleteData($position);

  ## -------- destroy the Fit object, delete its folder in stash space, delete its entry in the order file
  my $str = $thisfit->group;
  $thisfit->DEMOLISH;

  my $folder = File::Spec->catfile($Demeter::UI::Artemis::frames{main}->{project_folder}, 'fits', $str);
  rmtree($folder);

  my $orderfile = $Demeter::UI::Artemis::frames{main}->{order_file};
  my %order = ();
  eval {local $SIG{__DIE__} = sub {}; %order = YAML::Tiny::LoadFile($orderfile)};
  foreach my $k (keys %{$order{order}}) {
    delete $order{order}->{$k} if ($order{order}->{$k} eq $str);
  };
  my $string .= YAML::Tiny::Dump(%order);
  open(my $ORDER, '>'.$orderfile);
  print $ORDER $string;
  close $ORDER;
  %Demeter::UI::Artemis::fit_order = %order;

  Demeter::UI::Artemis::modified(1);
  $self->status("discarded $name");
};

sub savelog {
  my ($self, $position) = @_;
  ($position = $self->{list}->GetSelection) if not defined ($position);
  my $fit = $self->{list}->GetIndexedData($position);
  if (not defined($fit)) {
    $self->status("Cannot save log file -- cannot determine fit.");
    return;
  };

  (my $pref = $fit->name) =~ s{\s+}{_}g;
  my $fd = Wx::FileDialog->new( $self, "Save log file", cwd, $pref.q{.log},
				"Log files (*.log)|*.log",
				wxFD_SAVE|wxFD_CHANGE_DIR|wxFD_OVERWRITE_PROMPT,
				wxDefaultPosition);
  if ($fd->ShowModal == wxID_CANCEL) {
    $self->status("Not saving log file.");
    return;
  };
  my $fname = $fd->GetPath;
  #return if $self->overwrite_prompt($fname); # work-around gtk's wxFD_OVERWRITE_PROMPT bug (5 Jan 2011)
  $fit->logfile($fname);
  $self->status("Wrote log file to '$fname'.");
};

sub export {
  my ($self, $position) = @_;
  ($position = $self->{list}->GetSelection) if not defined ($position);

  my $newfolder = File::Spec->catfile(Demeter->stash_folder, '_dem_export_' . Demeter->randomstring(8));
  my $fit = $self->{list}->GetIndexedData($position);
  my $name = $fit->name;

  my $fname = "$name.fpj";
  $fname =~ s{\s+}{_}g;
  my $fd = Wx::FileDialog->new( $::app->{main}, "Save $name project file", cwd, $fname,
				"Artemis project (*.fpj)|*.fpj|All files (*)|*",
				wxFD_SAVE|wxFD_CHANGE_DIR|wxFD_OVERWRITE_PROMPT);
  if ($fd->ShowModal == wxID_CANCEL) {
    $self->status("Saving project canceled.");
    return;
  };
  $fname = $fd->GetPath;
  #return if $::app->{main}->overwrite_prompt($fname); # work-around gtk's wxFD_OVERWRITE_PROMPT bug (5 Jan 2011)

  mkpath($newfolder,0);

  ## copy the Readme file
  copy(File::Spec->catfile($::app->{main}->{project_folder}, 'Readme'),  File::Spec->catfile($newfolder, 'Readme'));
  ## save the current journal
  $::app->{Journal}->save_journal(File::Spec->catfile($::app->{main}->{project_folder}, 'journal'));
  copy(File::Spec->catfile($::app->{main}->{project_folder}, 'journal'), File::Spec->catfile($newfolder, 'journal'));
  ## save the current plot and indicator parameters  (indicator needs refactoring!)
  $::app->{Plot}->fetch_parameters;
  $::app->{Plot}->{indicators}->fetch;
  mkpath(File::Spec->catfile($newfolder, 'plot'), 0);
  Demeter->po -> serialize(File::Spec->catfile($newfolder, 'plot', 'plot.yaml'));
  open(my $IN, '>'.File::Spec->catfile($newfolder, 'plot', 'indicators.yaml'));
  foreach my $j (1..5) {
    my $this = $::app->{Plot}->{indicators}->{'group'.$j};
    my $found = Demeter->mo->fetch('Indicator', $this);
    print($IN $found -> serialization) if $found;
  };
  close $IN;

  ## copy over this fit
  mkpath(File::Spec->catfile($newfolder, 'fits'), 0);
  dircopy(File::Spec->catfile($::app->{main}->{project_folder}, 'fits', $fit->group), File::Spec->catfile($newfolder, 'fits', $fit->group));

  ## copy over all feffs
  dircopy(File::Spec->catfile($::app->{main}->{project_folder}, 'feff'), File::Spec->catfile($newfolder, 'feff'));

  ## write the order file
  open(my $OR, '>'.File::Spec->catfile($newfolder, 'order'));
  printf $OR "--- order\n---\n1: %s\ncurrent: 1\n", $fit->group;
  close $OR;

  ## zip it all up, clean up the mess, push it to the MRU list
  my $zip = Archive::Zip->new();
  $zip->addTree( $newfolder, "",  sub{ not m{\.sp$} }); #and not m{_dem_\w{8}\z}
  carp('error writing zip-style project') unless ($zip->writeToFileNamed( $fname ) == AZ_OK);
  undef $zip;

  rmtree($newfolder,0);

  Demeter->push_mru("artemis", $fname);
  &Demeter::UI::Artemis::set_mru;

  $self->status("exported $name as $fname");
};


sub add_plottool {
  my ($self, $fit) = @_;
  ++$self->{count};

  my $box      = Wx::StaticBox->new($self->{plottool}, -1, $fit->name, wxDefaultPosition, wxDefaultSize);
  my $boxsizer = Wx::StaticBoxSizer->new( $box, wxHORIZONTAL );

  my @list = @{$fit->data} || @{$fit->datagroups};
  foreach my $d (@{$fit->data}) {
    my $key = join('.', $fit->group, $d->group);
    $self->{$key} = Wx::Button->new($self->{plottool}, -1, $d->name);
    $boxsizer -> Add($self->{$key}, 0, wxALL, 5);
    EVT_BUTTON($self, $self->{$key},  sub{$self->transfer($fit, $d)});
    $self-> mouseover($key, "Put the fit to \"" . $d->name . "\" from \"" . $fit->name . "\" in the plotting list.");
  };

  ## this rather complicated bit gets the scrolling area filled in and
  ## redrawn correctly and leaves the display at the end of the
  ## scrolling area
  $self->{plottool}  -> Scroll(0,0);
  $self->{scrollbox} -> Add($boxsizer, 0, wxGROW|wxALL, 5);
  $self->{plottool}  -> SetSizer($self->{scrollbox});
  my $n               = ($self->{count}<8) ? 8 : $self->{count};
  my ($x,$y)          = $box->GetSizeWH;
  $self->{increment}  = max($y, $self->{increment});
  $self->{plottool}  -> SetScrollbars(10, $n, 30, $self->{increment}+11);
  $self->{plottool}  -> Refresh;
  ($x,$y)             = $box->GetSizeWH;
  $self->{increment}  = max($y, $self->{increment});
  $self->{plottool}  -> Scroll(0,1000);
};

## need to check if it is already in the plot list...
sub transfer {
  my ($self, $fit, $data) = @_;

  my $fitfile = File::Spec->catfile($Demeter::UI::Artemis::frames{main}->{project_folder}, 'fits', $fit->group, $data->group.'.fit');
  my $pldata = Demeter::Data->new(datatype => 'chi',
				  name     => sprintf("Fit to %s from %s", $data->name, $fit->name),);

  my $plotlist  = $Demeter::UI::Artemis::frames{Plot}->{plotlist};
  my $found     = 0;
  my $thisname  = $pldata->name;
  foreach my $i (0 .. $plotlist->GetCount - 1) {
    if ($thisname eq $plotlist->GetIndexedData($i)->name) {
      $found = 1;
      last;
    };
  };
  if ($found) {
    $self->status("\"$thisname\" is already in the plotting list.");
    return;
  };

  foreach my $att (qw(fft_kmin fft_kmax fft_kwindow fft_dk fft_pc fft_pctype fft_pcpath fft_pcpathgroup
		      bft_rmin bft_rmax bft_rwindow bft_dr)) {
    $pldata->$att($data->$att);
  };
  $pldata->just_fit($fitfile);

  $plotlist->AddData($pldata->name, $pldata);
  my $i = $plotlist->GetCount - 1;
  ##$plotlist->SetClientData($i, $data);
  $plotlist->Check($i,1);
  $self->status("\"" . $pldata->name . "\" was added to the plotting list.")
};




1;


=head1 NAME

Demeter::UI::Artemis::History - A fit history interface for Artemis

=head1 VERSION

This documentation refers to Demeter version 0.9.25.

=head1 SYNOPSIS

Examine past fits contained in the fitting project.

=head1 CONFIGURATION


=head1 DEPENDENCIES

Demeter's dependencies are in the F<Build.PL> file.

=head1 BUGS AND LIMITATIONS

=over 4

=item *

Discard one or more fits, completely removing them from the project
and the order file.  Delete folder, remove from order file/hash

=item *

Export selected fit to a project file.  This contains the model of the
selected fit without the history.  Useful for bug reports and other
communications.

=item *

Calculations on the report tab: average, Einstein

=back

Please report problems to the Ifeffit Mailing List
(L<http://cars9.uchicago.edu/mailman/listinfo/ifeffit/>)

Patches are welcome.

=head1 AUTHOR

Bruce Ravel (L<http://bruceravel.github.io/home>)

L<http://bruceravel.github.io/demeter/>

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2016 Bruce Ravel (L<http://bruceravel.github.io/home>). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
