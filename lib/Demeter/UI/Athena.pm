package Demeter::UI::Athena;

use feature "switch";

use Demeter qw(:athena);
#use Demeter::UI::Wx::DFrame;
use Demeter::UI::Wx::MRU;
use Demeter::UI::Wx::SpecialCharacters qw(:all);
use Demeter::UI::Wx::VerbDialog;
use Demeter::UI::Athena::IO;
use Demeter::UI::Athena::Group;
use Demeter::UI::Athena::TextBuffer;
use Demeter::UI::Athena::Replot;
use Demeter::UI::Athena::GroupList;

use Demeter::UI::Artemis::Buffer;
use Demeter::UI::Artemis::ShowText;
use Demeter::UI::Athena::Cursor;
use Demeter::UI::Athena::Status;
use Demeter::UI::Artemis::DND::PlotListDrag;

use vars qw($demeter $buffer $plotbuffer);

use Cwd;
use File::Basename;
use File::Copy;
use File::Path;
use File::Spec;
use List::Util qw(min max);
use List::MoreUtils qw(any);
use Time::HiRes qw(usleep);
use Const::Fast;
const my $FOCUS_UP	       => Wx::NewId();
const my $FOCUS_DOWN	       => Wx::NewId();
const my $MOVE_UP	       => Wx::NewId();
const my $MOVE_DOWN	       => Wx::NewId();
const my $AUTOSAVE_FILE     => 'Athena.autosave';
use Demeter::Constants qw($EPSILON2);

use Scalar::Util qw{looks_like_number};

use Wx qw(:everything);
use Wx::Event qw(EVT_MENU EVT_CLOSE EVT_TOOL_ENTER EVT_CHECKBOX EVT_BUTTON
		 EVT_ENTER_WINDOW EVT_LEAVE_WINDOW
		 EVT_RIGHT_UP EVT_LISTBOX EVT_RADIOBOX EVT_LISTBOX_DCLICK
		 EVT_CHOICEBOOK_PAGE_CHANGED EVT_CHOICEBOOK_PAGE_CHANGING
		 EVT_RIGHT_DOWN EVT_LEFT_DOWN EVT_CHECKLISTBOX
	       );
use base 'Wx::App';

use Wx::Perl::Carp qw(verbose);
$SIG{__WARN__} = sub {Wx::Perl::Carp::warn($_[0])};
$SIG{__DIE__}  = sub {Wx::Perl::Carp::warn($_[0])};
#Demeter->meta->add_method( 'confess' => \&Wx::Perl::Carp::warn );
#Demeter->meta->add_method( 'croak'   => \&Wx::Perl::Carp::warn );


sub identify_self {
  my @caller = caller;
  return dirname($caller[1]);
};
use vars qw($athena_base $icon $noautosave %frames);
$athena_base = identify_self();
$noautosave = 0;		# set this to skip autosave, see Demeter::UI::Artemis::Import::_feffit

sub OnInit {
  my ($app) = @_;
  local $|=1;
  #print DateTime->now, "  Initializing Demeter ...\n";
  $demeter = Demeter->new;
  $demeter->set_mode(backend=>1, screen=>0);
  $demeter->mo->silently_ignore_unplottable(1);
  $demeter -> mo -> ui('Wx');
  $demeter -> mo -> identity('Athena');
  $demeter -> mo -> iwd(cwd);


  $demeter -> plot_with($demeter->co->default(qw(plot plotwith)));
  my $old_cwd = File::Spec->catfile($demeter->dot_folder, "athena.cwd");
  if (-r $old_cwd) {
    my $yaml = YAML::Tiny::LoadFile($old_cwd);
    chdir($yaml->{cwd});
  };

  ## -------- create a new frame and set icon
  #print DateTime->now,  "  Making main frame ...\n";
  $app->{main} = Wx::Frame->new(undef, -1, 'Athena [XAS data processing]', wxDefaultPosition, wxDefaultSize,);
  my $iconfile = File::Spec->catfile(dirname($INC{'Demeter/UI/Athena.pm'}), 'Athena', 'icons', "athena.png");
  $icon = Wx::Icon->new( $iconfile, wxBITMAP_TYPE_ANY );
  $app->{main} -> SetIcon($icon);
  EVT_CLOSE($app->{main}, sub{$app->on_close($_[1])});

  ## -------- Set up menubar
  #print DateTime->now,  "  Making menubar and status bar...\n";
  $app -> menubar;
  $app -> set_mru();

  ## -------- status bar
  $app->{main}->{statusbar} = $app->{main}->CreateStatusBar;

  ## -------- the business part of the window
  my $hbox = Wx::BoxSizer->new( wxHORIZONTAL );
  #print DateTime->now,  "  Making main window ...\n";
  $app -> main_window($hbox);
  #print DateTime->now,  "  Making side bar ...\n";
  $app -> side_bar($hbox);

  my $accelerator = Wx::AcceleratorTable->new(
   					      [wxACCEL_CTRL, 107, $FOCUS_UP],
   					      [wxACCEL_CTRL, 106, $FOCUS_DOWN],
   					      [wxACCEL_ALT,  107, $MOVE_UP],
   					      [wxACCEL_ALT,  106, $MOVE_DOWN],
   					     );
  $app->{main}->SetAcceleratorTable( $accelerator );



  ## -------- "global" parameters
  #print DateTime->now,  "  Finishing ...\n";
  $app->{lastplot} = [q{}, q{single}];
  $app->{plotting} = 0;
  $app->{selected} = -1;
  $app->{modified} = 0;
  $app->{most_recent} = 0;
  $app->{main}->{currentproject} = q{};
  $app->{main}->{showing} = q{};
  $app->{constraining_spline_parameters}=0;
  $app->{selecting_data_group}=0;
  $app->{update_kweights}=1;

  ## -------- text buffers for various TextEntryDialogs
  $app->{rename_buffer}  = [];
  $app->{rename_pointer} = -1;
  $app->{regexp_buffer}  = [];
  $app->{regexp_pointer} = -1;
  $app->{style_buffer}   = [];
  $app->{style_pointer}  = -1;

  ## -------- a few more top-level widget-y things
  $app->{main}->{Status} = Demeter::UI::Athena::Status->new($app->{main});
  $app->{main}->{Status}->SetTitle("Athena [Status Buffer]");
  $app->{Buffer} = Demeter::UI::Artemis::Buffer->new($app->{main});
  $app->{Buffer}->SetTitle("Athena [".Demeter->backend_name." \& Plot Buffer]");

  $demeter->set_mode(callback     => \&ifeffit_buffer,
		     plotcallback => ($demeter->mo->template_plot eq 'pgplot') ? \&ifeffit_buffer : \&plot_buffer,
		     feedback     => \&feedback,
		    );

  $app->{main} -> SetSizerAndFit($hbox);
  $app->{main} ->{return}->Show;
  #$app->{main} -> SetSize(600,800);
  $app->{main} -> Show( 1 );
  $app->{main} -> Refresh;
  $app->{main} -> Update;
  $app->{main} -> status("Welcome to Athena $MDASH " . Demeter->identify . " $MDASH " . Demeter->backends);
  $app->OnGroupSelect(q{}, $app->{main}->{list}->GetSelection, 0);
  $app->{main} ->{return}->Hide;
  1;
};

sub process_argv {
  my ($app, @args) = @_;
  if (-r File::Spec->catfile($demeter->stash_folder, $AUTOSAVE_FILE)) {
    my $yesno = Demeter::UI::Wx::VerbDialog->new($app->{main}, -1,
						 "Athena found an autosave file.  Would you like to import it?",
						 "Import autosave?",
						 "Import");
    my $result = $yesno->ShowModal;
    if ($result == wxID_YES) {
      $app->Import(File::Spec->catfile($demeter->stash_folder, $AUTOSAVE_FILE));
    };
    $app->Clear;
    #unlink File::Spec->catfile($demeter->stash_folder, $AUTOSAVE_FILE);
    my $old_cwd = File::Spec->catfile($demeter->dot_folder, "athena.cwd");
    if (-r $old_cwd) {
      my $yaml = YAML::Tiny::LoadFile($old_cwd);
      chdir($yaml->{cwd});
    };
    return;
  };
  foreach my $a (@args) {
    if ($a =~ m{\A-(\d+)\z}) {
      my @list = $demeter->get_mru_list('xasdata');
      my $i = $1-1;
      #print  $list[$i]->[0], $/;
      $app->Import($list[$i]->[0]);
    } elsif (-r $a) {
      $app -> Import($a);
    } elsif (-r File::Spec->catfile($demeter->mo->iwd, $a)) {
      $app->Import(File::Spec->catfile($demeter->mo->iwd, $a));
    }; # switches?
  };
};


sub ifeffit_buffer {
  my ($text) = @_;
  #return if not defined($::app->{Buffer});
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
  my $sb = $app->{main}->GetStatusBar;
  EVT_ENTER_WINDOW($widget, sub{$sb->PushStatusText($text); $_[1]->Skip});
  EVT_LEAVE_WINDOW($widget, sub{$sb->PopStatusText if ($sb->GetStatusText eq $text); $_[1]->Skip});
};


sub on_close {
  my ($app, $event) = @_;
  if ($app->{modified}) {
    ## offer to save project....
    my $yesno = Demeter::UI::Wx::VerbDialog->new($app->{main}, -1,
						 "Save this project before exiting?",
						 "Save project?",
						 "Save", 1);
    my $result = $yesno->ShowModal;
    if ($result == wxID_CANCEL) {
      $app->{main}->status("Not exiting Athena after all.");
      $event->Veto  if defined $event;
      return 0;
    };
    $app -> Export('all', $app->{main}->{currentproject}) if $result == wxID_YES;
  };

  unlink File::Spec->catfile($demeter->stash_folder, $AUTOSAVE_FILE);
  my $persist = File::Spec->catfile($demeter->dot_folder, "athena.cwd");
  YAML::Tiny::DumpFile($persist, {cwd=>cwd . Demeter->slash});
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
  $info->SetCopyright( $demeter->identify . "\nusing " . $demeter->backend_id );
  $info->SetWebSite( 'http://cars9.uchicago.edu/iffwiki/Demeter', 'The Demeter web site' );
  #$info->SetDevelopers( ["Bruce Ravel <bravel\@bnl.gov>\n",
  #			 "Ifeffit is copyright $COPYRIGHT 1992-2013 Matt Newville"
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
  return $demeter->dd if not defined $app->{main}->{list};
  return $demeter->dd if not $app->{main}->{list}->GetCount;
  return $app->{main}->{list}->GetIndexedData($app->{main}->{list}->GetSelection);
};

const my $REPORT_ALL		=> Wx::NewId();
const my $REPORT_MARKED		=> Wx::NewId();
const my $XFIT			=> Wx::NewId();
const my $FPATH			=> Wx::NewId();

const my $SAVE_MARKED		=> Wx::NewId();
const my $SAVE_MUE		=> Wx::NewId();
const my $SAVE_NORM		=> Wx::NewId();
const my $SAVE_CHIK		=> Wx::NewId();
const my $SAVE_CHIR		=> Wx::NewId();
const my $SAVE_CHIQ		=> Wx::NewId();
const my $SAVE_COMPAT		=> Wx::NewId();

const my $EACH_MUE		=> Wx::NewId();
const my $EACH_NORM		=> Wx::NewId();
const my $EACH_CHIK		=> Wx::NewId();
const my $EACH_CHIR		=> Wx::NewId();
const my $EACH_CHIQ		=> Wx::NewId();

const my $MARKED_XMU		=> Wx::NewId();
const my $MARKED_NORM		=> Wx::NewId();
const my $MARKED_DER		=> Wx::NewId();
const my $MARKED_NDER		=> Wx::NewId();
const my $MARKED_SEC		=> Wx::NewId();
const my $MARKED_NSEC		=> Wx::NewId();
const my $MARKED_CHI		=> Wx::NewId();
const my $MARKED_CHIK		=> Wx::NewId();
const my $MARKED_CHIK2		=> Wx::NewId();
const my $MARKED_CHIK3		=> Wx::NewId();
const my $MARKED_RMAG		=> Wx::NewId();
const my $MARKED_RRE		=> Wx::NewId();
const my $MARKED_RIM		=> Wx::NewId();
const my $MARKED_RPHA		=> Wx::NewId();
const my $MARKED_RDPHA		=> Wx::NewId();
const my $MARKED_QMAG		=> Wx::NewId();
const my $MARKED_QRE		=> Wx::NewId();
const my $MARKED_QIM		=> Wx::NewId();
const my $MARKED_QPHA		=> Wx::NewId();

const my $CLEAR_PROJECT		=> Wx::NewId();

const my $RENAME		=> Wx::NewId();
const my $COPY			=> Wx::NewId();
#const my $COPY_SERIES		=> Wx::NewId();
const my $REMOVE		=> Wx::NewId();
const my $REMOVE_MARKED		=> Wx::NewId();
const my $DATA_ABOUT		=> Wx::NewId();
const my $DATA_YAML		=> Wx::NewId();
const my $DATA_TEXT		=> Wx::NewId();
const my $CHANGE_DATATYPE	=> Wx::NewId();
const my $EPSILON_MARKED	=> Wx::NewId();

const my $VALUES_ALL		=> Wx::NewId();
const my $VALUES_MARKED		=> Wx::NewId();
const my $SHOW_REFERENCE	=> Wx::NewId();
const my $TIE_REFERENCE		=> Wx::NewId();

const my $E0_IFEFFIT_ALL	=> Wx::NewId();
const my $E0_TABULATED_ALL	=> Wx::NewId();
const my $E0_FRACTION_ALL	=> Wx::NewId();
const my $E0_ZERO_ALL	        => Wx::NewId();
const my $E0_DMAX_ALL	        => Wx::NewId();
const my $E0_PEAK_ALL	        => Wx::NewId();
const my $E0_IFEFFIT_MARKED	=> Wx::NewId();
const my $E0_TABULATED_MARKED	=> Wx::NewId();
const my $E0_FRACTION_MARKED	=> Wx::NewId();
const my $E0_ZERO_MARKED        => Wx::NewId();
const my $E0_DMAX_MARKED        => Wx::NewId();
const my $E0_PEAK_MARKED        => Wx::NewId();

const my $WL_THIS               => Wx::NewId();
const my $WL_MARKED             => Wx::NewId();
const my $WL_ALL                => Wx::NewId();

const my $FREEZE_TOGGLE		=> Wx::NewId();
const my $FREEZE_ALL		=> Wx::NewId();
const my $UNFREEZE_ALL		=> Wx::NewId();
const my $FREEZE_MARKED		=> Wx::NewId();
const my $UNFREEZE_MARKED	=> Wx::NewId();
const my $FREEZE_REGEX		=> Wx::NewId();
const my $UNFREEZE_REGEX	=> Wx::NewId();
const my $FREEZE_TOGGLE_ALL	=> Wx::NewId();
const my $FREEZE_DOC	        => Wx::NewId();

const my $ZOOM			=> Wx::NewId();
const my $UNZOOM		=> Wx::NewId();
const my $CURSOR		=> Wx::NewId();
const my $PLOT_QUAD		=> Wx::NewId();
const my $PLOT_ED		=> Wx::NewId();
const my $PLOT_IOSIG		=> Wx::NewId();
const my $PLOT_K123		=> Wx::NewId();
const my $PLOT_R123		=> Wx::NewId();
const my $PLOT_E00		=> Wx::NewId();
const my $PLOT_I0MARKED		=> Wx::NewId();
const my $PLOT_NORMSCALED       => Wx::NewId();
const my $PLOT_STDDEV		=> Wx::NewId();
const my $PLOT_VARIENCE		=> Wx::NewId();
const my $TERM_1		=> Wx::NewId();
const my $TERM_2		=> Wx::NewId();
const my $TERM_3		=> Wx::NewId();
const my $TERM_4		=> Wx::NewId();
const my $PLOT_PNG		=> Wx::NewId();
const my $PLOT_GIF		=> Wx::NewId();
const my $PLOT_JPG		=> Wx::NewId();
const my $PLOT_PDF		=> Wx::NewId();
const my $PLOT_DOC		=> Wx::NewId();

const my $SHOW_BUFFER		=> Wx::NewId();
const my $PLOT_YAML		=> Wx::NewId();
const my $LCF_YAML		=> Wx::NewId();
const my $PCA_YAML		=> Wx::NewId();
const my $PEAK_YAML		=> Wx::NewId();
const my $STYLE_YAML		=> Wx::NewId();
const my $INDIC_YAML		=> Wx::NewId();
const my $MODE_STATUS		=> Wx::NewId();
const my $PERL_MODULES		=> Wx::NewId();
const my $CONDITIONAL		=> Wx::NewId();
const my $STATUS		=> Wx::NewId();
const my $IFEFFIT_STRINGS	=> Wx::NewId();
const my $IFEFFIT_SCALARS	=> Wx::NewId();
const my $IFEFFIT_GROUPS	=> Wx::NewId();
const my $IFEFFIT_ARRAYS	=> Wx::NewId();
const my $IFEFFIT_MEMORY	=> Wx::NewId();

const my $MARK_ALL		=> Wx::NewId();
const my $MARK_NONE		=> Wx::NewId();
const my $MARK_INVERT		=> Wx::NewId();
const my $MARK_TOGGLE		=> Wx::NewId();
const my $MARK_REGEXP		=> Wx::NewId();
const my $UNMARK_REGEXP		=> Wx::NewId();
const my $MARK_DOC		=> Wx::NewId();

const my $MERGE_MUE		=> Wx::NewId();
const my $MERGE_NORM		=> Wx::NewId();
const my $MERGE_CHI		=> Wx::NewId();
const my $MERGE_IMP		=> Wx::NewId();
const my $MERGE_NOISE		=> Wx::NewId();
const my $MERGE_STEP		=> Wx::NewId();
const my $MERGE_DOC		=> Wx::NewId();

const my $DOCUMENT		=> Wx::NewId();
const my $DEMO			=> Wx::NewId();

sub menubar {
  my ($app) = @_;
  my $bar        = Wx::MenuBar->new;
  $app->{main}->{mrumenu} = Wx::Menu->new;
  my $filemenu   = Wx::Menu->new;
  $app->{main}->{filemenu} = $filemenu;
  $filemenu->Append(wxID_OPEN,  "Import data\tCtrl+o", "Import data from a data or project file" );
  $filemenu->AppendSubMenu($app->{main}->{mrumenu}, "Recent files", "This submenu contains a list of recently used files" );
  $filemenu->AppendSeparator;
  $filemenu->Append(wxID_SAVE,    "Save project\tCtrl+s", "Save an Athena project file" );
  $filemenu->Append(wxID_SAVEAS,  "Save project as...", "Save an Athena project file as..." );
  $filemenu->Append($SAVE_MARKED, "Save marked groups as a project ...", "Save marked groups as an Athena project file ..." );
  $filemenu->AppendCheckItem($SAVE_COMPAT, "Backwards compatible project files", "Save project files so that they can be imported by Athena 0.9.17 and earlier (information WILL be lost!)");
  $filemenu->Check($SAVE_COMPAT, Demeter->co->default('athena', 'compatibility'));
  $filemenu->AppendSeparator;

  my $exportmenu   = Wx::Menu->new;
  $exportmenu->Append($REPORT_ALL,    "Excel report on all groups",    "Write an Excel report on the parameter values of all data groups" );
  $exportmenu->Append($REPORT_MARKED, "Excel report on marked groups", "Write an Excel report on the parameter values of the marked data groups" );
  $exportmenu->AppendSeparator;
  $exportmenu->Append($FPATH,         "Empirical standard",            "Write a file containing an empirical standard derived from this group which Artemis can import as a fitting standard" );
  ##$exportmenu->Append($XFIT,          "XFit file for current group",   "Write a file for the XFit XAS analysis program for the current group" );

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
  $savemarkedmenu->Append($MARKED_RDPHA, "Deriv(Pha[$CHI(R)])", "Save marked groups as the derivative of Pha[$CHI(R)] to a column data file") if ($Demeter::UI::Athena::demeter->co->default("athena", "show_dphase"));
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
  $filemenu->AppendSubMenu($savemarkedmenu,  "Save marked groups as ...",     "Save the data from the marked group as a single column data file" );
  $filemenu->AppendSubMenu($saveeachmenu,    "Save each marked group as ...", "Save the marked groups, each as its own column data file" );
  $filemenu->AppendSubMenu($exportmenu,      "Export ...",                    "Export" );
  $filemenu->AppendSeparator;
  $filemenu->Append($CLEAR_PROJECT, 'Clear project name', 'Clear project name');
  $filemenu->AppendSeparator;
  $filemenu->Append(wxID_CLOSE, "&Close\tCtrl+w" );
  $filemenu->Append(wxID_EXIT,  "E&xit\tCtrl+q" );

  my $monitormenu = Wx::Menu->new;
  #print ">>>>", Demeter->is_larch, $/;
  my $ifeffitmenu = Wx::Menu->new;
  $app->{main}->{monitormenu} = $monitormenu;
  $app->{main}->{ifeffitmenu} = $ifeffitmenu;
  #my $yamlmenu    = Wx::Menu->new;

  my $debugmenu   = Wx::Menu->new;
  $debugmenu->Append($MODE_STATUS,  "Show mode status",          "Show mode status dialog" );
  $debugmenu->Append($PERL_MODULES, "Show perl modules",         "Show perl module versions" );
  $debugmenu->Append($CONDITIONAL,  "Show conditional features", "Show which conditional Demeter features are present" );
  $debugmenu->AppendSeparator;
  $debugmenu->Append($PLOT_YAML,    "Plot object YAML",          "Show YAML dialog for Plot object" );
  $debugmenu->Append($STYLE_YAML,   "plot style objects YAML",   "Show YAML dialog for plot style objects" );
  $debugmenu->Append($INDIC_YAML,   "Indicator objects YAML",    "Show YAML dialog for Indicator objects" );
  $debugmenu->AppendSeparator;
  $debugmenu->Append($LCF_YAML,     "LCF object YAML",           "Show YAML dialog for LCF object" );
  $debugmenu->Append($PCA_YAML,     "PCA object YAML",           "Show YAML dialog for PCA object" );
  $debugmenu->Append($PEAK_YAML,    "PeakFit object YAML",       "Show YAML dialog for PeakFit object" );


  $monitormenu->Append($SHOW_BUFFER, "Show command buffer",    'Show the '.Demeter->backend_name.' and plotting commands buffer' );
  $monitormenu->Append($STATUS,      "Show status bar buffer", 'Show the buffer containing messages written to the status bars');
  my $thing1 = $monitormenu->AppendSeparator;
  $ifeffitmenu->Append($IFEFFIT_STRINGS, "strings",      "Examine all the strings currently defined in Ifeffit");
  $ifeffitmenu->Append($IFEFFIT_SCALARS, "scalars",      "Examine all the scalars currently defined in Ifeffit");
  $ifeffitmenu->Append($IFEFFIT_GROUPS,  "groups",       "Examine all the data groups currently defined in Ifeffit");
  $ifeffitmenu->Append($IFEFFIT_ARRAYS,  "arrays",       "Examine all the arrays currently defined in Ifeffit");
  my $thing2 = $monitormenu->AppendSubMenu($ifeffitmenu,  'Query Ifeffit for ...',    'Obtain information from Ifeffit about variables and arrays');
  my $thing3 = $monitormenu->Append($IFEFFIT_MEMORY,  "Show Ifeffit's memory use", "Show Ifeffit's memory use and remaining capacity");
  $app->{main}->{ifeffititems} = [$thing1, $thing2, $thing3]; # clean up Ifeffit menu entries for larch backend
                                                              # see line 192

  #if ($demeter->co->default("athena", "debug_menus")) {
    $monitormenu->AppendSeparator;
    $monitormenu->AppendSubMenu($debugmenu, 'Debug options', 'Display debugging tools');
  #};

  my $e0allmenu   = Wx::Menu->new;
  $e0allmenu->Append($E0_IFEFFIT_ALL,   "Ifeffit's default", "Set E0 for all groups to Ifeffit's default");
  $e0allmenu->Append($E0_TABULATED_ALL, "the tabulated value", "Set E0 for all groups to the tabulated value");
  $e0allmenu->Append($E0_FRACTION_ALL,  "a fraction of the edge step", "Set E0 for all groups to a fraction of the edge step");
  $e0allmenu->Append($E0_ZERO_ALL,      "the zero of the second derivative", "Set E0 for all groups to the zero of the second derivative");
  #$e0allmenu->Append($E0_DMAX_ALL,      "the peak of the first derivative", "Set E0 for all groups to the peak of the first derivative");
  $e0allmenu->Append($E0_PEAK_ALL,      "the peak of the white line", "Set E0 for all groups to the peak of the white line");
  my $e0markedmenu   = Wx::Menu->new;
  $e0markedmenu->Append($E0_IFEFFIT_ALL,      "Ifeffit's default", "Set E0 for marked groups to Ifeffit's default");
  $e0markedmenu->Append($E0_TABULATED_MARKED, "the tabulated value", "Set E0 for marked groups to the tabulated value");
  $e0markedmenu->Append($E0_FRACTION_MARKED,  "a fraction of the edge step", "Set E0 for marked groups to a fraction of the edge step");
  $e0markedmenu->Append($E0_ZERO_MARKED,      "the zero of the second derivative", "Set E0 for marked groups to the zero of the second derivative");
  #$e0markedmenu->Append($E0_DMAX_MARKED,      "the peak of the first derivative", "Set E0 for marked groups to the peak of the first derivative");
  $e0markedmenu->Append($E0_PEAK_MARKED,      "the peak of the white line", "Set E0 for marked groups to the peak of the white line");

  my $wlmenu = Wx::Menu->new;
  $wlmenu->Append($WL_THIS,   "for this group",    "Find the white line position for this group");
  $wlmenu->Append($WL_MARKED, "for marked groups", "Find the white line position for marked groups");
  $wlmenu->Append($WL_ALL,    "for all groups",    "Find the white line position for all groups");

  my $groupmenu   = Wx::Menu->new;
  $groupmenu->Append($RENAME, "Rename current group\tShift+Ctrl+l", "Rename the current group");
  $groupmenu->Append($COPY,   "Copy current group\tShift+Ctrl+y",   "Copy the current group");
  $groupmenu->Append($CHANGE_DATATYPE, "Change data type", "Change the data type for the current group or the marked groups");

  $groupmenu->AppendSeparator;
  $groupmenu->Append($VALUES_ALL,    "Set all groups' values to the current",    "Push this groups parameter values onto all other groups.");
  $groupmenu->Append($VALUES_MARKED, "Set marked groups' values to the current", "Push this groups parameter values onto all marked groups.");
  $groupmenu->AppendSeparator;
  #$groupmenu->AppendSubMenu($freezemenu, 'Freeze groups', 'Freeze groups, that is disable their controls such that their parameter values cannot be changed.');
  $groupmenu->Append($DATA_ABOUT,     "About current group", "Describe current data group");
  $groupmenu->Append($DATA_YAML,      "Show YAML for current group", "Show detailed contents of the current data group");
  $groupmenu->Append($DATA_TEXT,      "Show the text of the current group's data file",  "Show the text of the current data group's data file");
  $groupmenu->Append($EPSILON_MARKED, "Show measurement uncertainties.", "Show the measurement uncertainties of the marked groups." );
  $groupmenu->AppendSeparator;
  $groupmenu->Append($REMOVE,         "Remove current group",   "Remove the current group from this project");
  $groupmenu->Append($REMOVE_MARKED,  "Remove marked groups",   "Remove marked groups from this project");
  $groupmenu->Append(wxID_CLOSE,       "&Close\tCtrl+w" );
  $app->{main}->{groupmenu} = $groupmenu;


  my $energymenu  = Wx::Menu->new;
  $energymenu->AppendSubMenu($e0allmenu, "Set E0 for all groups to...", "Set E0 for all groups using one of four algorithms");
  $energymenu->AppendSubMenu($e0markedmenu, "Set E0 for marked groups to...", "Set E0 for marked groups using one of four algorithms");
  $energymenu->AppendSeparator;
  $energymenu->AppendSubMenu($wlmenu, "Find white line position...", "Find white line positions");
  $energymenu->AppendSeparator;
  $energymenu->Append($SHOW_REFERENCE, "Identify reference channel", "Identify the group that shares the data/reference relationship with this group.");
  $energymenu->Append($TIE_REFERENCE,  "Tie reference channel",  "Tie together two marked groups as data and reference channel.");
  $app->{main}->{energymenu} = $energymenu;


  my $freezemenu  = Wx::Menu->new;
  $freezemenu->Append($FREEZE_TOGGLE,     "Toggle this group\tShift+Ctrl+f", "Toggle the frozen state of this group");
  $freezemenu->Append($FREEZE_ALL,        "Freeze all groups", "Freeze all groups");
  $freezemenu->Append($UNFREEZE_ALL,      "Unfreeze all groups", "Unfreeze all groups" );
  $freezemenu->Append($FREEZE_TOGGLE_ALL, "Invert frozen state of all groups", "Toggle frozen state of all groups");
  $freezemenu->Append($FREEZE_MARKED,     "Freeze marked groups", "Freeze marked groups");
  $freezemenu->Append($UNFREEZE_MARKED,   "Unfreeze marked groups", "Unfreeze marked groups");
  $freezemenu->Append($FREEZE_REGEX,      "Freeze by regexp", "Freeze by regular expression");
  $freezemenu->Append($UNFREEZE_REGEX,    "Unfreeze by regexp", "Unfreeze by regular expression");
  $freezemenu->AppendSeparator;
  $freezemenu->Append($FREEZE_DOC,      "Document section: freezing groups", "Open the document page on freezing groups" );
  $app->{main}->{freezemenu} = $freezemenu;


  my $plotmenu    = Wx::Menu->new;
  my $currentplotmenu = Wx::Menu->new;
  my $markedplotmenu  = Wx::Menu->new;
  my $mergedplotmenu  = Wx::Menu->new;
  $app->{main}->{currentplotmenu} = $currentplotmenu;
  $app->{main}->{markedplotmenu}  = $markedplotmenu;
  $app->{main}->{mergedplotmenu}  = $mergedplotmenu;
  $currentplotmenu->Append($PLOT_QUAD,       "Quad plot",             "Make a quad plot from the current group" );
  $currentplotmenu->Append($PLOT_ED,         "Norm+deriv",            "Make a plot of norm(E)+deriv(E) of the current group" );
  $currentplotmenu->Append($PLOT_IOSIG,      "Data+I0+Signal",        "Plot data, I0, and signal from the current group" );
  $currentplotmenu->Append($PLOT_K123,       "k123 plot",             "Make a k123 plot from the current group" );
  $currentplotmenu->Append($PLOT_R123,       "R123 plot",             "Make an R123 plot from the current group" );
  $markedplotmenu ->Append($PLOT_E00,        "Plot with E0 at E=0",   "Plot each of the marked groups with its edge energy at E=0" );
  $markedplotmenu ->Append($PLOT_I0MARKED,   "Plot I0",               "Plot I0 for each of the marked groups" );
  $markedplotmenu ->Append($PLOT_NORMSCALED, "Plot norm(E) scaled by edge step", "Plot normalized data for all marked groups, scaled by the size of the edge step" );
  $mergedplotmenu ->Append($PLOT_STDDEV,     "Plot data + std. dev.", "Plot the merged data along with its standard deviation" );
  $mergedplotmenu ->Append($PLOT_VARIENCE,   "Plot data + variance",  "Plot the merged data along with its scaled variance" );

  if ($demeter->co->default('plot', 'plotwith') eq 'pgplot') {
    $plotmenu->Append($ZOOM,   'Zoom\tCtrl++',   'Zoom in on the latest plot');
    $plotmenu->Append($UNZOOM, 'Unzoom\tCtrl+-', 'Unzoom');
    $plotmenu->Append($CURSOR, 'Cursor\tCtrl+.', 'Show the coordinates of a point on the plot');
    $plotmenu->AppendSeparator;
  };
  $plotmenu->AppendSubMenu($currentplotmenu, "Current group", "Special plot types for the current group");
  $plotmenu->AppendSubMenu($markedplotmenu,  "Marked groups", "Special plot types for the marked groups");
  $plotmenu->AppendSubMenu($mergedplotmenu,  "Merge groups",  "Special plot types for merge data");
  if ($demeter->co->default('plot', 'plotwith') eq 'gnuplot') {
    my $imagemenu = Wx::Menu->new;
    $imagemenu->Append($PLOT_PNG, "PNG", "Send the last plot to a PNG file");
    $imagemenu->Append($PLOT_PDF, "PDF", "Send the last plot to a PDF file");

    $plotmenu->AppendSeparator;
    $plotmenu->AppendSubMenu($imagemenu, "Save last plot as...", "Save the last plot as an image file");
    $plotmenu->AppendSeparator;
    $plotmenu->AppendRadioItem($TERM_1, "Plot to terminal 1", "Plot to terminal 1");
    $plotmenu->AppendRadioItem($TERM_2, "Plot to terminal 2", "Plot to terminal 2");
    $plotmenu->AppendRadioItem($TERM_3, "Plot to terminal 3", "Plot to terminal 3");
    $plotmenu->AppendRadioItem($TERM_4, "Plot to terminal 4", "Plot to terminal 4");
  };
  $plotmenu->AppendSeparator;
  $plotmenu->Append($PLOT_DOC,      "Document section: plotting data", "Open the document page on plotting data" );
  $app->{main}->{plotmenu} = $plotmenu;

  my $markmenu   = Wx::Menu->new;
  $markmenu->Append($MARK_TOGGLE,   "Toggle current mark\tShift+Ctrl+t", "Toggle mark of current group" );
  $markmenu->Append($MARK_ALL,      "Mark all\tShift+Ctrl+a",            "Mark all groups" );
  $markmenu->Append($MARK_NONE,     "Clear all marks\tShift+Ctrl+u",     "Clear all marks" );
  $markmenu->Append($MARK_INVERT,   "Invert marks\tShift+Ctrl+i",        "Invert all mark" );
  $markmenu->Append($MARK_REGEXP,   "Mark by regexp\tShift+Ctrl+r",      "Mark all groups matching a regular expression" );
  $markmenu->Append($UNMARK_REGEXP, "Unmark by regexp\tShift+Ctrl+x",     "Unmark all groups matching a regular expression" );
  $markmenu->AppendSeparator;
  $markmenu->Append($MARK_DOC,      "Document section: marking groups", "Open the document page on marking groups" );
  $app->{main}->{markmenu} = $markmenu;

  my $mergemenu  = Wx::Menu->new;
  $mergemenu->Append($MERGE_MUE,  "Merge $MU(E)",  "Merge marked data at $MU(E)" );
  $mergemenu->Append($MERGE_NORM, "Merge norm(E)", "Merge marked data at normalized $MU(E)" );
  $mergemenu->Append($MERGE_CHI,  "Merge $CHI(k)", "Merge marked data at $CHI(k)" );
  $mergemenu->AppendSeparator;
  $mergemenu->AppendRadioItem($MERGE_IMP,   "Weight by importance",       "Weight the marked groups by their importance values when merging" );
  $mergemenu->AppendRadioItem($MERGE_NOISE, "Weight by noise in $CHI(k)", "Weight the marked groups by their $CHI(k) noise values when merging" );
  $mergemenu->AppendRadioItem($MERGE_STEP,  "Weight by $MU(E) edge step", "Weight the marked groups the size of the edge step in $MU(E) when merging" );
  $mergemenu->Check($MERGE_IMP,   1) if ($demeter->co->default('merge', 'weightby') eq 'importance');
  $mergemenu->Check($MERGE_NOISE, 1) if ($demeter->co->default('merge', 'weightby') eq 'noise');
  $mergemenu->Check($MERGE_STEP,  1) if ($demeter->co->default('merge', 'weightby') eq 'step');
  $mergemenu->AppendSeparator;
  $mergemenu->Append($MERGE_DOC,  "Document section: merging data", "Open the document page on merging data" );


  my $helpmenu   = Wx::Menu->new;
  $helpmenu->Append($DOCUMENT,  "Document\tCtrl-m",     "Open the Athena document" );
  #$helpmenu->Append($DEMO,      "Demo project", "Open a demo project" );
  $helpmenu->AppendSeparator;
  $helpmenu->Append(wxID_ABOUT, "&About Athena" );

  $bar->Append( $filemenu,    "&File" );
  $bar->Append( $groupmenu,   "&Group" );
  $bar->Append( $energymenu,  "&Energy" );
  $bar->Append( $markmenu,    "&Mark" );
  $bar->Append( $plotmenu,    "&Plot" );
  $bar->Append( $freezemenu,  "Free&ze" );
  $bar->Append( $mergemenu,   "Me&rge" );
  $bar->Append( $monitormenu, "M&onitor" );
  $bar->Append( $helpmenu,    "&Help" );
  $app->{main}->SetMenuBar( $bar );

  ##$exportmenu     -> Enable($_,0) foreach ($XFIT);
  $plotmenu       -> Enable($_,0) foreach ($ZOOM, $UNZOOM, $CURSOR);
  $mergedplotmenu -> Enable($_,0) foreach ($PLOT_STDDEV, $PLOT_VARIENCE);
  #$helpmenu       -> Enable($_,0) foreach ($DEMO);
  $exportmenu     -> Enable($FPATH, 0) if ($ENV{DEMETER_BACKEND} eq 'larch');

  EVT_MENU($app->{main}, -1, sub{my ($frame,  $event) = @_; OnMenuClick($frame,  $event, $app)} );
  if ($ENV{DEMETER_BACKEND} eq 'larch') {
    $app->{main}->{monitormenu}->Remove($_) foreach (@{$app->{main}->{ifeffititems}});
  };

  return $app;
};

sub project_compatibility {
  my ($app) = @_;
  return $app->{main}->{filemenu}->IsChecked($SAVE_COMPAT);
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

sub set_mergedplot {
  my ($app, $bool) = @_;
  $app->{main}->{mergedplotmenu} ->Enable($_,$bool) foreach ($PLOT_STDDEV, $PLOT_VARIENCE);
};

sub OnMenuClick {
  my ($self, $event, $app) = @_;
  my $id = $event->GetId;
  my $mru = $app->{main}->{mrumenu}->GetLabel($id);
  $mru =~ s{__}{_}g; 		# wtf!?!?!?

 SWITCH: {
    ($mru) and do {
      $app->{main}->status("$mru does not exist"), return if (not -e $mru);
      $app->{main}->status("cannot read $mru"),    return if (not -r $mru);
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
      $app->{main}->status("Closing project ...", "wait");
      my $busy = Wx::BusyCursor->new();
      $app->Remove('all');
      undef $busy;
      last SWITCH;
    };
    ($id == wxID_EXIT) and do {
      #my $ok = $app->on_close;
      #return if not $ok;
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

    ($id == $REPORT_ALL) and do {
      last SWITCH if $app->is_empty;
      $app -> Report('all');
      last SWITCH;
    };
    ($id == $REPORT_MARKED) and do {
      last SWITCH if $app->is_empty;
      $app -> Report('marked');
      last SWITCH;
    };
    ($id == $FPATH) and do {
      $app -> FPath;
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
		      $MARKED_RMAG, $MARKED_RRE,  $MARKED_RIM,  $MARKED_RPHA,  $MARKED_RDPHA,
		      $MARKED_QMAG, $MARKED_QRE,  $MARKED_QIM,  $MARKED_QPHA))
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
	        : ($id == $MARKED_RDPHA) ? "dph"
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
    ($id == $CHANGE_DATATYPE) and do {
      $app->change_datatype;
      last SWITCH;
    };
    ($id == $SHOW_REFERENCE) and do {
      last SWITCH if $app->is_empty;
      $app->{main}->status("The current group is tied to \"" . $app->current_data->reference->name . "\".");
      last SWITCH;
    };
    ($id == $TIE_REFERENCE) and do {
      last SWITCH if $app->is_empty;
      $app->tie_reference;
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
    ($id == $DATA_ABOUT) and do {
      last SWITCH if $app->is_empty;
      my $dialog = Demeter::UI::Artemis::ShowText
	-> new($app->{main}, $app->current_data->about, 'About current group')
	  -> Show;
      last SWITCH;
    };
    ($id == $DATA_YAML) and do {
      last SWITCH if $app->is_empty;
      my $dialog = Demeter::UI::Artemis::ShowText
	-> new($app->{main}, $app->current_data->serialization, 'Structure of Data object')
	  -> Show;
      last SWITCH;
    };
    ($id == $DATA_TEXT) and do {
      last SWITCH if $app->is_empty;
      if (-e $app->current_data->file) {
	my $dialog = Demeter::UI::Artemis::ShowText
	  -> new($app->{main}, $demeter->slurp($app->current_data->file), 'Text of data file')
	    -> Show;
      } else {
	$app->{main}->status("The current group's data file cannot be found.");
      };
      last SWITCH;
    };
    ($id == $EPSILON_MARKED) and do {
      last SWITCH if $app->is_empty;
      $app->show_epsilon;
      last SWITCH;
    };

    ## -------- values menu
    ($id == $VALUES_ALL) and do {
      $app->{main}->{Main}->constrain($app, 'all', 'all');
      last SWITCH;
    };
    ($id == $VALUES_MARKED) and do {
      $app->{main}->{Main}->constrain($app, 'all', 'marked');
      last SWITCH;
    };

    ($id == $E0_IFEFFIT_ALL) and do {
      $app->{main}->{Main}->set_e0($app, 'ifeffit', 'all');
      last SWITCH;
    };
    ($id == $E0_TABULATED_ALL) and do {
      $app->{main}->{Main}->set_e0($app, 'atomic', 'all');
      last SWITCH;
    };
    ($id == $E0_FRACTION_ALL) and do {
      $app->{main}->{Main}->set_e0($app, 'fraction', 'all');
      last SWITCH;
    };
    ($id == $E0_ZERO_ALL) and do {
      $app->{main}->{Main}->set_e0($app, 'zero', 'all');
      last SWITCH;
    };
    ($id == $E0_DMAX_ALL) and do {
      $app->{main}->{Main}->set_e0($app, 'dmax', 'all');
      last SWITCH;
    };
    ($id == $E0_PEAK_ALL) and do {
      $app->{main}->{Main}->set_e0($app, 'peak', 'all');
      last SWITCH;
    };

    ($id == $E0_IFEFFIT_MARKED) and do {
      $app->{main}->{Main}->set_e0($app, 'ifeffit', 'marked');
      last SWITCH;
    };
    ($id == $E0_TABULATED_MARKED) and do {
      $app->{main}->{Main}->set_e0($app, 'atomic', 'marked');
      last SWITCH;
    };
    ($id == $E0_FRACTION_MARKED) and do {
      $app->{main}->{Main}->set_e0($app, 'fraction', 'marked');
      last SWITCH;
    };
    ($id == $E0_ZERO_MARKED) and do {
      $app->{main}->{Main}->set_e0($app, 'zero', 'marked');
      last SWITCH;
    };
    ($id == $E0_DMAX_MARKED) and do {
      $app->{main}->{Main}->set_e0($app, 'dmax', 'marked');
      last SWITCH;
    };
    ($id == $E0_PEAK_MARKED) and do {
      $app->{main}->{Main}->set_e0($app, 'peak', 'marked');
      last SWITCH;
    };

    ## -------- white line positions
    ($id == $WL_THIS) and do {
      my $data = $app->current_data;
      my ($val, $err) = $data->find_white_line;
      $app->{main}->{'PlotE'}->pull_single_values;
      $data->po->set(emin=>-40, emax=>60, e_bkg=>0, e_pre=>0, e_post=>0, e_norm=>1, e_der=>0, 
		     e_sec=>0, e_mu=>1, e_i0=>0, e_signal=>0);
      #$app->plot(0, 0, 'E', 'single');
      return if not $app->preplot('e', $data);
      $data->po->start_plot;
      $data->po->title($app->{main}->{Other}->{title}->GetValue);
      $data->plot('E');
      $data->standard;
      my $indic = Demeter::Plot::Indicator->new(space=>'E', x=>$val-$data->bkg_e0);
      $indic->plot();
      $data->unset_standard;
      $app->{lastplot} = ['E', 'single'];
      $app->postplot($data, $data->bkg_fixstep);
      $app->{main}->status(sprintf("White line position %.3f eV", $val));
      last SWITCH;
    };
    ($id == $WL_MARKED) and do {
      $app->find_wl('marked');
      last SWITCH;
    };
    ($id == $WL_ALL) and do {
      $app->find_wl('all');
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
    ($id == $MERGE_IMP) and do {
      $demeter->mo->merge('importance');
      $app->{main}->status("Weighting merges by " . $demeter->mo->merge);
      last SWITCH;
    };
    ($id == $MERGE_NOISE) and do {
      $demeter->mo->merge('noise');
      $app->{main}->status("Weighting merges by " . $demeter->mo->merge);
      last SWITCH;
    };
    ($id == $MERGE_STEP) and do {
      $demeter->mo->merge('step');
      $app->{main}->status("Weighting merges by " . $demeter->mo->merge);
      last SWITCH;
    };
    ($id == $MERGE_DOC) and do {
      $app->document('process.merge');
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
      $app->show_ifeffit('strings');
      last SWITCH;
    };
    ($id == $IFEFFIT_SCALARS) and do {
      $app->show_ifeffit('scalars');
      last SWITCH;
    };
    ($id == $IFEFFIT_GROUPS) and do {
      $app->show_ifeffit('groups');
      last SWITCH;
    };
    ($id == $IFEFFIT_ARRAYS) and do {
      $app->show_ifeffit('arrays');
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

    ($id == $LCF_YAML) and do {
      my $dialog = Demeter::UI::Artemis::ShowText
	-> new($app->{main}, $app->{main}->{LCF}->{LCF}->serialization, 'YAML of Plot object')
	  -> Show;
      last SWITCH;
    };
    ($id == $PCA_YAML) and do {
      my $dialog = Demeter::UI::Artemis::ShowText
	-> new($app->{main}, $app->{main}->{PCA}->{PCA}->serialization, 'YAML of Plot object')
	  -> Show;
      last SWITCH;
    };
    ($id == $PEAK_YAML) and do {
      my $dialog = Demeter::UI::Artemis::ShowText
	-> new($app->{main}, $app->{main}->{PeakFit}->{PEAK}->serialization, 'YAML of Plot object')
	  -> Show;
      last SWITCH;
    };
    ($id == $STYLE_YAML) and do {
      my $text = q{};
      foreach my $i (0 .. $app->{main}->{Style}->{list}->GetCount-1) {
	$text .= $app->{main}->{Style}->{list}->GetClientData($i)->serialization;
      };
      my $dialog = Demeter::UI::Artemis::ShowText
	-> new($app->{main}, $text, 'YAML of Style objects')
	  -> Show;
      last SWITCH;
    };
    ($id == $INDIC_YAML) and do {
      my $text = q{};
      foreach my $i (1 .. $Demeter::UI::Athena::Plot::Indicators::nind) {
	$text .= $app->{main}->{Indicators}->{'group'.$i}->serialization if (ref($app->{main}->{Indicators}->{'group'.$i}) =~ m{Indicator});
      };
      my $dialog = Demeter::UI::Artemis::ShowText
	-> new($app->{main}, $text, 'YAML of Indicator objects')
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
    ($id == $CONDITIONAL) and do {
      my $dialog = Demeter::UI::Artemis::ShowText->new($app->{main}, $demeter->conditional_features, 'Conditionally loaded Demeter features') -> Show;
      last SWITCH;
    };

    ($id == $IFEFFIT_MEMORY) and do {
      $app->heap_check(1);
      last SWITCH;
    };

    ($id == $PLOT_QUAD) and do {
      my $data = $app->current_data;
      if ($app->current_data->datatype ne 'xmu') {
	$app->{main}->status("Cannot plot " . $app->current_data->datatype . " data as a quadplot.", "error");
	return;
      };
      #$app->{main}->{Main}->pull_values($data);
      $data->po->start_plot;
      $app->quadplot($data);
      last SWITCH;
    };
    ($id == $PLOT_ED) and do {
      my $data = $app->current_data;
      if ($app->current_data->datatype ne 'xmu') {
	$app->{main}->status("Cannot plot " . $app->current_data->datatype . " data as a quadplot.", "error");
	return;
      };
      #$app->{main}->{Main}->pull_values($data);
      $data->po->start_plot;
      $data->plot('ed');
      last SWITCH;
    };
    ($id == $PLOT_IOSIG) and do {
      my $data = $app->current_data;
      my $is_fixed = $data->bkg_fixstep;
      #$app->{main}->{Main}->pull_values($data);
      $app->{main}->{PlotE}->pull_single_values;
      $data->po->set(e_bkg=>0, e_pre=>0, e_post=>0, e_norm=>0, e_der=>0, e_sec=>0);
      $data->po->set(e_mu=>1, e_i0=>1, e_signal=>1);
      return if not $app->preplot('e', $data);
      $data->po->start_plot;
      $data->po->title($app->{main}->{Other}->{title}->GetValue);
      $data->plot('E');
      $data->po->set(e_i0=>0, e_signal=>0);
      $app->{main}->{plottabs}->SetSelection(1) if $app->spacetab;
      $app->{lastplot} = ['E', 'single'];
      $app->postplot($data, $is_fixed);
      last SWITCH;
    };
    ($id == $PLOT_K123) and do {
      my $data = $app->current_data;
      my $is_fixed = $data->bkg_fixstep;
      #$app->{main}->{Main}->pull_values($data);
      $app->{main}->{PlotK}->pull_single_values;
      return if not $app->preplot('k', $data);
      $data->po->start_plot;
      $data->po->title($app->{main}->{Other}->{title}->GetValue);
      $data->plot('k123');
      $app->{main}->{plottabs}->SetSelection(2) if $app->spacetab;
      $app->{lastplot} = ['k', 'single'];
      $app->postplot($data, $is_fixed);
      last SWITCH;
    };
    ($id == $PLOT_R123) and do {
      my $data = $app->current_data;
      my $is_fixed = $data->bkg_fixstep;
      #$app->{main}->{Main}->pull_values($data);
      $app->{main}->{PlotR}->pull_marked_values;
      return if not $app->preplot('r', $data);
      $data->po->start_plot;
      $data->po->title($app->{main}->{Other}->{title}->GetValue);
      $data->plot('R123');
      $app->postplot($data, $is_fixed);
      $app->{main}->{plottabs}->SetSelection(3) if $app->spacetab;
      $app->{lastplot} = ['R', 'single'];
      last SWITCH;
    };
    ($id == $PLOT_STDDEV) and do {
      my $data = $app->current_data;
      last SWITCH if not $data->is_merge;
      my $sp = $data->is_merge;
      $sp = 'e' if ($sp eq 'n');
      #return if not $app->preplot($sp, $data);
      my $which = ($sp eq 'k') ? 'PlotK' : 'PlotE';
      $app->{main}->{$which}->pull_marked_values;
      $data->po->title($app->{main}->{Other}->{title}->GetValue);
      $data->plot('stddev');
      #$app->postplot($data);
      $app->{lastplot} = [$sp, 'single'];
      last SWITCH;
    };
    ($id == $PLOT_VARIENCE) and do {
      my $data = $app->current_data;
      last SWITCH if not $data->is_merge;
      #return if not $app->postplot($data);
      my $sp = $data->is_merge;
      $sp = 'E' if ($sp eq 'n');
      my $which = ($sp eq 'k') ? 'PlotK' : 'PlotE';
      $app->{main}->{$which}->pull_marked_values;
      $data->po->title($app->{main}->{Other}->{title}->GetValue);
      $data->plot('variance');
      #$app->postplot($data);
      $app->{lastplot} = [$sp, 'single'];
      last SWITCH;
    };
    ($id == $PLOT_E00) and do {
      $app->plot_e00;
      last SWITCH;
    };
    ($id == $PLOT_I0MARKED) and do {
      $app->plot_i0_marked;
      last SWITCH;
    };
    ($id == $PLOT_NORMSCALED) and do {
      $app->plot_norm_scaled;
      last SWITCH;
    };

    ($id == $PLOT_PNG) and do {
      $app->image('png');
      last SWITCH;
    };
    ($id == $PLOT_GIF) and do {
      $app->image('gif');
      last SWITCH;
    };
    ($id == $PLOT_JPG) and do {
      $app->image('jpeg');
      last SWITCH;
    };
    ($id == $PLOT_PDF) and do {
      $app->image('pdf');
      last SWITCH;
    };

    ($id == $PLOT_DOC) and do {
      $app->document('plot');
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
    ($id == $TERM_4) and do {
      $demeter->po->terminal_number(4);
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
    ($id == $MARK_DOC) and do {
      $app->document('ui.mark');
      last SWITCH;
    };

    ($id == $FOCUS_UP) and do {
      $app->focus_up;
      return;
    };
    ($id == $FOCUS_DOWN) and do {
      $app->focus_down;
      return;
    };
    ($id == $MOVE_UP) and do {
      $app->move_group("up");
      return;
    };
    ($id == $MOVE_DOWN) and do {
      $app->move_group("down");
      return;
    };

    ($id == $FREEZE_TOGGLE) and do {
      $app->quench('toggle');
      last SWITCH;
    };
    ($id == $FREEZE_ALL) and do {
      $app->quench('all');
      last SWITCH;
    };
    ($id == $UNFREEZE_ALL) and do {
      $app->quench('none');
      last SWITCH;
    };
    ($id == $FREEZE_MARKED) and do {
      $app->quench('marked');
      last SWITCH;
    };
    ($id == $UNFREEZE_MARKED) and do {
      $app->quench('unfreeze_marked');
      last SWITCH;
    };
    ($id == $FREEZE_REGEX) and do {
      $app->quench('regex');
      last SWITCH;
    };
    ($id == $UNFREEZE_REGEX) and do {
      $app->quench('unfreeze_regex');
      last SWITCH;
    };
    ($id == $FREEZE_TOGGLE_ALL) and do {
      $app->quench('invert');
      last SWITCH;
    };
    ($id == $FREEZE_DOC) and do {
      $app->document('ui.frozen');
      last SWITCH;
    };

    ($id == wxID_ABOUT) and do {
      $app->on_about;
      return;
    };

    ($id == $DOCUMENT) and do {
      $app->document('index');
      return;
    };


  };
};


sub show_ifeffit {
  my ($app, $which) = @_;
  $demeter->dispense('process', 'show', {items=>'@'.$which});
  $app->{Buffer}->{iffcommands}->ShowPosition($app->{Buffer}->{iffcommands}->GetLastPosition);
  $app->{Buffer}->Show(1);
};

sub main_window {
  my ($app, $hbox) = @_;

  my $viewpanel = Wx::Panel    -> new($app->{main}, -1);
  my $viewbox   = Wx::BoxSizer -> new( wxVERTICAL );
  $hbox        -> Add($viewpanel, 0, wxGROW|wxALL, 0);


  my $topbar = Wx::BoxSizer->new( wxHORIZONTAL );
  $viewbox -> Add($topbar, 0, wxGROW|wxRIGHT, 5);

  $app->{main}->{token}   = Wx::StaticText->new($viewpanel, -1, q{ }, wxDefaultPosition, [10,-1]);
  $app->{main}->{project} = Wx::StaticText->new($viewpanel, -1, q{<untitled>},);
  my $size = Wx::SystemSettings::GetFont(wxSYS_DEFAULT_GUI_FONT)->GetPointSize + 2;
  $app->{main}->{project}->SetFont( Wx::Font->new( $size, wxDEFAULT, wxNORMAL, wxBOLD, 0, "" ) );
  $topbar -> Add($app->{main}->{token},   0, wxTOP|wxBOTTOM|wxLEFT, 5);
  $topbar -> Add($app->{main}->{project}, 0, wxGROW|wxALL, 5);

  $topbar -> Add(1,1,1);

  $app->{main}->{save}   = Wx::Button->new($viewpanel, wxID_SAVE, q{},  wxDefaultPosition, wxDefaultSize, wxBU_EXACTFIT);
  $app->{main}->{all}    = Wx::Button->new($viewpanel, -1,        q{A}, wxDefaultPosition, wxDefaultSize, wxBU_EXACTFIT);
  $app->{main}->{none}   = Wx::Button->new($viewpanel, -1,        q{U}, wxDefaultPosition, wxDefaultSize, wxBU_EXACTFIT);
  $app->{main}->{invert} = Wx::Button->new($viewpanel, -1,        q{I}, wxDefaultPosition, wxDefaultSize, wxBU_EXACTFIT);
  $topbar -> Add($app->{main}->{save},   0, wxGROW|wxTOP|wxBOTTOM, 2);
  $topbar -> Add(Wx::StaticText->new($viewpanel, -1, q{    }), 0, wxGROW|wxTOP|wxBOTTOM, 2);
  $topbar -> Add($app->{main}->{all},    0, wxGROW|wxTOP|wxBOTTOM, 2);
  $topbar -> Add($app->{main}->{none},   0, wxGROW|wxTOP|wxBOTTOM, 2);
  $topbar -> Add($app->{main}->{invert}, 0, wxGROW|wxTOP|wxBOTTOM, 2);
  $app->{main}->{save} -> Enable(0);
  $app->{main}->{save_start_color} = $app->{main}->{save}->GetBackgroundColour;
  $app->EVT_BUTTON($app->{main}->{save},   sub{$app -> Export('all', $app->{main}->{currentproject})});
  $app->EVT_BUTTON($app->{main}->{all},    sub{$app->mark('all')});
  $app->EVT_BUTTON($app->{main}->{none},   sub{$app->mark('none')});
  $app->EVT_BUTTON($app->{main}->{invert}, sub{$app->mark('invert')});
  $app->mouseover($app->{main}->{save},   "Save your project with one click");
  $app->mouseover($app->{main}->{all},    "Mark all groups");
  $app->mouseover($app->{main}->{none},   "Clear all marks");
  $app->mouseover($app->{main}->{invert}, "Invert all marks");

  my %labels_of = (
		   Main             => 'Main window',
		   Calibrate	    => "Calibrate data",
		   Align	    => "Align data",
		   Rebin	    => "Rebin data",
		   DeglitchTruncate => "Deglitch and truncate data",
		   Smooth	    => "Smooth data",
		   ConvoluteNoise   => "Convolute and add noise to data",
		   Deconvolute	    => "Deconvolute data",
		   SelfAbsorption   => "Self-absorption correction",
		   MEE              => "Multi-electron excitation removal",
		   Dispersive       => "Calibrate dispersive XAS data",
		   Series	    => "Copy series",
		   Summer	    => "Data summation",
		   LCF		    => "Linear combination fitting",
		   PCA		    => "Principle components analysis",
		   PeakFit	    => "Peak fitting",
		   LogRatio	    => "Log-ratio/phase-difference analysis",
		   Difference	    => "Difference spectra",
		   XDI		    => "File metadata",
		   Watcher	    => "Data watcher",
		   Journal	    => "Project journal",
		   PluginRegistry   => "Plugin registry",
		   Prefs	    => "Preferences",
		  );


  $app->{main}->{views} = Wx::Choicebook->new($viewpanel, -1);
  $viewbox -> Add($app->{main}->{views}, 1, wxLEFT|wxRIGHT, 5);
  #print join("|", $app->{main}->{views}->GetChildren), $/;
  $app->mouseover($app->{main}->{views}->GetChildren, "Change data processing and analysis tools using this menu.");

  my $pagesize;
  foreach my $which ('Main',		  # 0
		     'Calibrate',	  # 1
		     'Align',		  # 2
		     'Rebin',		  # 3
		     'DeglitchTruncate',  # 4
		     'Smooth',		  # 5
		     'ConvoluteNoise',	  # 6
		     'Deconvolute',	  # 7
		     'SelfAbsorption',	  # 8
		     'MEE',               # 9
		     'Dispersive',	  # 10
		     'Series',            # 11
		     'Summer',            # 12
		     # -----------------------
		     'LCF',		  # 14
		     'PCA',		  # 15
		     'PeakFit',		  # 16
		     'LogRatio',	  # 17
		     'Difference',	  # 18
		     # -----------------------
		     'XDI',               # 20
		     'Watcher',           # 21
		     'Journal',		  # 22
		     'PluginRegistry',    # 23
		     'Prefs',		  # 24
		    ) {
    next if (($which eq 'Watcher') and (not $Demeter::FML_exists));
    next if (($which eq 'Watcher') and (not Demeter->co->default(qw(athena show_watcher))));
    next if (($which eq 'Dispersive') and (not Demeter->co->default(qw(athena show_dispersive))));
    next if $INC{"Demeter/UI/Athena/$which.pm"};

    my $page = Wx::Panel->new($app->{main}->{views}, -1);
    $app->{main}->{$which."_page"} = $page;
    my $box = Wx::BoxSizer->new( wxVERTICAL );
    $app->{main}->{$which."_sizer"} = $box;

    ## postpone creating most views until they are selected for the first time. (see view_changing)
    if (any {$which eq $_} qw(Main)) {
      require "Demeter/UI/Athena/$which.pm";
      my $pm = "Demeter::UI::Athena::$which";
      $app->{main}->{$which} = $pm->new($page, $app);
      my $hh   = Wx::BoxSizer->new( wxVERTICAL );
      $hh  -> Add($app->{main}->{$which}, 1, wxGROW|wxEXPAND|wxALL, 0);
      $box -> Add($hh, 1, wxEXPAND|wxALL, 0);
    };
    $page -> SetSizer($box);
    ##my $label = eval '$'.'Demeter::UI::Athena::'.$which.'::label' || $labels_of{$which};
    my $label = $labels_of{$which};
    $app->{main}->{views} -> AddPage($page, $label, 0);

  };
  $app->{main}->{views}->SetSelection(0);

  $app->{main}->{return}   = Wx::Button->new($viewpanel, -1, 'Return to main window', wxDefaultPosition, wxDefaultSize, wxBU_EXACTFIT);
  $app->EVT_BUTTON($app->{main}->{return},   sub{  $app->{main}->{views}->SetSelection(0); $app->OnGroupSelect(0)});
  $viewbox -> Add($app->{main}->{return}, 0, wxGROW|wxLEFT|wxRIGHT, 5);

  $viewbox->Fit($app->{main}->{views});
  $viewbox->SetSizeHints($app->{main}->{views});
  $viewpanel -> SetSizerAndFit($viewbox);

  require Demeter::UI::Athena::Null;
  my $null = Demeter::UI::Athena::Null->new($app->{main}->{views});
  my $dashes = 12;		# deal correctly with optional tools
  ++$dashes if Demeter->co->default(qw(athena show_dispersive));
  $app->{main}->{views}->InsertPage($dashes, $null, $Demeter::UI::Athena::Null::label, 0);
  $dashes +=6;
  ##++$dashes if Demeter->co->default(qw(athena show_watcher));
  $app->{main}->{views}->InsertPage($dashes, $null, $Demeter::UI::Athena::Null::label, 0);


  EVT_CHOICEBOOK_PAGE_CHANGED($app->{main}, $app->{main}->{views}, sub{$app->OnGroupSelect(0,0,0);
								       $app->{main}->{return}->Show($app->{main}->{views}->GetSelection)
								     });
  EVT_CHOICEBOOK_PAGE_CHANGING($app->{main}, $app->{main}->{views}, sub{$app->view_changing(@_)});


  return $app;
};

sub side_bar {
  my ($app, $hbox) = @_;

  my $toolpanel = Wx::Panel    -> new($app->{main}, -1);
  my $toolbox   = Wx::BoxSizer -> new( wxVERTICAL );
  $hbox        -> Add($toolpanel, 1, wxGROW|wxALL, 0);

  $app->{main}->{list} = Wx::CheckListBox->new($toolpanel, -1, wxDefaultPosition, wxDefaultSize, [], wxLB_SINGLE|wxLB_NEEDED_SB);
  $app->{main}->{list}->{datalist} = []; # see modifications to CheckBookList at end of this file....
  $toolbox            -> Add($app->{main}->{list}, 1, wxGROW|wxALL, 0);
  EVT_LISTBOX($toolpanel, $app->{main}->{list}, sub{$app->OnGroupSelect(@_,1)});
  EVT_LISTBOX_DCLICK($toolpanel, $app->{main}->{list}, sub{$app->Rename;});
  EVT_RIGHT_DOWN($app->{main}->{list}, sub{OnRightDown(@_)});
  EVT_LEFT_DOWN($app->{main}->{list}, \&OnDrag);
  EVT_CHECKLISTBOX($toolpanel, $app->{main}->{list}, sub{OnMark(@_, $app->{main}->{list})});
  $app->{main}->{list}->SetDropTarget( Demeter::UI::Athena::DropTarget->new( $app->{main}, $app->{main}->{list} ) );
  #print Wx::SystemSettings::GetColour(wxSYS_COLOUR_HIGHLIGHT), $/;
  #$app->{main}->{list}->SetBackgroundColour(Wx::Colour->new($demeter->co->default("athena", "single")));

  my $singlebox = Wx::BoxSizer->new( wxHORIZONTAL );
  my $markedbox = Wx::BoxSizer->new( wxHORIZONTAL );
  $toolbox -> Add($singlebox, 0, wxGROW|wxALL, 0);
  $toolbox -> Add($markedbox, 0, wxGROW|wxALL, 0);
  foreach my $which (qw(E k R q kq)) {

    ## single plot button
    my $key = 'plot_single_'.$which;
    $app->{main}->{$key} = Wx::Button -> new($toolpanel, -1, sprintf("%2.2s",$which), wxDefaultPosition, wxDefaultSize, wxBU_EXACTFIT);
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
		 $::app->{update_kweights} = 1;
		 $::app->replot(@{$::app->{lastplot}}) if (lc($::app->{lastplot}->[0]) ne 'e');
	       });
  $app->mouseover($app->{main}->{kweights}, "Select the value of k-weighting to be used in plots in k, R, and q-space.");

  ## -------- fill the plotting options tabs
  $app->{main}->{plottabs}  = Wx::Choicebook->new($toolpanel, -1, wxDefaultPosition, wxDefaultSize, wxNB_TOP);
  $app->mouseover($app->{main}->{plottabs}->GetChildren, "Set various plotting parameters.");
  foreach my $m (qw(Other PlotE PlotK PlotR PlotQ Stack Indicators Style)) {
    next if $INC{"Demeter/UI/Athena/Plot/$m.pm"};
    require "Demeter/UI/Athena/Plot/$m.pm";
    $app->{main}->{$m} = "Demeter::UI::Athena::Plot::$m"->new($app->{main}->{plottabs}, $app);
    $app->{main}->{plottabs} -> AddPage($app->{main}->{$m},
					"Demeter::UI::Athena::Plot::$m"->label,
					($m eq 'PlotE'));
  };
  $toolbox -> Add($app->{main}->{plottabs}, 0, wxGROW|wxALL, 0);

#   my $exafs = Demeter::Plot::Style->new(name=>'exafs', emin=>-200, emax=>800);
#   my $xanes = Demeter::Plot::Style->new(name=>'xanes', emin=>-20,  emax=>80);
#   $app->{main}->{Style}->{list}->Append('exafs', $exafs);
#   $app->{main}->{Style}->{list}->Append('xanes', $xanes);
#   print $exafs->serialization, $xanes->serialization;

  $toolpanel -> SetSizerAndFit($toolbox);

  return $app;
};

sub OnRightDown {
  my ($this, $event) = @_;
  return if $::app->is_empty;
  # my $menu = Wx::Menu->new(q{});
  # $menu->AppendSubMenu($::app->{main}->{groupmenu},  "Group" );
  # $menu->AppendSubMenu($::app->{main}->{markmenu},   "Mark"  );
  # $menu->AppendSubMenu($::app->{main}->{plotmenu},   "Plot"  );
  # $menu->AppendSubMenu($::app->{main}->{freezemenu}, "Freeze");
  # $this->PopupMenu($menu, $event->GetPosition);
  $this->PopupMenu($::app->{main}->{groupmenu}, $event->GetPosition);
  $event->Skip(0);
};

sub OnDrag {
  my ($list, $event) = @_;
  if ($event->ControlDown) {
    my $which = $list->HitTest($event->GetPosition);
    my $source = Wx::DropSource->new( $list );
    my $dragdata = Demeter::UI::Artemis::DND::PlotListDrag->new(\$which);
    $source->SetData( $dragdata );
    $source->DoDragDrop(1);
    $event->Skip(0);
  } else {
    $event->Skip(1);
  };
};

sub OnMark {
  my ($this, $event, $clb) = @_;
  my $n = $event->GetInt;
  my $data = $clb->GetIndexedData($n);
  $data->marked($clb->IsChecked($n));
};

sub focus_up {
  my ($app) = @_;
  my $i = $app->{main}->{list}->GetSelection;
  return if ($i == 0);
  $app->{main}->{list}->SetSelection($i-1);
  $app->OnGroupSelect(q{}, $app->{main}->{list}->GetSelection, 0);
};
sub focus_down {
  my ($app) = @_;
  my $i = $app->{main}->{list}->GetSelection;
  return if ($i == $app->{main}->{list}->GetCount);
  $app->{main}->{list}->SetSelection($i+1);
  $app->OnGroupSelect(q{}, $app->{main}->{list}->GetSelection, 0);
};

sub move_group {
  my ($app, $dir) = @_;
  my $i = $app->{main}->{list}->GetSelection;

  return if (($dir eq 'up')   and ($i == 0));
  return if (($dir eq 'down') and ($i == $app->{main}->{list}->GetCount-1));

  my $from_object  = $app->{main}->{list}->GetIndexedData($i);
  my $from_label   = $app->{main}->{list}->GetString($i);
  my $from_checked = $app->{main}->{list}->IsChecked($i);

  my $to_label     = $app->{main}->{list}->GetString($i-1);

  $app->{main}->{list} -> DeleteData($i);
  my $to = ($dir eq 'down') ? $i+1 : $i-1;

  $app->{main}->{list} -> InsertData($from_label, $to, $from_object);
  $app->{main}->{list} -> Check($to, $from_checked);
  $app->{main}->{list} -> SetSelection($to);
  $app->OnGroupSelect(q{}, $app->{main}->{list}->GetSelection, 0);

  $app->modified(1);
  $app->{main}->status("Moved $from_label $dir");
};


sub OnGroupSelect {
  my ($app, $parent, $event, $plot) = @_;
  #$app->current_data->  pjoin(caller), $/;
  if ((ref($event) =~ m{Event}) and (not $event->IsSelection)) { # capture a control click which would otherwise deselect
    $app->{main}->{list}->SetSelection($app->{selected});
    $event->Skip(0);
    return;
  };
  my $is_index = (ref($event) =~ m{Event}) ? $event->GetSelection : $app->{main}->{list}->GetSelection;

  my $was = ((not defined($app->{selected})) or ($app->{selected} == -1)) ? 0 : $app->{main}->{list}->GetIndexedData($app->{selected});
  my $is  = $app->{main}->{list}->GetIndexedData($is_index);
  $app->{selecting_data_group}=1;

  my $view = $app->get_view($app->{main}->{views}->GetSelection);
  $app->make_page($view) if (not exists $app->{main}->{$view});
  my $showing = $app->{main}->{$view};
  if ($showing =~ m{XDI}) {
    $app->{main}->{XDI}->pull_values($was) if ($was and ($was ne $is));
  };

  if ($is_index != -1) {
    $showing->push_values($is, $plot);
    $showing->mode($is, 1, 0);
    $app->{selected} = $app->{main}->{list}->GetSelection;
  };
  $app->{main}->{groupmenu}  -> Enable($DATA_TEXT,($app->current_data and (-e $app->current_data->file)));
  $app->{main}->{energymenu} -> Enable($SHOW_REFERENCE,($app->current_data and $app->current_data->reference));
  $app->{main}->{energymenu} -> Enable($TIE_REFERENCE,($app->current_data and not $app->current_data->reference));

  my $n = $app->{main}->{list}->GetCount;
  foreach my $x ($PLOT_QUAD, $PLOT_IOSIG, $PLOT_K123, $PLOT_R123) {$app->{main}->{currentplotmenu} -> Enable($x, $n)};
  foreach my $x ($PLOT_E00, $PLOT_I0MARKED                      ) {$app->{main}->{markedplotmenu}  -> Enable($x, $n)};
  $app->set_mergedplot($app->current_data->is_merge);

  $app->select_plot($app->current_data) if $plot;
  $app->{selecting_data_group}=0;
  $app->heap_check(0);
  return;
};

sub select_plot {
  my ($app, $data) = @_;
  return if $app->is_empty;
  return if $app->{main}->{views}->GetSelection; # only on main window
  my $how = lc($data->co->default('athena', 'select_plot'));
  $data->po->start_plot;
  if ($how eq 'quad') {
    $app->quadplot($data);
  } elsif ($how eq 'k123') {
    $app->{main}->{PlotK}->pull_single_values;
    $data->plot('k123');
  } elsif ($how eq 'r123') {
    $app->{main}->{PlotR}->pull_single_values;
    $data->plot('k123');
  } elsif ($how =~ m{\A[ekrq]\z}) {
    $app->plot(0, 0, $how, 'single');
  }; # else $how is none
  return;
};


sub get_view {
  my ($app, $i) = @_;
  my @views = ('Main',		           # 0
	       'Calibrate',		   # 1
	       'Align',		           # 2
	       'Rebin',		           # 3
	       'DeglitchTruncate',	   # 4
	       'Smooth',		   # 5
	       'ConvoluteNoise',	   # 6
	       'Deconvolute',		   # 7
	       'SelfAbsorption',	   # 8
	       'MEE',	                   # 9
	       'Dispersive',	           # 10
	       'Series',		   # 11
	       'Summer',		   # 12
	       q{}, # -----------------------
	       'LCF',			   # 14
	       'PCA',			   # 15
	       'PeakFit',		   # 16
	       'LogRatio',		   # 17
	       'Difference',		   # 18
	       q{}, # -----------------------
	       'XDI',			   # 20
	       'Watcher',		   # 21
	       'Journal',		   # 22
	       'PluginRegistry',	   # 23
	       'Prefs',		           # 24
	      );
  my $watcher = 21;
  if (not Demeter->co->default(qw(athena show_dispersive))) {
    splice(@views, 10, 1);
    --$watcher;
  };
  if (not Demeter->co->default(qw(athena show_watcher))) {
    splice(@views, $watcher, 1);
  };
  return $views[$i];
};

sub make_page {
  my ($app, $view) = @_;
  my $busy = Wx::BusyCursor->new();
  Demeter->register_plugins if (($view eq 'PluginRegistry') and not @{Demeter->mo->Plugins});

  require "Demeter/UI/Athena/$view.pm";
  my $pm = "Demeter::UI::Athena::$view";
  $app->{main}->{$view} = $pm->new($app->{main}->{$view."_page"}, $app);
  $app->{main}->{$view."_page"}->SetSize($app->{main}->{"Main_page"}->GetSize);
  my $hh   = Wx::BoxSizer->new( wxVERTICAL );
  $hh  -> Add($app->{main}->{$view}, 1, wxGROW|wxEXPAND|wxALL, 0);
  $app->{main}->{$view."_sizer"} -> Add($hh, 1, wxEXPAND|wxALL, 0);

  #next if (not exists $app->{main}->{$which}->{document});
  #$app->{main}->{$view}->{document} -> Enable(0);

  #$hh -> Fit($app->{main}->{$view});
  $app->{main}->{$view."_page"} -> SetSizerAndFit($app->{main}->{$view."_sizer"});


  undef $busy;
};

sub view_changing {
  my ($app, $frame, $event) = @_;
  my $c = 5;
  --$c if (not Demeter->co->default(qw(athena show_dispersive)));
  --$c if (not Demeter->co->default(qw(athena show_watcher)));
  my $ngroups = $app->{main}->{list}->GetCount;
  my $nviews  = $app->{main}->{views}->GetPageCount;
  #print join("|", $app, $event, $nviews, $ngroups, $event->GetSelection), $/;

  my $prior = $app->{main}->{views}->GetPageText($app->{main}->{views}->GetSelection);

  my $string = $app->{main}->{views}->GetPageText($event->GetSelection);
  if ($string =~ m{\A-*\z}) {
    $event -> Veto();
  } else {
    ## create the view if it has not yet been seen
    my $i = $event->GetSelection;
    my $view = $app->get_view($i);
    $app->make_page($view) if ($view and (not exists $app->{main}->{$view}));

    if (($event->GetSelection != 0) and ($event->GetSelection < $nviews-$c)) {
      if (not $ngroups) {
	$app->{main}->status(sprintf("You have no data imported in Athena, thus you cannot use the %s tool.", lc($string)));
	$event -> Veto();
      };
    } else {

      $app->{main}->{XDI}->pull_values($app->current_data) if $prior =~ m{XDI};
      my $which = lc($app->{main}->{views}->GetPageText($event->GetSelection));
      $app->{main}->status(sprintf("Displaying the %s tool.", $which)) if ($which !~ m{main});
      #$app->{main}->{showing}=
    };
  };
};

sub marked_groups {
  my ($app) = @_;
  my @list = ();
  foreach my $i (0 .. $app->{main}->{list}->GetCount-1) {
    push(@list, $app->{main}->{list}->GetIndexedData($i)) if $app->{main}->{list}->IsChecked($i);
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
  my @is_fixed = map {$_->bkg_fixstep} @data;

  if (not @data and ($how eq 'marked')) {
    $app->{main}->status("No groups are marked.  Marked plot canceled.");
    return;
  };

  my $ok = $app->preplot($space, $data[0]);
  return if not $ok;
  my $pause = $data[0]->po->plot_pause*1000;
  ($pause = 0) if ($#data == 0);

  #$app->{main}->{Main}->pull_values($app->current_data);
  $app->pull_kweight($data[0], $how);

  $data[0]->po->single($how eq 'single');
  $data[0]->po->start_plot;
  my $title = ($how eq 'single')                                  ? q{}
            : ($app->{main}->{Other}->{title}->GetValue)          ? $app->{main}->{Other}->{title}->GetValue
            : ($app->{main}->{project}->GetLabel eq '<untitled>') ? 'marked groups'
	    :                                                       $app->{main}->{project}->GetLabel;
  $data[0]->po->title($title);

  my $sp = (lc($space) eq 'kq') ? 'K' : uc($space);
  $sp = 'E' if ($sp =~ m{\A(?:quad|)\z}i);
  $app->{main}->{'Plot'.$sp}->pull_single_values if ($how eq 'single');
  $app->{main}->{'Plot'.$sp}->pull_marked_values if ($how eq 'marked');
  $data[0]->po->chie(0) if (lc($space) eq 'kq');
  $data[0]->po->set(e_bkg=>0) if (($data[0]->datatype eq 'xanes') and (($how eq 'single')));


  ## energy k and kq
  if (lc($space) =~ m{(?:e|k|kq)}) {
    my $first_z = $data[0]->bkg_z;
    my $different = 0;
    if (($how eq 'single') and ($data[0]->datatype eq 'xanes') and (lc($space) =~ m{k})) {
	$::app->{main}->status("xanes data cannot be plotted in k.", 'alert');
	return;
    };
    if (($how eq 'single') and ($data[0]->datatype eq 'chi')   and (lc($space) eq q{e})) {
	$::app->{main}->status("chi data cannot be plotted in energy.", 'alert');
	return;
    };

    foreach my $d (@data) {
      next if (($d->datatype eq 'xanes') and (lc($space) =~ m{k}));
      next if (($d->datatype eq 'chi')   and (lc($space) =~ m{e}));
      $d->plot($space);
      ++$different if ($d->bkg_z ne $first_z);
      usleep($pause) if $pause;
    };
    $data[0]->plot_window('k') if (($how eq 'single') and
				   $app->{main}->{PlotK}->{win}->GetValue and
				   ($data[0]->datatype ne 'xanes') and
				   (lc($space) ne 'e'));
    if (lc($space) eq 'e') {
      $app->{main}->{plottabs}->SetSelection(1) if $app->spacetab;
    } else {
      $app->{main}->{plottabs}->SetSelection(2) if $app->spacetab;
    };
    if ((lc($space) eq 'e') and $different) {
      $::app->{main}->status("This marked-groups plot involved data measured on different elements.", 'alert');
    };

  ## R
  } elsif (lc($space) eq 'r') {
    if ($how eq 'single') {
      if ($data[0]->datatype ne 'xanes') {
	$data[0]->po->dphase($app->{main}->{PlotR}->{dphase}->GetValue);
	foreach my $which (qw(mag env re im pha)) {
	  if ($app->{main}->{PlotR}->{$which}->GetValue) {
	    $data[0]->po->r_pl(substr($which, 0, 1));
	    $data[0]->plot('r');
	  };
	};
	$data[0]->plot_window('r') if $app->{main}->{PlotR}->{win}->GetValue;
      } else {
	$::app->{main}->status("xanes data cannot be plotted in R.", 'alert');
      };
    } else {
      $data[0]->po->dphase($app->{main}->{PlotR}->{mdphase}->GetValue);
      foreach my $d (@data) {
	next if ($d->datatype eq 'xanes');
	$d->plot($space);
	usleep($pause) if $pause;
      };
    };
    $app->{main}->{plottabs}->SetSelection(3) if $app->spacetab;

  ## q
  } elsif (lc($space) eq 'q') {
    if ($how eq 'single') {
      if ($data[0]->datatype ne 'xanes') {
	foreach my $which (qw(mag env re im pha)) {
	  if ($app->{main}->{PlotQ}->{$which}->GetValue) {
	    $data[0]->po->q_pl(substr($which, 0, 1));
	    $data[0]->plot('q');
	  };
	};
	$data[0]->plot_window('q') if $app->{main}->{PlotQ}->{win}->GetValue;
      } else {
	$::app->{main}->status("xanes data cannot be plotted in q.", 'alert');
      };
    } else {
      foreach my $d (@data) {
	next if ($d->datatype eq 'xanes');
	$d->plot($space);
	usleep($pause) if $pause;
      };
    };
    $app->{main}->{plottabs}->SetSelection(4) if $app->spacetab;
  };

  ## I am not clear why this is necessary...
  foreach my $i (0 .. $#data) {
    my @save = $data[0]->get(qw(update_columns update_norm update_bkg update_fft update_bft));
    $data[$i]->bkg_fixstep($is_fixed[$i]);
    $data[$i]->set(update_columns => $save[0], update_norm => $save[1], update_bkg => $save[2],
		   update_fft     => $save[3], update_bft  => $save[4],);
  };
  $app->postplot($data[0], $is_fixed[0]);

  $app->{lastplot} = [$space, $how];
  $app->heap_check(0);
  my $this = $app->get_view($app->{main}->{views}->GetSelection);
  $app->{plotting} = 1;
  $app->OnGroupSelect(0,0,0);
  $app->{plotting} = 0;
  undef $busy;
};

sub image {
  my ($self, $terminal) = @_;

  my $on_screen = lc($::app->{lastplot}->[0]);
  if ($on_screen eq 'quad') {
    $::app->{main}->status("Cannot save a quad plot to an image file.", 'alert');
    return;
  };

  my $name = ($::app->{lastplot}->[1] eq 'single') ? $::app->current_data->name : $::app->{main}->{project}->GetLabel;
  $name =~ s{\s+}{_}g;

  my $suffix = $terminal;
  $terminal = 'pngcairo' if $terminal eq 'png';
  my $fd = Wx::FileDialog->new( $::app->{main}, "Save image file", cwd, join('.', $name, $suffix),
				"$suffix (*.$suffix)|*.$suffix|All files (*)|*",
				wxFD_SAVE|wxFD_CHANGE_DIR, # wxFD_OVERWRITE_PROMPT|
				wxDefaultPosition);
  if ($fd->ShowModal == wxID_CANCEL) {
    $::app->{main}->status("Saving image canceled.");
    return;
  };
  my $file = $fd->GetPath;
  return if $::app->{main}->overwrite_prompt($file); # work-around gtk's wxFD_OVERWRITE_PROMPT bug (5 Jan 2011)
  Demeter->po->image($file, $terminal);
  $::app->plot(q{}, q{}, @{$::app->{lastplot}});
  $::app->{main}->status("Saved $suffix image to \"$file\".");
};

sub spacetab {
  my ($app) = @_;
  my $n = $app->{main}->{plottabs}->GetSelection;
  return (($n > 0) and ($n < 5));
};

sub preplot {
  my ($app, $space, $data) = @_;
  if ($app->{main}->{Other}->{singlefile}->GetValue) {
    ## writing plot to a single file has been selected...
    my $fd = Wx::FileDialog->new( $app->{main}, "Save plot to a file", cwd, "plot.dat",
				  "Data (*.dat)|*.dat|All files (*)|*",
				  wxFD_SAVE|wxFD_CHANGE_DIR, #|wxFD_OVERWRITE_PROMPT,
				  wxDefaultPosition);
    if ($fd->ShowModal == wxID_CANCEL) {
      $app->{main}->status("Saving plot to a file has been canceled.");
      $app->{main}->{Other}->{singlefile}->SetValue(0);
      return 0;
    };
    ## set up for SingleFile backend
    my $file = $fd->GetPath;
    $app->{main}->{Other}->{singlefile}->SetValue(0), return
      if $app->{main}->overwrite_prompt($file); # work-around gtk's wxFD_OVERWRITE_PROMPT bug (5 Jan 2011)

    if (not $data) {
      foreach my $i (0 .. $app->{main}->{list}->GetCount-1) {
	if ($app->{main}->{list}->IsChecked($i)) {
	  $data = $app->{main}->{list}->GetIndexedData($i);
	  last;
	};
      };
    };
    $demeter->plot_with('singlefile');
    $data->po->prep(file     => $file,
		    standard => $data,
		    space    => $space);
    #$data->standard;
    #$data->po->space($space);
    #$demeter->po->file($fd->GetPath));
  };
  $data->po->plot_pause($app->{main}->{Other}->{pause}->GetValue);
  return 1;
};
sub postplot {
  my ($app, $data) = @_;
  ##if ($demeter->mo->template_plot eq 'singlefile') {
  my @save = $data->get(qw(update_columns update_norm update_bkg update_fft update_bft));
  if ($app->{main}->{Other}->{singlefile}->GetValue) {
    $demeter->po->finish;
    $app->{main}->status("Wrote plot data to ".$demeter->po->file);
    $demeter->plot_with($demeter->co->default(qw(plot plotwith)));
  } else {
    $data->standard;
    $app->{main}->{Indicators}->plot;
    $data->unset_standard;
  };
  my $is_fixed = $data->bkg_fixstep;
  if ($data eq $app->current_data) {
    my $was = $app->{modified};
    $app->{main}->{Main}->{bkg_step}->SetValue($app->current_data->bkg_step);
    $data->bkg_fixstep($is_fixed);
    $app->{main}->{Main}->{bkg_fixstep}->SetValue($is_fixed);
    $app->{plotting} = 1;
    $app->OnGroupSelect(q{}, $app->{main}->{list}->GetSelection, 0);
    $app->{modified} = $was;
  };
  $data->bkg_fixstep($is_fixed);
  $data->set(update_norm=>0, update_bkg=>0);
  $data->set(update_fft => $save[3], update_bft => $save[4],);

  $app->{main}->{Other}->{singlefile}->SetValue(0);
  return;
};

sub quadplot {
  my ($app, $data) = @_;
  if ($data->datatype eq 'xanes') {
    $app->plot(q{}, q{}, 'E', 'single')
  } elsif ($data->datatype eq 'chi') {
    $app->plot(q{}, q{}, 'k', 'single')
  } elsif ($data->mo->template_plot eq 'gnuplot') {
    my ($showkey, $fontsize) = ($data->po->showlegend, $data->co->default("gnuplot", "fontsize"));
    $data->po->showlegend(0);
    $data->co->set_default("gnuplot", "fontsize", 8);

    $app->{main}->{PlotE}->pull_single_values;
    $app->{main}->{PlotK}->pull_single_values;
    $app->{main}->{PlotR}->pull_marked_values;
    $app->{main}->{PlotQ}->pull_marked_values;
    $app->pull_kweight($data, 'single');
    $data->plot('quad');

    $data->po->showlegend($showkey);
    $data->co->set_default("gnuplot", "fontsize", $fontsize);
    $app->{lastplot} = ['quad', 'single'];
  } else {
    $app->plot(q{}, q{}, 'E', 'single')
  };
};

sub plot_e00 {
  my ($app) = @_;

  $app->preplot('e', $app->current_data);
  $app->{main}->{PlotE}->pull_marked_values;
  $app->current_data->po->set(e_mu=>1, e_markers=>0, e_zero=>1, e_bkg=>0, e_pre=>0, e_post=>0,
			      e_der=>0, e_sec=>0, e_i0=>0, e_signal=>0); #e_norm=>1, 
  $app->current_data->po->start_plot;
  $app->current_data->po->title($app->{main}->{Other}->{title}->GetValue || $app->{main}->{project}->GetLabel);
  foreach my $i (0 .. $app->{main}->{list}->GetCount-1) {
    $app->{main}->{list}->GetIndexedData($i)->plot('e')
      if $app->{main}->{list}->IsChecked($i);
  };
  $app->current_data->po->set(e_zero=>0, e_markers=>1);
  $app->postplot($app->current_data);
};
sub plot_i0_marked {
  my ($app) = @_;

  $app->preplot('e', $app->current_data);
  $app->{main}->{PlotE}->pull_single_values;
  $app->current_data->po->set(e_mu=>0, e_markers=>0, e_zero=>0, e_bkg=>0, e_pre=>0, e_post=>0,
			      e_norm=>0, e_der=>0, e_sec=>0, e_i0=>1, e_signal=>0);
  $app->current_data->po->start_plot;
  $app->current_data->po->title($app->{main}->{Other}->{title}->GetValue || $app->{main}->{project}->GetLabel);
  foreach my $i (0 .. $app->{main}->{list}->GetCount-1) {
    $app->{main}->{list}->GetIndexedData($i)->plot('e')
      if $app->{main}->{list}->IsChecked($i);
  };
  $app->current_data->po->set(e_i0=>0, e_markers=>1);
  $app->postplot($app->current_data);
};

sub plot_norm_scaled {
  my ($app) = @_;

  $app->preplot('e', $app->current_data);
  $app->{main}->{PlotE}->pull_single_values;
  $app->current_data->po->set(e_mu=>1, e_markers=>0, e_zero=>0, e_bkg=>0, e_pre=>0, e_post=>0,
			      e_norm=>1, e_der=>0, e_sec=>0, e_i0=>0, e_signal=>0);
  $app->current_data->po->start_plot;
  $app->current_data->po->title($app->{main}->{Other}->{title}->GetValue || $app->{main}->{project}->GetLabel);
  foreach my $i (0 .. $app->{main}->{list}->GetCount-1) {
    my $data = $app->{main}->{list}->GetIndexedData($i);
    my $save = $data->plot_multiplier;
    $data->plot_multiplier($data->bkg_step);
    $data->plot('e') if $app->{main}->{list}->IsChecked($i);
    $data->plot_multiplier($save);
  };
  $app->current_data->po->set(e_markers=>1);
  $app->postplot($app->current_data);
};

## take care to update kweights only when they have changed to avoid
## having the Plot object update everyone's update_fft attribute
sub pull_kweight {
  my ($app, $data, $how) = @_;
  my $kw = $app->{main}->{kweights}->GetStringSelection;
  if ($kw eq 'kw') {
    #$data->po->kweight($data->fit_karb_value);
    if ($how eq 'single') {
      if ($app->{update_kweights}) {
	$data->po->kweight($data->fit_karb_value);
	$app->{update_kweights}=0;
      };
    } else {
      ## check to see if marked groups all have the same arbitrary k-weight
      my @kweights = map {$_->fit_karb_value} $app->marked_groups;
      my $nuniq = grep {abs($_-$kweights[0]) > $EPSILON2} @kweights;
      if ($app->{update_kweights}) {
	$data->po->kweight($data->fit_karb_value);
	$data->po->kweight(-1) if $nuniq; # variable k-weighting if not all the same
	$app->{update_kweights}=0;
      };
    };
  } else {
    if ($app->{update_kweights}) {
      $data->po->kweight($kw);
	$app->{update_kweights}=0;
      };
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
  if (ref($how) =~ m{Demeter}) {
    foreach my $i (0 .. $clb->GetCount-1) {
      if ($clb->GetIndexedData($i)->group eq $how->group) {
	$clb->Check($i,1);
	$clb->GetIndexedData($i)->marked(1);
	last;
      };
    };
  } elsif ($how eq 'toggle') {
    $clb->Check($clb->GetSelection, not $clb->IsChecked($clb->GetSelection));
    $clb->GetIndexedData($::app->current_index)->marked($clb->IsChecked($::app->current_index));
    return;

  } elsif ($how =~ m{all|none|invert}) {
    foreach my $i (0 .. $clb->GetCount-1) {
      my $val = ($how eq 'all')    ? 1
	      : ($how eq 'none')   ? 0
	      : ($how eq 'invert') ? not $clb->IsChecked($i)
	      :                     $clb->IsChecked($i);
      $clb->Check($i, $val);
      $clb->GetIndexedData($i)->marked($val);
    };

  } else {			# regexp mark or unmark
    my $word = ($how eq 'regexp') ? 'Mark' : 'Unmark';
    my $ted = Wx::TextEntryDialog->new( $app->{main}, "$word data groups matching this regular expression:", "Enter a regular expression", q{}, wxOK|wxCANCEL, Wx::GetMousePosition);
    $app->set_text_buffer($ted, "regexp");
    if ($ted->ShowModal == wxID_CANCEL) {
      $app->{main}->status($word."ing by regular expression canceled.");
      $app->{regexp_pointer} = $#{$app->{regexp_buffer}}+1;
      return;
    };
    $regex = $ted->GetValue;
    my $re;
    my $is_ok = eval '$re = qr/$regex/';
    if (not $is_ok) {
      $app->{main}->status("Oops!  \"$regex\" is not a valid regular expression");
      $app->{regexp_pointer} = $#{$app->{regexp_buffer}}+1;
      return;
    };
    $app->update_text_buffer("regexp", $regex, 1);

    foreach my $i (0 .. $clb->GetCount-1) {
      next if ($clb->GetIndexedData($i)->name !~ m{$re});
      my $val = ($how eq 'regexp') ? 1 : 0;
      $clb->Check($i, $val);
      $clb->GetIndexedData($i)->marked($val);
    };
  };
  if (ref($how) !~ m{Demeter}) {
    my $text = $mark_feeedback{$how};
    $text .= '/'.$regex.'/' if ($how =~ m{regexp});
    $app->{main}->status($text);
  };
};

sub find_wl {
  my ($app, $how) = @_;
  my $clb = $app->{main}->{list};
  return if not $clb->GetCount;

  my $busy = Wx::BusyCursor->new();
  $app->{main}->status("Finding white line positions for $how groups", 'wait');
  my $max = 0;
  foreach my $i (0 .. $app->{main}->{list}->GetCount-1) {
    next if (($how eq 'marked') and (not $app->{main}->{list}->IsChecked($i)));
    $max = max($max, length($app->{main}->{list}->GetIndexedData($i)->name));
  };
  $max += 2;

  my $format  = '  %-'.$max.'s     %9.3f'."\n";
  my $tformat = '# %-'.$max.'s     %s'."\n";
  my $text = sprintf($tformat, 'group', 'white line position');
  $text .= '# ' . '=' x 50 . "\n";
  foreach my $i (0 .. $clb->GetCount-1) {
    next if (($how eq 'marked') and not $clb->IsChecked($i));
    $text .= sprintf($format, '"'.$clb->GetIndexedData($i)->name.'"', $clb->GetIndexedData($i)->find_white_line);
  };
  my $dialog = Demeter::UI::Artemis::ShowText
    -> new($app->{main}, $text, "White line positions")
      -> Show;
  $app->{main}->status("Found white line positions");
  undef $busy;
};

sub quench {
  my ($app, $how) = @_;
  my $clb = $app->{main}->{list};
  return if not $clb->GetCount;

  my $regex = q{};

  given ($how) {
    when ('toggle') {
      $app->current_data->quenched(not $app->current_data->quenched);
    };

    when (m{all|none|invert}) {
      foreach my $i (0 .. $clb->GetCount-1) {
	my $val = ($how eq 'all')    ? 1
	        : ($how eq 'none')   ? 0
	        : ($how eq 'invert') ? not $clb->GetIndexedData($i)->quenched
	        :                      $clb->GetIndexedData($i)->quenched;
	$clb->GetIndexedData($i)->quenched($val);
      };
    };

    when (m{marked}) {
      foreach my $i (0 .. $clb->GetCount-1) {
	next if not $clb->IsChecked($i);
	my $val = ($how eq 'marked') ? 1 : 0;
	$clb->GetIndexedData($i)->quenched($val);
      };
    };

    when (m{regex}) {
      my $word = ($how eq 'regex') ? 'Freeze' : 'Unfreeze';
      my $ted = Wx::TextEntryDialog->new( $app->{main}, "$word data groups matching this regular expression:", "Enter a regular expression", q{}, wxOK|wxCANCEL, Wx::GetMousePosition);
      $app->set_text_buffer($ted, "regexp");
      if ($ted->ShowModal == wxID_CANCEL) {
	$app->{main}->status(chomp($word)."ing by regular expression canceled.");
	$app->{regexp_pointer} = $#{$app->{regexp_buffer}}+1;
	return;
      };
      $regex = $ted->GetValue;
      my $re;
      my $is_ok = eval '$re = qr/$regex/';
      if (not $is_ok) {
	$app->{main}->status("Oops!  \"$regex\" is not a valid regular expression");
	$app->{regexp_pointer} = $#{$app->{regexp_buffer}}+1;
	return;
      };
      $app->update_text_buffer("regexp", $regex, 1);

      foreach my $i (0 .. $clb->GetCount-1) {
	next if ($clb->GetIndexedData($i)->name !~ m{$re});
	my $val = ($how eq 'regex') ? 1 : 0;
	$clb->GetIndexedData($i)->quenched($val);
      };

    };
  };
  $app->OnGroupSelect(0,0,0);
};

sub merge {
  my ($app, $how, $noplot) = @_;
  return if $app->is_empty;
  $noplot ||= 0;
  my $busy = Wx::BusyCursor->new();
  my @data = ();
  my $max = 0;
  foreach my $i (0 .. $app->{main}->{list}->GetCount-1) {
    my $this = $app->{main}->{list}->GetIndexedData($i);
    if ($this->name =~ m{\A\s*merge\s*(\d*)\s*\z}) {
      $max = $1 if (looks_like_number($1) and ($1 > $max));
      $max ||= 1;
    };
    push(@data, $this) if $app->{main}->{list}->IsChecked($i);
  };
  if (not @data) {
    $app->{main}->status("No groups are marked.  Merge canceled.");
    undef $busy;
    return;
  };

  $app->{main}->status("Merging marked groups");
  my $merged = $data[0]->merge($how, @data);
  $max = q{} if not $max;
  $max = sprintf(" %d", $max+1) if $max;
  $merged->name('merge'.$max);
  $app->{main}->{list}->AddData($merged->name, $merged);
  my $n = 1;

  if ($data[0] -> reference) {
    my @refs = grep {$_} map  {$_->reference} @data;
    $app->{main}->status("Merging marked groups");
    my $refmerged = $refs[0]->merge($how, @refs);
    $refmerged->name("  Ref ". $merged->name);
    $refmerged->reference($merged);
    $app->{main}->{list}->AddData($refmerged->name, $refmerged);
    $n = 2;
  };

  $app->{main}->{list}->SetSelection($app->{main}->{list}->GetCount-$n);
  $app->OnGroupSelect(q{}, $app->{main}->{list}->GetSelection, 0);
  $app->{main}->{Main}->mode($merged, 1, 0);
  $app->{main}->{list}->Check($app->{main}->{list}->GetCount-$n, 1);
  $merged->marked(1);
  $app->modified(1);

  ## handle plotting, respecting the choice in the athena->merge_plot config parameter
  if (not $noplot) {
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
  };
  $app->{main}->status("Made merged data group");
  $app->{main}->status($merged->annotation, 'alert') if $merged->annotation;
  $app->heap_check(0);
  undef $busy;
};

sub modified {
  my ($app, $is_modified) = @_;
  $app->{modified} += $is_modified;
  $app->{modified} = 0 if not $is_modified;
  $app->{main}->{save}->Enable($is_modified);
  my $token = ($is_modified) ? q{*} : q{ };
  $app->{main}->{token}->SetLabel($token);
  #   my $projname = $app->{main}->{project}->GetLabel;
  #   return if ($projname eq '<untitled>');
  #   $projname = substr($projname, 1) if ($projname =~ m{\A\*});
  #   $projname = '*'.$projname if ($is_modified);
  #   $app->{main}->{project}->SetLabel($projname);

  my $c = $app->{main}->{save_start_color};
  $app->{main}->{save}->SetBackgroundColour($c) if not $is_modified;
  my $j = $demeter->co->default('athena', 'save_alert');
  $app->autosave if ($app->{modified} % $demeter->co->default('athena', 'autosave_frequency') == 0);
  return if ($j <= 0);
  my $n = min( 1, $app->{modified}/$j );
  if ($app->{modified}) {
    my ($r, $g, $b) = ($c->Red, $c->Green, $c->Blue);
    $r = int( min ( 255, $r + (255 - $r) * 2 * $n ) );
    $g = int($g * (1-$n));
    $b = int($b * (1-$n));
    ##print join(" ", $r, $g, $b, $n, $app->{modified}, $is_modified, $j, caller), $/;
    $app->{main}->{save}->SetBackgroundColour(Wx::Colour->new($r, $g, $b));
  } else {
    $app->{main}->{save}->SetBackgroundColour($c);
  };
};

sub autosave {
  my ($app, $j) = @_;
  return if ($app->{modified} == 0);
  return if not $demeter->co->default('athena', 'autosave');
  return if ($demeter->co->default('athena', 'autosave_frequency') < 1);
  $app->{main}->status("Performing autosave ...", "wait|nobuffer");
  $app -> Export('all', File::Spec->catfile($demeter->stash_folder, $AUTOSAVE_FILE));
  $app->{main}->status("Successfully performed autosave.");
};

sub Clear {
  my ($app) = @_;
  $app->{main}->{currentproject} = q{};
  $app->{main}->{project}->SetLabel('<untitled>');
  $app->modified(not $app->is_empty);
  $app->{main}->status(sprintf("Unamed the current project."));
};

## in future times, check to see if Ifeffit is being used
sub heap_check {
  my ($app, $show) = @_;
  return if Demeter->is_larch;
  if ($app->current_data->mo->heap_used > 0.98) {
    $app->{main}->status("You have used all of Ifeffit's memory!  It is likely that your data is corrupted!", "error");
  } elsif ($app->current_data->mo->heap_used > 0.95) {
    $app->{main}->status("You have used more than 95% of Ifeffit's memory.  Save your work!", "error");
  } elsif ($app->current_data->mo->heap_used > 0.9) {
    $app->{main}->status("You have used more than 90% of Ifeffit's memory.  Save your work!", "error");
  } elsif ($show) {
    $app->current_data->ifeffit_heap;
    $app->{main}->status(sprintf("You are currently using %.1f%% of Ifeffit's %.1f Mb of memory",
				 100*$app->current_data->mo->heap_used,
				 $app->current_data->mo->heap_free/(1-$app->current_data->mo->heap_used)/2**20));
  };
};

sub show_epsilon {
  my ($app) = @_;
  my $clb = $app->{main}->{list};
  return if not $clb->GetCount;
  my $busy = Wx::BusyCursor->new();
  my $text = sprintf("\n%-25s : %9s  %9s\n", qw(group epsilon_k epsilon_r));
  $text .= '=' x 48 . "\n";
  foreach my $i (0 .. $clb->GetCount-1) {
    next if not $clb->IsChecked($i);
    my $d = $clb->GetIndexedData($i);
    $d -> _update('bft');
    $text .= sprintf("%-25s : %9.3e  %9.3e\n", $d->name, $d->epsk, $d->epsr);
  };
  undef $busy;
  my $dialog = Demeter::UI::Artemis::ShowText
    -> new($app->{main}, $text, 'Measurement uncertainties')
      -> Show;
};


sub document {
  my ($app, $doc, $target) = @_;
  my $file;
  my @path = ('Demeter', 'UI', 'Athena', 'share', 'aug', 'html');
  my $url = Demeter->co->default('athena', 'doc_url');
  if (any {$doc eq $_} (qw(analysis bkg examples import other output params plot process ui))) {
    push @path, $doc;
    $file = 'index';
    $url .= $doc . '/index.html';
  } elsif ($doc =~ m{\.}) {
    my @parts = split(/\./, $doc);
    push @path, $parts[0];
    $file = $parts[1];
    $url .= $parts[0] . '/' . $parts[1] . ".html";
  } else {
    $file = $doc;
    $url .= $doc . '.html';
  };
  my $fname = File::Spec->catfile(dirname($INC{'Demeter.pm'}), @path, $file.'.html');
  if (-e $fname) {
    $fname  = 'file://'.$fname;
    $fname .= '#'.$target if $target;
    $::app->{main}->status("Displaying local document page: $fname");
    Wx::LaunchDefaultBrowser($fname);
  } else {
    $url .= '#'.$target if $target;
    $::app->{main}->status("Displaying online document page: $url");
    Wx::LaunchDefaultBrowser($url);
    ##$::app->{main}->status("Document target not found: $fname");
  };
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
and the log buffer.  $type of "nobuffer" will display the status
message, but not push it into the buffer.

=cut

package Wx::Frame;
use Wx qw(wxNullColour);
use Demeter::UI::Wx::OverwritePrompt;
my $normal = wxNullColour;
my $wait   = Wx::Colour->new("#C5E49A");
my $alert  = Wx::Colour->new("#FCDD9F");
my $error  = Wx::Colour->new("#FD7E6F");
my $debug  = 0;
sub status {
  my ($self, $text, $type) = @_;
  $type ||= 'normal';

  if ($debug) {
    local $|=1;
    print $text, " -- ", join(", ", (caller)[0,2]), $/;
  };

  my $color = ($type =~ m{normal}) ? $normal
            : ($type =~ m{alert})  ? $alert
            : ($type =~ m{wait})   ? $wait
            : ($type =~ m{error})  ? $error
	    :                        $normal;
  $self->GetStatusBar->SetBackgroundColour($color);
  $self->GetStatusBar->SetStatusText($text);
  return if ($type =~ m{nobuffer});
  $self->{Status}->put_text($text, $type);
  $self->Refresh;
};

# sub OnCreateStatusBar {
#   my ($self, $number, $style, $id, $name);
#   print "Hi!\n";
#   return Demeter::UI::Wx::EchoArea->new($self);
# };

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
  $clb->Check($clb->GetCount-1, $data->marked);
  push @{$clb->{datalist}}, $data;
  $::app->{most_recent} = $data;
};

sub InsertData {
  my ($clb, $name, $n, $data) = @_;
  $clb->Insert($name, $n);
  my @list = @{$clb->{datalist}};
  splice(@list, $n, 0, $data);
  $clb->{datalist} = \@list;
};

sub GetIndexedData {
  my ($clb, $n) = @_;
  return $clb->{datalist}->[$n];
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


package Demeter::UI::Athena::DropTarget;

use Wx qw( :everything);
use base qw(Wx::DropTarget);
use Demeter::UI::Artemis::DND::PlotListDrag;

use Scalar::Util qw(looks_like_number);

sub new {
  my $class = shift;
  my $this = $class->SUPER::new;

  my $data = Demeter::UI::Artemis::DND::PlotListDrag->new();
  $this->SetDataObject( $data );
  $this->{DATA} = $data;
  return $this;
};

sub OnData {
  my ($this, $x, $y, $def) = @_;

  my $list = $::app->{main}->{list};
  return 0 if not $list->GetCount;
  $this->GetData;		# this line is what transfers the data from the Source to the Target

  my $from = ${ $this->{DATA}->{Data} };
  my $from_object  = $list->GetIndexedData($from);
  my $from_label   = $list->GetString($from);
  my $from_checked = $list->IsChecked($from);
  my $point = Wx::Point->new($x, $y);
  my $to = $list->HitTest($point);
  my $to_label   = $list->GetString($to);

  return 0 if ($to == $from);	# either of these two would leave the list in the same state
#  return 0 if ($to == $from+1);

  my $message;
  $list -> DeleteData($from);
  if ($to == -1) {
    $list -> AddData($from_label, $from_object);
    $list -> Check($list->GetCount-1, $from_checked);
    $::app->{main}->{list}->SetSelection($from);
    $message = sprintf("Moved '%s' to the last position.", $from_label);
  } else {
    $message = sprintf("Moved '%s' above %s.", $from_label, $to_label);
    --$to if ($from < $to);
    $list -> InsertData($from_label, $to, $from_object);
    #$list -> SetClientData($to, $from_object);
    $list -> Check($to, $from_checked);
    $::app->{main}->{list}->SetSelection($to);
  };
  $::app->OnGroupSelect(q{}, $::app->{main}->{list}->GetSelection, 0);
  $::app->modified(1);
  $::app->{main}->status($message);

  return $def;
};

1;



=head1 NAME

Demeter::UI::Athena - XAS data processing

=head1 VERSION

This documentation refers to Demeter version 0.9.18.

=head1 SYNOPSIS

This short program launches Athena:

  use Wx;
  use Demeter::UI::Athena;
  Wx::InitAllImageHandlers();
  my $window = Demeter::UI::Athena->new;
  $window -> MainLoop;

=head1 DESCRIPTION

Athena is ...

=head1 USE

Using ...

=head1 CONFIGURATION

Many aspects of Athena and its UI are configurable using the
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

L<http://bruceravel.github.com/demeter/>

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2013 Bruce Ravel (bravel AT bnl DOT gov). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
