package  Demeter::UI::Atoms::Feff;

use Demeter;
use Demeter::StrTypes qw( Element );

use Cwd;
use File::Spec;

use Wx qw( :everything );
use base 'Wx::Panel';

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
    $self->{statusbar}->SetStatusText($self->{$which}->GetToolLongHelp($event->GetSelection));
  } else {
    $self->{statusbar}->SetStatusText(q{});
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
  $self->{statusbar}->SetStatusText("There are no recent Feff files."), return
    if ($dialog == -1);
  if( $dialog->ShowModal == wxID_CANCEL ) {
    $self->{statusbar}->SetStatusText("Import cancelled.");
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
				  "input file (*.inp)|*.inp|All files|*",
				  wxFD_OPEN|wxFD_FILE_MUST_EXIST|wxFD_CHANGE_DIR|wxFD_PREVIEW,
				  wxDefaultPosition);
    $fd -> ShowModal;
    $file = File::Spec->catfile($fd->GetDirectory, $fd->GetFilename);
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
				"input file (*.inp)|*.inp|All files|*",
				wxFD_SAVE|wxFD_CHANGE_DIR,
				wxDefaultPosition);
  if ($fd -> ShowModal == wxID_CANCEL) {
    $self->{statusbar}->SetStatusText("Saving feff input file aborted.")
  } else {
    my $file = File::Spec->catfile($fd->GetDirectory, $fd->GetFilename);
    open my $OUT, ">".$file;
    print $OUT $self->{feff}->GetValue;
    close $OUT;
    $Demeter::UI::Atoms::demeter -> push_mru("feff", $file);
    $self->{statusbar}->SetStatusText("Saved feff input file to $file.");
  };
};

sub clear_all {
  my ($self) = @_;
  $self->{feff}->SetValue(q{}), return 1 if (not $self->{feffobject}->co->default("atoms", "do_confirm"));
  return 1 if ($self->{feff}->GetNumberOfLines <= 1);
  my $yesno = Wx::MessageDialog->new($self, "Do you really wish to discard this feff.inp file and replace it with a new one?",
				     "Discard?", wxYES_NO);
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
  $self->{statusbar}->SetStatusText("Fill in this boilerplate with your structure....");
};


sub run_feff {
  my ($self) = @_;
  return 1 if ($self->{feff}->GetNumberOfLines <= 1);
  my $busy = Wx::BusyCursor->new();
  my $feff = $self->{feffobject};
  $feff -> clear;

  my $inpfile = File::Spec->catfile($feff->workspace, $feff->group . ".inp");
  open my $OUT, ">".$inpfile;
  print $OUT $self->{feff}->GetValue;
  close $OUT;
  $feff->name($self->{parent}->{Feff}->{name}->GetValue);
  print $feff->name, $/;
  $feff->file($inpfile);


  my %problems = %{ $feff->problems };
  my @warnings = @{ $problems{warnings} };
  my @errors   = @{ $problems{errors}   };
  if (@errors) {
    warn join($/, @errors) . $/;
    undef $busy;
    return;
  };
  if (@warnings) {
    warn join($/, @warnings) . $/;
  };

  $self->{parent}->{Console}->{console}->AppendText($self->now("Feff calculation beginning at ", $feff));
  $self->{statusbar}->SetStatusText("Computing potentials using Feff6 ...");
  $feff->potph;
  print $feff->name, $/;

  $self->{statusbar}->SetStatusText("Finding scattering paths using Demeter's pathfinder...");
  $feff->pathfinder;
  my $yaml = File::Spec->catfile($feff->workspace, $feff->group.".yaml");
  $feff->freeze($yaml);
  print $feff->name, $/;

  $self->fill_intrp_page($feff);
  $self->fill_ss_page($feff);

  $self->{parent}->{notebook}->ChangeSelection(2);

  $self->{parent}->{Console}->{console}->AppendText(join("\n", @{ $feff->iobuffer }));
  $self->{parent}->{Console}->{console}->AppendText($self->now("Feff calculation finished at ", $feff));
  $feff->clear_iobuffer;

  $self->{statusbar}->SetStatusText("Feff calculation complete!");
  #unlink $inpfile;
  undef $busy;
};

sub fill_intrp_page {
  my ($self, $feff) = @_;
  $self->{parent}->{Paths}->{name}->SetValue($feff->name);
  $self->{parent}->{Paths}->{header}->SetValue($feff->intrp_header);
  $self->{parent}->{Paths}->{paths}->DeleteAllItems;
  my @COLOURS = (Wx::Colour->new( $feff->co->default('feff', 'intrp0color') ),
		 Wx::Colour->new( $feff->co->default('feff', 'intrp1color') ),
		 Wx::Colour->new( $feff->co->default('feff', 'intrp2color') )
		);
  my $i = 0;
  foreach my $p (@{ $feff->pathlist }) {
    my $idx = $self->{parent}->{Paths}->{paths}->InsertImageStringItem($i, sprintf("%4.4d", $i), 0);
    $self->{parent}->{Paths}->{paths}->SetItemTextColour($idx, $COLOURS[$p->weight]);
    $self->{parent}->{Paths}->{paths}->SetItemData($idx, $i);
    #$self->{parent}->{Paths}->{paths}->SetItemData($idx, $i++);
    $self->{parent}->{Paths}->{paths}->SetItem($idx, 1, $p->n);
    $self->{parent}->{Paths}->{paths}->SetItem($idx, 2, sprintf("%.4f", $p->fuzzy));
    $self->{parent}->{Paths}->{paths}->SetItem($idx, 3, $p->intrplist);
    $self->{parent}->{Paths}->{paths}->SetItem($idx, 4, $p->weight);
    $self->{parent}->{Paths}->{paths}->SetItem($idx, 5, $p->nleg);
    $self->{parent}->{Paths}->{paths}->SetItem($idx, 6, $p->Type);
    ++$i;
  };
};

sub fill_ss_page {
  my ($self, $feff) = @_;
  #$self->{parent}->{SS}->{name}->SetValue($feff->name);
  return 0 if not exists $self->{parent}->{SS};

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

This documentation refers to Demeter version 0.4.

=head1 DESCRIPTION

This class is used to populate the Feff tab in the Wx version of Atoms.

=head1 AUTHOR

Bruce Ravel (bravel AT bnl DOT gov)

L<http://cars9.uchicago.edu/~ravel/software/>

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2011 Bruce Ravel (bravel AT bnl DOT gov). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
