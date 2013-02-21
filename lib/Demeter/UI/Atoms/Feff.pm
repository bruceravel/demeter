package  Demeter::UI::Atoms::Feff;

use Demeter::StrTypes qw( Element );
use Demeter::UI::Wx::SpecialCharacters qw($ARING);

use Cwd;
use Chemistry::Elements qw(get_Z);
use File::Spec;

use Wx qw( :everything );
use base 'Wx::Panel';

#use Wx::Perl::ProcessStream qw( :everything );
use Wx::Event qw(EVT_CHOICE EVT_KEY_DOWN EVT_MENU EVT_TOOL_ENTER EVT_TOOL_RCLICKED
		 EVT_ENTER_WINDOW EVT_LEAVE_WINDOW);
use Demeter::UI::Wx::MRU;

my %hints = (
	     open     => "Import an existing feff.inp file -- Hint: Right click for recent files",
	     save     => "Save this feff.inp file",
	     exec     => "Run Feff on this cluster",
	     boiler   => "Insert boilerplate for a feff.inp file",
	     clear    => "Clear all data",
	    );

sub new {
  my ($class, $page, $parent) = @_;
  my $self = $class->SUPER::new($page, -1, wxDefaultPosition, wxDefaultSize, wxMAXIMIZE_BOX );
  $self->{parent}    = $parent;
  $self->{statusbar} = $parent->{statusbar};
  #$self->{feffobject} = $parent->{feffobject} || $Demeter::UI::Atoms::demeter;
  my $vbox = Wx::BoxSizer->new( wxVERTICAL );

  $self->{toolbar} = Wx::ToolBar->new($self, -1, wxDefaultPosition, wxDefaultSize, wxTB_HORIZONTAL|wxTB_3DBUTTONS|wxTB_TEXT);
  EVT_MENU( $self->{toolbar}, -1, sub{my ($toolbar, $event) = @_; OnToolClick($toolbar, $event, $self)} );
  $self->{toolbar} -> AddTool(-1, "Open file",  $self->icon("open"),        wxNullBitmap, wxITEM_NORMAL, q{}, $hints{open} );
  $self->{toolbar} -> AddTool(-1, "Save file",  $self->icon("save"),        wxNullBitmap, wxITEM_NORMAL, q{}, $hints{save} );
  $self->{toolbar} -> AddTool(-1, "Clear all",  $self->icon("empty"),       wxNullBitmap, wxITEM_NORMAL, q{}, $hints{clear});
  $self->{toolbar} -> AddTool(-1, "Template",   $self->icon("boilerplate"), wxNullBitmap, wxITEM_NORMAL, q{}, $hints{boiler});
  $self->{toolbar} -> AddSeparator;
  $self->{toolbar} -> AddTool(-1, "Run Feff",   $self->icon("exec"),        wxNullBitmap, wxITEM_NORMAL, q{}, $hints{exec} );
  EVT_TOOL_ENTER( $self, $self->{toolbar}, sub{my ($toolbar, $event) = @_; &OnToolEnter($toolbar, $event, 'toolbar')} );
  $self->{toolbar} -> Realize;
  $vbox -> Add($self->{toolbar}, 0, wxGROW|wxALL, 5);
  EVT_TOOL_RCLICKED($self->{toolbar}, -1, sub{my ($toolbar, $event) = @_; OnToolRightClick($toolbar, $event, $self)});


  my $hh = Wx::BoxSizer->new( wxHORIZONTAL );
  $vbox -> Add($hh, 0, wxEXPAND|wxALL, 0);
  my $label      = Wx::StaticText->new($self, -1, 'Name of this Feff calculation: ', wxDefaultPosition, [-1,-1]);
  $self->{name}  = Wx::TextCtrl  ->new($self, -1, q{}, wxDefaultPosition, [70,-1], wxTE_READONLY);
  $hh->Add($label,        0, wxEXPAND|wxALL, 5);
  $hh->Add($self->{name}, 1, wxEXPAND|wxALL, 5);

  $self->{feffbox}       = Wx::StaticBox->new($self, -1, 'Feff input file', wxDefaultPosition, wxDefaultSize);
  $self->{feffboxsizer}  = Wx::StaticBoxSizer->new( $self->{feffbox}, wxVERTICAL );
  $self->{feff} = Wx::TextCtrl->new($self, -1, q{}, wxDefaultPosition, wxDefaultSize,
				       wxTE_MULTILINE|wxHSCROLL|wxALWAYS_SHOW_SB);
  $self->{feff}->SetFont( Wx::Font->new( 9, wxTELETYPE, wxNORMAL, wxNORMAL, 0, "" ) );
  $self->{feffboxsizer} -> Add($self->{feff}, 1, wxEXPAND|wxALL, 0);

  $vbox -> Add($self->{feffboxsizer}, 1, wxEXPAND|wxALL, 5);

  #print ">>> ", $parent->{feffobject}, $/;
  $self->{feffobject} = $parent->{feffobject} || Demeter::Feff->new(screen=>0, buffer=>1, save=>0);
  #$self->{feffobject} = Demeter::Feff->new(screen=>0, buffer=>1, save=>0);
  my $base = $self->{parent}->{base} || $self->{feffobject}->stash_folder;
  $self->{feffobject} -> workspace(File::Spec->catfile($base, $self->{feffobject}->group));
  $self->{feffobject} -> make_workspace;

  $self -> SetSizerAndFit( $vbox );
  return $self;
};

sub icon {
  my ($self, $which) = @_;
  my $icon = File::Spec->catfile($Demeter::UI::Atoms::atoms_base, 'Atoms', 'icons', "$which.png");
  return wxNullBitmap if (not -e $icon);
  return Wx::Bitmap->new($icon, wxBITMAP_TYPE_ANY)
};

sub OnToolEnter {
  my ($self, $event, $which) = @_;
  if ( $event->GetSelection > -1 ) {
    $self->{statusbar}->PushStatusText($self->{$which}->GetToolLongHelp($event->GetSelection));
  } else {
    $self->{statusbar}->PopStatusText;
  };
};

sub OnToolClick {
  my ($toolbar, $event, $self) = @_;
  ##                 Vv--order of toolbar on the screen--vV
  my @callbacks = qw(import save_file clear_all insert_boilerplate noop run_feff );
  my $closure = $callbacks[$toolbar->GetToolPos($event->GetId)];
  $self->$closure;
};
sub OnToolRightClick {
  my ($toolbar, $event, $self) = @_;
  return if not ($toolbar->GetToolPos($event->GetId) == 0);
  my $dialog = Demeter::UI::Wx::MRU->new($self, 'feff',
					 "Select a recent feff.inp file",
					 "Recent feff.inp files");
  $self->{parent}->status("There are no recent Feff files."), return
    if ($dialog == -1);
  if( $dialog->ShowModal == wxID_CANCEL ) {
    $self->{parent}->status("Import canceled.");
  } else {
   $self->import( $dialog->GetMruSelection );
  };
};

sub noop {
  return 1;
};

sub import {
  my ($self, $file) = @_;
  return if not $self->clear_all;
  if ((not $file) or (not -e $file)) {
    my $fd = Wx::FileDialog->new( $self, "Import a feff.inp file", cwd, q{},
				  "input file (*.inp)|*.inp|All files (*)|*",
				  wxFD_OPEN|wxFD_FILE_MUST_EXIST|wxFD_CHANGE_DIR|wxFD_PREVIEW,
				  wxDefaultPosition);
    $fd -> ShowModal;
    $file = $fd->GetPath;
  };
  $self->{feff}->SetValue(q{});
  local $/;
  open(my $INP, $file);
  my $text = <$INP>;
  close $INP;
  $self->{feff}->SetValue($text);
  $Demeter::UI::Atoms::demeter -> push_mru("feff", $file);
};


sub save_file {
  my ($self) = @_;
  my $fd = Wx::FileDialog->new( $self, "Save feff input file", cwd, q{feff.inp},
				"input file (*.inp)|*.inp|All files (*)|*",
				wxFD_SAVE|wxFD_CHANGE_DIR,
				wxDefaultPosition);
  if ($fd -> ShowModal == wxID_CANCEL) {
    $self->{parent}->status("Saving feff input file aborted.")
  } else {
    my $file = $fd->GetPath;
    open my $OUT, ">".$file;
    print $OUT $self->{feff}->GetValue;
    close $OUT;
    $Demeter::UI::Atoms::demeter -> push_mru("feff", $file);
    $self->{parent}->status("Saved feff input file to $file.");
  };
};

sub clear_all {
  my ($self) = @_;
  $self->{feff}->SetValue(q{}), return 1 if (not $self->{feffobject}->co->default("atoms", "do_confirm"));
  return 1 if ($self->{feff}->GetNumberOfLines <= 1);
  my $yesno = Demeter::UI::Wx::VerbDialog->new($self, -1,
					       "Do you really wish to discard this feff.inp file and replace it with a new one?",
					       "Discard?",
					       "Discard");
  if ($yesno->ShowModal == wxID_NO) {
    return 0;
  } else {
    $self->{feff}->SetValue(q{});
    return 1;
  };
};

sub insert_boilerplate {
  my ($self) = @_;
  return if not $self->clear_all;
  my $feff   = Demeter::Feff->new(screen=>0, buffer=>1, save=>0);
  $self->{feff}->SetValue($feff->template("feff", "boilerplate"));
  undef $feff;
  $self->{parent}->status("Fill in this boilerplate with your structure....");
};


sub run_feff {
  my ($self) = @_;
  return 1 if ($self->{feff}->GetNumberOfLines <= 1);
  my $feff = $self->{feffobject};
  $feff -> clear;
  my $v = ($feff->mo->template_feff eq 'feff8') ? 8 : 6;
  $feff -> feff_version($v);
  #$feff -> screen(1);
  #$feff -> save(1);

  my $inpfile = File::Spec->catfile($feff->workspace, $feff->group . ".inp");
  open my $OUT, ">".$inpfile;
  print $OUT $self->{feff}->GetValue;
  close $OUT;
  $feff->name($self->{parent}->{Feff}->{name}->GetValue);
  $feff->file($inpfile);

  ##print join("|", $feff->feff_version, @{$feff->scf}), $/;
  if (($feff->feff_version == 8) and (@{$feff->scf})) {
    my $md = Demeter::UI::Wx::VerbDialog->new($rframes->{main}, -1,
					      "You are running Feff8 with self-consistent potentials.  It WILL be time consuming and all interaction with Artemis will be blocked until the Feff calculation is done.  Currently Artemis does not provide real-time feedback, so you will have to be very patient.\n\nContinue?",
					      "Feff8 with self-consistent potentials",
					      "Continue");
    if ($md->ShowModal == wxID_NO) {
      $self->{parent}->status("Self-consistent Feff calculation canceled.");
      return 1;
    };
  };

  #print $feff->serialization;
  #return 1;

  #my $zabs = $feff->potentials->[$feff->abs_index]->[1];
  if (get_Z($feff->abs_species) > 95) {
    my $error = Wx::MessageDialog->new($rframes->{main},
				       "The version of Feff you are using cannot calculate for absorbers above Z=95.",
				       "Cannot run Feff",
				       wxOK|wxICON_EXCLAMATION);
    my $result = $error->ShowModal;
    $self->{parent}->status("The version of Feff you are using cannot calculate for absorbers above Z=95.", 'alert');
    return 0;
  };

  if ($feff->rmax > 6.51) {
    my $yesno = Demeter::UI::Wx::VerbDialog->new($self, -1,
						 'You have set RMAX to larger than 6.5 Angstroms.

The pathfinder will likely be quite time consuming,
as will reading and writing a project file
containing this Feff calculation.

Should we continue?',
						 "Continue calculating?",
						 "Continue",
						);
    my $ok = $yesno->ShowModal;
    if ($ok == wxID_NO) {
      $self->{parent}->status("Canceling Feff calculation");
      return 0;
    };

  };


  my %restore  = ();
  my %problems = %{ $feff->problems };
  my @warnings = @{ $problems{warnings} };
  my @errors   = @{ $problems{errors}   };
  if (@errors) {
    warn join($/, @errors) . $/;
    return;
  };
  if (@warnings) {
    warn join($/, @warnings) . $/;
  };

  $self->{parent}->make_page('Console') if not $self->{parent}->{Console};
  $self->{parent}->{Console}->{console}->AppendText($self->now("Feff calculation beginning at ", $feff));
  $self->{parent}->status("Computing potentials using Feff ...");
  my $n = (exists $Demeter::UI::Artemis::frames{main}) ? 4 : 3;
  $self->{parent}->{notebook}->ChangeSelection($n);
  $self->{parent}->{Console}->{console}->Update;
  my $busy = Wx::BusyCursor->new();

  $feff->execution_wrapper(sub{$self->run_and_gather(@_)});

  ## rerunning, so clean upprevious results
  my $phbin = File::Spec->catfile($feff->workspace, 'phase.bin');
  unlink $phbin;
  $self->{parent}->{Paths}->{header}->SetValue(q{}) if exists $self->{parent}->{Paths};
  $self->{parent}->{Paths}->{paths}->DeleteAllItems if exists $self->{parent}->{Paths};

  ## need to disable EVERYTHING so that no event stack up in the queue
  ## during the feff run.  were that happen, they would unqueue when
  ## text is written to the console using Wx::Yield. (see run_and_gather)
  if ($self->{parent}->{component}) {
    $self->{parent}->{toolbar}->Enable(0);
    foreach my $k (keys %$::app) {
      if ($::app->{$k}->IsShown) {
	$restore{$k} = 1;
	$::app->{$k}->Enable(0);
      };
    };
  } else {
    $self->{parent}->GetMenuBar->EnableTop($_,0) foreach (0..1);
    $self->{parent}->{notebook}->Enable(0);
  };
  $feff->potph;

  ## the call to check_exe happened in the previous method call,
  ## however, the logging happens below before "clear_iobuffer" line, so
  ## this appears above the messages from Feff's potph
  $self->{parent}->{Console}->{console}->AppendText("(Feff executable: ".
						    $feff->co->default(qw(feff executable)) .
						    ")\n\n");
  $Demeter::UI::Artemis::frames{main}->status(q{}) if (exists $Demeter::UI::Artemis::frames{main});
  if (-e $phbin) {
    $self->{parent}->{Console}->{console}->AppendText("\n\n********** Running pathfinder...\n");
    $self->{parent}->status("Finding scattering paths using Demeter's pathfinder...");
    $feff->pathfinder;
    my $yaml = File::Spec->catfile($feff->workspace, $feff->group.".yaml");
    $feff->freeze($yaml);

    $self->fill_intrp_page($feff);
    $self->fill_ss_page($feff);

    $self->{parent}->{notebook}->ChangeSelection(2);
    $self->{parent}->status("Feff calculation complete!");
  } else {
    my $n = 4;
    if (exists $Demeter::UI::Artemis::frames{main}) {
      $Demeter::UI::Artemis::frames{main}->status("Feff failed to compute potentials!  See Feff console for details.", 'error');
      $n=4;
    } else {
      $self->{parent}->status("Feff failed to compute potentials!");
      $n=3;
    };
    $self->{parent}->{notebook}->ChangeSelection($n);
  };
  if ($self->{parent}->{component}) {
    $self->{parent}->{toolbar}->Enable(1);
    foreach my $k (keys %restore) {
      $::app->{$k}->Enable(1);
    };
  } else {
    $self->{parent}->GetMenuBar->EnableTop($_,1) foreach (0..1);
    $self->{parent}->{notebook}->Enable(1);
  };


  #$self->{parent}->{Console}->{console}->AppendText(join("\n", @{ $feff->iobuffer }));
  $self->{parent}->{Console}->{console}->AppendText($self->now("Feff calculation finished at ", $feff));
  $feff->clear_iobuffer;

  $feff->execution_wrapper(0);

  #unlink $inpfile;
  undef $busy;
};


sub run_and_gather {
  my ($self, $line) = @_;
  return if ($line =~ m{\A\s*potph});
  return if ($line =~ m{\A\s*titles\s*\z});
  $self->{parent}->{Console}->{console}->AppendText($line);
  $self->{parent}->{Console}->{console}->Update;
  $::app->Yield;		# unqueue this AppendText event
};

# sub run_and_gather {
#   my ($self) = @_;
#   my $cwd = cwd();
#   chdir $self->{feffobject}->workspace;
#   my $exe = Demeter->co->default("feff", "executable");
#   EVT_WXP_PROCESS_STREAM_STDOUT( $self, \&evt_process_stdout );
#   EVT_WXP_PROCESS_STREAM_EXIT  ( $self, \&evt_process_exit   );
#   my $proc = Wx::Perl::ProcessStream::Process->new($exe, 'FeffProcess', $self);
#   $proc->Run;
#   # my $exitcode = $proc->GetExitCode();

#   my $isalive = $proc->IsAlive();
#   while ($isalive) {
#     print "running\n";
#     $isalive = $proc->IsAlive();
#   };

#   chdir $cwd;
# };

# sub evt_process_stdout {
#   my ($self, $event) = @_;
#   $event->Skip(1);
#   my $process = $event->GetProcess;
#   my $line = $event->GetLine;
#   $self->{parent}->{Console}->{console}->AppendText($line.$/);
#   $self->Update;
#   if ($line =~ m{nice day}) {
#     $process->TerminateProcess;
#   };
# };

# sub evt_process_exit {
#   my ($self, $event) = @_;
#   $event->Skip(1);
#   my $process = $event->GetProcess;
#   my $line = $event->GetLine;
#   my @buffers = @{ $process->GetStdOutBuffer };
#   my @errors = @{ $process->GetStdErrBuffer };
#   my $exitcode = $process->GetExitCode;

#   $process->Destroy;
# };

sub fill_intrp_page {
  my ($self, $feff) = @_;
  $self->{parent}->make_page('Paths') if not $self->{parent}->{Paths};
  $self->{parent}->{Paths}->{name}->SetValue($feff->name);
  $self->{parent}->{Paths}->{header}->SetValue($feff->intrp_header);
  $self->{parent}->{Paths}->{paths}->DeleteAllItems;
  my @COLOURS = (Wx::Colour->new( $feff->co->default('feff', 'intrp0color') ),
		 Wx::Colour->new( $feff->co->default('feff', 'intrp1color') ),
		 Wx::Colour->new( $feff->co->default('feff', 'intrp2color') )
		);
  my $i = 0;
  $self->{parent}->make_page('Console') if not $self->{parent}->{Console};
  $self->{parent}->{Console}->{console}->AppendText("\n\n********** Ranking paths...\n");
  $self->{parent}->status("Ranking paths...");
  $feff->rank_paths;
  my $which = (Demeter->co->default('pathfinder', 'rank') eq 'feff') ? 'zcwif' : 'chimag2';
  foreach my $p (@{ $feff->pathlist }) {
    my $idx = $self->{parent}->{Paths}->{paths}->InsertImageStringItem($i, sprintf("%4.4d", $i), 0);
    $self->{parent}->{Paths}->{paths}->SetItemTextColour($idx, $COLOURS[$p->weight]);
    $self->{parent}->{Paths}->{paths}->SetItemData($idx, $i);
    #$self->{parent}->{Paths}->{paths}->SetItemData($idx, $i++);
    $self->{parent}->{Paths}->{paths}->SetItem($idx, 1, $p->n);
    $self->{parent}->{Paths}->{paths}->SetItem($idx, 2, sprintf("%.4f", $p->fuzzy));
    $self->{parent}->{Paths}->{paths}->SetItem($idx, 3, $p->intrplist);
    #$self->{parent}->{Paths}->{paths}->SetItem($idx, 4, $p->weight);
    $self->{parent}->{Paths}->{paths}->SetItem($idx, 4, $p->get_rank($which));
    $self->{parent}->{Paths}->{paths}->SetItem($idx, 5, $p->nleg);
    $self->{parent}->{Paths}->{paths}->SetItem($idx, 6, $p->Type);
    ++$i;
  };
  my $which = 6;
  if (Demeter->po->space eq 'k') {
    $which = 5;
  } elsif (Demeter->po->space eq 'q') {
    $which = 5;
  } elsif (Demeter->po->r_pl eq 'm') {
    $which = 6;
  } elsif (Demeter->po->r_pl eq 'r') {
    $which = 7;
  } elsif (Demeter->po->r_pl eq 'i') {
    $which = 8;
  };
  $self->{parent}->{Paths}->{toolbar} -> ToggleTool($which, 1);
};

sub fill_ss_page {
  my ($self, $feff) = @_;

  #$self->{parent}->{SS}->{name}->SetValue($feff->name);
  return 0 if ($Demeter::UI::AtomsApp::utilities[3] ne 'SS');
  $self->{parent}->make_page('SS') if not $self->{parent}->{SS};

  my @ipots = @{$feff->potentials};
  shift @ipots;			# get rid of absorber
  my $ipmax = $#ipots;
  my @entries = map {sprintf("%d: %s", $_->[0], $_->[2])} @ipots;
  my $i = 0;
  foreach my $e (@entries) {
    $self->{parent}->{SS}->{ss_ipot}->SetLabel($i, $e);
    $self->{parent}->{SS}->{ss_ipot}->Enable($i, 1);
    $self->{parent}->{SS}->{histo_ss_ipot}->SetLabel($i, $e);
    $self->{parent}->{SS}->{histo_ss_ipot}->Enable($i, 1);
    $self->{parent}->{SS}->{histo_ncl_ipot1}->SetLabel($i, $e);
    $self->{parent}->{SS}->{histo_ncl_ipot1}->Enable($i, 1);
    $self->{parent}->{SS}->{histo_ncl_ipot2}->SetLabel($i, $e);
    $self->{parent}->{SS}->{histo_ncl_ipot2}->Enable($i, 1);
    $self->{parent}->{SS}->{histo_thru_ipot1}->SetLabel($i, $e);
    $self->{parent}->{SS}->{histo_thru_ipot1}->Enable($i, 1);
    $self->{parent}->{SS}->{histo_thru_ipot2}->SetLabel($i, $e);
    $self->{parent}->{SS}->{histo_thru_ipot2}->Enable($i, 1);
    ++$i;
  };
  foreach my $ii ($i .. 6) {
    $self->{parent}->{SS}->{ss_ipot}->SetLabel($ii, q{     });
    $self->{parent}->{SS}->{ss_ipot}->Enable($ii, 0);
    $self->{parent}->{SS}->{histo_ss_ipot}->SetLabel($ii, q{     });
    $self->{parent}->{SS}->{histo_ss_ipot}->Enable($ii, 0);
    $self->{parent}->{SS}->{histo_ncl_ipot1}->SetLabel($ii, q{     });
    $self->{parent}->{SS}->{histo_ncl_ipot1}->Enable($ii, 0);
    $self->{parent}->{SS}->{histo_ncl_ipot2}->SetLabel($ii, q{     });
    $self->{parent}->{SS}->{histo_ncl_ipot2}->Enable($ii, 0);
    $self->{parent}->{SS}->{histo_thru_ipot1}->SetLabel($ii, q{     });
    $self->{parent}->{SS}->{histo_thru_ipot1}->Enable($ii, 0);
    $self->{parent}->{SS}->{histo_thru_ipot2}->SetLabel($ii, q{     });
    $self->{parent}->{SS}->{histo_thru_ipot2}->Enable($ii, 0);
  };
  if ($self->{parent}->{SS}->{histo_ss_ipot}->GetSelection > $ipmax) {
    $self->{parent}->{SS}->{histo_ss_ipot}->SetSelection(0);
  };
  if ($self->{parent}->{SS}->{histo_ncl_ipot1}->GetSelection > $ipmax) {
    $self->{parent}->{SS}->{histo_ncl_ipot1}->SetSelection(0);
  };
  if ($self->{parent}->{SS}->{histo_ncl_ipot2}->GetSelection > $ipmax) {
    $self->{parent}->{SS}->{histo_ncl_ipot2}->SetSelection(0);
  };
  if ($self->{parent}->{SS}->{histo_thru_ipot1}->GetSelection > $ipmax) {
    $self->{parent}->{SS}->{histo_thru_ipot1}->SetSelection(0);
  };
  if ($self->{parent}->{SS}->{histo_thru_ipot2}->GetSelection > $ipmax) {
    $self->{parent}->{SS}->{histo_thru_ipot2}->SetSelection(0);
  };

  $self->{parent}->{SS}->{ss_name}->SetValue($feff->potentials->[0]->[2] . ' SS');
  $self->{parent}->{SS}->{ss_drag}->Enable(1);
  $self->{parent}->{SS}->{histo_ss_drag}->Enable(1);
  $self->{parent}->{SS}->{histo_ncl_drag}->Enable(1);
  $self->{parent}->{SS}->{histo_thru_drag}->Enable(1);
};

sub now {
  my ($self, $text, $feff) = @_;
  my $string = $/ x 2;
  $string   .= '********** ' . $text . $feff->now;
  $string   .= $/ x 2;
  return $string;
};

1;

=head1 NAME

Demeter::UI::Atoms::Feff - Atoms' Feff utility

=head1 VERSION

This documentation refers to Demeter version 0.9.15.

=head1 DESCRIPTION

This class is used to populate the Feff tab in the Wx version of Atoms.

=head1 AUTHOR

Bruce Ravel (bravel AT bnl DOT gov)

L<http://cars9.uchicago.edu/~ravel/software/>

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2013 Bruce Ravel (bravel AT bnl DOT gov). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
