package Demeter::UI::Artemis;

use Demeter; # qw(:plotwith=gnuplot);
use Demeter::UI::Atoms;
use Demeter::UI::Artemis::Project;
use Demeter::UI::Artemis::ShowText;
use Demeter::UI::Wx::MRU;

use vars qw($demeter $buffer $plotbuffer);
$demeter = Demeter->new;
$demeter->set_mode(ifeffit=>1, screen=>0);

use Cwd;
use File::Basename;
use File::Copy;
use File::Path;
use File::Spec;
use List::MoreUtils qw(zip);
use Scalar::Util qw(blessed);
use String::Random qw(random_string);
use YAML;

use Wx qw(:everything);
use Wx::Event qw(EVT_MENU EVT_CLOSE EVT_TOOL_ENTER EVT_CHECKBOX EVT_BUTTON
		 EVT_TOGGLEBUTTON EVT_ENTER_WINDOW EVT_LEAVE_WINDOW
		 EVT_TOOL_RCLICKED);
use base 'Wx::App';

use Readonly;
Readonly my $MRU	    => Wx::NewId();
Readonly my $SHOW_BUFFER    => Wx::NewId();
Readonly my $CONFIG	    => Wx::NewId();
Readonly my $SHOW_GROUPS    => Wx::NewId();
Readonly my $SHOW_ARRAYS    => Wx::NewId();
Readonly my $SHOW_SCALARS   => Wx::NewId();
Readonly my $SHOW_STRINGS   => Wx::NewId();
Readonly my $IMPORT_FEFFIT  => Wx::NewId();
Readonly my $IMPORT_OLD     => Wx::NewId();
Readonly my $EXPORT_IFEFFIT => Wx::NewId();
Readonly my $EXPORT_DEMETER => Wx::NewId();
Readonly my $PLOT_YAML      => Wx::NewId();
Readonly my $MODE_STATUS    => Wx::NewId();
Readonly my $PERL_MODULES   => Wx::NewId();

use Wx::Perl::Carp;
$SIG{__WARN__} = sub {Wx::Perl::Carp::warn($_[0])};
$SIG{__DIE__}  = sub {Wx::Perl::Carp::warn($_[0])};

sub identify_self {
  my @caller = caller;
  return dirname($caller[1]);
};
use vars qw($artemis_base $icon $nset %frames %fit_order);
$fit_order{order}{current} = 0;
$nset = 0;
$artemis_base = identify_self();

my %hints = (
	     gds  => "Display the Guess/Def/Set parameters dialog",
	     plot => "Display the plotting controls dialog",
	     log  => "Display the fit log",
	     fit  => "Display the fit history dialog",
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
  foreach my $m (qw(GDS Plot History Log Buffer Config Data Prj)) {
    next if $INC{"Demeter/UI/Artemis/$m.pm"};
    ##print "Demeter/UI/Artemis/$m.pm\n";
    require "Demeter/UI/Artemis/$m.pm";
  };

  ## -------- create a new frame and set icon
  $frames{main} = Wx::Frame->new(undef, -1, 'Artemis [EXAFS data analysis] - <untitled>',
				[1,1], # position -- along top of screen
				[Wx::SystemSettings::GetMetric(wxSYS_SCREEN_X), 150] # size -- entire width of screen
			       );
  my $iconfile = File::Spec->catfile(dirname($INC{'Demeter/UI/Artemis.pm'}), 'Artemis', 'icons', "artemis.png");
  $icon = Wx::Icon->new( $iconfile, wxBITMAP_TYPE_ANY );
  $frames{main} -> SetIcon($icon);
  $frames{main} -> {currentfit} = q{};
  $frames{main} -> {projectname} = '<untitled>';
  $frames{main} -> {projectpath} = q{};
  $frames{main} -> {modified} = 0;

  ## -------- Set up menubar
  my $bar        = Wx::MenuBar->new;
  my $filemenu   = Wx::Menu->new;
  my $mrumenu    = Wx::Menu->new;

  my $importmenu = Wx::Menu->new;
  $importmenu->Append($IMPORT_OLD,     "an old-style Artemis project",  "Import the current fitting model from an old-style Artemis project file");
  $importmenu->Append($IMPORT_FEFFIT,  "a feffit.inp file",             "Import a fitting model from a feffit.inp file");
  $importmenu->Enable($_, 0) foreach ($IMPORT_OLD, $IMPORT_FEFFIT);

  my $exportmenu = Wx::Menu->new;
  $exportmenu->Append($EXPORT_IFEFFIT,  "to Ifeffit script",  "Export the current fitting model as an Ifeffit script");
  $exportmenu->Append($EXPORT_DEMETER,  "to Demeter script",  "Export the current fitting model as a perl script using Demeter");

  $filemenu->Append(wxID_OPEN, "Open project", "Read from a project file" );
  $filemenu->AppendSubMenu($mrumenu, "Recent projects", "Open a submenu of recently used files" );
  $filemenu->Append(wxID_SAVE, "Save project", "Save project" );
  $filemenu->Append(wxID_SAVEAS, "Save project as...", "Save to a new project file" );
  $filemenu->AppendSeparator;
  $filemenu->AppendSubMenu($importmenu, "Import...", "Export a fitting model from ..." );
  $filemenu->AppendSubMenu($exportmenu, "Export...", "Export the current fitting model as ..." );
  $filemenu->AppendSeparator;
  $filemenu->Append(wxID_CLOSE, "&Close" );
  $filemenu->Append(wxID_EXIT, "E&xit" );
  $frames{main}->{filemenu} = $filemenu;
  $frames{main}->{mrumenu}  = $mrumenu;

  my $showmenu = Wx::Menu->new;
  $showmenu->Append($SHOW_GROUPS,  "groups",  "Show Ifeffit groups");
  $showmenu->Append($SHOW_ARRAYS,  "arrays",  "Show Ifeffit arrays");
  $showmenu->Append($SHOW_SCALARS, "scalars", "Show Ifeffit scalars");
  $showmenu->Append($SHOW_STRINGS, "strings", "Show Ifeffit strings");

  my $settingsmenu = Wx::Menu->new;
  $settingsmenu->AppendSubMenu($showmenu, "Show Ifeffit ...", "Show variables from Ifeffit");
  $settingsmenu->Append($SHOW_BUFFER, "Show command buffer", "Show the Ifeffit and plotting commands buffer");
  $settingsmenu->Append($CONFIG, "Edit Preferences", "Show the preferences editing dialog");

  my $debugmenu = Wx::Menu->new;
  $debugmenu->Append($PLOT_YAML, "Show YAML for Plot object",  "Show YAML for Plot object",  wxITEM_NORMAL );
  $debugmenu->Append($MODE_STATUS, "Mode status",  "Mode status",  wxITEM_NORMAL );
  $debugmenu->Append($PERL_MODULES, "Perl modules", "Show perl module versions", wxITEM_NORMAL );

  my $helpmenu = Wx::Menu->new;
  $helpmenu->Append(wxID_ABOUT, "&About..." );
  $helpmenu->AppendSubMenu($debugmenu, 'Debug options', 'Display debugging tools')
    if ($demeter->co->default("artemis", "debug_menus"));

  $bar->Append( $filemenu,      "&File" );
  $bar->Append( $settingsmenu,  "&Settings" );
  $bar->Append( $helpmenu,      "&Help" );
  $frames{main}->SetMenuBar( $bar );

  my $hbox = Wx::BoxSizer->new( wxHORIZONTAL);

  ## -------- status bar
  $frames{main}->{statusbar} = $frames{main}->CreateStatusBar;
  $frames{main}->{statusbar} -> SetStatusText("Welcome to Artemis (" . $demeter->identify . ")");

  ## -------- GDS and Plot toolbar
  my $vbox = Wx::BoxSizer->new( wxVERTICAL);
  $hbox -> Add($vbox, 0, wxALL, 5);
  my $toolbar = Wx::ToolBar->new($frames{main}, -1, wxDefaultPosition, wxDefaultSize, wxTB_VERTICAL|wxTB_HORZ_TEXT);
  $frames{main}->{toolbar} = $toolbar;
  $frames{main}->{gds_toggle}     = $toolbar -> AddCheckTool(1, "Show GDS",           icon("gds"),     wxNullBitmap, q{}, $hints{gds} );
  $frames{main}->{plot_toggle}    = $toolbar -> AddCheckTool(2, "  Show plot tools",  icon("plot"),    wxNullBitmap, q{}, $hints{plot} );
  $frames{main}->{history_toggle} = $toolbar -> AddCheckTool(3, "  Show fit history", icon("history"), wxNullBitmap, q{}, $hints{fit} );
  $toolbar -> Realize;
  $vbox -> Add($toolbar, 0, wxALL, 0);

  ## -------- Data box
  $vbox = Wx::BoxSizer->new( wxVERTICAL);
  $hbox -> Add($vbox, 0, wxALL, 5);
  my $databox       = Wx::StaticBox->new($frames{main}, -1, 'Data sets', wxDefaultPosition, wxDefaultSize);
  my $databoxsizer  = Wx::StaticBoxSizer->new( $databox, wxVERTICAL );

  my $datalist = Wx::ScrolledWindow->new($frames{main}, -1, wxDefaultPosition, wxDefaultSize, wxVSCROLL);
  # $datalist->SetScrollbars(20, 20, 50, 50);
  my $datavbox = Wx::BoxSizer->new( wxVERTICAL );
  $datalist->SetSizer($datavbox);
  my $datatool = Wx::ToolBar->new($datalist, -1, wxDefaultPosition, wxDefaultSize, wxTB_VERTICAL|wxTB_HORZ_TEXT|wxTB_LEFT);
  $datatool -> AddTool(0, "New data           ", icon("add"), wxNullBitmap, wxITEM_NORMAL, q{}, "Import a new data set" );
  $datatool -> AddSeparator;
  #   $datatool -> AddCheckTool(-1, "Show data set 1", icon("pixel"), wxNullBitmap, wxITEM_NORMAL, q{}, q{} );
  $datatool -> Realize;
  $datavbox     -> Add($datatool);
  $databoxsizer -> Add($datalist, 1, wxGROW|wxALL, 0);
  $hbox         -> Add($databoxsizer, 2, wxGROW|wxALL, 0);
  $frames{main}->{datatool} = $datatool;

  EVT_TOOL_RCLICKED($frames{main}->{datatool}, -1, \&OnDataRightClick);


  ## -------- Feff box
  $vbox = Wx::BoxSizer->new( wxVERTICAL);
  $hbox -> Add($vbox, 0, wxALL, 5);
  my $feffbox       = Wx::StaticBox->new($frames{main}, -1, 'Feff calculations', wxDefaultPosition, wxDefaultSize);
  my $feffboxsizer  = Wx::StaticBoxSizer->new( $feffbox, wxVERTICAL );

  my $fefflist = Wx::ScrolledWindow->new($frames{main}, -1, wxDefaultPosition, wxDefaultSize, wxVSCROLL);
  # $fefflist->SetScrollbars(20, 20, 50, 50);
  my $feffvbox = Wx::BoxSizer->new( wxVERTICAL);
  $fefflist->SetSizer($feffvbox);
  my $fefftool = Wx::ToolBar->new($fefflist, -1, wxDefaultPosition, wxDefaultSize, wxTB_VERTICAL|wxTB_HORZ_TEXT|wxTB_LEFT);
  $fefftool -> AddTool(-1, "New Feff calculation", icon("add"), wxNullBitmap, wxITEM_NORMAL, q{}, "Import a new Feff calculation" );
  $fefftool -> AddSeparator;
  #   $fefftool -> AddCheckTool(-1, "Show feff calc 1", icon("pixel"), wxNullBitmap, q{}, q{} );
  $fefftool -> Realize;
  $feffvbox     -> Add($fefftool);
  $feffboxsizer -> Add($fefflist, 0, wxGROW|wxALL, 0);
  $hbox         -> Add($feffboxsizer, 2, wxGROW|wxALL, 0);
  $frames{main}->{fefftool} = $fefftool;

  ## -------- Fit box
  $vbox = Wx::BoxSizer->new( wxVERTICAL);
  $hbox -> Add($vbox, 3, wxGROW|wxLEFT|wxRIGHT|wxTOP, 5);

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


  $hname  -> Add($label,   0, wxALL, 3);
  map {$hname  -> Add($_,   0, wxLEFT|wxRIGHT, 2)} @fitspace;
  $fitspace[1]->SetValue(1) if ($demeter->co->default("fit", "space") eq 'r');
  $fitspace[2]->SetValue(2) if ($demeter->co->default("fit", "space") eq 'q');

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



  EVT_MENU	 ($frames{main}, -1,         sub{my ($frame,  $event) = @_; OnMenuClick($frame,  $event)} );
  EVT_CLOSE	 ($frames{main},             \&on_close);
  EVT_MENU	 ($toolbar,      -1,         sub{my ($toolbar,  $event) = @_; OnToolClick($toolbar,  $event, $frames{main})} );
  EVT_MENU	 ($datatool,     -1,         sub{my ($datatool, $event) = @_; OnDataClick($datatool, $event, $frames{main})} );
  EVT_MENU	 ($fefftool,     -1,         sub{my ($fefftool, $event) = @_; OnFeffClick($fefftool, $event, $frames{main})} );
  EVT_TOOL_ENTER ($frames{main}, $toolbar,   sub{my ($toolbar,  $event) = @_; OnToolEnter($toolbar,  $event, 'toolbar')} );
  EVT_BUTTON     ($frames{main}->{fitbutton}, -1, sub{fit(@_, \%frames)});



  $frames{main} -> SetSizer($hbox);
  #$hbox  -> Fit($toolbar);
  #$hbox  -> SetSizeHints($toolbar);

  foreach my $part (qw(GDS Plot Log History Buffer Config)) {
    my $pp = "Demeter::UI::Artemis::".$part;
    $frames{$part} = $pp->new($frames{main});
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

  my $orderfile = File::Spec->catfile($frames{main}->{project_folder}, "order");
  $frames{main}->{order_file} = $orderfile;
  if (not -e $orderfile) {
    my $string .= YAML::Dump(%fit_order);
    open(my $ORDER, '>'.$orderfile);
    print $ORDER $string;
    close $ORDER;
  };

  set_mru();
  ## now that everything is established, set up disposal callbacks to
  ## display Ifeffit commands in the buffer window
  $demeter->set_mode(callback     => \&ifeffit_buffer,
		     plotcallback => ($demeter->mo->template_plot eq 'pgplot') ? \&ifeffit_buffer : \&plot_buffer,
		     feedback     => \&feedback,
		    );

  if ($ARGV[0] and -e $ARGV[0]) {
    my $file = File::Spec->rel2abs( $ARGV[0] );
    read_project(\%frames, $file);
  };
  1;
}

sub mouseover {
  my ($widget, $text) = @_;
  my $sb = $frames{main}->{statusbar};
  EVT_ENTER_WINDOW($widget, sub{$sb->PushStatusText($text); $_[1]->Skip});
  EVT_LEAVE_WINDOW($widget, sub{$sb->PopStatusText;         $_[1]->Skip});
};

sub on_close {
  my ($self, $event) = @_;

  ## offer to save project....
  my $yesno = Wx::MessageDialog->new($frames{main},
				     "Save this project before exiting?",
				     "Save project?",
				     wxYES_NO|wxCANCEL|wxYES_DEFAULT|wxICON_QUESTION);
  my $result = $yesno->ShowModal;
  if ($result == wxID_CANCEL) {
    $frames{main}->{statusbar}->SetStatusText("Not exiting project.");
    return 0;
  };
  save_project(\%frames) if $result == wxID_YES;
  rmtree($self->{project_folder});
  $demeter->mo->destroy_all;
  foreach my $f (values(%frames)) {
    next if ($f !~ m{Demeter});
    #print '>', $f, '<', $/;
    $f->Destroy;
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
  $info->SetDevelopers( ["Bruce Ravel <bravel\@bnl.gov>\n",
			 "Ifeffit is copyright © 1992-2009 Matt Newville"
			] );
  $info->SetLicense( slurp(File::Spec->catfile($artemis_base, 'Artemis', 'share', "GPL.dem")) );
  my $artwork = <<'EOH'
Blah blah blah

Some icons taken from the Fairytale icon set at Wikimedia commons,
http://commons.wikimedia.org/ and others from the Gartoon Redux icon
set from http:://www.gnome-look.org

All other icons icons are from the Kids icon set for
KDE by Everaldo Coelho, http://www.everaldo.com
EOH
  ;
  $info -> AddArtist($artwork);

  Wx::AboutBox( $info );
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

  modified(1);
  return ($abort, \@data, \@paths);
};

sub fit {
  my ($button, $event, $rframes) = @_;
  $rframes->{main}->{statusbar}->SetStatusText("Fitting (please be patient, it may take a while...)");
  my $busy = Wx::BusyCursor->new();

  ## reset all relevant widgets to their initial states (i.e. assume
  ## that the last fit returned trouble and that the widgets
  ## containing the responsible data were colored in some way to
  ## indicate that)

  #foreach my $f (keys %$rframes) {
  #  next if ($f !~ m{data});
  #  print $rframes->{$f}->{pathlist}->GetPage(0)->{path}->parentgroup;
  #};
  #return;

  my ($abort, $rdata, $rpaths) = uptodate($rframes);
  my $rgds = $rframes->{GDS}->reset_all;

  my @data  = @$rdata;
  my @paths = @$rpaths;
  my @gds   = @$rgds;
  if ($abort) {
    $rframes->{main}->{statusbar}->SetStatusText("There is a problem in your fit.");
    return;
  };


  ## get name, fom, and description + other properties
  my $fit = Demeter::Fit->new(data => \@data, paths => \@paths, gds => \@gds);
  $fit->interface("Artemis (Wx $Wx::VERSION)");
  my $name = $rframes->{main}->{name}->GetValue || 'Fit '.$fit->mo->currentfit;
  $fit->name($name);
  $fit->description($rframes->{main}->{description}->GetValue);
  $fit -> fom($fit->mo->currentfit);
  #$fit->ignore_errors(1);
  $rframes->{main} -> {currentfit} = $fit;

  $fit->set_mode(ifeffit=>1, screen=>0);
  my $result = $fit->fit;
  if ($result eq $fit) {
    $fit -> serialize(tree     => File::Spec->catfile($frames{main}->{project_folder}, 'fits'),
		      folder   => $fit->group,
		      nozip    => 1,
		      copyfeff => 0,
		     );
    my $thisfit = $fit_order{order}{current} || 0;
    ++$thisfit;
    $fit_order{order}{$thisfit} = $fit->group;
    $fit_order{order}{current}  = $thisfit;
    my $string .= YAML::Dump(%fit_order);
    open(my $ORDER, '>'.$frames{main}->{order_file});
    print $ORDER $string;
    close $ORDER;

    $rframes->{GDS}->fill_results(@gds);
    $rframes->{Log}->put_log($fit->logtext, $fit->color);
    $rframes->{Log}->SetTitle("Artemis [Log] " . $rframes->{main}->{name}->GetValue);
    $rframes->{Log}->Show(1);
    $rframes->{main}->{log_toggle}->SetValue(1);

    ## fill in plotting list
    if (not $rframes->{Plot}->{freeze}->GetValue) {
      $rframes->{Plot}->{plotlist}->Clear;
      foreach my $k (sort (keys (%$rframes))) {
	next if ($k !~ m{data});
	$rframes->{$k}->transfer if $rframes->{$k}->{plot_after}->GetValue;
	foreach my $p (0 .. $rframes->{$k}->{pathlist}->GetPageCount -1) {
	  my $pathpage = $rframes->{$k}->{pathlist}->{LIST}->GetClientData($p);
	  $pathpage->transfer if $pathpage->{plotafter}->GetValue;
	};
      };
    };
    set_happiness_color($fit->color);

    $fit->po->start_plot;
    $rframes->{Plot}->{limits}->{fit}->SetValue(1);
    $fit->po->plot_fit(1);
    my $how = $fit->co->default("artemis", "plot_after_fit");
    if ($how =~ m{\A(?:rmr|r123|k123|kq)\z}) {
      $data[0]->plot($how);
    } elsif ($how =~ m{\A[krq]\z}) {
      $rframes->{Plot}->plot(q{}, $how);
    };

    $rframes->{main}->{statusbar}->SetStatusText("Your fit is finished!");
  } else {
    $rframes->{Log}->{text}->SetValue($fit->troubletext);
    #$rframes->{Log}->Show(1);
    #$rframes->{main}->{log_toggle}->SetValue(1);
    set_happiness_color($fit->co->default("happiness", "bad_color"));
    $rframes->{main}->{statusbar}->SetStatusText("The error report from the fit that just failed are written in the log window.");
  };

  my $this_name = $fit->name;
  $rframes->{main}->{name}->SetValue("Fit ". $fit->mo->currentfit) if ($this_name =~ m{\A\s*Fit\s+\d+\z});
  $rframes->{main}->{description}->SetValue($fit->description);
  undef $busy;
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
    my $color = ($line =~ m{\A\#}) ? 'comment' : 'normal';
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
  $frames{main}->{fitbutton}  -> SetBackgroundColour(Wx::Colour->new($color));
  $frames{Plot}->{k_button}   -> SetBackgroundColour(Wx::Colour->new($color));
  $frames{Plot}->{r_button}   -> SetBackgroundColour(Wx::Colour->new($color));
  $frames{Plot}->{'q_button'} -> SetBackgroundColour(Wx::Colour->new($color));
  foreach my $k (keys(%frames)) {
    next unless ($k =~ m{\Adata});
    $frames{$k}->{'plot_k123'} -> SetBackgroundColour(Wx::Colour->new($color));
    $frames{$k}->{plot_r123}   -> SetBackgroundColour(Wx::Colour->new($color));
    $frames{$k}->{plot_rmr}    -> SetBackgroundColour(Wx::Colour->new($color));
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

sub slurp {
  my $file = shift;
  local $/;
  open(my $FH, $file);
  my $text = <$FH>;
  close $FH;
  return $text;
};

sub _doublewide {
  my ($widget) = @_;
  my ($w, $h) = $widget->GetSizeWH;
  $widget -> SetSizeWH(2*$w, $h);
};

sub set_mru {
  my ($self) = @_;

  foreach my $i (0 .. $frames{main}->{mrumenu}->GetMenuItemCount-1) {
    $frames{main}->{mrumenu}->Delete($frames{main}->{mrumenu}->FindItemByPosition(0));
  };

  my @list = $demeter->get_mru_list('artemis');
  foreach my $f (@list) {
    #print ">> $f\n";
    $frames{main}->{mrumenu}->Append(-1, $f);
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
      save_project(\%frames, $frames{main}->{projectname}.'.fpj');
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
    ($id == $CONFIG) and do {
      $frames{Config}->Show(1);
      last SWITCH;
    };
    ($mru) and do {
      read_project(\%frames, $mru);
      last SWITCH;
    };

    (($id == $SHOW_GROUPS)  or ($id == $SHOW_ARRAYS) or
     ($id == $SHOW_SCALARS) or ($id == $SHOW_STRINGS)) and do {
       show_ifeffit($id);
      last SWITCH;
    };

    ($id == $EXPORT_IFEFFIT) and do {
      export(\%frames, 'ifeffit');
      last SWITCH;
    };
    ($id == $EXPORT_DEMETER) and do {
      export(\%frames, 'demeter');
      last SWITCH;
    };

    ($id == $PLOT_YAML) and do {
      $frames{Plot}->fetch_parameters;
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

  };
};

sub show_ifeffit {
  my ($id) = @_;
  my $text = ($id =~ m{\A[a-z]+\z}) ? "\@group $id"
           : ($id == $SHOW_GROUPS)  ? "\@groups"
           : ($id == $SHOW_ARRAYS)  ? "\@arrays"
           : ($id == $SHOW_SCALARS) ? "\@scalars"
           : ($id == $SHOW_STRINGS) ? "\@strings"
           :                          q{};
  return if not $text;
  $demeter->dispose("show $text");
  $frames{Buffer}->Show(1);
};

sub OnToolEnter {
  1;
};
sub OnToolClick {
  my ($toolbar, $event, $self) = @_;
  my $which = (qw(GDS Plot History))[$toolbar->GetToolPos($event->GetId)];
  $frames{$which}->Show($toolbar->GetToolState($event->GetId));
};
sub OnDataRightClick {
  my ($toolbar, $event) = @_;
  return if ($event->GetId != 0);

  #my @mrulist = $demeter->get_mru_list("athena");
  my $dialog = Demeter::UI::Wx::MRU->new($frames{main}, 'athena', "Select a recent Athena project file", "Recent Athena project files");
  $frames{main}->{statusbar}->SetStatusText("There are no recent Athena project files."), return
    if ($dialog == -1);
  if( $dialog->ShowModal == wxID_CANCEL ) {
    $frames{main}->{statusbar}->SetStatusText("Import cancelled.");
  } else {
    import_prj($dialog->GetStringSelection);
  };
};

sub OnDataClick {
  my ($databar, $event, $self) = @_;
  my $which = $databar->GetToolPos($event->GetId);
  if ($which == 0) {
    import_prj(0);
  } else {
    my $this = sprintf("data%s", $event->GetId);
    return if not exists($frames{$this});
    $frames{$this}->Show($databar->GetToolState($event->GetId));
  };
};
sub import_prj {
  my ($fname) = @_;
  my $file = $fname;
  if (not $fname) {
    my $fd = Wx::FileDialog->new( $frames{main}, "Import an Athena project", cwd, q{},
				  "Athena project (*.prj)|*.prj|All files|*.*",
				  wxFD_OPEN|wxFD_FILE_MUST_EXIST|wxFD_CHANGE_DIR|wxFD_PREVIEW,
				  wxDefaultPosition);
    if ($fd->ShowModal == wxID_CANCEL) {
      $frames{main}->{statusbar}->SetStatusText("Data import cancelled.");
      return;
    };
    $file = File::Spec->catfile($fd->GetDirectory, $fd->GetFilename);
  }
  ##
  my $selection = 0;
  $frames{prj} =  Demeter::UI::Artemis::Prj->new($frames{main}, $file);
  my $result = $frames{prj} -> ShowModal;

  if (
      ($result == wxID_CANCEL) or     # cancel button clicked
      ($frames{prj}->{record} == -1)  # import button without selecting a group
     ) {
    $frames{main}->{statusbar}->SetStatusText("Data import cancelled.");
    return;
  };

  my $data = $frames{prj}->{prj}->record($frames{prj}->{record});
  my ($dnum, $idata) = make_data_frame($frames{main}, $data);
  $data->po->start_plot;
  $data->plot('k');
  $data->plot_window('k') if $data->po->plot_win;
  $frames{$dnum} -> Show(1);
  $frames{main}->{datatool}->ToggleTool($idata,1);
  delete $frames{prj};
  $demeter->push_mru("athena", $file);
  $frames{main}->{statusbar}->SetStatusText("Imported data \"" . $data->name . "\" from $file.");
};
sub make_data_frame {
  my ($self, $data) = @_;
  my $databar = $self->{datatool};

  my $newtool = $databar -> AddCheckTool(-1, "Show ".$data->name, icon("pixel"), wxNullBitmap, q{}, q{} );
  do_the_size_dance($self);
  my $idata = $newtool->GetId;
  my $dnum = sprintf("data%s", $idata);
  $frames{main}  -> {$dnum."_button"} = $newtool;
  $frames{$dnum}  = Demeter::UI::Artemis::Data->new($self, $nset++);
  $frames{$dnum} -> SetTitle("Artemis [Data] ".$data->name);
  $frames{$dnum} -> SetIcon($icon);
  $frames{$dnum} -> populate($data);
  $frames{$dnum} -> transfer;
  $frames{$dnum} -> {dnum} = $dnum;
  set_happiness_color();
  $frames{$dnum} -> Show(0);
  $databar->ToggleTool($idata,0);
  modified(1);
  return ($dnum, $idata);
};


sub OnFeffClick {
  my ($feffbar, $event, $self) = @_;
  my $which = $feffbar->GetToolPos($event->GetId);

  if ($which == 0) {
    new_feff($self);
  } else {
    my $this = sprintf("feff%s", $event->GetId);
    return if not exists($frames{$this});
    $frames{$this}->Show($feffbar->GetToolState($event->GetId));
  };

};

sub new_feff {
  my ($self) = @_;
  my $feffbar = $self->{fefftool};
  ## also yaml data
  my $fd = Wx::FileDialog->new( $self, "Import crystal or Feff data", cwd, q{},
				"input and CIF files (*.inp;*.cif)|*.inp;*.cif|input file (*.inp)|*.inp|CIF file (*.cif)|*.cif|All files|*.*",
				wxFD_OPEN|wxFD_FILE_MUST_EXIST|wxFD_CHANGE_DIR|wxFD_PREVIEW,
				wxDefaultPosition);
  if ($fd->ShowModal == wxID_CANCEL) {
    $self->{statusbar}->SetStatusText("Crystal/Feff data import cancelled.");
    return;
  };
  my $file = File::Spec->catfile($fd->GetDirectory, $fd->GetFilename);

  my ($fnum, $ifeff) = make_feff_frame($self, $file);
  $frames{$fnum} -> Show(1);
  $frames{$fnum}->{statusbar}->SetStatusText("Imported crystal data from " . basename($file));
  $feffbar->ToggleTool($ifeff,1);
};

sub make_feff_frame {
  my ($self, $file, $name, $feffobject) = @_;
  my $feffbar = $self->{fefftool};
  $name ||= basename($file);	# ok for importing an atoms or CIF file

  my $newtool = $feffbar -> AddCheckTool(-1, "Show $name", icon("pixel"), wxNullBitmap, q{}, q{} );
  do_the_size_dance($self);
  my $ifeff = $newtool->GetId;
  my $fnum = sprintf("feff%s", $ifeff);
  my $base = File::Spec->catfile($self->{project_folder}, 'feff');
  $frames{$fnum} =  Demeter::UI::AtomsApp->new($base, $feffobject, 1);
  $frames{$fnum} -> SetTitle('Artemis [Feff] Atoms and Feff');
  $frames{$fnum} -> SetIcon($icon);
  $frames{$fnum}->{Atoms}->Demeter::UI::Atoms::Xtal::open_file($file);
  #$newtool -> SetLabel( $frames{$fnum}->{Atoms}->{name}->GetValue );
  $frames{$fnum} -> {fnum} = $fnum;

  EVT_CLOSE($frames{$fnum}, sub{  $frames{$fnum}->Show(0);
				  $frames{main}->{fefftool}->ToggleTool($ifeff, 0);
				});

  $frames{$fnum} -> Show(0);
  $feffbar->ToggleTool($ifeff,0);
  modified(1);

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
  my $fefftool = $frames{main}->{fefftool};
  $fefftool->DeleteTool($id);

  ## remove the frame with the feff calculation
  $frames{$fnum}->Hide;
  $frames{$fnum}->Destroy;
  delete $frames{$fnum};

  ## destroy the ScatteringPath object
  ## destroy the feff object
  $feffobject->DESTROY;
}

sub export {
  my ($rframes, $how) = @_;

  ## make a disposable Fit objkect
  my ($abort, $rdata, $rpaths) = uptodate($rframes);
  my $rgds = $rframes->{GDS}->reset_all;
  my @data  = @$rdata;
  my @paths = @$rpaths;
  my @gds   = @$rgds;
  if ($abort) {
    $rframes->{main}->{statusbar}->SetStatusText("There is a problem in your fit.");
    return;
  };
  my $fit = Demeter::Fit->new(data => \@data, paths => \@paths, gds => \@gds);

  my $suffix = ($how eq 'ifeffit') ? 'iff' : 'pl';
  ## prompt for a filename
  my $fd = Wx::FileDialog->new( $rframes->{main}, "Export this fitting model", cwd, "artemis.$suffix",
				"fitting scripts (*.$suffix)|*.$suffix|All files|*.*",
				wxFD_SAVE|wxFD_CHANGE_DIR|wxFD_OVERWRITE_PROMPT,
				wxDefaultPosition);
  if ($fd->ShowModal == wxID_CANCEL) {
    $rframes->{main}->{statusbar}->SetStatusText("Exporting fitting model cancelled.");
    return;
  };
  my $fname = File::Spec->catfile($fd->GetDirectory, $fd->GetFilename);
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

  ## do the fit, this writing the script file
  $fit -> fit;

  ## restore mode settings
  $fit -> mo -> set(zip(@modes, @values));

  undef $fit;

};


1;


=head1 NAME

Demeter::UI::Artemis - EXAFS analysis using Feff and Ifeffit

=head1 VERSION

This documentation refers to Demeter version 0.3.

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

blah blah

=back

Please report problems to Bruce Ravel (bravel AT bnl DOT gov)

Patches are welcome.

=head1 AUTHOR

Bruce Ravel (bravel AT bnl DOT gov)

L<http://cars9.uchicago.edu/~ravel/software/>

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2009 Bruce Ravel (bravel AT bnl DOT gov). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
