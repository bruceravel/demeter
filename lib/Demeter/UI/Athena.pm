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

  #my $conffile = File::Spec->catfile(dirname($INC{'Demeter/UI/Artemis.pm'}), 'Artemis', 'share', "artemis.demeter_conf");
  #$demeter -> co -> read_config($conffile);
  #$demeter -> co -> read_ini('artemis');
  #$demeter -> plot_with($demeter->co->default(qw(plot plotwith)));

  ## -------- import all of Artemis' various parts
  #foreach my $m (qw(GDS Plot History Journal Log Buffer Status Config Data Prj)) {
  #  next if $INC{"Demeter/UI/Artemis/$m.pm"};
  #  ##print "Demeter/UI/Artemis/$m.pm\n";
  #  require "Demeter/UI/Artemis/$m.pm";
  #};

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
  my $bar      = Wx::MenuBar->new;
  my $filemenu = Wx::Menu->new;
  my $helpmenu = Wx::Menu->new;

  $bar->Append( $filemenu, "&File" );
  $bar->Append( $helpmenu, "&Help" );
  $frames{main}->SetMenuBar( $bar );

  my $box = Wx::BoxSizer->new( wxVERTICAL );

  my $hbox = Wx::BoxSizer->new( wxHORIZONTAL );
  $box -> Add($hbox, 0, wxGROW|wxRIGHT, 5);

  my $viewbox = Wx::BoxSizer->new( wxVERTICAL );
  $hbox -> Add($viewbox, 0, wxRIGHT, 5);

  my $toolbox = Wx::BoxSizer->new( wxVERTICAL );
  $hbox -> Add($toolbox, 0, wxRIGHT, 5);

  my $views = Wx::Choice->new($frames{main}, -1, wxDefaultPosition, wxDefaultSize, ['Data processing', 'Calibrate', 'Alignment', 'Preferences']);
  $toolbox -> Add($views, 0, wxGROW|wxALL, 5);


  my $redbox = Wx::BoxSizer->new( wxHORIZONTAL );
  $toolbox -> Add($redbox, 0, wxGROW|wxALL, 5);
  foreach my $which (qw(E k R q kq)) {
    my $key = 'plot_red_'.$which;
    $frames{main}->{$key} = Wx::Button -> new($frames{main}, -1, $which, wxDefaultPosition, wxDefaultSize, wxBU_EXACTFIT);
    $frames{main}->{$key}->SetBackgroundColour( Wx::Colour->new(139, 0, 0, 0) );
    $frames{main}->{$key}->SetOwnForegroundColour( Wx::Colour->new(255, 255, 255, 0) );
    $redbox -> Add($frames{main}->{$key}, 1, wxALL, 2);
  };

  my $purplebox = Wx::BoxSizer->new( wxHORIZONTAL );
  $toolbox -> Add($purplebox, 0, wxGROW|wxALL, 5);
  foreach my $which (qw(E k R q)) {
    my $key = 'plot_purple_'.$which;
    $frames{main}->{$key} = Wx::Button -> new($frames{main}, -1, $which, wxDefaultPosition, wxDefaultSize, wxBU_EXACTFIT);
    $frames{main}->{$key}->SetForegroundColour( Wx::Colour->new(255, 255, 255, 0) );
    $frames{main}->{$key}->SetBackgroundColour( Wx::Colour->new(148, 0, 211, 0) );
    $purplebox -> Add($frames{main}->{$key}, 1, wxALL, 2);
  };
  

  ## -------- status bar
  $frames{main}->{statusbar} = $frames{main}->CreateStatusBar;

  $frames{main} -> SetSizerAndFit($box);
  $frames{main} -> SetSize(600,800);
  $frames{main} -> Show( 1 );
  $frames{main}->status("Welcome to Athena (" . $demeter->identify . ")");
  1;
}


















=for Explain

Every window in Artemis is a Wx::Frame.  This inserts a method into
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
