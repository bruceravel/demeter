package Demeter::UI::Athena;

use Demeter; # qw(:plotwith=gnuplot);
use Demeter::UI::Wx::MRU;
use Demeter::UI::Wx::SpecialCharacters qw(:all);
use Demeter::UI::Athena::IO;
use Demeter::UI::Athena::Group;
use Demeter::UI::Athena::Replot;

use Demeter::UI::Artemis::Buffer;
use Demeter::UI::Artemis::ShowText;
use Demeter::UI::Athena::Status;

use vars qw($demeter $buffer $plotbuffer);
$demeter = Demeter->new;
$demeter->set_mode(ifeffit=>1, screen=>0);
$demeter->mo->silently_ignore_unplottable(1);

use Cwd;
use File::Basename;
use File::Copy;
use File::Path;
use File::Spec;
use List::MoreUtils qw(any);
use Readonly;
use Scalar::Util qw{looks_like_number};

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
  $demeter -> mo -> iwd(cwd);

  my $conffile = File::Spec->catfile(dirname($INC{'Demeter/UI/Athena.pm'}), 'Athena', 'share', "athena.demeter_conf");
  $demeter -> co -> read_config($conffile);
  $demeter -> co -> read_ini('athena');
  $demeter -> plot_with($demeter->co->default(qw(plot plotwith)));
  my $old_cwd = File::Spec->catfile($demeter->dot_folder, "athena.cwd");
  if (-r $old_cwd) {
    my $yaml = YAML::Tiny::LoadFile($old_cwd);
    chdir($yaml->{cwd});
  };

  ## -------- create a new frame and set icon
  $app->{main} = Wx::Frame->new(undef, -1, 'Athena [XAS data processing] - <untitled>', wxDefaultPosition, wxDefaultSize,);
  my $iconfile = File::Spec->catfile(dirname($INC{'Demeter/UI/Athena.pm'}), 'Athena', 'icons', "athena.png");
  $icon = Wx::Icon->new( $iconfile, wxBITMAP_TYPE_ANY );
  $app->{main} -> SetIcon($icon);
  EVT_CLOSE($app->{main}, sub{$app->on_close($_[1])});

  ## -------- Set up menubar
  $app -> menubar;
  $app -> set_mru();

  ## -------- status bar
  $app->{main}->{statusbar} = $app->{main}->CreateStatusBar;

  ## -------- the business part of the window
  my $hbox = Wx::BoxSizer->new( wxHORIZONTAL );
  $app -> main_window($hbox);
  $app -> side_bar($hbox);

  ## -------- "global" parameters
  $app->{lastplot} = [q{}, q{}];
  $app->{selected} = -1;
  $app->{modified} = 0;
  $app->{main}->{currentproject} = q{};
  $app->{main}->{showing} = q{};
  $app->{constraining_spline_parameters}=0;
  $app->{selecting_data_group}=0;

  ## -------- a few more top-level widget-y things
  $app->{main}->{Status} = Demeter::UI::Athena::Status->new($app->{main});
  $app->{main}->{Status}->SetTitle("Athena [Status Buffer]");
  $app->{Buffer} = Demeter::UI::Artemis::Buffer->new($app->{main});
  $app->{Buffer}->SetTitle("Athena [Ifeffit \& Plot Buffer]");

  $demeter->set_mode(callback     => \&ifeffit_buffer,
		     plotcallback => ($demeter->mo->template_plot eq 'pgplot') ? \&ifeffit_buffer : \&plot_buffer,
		     feedback     => \&feedback,
		    );

  $app->{main} -> SetSizerAndFit($hbox);
  #$app->{main} -> SetSize(600,800);
  $app->{main} -> Show( 1 );
  $app->process_argv(@ARGV);
  $app->{main} -> status("Welcome to Athena (" . $demeter->identify . ")");
  1;
};

sub process_argv {
  my ($app, @args) = @_;
  foreach my $a (@args) {
    if ($a =~ m{\A-\d+\z}) {
      ## take the i^th item from the mru list
    } elsif (-r File::Spec->catfile($demeter->mo->iwd, $a)) {
      print File::Spec->catfile($demeter->mo->iwd, $a), "\n";
      ##$app->Import(File::Spec->catfile($demeter->mo->iwd, $a));
    };
  };
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
  my ($app, $event) = @_;
  if ($app->{modified}) {
    ## offer to save project....
    my $yesno = Wx::MessageDialog->new($app->{main},
				       "Save this project before exiting?",
				       "Save project?",
				       wxYES_NO|wxCANCEL|wxYES_DEFAULT|wxICON_QUESTION);
    my $result = $yesno->ShowModal;
    if ($result == wxID_CANCEL) {
      $app->{main}->status("Not exiting Athena after all.");
      $event->Veto  if defined $event;
      return 0;
    };
    $app -> Export('all', $app->{main}->{currentproject}) if $result == wxID_YES;
  };

#  unlink $app->{main}->{autosave_file};
  my $persist = File::Spec->catfile($demeter->dot_folder, "athena.cwd");
  YAML::Tiny::DumpFile($persist, {cwd=>cwd});
  $demeter->mo->destroy_all;
  $event->Skip(1) if defined $event;
  return 1;
};
sub on_about {
  my ($app) = @_;

  my $info = Wx::AboutDialogInfo->new;

  $info->SetName( 'Athena' );
  #$info->SetVersion( $demeter->version );
  $info->SetDescription( "XAS Data Processing" );
  $info->SetCopyright( $demeter->identify . "\nusing Ifeffit " . Ifeffit::get_string('&build'));
  $info->SetWebSite( 'http://cars9.uchicago.edu/iffwiki/Demeter', 'The Demeter web site' );
  #$info->SetDevelopers( ["Bruce Ravel <bravel\@bnl.gov>\n",
  #			 "Ifeffit is copyright $COPYRIGHT 1992-2010 Matt Newville"
  #			] );
  $info->SetLicense( $demeter->slurp(File::Spec->catfile($athena_base, 'Athena', 'share', "GPL.dem")) );

  Wx::AboutBox( $info );
}

sub is_empty {
  my ($app) = @_;
  return not $app->{main}->{list}->GetCount;
};

sub current_index {
  my ($app) = @_;
  return $app->{main}->{list}->GetSelection;
};
sub current_data {
  my ($app) = @_;
  return $app->{main}->{list}->GetClientData($app->{main}->{list}->GetSelection);
};

Readonly my $SAVE_MARKED  => Wx::NewId();
Readonly my $SAVE_MUE     => Wx::NewId();
Readonly my $SAVE_NORM    => Wx::NewId();
Readonly my $SAVE_CHIK    => Wx::NewId();
Readonly my $SAVE_CHIR    => Wx::NewId();
Readonly my $SAVE_CHIQ    => Wx::NewId();

Readonly my $EACH_MUE     => Wx::NewId();
Readonly my $EACH_NORM    => Wx::NewId();
Readonly my $EACH_CHIK    => Wx::NewId();
Readonly my $EACH_CHIR    => Wx::NewId();
Readonly my $EACH_CHIQ    => Wx::NewId();

Readonly my $MARKED_XMU	  => Wx::NewId();
Readonly my $MARKED_NORM  => Wx::NewId();
Readonly my $MARKED_DER	  => Wx::NewId();
Readonly my $MARKED_NDER  => Wx::NewId();
Readonly my $MARKED_SEC	  => Wx::NewId();
Readonly my $MARKED_NSEC  => Wx::NewId();
Readonly my $MARKED_CHI	  => Wx::NewId();
Readonly my $MARKED_CHIK  => Wx::NewId();
Readonly my $MARKED_CHIK2 => Wx::NewId();
Readonly my $MARKED_CHIK3 => Wx::NewId();
Readonly my $MARKED_RMAG  => Wx::NewId();
Readonly my $MARKED_RRE	  => Wx::NewId();
Readonly my $MARKED_RIM	  => Wx::NewId();
Readonly my $MARKED_RPHA  => Wx::NewId();
Readonly my $MARKED_QMAG  => Wx::NewId();
Readonly my $MARKED_QRE	  => Wx::NewId();
Readonly my $MARKED_QIM	  => Wx::NewId();
Readonly my $MARKED_QPHA  => Wx::NewId();

Readonly my $CLEAR_PROJECT => Wx::NewId();

Readonly my $RENAME	   => Wx::NewId();
Readonly my $COPY	   => Wx::NewId();
Readonly my $REMOVE	   => Wx::NewId();
Readonly my $REMOVE_MARKED => Wx::NewId();
Readonly my $DATA_YAML	   => Wx::NewId();

Readonly my $PLOT_QUAD	  => Wx::NewId();
Readonly my $PLOT_IOSIG	  => Wx::NewId();
Readonly my $PLOT_K123	  => Wx::NewId();
Readonly my $PLOT_R123	  => Wx::NewId();
Readonly my $PLOT_I0MARKED=> Wx::NewId();
Readonly my $PLOT_STDDEV  => Wx::NewId();
Readonly my $PLOT_VARIENCE=> Wx::NewId();

Readonly my $SHOW_BUFFER  => Wx::NewId();
Readonly my $PLOT_YAML	  => Wx::NewId();
Readonly my $MODE_STATUS  => Wx::NewId();
Readonly my $PERL_MODULES => Wx::NewId();
Readonly my $STATUS	  => Wx::NewId();
Readonly my $IFEFFIT_STRINGS => Wx::NewId();
Readonly my $IFEFFIT_GROUPS  => Wx::NewId();
Readonly my $IFEFFIT_ARRAYS  => Wx::NewId();

Readonly my $MARK_ALL      => Wx::NewId();
Readonly my $MARK_NONE     => Wx::NewId();
Readonly my $MARK_INVERT   => Wx::NewId();
Readonly my $MARK_TOGGLE   => Wx::NewId();
Readonly my $MARK_REGEXP   => Wx::NewId();
Readonly my $UNMARK_REGEXP => Wx::NewId();

Readonly my $MERGE_MUE     => Wx::NewId();
Readonly my $MERGE_NORM    => Wx::NewId();
Readonly my $MERGE_CHI     => Wx::NewId();
Readonly my $MERGE_IMP     => Wx::NewId();
Readonly my $MERGE_NOISE   => Wx::NewId();

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

  my $savecurrentmenu = Wx::Menu->new;
  $savecurrentmenu->Append($SAVE_MUE,    "$MU(E)",  "Save $MU(E) from the current group" );
  $savecurrentmenu->Append($SAVE_NORM,   "norm(E)", "Save normalized $MU(E) from the current group" );
  $savecurrentmenu->Append($SAVE_CHIK,   "$CHI(k)", "Save $CHI(k) from the current group" );
  $savecurrentmenu->Append($SAVE_CHIR,   "$CHI(R)", "Save $CHI(R) from the current group" );
  $savecurrentmenu->Append($SAVE_CHIQ,   "$CHI(q)", "Save $CHI(q) from the current group" );

  my $savemarkedmenu = Wx::Menu->new;
  $savemarkedmenu->Append($MARKED_XMU,   "$MU(E)",          "Save marked groups as $MU(E) to a column data file");
  $savemarkedmenu->Append($MARKED_NORM,  "norm(E)",         "Save marked groups as norm(E) to a column data file");
  $savemarkedmenu->Append($MARKED_DER,   "deriv($MU(E))",   "Save marked groups as deriv($MU(E)) to a column data file");
  $savemarkedmenu->Append($MARKED_NDER,  "deriv(norm(E))",  "Save marked groups as deriv(norm(E)) to a column data file");
  $savemarkedmenu->Append($MARKED_SEC,   "second($MU(E))",  "Save marked groups as second($MU(E)) to a column data file");
  $savemarkedmenu->Append($MARKED_NSEC,  "second(norm(E))", "Save marked groups as second(norm(E)) to a column data file");
  $savemarkedmenu->AppendSeparator;
  $savemarkedmenu->Append($MARKED_CHI,   "$CHI(k)",         "Save marked groups as $CHI(k) to a column data file");
  $savemarkedmenu->Append($MARKED_CHIK,  "k$CHI(k)",        "Save marked groups as k$CHI(k) to a column data file");
  $savemarkedmenu->Append($MARKED_CHIK2, "k$TWO$CHI(k)",    "Save marked groups as k$TWO$CHI(k) to a column data file");
  $savemarkedmenu->Append($MARKED_CHIK3, "k$THR$CHI(k)",    "Save marked groups as k$THR$CHI(k) to a column data file");
  $savemarkedmenu->AppendSeparator;
  $savemarkedmenu->Append($MARKED_RMAG,  "|$CHI(R)|",       "Save marked groups as |$CHI(R)| to a column data file");
  $savemarkedmenu->Append($MARKED_RRE,   "Re[$CHI(R)]",     "Save marked groups as Re[$CHI(R)] to a column data file");
  $savemarkedmenu->Append($MARKED_RIM,   "Im[$CHI(R)]",     "Save marked groups as Im[$CHI(R)] to a column data file");
  $savemarkedmenu->Append($MARKED_RPHA,  "Pha[$CHI(R)]",    "Save marked groups as Pha[$CHI(R)] to a column data file");
  $savemarkedmenu->AppendSeparator;
  $savemarkedmenu->Append($MARKED_QMAG,  "|$CHI(q)|",       "Save marked groups as |$CHI(q)| to a column data file");
  $savemarkedmenu->Append($MARKED_QRE,   "Re[$CHI(q)]",     "Save marked groups as Re[$CHI(q)] to a column data file");
  $savemarkedmenu->Append($MARKED_QIM,   "Im[$CHI(q)]",     "Save marked groups as Im[$CHI(q)] to a column data file");
  $savemarkedmenu->Append($MARKED_QPHA,  "Pha[$CHI(q)]",    "Save marked groups as Pha[$CHI(q)] to a column data file");

  my $saveeachmenu   = Wx::Menu->new;
  $saveeachmenu->Append($EACH_MUE,    "$MU(E)",  "Save $MU(E) for each marked group" );
  $saveeachmenu->Append($EACH_NORM,   "norm(E)", "Save normalized $MU(E) for each marked group" );
  $saveeachmenu->Append($EACH_CHIK,   "$CHI(k)", "Save $CHI(k) for each marked group" );
  $saveeachmenu->Append($EACH_CHIR,   "$CHI(R)", "Save $CHI(R) for each marked group" );
  $saveeachmenu->Append($EACH_CHIQ,   "$CHI(q)", "Save $CHI(q) for each marked group" );

  $filemenu->AppendSubMenu($savecurrentmenu, "Save current group as ...",     "Save the data in the current group as a column data file" );
  $filemenu->AppendSubMenu($savemarkedmenu,  "Save marked groups as ...",     "Save the data from the marked group as a column data file" );
  $filemenu->AppendSubMenu($saveeachmenu,    "Save each marked group as ...", "Save the data in the marked group as column data files" );
  $filemenu->AppendSeparator;
  $filemenu->Append($CLEAR_PROJECT, 'Clear project name', 'Clear project name');
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
  $monitormenu->AppendSeparator;
  $monitormenu->Append($IFEFFIT_STRINGS, "Show Ifeffit strings", "Examine all the strings currently defined in Ifeffit");
  $monitormenu->Append($IFEFFIT_GROUPS,  "Show Ifeffit groups",  "Examine all the data groups currently defined in Ifeffit");
  $monitormenu->Append($IFEFFIT_ARRAYS,  "Show Ifeffit arrays",  "Examine all the arrays currently defined in Ifeffit");
  $monitormenu->AppendSeparator;
  $monitormenu->AppendSubMenu($debugmenu, 'Debug options',     'Display debugging tools')
    if ($demeter->co->default("athena", "debug_menus"));


  my $groupmenu   = Wx::Menu->new;
  $groupmenu->Append($RENAME, "Rename current group\tALT+SHIFT+l", "Rename the current group");
  $groupmenu->Append($COPY,   "Copy current group\tALT+SHIFT+y",   "Copy the current group");
  $groupmenu->AppendSeparator;
  $groupmenu->Append($DATA_YAML, "Show structure of current group",  "Show detailed contents of the current data group");
  $groupmenu->AppendSeparator;
  $groupmenu->Append($REMOVE, "Remove current group",   "Remove the current group from this project");
  $groupmenu->Append($REMOVE_MARKED, "Remove marked groups",   "Remove marked groups from this project");
  $groupmenu->Append(wxID_CLOSE, "&Close" );

  my $valuesmenu  = Wx::Menu->new;
  my $plotmenu    = Wx::Menu->new;
  my $currentplotmenu = Wx::Menu->new;
  my $markedplotmenu  = Wx::Menu->new;
  my $mergedplotmenu  = Wx::Menu->new;
  $currentplotmenu->Append($PLOT_QUAD,       "Quad plot",      "Make a quad plot from the current group" );
  $currentplotmenu->Append($PLOT_IOSIG,      "Data+I0+Signal", "Plot data, I0, and signal from the current group" );
  $currentplotmenu->Append($PLOT_K123,       "k123 plot",      "Make a k123 plot from the current group" );
  $currentplotmenu->Append($PLOT_R123,       "R123 plot",      "Make an R123 plot from the current group" );
  $markedplotmenu ->Append($PLOT_I0MARKED,   "Plot I0",        "Plot I0 for each of the marked groups" );
  $mergedplotmenu ->Append($PLOT_STDDEV,     "Plot data + std. dev.", "Plot the merged data along with its standard deviation" );
  $mergedplotmenu ->Append($PLOT_VARIENCE,   "Plot data + variance",  "Plot the merged data along with its scaled variance" );
  $plotmenu->AppendSubMenu($currentplotmenu, "Current group",  "Additional plot types for the current group");
  $plotmenu->AppendSubMenu($markedplotmenu,  "Marked groups",  "Additional plot types for the marked groups");
  $plotmenu->AppendSubMenu($mergedplotmenu,  "Merged groups",  "Additional plot types for the merged data");
  ##$mergedplotmenu->Enable(0,0);

  my $markmenu   = Wx::Menu->new;
  $markmenu->Append($MARK_ALL,      "Mark all\tCTRL+SHIFT+a",            "Mark all groups" );
  $markmenu->Append($MARK_NONE,     "Clear all marks\tCTRL+SHIFT+u",     "Clear all marks" );
  $markmenu->Append($MARK_INVERT,   "Invert marks\tCTRL+SHIFT+i",        "Invert all mark" );
  $markmenu->Append($MARK_TOGGLE,   "Toggle current mark\tCTRL+SHIFT+t", "Toggle mark of current group" );
  $markmenu->Append($MARK_REGEXP,   "Mark by regexp\tCTRL+SHIFT+r",      "Mark all groups matching a regular expression" );
  $markmenu->Append($UNMARK_REGEXP, "Unmark by all\tCTRL+SHIFT+x",       "Unmark all groups matching a regular expression" );

  my $mergemenu  = Wx::Menu->new;
  $mergemenu->Append($MERGE_MUE,  "Merge $MU(E)",  "Merge marked data at $MU(E)" );
  $mergemenu->Append($MERGE_NORM, "Merge norm(E)", "Merge marked data at normalized $MU(E)" );
  $mergemenu->Append($MERGE_CHI,  "Merge $CHI(k)", "Merge marked data at $CHI(k)" );
  $mergemenu->AppendSeparator;
  $mergemenu->AppendRadioItem($MERGE_IMP,   "Weight by importance",       "Weight the marked groups by their importance values when merging" );
  $mergemenu->AppendRadioItem($MERGE_NOISE, "Weight by noise in $CHI(k)", "Weight the marked groups by their $CHI(k) noise values when merging" );


  my $helpmenu   = Wx::Menu->new;
  $helpmenu->Append(wxID_ABOUT, "&About..." );

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
      $app -> Import($mru);
      last SWITCH;
    };
    ($id == wxID_ABOUT) and do {
      &on_about;
      last SWITCH;
    };
    ($id == $CLEAR_PROJECT) and do {
      $app->Clear;
      last SWITCH;
    };

    ($id == wxID_CLOSE) and do {
      $app->Remove('all');
      last SWITCH;
    };
    ($id == wxID_EXIT) and do {
      my $ok = $app->on_close;
      return if not $ok;
      $self->Close;
      return;
    };
    ($id == wxID_OPEN) and do {
      $app -> Import();
      last SWITCH;
    };
    ($id == wxID_SAVE) and do {
      $app -> Export('all', $app->{main}->{currentproject});
      last SWITCH;
    };
    ($id == wxID_SAVEAS) and do {
      $app -> Export('all');
      last SWITCH;
    };
    ($id == $SAVE_MARKED) and do {
      $app -> Export('marked');
      last SWITCH;
    };

    (any {$id == $_} ($SAVE_MUE, $SAVE_NORM, $SAVE_CHIK, $SAVE_CHIR, $SAVE_CHIQ)) and do {
      my $how = ($id == $SAVE_MUE)  ? 'mue'
	      : ($id == $SAVE_NORM) ? 'norm'
	      : ($id == $SAVE_CHIK) ? 'chik'
	      : ($id == $SAVE_CHIR) ? 'chir'
	      : ($id == $SAVE_CHIQ) ? 'chiq'
	      :                       '???';
      $app->save_column($how);
      last SWITCH;
    };

    (any {$id == $_} ($MARKED_XMU,  $MARKED_NORM, $MARKED_DER,  $MARKED_NDER,  $MARKED_SEC,
		      $MARKED_NSEC, $MARKED_CHI,  $MARKED_CHIK, $MARKED_CHIK2, $MARKED_CHIK3,
		      $MARKED_RMAG, $MARKED_RRE,  $MARKED_RIM,  $MARKED_RPHA,  $MARKED_QMAG,
		      $MARKED_QRE,  $MARKED_QIM,  $MARKED_QPHA))
      and do {
	my $how = ($id == $MARKED_XMU)   ? "xmu"
	        : ($id == $MARKED_NORM)  ? "norm"
 	        : ($id == $MARKED_DER)   ? "der"
	        : ($id == $MARKED_NDER)  ? "nder"
	        : ($id == $MARKED_SEC)   ? "sec"
	        : ($id == $MARKED_NSEC)  ? "nsec"
	        : ($id == $MARKED_CHI)   ? "chi"
	        : ($id == $MARKED_CHIK)  ? "chik"
	        : ($id == $MARKED_CHIK2) ? "chik2"
	        : ($id == $MARKED_CHIK3) ? "chik3"
	        : ($id == $MARKED_RMAG)  ? "chir_mag"
	        : ($id == $MARKED_RRE)   ? "chir_re"
	        : ($id == $MARKED_RIM)   ? "chir_im"
	        : ($id == $MARKED_RPHA)  ? "chir_pha"
	        : ($id == $MARKED_QMAG)  ? "chiq_mag"
	        : ($id == $MARKED_QRE)   ? "chiq_re"
	        : ($id == $MARKED_QIM)   ? "chiq_im"
	        : ($id == $MARKED_QPHA)  ? "chiq_pha"
		:                          '???';
	$app->save_marked($how);
	last SWITCH;
      };

    (any {$id == $_} ($EACH_MUE, $EACH_NORM, $EACH_CHIK, $EACH_CHIR, $EACH_CHIQ)) and do {
      my $how = ($id == $EACH_MUE)  ? 'mue'
	      : ($id == $EACH_NORM) ? 'norm'
	      : ($id == $EACH_CHIK) ? 'chik'
	      : ($id == $EACH_CHIR) ? 'chir'
	      : ($id == $EACH_CHIQ) ? 'chiq'
	      :                       '???';
      $app->save_each($how);
      last SWITCH;
    };

    ## -------- group menu
    ($id == $RENAME) and do {
      $app->Rename;
      last SWITCH;
    };
    ($id == $COPY) and do {
      $app->Copy;
      last SWITCH;
    };
    ($id == $REMOVE) and do {
      $app->Remove('current');
      last SWITCH;
    };
    ($id == $REMOVE_MARKED) and do {
      $app->Remove('marked');
      last SWITCH;
    };
    ($id == $DATA_YAML) and do {
      last SWITCH if $app->is_empty;
      my $dialog = Demeter::UI::Artemis::ShowText
	-> new($app->{main}, $app->current_data->serialization, 'Structure of Data object')
	  -> Show;
      last SWITCH;
    };

    ## -------- merge menu
    ($id == $MERGE_MUE) and do {
      $app->merge('e');
      last SWITCH;
    };
    ($id == $MERGE_NORM) and do {
      $app->merge('n');
      last SWITCH;
    };
    ($id == $MERGE_CHI) and do {
      $app->merge('k');
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
    ($id == $IFEFFIT_STRINGS) and do {
      $demeter->dispose('show @strings');
      $app->{Buffer}->{iffcommands}->ShowPosition($app->{Buffer}->{iffcommands}->GetLastPosition);
      $app->{Buffer}->Show(1);
      last SWITCH;
    };
    ($id == $IFEFFIT_GROUPS) and do {
      $demeter->dispose('show @groups');
      $app->{Buffer}->{iffcommands}->ShowPosition($app->{Buffer}->{iffcommands}->GetLastPosition);
      $app->{Buffer}->Show(1);
      last SWITCH;
    };
    ($id == $IFEFFIT_ARRAYS) and do {
      $demeter->dispose('show @arrays');
      $app->{Buffer}->{iffcommands}->ShowPosition($app->{Buffer}->{iffcommands}->GetLastPosition);
      $app->{Buffer}->Show(1);
      last SWITCH;
    };
    ## -------- debug submenu
    ($id == $PLOT_YAML) and do {
      $app->{main}->{PlotE}->pull_single_values;
      $app->{main}->{PlotK}->pull_single_values;
      $app->{main}->{PlotR}->pull_marked_values;
      $app->{main}->{PlotQ}->pull_marked_values;
      my $dialog = Demeter::UI::Artemis::ShowText
	-> new($app->{main}, $demeter->po->serialization, 'YAML of Plot object')
	  -> Show;
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
      my $data = $app->current_data;
      $app->{main}->{Main}->pull_values($data);
      $data->po->start_plot;
      $app->quadplot($data);
      last SWITCH;
    };
    ($id == $PLOT_IOSIG) and do {
      my $data = $app->current_data;
      $app->{main}->{Main}->pull_values($data);
      $app->{main}->{PlotE}->pull_single_values;
      $data->po->set(e_bkg=>0, e_pre=>0, e_post=>0, e_norm=>0, e_der=>0, e_sec=>0);
      $data->po->set(e_mu=>1, e_i0=>1, e_signal=>1);
      $data->po->start_plot;
      $data->plot('E');
      $data->po->set(e_i0=>0, e_signal=>0);
      $app->{main}->{plottabs}->SetSelection(0);
      last SWITCH;
    };
    ($id == $PLOT_K123) and do {
      my $data = $app->current_data;
      $app->{main}->{Main}->pull_values($data);
      $app->{main}->{PlotK}->pull_single_values;
      $data->po->start_plot;
      $data->plot('k123');
      $app->{main}->{plottabs}->SetSelection(1);
      last SWITCH;
    };
    ($id == $PLOT_R123) and do {
      my $data = $app->current_data;
      $app->{main}->{Main}->pull_values($data);
      $app->{main}->{PlotR}->pull_marked_values;
      $data->po->start_plot;
      $data->plot('R123');
      $app->{main}->{plottabs}->SetSelection(2);
      last SWITCH;
    };
    ($id == $PLOT_STDDEV) and do {
      my $data = $app->current_data;
      last SWITCH if not $data->is_merge;
      $data->plot('stddev');
      last SWITCH;
    };
    ($id == $PLOT_VARIENCE) and do {
      my $data = $app->current_data;
      last SWITCH if not $data->is_merge;
      $data->plot('variance');
      last SWITCH;
    };

    ($id == $MARK_ALL) and do {
      $app->mark('all');
      last SWITCH;
    };
    ($id == $MARK_NONE) and do {
      $app->mark('none');
      last SWITCH;
    };
    ($id == $MARK_INVERT) and do {
      $app->mark('invert');
      last SWITCH;
    };
    ($id == $MARK_TOGGLE) and do {
      $app->mark('toggle');
      last SWITCH;
    };
    ($id == $MARK_REGEXP) and do {
      $app->mark('regexp');
      last SWITCH;
    };
    ($id == $UNMARK_REGEXP) and do {
      $app->mark('unmark_regexp');
      last SWITCH;
    };


    ($id == wxID_ABOUT) and do {
      $app->on_about;
      return;
    };

  };
};


sub main_window {
  my ($app, $hbox) = @_;

  my $viewpanel = Wx::Panel    -> new($app->{main}, -1);
  my $viewbox   = Wx::BoxSizer -> new( wxVERTICAL );
  $hbox        -> Add($viewpanel, 0, wxGROW|wxALL, 5);


  my $topbar = Wx::BoxSizer->new( wxHORIZONTAL );
  $viewbox -> Add($topbar, 0, wxGROW|wxALL, 0);

  $app->{main}->{project} = Wx::StaticText->new($viewpanel, -1, q{<untitled>},);
  my $size = Wx::SystemSettings::GetFont(wxSYS_DEFAULT_GUI_FONT)->GetPointSize + 2;
  $app->{main}->{project}->SetFont( Wx::Font->new( $size, wxDEFAULT, wxNORMAL, wxBOLD, 0, "" ) );
  $topbar -> Add($app->{main}->{project}, 0, wxGROW|wxALL, 5);

  $topbar -> Add(1,1,1);

  $app->{main}->{save}   = Wx::Button->new($viewpanel, wxID_SAVE, q{},  wxDefaultPosition, wxDefaultSize, wxBU_EXACTFIT);
  $app->{main}->{all}    = Wx::Button->new($viewpanel, -1,        q{A}, wxDefaultPosition, wxDefaultSize, wxBU_EXACTFIT);
  $app->{main}->{none}   = Wx::Button->new($viewpanel, -1,        q{U}, wxDefaultPosition, wxDefaultSize, wxBU_EXACTFIT);
  $app->{main}->{invert} = Wx::Button->new($viewpanel, -1,        q{I}, wxDefaultPosition, wxDefaultSize, wxBU_EXACTFIT);
  $topbar -> Add($app->{main}->{save},   0, wxGROW|wxTOP|wxBOTTOM, 5);
  $topbar -> Add($app->{main}->{all},    0, wxGROW|wxTOP|wxBOTTOM, 5);
  $topbar -> Add($app->{main}->{none},   0, wxGROW|wxTOP|wxBOTTOM, 5);
  $topbar -> Add($app->{main}->{invert}, 0, wxGROW|wxTOP|wxBOTTOM, 5);
  $app->{main}->{save} -> Enable(0);
  $app->EVT_BUTTON($app->{main}->{save},   sub{$app -> Export('all', $app->{main}->{currentproject})});
  $app->EVT_BUTTON($app->{main}->{all},    sub{$app->mark('all')});
  $app->EVT_BUTTON($app->{main}->{none},   sub{$app->mark('none')});
  $app->EVT_BUTTON($app->{main}->{invert}, sub{$app->mark('invert')});
  $app->mouseover($app->{main}->{save},   "One-click-save your project");
  $app->mouseover($app->{main}->{all},    "Mark all groups");
  $app->mouseover($app->{main}->{none},   "Clear all marks");
  $app->mouseover($app->{main}->{invert}, "Invert all marks");



  $app->{main}->{views} = Wx::Choicebook->new($viewpanel, -1);
  $viewbox -> Add($app->{main}->{views}, 0, wxALL, 5);
  #print join("|", $app->{main}->{views}->GetChildren), $/;
  $app->mouseover($app->{main}->{views}->GetChildren, "Change data processing and analysis tools using this menu.");

  foreach my $which (qw(Main Calibrate Journal Prefs)) {
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
  #print("same!\n"), return if ($was eq $is);
  #  print join("|", $parent, $event, $is_index, $is, $was), $/;
  $app->{selecting_data_group}=1;

  if ($was) {
    $app->{main}->{Main}->pull_values($was);
  };
  if ($is_index != -1) {
    $app->{main}->{Main}->push_values($is);
    $app->{main}->{Main}->mode($is, 1, 0);
    $app->{selected} = $app->{main}->{list}->GetSelection;
  };
  $app->{selecting_data_group}=0;
};

sub view_changing {
  my ($app, $frame, $event) = @_;
  my $ngroups = $app->{main}->{list}->GetCount;
  my $nviews  = $app->{main}->{views}->GetPageCount;
  #print join("|", $app, $event, $ngroups, $event->GetSelection), $/;

  if (($event->GetSelection != 0) and ($event->GetSelection < $nviews-2)) {
    if (not $ngroups) {
      $app->{main}->status(sprintf("You have no data imported in Athena, thus you cannot use the %s tool.",
				   lc($app->{main}->{views}->GetPageText($event->GetSelection))));
      $event -> Veto();
    };
  } else {
    $app->{main}->status(sprintf("Displaying the %s tool.",
				 lc($app->{main}->{views}->GetPageText($event->GetSelection))));
    #$app->{main}->{showing}=
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
  return if $app->is_empty;
  return if not ($space);
  return if not ($how);

  my $busy = Wx::BusyCursor->new();

  my @data = ($how eq 'single') ? ( $app->current_data ) : $app->marked_groups;

  if (not @data and ($how eq 'marked')) {
    $app->{main}->status("No groups are marked.  Marked plot cancelled.");
    return;
  };

  $app->{main}->{Main}->pull_values($app->current_data);
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


my %mark_feeedback = (all	    => "Marked all groups.",
		      none	    => "Cleared all marks",
		      invert	    => "Inverted all marks",
		      toggle	    => "Toggled mark for current data group",
		      regexp	    => "Marked all groups matching ",
		      unmark_regexp => "Unmarked all groups matching ",);
sub mark {
  my ($app, $how) = @_;
  my $clb = $app->{main}->{list};
  return if not $clb->GetCount;

  my $regex = q{};
  if ($how eq 'toggle') {
    $clb->Check($clb->GetSelection, not $clb->IsChecked($clb->GetSelection));
    return;

  } elsif ($how =~ m{all|none|invert}) {
    foreach my $i (0 .. $clb->GetCount-1) {
      my $val = ($how eq 'all')    ? 1
	      : ($how eq 'none')   ? 0
	      : ($how eq 'invert') ? not $clb->IsChecked($i)
	      :                     $clb->IsChecked($i);
      $clb->Check($i, $val);
    };

  } else {			# regexp mark or unmark
    my $word = ($how eq 'regexp') ? 'Mark' : 'Unmark';
    my $ted = Wx::TextEntryDialog->new( $app->{main}, "$word data groups matching this regular expression:", "Enter a regular expression", q{}, wxOK|wxCANCEL, Wx::GetMousePosition);
    if ($ted->ShowModal == wxID_CANCEL) {
      $app->{main}->status($word."ing by regular expression cancelled.");
      return;
    };
    $regex = $ted->GetValue;
    my $re;
    my $is_ok = eval '$re = qr/$regex/';
    if (not $is_ok) {
      $app->{main}->status("Oops!  \"$regex\" is not a valid regular expression");
      return;
    };
    foreach my $i (0 .. $clb->GetCount-1) {
      next if ($clb->GetClientData($i)->name !~ m{$re});
      my $val = ($how eq 'regexp') ? 1 : 0;
      $clb->Check($i, $val);
    };
  };
  $app->{main}->status($mark_feeedback{$how}.$regex);
};


sub merge {
  my ($app, $how) = @_;
  return if $app->is_empty;
  my $busy = Wx::BusyCursor->new();
  my @data = ();
  my $max = 0;
  foreach my $i (0 .. $app->{main}->{list}->GetCount-1) {
    my $this = $app->{main}->{list}->GetClientData($i);
    if ($this->name =~ m{\A\s*merge\s*(\d*)\s*\z}) {
      $max = $1 if (looks_like_number($1) and ($1 > $max));
      $max ||= 1;
    };
    push(@data, $this) if $app->{main}->{list}->IsChecked($i);
  };
  if (not @data) {
    $app->{main}->status("No groups are marked.  Merge cancelled.");
    return;
  };

  my $merged = $data[0]->merge($how, @data);
  $max = q{} if not $max;
  $max = sprintf(" %d", $max+1) if $max;
  $merged->name('merge'.$max);
  $app->{main}->{list}->Append($merged->name, $merged);
  $app->{main}->{list}->SetSelection($app->{main}->{list}->GetCount-1);
  $app->OnGroupSelect(q{}, $app->{main}->{list}->GetSelection);
  $app->{main}->{Main}->mode($merged, 1, 0);
  $app->{main}->{list}->Check($app->{main}->{list}->GetCount-1, 1);
  $app->modified(1);

  ## handle plotting, respecting the choice in the athena->merge_plot config parameter
  my $plot = $merged->co->default('athena', 'merge_plot');
  if ($plot =~ m{stddev|variance}) {
    $app->{main}->{PlotE}->pull_single_values;
    $app->{main}->{PlotK}->pull_single_values;
    $merged->plot($plot);
  } elsif (($plot eq 'marked') and ($how =~ m{\A[en]\z})) {
    $app->{main}->{PlotE}->pull_single_values;
    $merged->po->set(e_mu=>1, e_bkg=>0, e_pre=>0, e_post=>0, e_norm=>0, e_der=>0, e_sec=>0, e_markers=>0, e_i0=>0, e_signal=>0);
    $merged->po->set(e_norm=>1) if ($how eq 'n');
    $merged->po->start_plot;
    $_->plot('e') foreach (@data, $merged);
  } elsif (($plot eq 'marked') and ($how eq 'k')) {
    $app->{main}->{PlotK}->pull_single_values;
    $merged->po->chie(0);
    $merged->po->start_plot;
    $_->plot('k') foreach (@data, $merged);
  };
  $merged->po->e_markers(1);
  undef $busy;
  $app->{main}->status("Made merged data group");
};

sub modified {
  my ($app, $is_modified) = @_;
  $app->{modified} = $is_modified;
  $app->{main}->{save}->Enable($is_modified);
  my $projname = $app->{main}->{project}->GetLabel;
  return if ($projname eq '<untitled>');
  $projname = substr($projname, 1) if ($projname =~ m{\A\*});
  $projname = '*'.$projname if ($is_modified);
  $app->{main}->{project}->SetLabel($projname);
};

sub Clear {
  my ($app) = @_;
  $app->{main}->{currentproject} = q{};
  $app->{main}->{project}->SetLabel('<untitled>');
  $app->{main}->status(sprintf("Unamed the current project."));
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
