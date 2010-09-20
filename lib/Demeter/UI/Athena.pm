package Demeter::UI::Athena;

use Demeter; # qw(:plotwith=gnuplot);
use Demeter::UI::Wx::MRU;
use Demeter::UI::Wx::SpecialCharacters qw(:all);
use Demeter::UI::Athena::Import;
use Demeter::UI::Athena::Replot;

use Demeter::UI::Artemis::Buffer;
use Demeter::UI::Artemis::ShowText;
use Demeter::UI::Athena::Status;

use vars qw($demeter $buffer $plotbuffer);
$demeter = Demeter->new;
$demeter->set_mode(ifeffit=>1, screen=>0);

use Cwd;
use File::Basename;
use File::Copy;
use File::Path;
use File::Spec;
use Readonly;

use Wx qw(:everything);
use Wx::Event qw(EVT_MENU EVT_CLOSE EVT_TOOL_ENTER EVT_CHECKBOX EVT_BUTTON
		 EVT_ENTER_WINDOW EVT_LEAVE_WINDOW
		 EVT_RIGHT_UP EVT_LISTBOX
		 EVT_CHOICEBOOK_PAGE_CHANGING EVT_RADIOBOX
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
  $app->{main} = Wx::Frame->new(undef, -1, 'Athena [XAS data processing] - <untitled>', wxDefaultPosition, wxDefaultSize,);
  my $iconfile = File::Spec->catfile(dirname($INC{'Demeter/UI/Athena.pm'}), 'Athena', 'icons', "athena.png");
  $icon = Wx::Icon->new( $iconfile, wxBITMAP_TYPE_ANY );
  $app->{main} -> SetIcon($icon);

  ## -------- Set up menubar
  $app -> menubar;
  $app -> set_mru();

  ## -------- status bar
  $app->{main}->{statusbar} = $app->{main}->CreateStatusBar;

  ## -------- the business part of the window
  my $hbox = Wx::BoxSizer->new( wxHORIZONTAL );
  $app -> main_window($hbox);
  $app -> side_bar($hbox);

  ## -------- other "globals"
  $app->{lastplot} = [q{}, q{}];
  $app->{selected} = -1;
  $app->{main}->{Status} = Demeter::UI::Athena::Status->new($app->{main});
  $app->{Buffer} = Demeter::UI::Artemis::Buffer->new($app->{main});
  $app->{Buffer}->SetTitle("Athena [Ifeffit \& Plot Buffer]");
  ## this needs to be fixed...
  $app->{Buffer}->{ifeffitprompt}->Enable(0);
  $app->{Buffer}->{commandline}->SetValue('## broken ...');
  $app->{Buffer}->{commandline}->Enable(0);

  $demeter->set_mode(callback     => \&ifeffit_buffer,
		     plotcallback => ($demeter->mo->template_plot eq 'pgplot') ? \&ifeffit_buffer : \&plot_buffer,
		     feedback     => \&feedback,
		    );

  $app->{main} -> SetSizerAndFit($hbox);
  #$app->{main} -> SetSize(600,800);
  $app->{main} -> Show( 1 );
  $app->{main} -> status("Welcome to Athena (" . $demeter->identify . ")");
  1;
};

sub ifeffit_buffer {
  my ($text) = @_;
  foreach my $line (split(/\n/, $text)) {
    my ($was, $is) = $::app->{Buffer}->insert('ifeffit', $line);
    my $color = ($line =~ m{\A\#}) ? 'comment' : 'normal';
    $::app->{Buffer}->color('ifeffit', $was, $is, $color);
    $::app->{Buffer}->insert('ifeffit', $/)
  };
};
sub plot_buffer {
  my ($text) = @_;
  foreach my $line (split(/\n/, $text)) {
    my ($was, $is) = $::app->{Buffer}->insert('plot', $line);
    my $color = ($line =~ m{\A\#}) ? 'comment'
      : ($demeter->mo->template_plot eq 'singlefile') ? 'singlefile'
	:'normal';

    $::app->{Buffer}->color('plot', $was, $is, $color);
    $::app->{Buffer}->insert('plot', $/)
  };
};
sub feedback {
  my ($text) = @_;
  my ($was, $is) = $::app->{Buffer}->insert('ifeffit', $text);
  my $color = ($text =~ m{\A\s*\*}) ? 'warning' : 'feedback';
  $::app->{Buffer}->color('ifeffit', $was, $is, $color);
};


sub mouseover {
  my ($app, $widget, $text) = @_;
  return if not $demeter->co->default("athena", "hints");
  my $sb = $app->{main}->{statusbar};
  EVT_ENTER_WINDOW($widget, sub{$sb->PushStatusText($text); $_[1]->Skip});
  EVT_LEAVE_WINDOW($widget, sub{$sb->PopStatusText if ($sb->GetStatusText eq $text); $_[1]->Skip});
};


sub on_close {
  my ($self, $event) = @_;
#  if ($app->{main} -> {modified}) {
#    ## offer to save project....
#    my $yesno = Wx::MessageDialog->new($app->{main},
#				       "Save this project before exiting?",
#				       "Save project?",
#				       wxYES_NO|wxCANCEL|wxYES_DEFAULT|wxICON_QUESTION);
#    my $result = $yesno->ShowModal;
#    if ($result == wxID_CANCEL) {
#      $app->{main}->status("Not exiting Artemis.");
#      return 0;
#    };
#    save_project(\%frames) if $result == wxID_YES;
#  };

#  unlink $app->{main}->{autosave_file};
  $demeter->mo->destroy_all;
  $event->Skip(1);
};


Readonly my $SAVE_MARKED  => Wx::NewId();
Readonly my $PLOT_QUAD	  => Wx::NewId();
Readonly my $PLOT_IOSIG	  => Wx::NewId();
Readonly my $PLOT_K123	  => Wx::NewId();
Readonly my $PLOT_R123	  => Wx::NewId();
Readonly my $SHOW_BUFFER  => Wx::NewId();
Readonly my $PLOT_YAML	  => Wx::NewId();
Readonly my $MODE_STATUS  => Wx::NewId();
Readonly my $PERL_MODULES => Wx::NewId();
Readonly my $STATUS	  => Wx::NewId();

sub menubar {
  my ($app) = @_;
  my $bar        = Wx::MenuBar->new;
  $app->{main}->{mrumenu} = Wx::Menu->new;
  my $filemenu   = Wx::Menu->new;
  $filemenu->Append(wxID_OPEN,  "Import data", "Import data from a data or project file" );
  $filemenu->AppendSubMenu($app->{main}->{mrumenu}, "Recent files",    "This submenu contains a list of recently used files" );
  $filemenu->AppendSeparator;
  $filemenu->Append(wxID_SAVE,    "Save project", "Save an Athena project file" );
  $filemenu->Append(wxID_SAVEAS,  "Save project as...", "Save an Athena project file as..." );
  $filemenu->Append($SAVE_MARKED, "Save marked groups as...", "Save marked groups as an Athena project file as..." );
  $filemenu->AppendSeparator;
  $filemenu->Append(wxID_CLOSE, "&Close" );
  $filemenu->Append(wxID_EXIT,  "E&xit" );

  my $monitormenu = Wx::Menu->new;
  my $debugmenu = Wx::Menu->new;
  $debugmenu->Append($PLOT_YAML,    "Show YAML for Plot object",  "Show YAML for Plot object",  wxITEM_NORMAL );
  $debugmenu->Append($MODE_STATUS,  "Mode status",                "Mode status",  wxITEM_NORMAL );
  $debugmenu->Append($PERL_MODULES, "Perl modules",               "Show perl module versions", wxITEM_NORMAL );
  $monitormenu->Append($SHOW_BUFFER, "Show command buffer", 'Show the Ifeffit and plotting commands buffer' );
  $monitormenu->Append($STATUS,      "Show status bar buffer", 'Show the buffer containing messages written to the status bars');
  $monitormenu->AppendSubMenu($debugmenu, 'Debug options',     'Display debugging tools')
    if ($demeter->co->default("athena", "debug_menus"));


  my $groupmenu   = Wx::Menu->new;
  my $valuesmenu  = Wx::Menu->new;
  my $plotmenu    = Wx::Menu->new;
  my $currentplotmenu = Wx::Menu->new;
  my $markedplotmenu  = Wx::Menu->new;
  $currentplotmenu->Append($PLOT_QUAD,       "Quad plot",      "Make a quad plot from the current group" );
  $currentplotmenu->Append($PLOT_IOSIG,      "Data+I0+Signal", "Plot data, I0, and signal from the current group" );
  $currentplotmenu->Append($PLOT_K123,       "k123 plot",      "Make a k123 plot from the current group" );
  $currentplotmenu->Append($PLOT_R123,       "R123 plot",      "Make an R123 plot from the current group" );
  $plotmenu->AppendSubMenu($currentplotmenu, "Current group",  "Additional plot types for the current group");
  $plotmenu->AppendSubMenu($markedplotmenu,  "Marked groups",  "Additional plot types for the marked groups");

  my $markmenu   = Wx::Menu->new;
  my $mergemenu  = Wx::Menu->new;
  my $helpmenu   = Wx::Menu->new;

  $bar->Append( $filemenu,    "&File" );
  $bar->Append( $groupmenu,   "&Group" );
  $bar->Append( $valuesmenu,  "&Values" );
  $bar->Append( $plotmenu,    "&Plot" );
  $bar->Append( $markmenu,    "&Mark" );
  $bar->Append( $mergemenu,   "Merge" );
  $bar->Append( $monitormenu, "M&onitor" );
  $bar->Append( $helpmenu,    "&Help" );
  $app->{main}->SetMenuBar( $bar );

  EVT_MENU	 ($app->{main}, -1, sub{my ($frame,  $event) = @_; OnMenuClick($frame,  $event, $app)} );
  EVT_CLOSE	 ($app->{main},     \&on_close);
  return $app;
};

sub set_mru {
  my ($app) = @_;

  foreach my $i (0 .. $app->{main}->{mrumenu}->GetMenuItemCount-1) {
    $app->{main}->{mrumenu}->Delete($app->{main}->{mrumenu}->FindItemByPosition(0));
  };

  my @list = $demeter->get_mru_list('xasdata');
  foreach my $f (@list) {
    ##print ">> ", join("|", @$f),  "  \n";
    $app->{main}->{mrumenu}->Append(-1, $f->[0]);
  };
};


sub OnMenuClick {
  my ($self, $event, $app) = @_;
  my $id = $event->GetId;
  my $mru = $app->{main}->{mrumenu}->GetLabel($id);

 SWITCH: {
    ($mru) and do {
      $app -> Import('data', $mru);
      last SWITCH;
    };
    ($id == wxID_ABOUT) and do {
      &on_about;
      return;
    };
    ($id == wxID_CLOSE) and do {
      #close_project(\%frames);
      print "close\n";
      return;
    };
    ($id == wxID_EXIT) and do {
      $self->Close;
      return;
    };
    ($id == wxID_OPEN) and do {
      $app -> Import('data');
      last SWITCH;
    };

    ## -------- monitor menu
    ($id == $SHOW_BUFFER) and do {
      $app->{Buffer}->Show(1);
      last SWITCH;
    };
    ($id == $STATUS) and do {
      $app->{main}->{Status} -> Show(1);
      last SWITCH;
    };
    ## -------- debug submenu
    ($id == $PLOT_YAML) and do {
      $app->{main}->{PlotE}->pull_single_values;
      $app->{main}->{PlotK}->pull_single_values;
      $app->{main}->{PlotR}->pull_marked_values;
      $app->{main}->{PlotQ}->pull_marked_values;
      my $yaml   = $demeter->po->serialization;
      my $dialog = Demeter::UI::Artemis::ShowText->new($app->{main}, $yaml, 'YAML of Plot object') -> Show;
      last SWITCH;
    };
    ($id == $PERL_MODULES) and do {
      my $text   = $demeter->module_environment . $demeter -> wx_environment;
      my $dialog = Demeter::UI::Artemis::ShowText->new($app->{main}, $text, 'Perl module versions') -> Show;
      last SWITCH;
    };
    ($id == $MODE_STATUS) and do {
      my $dialog = Demeter::UI::Artemis::ShowText->new($app->{main}, $demeter->mo->report('all'), 'Overview of this instance of Demeter') -> Show;
      last SWITCH;
    };

    ($id == $PLOT_QUAD) and do {
      my $data = $app->{main}->{list}->GetClientData($app->{main}->{list}->GetSelection);
      $app->{main}->{Main}->pull_values($data);
      $data->po->start_plot;
      $app->quadplot($data);
      last SWITCH;
    };
    ($id == $PLOT_IOSIG) and do {
      my $data = $app->{main}->{list}->GetClientData($app->{main}->{list}->GetSelection);
      $app->{main}->{Main}->pull_values($data);
      $app->{main}->{PlotE}->pull_single_values;
      $data->po->set(e_bkg=>0, e_pre=>0, e_post=>0, e_norm=>0, e_der=>0, e_sec=>0);
      $data->po->set(e_mu=>1, e_i0=>1, e_signal=>1);
      $data->po->start_plot;
      $data->plot('E');
      $data->po->set(e_i0=>0, e_signal=>0);
      last SWITCH;
    };
    ($id == $PLOT_K123) and do {
      my $data = $app->{main}->{list}->GetClientData($app->{main}->{list}->GetSelection);
      $app->{main}->{Main}->pull_values($data);
      $app->{main}->{PlotK}->pull_single_values;
      $data->po->start_plot;
      $data->plot('k123');
      last SWITCH;
    };
    ($id == $PLOT_R123) and do {
      my $data = $app->{main}->{list}->GetClientData($app->{main}->{list}->GetSelection);
      $app->{main}->{Main}->pull_values($data);
      $app->{main}->{PlotR}->pull_marked_values;
      $data->po->start_plot;
      $data->plot('R123');
      last SWITCH;
    };

  };
};


sub main_window {
  my ($app, $hbox) = @_;

  my $viewpanel = Wx::Panel    -> new($app->{main}, -1);
  my $viewbox   = Wx::BoxSizer -> new( wxVERTICAL );
  $hbox        -> Add($viewpanel, 0, wxGROW|wxALL, 5);

  $app->{main}->{project} = Wx::StaticText->new($viewpanel, -1, q{<untitled>},);
  my $size = Wx::SystemSettings::GetFont(wxSYS_DEFAULT_GUI_FONT)->GetPointSize + 2;
  $app->{main}->{project}->SetFont( Wx::Font->new( $size, wxDEFAULT, wxNORMAL, wxBOLD, 0, "" ) );
  $viewbox -> Add($app->{main}->{project}, 0, wxGROW|wxALL, 5);

  $app->{main}->{views} = Wx::Choicebook->new($viewpanel, -1);
  $viewbox -> Add($app->{main}->{views}, 0, wxALL, 5);
  #print join("|", $app->{main}->{views}->GetChildren), $/;
  $app->mouseover($app->{main}->{views}->GetChildren, "Change data processing and analysis tools using this menu.");

  foreach my $which (qw(Main Calibrate Prefs)) {
    next if $INC{"Demeter/UI/Athena/$which.pm"};
    require "Demeter/UI/Athena/$which.pm";
    $app->{main}->{$which} = "Demeter::UI::Athena::$which"->new($app->{main}->{views}, $app);
    my $label = eval '$'.'Demeter::UI::Athena::'.$which.'::label';
    $app->{main}->{views} -> AddPage($app->{main}->{$which}, $label, 0);
  };
  $app->{main}->{views}->SetSelection(0);
  ##$app->{main}->{views}->Enable($_,0) foreach (1 .. $app->{main}->{views}->GetPageCount-2);
  $viewpanel -> SetSizerAndFit($viewbox);

  EVT_CHOICEBOOK_PAGE_CHANGING($app->{main}, $app->{main}->{views}, sub{$app->view_changing(@_)});


  return $app;
};

sub side_bar {
  my ($app, $hbox) = @_;

  my $toolpanel = Wx::Panel    -> new($app->{main}, -1);
  my $toolbox   = Wx::BoxSizer -> new( wxVERTICAL );
  $hbox        -> Add($toolpanel, 1, wxGROW|wxALL, 5);

  $app->{main}->{list} = Wx::CheckListBox->new($toolpanel, -1, wxDefaultPosition, wxDefaultSize, [], wxLB_SINGLE|wxLB_NEEDED_SB);
  $toolbox            -> Add($app->{main}->{list}, 1, wxGROW|wxALL, 0);
  EVT_LISTBOX($toolpanel, $app->{main}->{list}, sub{$app->OnGroupSelect(@_)});

  my $singlebox = Wx::BoxSizer->new( wxHORIZONTAL );
  $toolbox     -> Add($singlebox, 0, wxGROW|wxALL, 0);
  my $markedbox = Wx::BoxSizer->new( wxHORIZONTAL );
  $toolbox     -> Add($markedbox, 0, wxGROW|wxALL, 0);
  foreach my $which (qw(E k R q kq)) {

    ## single plot button
    my $key = 'plot_single_'.$which;
    $app->{main}->{$key} = Wx::Button -> new($toolpanel, -1, $which, wxDefaultPosition, wxDefaultSize, wxBU_EXACTFIT);
    $app->{main}->{$key}-> SetBackgroundColour( Wx::Colour->new($demeter->co->default("athena", "single")) );
    $singlebox          -> Add($app->{main}->{$key}, 1, wxALL, 1);
    EVT_BUTTON($app->{main}, $app->{main}->{$key}, sub{$app->plot(@_, $which, 'single')});
    $app->mouseover($app->{main}->{$key}, "Plot the current group in $which");
    next if ($which eq 'kq');

    ## marked plot buttons
    $key    = 'plot_marked_'.$which;
    $app->{main}->{$key} = Wx::Button -> new($toolpanel, -1, $which, wxDefaultPosition, wxDefaultSize, wxBU_EXACTFIT);
    $app->{main}->{$key}-> SetBackgroundColour( Wx::Colour->new($demeter->co->default("athena", "marked")) );
    $markedbox          -> Add($app->{main}->{$key}, 1, wxALL, 1);
    EVT_BUTTON($app->{main}, $app->{main}->{$key}, sub{$app->plot(@_, $which, 'marked')});
    $app->mouseover($app->{main}->{$key}, "Plot the marked groups in $which");
  };

  $app->{main}->{kweights} = Wx::RadioBox->new($toolpanel, -1, 'Plotting k-weights', wxDefaultPosition, wxDefaultSize,
					       [qw(0 1 2 3 kw)], 1, wxRA_SPECIFY_ROWS);
  $toolbox -> Add($app->{main}->{kweights}, 0, wxALL|wxALIGN_CENTER_HORIZONTAL, 5);
  $app->{main}->{kweights}->SetSelection($demeter->co->default("plot", "kweight"));
  EVT_RADIOBOX($app->{main}, $app->{main}->{kweights},
	       sub {
		 $::app->replot(@{$::app->{lastplot}}) if (lc($::app->{lastplot}->[0]) ne 'e');
	       });
  $app->mouseover($app->{main}->{kweights}, "Select the value of k-weighting to be used in plots in k, R, and q-space.");

  ## -------- fill the plotting options tabs
  $app->{main}->{plottabs}  = Wx::Notebook->new($toolpanel, -1, wxDefaultPosition, wxDefaultSize, wxNB_TOP);
  foreach my $m (qw(PlotE PlotK PlotR PlotQ)) {
    next if $INC{"Demeter/UI/Athena/$m.pm"};
    require "Demeter/UI/Athena/$m.pm";
    $app->{main}->{$m} = "Demeter::UI::Athena::$m"->new($app->{main}->{plottabs}, $app);
    if ($m =~ m{[KQ]\z}) {
      $app->{main}->{plottabs} -> AddPage($app->{main}->{$m}, lc(substr($m, -1)), 0);
    } else {
      $app->{main}->{plottabs} -> AddPage($app->{main}->{$m},    substr($m, -1),  ($m eq 'PlotE'));
    };
  };
  $toolbox   -> Add($app->{main}->{plottabs}, 0, wxGROW|wxALL, 0);

  $toolpanel -> SetSizerAndFit($toolbox);

  return $app;
};


sub OnGroupSelect {
  my ($app, $parent, $event) = @_;
  my $is_index = (ref($event) =~ m{Event}) ? $event->GetSelection : $app->{main}->{list}->GetSelection;

  my $was = ($app->{selected} == -1) ? 0 : $app->{main}->{list}->GetClientData($app->{selected});
  my $is  = $app->{main}->{list}->GetClientData($is_index);

  if ($was) {
    $app->{main}->{Main}->pull_values($was);
  };
  $app->{main}->{Main}->push_values($is);
  $app->{selected} = $app->{main}->{list}->GetSelection;

};

sub view_changing {
  my ($app, $frame, $event) = @_;
  my $ngroups = $app->{main}->{list}->GetCount;
  my $nviews  = $app->{main}->{views}->GetPageCount;
  #print join("|", $app, $event, $ngroups, $event->GetSelection), $/;

  if (($event->GetSelection != 0) and ($event->GetSelection != $nviews-1)) {
    if (not $ngroups) {
      $app->{main}->status(sprintf("You have no data imported in Athena, thus you cannot use the %s tool.",
				   lc($app->{main}->{views}->GetPageText($event->GetSelection))));
      $event -> Veto();
    };
  } else {
    $app->{main}->status(sprintf("Displaying the %s tool.",
				 lc($app->{main}->{views}->GetPageText($event->GetSelection))));

  };
};

sub marked_groups {
  my ($app) = @_;
  my @list = ();
  foreach my $i (0 .. $app->{main}->{list}->GetCount-1) {
    push(@list, $app->{main}->{list}->GetClientData($i)) if $app->{main}->{list}->IsChecked($i);
  };
  return @list;
};

sub plot {
  my ($app, $frame, $event, $space, $how) = @_;
  if (not $app->{main}->{list}->GetCount) {
    #$app->{main}->status("Cannot plot -- no data.");
    return;
  };
  return if not ($space);
  return if not ($how);

  my $busy = Wx::BusyCursor->new();

  my @data = ($how eq 'single')
    ? ( $app->{main}->{list}->GetClientData($app->{main}->{list}->GetSelection) )
      : $app->marked_groups;

  $app->{main}->{Main}->pull_values($app->{main}->{list}->GetClientData($app->{main}->{list}->GetSelection));
  $app->pull_kweight($data[0]);

  $data[0]->po->start_plot;

  my $sp = (lc($space) eq 'kq') ? 'K' : uc($space);
  $app->{main}->{'Plot'.$sp}->pull_single_values if ($how eq 'single');
  $app->{main}->{'Plot'.$sp}->pull_marked_values if ($how eq 'marked');
  $data[0]->po->chie(0) if (lc($space) eq 'kq');


  ## energy k and kq
  if (lc($space) =~ m{(?:e|k|kq)}) {
    $_->plot($space) foreach @data;
    $data[0]->plot_window('k') if (($how eq 'single') and
				   $app->{main}->{PlotK}->{win}->GetValue and
				   (lc($space) ne 'e'));
    if (lc($space) eq 'e') {
      $app->{main}->{plottabs}->SetSelection(0);
    } else {
      $app->{main}->{plottabs}->SetSelection(1);
    };

  ## R
  } elsif (lc($space) eq 'r') {
    if ($how eq 'single') {
      foreach my $which (qw(mag env re im pha)) {
	if ($app->{main}->{PlotR}->{$which}->GetValue) {
	  $data[0]->po->r_pl(substr($which, 0, 1));
	  $data[0]->plot('r');
	};
      };
      $data[0]->plot_window('r') if $app->{main}->{PlotR}->{win}->GetValue;
    } else {
      $_->plot($space) foreach @data;
    };
    $app->{main}->{plottabs}->SetSelection(2);

  ## q
  } elsif (lc($space) eq 'q') {
    if ($how eq 'single') {
      foreach my $which (qw(mag env re im pha)) {
	if ($app->{main}->{PlotQ}->{$which}->GetValue) {
	  $data[0]->po->q_pl(substr($which, 0, 1));
	  $data[0]->plot('q');
	};
      };
      $data[0]->plot_window('q') if $app->{main}->{PlotQ}->{win}->GetValue;
    } else {
      $_->plot($space) foreach @data;
    };
    $app->{main}->{plottabs}->SetSelection(3);
  };

  $app->{lastplot} = [$space, $how];
  undef $busy;
};

sub quadplot {
  my ($app, $data) = @_;
  if ($data->mo->template_plot eq 'gnuplot') {
    my ($showkey, $fontsize) = ($data->po->showlegend, $data->co->default("gnuplot", "fontsize"));
    $data->po->showlegend(0);
    $data->co->set_default("gnuplot", "fontsize", 8);

    $app->{main}->{PlotE}->pull_single_values;
    $app->{main}->{PlotK}->pull_single_values;
    $app->{main}->{PlotR}->pull_marked_values;
    $app->{main}->{PlotQ}->pull_marked_values;
    $app->pull_kweight($data);
    $data->plot('quad');

    $data->po->showlegend($showkey);
    $data->co->set_default("gnuplot", "fontsize", $fontsize);
  } else {
    $app->plot(q{}, q{}, 'E', 'single')
  };
};

sub pull_kweight {
  my ($app, $data) = @_;
  my $kw = $app->{main}->{kweights}->GetStringSelection;
  if ($kw eq 'kw') {
    $data->po->kweight($data->fit_karb_value);
  } else {
    $data->po->kweight($kw);
  };
  return $data->po->kweight;
};

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
  $self->{Status}->put_text($text, $type);
};


1;
