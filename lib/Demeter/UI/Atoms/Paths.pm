package Demeter::UI::Atoms::Paths;

use Demeter::StrTypes qw( Element );
use Demeter::UI::Artemis::DND::PathDrag;
use Demeter::UI::Artemis::ShowText;

use Const::Fast;
use Cwd;
use File::Spec;

use Wx qw( :everything );
use Wx::DND;
use base 'Wx::Panel';

use Wx::Event qw(EVT_CHOICE EVT_KEY_DOWN EVT_MENU EVT_TOOL_ENTER
		 EVT_ENTER_WINDOW EVT_LEAVE_WINDOW EVT_LIST_ITEM_RIGHT_CLICK
		 EVT_LEFT_DOWN EVT_RIGHT_DOWN EVT_LIST_BEGIN_DRAG);

my %hints = (
	     save     => "Save this Feff calculation to a Demeter save file",
	     plot     => "Plot selected paths",
	     chik     => "Plot paths in k space",
	     chir_mag => "Plot paths as the magnitude of chi(R)",
	     chir_re  => "Plot paths as the real part of chi(R)",
	     chir_im  => "Plot paths as the imaginary part of chi(R)",
	     doc      => "Show the path interpretation documentation in a browser",
	     rank     => "Compare path rankings by the various ranking criteria",
	    );

sub new {
  my ($class, $page, $parent) = @_;
  my $self = $class->SUPER::new($page, -1, wxDefaultPosition, wxDefaultSize, wxMAXIMIZE_BOX );
  $self->{parent}    = $parent;
  $self->{statusbar} = $parent->{statusbar};
  my $vbox = Wx::BoxSizer->new( wxVERTICAL );

  $self->{toolbar} = Wx::ToolBar->new($self, -1, wxDefaultPosition, wxDefaultSize, wxTB_HORIZONTAL|wxTB_3DBUTTONS|wxTB_TEXT);
  EVT_MENU( $self->{toolbar}, -1, sub{my ($toolbar, $event) = @_; OnToolClick($toolbar, $event, $self)} );
  #$self->{toolbar} -> AddTool(1, "Save calc.",      $self->icon("save"), wxNullBitmap, wxITEM_NORMAL, q{}, $hints{save});
  #$self->{toolbar} -> AddSeparator;
  $self->{toolbar} -> AddTool(1, "Plot selection",  $self->icon("plot"), wxNullBitmap, wxITEM_NORMAL, q{}, $hints{plot});
  $self->{toolbar} -> AddSeparator;
  $self->{toolbar} -> AddRadioTool(3, 'chi(k)',     $self->icon("chik"),    wxNullBitmap, q{}, $hints{chik});
  my $this = $self->{toolbar} -> AddRadioTool(4, '|chi(R)|',   $self->icon("chirmag"), wxNullBitmap, q{}, $hints{chir_mag});
  $self->{toolbar} -> AddRadioTool(5, 'Re[chi(R)]', $self->icon("chirre"),  wxNullBitmap, q{}, $hints{chir_re});
  $self->{toolbar} -> AddRadioTool(6, 'Im[chi(R)]', $self->icon("chirim"),  wxNullBitmap, q{}, $hints{chir_im});
  $self->{toolbar} -> AddSeparator;
  my $rank = $self->{toolbar} -> AddTool(8, "Rank", $self->icon("rank"),     wxNullBitmap, wxITEM_NORMAL, q{}, $hints{rank});
  $self->{toolbar} -> AddTool(9, "Doc",  $self->icon("document"), wxNullBitmap, wxITEM_NORMAL, q{}, $hints{doc});
  $self->{toolbar} -> ToggleTool(6, 0);
  $self->{toolbar} -> ToggleTool(4, 1);

  $self->{rankid} = $rank->GetId;
  $self->{toolbar}->EnableTool($self->{rankid},0);

  EVT_TOOL_ENTER( $self, $self->{toolbar}, sub{my ($toolbar, $event) = @_; &OnToolEnter($toolbar, $event, 'toolbar')} );
  $self->{toolbar} -> Realize;
  $vbox -> Add($self->{toolbar}, 0, wxGROW|wxALL, 5);

  my $hh = Wx::BoxSizer->new( wxHORIZONTAL );
  $vbox -> Add($hh, 0, wxEXPAND|wxALL, 0);
  my $label      = Wx::StaticText->new($self, -1, 'Name of this Feff calculation: ', wxDefaultPosition, [-1,-1]);
  $self->{name}  = Wx::TextCtrl  ->new($self, -1, q{}, wxDefaultPosition, [70,-1], wxTE_READONLY);
  $hh->Add($label,        0, wxEXPAND|wxALL, 5);
  $hh->Add($self->{name}, 1, wxEXPAND|wxALL, 5);


  $self->{headerbox}       = Wx::StaticBox->new($self, -1, 'Description', wxDefaultPosition, wxDefaultSize);
  $self->{headerboxsizer}  = Wx::StaticBoxSizer->new( $self->{headerbox}, wxVERTICAL );
  $self->{header}          = Wx::TextCtrl->new($self, -1, q{}, wxDefaultPosition, [-1,100],
					       wxTE_MULTILINE|wxALWAYS_SHOW_SB|wxTE_READONLY);
  $self->{header}         -> SetFont( Wx::Font->new( 9, wxTELETYPE, wxNORMAL, wxNORMAL, 0, "" ) );
  $self->{headerboxsizer} -> Add($self->{header}, 0, wxEXPAND|wxALL, 0);

  $vbox -> Add($self->{headerboxsizer}, 0, wxEXPAND|wxALL, 5);

  $self->{pathsbox}       = Wx::StaticBox->new($self, -1, 'Scattering Paths', wxDefaultPosition, wxDefaultSize);
  $self->{pathsboxsizer}  = Wx::StaticBoxSizer->new( $self->{pathsbox}, wxVERTICAL );
  $self->{paths} = Wx::ListView->new($self, -1, wxDefaultPosition, wxDefaultSize, wxLC_REPORT|wxLC_HRULES);
  $self->{paths}->InsertColumn( 0,  q{}		     );
  $self->{paths}->InsertColumn( 1, "Degen"	     );
  $self->{paths}->InsertColumn( 2, "Reff"	     );
  $self->{paths}->InsertColumn( 3, "Scattering path" );
  $self->{paths}->InsertColumn( 4, "Rank"	     );
  $self->{paths}->InsertColumn( 5, "Legs"	     );
  $self->{paths}->InsertColumn( 6, "Type"	     );

  $self->{paths}->SetColumnWidth( 0,  50 );
  $self->{paths}->SetColumnWidth( 1,  55 );
  $self->{paths}->SetColumnWidth( 2,  55 );
  $self->{paths}->SetColumnWidth( 3, 190 );
  $self->{paths}->SetColumnWidth( 4,  50 );
  $self->{paths}->SetColumnWidth( 5,  40 );
  $self->{paths}->SetColumnWidth( 6, 180 );

  #EVT_LIST_ITEM_RIGHT_CLICK($self, $self->{paths}, sub{OnRightClick(@_)});
  EVT_RIGHT_DOWN($self->{paths}, sub{OnRightClick(@_, $self)});
  EVT_MENU($self, -1, sub{ $self->OnMenu(@_) });
  EVT_LIST_BEGIN_DRAG($self, $self->{paths}, \&OnDrag) if $parent->{component};

  $self->{pathsboxsizer} -> Add($self->{paths}, 1, wxEXPAND|wxALL, 0);

  $vbox -> Add($self->{pathsboxsizer}, 1, wxEXPAND|wxALL, 5);

  $self -> SetSizerAndFit( $vbox );
  return $self;
};

sub icon {
  my ($self, $which) = @_;
  my $icon = File::Spec->catfile($Demeter::UI::Atoms::atoms_base, 'Atoms', 'icons', "$which.png");
  return wxNullBitmap if (not -e $icon);
  return Wx::Bitmap->new($icon, wxBITMAP_TYPE_ANY)
};

const my $SHOWGEOM => Wx::NewId();
const my $SELR     => Wx::NewId();
const my $SELA     => Wx::NewId();
const my $SELSS    => Wx::NewId();
const my $SELFOR   => Wx::NewId();
const my $RANKSEL  => Wx::NewId();
const my $RANKALL  => Wx::NewId();

sub OnRightClick {
  my ($list, $event, $parent) = @_;
  foreach my $it (0 .. $list->GetItemCount-1) {
    $list->SetItemState($it, 0, wxLIST_STATE_SELECTED);
  };
  my ($item, $flags) = $list->HitTest($event->GetPosition);
  $list->SetItemState($item, wxLIST_STATE_SELECTED, wxLIST_STATE_SELECTED );
  $parent->{rcselected}=$item;
  my $menu  = Wx::Menu->new(q{});
  $menu->Append($SHOWGEOM, "Show geometry for this path");
  $menu->AppendSeparator;
  $menu->Append($SELA,     "Select paths with rank above A");
  $menu->Append($SELR,     "Select paths shorter than R");
  $menu->Append($SELSS,    "Select single scattering paths");
  $menu->Append($SELFOR,   "Select forward scattering paths");
  $list->PopupMenu($menu, $event->GetPosition);
};

sub OnMenu {
  my ($parent, $p2, $event) = @_;
  my $id = $event->GetId;
  if ($id == $SHOWGEOM) {
    $parent->show_geometry($event);
  } else {
    $parent->Select($id);
  };
}

sub show_geometry {
  my ($parent, $event) = @_;
  my $list = $parent->{paths};
  my @pathlist = @{ $parent->{parent}->{Feff}->{feffobject}->pathlist };
  ## the ItemData is the index of that path in the Feff objects
  ## pathslist -- the counting is done correctly, even if not all
  ## paths are displayed in the path interpretation due to the
  ## postcrit
  my $i = $list->GetItemData($parent->{rcselected});
  my $sp   = $pathlist[$i]; # the ScatteringPath associated with this selected item
  my $feff = $parent->{parent}->{Feff}->{feffobject};
  my $pd = (($feff->source eq 'aggregate') and ($sp->nleg == 2)) ? $feff->path_geom($sp) : $sp->pathsdat;
  ##                                       ^^^^^^^^^^^^^^^^^^^^
  ##                                  fix this once MSPath is working
  $pd =~ s{\A\s+\d+}{};
  $pd =~ s{index,}{};
  my $text = "The path\n\t" . $sp->intrplist . "\nis calculated using these atom positions:\n\n" . $pd;
  my $dialog = Demeter::UI::Artemis::ShowText->new($parent, $text, $sp->intrplist)
    -> Show;
};

sub Select {
  my ($parent, $id) = @_;
  if ($id == $SELR) {
    my $ted = Wx::TextEntryDialog->new( $self, "Select paths shorter than this path length:",
					"Enter a path length", q{}, wxOK|wxCANCEL, Wx::GetMousePosition);
    if ($ted->ShowModal == wxID_CANCEL) {
      $self->status("Path selection canceled.");
      return;
    };
    my $r = $ted->GetValue;
    if ($r !~ m{$NUMBER}) {
      $self->status("Oops!  That wasn't a number.");
      return;
    };
    foreach my $item (0 .. $parent->{paths}->GetItemCount-1) {
      $parent->{paths}->SetItemState($item, 0, wxLIST_STATE_SELECTED);
      $parent->{paths}->SetItemState($item, wxLIST_STATE_SELECTED, wxLIST_STATE_SELECTED )
	if ($parent->{paths}->GetItem($item, 2)->GetText < $r)
      };

  } elsif ($id == $SELA) {
    my $ted = Wx::TextEntryDialog->new( $self, "Select paths which rank above:",
					"Enter a path ranking", q{}, wxOK|wxCANCEL, Wx::GetMousePosition);
    if ($ted->ShowModal == wxID_CANCEL) {
      $self->status("Path selection canceled.");
      return;
    };
    my $a = $ted->GetValue;
    if ($a !~ m{$NUMBER}) {
      $self->status("Oops!  That wasn't a number.");
      return;
    };
    foreach my $item (0 .. $parent->{paths}->GetItemCount-1) {
      $parent->{paths}->SetItemState($item, 0, wxLIST_STATE_SELECTED);
      $parent->{paths}->SetItemState($item, wxLIST_STATE_SELECTED, wxLIST_STATE_SELECTED )
	if ($parent->{paths}->GetItem($item, 4)->GetText > $a)
      };

  } elsif ($id == $SELSS) {
    foreach my $item (0 .. $parent->{paths}->GetItemCount-1) {
      $parent->{paths}->SetItemState($item, 0, wxLIST_STATE_SELECTED);
      $parent->{paths}->SetItemState($item, wxLIST_STATE_SELECTED, wxLIST_STATE_SELECTED )
	if ($parent->{paths}->GetItem($item, 5)->GetText == 2)
      };

  } elsif ($id == $SELFOR) {
    foreach my $item (0 .. $parent->{paths}->GetItemCount-1) {
      $parent->{paths}->SetItemState($item, 0, wxLIST_STATE_SELECTED);
      $parent->{paths}->SetItemState($item, wxLIST_STATE_SELECTED, wxLIST_STATE_SELECTED )
	if ($parent->{paths}->GetItem($item, 6)->GetText =~ m{forward (?:scat|thro)})
      };

  };
};

sub OnDrag {
  my ($parent, $event) = @_;
  my $list = $parent->{paths};
  my $which = $event->GetIndex;
  my @pathlist = @{ $parent->{parent}->{Feff}->{feffobject}->pathlist };
  my @data;
  my $item = $list->GetFirstSelected;
  while ($item ne -1) {
    my $p = $list->GetItemData($item);
    push @data, $pathlist[$p]->group;
    #print $pathlist[$item]->intrpline, $/;
    $item = $list->GetNextSelected($item);
  };
  my $source = Wx::DropSource->new( $list );
  my $dragdata = Demeter::UI::Artemis::DND::PathDrag->new(\@data);
  $source->SetData( $dragdata );
  $source->DoDragDrop(1);
  #$event->Skip(1);
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
  ##                 Vv---------order of toolbar on the screen------------vV
  my @callbacks = qw(plot noop set_plot set_plot set_plot set_plot noop rank document); # save noop 
  my $closure = $callbacks[$toolbar->GetToolPos($event->GetId)];
  $self->$closure($event->GetId);
};

sub noop {
  return 1;
};

sub document {
  $::app->document('feff.paths');
};

sub rank {
  my ($self) = @_;
  return if not $self->{paths}->GetItemCount;

  $self->{parent}->status("Beginning path rank comparison ...");
  my $busy   = Wx::BusyCursor->new();
  my $text = "# Path rankings\n# ------------------------------\n";
  my $feff = $self->{parent}->{Feff}->{feffobject};
  my $hash = {kmin=>3, kmax=>12, rmin=>1, rmax=>4,
	      update=>sub{$self->{parent}->status($_[0], 'nobuffer'); $self->{parent}->Update}};
  $feff->rank_paths(\@Demeter::StrTypes::rankings_list, $hash);

  $text .= "# index   " . sprintf('   %-7s' x ($#Demeter::StrTypes::rankings_list+1), @Demeter::StrTypes::rankings_list) . "\n";
  #my $n = $#Demeter::StrTypes::rankings_list x 10 + 21;
  #my $dashes = '-' x $n;
  #$text .= "# $dashes\n";
  my $i=1;
  my $format = '   %7.2f' x ($#Demeter::StrTypes::rankings_list+1);
  #foreach my $sp (@{ $feff->pathlist }) {
  foreach my $item (0 .. $self->{paths}->GetItemCount-1) {

    my $data = $self->{paths}->GetItemData($item);
    my $sp   = $feff->pathlist->[$data]; # the ScatteringPath associated with this selected item


    $text .= sprintf("  %s  " . $format . "\n",
      $self->{paths}->GetItem($item,0)->GetText, map {$sp->get_rank($_)} @Demeter::StrTypes::rankings_list);
  };

  $self->{parent}->status("Path rank comparison ... done!");
  undef $busy;
  my $dialog = Demeter::UI::Artemis::ShowText->new($self->{parent}, $text, 'Path rankings') -> Show;
};


sub set_plot {
  my ($self, $id) = @_;
  ## set plotting space
  my $space = ($id == 3) ? 'k' : 'r';
  $self->{parent}->{Feff}->{feffobject}->po->space($space);
  # set part of R space plot
  my %pl = (3 => q{}, 4 => 'm', 5 => 'r', 6 => 'i');
  $self->{parent}->{Feff}->{feffobject}->po->r_pl($pl{$id}) if $pl{$id};
  # sensible status bar message
  my %as = (3 => 'chi(k)', 4 => 'the magnitude of chi(R)', 5 => 'the real part of chi(R)', 6 => 'the imaginary part of chi(R)');
  $self->{parent}->status("Plotting as $as{$id}");
  return $self;
};

#sub clear_all {
#  my ($self) = #
#
#};

sub save {
  my ($self) = @_;
  return if not $self->{paths}->GetItemCount;
  my $fd = Wx::FileDialog->new( $self, "Save Feff calculation", cwd, q{feff.yaml},
				"Feff calculations (*.yaml)|*.yaml|All files (*)|*",
				wxFD_SAVE|wxFD_CHANGE_DIR,
				wxDefaultPosition);
  if ($fd -> ShowModal == wxID_CANCEL) {
    $self->{parent}->status("Saving Feff calculation aborted.")
  } else {
    my $yaml = $fd->GetPath;
    $self->{parent}->{Feff}->{feffobject}->freeze($yaml);
    #$self->{parent}->{Feff}->{feffobject}->push_mru("feffcalc", $yaml);
    $self->{parent}->status("Saved Feff calculation to $yaml.")
  };
};

sub plot {
  my ($self) = @_;
  return if not $self->{paths}->GetItemCount;
  my $this = $self->{paths}->GetFirstSelected;
  $self->{parent}->status("No paths are selected!") if ($this == -1);
  my $busy   = Wx::BusyCursor->new();
  $Demeter::UI::Atoms::demeter->po->start_plot;
  $Demeter::UI::Atoms::demeter->reset_path_indeces;
  my $save = $Demeter::UI::Atoms::demeter->po->title;
  $Demeter::UI::Atoms::demeter->po->title("Feff calculation");
  while ($this != -1) {
    my $i    = $self->{paths}->GetItemData($this);
    my $feff = $self->{parent}->{Feff}->{feffobject};
    my $sp   = $feff->pathlist->[$i]; # the ScatteringPath associated with this selected item
    my $space = $self->{parent}->{Feff}->{feffobject}->po->space;

    $self->{parent}->{Console}->{console}->AppendText($self->now("Feff calculation (".$sp->randstring.") beginning at "));
    $self->{parent}->{Console}->{console}->AppendText("(Feff executable: ".
						      $feff->co->default(qw(feff executable)) .
						      ")\n\n");

    Demeter::Path -> new(parent=>$feff, sp=>$sp, name=>$sp->intrplist) -> plot($space);
    #my $path_object = Demeter::Path -> new(parent=>$feff_object, sp=>$sp);
    #$path_object -> plot("r");
    #undef $path_object;
    $this    = $self->{paths}->GetNextSelected($this);

    $self->{parent}->{Console}->{console}->AppendText(join("\n", @{ $feff->iobuffer }));
    $self->{parent}->{Console}->{console}->AppendText($self->now("Feff calculation finished at "));
  };
  $Demeter::UI::Atoms::demeter->po->title($save);
  undef $busy;
};

sub now {
  my ($self, $text, $feff) = @_;
  my $string = $/ x 2;
  $string   .= '********** ' . $text . Demeter->now;
  $string   .= $/ x 2;
  return $string;
};


1;

=head1 NAME

Demeter::UI::Atoms::Paths - Atoms' path organizer utility

=head1 VERSION

This documentation refers to Demeter version 0.9.20.

=head1 DESCRIPTION

This class is used to populate the Paths tab in the Wx version of Atoms.

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
