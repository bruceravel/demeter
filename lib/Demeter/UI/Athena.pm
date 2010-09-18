package Demeter::UI::Athena;

use Demeter; # qw(:plotwith=gnuplot);
use Demeter::UI::Wx::MRU;
use Demeter::UI::Wx::SpecialCharacters qw(:all);

use vars qw($demeter $buffer $plotbuffer);
$demeter = Demeter->new;
$demeter->set_mode(ifeffit=>1, screen=>0);

use Cwd;
use File::Basename;
use File::Copy;
use File::Path;
use File::Spec;

use Wx qw(:everything);
use Wx::Event qw(EVT_MENU EVT_CLOSE EVT_TOOL_ENTER EVT_CHECKBOX EVT_BUTTON
		 EVT_TOGGLEBUTTON EVT_ENTER_WINDOW EVT_LEAVE_WINDOW
		 EVT_TOOL_RCLICKED EVT_RIGHT_UP
		 EVT_NOTEBOOK_PAGE_CHANGING
	       );
use base 'Wx::App';

use Wx::Perl::Carp qw(verbose);
$SIG{__WARN__} = sub {Wx::Perl::Carp::warn($_[0])};
$SIG{__DIE__}  = sub {Wx::Perl::Carp::warn($_[0])};

sub identify_self {
  my @caller = caller;
  return dirname($caller[1]);
};
use vars qw($athena_base $icon $noautosave %frames);
$athena_base = identify_self();
$noautosave = 0;		# set this to skip autosave, see Demeter::UI::Artemis::Import::_feffit


sub OnInit {
  my ($app) = @_;
  $demeter -> mo -> ui('Wx');
  $demeter -> mo -> identity('Athena');

  my $conffile = File::Spec->catfile(dirname($INC{'Demeter/UI/Athena.pm'}), 'Athena', 'share', "athena.demeter_conf");
  $demeter -> co -> read_config($conffile);
  $demeter -> co -> read_ini('athena');
  $demeter -> plot_with($demeter->co->default(qw(plot plotwith)));


  ## -------- create a new frame and set icon
  $frames{main} = Wx::Frame->new(undef, -1, 'Athena [XAS data processing] - <untitled>',
				 wxDefaultPosition, wxDefaultSize,
				 #[0,0], # position
				 #[0,0]  # size
			       );
  my $iconfile = File::Spec->catfile(dirname($INC{'Demeter/UI/Athena.pm'}), 'Athena', 'icons', "athena.png");
  $icon = Wx::Icon->new( $iconfile, wxBITMAP_TYPE_ANY );
  $frames{main} -> SetIcon($icon);

  ## -------- Set up menubar
  my $bar        = Wx::MenuBar->new;
  my $filemenu   = Wx::Menu->new;
  my $groupmenu  = Wx::Menu->new;
  my $valuesmenu = Wx::Menu->new;
  my $markmenu   = Wx::Menu->new;
  my $mergemenu  = Wx::Menu->new;
  my $helpmenu   = Wx::Menu->new;

  $bar->Append( $filemenu,   "&File" );
  $bar->Append( $groupmenu,  "&Group" );
  $bar->Append( $valuesmenu, "&Values" );
  $bar->Append( $markmenu,   "&Mark" );
  $bar->Append( $mergemenu,  "Merge" );
  $bar->Append( $helpmenu,   "&Help" );
  $frames{main}->SetMenuBar( $bar );

  my $hbox = Wx::BoxSizer->new( wxHORIZONTAL );



  my $viewpanel = Wx::Panel->new($frames{main}, -1);
  my $viewbox = Wx::BoxSizer->new( wxVERTICAL );
  $hbox -> Add($viewpanel, 0, wxGROW|wxALL, 5);

  $frames{main}->{project} = Wx::StaticText->new($viewpanel, -1, q{<Project name>},);
  my $size = Wx::SystemSettings::GetFont(wxSYS_DEFAULT_GUI_FONT)->GetPointSize + 2;
  $frames{main}->{project}->SetFont( Wx::Font->new( $size, wxDEFAULT, wxNORMAL, wxBOLD, 0, "" ) );
  $viewbox -> Add($frames{main}->{project}, 0, wxGROW|wxALL, 5);

  $frames{main}->{views} = Wx::Choicebook->new($viewpanel, -1);
  $viewbox -> Add($frames{main}->{views}, 0, wxALL, 5);

  foreach my $which (qw(Main Calibrate Prefs)) {
    next if $INC{"Demeter/UI/Athena/$which.pm"};
    require "Demeter/UI/Athena/$which.pm";
    $frames{main}->{$which} = "Demeter::UI::Athena::$which"->new($frames{main}->{views});
    my $label = eval '$'.'Demeter::UI::Athena::'.$which.'::label';
    $frames{main}->{views} -> AddPage($frames{main}->{$which}, $label, 0);
  };
  $frames{main}->{views}->SetSelection(0);
  $viewpanel -> SetSizerAndFit($viewbox);





  my $toolpanel = Wx::Panel->new($frames{main}, -1);
  my $toolbox = Wx::BoxSizer->new( wxVERTICAL );
  $hbox -> Add($toolpanel, 1, wxGROW|wxALL, 5);


  $frames{main}->{list} = Wx::CheckListBox->new($toolpanel, -1,);
  $toolbox -> Add($frames{main}->{list}, 1, wxGROW|wxALL, 0);

  my $singlebox = Wx::BoxSizer->new( wxHORIZONTAL );
  $toolbox  -> Add($singlebox, 0, wxGROW|wxALL, 0);
  foreach my $which (qw(E k R q kq)) {
    my $key = 'plot_single_'.$which;
    $frames{main}->{$key} = Wx::Button -> new($toolpanel, -1, $which, wxDefaultPosition, wxDefaultSize, wxBU_EXACTFIT);
    $frames{main}->{$key}->SetBackgroundColour( Wx::Colour->new($demeter->co->default("athena", "single")) );
    $singlebox   -> Add($frames{main}->{$key}, 1, wxALL, 1);
  };

  my $markedbox = Wx::BoxSizer->new( wxHORIZONTAL );
  $toolbox -> Add($markedbox, 0, wxGROW|wxALL, 0);
  foreach my $which (qw(E k R q)) {
    my $key = 'plot_marked_'.$which;
    $frames{main}->{$key} = Wx::Button -> new($toolpanel, -1, $which, wxDefaultPosition, wxDefaultSize, wxBU_EXACTFIT);
    $frames{main}->{$key}->SetBackgroundColour( Wx::Colour->new($demeter->co->default("athena", "marked")) );
    $markedbox   -> Add($frames{main}->{$key}, 1, wxALL, 1);
  };

  $frames{main}->{kweights} = Wx::RadioBox->new($toolpanel, -1, 'Plotting k-weights', wxDefaultPosition, wxDefaultSize,
						[qw(0 1 2 3 kw)], 1, wxRA_SPECIFY_ROWS);
  $toolbox     -> Add($frames{main}->{kweights}, 0, wxGROW|wxALL, 0);

  ## -------- fill the plotting options tabs
  $frames{main}->{plottabs}  = Wx::Notebook->new($toolpanel, -1, wxDefaultPosition, wxDefaultSize, wxNB_TOP);
  foreach my $m (qw(PlotE PlotK PlotR PlotQ)) {
    next if $INC{"Demeter/UI/Athena/$m.pm"};
    require "Demeter/UI/Athena/$m.pm";
    $frames{main}->{$m} = "Demeter::UI::Athena::$m"->new($frames{main}->{plottabs});
    $frames{main}->{plottabs} -> AddPage($frames{main}->{$m}, substr($m, -1), ($m eq 'PlotE'));
  };
  $toolbox     -> Add($frames{main}->{plottabs}, 0, wxGROW|wxALL, 0);

  $toolpanel -> SetSizerAndFit($toolbox);


  ## -------- status bar
  $frames{main}->{statusbar} = $frames{main}->CreateStatusBar;

  $frames{main} -> SetSizerAndFit($hbox);
  #$frames{main} -> SetSize(600,800);
  $frames{main} -> Show( 1 );
  $frames{main} -> status("Welcome to Athena (" . $demeter->identify . ")");
  1;
}


















=for Explain

Every window in Athena is a Wx::Frame.  This inserts a method into
that namespace which serves as a choke point for writing messages to
the status bar.  The two purposes served are (1) to apply some color
to the text in the status bar and (2) to log all such messages.  The
neat thing about doing it this way is that each window will write to
its own status bar yet all messages get captured to a common log.

  $wxframe->status($text, $type);

where the optional $type is one of "normal", "error", or "wait", each
of which corresponds to a different text style in both the status bar
and the log buffer.

=cut

package Wx::Frame;
use Wx qw(wxNullColour);
my $normal = wxNullColour;
my $wait   = Wx::Colour->new("#C5E49A");
my $error  = Wx::Colour->new("#FD7E6F");
my $debug  = 0;
sub status {
  my ($self, $text, $type) = @_;
  $type ||= 'normal';

  if ($debug) {
    local $|=1;
    print $text, " -- ", join(", ", (caller)[0,2]), $/;
  };

  my $color = ($type eq 'normal') ? $normal
            : ($type eq 'wait')   ? $wait
            : ($type eq 'error')  ? $error
	    :                       $normal;
  $self->{statusbar}->SetBackgroundColour($color);
  $self->{statusbar}->SetStatusText($text);
#  $Demeter::UI::Artemis::frames{Status}->put_text($text, $type);
};


1;
