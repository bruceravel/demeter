package  Demeter::UI::Atoms::Feff;

use Demeter;
use Demeter::StrTypes qw( Element );

use Cwd;
use File::Spec;

use Wx qw( :everything );
use base 'Wx::Panel';

use Wx::Event qw(EVT_CHOICE EVT_KEY_DOWN EVT_MENU EVT_TOOL_ENTER EVT_ENTER_WINDOW EVT_LEAVE_WINDOW);


my %hints = (
	     save     => "Save this feff.inp file",
	     exec     => "Run Feff on this cluster",
	     boiler   => "Insert boilerplate for a feff.inp file",
	     clear    => "Clear all data",
	    );

sub new {
  my ($class, $page, $parent, $statusbar) = @_;
  my $self = $class->SUPER::new($page, -1, wxDefaultPosition, wxDefaultSize, wxMAXIMIZE_BOX );
  $self->{parent}    = $parent;
  $self->{statusbar} = $statusbar;
  my $vbox = Wx::BoxSizer->new( wxVERTICAL );


  $self->{toolbar} = Wx::ToolBar->new($self, -1, wxDefaultPosition, wxDefaultSize, wxTB_HORIZONTAL|wxTB_3DBUTTONS|wxTB_TEXT);
  EVT_MENU( $self->{toolbar}, -1, sub{my ($toolbar, $event) = @_; OnToolClick($toolbar, $event, $self)} );
  $self->{toolbar} -> AddTool(-1, "Save file",  $self->icon("save"),        wxNullBitmap, wxITEM_NORMAL, q{}, $hints{save} );
  $self->{toolbar} -> AddTool(-1, "Clear all",  $self->icon("empty"),       wxNullBitmap, wxITEM_NORMAL, q{}, $hints{clear});
  $self->{toolbar} -> AddTool(-1, "Template",   $self->icon("boilerplate"), wxNullBitmap, wxITEM_NORMAL, q{}, $hints{boiler});
  $self->{toolbar} -> AddSeparator;
  $self->{toolbar} -> AddTool(-1, "Run Feff",   $self->icon("exec"),        wxNullBitmap, wxITEM_NORMAL, q{}, $hints{exec} );
  EVT_TOOL_ENTER( $self, $self->{toolbar}, sub{my ($toolbar, $event) = @_; &OnToolEnter($toolbar, $event, 'toolbar')} );
  $self->{toolbar} -> Realize;
  $vbox -> Add($self->{toolbar}, 0, wxALL, 5);


  $self->{feffbox}       = Wx::StaticBox->new($self, -1, 'Feff input file', wxDefaultPosition, wxDefaultSize);
  $self->{feffboxsizer}  = Wx::StaticBoxSizer->new( $self->{feffbox}, wxVERTICAL );
  $self->{feff} = Wx::TextCtrl->new($self, -1, q{}, wxDefaultPosition, wxDefaultSize,
				       wxTE_MULTILINE|wxHSCROLL|wxALWAYS_SHOW_SB);
  $self->{feff}->SetFont( Wx::Font->new( 9, wxTELETYPE, wxNORMAL, wxNORMAL, 0, "" ) );
  $self->{feffboxsizer} -> Add($self->{feff}, 1, wxEXPAND|wxALL, 0);

  $vbox -> Add($self->{feffboxsizer}, 1, wxEXPAND|wxALL, 5);

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
  my @callbacks = qw(save_file clear_all insert_boilerplate noop run_feff );
  my $closure = $callbacks[$toolbar->GetToolPos($event->GetId)];
  $self->$closure;
};

sub noop {
  return 1;
};


sub save_file {
  my ($self) = @_;
  my $fd = Wx::FileDialog->new( $self, "Save feff input file", cwd, q{feff.inp},
				"input file (*.inp)|*.inp|All files|*.*",
				wxFD_SAVE|wxFD_CHANGE_DIR,
				wxDefaultPosition);
  $fd -> ShowModal;
  my $file = File::Spec->catfile($fd->GetDirectory, $fd->GetFilename);
  open my $OUT, ">".$file;
  print $OUT $self->{feff}->GetValue;
  close $OUT;
  $self->{statusbar}->SetStatusText("Saved feff input file to $file.");
};

sub clear_all {
  my ($self) = @_;
  $self->{feff}->SetValue(q{});
};

sub insert_boilerplate {
  my ($self) = @_;
  my $feff   = Demeter::Feff->new(screen=>0, buffer=>1, save=>0);
  $self->{feff}->SetValue($feff->template("feff", "boilerplate"));
  undef $feff;
  $self->{statusbar}->SetStatusText("Fill in this boilerplate with your structure....");
};

sub run_feff {
  my ($self) = @_;
  my $busy   = Wx::BusyCursor->new();
  my $feff   = Demeter::Feff->new(screen=>0, buffer=>1, save=>0);
  $feff -> workspace(File::Spec->catfile($feff->stash_folder, $feff->group));
  $feff -> make_workspace;

  my $inpfile = File::Spec->catfile($feff->stash_folder, $feff->group . ".inp");
  open my $OUT, ">".$inpfile;
  print $OUT $self->{feff}->GetValue;
  close $OUT;
  $feff->file($inpfile);

  $self->{parent}->{Console}->{console}->AppendText($self->now("Feff calculation begin at ", $feff));
  $self->{statusbar}->SetStatusText("Computing potentials using Feff6 ...");
  $feff->potph;

  $self->{statusbar}->SetStatusText("Finding scattering paths using Demeter's pathfinder...");
  $feff->pathfinder;

  $self->{parent}->{Paths}->{header}->SetValue($feff->intrp_header);
  $self->{parent}->{Paths}->{paths}->DeleteAllItems;
  my $i = 0;
  foreach my $p (@{ $feff->pathlist }) {
    my $idx = $self->{parent}->{Paths}->{paths}->InsertImageStringItem($i, sprintf("%4.4d", $i), 0);
    $self->{parent}->{Paths}->{paths}->SetItemData($idx, $i++);
    $self->{parent}->{Paths}->{paths}->SetItem($idx, 1, $p->n);
    $self->{parent}->{Paths}->{paths}->SetItem($idx, 2, sprintf("%.4f", $p->fuzzy));
    $self->{parent}->{Paths}->{paths}->SetItem($idx, 3, $p->intrplist);
    $self->{parent}->{Paths}->{paths}->SetItem($idx, 4, $p->weight);
    $self->{parent}->{Paths}->{paths}->SetItem($idx, 5, $p->nleg);
    $self->{parent}->{Paths}->{paths}->SetItem($idx, 6, $p->Type);
  };

  $self->{parent}->{notebook}->ChangeSelection(2);

  $self->{parent}->{Console}->{console}->AppendText(join("\n", @{ $feff->iobuffer }));
  $self->{parent}->{Console}->{console}->AppendText($self->now("Feff calculation finished at ", $feff));
  $feff->clear_iobuffer;

  $self->{statusbar}->SetStatusText("Feff calculation complete!");
  unlink $inpfile;
  undef $busy;
};

sub now {
  my ($self, $text, $feff) = @_;
  my $string = $/ x 2;
  $string   .= '********** ' . $text . $feff->now;
  $string   .= $/ x 2;
  return $string;
};

1;

## busy indicator
## report list of intrp
## dump iobuffer into console
