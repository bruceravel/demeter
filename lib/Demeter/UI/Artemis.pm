package Demeter::UI::Artemis;

use Demeter; # qw(:plotwith=gnuplot);
use Demeter::UI::Atoms;
use Demeter::UI::Artemis::Import;
use Demeter::UI::Artemis::Project;
use Demeter::UI::Artemis::ShowText;
use Demeter::UI::Wx::MRU;
use Demeter::UI::Wx::SpecialCharacters qw(:all);
use Demeter::UI::Athena::Cursor;

use vars qw($demeter $buffer $plotbuffer);
$demeter = Demeter->new;
$demeter->set_mode(ifeffit=>1, screen=>0);

use Archive::Zip qw( :ERROR_CODES :CONSTANTS );
use Cwd;
use File::Basename;
use File::Copy;
use File::Path;
use File::Spec;
use List::MoreUtils qw(zip);
use Scalar::Util qw(blessed);

use String::Random qw(random_string);
use YAML::Tiny;

use Wx qw(:everything);
use Wx::Event qw(EVT_MENU EVT_CLOSE EVT_TOOL_ENTER EVT_CHECKBOX EVT_BUTTON
		 EVT_TOGGLEBUTTON EVT_ENTER_WINDOW EVT_LEAVE_WINDOW
		 EVT_TOOL_RCLICKED EVT_RIGHT_UP
		 EVT_NOTEBOOK_PAGE_CHANGING
	       );
use base 'Wx::App';


use Readonly;
Readonly my $BLANK           => q{___.BLANK.___};
Readonly my $MRU	     => Wx::NewId();
Readonly my $SHOW_BUFFER     => Wx::NewId();
Readonly my $CONFIG	     => Wx::NewId();
Readonly my $CRASH	     => Wx::NewId();
Readonly my $SHOW_GROUPS     => Wx::NewId();
Readonly my $SHOW_ARRAYS     => Wx::NewId();
Readonly my $SHOW_SCALARS    => Wx::NewId();
Readonly my $SHOW_STRINGS    => Wx::NewId();
Readonly my $SHOW_FEFFPATHS  => Wx::NewId();
Readonly my $SHOW_PATHS      => Wx::NewId();
Readonly my $IMPORT_DPJ      => Wx::NewId();
Readonly my $IMPORT_FEFFIT   => Wx::NewId();
Readonly my $IMPORT_FEFF     => Wx::NewId();
Readonly my $IMPORT_MOLECULE => Wx::NewId();
Readonly my $IMPORT_OLD      => Wx::NewId();
Readonly my $IMPORT_CHI      => Wx::NewId();
Readonly my $EXPORT_IFEFFIT  => Wx::NewId();
Readonly my $EXPORT_DEMETER  => Wx::NewId();
Readonly my $PLOT_YAML       => Wx::NewId();
Readonly my $MODE_STATUS     => Wx::NewId();
Readonly my $PERL_MODULES    => Wx::NewId();
Readonly my $STATUS          => Wx::NewId();
Readonly my $DOCUMENT        => Wx::NewId();
Readonly my $TERM_1          => Wx::NewId();
Readonly my $TERM_2          => Wx::NewId();
Readonly my $TERM_3          => Wx::NewId();
Readonly my $IFEFFIT_MEMORY  => Wx::NewId();

use Wx::Perl::Carp qw(verbose);
$SIG{__WARN__} = sub {Wx::Perl::Carp::warn($_[0])};
$SIG{__DIE__}  = sub {Wx::Perl::Carp::warn($_[0])};
##$SIG{PIPE} = 'IGNORE';


sub identify_self {
  my @caller = caller;
  return dirname($caller[1]);
};
use vars qw($artemis_base $icon $nset $noautosave %frames %fit_order);
$fit_order{order}{current} = 0;
$nset = 0;
$artemis_base = identify_self();
$noautosave = 0;		# set this to skip autosave, see Demeter::UI::Artemis::Import::_feffit

my %hints = (
	     gds     => "Display/hide the Guess/Def/Set parameters dialog",
	     plot    => "Display/hide the plotting controls dialog",
	     log     => "Display/hide the fit log",
	     fit     => "Display/hide the fit history dialog",
	     journal => "Display/hide the fit journal",
	    );

sub OnInit {
  my ($app) = @_;
  $demeter -> mo -> ui('Wx');
  $demeter -> mo -> identity('Artemis');

  #my $app = $class->SUPER::new;

  my $conffile = File::Spec->catfile(dirname($INC{'Demeter/UI/Artemis.pm'}), 'Artemis', 'share', "artemis.demeter_conf");
  $demeter -> co -> read_config($conffile);
  $demeter -> co -> read_ini('artemis');
  $demeter -> plot_with($demeter->co->default(qw(plot plotwith)));

  ## -------- import all of Artemis' various parts
  foreach my $m (qw(GDS Plot History Journal Log Buffer Status Config Data Prj)) {
    next if $INC{"Demeter/UI/Artemis/$m.pm"};
    ##print "Demeter/UI/Artemis/$m.pm\n";
    require "Demeter/UI/Artemis/$m.pm";
  };

  ## -------- create a new frame and set icon
  $frames{main} = Wx::Frame->new(undef, -1, 'Artemis [EXAFS data analysis] - <untitled>',
				[0,0], # position -- along top of screen
				[Wx::SystemSettings::GetMetric(wxSYS_SCREEN_X), -1] # size -- entire width of screen
			       );
  $frames{main} -> SetBackgroundColour( wxNullColour );

  my $iconfile = File::Spec->catfile(dirname($INC{'Demeter/UI/Artemis.pm'}), 'Artemis', 'icons', "artemis.png");
  $icon = Wx::Icon->new( $iconfile, wxBITMAP_TYPE_ANY );
  $frames{main} -> SetIcon($icon);
  $frames{main} -> {currentfit} = q{};
  $frames{main} -> {projectname} = '<untitled>';
  $frames{main} -> {projectpath} = q{};
  $frames{main} -> {modified} = 0;
  $app->{main} = $frames{main};

  ## -------- Set up menubar
  my $bar      = Wx::MenuBar->new;
  my $filemenu = Wx::Menu->new;
  my $mrumenu  = Wx::Menu->new;

  my $importmenu = Wx::Menu->new;
  $importmenu->Append($IMPORT_CHI,      "$CHI(k) data",                  "Import $CHI(k) data from a column data file");
  $importmenu->Append($IMPORT_DPJ,      "Demeter fit serialization",     "Import a Demeter fit serialization (.dpj) file");
  $importmenu->AppendSeparator;
  $importmenu->Append($IMPORT_FEFF,     "a Feff calculation",            "Import a Feff input file and the results of a calculation made with that file");
  $importmenu->Append($IMPORT_MOLECULE, "a molecule",                    "Import a molecule using OpenBabel");
  $importmenu->AppendSeparator;
  $importmenu->Append($IMPORT_OLD,      "an old-style Artemis project",  "Import the current fitting model from an old-style Artemis project file");
  $importmenu->Append($IMPORT_FEFFIT,   "a feffit.inp file",             "Import a fitting model from a feffit.inp file");
  $importmenu->Enable($IMPORT_MOLECULE, 0);

  my $exportmenu = Wx::Menu->new;
  $exportmenu->Append($EXPORT_IFEFFIT,  "to an Ifeffit script",  "Export the current fitting model as an Ifeffit script");
  $exportmenu->Append($EXPORT_DEMETER,  "to a Demeter script",   "Export the current fitting model as a perl script using Demeter");

  $filemenu->Append(wxID_OPEN,       "Open project\tCtrl+o", "Read from a project file" );
  $filemenu->AppendSubMenu($mrumenu, "Recent files",    "Open a submenu of recently used files" );
  $filemenu->Append(wxID_SAVE,       "Save project\tCtrl+s", "Save project" );
  $filemenu->Append(wxID_SAVEAS,     "Save project as...", "Save to a new project file" );
  $filemenu->AppendSeparator;
  $filemenu->AppendSubMenu($importmenu, "Import...", "Export a fitting model from ..." );
  $filemenu->AppendSubMenu($exportmenu, "Export...", "Export the current fitting model as ..." );
  $filemenu->AppendSeparator;
  $filemenu->Append(wxID_PREFERENCES , "Edit Preferences",   "Show the preferences editing dialog");
  $filemenu->AppendSeparator;
  $filemenu->Append(wxID_CLOSE, "&Close\tCtrl+w" );
  $filemenu->Append(wxID_EXIT, "E&xit\tCtrl+q" );
  $frames{main}->{filemenu} = $filemenu;
  $frames{main}->{mrumenu}  = $mrumenu;

  $frames{main}->{mruartemis}   = Wx::Menu->new;
  $frames{main}->{mrufit}       = Wx::Menu->new;
  $frames{main}->{mruathena}    = Wx::Menu->new;
  $frames{main}->{mrustructure} = Wx::Menu->new;
  $frames{main}->{mruold}       = Wx::Menu->new;
  $mrumenu->AppendSubMenu($frames{main}->{mruartemis},   "Artemis projects" );
  $mrumenu->AppendSubMenu($frames{main}->{mruathena},    "Athena projects" );
  $mrumenu->AppendSubMenu($frames{main}->{mrustructure}, "Crystal/structure data" );
  $mrumenu->AppendSubMenu($frames{main}->{mrufit},       "Fit serializations" );
  $mrumenu->AppendSubMenu($frames{main}->{mruold},       "Old-style artemis projects" );



  my $showmenu = Wx::Menu->new;
  $showmenu->Append($SHOW_GROUPS,    "groups",    "Show Ifeffit groups");
  $showmenu->Append($SHOW_ARRAYS,    "arrays",    "Show Ifeffit arrays");
  $showmenu->Append($SHOW_SCALARS,   "scalars",   "Show Ifeffit scalars");
  $showmenu->Append($SHOW_STRINGS,   "strings",   "Show Ifeffit strings");
  $showmenu->Append($SHOW_PATHS,     "paths",     "Show Ifeffit paths");
  $showmenu->Append($SHOW_FEFFPATHS, "feffpaths", "Show Ifeffit feffpaths");

  my $debugmenu = Wx::Menu->new;
  $debugmenu->Append($PLOT_YAML,    "Show YAML for Plot object",  "Show YAML for Plot object",  wxITEM_NORMAL );
  $debugmenu->Append($MODE_STATUS,  "Mode status",                "Mode status",  wxITEM_NORMAL );
  $debugmenu->Append($PERL_MODULES, "Perl modules",               "Show perl module versions", wxITEM_NORMAL );
  #$debugmenu->Append($CRASH,        "Crash Artemis",              "Force a crash of Artemis to test autosave file", wxITEM_NORMAL );

  my $feedbackmenu = Wx::Menu->new;
  $feedbackmenu->Append($SHOW_BUFFER, "Show command buffer",    'Show the Ifeffit and plotting commands buffer');
  $feedbackmenu->Append($STATUS,      "Show status bar buffer", 'Show the buffer containing messages written to the status bars');
  $feedbackmenu->AppendSubMenu($showmenu,  "Show Ifeffit ...",  'Show variables from Ifeffit');
  $feedbackmenu->AppendSubMenu($debugmenu, 'Debug options',     'Display debugging tools')
    if ($demeter->co->default("artemis", "debug_menus"));
  $feedbackmenu->Append($IFEFFIT_MEMORY,  "Show Ifeffit's memory use", "Show Ifeffit's memory use and remaining capacity");

  #my $settingsmenu = Wx::Menu->new;

  my $plotmenu = Wx::Menu->new;
  $plotmenu->AppendRadioItem($TERM_1, "Plot to terminal 1", "Plot to terminal 1");
  $plotmenu->AppendRadioItem($TERM_2, "Plot to terminal 2", "Plot to terminal 2");
  $plotmenu->AppendRadioItem($TERM_3, "Plot to terminal 3", "Plot to terminal 3");


  my $helpmenu = Wx::Menu->new;
  $helpmenu->Append($DOCUMENT,  "Read user manual" );
  $helpmenu->Append(wxID_ABOUT, "&About..." );
  $helpmenu->Enable($DOCUMENT,0);

  $bar->Append( $filemenu,      "&File" );
  $bar->Append( $feedbackmenu,  "&Monitor" );
  $bar->Append( $plotmenu,      "Plot" ) if ($demeter->co->default('plot', 'plotwith') eq 'gnuplot');
  $bar->Append( $helpmenu,      "&Help" );
  $frames{main}->SetMenuBar( $bar );

  my $hbox = Wx::BoxSizer->new( wxHORIZONTAL);

  ## -------- status bar
  $frames{main}->{statusbar} = $frames{main}->CreateStatusBar;

  ## -------- GDS and Plot toolbar
  my $vbox = Wx::BoxSizer->new( wxVERTICAL);
  $hbox -> Add($vbox, 0, wxALL, 5);
  my $toolbar = Wx::ToolBar->new($frames{main}, -1, wxDefaultPosition, wxDefaultSize, wxTB_VERTICAL|wxTB_HORZ_TEXT);
  $frames{main}->{toolbar} = $toolbar;
  $frames{main}->{gds_toggle}     = $toolbar -> AddCheckTool(1, "GDS",      icon("gds"),     wxNullBitmap, q{}, $hints{gds} );
  $frames{main}->{plot_toggle}    = $toolbar -> AddCheckTool(2, "Plot",     icon("plot"),    wxNullBitmap, q{}, $hints{plot} );
  $frames{main}->{history_toggle} = $toolbar -> AddCheckTool(3, " History", icon("history"), wxNullBitmap, q{}, $hints{fit} );
  $frames{main}->{journal_toggle} = $toolbar -> AddCheckTool(4, " Journal", icon("journal"), wxNullBitmap, q{}, $hints{journal} );
  $toolbar -> Realize;
  $vbox -> Add($toolbar, 0, wxALL, 0);

  ## -------- Data box
  $vbox = Wx::BoxSizer->new( wxVERTICAL);
  $hbox -> Add($vbox, 0, wxALL, 5);
  my $databox       = Wx::StaticBox->new($frames{main}, -1, 'Data sets', wxDefaultPosition, wxDefaultSize);
  my $databoxsizer  = Wx::StaticBoxSizer->new( $databox, wxVERTICAL );

  my $datalist = Wx::ScrolledWindow->new($frames{main}, -1, wxDefaultPosition, wxDefaultSize, wxVSCROLL);
  $datalist->SetScrollbars(20, 20, 50, 50);
  my $datavbox = Wx::BoxSizer->new( wxVERTICAL );
  $datalist->SetSizer($datavbox);

  $frames{main}->{newdata} = Wx::Button->new($datalist, wxID_ADD, "", wxDefaultPosition, wxDefaultSize, wxNO_BORDER);
  $datavbox -> Add($frames{main}->{newdata}, 0, wxGROW|wxRIGHT, 5);
  mouseover($frames{main}->{newdata}, "Import a new data set.  Right click for menu of recently used Athena project files.");
  EVT_BUTTON($frames{main}->{newdata}, -1, sub{Import('prj', q{})});

  $datavbox     -> Add(Wx::StaticLine->new($datalist, -1, wxDefaultPosition, wxDefaultSize, wxLI_HORIZONTAL), 0, wxGROW|wxALL, 2);
  $databoxsizer -> Add($datalist, 1, wxGROW|wxALL, 0);
  $hbox         -> Add($databoxsizer, 2, wxGROW|wxALL, 0);

  $frames{main}->{datalist} = $datalist;
  $frames{main}->{databox}  = $datavbox;
  EVT_RIGHT_UP($frames{main}->{newdata}, \&OnDataRightClick);


  ## -------- Feff box
  $vbox = Wx::BoxSizer->new( wxVERTICAL);
  $hbox -> Add($vbox, 0, wxALL, 5);
  my $feffbox       = Wx::StaticBox->new($frames{main}, -1, 'Feff calculations', wxDefaultPosition, wxDefaultSize);
  my $feffboxsizer  = Wx::StaticBoxSizer->new( $feffbox, wxVERTICAL );

  my $fefflist = Wx::ScrolledWindow->new($frames{main}, -1, wxDefaultPosition, wxDefaultSize, wxVSCROLL);
  $fefflist->SetScrollbars(20, 20, 50, 50);
  my $feffvbox = Wx::BoxSizer->new( wxVERTICAL);
  $fefflist->SetSizer($feffvbox);

  $frames{main}->{newfeff} = Wx::Button->new($fefflist, wxID_ADD, "", wxDefaultPosition, wxDefaultSize, wxNO_BORDER);
  $feffvbox -> Add($frames{main}->{newfeff}, 0, wxGROW|wxRIGHT, 5);
  mouseover($frames{main}->{newfeff}, "Start a new Feff calculation.  Right click for menu of recently used crystal data files.  Also right click to start a brand new Atoms input file.");
  EVT_BUTTON($frames{main}->{newfeff}, -1, sub{Import('feff')});

  $feffvbox     -> Add(Wx::StaticLine->new($fefflist, -1, wxDefaultPosition, wxDefaultSize, wxLI_HORIZONTAL), 0, wxGROW|wxALL, 2);
  $feffboxsizer -> Add($fefflist, 1, wxGROW|wxALL, 0);
  $hbox         -> Add($feffboxsizer, 2, wxGROW|wxALL, 0);

  $frames{main}->{fefflist} = $fefflist;
  $frames{main}->{feffbox}  = $feffvbox;
  EVT_RIGHT_UP($frames{main}->{newfeff}, \&OnFeffRightClick);

  ## -------- Fit box
  $vbox = Wx::BoxSizer->new( wxVERTICAL);
  $hbox -> Add($vbox, 4, wxGROW|wxLEFT|wxRIGHT|wxTOP, 5);

  my $hname = Wx::BoxSizer->new( wxHORIZONTAL);
  $vbox -> Add($hname, 0, wxGROW|wxTOP|wxBOTTOM, 0);
  my $label = Wx::StaticText->new($frames{main}, -1, "Name");
  $frames{main}->{name}  = Wx::TextCtrl->new($frames{main}, -1, "Fit 1");
  $hname -> Add($label,                0, wxALL, 5);
  $hname -> Add($frames{main}->{name}, 1, wxALL, 2);
  mouseover($frames{main}->{name}, "Provide a short description of this fitting model.");

  $label = Wx::StaticText->new($frames{main}, -1, "Fit space:");
  my @fitspace = (Wx::RadioButton->new($frames{main}, -1, 'k', wxDefaultPosition, wxDefaultSize, wxRB_GROUP),
		  Wx::RadioButton->new($frames{main}, -1, 'R', wxDefaultPosition, wxDefaultSize),
		  Wx::RadioButton->new($frames{main}, -1, 'q', wxDefaultPosition, wxDefaultSize),
		 );
  $frames{main}->{fitspace} = \@fitspace;

  $hname  -> Add($label,   0, wxALL, 3);
  map {$hname  -> Add($_,   0, wxLEFT|wxRIGHT, 2)} @fitspace;
  $fitspace[0]->SetValue(1) if ($demeter->co->default("fit", "space") eq 'k');
  $fitspace[1]->SetValue(1) if ($demeter->co->default("fit", "space") eq 'r');
  $fitspace[2]->SetValue(1) if ($demeter->co->default("fit", "space") eq 'q');

  mouseover($fitspace[0], "Evaluate the fitting metric in k-space.");
  mouseover($fitspace[1], "Evaluate the fitting metric in R-space.");
  mouseover($fitspace[2], "Evaluate the fitting metric in q-space.");

  my $descbox      = Wx::StaticBox->new($frames{main}, -1, 'Fit description', wxDefaultPosition, wxDefaultSize);
  my $descboxsizer = Wx::StaticBoxSizer->new( $descbox, wxVERTICAL );
  $frames{main}->{description}  = Wx::TextCtrl->new($frames{main}, -1, q{}, wxDefaultPosition, [-1, 25], wxTE_MULTILINE);
  $descboxsizer   -> Add($frames{main}->{description},  1, wxGROW|wxALL, 0);
  $vbox           -> Add($descboxsizer, 1, wxGROW|wxALL, 0);
  mouseover($frames{main}->{description}, "Use this space to fully describe this fitting model.");

  $vbox = Wx::BoxSizer->new( wxVERTICAL);
  $hbox -> Add($vbox, 0, wxGROW|wxALL, 0);

  $frames{main}->{fitbutton}  = Wx::Button->new($frames{main}, -1, "F&it", wxDefaultPosition, wxDefaultSize);
  $frames{main}->{fitbutton} -> SetForegroundColour(Wx::Colour->new("#000000"));
  $frames{main}->{fitbutton} -> SetBackgroundColour(Wx::Colour->new($demeter->co->default("happiness", "average_color")));
  $frames{main}->{fitbutton} -> SetFont(Wx::Font->new( 10, wxDEFAULT, wxNORMAL, wxBOLD, 0, "" ) );
  $vbox->Add($frames{main}->{fitbutton}, 1, wxGROW|wxALL, 2);
  mouseover($frames{main}->{fitbutton}, "Start the fit.");

  $frames{main}->{log_toggle} = Wx::ToggleButton -> new($frames{main}, -1, "Show &log",);
  $vbox->Add($frames{main}->{log_toggle}, 0, wxGROW|wxALL, 2);
  mouseover($frames{main}->{log_toggle}, $hints{log});



  EVT_MENU	 ($frames{main}, -1,         sub{my ($frame,  $event) = @_; OnMenuClick($frame,  $event)} );
  EVT_CLOSE	 ($frames{main},             \&on_close);
  EVT_MENU	 ($toolbar,      -1,         sub{my ($toolbar,  $event) = @_; OnToolClick($toolbar,  $event, $frames{main})} );
  EVT_TOOL_ENTER ($frames{main}, $toolbar,   sub{my ($toolbar,  $event) = @_; OnToolEnter($toolbar,  $event, 'toolbar')} );
  EVT_BUTTON     ($frames{main}->{fitbutton}, -1, sub{fit(@_, \%frames)});



  $frames{main} -> SetSizerAndFit($hbox);
  ##         sum of menu bar, toolbar, and statusbar + the spaceing around the bix containing the toolbar
  #my $h = ($toolbar->GetSizeWH)[1] + ($frames{main}->{statusbar}->GetSizeWH)[1] + ($bar->GetSizeWH)[1] + 10;
  #$frames{main} -> SetSize(Wx::Size->new(Wx::SystemSettings::GetMetric(wxSYS_SCREEN_X), $h));
  $frames{main} -> SetSize(Wx::Size->new(Wx::SystemSettings::GetMetric(wxSYS_SCREEN_X), -1));

  foreach my $part (qw(GDS Plot Log History Journal Buffer Status Config)) {
    my $pp = "Demeter::UI::Artemis::".$part;
    $app->{$part}   = $pp->new($frames{main});
    $frames{$part}  = $app->{$part};
    $frames{$part} -> SetIcon($icon);
  };

  $frames{main} -> Show( 1 );
  $toolbar->ToggleTool($frames{main}->{plot_toggle}->GetId,1);
  $frames{Plot} -> Show( 1 );
  EVT_TOGGLEBUTTON($frames{main}->{log_toggle}, -1, sub{ $frames{Log}->Show($frames{main}->{log_toggle}->GetValue) });

  ## -------- disk space to hold this project
  my $this = '_dem_' . random_string('cccccccc');
  my $project_folder = File::Spec->catfile($demeter->stash_folder, $this);
  $frames{main}->{project_folder} = $project_folder;
  mkpath($project_folder,0);

  my $readme = File::Spec->catfile($demeter->share_folder, "Readme.fit_serialization");
  my $target = File::Spec->catfile($project_folder, "Readme");
  copy($readme, $target);
  chmod(0666, $target) if $demeter->is_windows;

  my $orderfile = File::Spec->catfile($frames{main}->{project_folder}, "order");
  $frames{main}->{order_file} = $orderfile;
  if (not -e $orderfile) {
    my $string .= YAML::Tiny::Dump(%fit_order);
    open(my $ORDER, '>'.$orderfile);
    print $ORDER $string;
    close $ORDER;
  };
  $frames{main}->{plot_folder} = File::Spec->catfile($frames{main}->{project_folder}, 'plot');
  mkpath($frames{main}->{plot_folder}, 0);

  $frames{main}->{autosave_file} = File::Spec->catfile($demeter->stash_folder, $this.'.autosave');
  #touch(File::Spec->catfile($frames{main}->{project_folder}, $this));

  set_mru();
  ## now that everything is established, set up disposal callbacks to
  ## display Ifeffit commands in the buffer window
  $demeter->set_mode(callback     => \&ifeffit_buffer,
		     plotcallback => ($demeter->mo->template_plot eq 'pgplot') ? \&ifeffit_buffer : \&plot_buffer,
		     feedback     => \&feedback,
		    );

  if ($demeter->co->default("artemis", "autosave") and autosave_exists()) {
    import_autosave();
  } elsif ($ARGV[0] and -e $ARGV[0]) {
    my $file = File::Spec->rel2abs( $ARGV[0] );
    read_project(\%frames, $file);
  };
  $frames{main}->status("Welcome to Artemis (" . $demeter->identify . ")");
  1;
}


sub mouseover {
  my ($widget, $text) = @_;
  my $sb = $frames{main}->{statusbar};
  EVT_ENTER_WINDOW($widget, sub{$sb->PushStatusText($text); $_[1]->Skip});
  EVT_LEAVE_WINDOW($widget, sub{$sb->PopStatusText if ($sb->GetStatusText eq $text); $_[1]->Skip});
};

sub on_close {
  my ($self, $event) = @_;

  if ($frames{main} -> {modified}) {
    ## offer to save project....
    my $yesno = Wx::MessageDialog->new($frames{main},
				       "Save this project before exiting?",
				       "Save project?",
				       wxYES_NO|wxCANCEL|wxYES_DEFAULT|wxICON_QUESTION);
    my $result = $yesno->ShowModal;
    if ($result == wxID_CANCEL) {
      $frames{main}->status("Not exiting Artemis.");
      return 0;
    };
    save_project(\%frames) if $result == wxID_YES;
  };
  rmtree($self->{project_folder}); #, {verbose=>1});
  unlink $frames{main}->{autosave_file};
  $demeter->mo->destroy_all;
  foreach my $f (keys(%frames)) {
    #print '>', $f, '<', $/;
    #next if ($f !~ m{Demeter});
    next if ($f eq 'main');
    $frames{$f}->Destroy;
  };
  $frames{main}->Destroy;
  $event->Skip(1);
};

#sub OnExit {
#  my ($self, $event) = @_;
#  $demeter->mo->destroy_all;
#  $event->Skip(1);
#};

sub on_about {
  my ($self) = @_;

  my $info = Wx::AboutDialogInfo->new;

  $info->SetName( 'Artemis' );
  #$info->SetVersion( $demeter->version );
  $info->SetDescription( "EXAFS analysis using Feff and Ifeffit" );
  $info->SetCopyright( $demeter->identify );
  $info->SetWebSite( 'http://cars9.uchicago.edu/iffwiki/Demeter', 'The Demeter web site' );
  $info->SetDevelopers( ["Bruce Ravel <bravel\@bnl.gov>\n" .
			 "Ifeffit is copyright $COPYRIGHT 1992-2011 Matt Newville\n" .
			 "Artemis is powered using Wx $Wx::VERSION with $Wx::wxVERSION_STRING\n" .
			 "and Moose $Moose::VERSION"]
		      );
  $info->SetLicense( $demeter->slurp(File::Spec->catfile($artemis_base, 'Artemis', 'share', "GPL.dem")) );
  my $artwork = <<'EOH'
Design and layout of Artemis is the work of Bruce Ravel

Some icons taken from the Fairytale icon set at Wikimedia
Commons (http://commons.wikimedia.org/) and others from
the Gartoon Redux icon set from http://www.gnome-look.org
All other icons icons are from the Kids icon set for
KDE by Everaldo Coelho, http://www.everaldo.com
EOH
  ;
  $info -> AddArtist($artwork);

  Wx::AboutBox( $info );
};

sub heap_check {
  my ($app, $show) = @_;
  if ($demeter->mo->heap_used > 0.99) {
    $app->{main}->status("You have used all of Ifeffit's memory!  It is likely that your data is corrupted!", "error");
  } elsif ($demeter->mo->heap_used > 0.95) {
    $app->{main}->status("You have used more than 95% of Ifeffit's memory.  Save your work!", "error");
  } elsif ($demeter->mo->heap_used > 0.9) {
    $app->{main}->status("You have used more than 90% of Ifeffit's memory.  Save your work!", "error");
  } elsif ($show) {
    $demeter->ifeffit_heap;
    $app->{main}->status(sprintf("You are currently using %.1f%% of Ifeffit's %.1f Mb of memory",
				 100*$demeter->mo->heap_used,
				 $demeter->mo->heap_free/(1-$demeter->mo->heap_used)/2**20));
  };
};

sub uptodate {
  my ($rframes) = @_;
  my (@data, @paths, @gds);
  my $abort = 0;

  ## do I need to take care at this point about GDS's with the same name?
  #   my $grid = $rframes->{GDS}->{grid};
  #   foreach my $row (0 .. $grid->GetNumberRows) {
  #     $grid -> SetCellValue($row, 3, q{});
  #     my $name = $grid -> GetCellValue($row, 1);
  #     next if ($name =~ m{\A\s*\z});
  #     my $type = $grid -> GetCellValue($row, 0);
  #     my $mathexp = $grid -> GetCellValue($row, 2);
  #     my $thisgds = $grid->{$name} || Demeter::GDS->new(); # take care to reuse GDS objects whenever possible
  #     $thisgds -> set(name=>$name, gds=>$type, mathexp=>$mathexp);
  #     $grid->{$name} = $thisgds;
  #     push @gds, $thisgds;
  #     $thisgds->dispose($thisgds->write_gds);
  #   };

  foreach my $k (keys(%$rframes)) {
    next unless ($k =~ m{\Adata});
    my $this = $rframes->{$k}->{data};
    ++$abort if ($rframes->{$k}->fetch_parameters == 0);
    push @data, $this;

    my $npath = $rframes->{$k}->{pathlist}->GetPageCount - 1;
    foreach my $p (0 .. $npath) {
      my $path = $rframes->{$k}->{pathlist}->GetPage($p);
      next if (blessed($path) !~ m{Path});
      $path->fetch_parameters;
      push @paths, $path->{path};
    };
  };
  $rframes->{Plot}->fetch_parameters('plot');

  #modified(1);
  return ($abort, \@data, \@paths);
};

sub fit {
  my ($button, $event, $rframes) = @_;
  my $busy = Wx::BusyCursor->new();

  ## reset all relevant widgets to their initial states (i.e. assume
  ## that the last fit returned trouble and that the widgets
  ## containing the responsible data were colored in some way to
  ## indicate that)

  $rframes->{Plot}->{fileout}->SetValue(0);

  my $rgds = $rframes->{GDS}->reset_all(1, 1);
  my ($abort, $rdata, $rpaths) = uptodate($rframes);

  if (($#{$rdata} == -1) or ($#{$rpaths} == -1) or ($#{$rgds} == -1)) {
    my $message = q{};
    $message .= "You have not defined any data sets.\n"          if ($#{$rdata}  == -1);
    $message .= "You have not defined any paths.\n"              if ($#{$rpaths} == -1);
    $message .= "You have not defined any fitting parameters.\n" if ($#{$rgds}   == -1);
    Wx::MessageDialog->new($rframes->{main}, $message, "Fit cannot continue", wxOK|wxICON_ERROR) -> ShowModal;
    $rframes->{main}->status("Your fit cannot continue.");
    undef $busy;
    return;
  };

  my @data  = @$rdata;
  my @paths = @$rpaths;
  my @gds   = @$rgds;
  if ($abort) {
    $rframes->{main}->status("There is a problem in your fit.", "error");
    return;
  };
  my $start = DateTime->now( time_zone => 'floating' );
  $rframes->{main}->status("Fitting (please be patient, it may take a while...)", "wait");


  ## get name, fom, and description + other properties
  my $fit = $rframes->{main} -> {currentfit};
  $fit -> set(data => \@data, paths => \@paths, gds => \@gds);
  my $name = $rframes->{main}->{name}->GetValue || 'Fit '.$fit->mo->currentfit;
  my $startingname = $name;
  $fit->name($name);
  $fit->description($rframes->{main}->{description}->GetValue);
  $fit->fom($fit->mo->currentfit);
  #$fit->ignore_errors(1);
  $rframes->{main} -> {currentfit} = $fit;


  $fit->set_mode(ifeffit=>1, screen=>0);
  ##autosave($name);
  my $result = $fit->fit;
  my $finishtext = q{};
  my $code = "normal";
  if ($result eq $fit) {
    $fit -> serialize(tree     => File::Spec->catfile($frames{main}->{project_folder}, 'fits'),
		      folder   => $fit->group,
		      nozip    => 1,
		      copyfeff => 0,
		     );
    update_order_file();

    $rframes->{Log}->{name} = $fit->name;
    $rframes->{Log}->Show(1) if ($fit->co->default("artemis", "show_after_fit") eq 'log');
    $rframes->{Log}->put_log($fit);
    $rframes->{Log}->SetTitle("Artemis [Log] " . $rframes->{main}->{name}->GetValue);
    $rframes->{Log}->Refresh;
    $rframes->{main}->{log_toggle}->SetValue(1) if ($fit->co->default("artemis", "show_after_fit") eq 'log');

    ## fill in plotting list
    if (not $rframes->{Plot}->{freeze}->GetValue) {
      $rframes->{Plot}->{plotlist}->ClearAll;
      foreach my $k (sort (keys (%$rframes))) {
	next if ($k !~ m{data});
	$rframes->{$k}->transfer if $rframes->{$k}->{plot_after}->GetValue;
	foreach my $p (0 .. $rframes->{$k}->{pathlist}->GetPageCount -1) {
	  my $pathpage = $rframes->{$k}->{pathlist}->{LIST}->GetIndexedData($p);
	  $pathpage->transfer if $pathpage->{plotafter}->GetValue;
	};
      };
    };
    set_happiness_color($fit->color);
    $_->update_fft(1) foreach @data;
    $fit->po->start_plot;
    $rframes->{Plot}->{limits}->{fit}->SetValue(1);
    $fit->po->plot_fit(1);
    my $how = $fit->co->default("artemis", "plot_after_fit");
    if ($how =~ m{\A(?:rmr|rk|r123|k123|kq)\z}) {
      $data[0]->plot($how);
    } elsif ($how =~ m{\A[krq]\z}) {
      $rframes->{Plot}->plot(q{}, $how);
    };
    $rframes->{GDS}->fill_results(@gds);
    my $finish = DateTime->now( time_zone => 'floating' );
    my $dur = $finish->delta_ms($start);
    $finishtext = sprintf "Your fit finished in %d seconds.", $dur->seconds;
    $rframes->{History}->{list}->AddData($fit->name, $fit);
    $rframes->{History}->add_plottool($fit);
    if ($fit->co->default("artemis", "show_after_fit") eq 'history') {
      $rframes->{History}->Show(1);
      $rframes->{History}->{list}->SetSelection($rframes->{History}->{list}->GetCount-1);
      $rframes->{History}->put_log($fit);
      $rframes->{History}->set_params($fit);
    };
    undef $dur;
    undef $finish;
  } else {
    $rframes->{Log}->{text}->SetValue($fit->troubletext);
    $rframes->{Log}->Show(1);
    $rframes->{main}->{log_toggle}->SetValue(1);
    set_happiness_color($fit->co->default("happiness", "bad_color"));
    $finishtext = "The error report from the fit that just failed is written in the log window.";
    $code = "error";
  };

  my $this_name = $fit->name;
  $rframes->{main}->{name}->SetValue("Fit ". $fit->mo->currentfit) if ($this_name =~ m{\A\s*Fit\s+\d+\z});
  $rframes->{main}->{description}->SetValue($fit->description);
  autosave($name);
  $rframes->{main}->status($finishtext, $code);

  my @saved = $rframes->{main} -> {currentfit}->get(qw(happiness fom name description));
  my $newfit = Demeter::Fit->new(interface=>"Artemis (Wx $Wx::VERSION)");
  $newfit->set(happiness=>$saved[0], fom=>$saved[1], description=>$saved[3]);
  if ($saved[2] =~ m{\AFit\s+\d+\n}) {
    $newfit->name("Fit " . $saved[1]);
  } else {
    $newfit->name($saved[2]);
  };
  $rframes->{main} -> {currentfit} = $newfit;
  ++$fit_order{order}{current};

  modified(1);
  $::app->heap_check;

  undef $start;
  undef $busy;
};

sub update_order_file {
  my ($just_write) = @_;
  $just_write || 0;
  my $thisfit = $fit_order{order}{current} || 1;
  if (not $just_write) {
    $fit_order{order}{$thisfit} = $frames{main}->{currentfit}->group;
    $fit_order{order}{current}  = $thisfit;
  };
  my $string .= YAML::Tiny::Dump(%fit_order);
  open(my $ORDER, '>'.$frames{main}->{order_file});
  print $ORDER $string;
  close $ORDER;
  return $thisfit;
};

sub ifeffit_buffer {
  my ($text) = @_;
  foreach my $line (split(/\n/, $text)) {
    my ($was, $is) = $frames{Buffer}->insert('ifeffit', $line);
    my $color = ($line =~ m{\A\#}) ? 'comment' : 'normal';
    $frames{Buffer}->color('ifeffit', $was, $is, $color);
    $frames{Buffer}->insert('ifeffit', $/)
  };
};
sub plot_buffer {
  my ($text) = @_;
  foreach my $line (split(/\n/, $text)) {
    my ($was, $is) = $frames{Buffer}->insert('plot', $line);
    my $color = ($line =~ m{\A\#}) ? 'comment'
      : ($demeter->mo->template_plot eq 'singlefile') ? 'singlefile'
	:'normal';

    $frames{Buffer}->color('plot', $was, $is, $color);
    $frames{Buffer}->insert('plot', $/)
  };
};
sub feedback {
  my ($text) = @_;
  my ($was, $is) = $frames{Buffer}->insert('ifeffit', $text);
  my $color = ($text =~ m{\A\s*\*}) ? 'warning' : 'feedback';
  $frames{Buffer}->color('ifeffit', $was, $is, $color);
};



sub set_happiness_color {
  my $color = $_[0] || $demeter->co->default("happiness", "average_color");
  $color = wxNullColour if (not $demeter->co->default("artemis", "happiness"));
  $frames{main}->{fitbutton}  -> SetBackgroundColour(Wx::Colour->new($color));
  $frames{Plot}->{k_button}   -> SetBackgroundColour(Wx::Colour->new($color));
  $frames{Plot}->{r_button}   -> SetBackgroundColour(Wx::Colour->new($color));
  $frames{Plot}->{'q_button'} -> SetBackgroundColour(Wx::Colour->new($color));
  foreach my $k (keys(%frames)) {
    next unless ($k =~ m{\Adata});
    $frames{$k}->{'plot_k123'} -> SetBackgroundColour(Wx::Colour->new($color));
    $frames{$k}->{plot_r123}   -> SetBackgroundColour(Wx::Colour->new($color));
    $frames{$k}->{plot_rmr}    -> SetBackgroundColour(Wx::Colour->new($color));
    $frames{$k}->{plot_rk}     -> SetBackgroundColour(Wx::Colour->new($color));
    $frames{$k}->{plot_kq}     -> SetBackgroundColour(Wx::Colour->new($color));
  };
};

sub button_label {
  my ($string) = @_;
  my $this =  sprintf("%-40s", $string);
  return $string;
};

sub icon {
  my ($which) = @_;
  my $icon = File::Spec->catfile($Demeter::UI::Artemis::artemis_base, 'Artemis', 'icons', "$which.png");
  return wxNullBitmap if (not -e $icon);
  return Wx::Bitmap->new($icon, wxBITMAP_TYPE_ANY)
};

sub _doublewide {
  my ($widget) = @_;
  my ($w, $h) = $widget->GetSizeWH;
  $widget -> SetSizeWH(2*$w, $h);
};

sub set_mru {
  my ($self) = @_;

  foreach my $which (qw(artemis athena structure fit_serialization old_artemis)) {
    my $type = ($which eq 'fit_serialization') ? 'fit'
             : ($which eq 'old_artemis')       ? 'old'
	     :                                   $which;
    foreach my $i (0 .. $frames{main}->{mrumenu}->GetMenuItemCount-1) {
      $frames{main}->{'mru'.$type}->Delete($frames{main}->{'mru'.$type}->FindItemByPosition(0));
    };

    my @list = ($which eq 'structure') ? $demeter->get_mru_list('atoms', 'feff') : $demeter->get_mru_list($which);
    foreach my $f (@list) {
      $frames{main}->{'mru'.$type}-> Append(-1, $f->[0]);
    };
  };
};

sub OnMenuClick {
  my ($self, $event) = @_;
  my $id = $event->GetId;
  my $mru = $frames{main}->{mrumenu}->GetLabel($id);
  #print "$id    $mru\n";
  $mru =~ s{__}{_}g; 		# wtf!?!?!?

 SWITCH: {
    ($id == wxID_ABOUT) and do {
      &on_about;
      return;
    };
    ($id == wxID_CLOSE) and do {
      close_project(\%frames);
      return;
    };
    ($id == wxID_EXIT) and do {
      $self->Close;
      return;
    };
    ($id == wxID_OPEN) and do {
      read_project(\%frames);
      last SWITCH;
    };
    ($id == wxID_SAVE) and do {
      #my $fpj = File::Spec->catfile();
      save_project(\%frames, $frames{main}->{projectpath});
      last SWITCH;
    };
    ($id == wxID_SAVEAS) and do {
      save_project(\%frames);
      last SWITCH;
    };
    ($id == $SHOW_BUFFER) and do {
      $frames{Buffer}->Show(1);
      last SWITCH;
    };
    ($id == wxID_PREFERENCES) and do {
      $frames{Config}->Show(1);
      last SWITCH;
    };
    ($mru) and do {
      ## figure out which submenu it came from...
      read_project(\%frames, $mru) if $frames{main}->{mruartemis}  ->GetLabel($id);
      Import('dpj',  $mru)         if $frames{main}->{mrufit}      ->GetLabel($id);
      Import('prj',  $mru)         if $frames{main}->{mruathena}   ->GetLabel($id);
      Import('feff', $mru)         if $frames{main}->{mrustructure}->GetLabel($id);
      Import('old',  $mru)         if $frames{main}->{mruold}      ->GetLabel($id);
      last SWITCH;
    };

    (($id == $SHOW_GROUPS)  or ($id == $SHOW_ARRAYS) or
     ($id == $SHOW_SCALARS) or ($id == $SHOW_STRINGS) or
     ($id == $SHOW_PATHS)   or ($id == $SHOW_FEFFPATHS)) and do {
       show_ifeffit($id);
      last SWITCH;
    };

    ## -------- import submenu
    ($id == $IMPORT_OLD) and do {
      Import('old', q{});
      last SWITCH;
    };
    ($id == $IMPORT_FEFF) and do {
      Import('feff', q{});
      last SWITCH;
    };
    ($id == $IMPORT_FEFFIT) and do {
      Import('feffit', q{});
      last SWITCH;
    };
    ($id == $IMPORT_CHI) and do {
      Import('chi', q{});
      last SWITCH;
    };
    ($id == $IMPORT_DPJ) and do {
      Import('dpj', q{});
      last SWITCH;
    };

    ## -------- export submenu
    ($id == $EXPORT_IFEFFIT) and do {
      export('ifeffit');
      last SWITCH;
    };
    ($id == $EXPORT_DEMETER) and do {
      export('demeter');
      last SWITCH;
    };

    ## -------- debug submenu
    ($id == $PLOT_YAML) and do {
      $frames{Plot}->fetch_parameters('plot');
      my $yaml   = $demeter->po->serialization;
      my $dialog = Demeter::UI::Artemis::ShowText->new($frames{main}, $yaml, 'YAML of Plot object') -> Show;
      last SWITCH;
    };
    ($id == $PERL_MODULES) and do {
      my $text   = $demeter->module_environment . $demeter -> wx_environment;
      my $dialog = Demeter::UI::Artemis::ShowText->new($frames{main}, $text, 'Perl module versions') -> Show;
      last SWITCH;
    };
    ($id == $MODE_STATUS) and do {
      my $dialog = Demeter::UI::Artemis::ShowText->new($frames{main}, $demeter->mo->report('all'), 'Overview of this instance of Demeter') -> Show;
      last SWITCH;
    };
    #($id == $CRASH) and do {
    #  my $x = 1/0;
    #  last SWITCH;
    #};
    ($id == $IFEFFIT_MEMORY) and do {
      $::app->heap_check(1);
      last SWITCH;
    };

    ($id == $TERM_1) and do {
      $demeter->po->terminal_number(1);
      last SWITCH;
    };
    ($id == $TERM_2) and do {
      $demeter->po->terminal_number(2);
      last SWITCH;
    };
    ($id == $TERM_3) and do {
      $demeter->po->terminal_number(3);
      last SWITCH;
    };

    ## -------- help menu
    ($id == $STATUS) and do {
      $frames{Status} -> Show(1);
      last SWITCH;
    };
  };
};

sub show_ifeffit {
  my ($id) = @_;
  my $text = ($id =~ m{\A[a-z]+\z})   ? "\@group $id"
           : ($id == $SHOW_GROUPS)    ? "\@groups"
           : ($id == $SHOW_ARRAYS)    ? "\@arrays"
           : ($id == $SHOW_SCALARS)   ? "\@scalars"
           : ($id == $SHOW_STRINGS)   ? "\@strings"
           : ($id == $SHOW_PATHS)     ? "\@paths"
           : ($id == $SHOW_FEFFPATHS) ? "\@feffpaths"
           :                            q{};
  return if not $text;
  $demeter->dispose("show $text");
  $frames{Buffer}->Show(1);
};

sub OnToolEnter {
  1;
};
sub OnToolClick {
  my ($toolbar, $event, $self) = @_;
  my $which = (qw(GDS Plot History Journal))[$toolbar->GetToolPos($event->GetId)];
  $frames{$which}->Show($toolbar->GetToolState($event->GetId));
};
sub OnDataRightClick {
  my ($self, $event) = @_;
  my $dialog = Demeter::UI::Wx::MRU->new($frames{main}, 'athena', "Select a recent Athena project file", "Recent Athena project files");
  $frames{main}->status("There are no recent Athena project files."), return if ($dialog == -1);
  if( $dialog->ShowModal == wxID_CANCEL ) {
    $frames{main}->status("Import cancelled.");
  } else {
    Import('prj', $dialog->GetMruSelection);
  };
};





sub make_data_frame {
  my ($self, $data) = @_;
  my $databox = $self->{databox};

  #print join('|', split(//, emph($data->name))), $/;
  my $new = Wx::ToggleButton->new($self->{datalist}, -1, "Hide ".emph($data->name));
  #my $new = Wx::ToggleButton->new($self->{datalist}, -1, "Hide ".$data->name);
  $databox -> Add($new, 0, wxGROW|wxALL, 0);
  mouseover($new, "Display/hide " . $data->name . ".");

  do_the_size_dance($self);
  my $idata = $new->GetId;
  my $dnum = sprintf("data%s", $idata);
  $self->{$dnum} = $new;
  EVT_TOGGLEBUTTON($new, -1, sub{
		     $frames{$dnum}->Show($_[0]->GetValue);
		     my $label = $_[0]->GetLabel;
		     if ($_[0]->GetValue) {
		       $label =~ s{Show}{Hide};
		     } else {
		       $label =~ s{Hide}{Show};
		     };
		     $_[0]->SetLabel($label);
		   });


  $frames{$dnum}  = Demeter::UI::Artemis::Data->new($self, $nset++);
  $frames{$dnum} -> SetTitle("Artemis [Data] ".$data->name);
  $frames{$dnum} -> SetIcon($icon);
  $frames{$dnum} -> populate($data);
  $frames{$dnum} -> transfer;
  $frames{$dnum} -> {dnum} = $dnum;
  set_happiness_color();
  $frames{$dnum} -> Show(0);
  $new->SetValue(0);
  modified(1);
  $::app->heap_check;
  return ($dnum, $idata);
};


sub OnFeffClick {
  my ($feffbar, $event, $self) = @_;
  my $which = $feffbar->GetToolPos($event->GetId);

  if ($which == 0) {
    Import('feff', q{});
  } else {
    my $this = sprintf("feff%s", $event->GetId);
    return if not exists($frames{$this});
    $frames{$this}->Show($feffbar->GetToolState($event->GetId));
  };

};
sub OnFeffRightClick {
  my ($self, $event) = @_;
  my $dialog = Demeter::UI::Wx::MRU->new($frames{main}, ['atoms', 'feff'], "Start a new Atoms input or select a recent Feff input file, Atoms input file, or CIF file", "Recent Feff or crystal data file");
  $frames{main}->status("There are no recent crystal files."), return if ($dialog == -1);
  if( $dialog->ShowModal == wxID_CANCEL ) {
    $frames{main}->status("Import cancelled.");
  } else {
    my $which = $dialog->GetMruSelection;
    if ($which eq 'Open a blank Atoms window') {
      my ($fnum, $ifeff) = make_feff_frame($frames{main}, $BLANK);
      $frames{$fnum} -> Show(1);
      $frames{main}->{$fnum}->SetValue(1);
    } elsif (not -e $which) {
      $frames{main}->status("\"$which\" does not exist.");
    } elsif (not -r $which) {
      $frames{main}->status("\"$which\" cannot be read.");
    } else {
      Import('feff', $which);
    };
  };
};


## name for empty feff frame...
sub make_feff_frame {
  my ($self, $file, $name, $feffobject) = @_;
  my $feffbox = $self->{feffbox};
  $name ||= basename($file) if $file;	# ok for importing an atoms or CIF file
  $name ||= 'new';
  $name   = 'new' if ($name eq $BLANK);

  my $new = Wx::ToggleButton->new($self->{fefflist}, -1, "Hide ".emph($name));
  my $ifeff = $new->GetId;
  $feffbox -> Add($new, 0, wxGROW|wxRIGHT, 5);
  mouseover($new, "Display/hide $name.");

  do_the_size_dance($self);
  my $fnum = sprintf("feff%s", $ifeff);
  $self->{$fnum} = $new;
  EVT_TOGGLEBUTTON($new, -1, sub{
		     $frames{$fnum}->Show($_[0]->GetValue);
		     my $label = $_[0]->GetLabel;
		     if ($_[0]->GetValue) {
		       $label =~ s{Show}{Hide};
		     } else {
		       $label =~ s{Hide}{Show};
		     };
		     $_[0]->SetLabel($label);
		   });

  my $base = File::Spec->catfile($self->{project_folder}, 'feff');
  $frames{$fnum} =  Demeter::UI::AtomsApp->new($base, $feffobject, $fnum);
  $frames{$fnum} -> SetTitle('Artemis [Feff] Atoms and Feff');
  $frames{$fnum} -> SetIcon($icon);
  if ($file and (-e $file) and ($demeter->is_atoms($file) or $demeter->is_cif($file))) {
    $frames{$fnum}->{Atoms}->Demeter::UI::Atoms::Xtal::open_file($file);
  } else {
    $frames{$fnum}->{Atoms}->{used} = 0;
    $frames{$fnum}->{Atoms}->{name}->SetValue('new');
    if ($file ne $BLANK) {
      $frames{$fnum}->{notebook}->SetPageImage(0, 5); # see Demeter::UI::Atoms.pm around line 60
      $frames{$fnum}->{notebook}->SetPageText(0, '');
      EVT_NOTEBOOK_PAGE_CHANGING($frames{$fnum}, $frames{$fnum}->{notebook},
				 sub{ my($self, $event) = @_;
				      my ($selection) = $event->GetSelection;
				      $event->Veto() if ($selection == 0); # veto selection of Atoms tab
				      return;
				    });
    };
  };
  if ($file and (-e $file) and $demeter->is_feff($file)) {
    my $text = $demeter->slurp($file);
    $frames{$fnum}->{Feff}->{feff}->SetValue($text);
    $frames{$fnum}->{Feff}->{name}->SetValue(basename($file, '.inp'));
    $frames{$fnum}->{notebook}->ChangeSelection(1);
    $demeter -> push_mru("feff", $file)
  };
  #$newtool -> SetLabel( $frames{$fnum}->{Atoms}->{name}->GetValue );
  $frames{$fnum} -> {fnum} = $fnum;

  EVT_CLOSE($frames{$fnum}, sub{  $frames{$fnum}->Show(0);
				  $frames{main}->{$fnum}->SetValue(0);
				  (my $label = $frames{main}->{$fnum}->GetLabel) =~ s{Hide}{Show};
				  $frames{main}->{$fnum}->SetLabel($label);
				});

  $frames{$fnum} -> Show(0);
  $new->SetValue(0);
  modified(1) if ($file);
  return ($fnum, $ifeff);
};


## the tool bars only seem to update after a resize.  I could not
## figure out how to force an update without resizing, so this sub
## jiggles the window and voila! the new tool button appears.
sub do_the_size_dance {
  my ($top) = @_;
  my @size = $top->GetSizeWH;
  $top -> SetSize($size[0], $size[1]+1);
  $top -> SetSize($size[0], $size[1]);
};


sub discard_feff {
  my ($which, $force) = @_;
  my $feffobject = $frames{$which}->{feffobject};
  ##my $atomsobject = $frames{$which}->{Atoms}

  if (not $force) {
    my $yesno = Wx::MessageDialog->new($frames{main}, "Do you really wish to discard this Feff calculation?",
				       "Discard?", wxYES_NO);
    return if ($yesno->ShowModal == wxID_NO);
  };

  ## remove the button from the data tool bar
  my $fnum = $frames{$which}->{fnum};
  (my $id = $fnum) =~ s{feff}{};
  $frames{main}->{$fnum}->Destroy;

  ## remove the frame with the feff calculation
  $frames{$fnum}->Hide;
  $frames{$fnum}->Destroy;
  delete $frames{$fnum};

  ## destroy the ScatteringPath object
  ## destroy the feff object
  $feffobject->DESTROY if (defined($feffobject) and (ref($feffobject) =~ m{Demeter}));
}

sub export {
  my ($how) = @_;

  ## make a disposable Fit object
  my ($abort, $rdata, $rpaths) = uptodate(\%frames);
  my $rgds = $frames{GDS}->reset_all(0,0);
  my @data  = @$rdata;
  my @paths = @$rpaths;
  my @gds   = @$rgds;
  if ($abort) {
    $frames{main}->status("There is a problem in your fit.");
    return;
  };
  my $fit = Demeter::Fit->new(data => \@data, paths => \@paths, gds => \@gds);

  my $suffix = ($how eq 'ifeffit') ? 'iff' : 'pl';

  my $fd = Wx::FileDialog->new( $::app->{main}, "Export this fitting model", cwd, "artemis.$suffix",
				"fitting scripts (*.$suffix)|*.$suffix|All files|*",
				wxFD_SAVE|wxFD_CHANGE_DIR, #|wxFD_OVERWRITE_PROMPT,
				wxDefaultPosition);
  if ($fd->ShowModal == wxID_CANCEL) {
    $::app->{main}->status("Exporting fitting model cancelled.");
    return;
  };
  my $fname = File::Spec->catfile($fd->GetDirectory, $fd->GetFilename);
  return if $::app->{main}->overwrite_prompt($fname); # work-around gtk's wxFD_OVERWRITE_PROMPT bug (5 Jan 2011)
  unlink $fname;

  ## save mode settings
  my @modes = qw(template_process template_fit ifeffit file callback plotcallback feedback);
  my @values = $fit -> mo -> get(@modes);

  ## set mode settings appropriate to file output
  $fit -> mo -> template_process($how);
  $fit -> mo -> template_fit($how);
  $fit -> mo -> ifeffit(0);
  $fit -> mo -> file('>'.$fname);
  $fit -> mo -> callback(sub{});
  $fit -> mo -> plotcallback(sub{});
  $fit -> mo -> feedback(sub{});

  ## do the fit, thus writing the script file
  $fit -> fit;

  ## restore mode settings
  $fit -> mo -> set(zip(@modes, @values));

  undef $fit;
};

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
use Demeter::UI::Wx::OverwritePrompt;
my $normal = wxNullColour;
my $wait   = Wx::Colour->new("#C5E49A");
my $error  = Wx::Colour->new("#FD7E6F");
my $alert  = Wx::Colour->new("#FCDD9F");
my $debug  = 0;
sub status {
  my ($self, $text, $type) = @_;
  $type ||= 'normal';

  if ($debug) {
    local $|=1;
    print $text, " -- ", join(", ", (caller)[0,2]), $/;
  };

  my $bgcolor = ($type =~ m{normal}) ? $normal
              : ($type =~ m{wait})   ? $wait
              : ($type =~ m{alert})  ? $alert
              : ($type =~ m{error})  ? $error
	      :                        $normal;
  $self->GetStatusBar->SetBackgroundColour($bgcolor);
  $self->GetStatusBar->Refresh;
  $self->GetStatusBar->SetStatusText($text);
  return if ($type =~ m{nobuffer});
  $Demeter::UI::Artemis::frames{Status}->put_text($text, $type);
};


=for Explain

According to the wxWidgets documentation, "Please note that
wxCheckListBox uses client data in its implementation, and therefore
this is not available to the application."  This appears either not to
be true on Linux or, perhaps, that the client data is overwritable
with no ill effect.  On Windows, however, attempting to set client
data crashes the application.

On the wxperl-users mailing list Mattia Barbon said: "It's a wxWidgets
limitation: it uses the same Win32 client data slot in wxListBox to
store client data, in wxCheckListBox to store the boolean state of the
item."

Sigh....

These methods are an attempt to replicate the effect of client data by
maintaining a list of pointers to data that is indexed to the
CheckListBox.  This list is stored in the underlying hash of the
CheckListBox object.  The trick is to keep the list in sync with the
displayed content of the CheckListBox at all times.

Yes, this *is* much to complicated.

=cut

package Wx::CheckListBox;
use Wx qw(:everything);
sub AddData {
  my ($clb, $name, $data) = @_;
  $clb->Append($name);
  push @{$clb->{datalist}}, $data;
};

sub InsertData {
  my ($clb, $name, $n, $data) = @_;
  $clb->Insert($name, $n);
  my @list = @{$clb->{datalist}};
  splice(@list, $n, 0, $data);
  $clb->{datalist} = \@list;
};

sub SetIndexedData {
  my ($clb, $n, $data) = @_;
  $clb->{datalist}->[$n]=$data;
};

sub GetIndexedData {
  my ($clb, $n) = @_;
  return $clb->{datalist}->[$n] if defined($n);
  return $clb->{intial};
};

sub DeleteData {
  my ($clb, $n) = @_;

  ## remove from the Indexed array
  my @list = @{$clb->{datalist}};
  my $gone = splice(@list, $n, 1);
  #print $gone, "  ", $gone->name, $/;
  $clb->{datalist} = \@list;

  $clb->Delete($n); # this calls the selection event on the new item
};

sub ClearAll {
  my ($clb) = @_;
  $clb->{datalist} = [];
  $clb->Clear;
};

## also need a method for reordering items on the list...

1;


=head1 NAME

Demeter::UI::Artemis - EXAFS analysis using Feff and Ifeffit

=head1 VERSION

This documentation refers to Demeter version 0.4.

=head1 SYNOPSIS

This short program launches Artemis:

  use Wx;
  use Demeter::UI::Artemis;
  Wx::InitAllImageHandlers();
  my $window = Demeter::UI::Artemis->new;
  $window -> MainLoop;

=head1 DESCRIPTION

Artemis...

=head1 USE

Using ...

=head1 CONFIGURATION

Many aspects of Artemis and its UI are configurable using the
configuration ...

=head1 DEPENDENCIES

This is a Wx application.  Demeter's dependencies are in the
F<Bundle/DemeterBundle.pm> file.

=head1 BUGS AND LIMITATIONS

=over 4

=item *

Many, many, many ...

=back

Please report problems to Bruce Ravel (bravel AT bnl DOT gov)

Patches are welcome.

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
