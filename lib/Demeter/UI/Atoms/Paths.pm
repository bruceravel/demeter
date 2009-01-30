package  Demeter::UI::Atoms::Paths;

use Demeter;
use Demeter::StrTypes qw( Element );

use Cwd;
use File::Spec;

use Wx qw( :everything );
use base 'Wx::Panel';

use Wx::Event qw(EVT_CHOICE EVT_KEY_DOWN EVT_MENU EVT_TOOL_ENTER EVT_ENTER_WINDOW EVT_LEAVE_WINDOW);

my %hints = (
	     save => "Save this feff.inp file",
	     plot => "Plot selected paths",
	    );

sub new {
  my ($class, $page, $parent, $statusbar) = @_;
  my $self = $class->SUPER::new($page, -1, wxDefaultPosition, wxDefaultSize, wxMAXIMIZE_BOX );
  $self->{parent}    = $parent;
  $self->{statusbar} = $statusbar;
  my $vbox = Wx::BoxSizer->new( wxVERTICAL );

  $self->{toolbar} = Wx::ToolBar->new($self, -1, wxDefaultPosition, wxDefaultSize, wxTB_HORIZONTAL|wxTB_3DBUTTONS|wxTB_TEXT);
  EVT_MENU( $self->{toolbar}, -1, sub{my ($toolbar, $event) = @_; OnToolClick($toolbar, $event, $self)} );
  $self->{toolbar} -> AddTool(-1, "Save calculation",  $self->icon("save"), wxNullBitmap, wxITEM_NORMAL, q{}, $hints{save});
  $self->{toolbar} -> AddTool(-1, "Plot selected",     $self->icon("plot"), wxNullBitmap, wxITEM_NORMAL, q{}, $hints{plot});
  EVT_TOOL_ENTER( $self, $self->{toolbar}, sub{my ($toolbar, $event) = @_; &OnToolEnter($toolbar, $event, 'toolbar')} );
  $self->{toolbar} -> Realize;
  $vbox -> Add($self->{toolbar}, 0, wxALL, 5);


  $self->{headerbox}       = Wx::StaticBox->new($self, -1, 'Description', wxDefaultPosition, wxDefaultSize);
  $self->{headerboxsizer}  = Wx::StaticBoxSizer->new( $self->{headerbox}, wxVERTICAL );
  $self->{header} = Wx::TextCtrl->new($self, -1, q{}, wxDefaultPosition, wxDefaultSize,
				       wxTE_MULTILINE|wxHSCROLL|wxALWAYS_SHOW_SB);
  $self->{header}->SetFont( Wx::Font->new( 9, wxTELETYPE, wxNORMAL, wxNORMAL, 0, "" ) );
  $self->{headerboxsizer} -> Add($self->{header}, 0, wxEXPAND|wxALL, 0);

  $vbox -> Add($self->{headerboxsizer}, 0, wxEXPAND|wxALL, 5);

  $self->{pathsbox}       = Wx::StaticBox->new($self, -1, 'Scattering Paths', wxDefaultPosition, wxDefaultSize);
  $self->{pathsboxsizer}  = Wx::StaticBoxSizer->new( $self->{pathsbox}, wxVERTICAL );
  $self->{paths} = Wx::ListView->new($self, -1, wxDefaultPosition, wxDefaultSize, wxLC_REPORT|wxLC_HRULES);
  $self->{paths}->InsertColumn( 0, q{} );
  $self->{paths}->InsertColumn( 1, "Degen" );
  $self->{paths}->InsertColumn( 2, "Reff" );
  $self->{paths}->InsertColumn( 3, "Scattering path" );
  $self->{paths}->InsertColumn( 4, "Imp." );
  $self->{paths}->InsertColumn( 5, "Legs" );
  $self->{paths}->InsertColumn( 6, "Type" );

  $self->{paths}->SetColumnWidth( 0, 50 );
  $self->{paths}->SetColumnWidth( 1, 50 );
  $self->{paths}->SetColumnWidth( 2, 55 );
  $self->{paths}->SetColumnWidth( 3, 190 );
  $self->{paths}->SetColumnWidth( 4, 35 );
  $self->{paths}->SetColumnWidth( 5, 40 );
  $self->{paths}->SetColumnWidth( 6, 180 );



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
  my @callbacks = qw(save plot);
  my $closure = $callbacks[$toolbar->GetToolPos($event->GetId)];
  $self->$closure;
};

sub noop {
  return 1;
};

sub save {
  print "save a yaml\n";
};

sub plot {
  print "plot some paths\n";
};


1;
