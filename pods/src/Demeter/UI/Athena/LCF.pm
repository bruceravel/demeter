package Demeter::UI::Athena::LCF;
use strict;
use warnings;

use Wx qw( :everything );
use base 'Wx::Panel';
use Wx::Event qw(EVT_BUTTON EVT_CHECKBOX EVT_COMBOBOX EVT_RADIOBOX EVT_LIST_ITEM_SELECTED EVT_TEXT_ENTER);
use Wx::Perl::TextValidator;

use Demeter::LCF;
use Demeter::UI::Wx::SpecialCharacters qw(:all);

use Cwd;
use File::Basename;
use File::Spec;
use Scalar::Util qw(looks_like_number);

use vars qw($label);
$label = "Linear combination fitting";	# used in the Choicebox and in status bar messages to identify this tool

my $tcsize   = [60,-1];
my $icon     = File::Spec->catfile(dirname($INC{"Demeter/UI/Athena.pm"}), 'Athena', , 'icons', "bullseye.png");
my $bullseye = Wx::Bitmap->new($icon, wxBITMAP_TYPE_PNG);

sub new {
  my ($class, $parent, $app) = @_;
  my $this = $class->SUPER::new($parent, -1, wxDefaultPosition, wxDefaultSize, wxMAXIMIZE_BOX );

  my $box = Wx::BoxSizer->new( wxVERTICAL);
  $this->{sizer}  = $box;

  $this->{LCF} = Demeter::LCF->new(include_caller=>0);
  $this->{emin} = Demeter->co->default('lcf', 'emin');
  $this->{emax} = Demeter->co->default('lcf', 'emax');
  $this->{kmin} = Demeter->co->default('lcf', 'kmin');
  $this->{kmax} = Demeter->co->default('lcf', 'kmax');
  $this->{pastspace} = 0;

  my $hbox = Wx::BoxSizer->new( wxHORIZONTAL );
  $box->Add($hbox, 0, wxGROW|wxLEFT|wxRIGHT, 5);
  $hbox->Add(Wx::StaticText->new($this, -1, 'Fit range:'), 0, wxRIGHT|wxALIGN_CENTRE, 5);
  $this->{xmin} = Wx::TextCtrl->new($this, -1, $this->{emin}, wxDefaultPosition, $tcsize, wxTE_PROCESS_ENTER);
  $hbox->Add($this->{xmin}, 0, wxLEFT|wxRIGHT|wxALIGN_CENTRE, 5);
  $this->{xmin_pluck} = Wx::BitmapButton -> new($this, -1, $bullseye);
  $hbox->Add($this->{xmin_pluck}, 0, wxRIGHT|wxALIGN_CENTRE, 5);

  $hbox->Add(Wx::StaticText->new($this, -1, 'to'), 0, wxRIGHT|wxALIGN_CENTRE, 5);
  $this->{xmax} = Wx::TextCtrl->new($this, -1, $this->{emax}, wxDefaultPosition, $tcsize, wxTE_PROCESS_ENTER);
  $hbox->Add($this->{xmax}, 0, wxLEFT|wxRIGHT|wxALIGN_CENTRE, 5);
  $this->{xmax_pluck} = Wx::BitmapButton -> new($this, -1, $bullseye);
  $hbox->Add($this->{xmax_pluck}, 0, wxRIGHT|wxALIGN_CENTRE, 5);

  $this->{space} = Wx::RadioBox->new($this, -1, 'Fitting space', wxDefaultPosition, wxDefaultSize,
				     ["norm $MU(E)", "deriv $MU(E)", "$CHI(k)"],
				     1, wxRA_SPECIFY_ROWS);
  $hbox->Add($this->{space}, 0, wxLEFT|wxRIGHT|wxALIGN_CENTRE, 5);
  $this->{space}->SetSelection(0);
  EVT_RADIOBOX($this, $this->{space}, sub{OnSpace(@_)});
  $this->{xmin} -> SetValidator( Wx::Perl::TextValidator->new( qr([-0-9.]) ) );
  $this->{xmax} -> SetValidator( Wx::Perl::TextValidator->new( qr([-0-9.]) ) );
  EVT_TEXT_ENTER($this, $this->{xmin}, sub{plot(@_)});
  EVT_TEXT_ENTER($this, $this->{xmax}, sub{plot(@_)});

  $this->{document} = Wx::Button->new($this, -1, 'Document section: LCF');
  $this->{notebook} = Wx::Notebook->new($this, -1, wxDefaultPosition, wxDefaultSize, wxNB_TOP);
  $box -> Add($this->{notebook}, 1, wxGROW|wxALL, 2);
  my $main   = $this->main_page($this->{notebook});
  my $fits   = $this->fit_page($this->{notebook});
  my $combi  = $this->combi_page($this->{notebook});
  my $marked = $this->marked_page($this->{notebook});
  $this->{notebook} ->AddPage($main,   'Standards',     1);
  $this->{notebook} ->AddPage($fits,   'Fit results',   0);
  $this->{notebook} ->AddPage($combi,  'Combinatorics', 0);
  $this->{notebook} ->AddPage($marked, 'Sequence',      0);


  #$box -> Add($this->{document}, 0, wxGROW|wxALL, 2);
  EVT_BUTTON($this, $this->{document}, sub{  $app->document("analysis.lcf")});
  EVT_BUTTON($this, $this->{xmin_pluck}, sub{Pluck(@_, 'xmin')});
  EVT_BUTTON($this, $this->{xmax_pluck}, sub{Pluck(@_, 'xmax')});
  $this->{xmin_pluck}->Enable(0);
  $this->{xmax_pluck}->Enable(0);

  $this->SetSizerAndFit($box);
  return $this;
};

sub main_page {
  my ($this, $nb) = @_;
  my $panel = Wx::Panel->new($nb, -1, wxDefaultPosition, wxDefaultSize, wxMAXIMIZE_BOX );
  my $box = Wx::BoxSizer->new( wxVERTICAL);

  my $hbox = Wx::BoxSizer->new( wxHORIZONTAL );
  $box -> Add($hbox, 0, wxALL|wxGROW, 5);
  $hbox->Add(Wx::StaticText->new($panel, -1, '       Standards', wxDefaultPosition, [180,-1]), 0, wxLEFT|wxRIGHT, 5);
  $hbox->Add(Wx::StaticText->new($panel, -1, 'Weight',   wxDefaultPosition, $tcsize), 0, wxLEFT|wxRIGHT, 10);
  $hbox->Add(Wx::StaticText->new($panel, -1, 'E0',), 0, wxLEFT|wxRIGHT, 10);
  $hbox->Add(Wx::StaticText->new($panel, -1, 'Fit E0'),   0, wxLEFT|wxRIGHT, 10);
  $hbox->Add(Wx::StaticText->new($panel, -1, 'Required'), 0, wxLEFT|wxRIGHT, 10);

  $this->{window} = Wx::ScrolledWindow->new($panel, -1, wxDefaultPosition, wxDefaultSize, wxVSCROLL);
  my $winbox  = Wx::GridBagSizer->new( 2,2 );
  $this->{window} -> SetSizer($winbox);
  $this->{window} -> SetScrollbars(0, 20, 0, 50);

  $this->{nstan} = Demeter->co->default('lcf', 'nstan');
  foreach my $i (0 .. $this->{nstan}-1) {
    $this->add_standard($this->{window}, $winbox, $i);
  };
  $box -> Add($this->{window}, 1, wxALL|wxGROW, 5);

  $hbox = Wx::BoxSizer->new( wxHORIZONTAL );
  $box -> Add($hbox, 2, wxLEFT|wxRIGHT|wxGROW, 5);

  my $vbox = Wx::BoxSizer->new( wxVERTICAL );
  $hbox -> Add($vbox, 1, wxGROW|wxALL, 5);


  ## ------------- fitting options
  my $optionsbox       = Wx::StaticBox->new($panel, -1, 'Options', wxDefaultPosition, wxDefaultSize);
  my $optionsboxsizer  = Wx::StaticBoxSizer->new( $optionsbox, wxVERTICAL );
  $vbox -> Add($optionsboxsizer, 0, wxGROW|wxALL, 5);
  $this->{components} = Wx::CheckBox->new($panel, -1, 'Plot weighted components');
  $this->{residual}   = Wx::CheckBox->new($panel, -1, 'Plot residual');
  $this->{inclusive}  = Wx::CheckBox->new($panel, -1, 'All weights between 0 and 1');
  $this->{unity}      = Wx::CheckBox->new($panel, -1, 'Force weights to sum to 1');
  $this->{linear}     = Wx::CheckBox->new($panel, -1, 'Add a linear term after E0');
  $this->{one_e0}     = Wx::CheckBox->new($panel, -1, 'All standards share an E0');
  $this->{reset}      = Wx::Button->new($panel, -1, 'Reset', wxDefaultPosition, wxDefaultSize, wxBU_EXACTFIT);
  $this->{spacer}     = Wx::StaticLine->new($panel, -1, wxDefaultPosition, [0,0], wxLI_HORIZONTAL);

  $::app->mouseover($this->{components},  "Include the weighted components in the plot.");
  $::app->mouseover($this->{residual},    "Include the residual from the fit in the plot.");
  $::app->mouseover($this->{inclusive},   "Force all weights to evaluate to values between 0 and 1.");
  $::app->mouseover($this->{unity},       "Force the weights to sum to 1, otherwise allow the weight of each group to float.");
  $::app->mouseover($this->{linear},      "Include a linear component (m*E + b) in the fit which is only evaluated after E0.");
  $::app->mouseover($this->{one_e0},      "Force the standards to share a single E0 parameter.  This is equivalent (albeit with a sign change) to floating E0 for the data.");
  $::app->mouseover($this->{reset},       "Reset all LCF parameters to their default values.");


  #$optionsboxsizer->Add($this->{$_}, 0, wxGROW|wxALL, 0)
  #  foreach (qw(components residual spacer inclusive unity spacer linear one_e0 usemarked reset));
  $optionsboxsizer->Add($this->{$_}, 0, wxGROW|wxALL, 0)
    foreach (qw(components residual));
  #$optionsboxsizer->Add($this->{spacer}, 0, wxALL, 3);
  $optionsboxsizer->Add($this->{$_}, 0, wxGROW|wxALL, 0)
    foreach (qw(inclusive unity));
  #$optionsboxsizer->Add($this->{spacer}, 0, wxALL, 3);
  $optionsboxsizer->Add($this->{$_}, 0, wxGROW|wxALL, 0)
    foreach (qw(linear one_e0));
  $optionsboxsizer->Add($this->{spacer}, 0, wxALL, 3);

  $this->{components} -> SetValue(Demeter->co->default('lcf', 'components'));
  $this->{residual}   -> SetValue(Demeter->co->default('lcf', 'difference'));
  $this->{$_} -> SetValue(0) foreach (qw(linear one_e0));
  $this->{$_} -> SetValue(Demeter->co->default('lcf', $_)) foreach (qw(inclusive unity));
  $this->{linear}->Enable(0) if (Demeter->mo->template_analysis ne 'larch');

  my $noisebox = Wx::BoxSizer->new( wxHORIZONTAL );
  $optionsboxsizer->Add($noisebox, 0, wxGROW|wxALL, 1);
  $noisebox->Add(Wx::StaticText->new($panel, -1, 'Add noise'), 0, wxRIGHT|wxALIGN_CENTRE, 5);
  $this->{noise} = Wx::TextCtrl->new($panel, -1, 0, wxDefaultPosition, $tcsize, wxTE_PROCESS_ENTER);
  $this->{noise} -> SetValidator( Wx::Perl::TextValidator->new( qr([0-9.]) ) );
  $noisebox->Add($this->{noise}, 0, wxLEFT|wxRIGHT|wxALIGN_CENTRE, 5);
  $noisebox->Add(Wx::StaticText->new($panel, -1, 'to data'), 0, wxRIGHT|wxALIGN_CENTRE, 5);

  my $ninfobox = Wx::BoxSizer->new( wxHORIZONTAL );
  $optionsboxsizer->Add($ninfobox, 0, wxGROW|wxALL, 1);
  $ninfobox->Add(Wx::StaticText->new($panel, -1, 'Information content'), 0, wxRIGHT|wxALIGN_CENTRE, 5);
  $this->{ninfo} = Wx::TextCtrl->new($panel, -1, 0, wxDefaultPosition, $tcsize, wxTE_PROCESS_ENTER);
  $this->{ninfo} -> SetValidator( Wx::Perl::TextValidator->new( qr([0-9.]) ) );
  $ninfobox->Add($this->{ninfo}, 0, wxLEFT|wxRIGHT|wxALIGN_CENTRE, 5);

  $::app->mouseover($this->{noise}, "Add randomly distributed noise, scaled by this amount, to the data before doing the fit.");
  if (Demeter->is_ifeffit) {
    $::app->mouseover($this->{ninfo}, "This displays Athena's estimate of the information content, which is not currently used in the fit.");
  } else {
    $::app->mouseover($this->{ninfo}, "Specify the information content of your data.  If 0, Athena will estimate the information content.");
  };


  ## ------------- combinatorics options
  my $combinbox       = Wx::StaticBox->new($panel, -1, 'Combinatorics', wxDefaultPosition, wxDefaultSize);
  my $combinboxsizer  = Wx::StaticBoxSizer->new( $combinbox, wxVERTICAL );
  $vbox -> Add($combinboxsizer, 0, wxGROW|wxALL, 5);

  my $maxbox = Wx::BoxSizer->new( wxHORIZONTAL );
  $combinboxsizer->Add($maxbox, 0, wxGROW|wxALL, 1);
  $maxbox->Add(Wx::StaticText->new($panel, -1, 'Use at most'), 0, wxRIGHT|wxALIGN_CENTRE, 5);
  $this->{max} = Wx::SpinCtrl->new($panel, -1, 4, wxDefaultPosition, $tcsize, wxSP_ARROW_KEYS, 2, 100);
  $maxbox->Add($this->{max}, 0, wxLEFT|wxRIGHT|wxALIGN_CENTRE, 5);
  $maxbox->Add(Wx::StaticText->new($panel, -1, 'standards'), 0, wxRIGHT|wxALIGN_CENTRE, 5);

  $::app->mouseover($this->{max}, "In a combinatorial fit, only consider combinations up to this number of standards.");

  ## ------------- reset button
  $vbox->Add($this->{spacer}, 0, wxALL, 3);
  $vbox->Add($this->{reset}, 0, wxGROW|wxLEFT|wxRIGHT, 5);


  $this->{LCF}->plot_components(Demeter->co->default('lcf', 'components'));
  $this->{LCF}->plot_difference(Demeter->co->default('lcf', 'difference'));
  $this->{LCF}->linear   (0);
  $this->{LCF}->inclusive(Demeter->co->default('lcf', 'inclusive'));
  $this->{LCF}->unity    (Demeter->co->default('lcf', 'unity'));
  $this->{LCF}->one_e0   (0);

  EVT_CHECKBOX($this, $this->{components}, sub{$this->{LCF}->plot_components($this->{components}->GetValue)});
  EVT_CHECKBOX($this, $this->{residual},   sub{$this->{LCF}->plot_difference($this->{residual}  ->GetValue)});
  EVT_CHECKBOX($this, $this->{linear},     sub{$this->{LCF}->linear         ($this->{linear}    ->GetValue)});
  EVT_CHECKBOX($this, $this->{inclusive},  sub{$this->{LCF}->inclusive      ($this->{inclusive} ->GetValue)});
  EVT_CHECKBOX($this, $this->{unity},      sub{$this->{LCF}->unity          ($this->{unity}     ->GetValue)});
  EVT_CHECKBOX($this, $this->{one_e0},     sub{use_one_e0(@_)});
  EVT_BUTTON($this, $this->{reset},        sub{Reset(@_)});
  EVT_TEXT_ENTER($this, $this->{noise},    sub{1;});

  my $actionsbox       = Wx::StaticBox->new($panel, -1, 'Actions', wxDefaultPosition, wxDefaultSize);
  my $actionsboxsizer  = Wx::StaticBoxSizer->new( $actionsbox, wxVERTICAL );
  $hbox -> Add($actionsboxsizer, 1, wxGROW|wxALL, 5);

  $this->{usemarked}     = Wx::Button->new($panel, -1, 'Use marked groups');
  $this->{fit}		 = Wx::Button->new($panel, -1, 'Fit this group');
  $this->{combi}	 = Wx::Button->new($panel, -1, 'Fit all combinations');
  $this->{fitmarked}	 = Wx::Button->new($panel, -1, 'Fit marked groups');
  $this->{report}	 = Wx::Button->new($panel, -1, 'Save fit as column data');
  $this->{plot}		 = Wx::Button->new($panel, -1, 'Plot data and sum');
  $this->{plotr}	 = Wx::Button->new($panel, -1, 'Plot data and sum in R');
  $this->{make}		 = Wx::Button->new($panel, -1, 'Make group from fit');

  foreach my $w (qw(fit combi fitmarked report plot plotr make)) {
    my $n = ($w eq 'fit') ? 4 : 0;
    $actionsboxsizer->Add($this->{$w}, 0, wxGROW|wxTOP, $n);
    $this->{$w}->Enable(0);
  };
  $actionsboxsizer->Add($this->{usemarked}, 0, wxGROW|wxTOP, 10);
  $actionsboxsizer->Add(1,1,1);
  $this->{document} -> Reparent($panel);
  $actionsboxsizer->Add($this->{document}, 0, wxGROW|wxALL, 0);

  EVT_BUTTON($this, $this->{fit},       sub{fit(@_, 0)});
  EVT_BUTTON($this, $this->{plot},      sub{plot(@_)});
  EVT_BUTTON($this, $this->{report},    sub{save(@_)});
  EVT_BUTTON($this, $this->{combi},     sub{combi(@_)});
  EVT_BUTTON($this, $this->{fitmarked}, sub{sequence(@_)});
  EVT_BUTTON($this, $this->{make},      sub{make(@_)});
  EVT_BUTTON($this, $this->{plotr},     sub{fft(@_)});
  EVT_BUTTON($this, $this->{usemarked},    sub{use_marked(@_)});

  $::app->mouseover($this->{fit},       "Fit the current group using the current model.");
  $::app->mouseover($this->{plot},      "Plot the data with current sum of standards.");
  $::app->mouseover($this->{report},    "Save a column data file containing the current fit and its components.");
  $::app->mouseover($this->{combi},     "Perform a combinatorial fitting sequence using all possible combinations from the standards list.");
  $::app->mouseover($this->{fitmarked}, "Fit all marked groups using the current fitting model.");
  $::app->mouseover($this->{make},      "Turn the current sum of standards into its own data group.");
  $::app->mouseover($this->{plotr},     "Plot the current group and the current model in R space.");
  $::app->mouseover($this->{document},  "Show the document page for LCF in a browser.");
  $::app->mouseover($this->{usemarked}, "Move all marked groups into the list of standards.");


  $panel->SetSizerAndFit($box);
  return $panel;
};

sub fit_page {
  my ($this, $nb) = @_;
  my $panel = Wx::Panel->new($nb, -1, wxDefaultPosition, wxDefaultSize, wxMAXIMIZE_BOX );
  my $box = Wx::BoxSizer->new( wxVERTICAL);

  $this->{result} = Wx::TextCtrl->new($panel, -1, q{}, wxDefaultPosition, wxDefaultSize,
				       wxTE_MULTILINE|wxTE_WORDWRAP|wxTE_AUTO_URL|wxTE_READONLY|wxTE_RICH2);
  my $size = Wx::SystemSettings::GetFont(wxSYS_DEFAULT_GUI_FONT)->GetPointSize;
  $this->{result}->SetFont( Wx::Font->new( $size, wxTELETYPE, wxNORMAL, wxNORMAL, 0, "" ) );
  $box->Add($this->{result}, 1, wxGROW|wxALL, 5);

  $this->{resultplot} = Wx::Button->new($panel, -1, 'Plot data and fit');
  $box->Add($this->{resultplot}, 0, wxGROW|wxALL, 2);
  $this->{resultreport} = Wx::Button->new($panel, -1, 'Save fit as column data');
  $box->Add($this->{resultreport}, 0, wxGROW|wxALL, 2);
  EVT_BUTTON($this, $this->{resultplot},   sub{fit(@_, 1)});
  EVT_BUTTON($this, $this->{resultreport}, sub{save(@_)});
  $this->{resultplot}->Enable(0);
  $this->{resultreport}->Enable(0);

  $panel->SetSizerAndFit($box);
  return $panel;
};

sub combi_page {
  my ($this, $nb) = @_;
  my $panel = Wx::Panel->new($nb, -1, wxDefaultPosition, wxDefaultSize, wxMAXIMIZE_BOX );
  my $box = Wx::BoxSizer->new( wxVERTICAL);

  $this->{stats} = Wx::ListCtrl->new($panel, -1, wxDefaultPosition, wxDefaultSize, wxLC_REPORT|wxLC_HRULES||wxLC_SINGLE_SEL);
  $this->{stats}->InsertColumn( 0, "Standards", wxLIST_FORMAT_LEFT, 100 );
  $this->{stats}->InsertColumn( 1, "R-factor",  wxLIST_FORMAT_LEFT, 100 );
  $this->{stats}->InsertColumn( 2, "Reduced chi-square" , wxLIST_FORMAT_LEFT, 150 );
  $box->Add($this->{stats}, 1, wxALL|wxGROW, 3);
  EVT_LIST_ITEM_SELECTED($this, $this->{stats}, sub{combi_select(@_)});

  $this->{fitresults} = Wx::ListCtrl->new($panel, -1, wxDefaultPosition, wxDefaultSize, wxLC_REPORT|wxLC_HRULES||wxLC_SINGLE_SEL);
  $this->{fitresults}->InsertColumn( 0, "#",        wxLIST_FORMAT_LEFT, 20 );
  $this->{fitresults}->InsertColumn( 1, "Standard", wxLIST_FORMAT_LEFT, 150 );
  $this->{fitresults}->InsertColumn( 2, "Weight",   wxLIST_FORMAT_LEFT, 130 );
  $this->{fitresults}->InsertColumn( 3, "E0",       wxLIST_FORMAT_LEFT, 130 );
  $box->Add($this->{fitresults}, 1, wxALL|wxGROW, 3);

  $this->{combireport} = Wx::Button->new($panel, -1, 'Save combinatorial results as an Excel file');
  $box->Add($this->{combireport}, 0, wxGROW|wxALL, 2);
  EVT_BUTTON($this, $this->{combireport}, sub{combi_report(@_)});
  $this->{combireport}->Enable(0);

  $panel->SetSizerAndFit($box);
  return $panel;
};

sub marked_page {
  my ($this, $nb) = @_;
  my $panel = Wx::Panel->new($nb, -1, wxDefaultPosition, wxDefaultSize, wxMAXIMIZE_BOX );
  my $box = Wx::BoxSizer->new( wxVERTICAL);

  $this->{markedresults} = Wx::ListCtrl->new($panel, -1, wxDefaultPosition, wxDefaultSize, wxLC_REPORT|wxLC_HRULES||wxLC_SINGLE_SEL);
  $this->{markedresults}->InsertColumn( 0, "Data",            wxLIST_FORMAT_LEFT, 100 );
  $this->{markedresults}->InsertColumn( 1, "R-factor",        wxLIST_FORMAT_LEFT, 80 );
  $this->{markedresults}->InsertColumn( 2, "Red. chi-square", wxLIST_FORMAT_LEFT, 80 );
  $this->{markedresults}->InsertColumn( 3, "Stan. 1",         wxLIST_FORMAT_LEFT, 80 );
  $this->{markedresults}->InsertColumn( 4, "Stan. 2",         wxLIST_FORMAT_LEFT, 80 );
  $this->{markedresults}->InsertColumn( 5, "Stan. 3",         wxLIST_FORMAT_LEFT, 80 );
  $this->{markedresults}->InsertColumn( 6, "Stan. 4",         wxLIST_FORMAT_LEFT, 80 );
  $box->Add($this->{markedresults}, 1, wxALL|wxGROW, 3);
  EVT_LIST_ITEM_SELECTED($this, $this->{markedresults}, sub{seq_select(@_)});

  $this->{mreport} = Wx::TextCtrl->new($panel, -1, q{}, wxDefaultPosition, wxDefaultSize,
					    wxTE_MULTILINE|wxTE_WORDWRAP|wxTE_AUTO_URL|wxTE_READONLY|wxTE_RICH2);
  my $size = Wx::SystemSettings::GetFont(wxSYS_DEFAULT_GUI_FONT)->GetPointSize;
  $this->{mreport}->SetFont( Wx::Font->new( $size, wxTELETYPE, wxNORMAL, wxNORMAL, 0, "" ) );
  $box->Add($this->{mreport}, 1, wxALL|wxGROW, 3);


  $this->{plotmarked}	 = Wx::Button->new($panel, -1, 'Plot components from fit sequence');
  $this->{markedreport}	 = Wx::Button->new($panel, -1, 'Save fit sequence report as an Excel file');
  $box->Add($this->{plotmarked},   0, wxGROW|wxALL, 2);
  $box->Add($this->{markedreport}, 0, wxGROW|wxALL, 2);
  EVT_BUTTON($this, $this->{markedreport}, sub{seq_report(@_)});
  EVT_BUTTON($this, $this->{plotmarked},   sub{seq_plot(@_)});
  $this->{plotmarked}->Enable(0);
  $this->{markedreport}->Enable(0);

  $panel->SetSizerAndFit($box);
  return $panel;
};


sub add_standard {
  my ($this, $panel, $gbs, $i) = @_;
  my $box = Wx::BoxSizer->new( wxHORIZONTAL );
  $this->{'standard'.$i} = Demeter::UI::Athena::GroupList -> new($panel, $::app, 0, 0);
  $this->{'weight'.$i}   = Wx::TextCtrl -> new($panel, -1, 0, wxDefaultPosition, $tcsize, wxTE_PROCESS_ENTER);
  $this->{'e0'.$i}       = Wx::TextCtrl -> new($panel, -1, 0, wxDefaultPosition, $tcsize, wxTE_PROCESS_ENTER);
  $this->{'fite0'.$i}    = Wx::CheckBox -> new($panel, -1, q{ });
  $this->{'require'.$i}  = Wx::CheckBox -> new($panel, -1, q{ });
  $gbs -> Add(Wx::StaticText->new($panel, -1, sprintf("%2d: ",$i+1)), Wx::GBPosition->new($i,0));
  $gbs -> Add($this->{'standard'.$i}, Wx::GBPosition->new($i,1));
  $gbs -> Add($this->{'weight'.$i},   Wx::GBPosition->new($i,2));
  $gbs -> Add($this->{'e0'.$i},       Wx::GBPosition->new($i,3));
  $gbs -> Add($this->{'fite0'.$i},    Wx::GBPosition->new($i,4));
  $gbs -> Add($this->{'require'.$i},  Wx::GBPosition->new($i,5));
  $this->{'standard'.$i}->SetSelection(0);
  EVT_TEXT_ENTER($this, $this->{'weight'.$i}, sub{1});
  EVT_TEXT_ENTER($this, $this->{'e0'.$i}, sub{1});
  EVT_CHECKBOX($this, $this->{'fite0'.$i}, sub{use_individual_e0(@_, $i)});

  $this->{'standard'.$i}->{callback} = sub{$this->OnSelect};
  $this->{'weight'.$i} -> SetValidator( Wx::Perl::TextValidator->new( qr([0-9.]) ) );
  $this->{'e0'.$i}     -> SetValidator( Wx::Perl::TextValidator->new( qr([-0-9.]) ) );

};

## deprecated?
sub pull_values {
  my ($this, $data) = @_;
  1;
};

## this subroutine fills the controls when an item is selected from the Group list
sub push_values {
  my ($this, $data) = @_;
  foreach my $i (0 .. $this->{nstan}-1) {
    my $str = $this->{'standard'.$i}->GetStringSelection;
    $this->{'standard'.$i}->fill($::app, 1, 0);
    $this->{'standard'.$i}->SetStringSelection($str);
    $this->{'standard'.$i}->SetSelection(0) if not scalar $this->{'standard'.$i}->GetSelection;

    # if ((not defined $this->{'standard'.$i}->GetSelection) or
    # 	(not scalar $this->{'standard'.$i}->GetSelection) or
    # 	(not defined $this->{'standard'.$i}->GetClientData(scalar $this->{'standard'.$i}->GetSelection))) {
    #   $this->{'standard'.$i}->SetSelection(0);
    # };
  };
  $this->{result}->Clear;
  $this->{$_} -> Enable(0) foreach (qw(make report fitmarked resultplot resultreport));
  my $count = 0;
  foreach my $i (0 .. $this->{nstan}-1) {
    ++$count if (scalar $this->{'standard'.$i}->GetSelection > 0);
  };
  $this->{fit}       -> Enable($count > 1);
  $this->{fitmarked} -> Enable($count > 1);
  $this->{combi}     -> Enable($count > 2);
  $this->{plot}      -> Enable($count > 0);
  $this->{plotr}     -> Enable($count > 0) if ($this->{space}->GetSelection == 2);
  $this->{LCF}->data($::app->current_data);
  if ($this->{LCF}->data->datatype eq 'chi') {
    $this->{space}->Enable(0,0);
    $this->{space}->Enable(1,0);
    $this->{space}->SetSelection(2);
    $this->OnSpace;
  } else {
    $this->{space}->Enable(0,1);
    $this->{space}->Enable(1,1);
    $this->OnSpace;
  };
  1;
};

## this subroutine sets the enabled/frozen state of the controls
sub mode {
  my ($this, $data, $enabled, $frozen) = @_;
  1;
};

sub OnSelect {
  my ($this, $event) = @_;
  my $count = 0;
  foreach my $i (0 .. $this->{nstan}-1) {
    ++$count if (scalar $this->{'standard'.$i}->GetSelection > 0);
  };
  foreach my $i (0 .. $this->{nstan}-1) {
    if (scalar $this->{'standard'.$i}->GetSelection > 0) {
      $this->{'weight'.$i}->SetValue(sprintf("%.3f", 1/$count));
    } else {
      $this->{'weight'.$i}->SetValue(0);
    };
  };
  $this->{xmin_pluck} -> Enable($count > 0);
  $this->{xmax_pluck} -> Enable($count > 0);

  $this->{fit}       -> Enable($count > 1);
  $this->{fitmarked} -> Enable($count > 1);
  $this->{combi}     -> Enable($count > 2);
  $this->{plot}      -> Enable($count > 0);
  $this->{plotr}     -> Enable($count > 0) if ($this->{space}->GetSelection == 2);

  $this->{make}         -> Enable(0);
  $this->{report}       -> Enable(0);
  $this->{resultplot}   -> Enable(0);
  $this->{resultreport} -> Enable(0);
};

sub Pluck {
  my ($self, $ev, $which) = @_;
  my $busy = Wx::BusyCursor->new();
  plot($self, $ev);
  undef $busy;
  my ($ok, $x, $y)    = $::app->cursor($self);
  $self->status("Failed to pluck a value for $which"), return if not $ok;
  $x -= $::app->current_data->bkg_e0 if ($self->{LCF}->space ne 'chi');
  my $plucked         = sprintf("%.3f", $x);
  $self->{$which}->SetValue($plucked);
  my $text            = sprintf("Plucked %s as the value for %s.", $plucked, $which);
  $::app->{main}->status($text);
}

sub use_one_e0 {
  my ($this, $event) = @_;
  my $val = $this->{one_e0}->GetValue;
  $this->{LCF}->one_e0($val);
  if ($val) {
    foreach my $i (0 .. $this->{nstan}-1) {
      $this->{'e0'.$i}->SetValue(0);
      $this->{'fite0'.$i}->SetValue(0);
    };
  };
};

sub use_individual_e0 {
  my ($this, $event, $i) = @_;
  my $val = $this->{'fite0'.$i}->GetValue;
  if ($val) {
    $this->{one_e0}->SetValue(0);
    $this->{LCF}->one_e0(0);
  };
};

sub use_marked {
  my ($this, $event) = @_;
  my $count = 0;
  $this->_remove_all;
  foreach my $i (0 .. $::app->{main}->{list}->GetCount-1) {
    next if not $::app->{main}->{list}->IsChecked($i);
    $this->{'standard'.$count}->SetStringSelection($::app->{main}->{list}->GetIndexedData($i)->name);
    $this->{'fite0'.$count}->SetValue(0);
    $this->{'require'.$count}->SetValue(0);
    ++$count;
  };
  $this->OnSelect($event);
};

sub Reset {
  my ($this, $event) = @_;
  $this->OnSelect;
  foreach my $i (0 .. $this->{nstan}-1) {
    $this->{'e0'.$i}->SetValue(0);
    $this->{'fite0'.$i}->SetValue(0);
    $this->{'require'.$i}->SetValue(0);
  };
  $this->{$_} -> SetValue(0) foreach (qw(linear one_e0));
  $this->{$_} -> SetValue(Demeter->co->default('lcf', $_)) foreach (qw(inclusive unity));
};

sub OnSpace {
  my ($this, $event) = @_;
  if ($this->{space}->GetSelection == 2) {
    if ($this->{pastspace} != 2) {
      $this->{emin} = $this->{xmin}->GetValue;
      $this->{emax} = $this->{xmax}->GetValue;
      $this->{xmin}->SetValue($this->{kmin});
      $this->{xmax}->SetValue($this->{kmax});
    };
    $this->{plotr} -> Enable(1);
    $this->{LCF}->po->space('k');
  } else {
    if ($this->{pastspace} == 2) {
      $this->{kmin} = $this->{xmin}->GetValue;
      $this->{kmax} = $this->{xmax}->GetValue;
      $this->{xmin}->SetValue($this->{emin});
      $this->{xmax}->SetValue($this->{emax});
    };
    $this->{plotr} -> Enable(0);
    $this->{LCF}->po->space('E');
  };
  $this->{pastspace} = $this->{space}->GetSelection;
  $this->{LCF}->space('norm')  if $this->{space}->GetSelection == 0;
  $this->{LCF}->space('deriv') if $this->{space}->GetSelection == 1;
  $this->{LCF}->space('chi')   if $this->{space}->GetSelection == 2;
};

sub fetch {
  my ($this) = @_;
  my $max = $this->{max}->GetValue;
  $max = 2 if ($max < 2);
  $this->{LCF}->max_standards($max);
  my $noise = $this->{noise}->GetValue;
  #$noise =~ s{\.{2,}}{.}g;
  $noise = 0 if (not looks_like_number($noise));
  $noise = 0 if ($noise < 0);
  $this->{LCF}->noise($noise);
};

sub _prep {
  my ($this, $nofit) = @_;
  $nofit ||= 0;
  my $trouble = 0;
  my $busy = Wx::BusyCursor->new();
  $this->fetch;
  $this->{LCF}->clear;
  $this->{LCF}->clean if not $nofit;
  $this->{LCF}->data($::app->current_data);
  foreach my $i (0 .. $this->{nstan}-1) {
    my $n = scalar $this->{'standard'.$i}->GetSelection;
    my $stan = $this->{'standard'.$i}->GetClientData($n);
    next if not defined($stan);
    #print join("|", $i, $n, $this->{'weight'.$i}->GetValue), $/;

    return sprintf("weight #%d", $i+1) if (not looks_like_number($this->{'weight'.$i}->GetValue));
    return sprintf("e0 #%d"    , $i+1) if (not looks_like_number($this->{'e0'.$i}->GetValue));

    $this->{LCF} -> add($stan,
			required => $this->{'require'.$i}->GetValue,
			float_e0 => $this->{'fite0'.$i}->GetValue,
			weight   => $this->{'weight'.$i}->GetValue,
			e0       => $this->{'e0'.$i}->GetValue,
		       );
  };
  $this->{LCF}->space('norm')  if $this->{space}->GetSelection == 0;
  $this->{LCF}->space('deriv') if $this->{space}->GetSelection == 1;
  $this->{LCF}->space('chi')   if $this->{space}->GetSelection == 2;
  my $e0 = ($this->{LCF}->space eq 'chi') ? 0 : $this->{LCF}->data->bkg_e0;
  ($this->{LCF}->space eq 'chi') ? $this->{LCF}->data->_update('fft') : $this->{LCF}->data->_update('background');

  return 'xmin' if (not looks_like_number($this->{xmin}->GetValue));
  return 'xmax' if (not looks_like_number($this->{xmax}->GetValue));

  $this->{LCF}->xmin($this->{xmin}->GetValue + $e0);
  $this->{LCF}->xmax($this->{xmax}->GetValue + $e0);
  if ($this->{LCF}->space eq 'chi') {
    $this->{LCF}->po->set(kmin=>0, kmax=>$this->{xmax}->GetValue+1);
  } else {
    $this->{LCF}->po->set(emin=>$this->{xmin}->GetValue-10, emax=>$this->{xmax}->GetValue+10);
  };
  undef $busy;
  return $trouble;
};

sub _results {
  my ($this) = @_;
  foreach my $i (0 .. $this->{nstan}-1) {
    my $n = scalar $this->{'standard'.$i}->GetSelection;
    my $stan = $this->{'standard'.$i}->GetClientData($n);
    next if not defined($stan);
    my @answer = ($this->{LCF}->weight($stan));
    my $w = sprintf("%.3f", $answer[0]);
    @answer = ($this->{LCF}->e0($stan));
    my $e = sprintf("%.3f", $answer[0]);
    $this->{'weight'.$i}->SetValue($w);
    $this->{'e0'.$i}    ->SetValue($e);
  };
  $this->{ninfo}->SetValue($this->{LCF}->ninfo);
  $this->{result}->Clear;
  $this->{result}->SetValue($this->{LCF}->report);
};

sub fit {
  my ($this, $event, $nofit) = @_;
  my $trouble = $this->_prep($nofit);
  my $busy = Wx::BusyCursor->new();
  if (($this->{space}->GetSelection == 2) and ($::app->{main}->{kweights}->GetStringSelection eq 'kw')) {
    $::app->{main}->status("Not doing LCF -- Linear combination fitting in chi(k) cannot be done with arbitrary k-wieghting!", 'error');
    return;
  };
  if ($trouble) {
    $::app->{main}->status("Not doing LCF -- the $trouble parameter value is not a number!", 'error');
    return;
  };
  $this->{LCF} -> fit if not $nofit;
  $this->{LCF} -> plot_fit;
  $this->_results if not $nofit;
  $this->{make}         -> Enable(1);
  $this->{report}       -> Enable(1);
  #$this->{fitmarked}    -> Enable(1);
  #$this->{markedreport} -> Enable(1);
  $this->{resultplot}   -> Enable(1);
  $this->{resultreport} -> Enable(1);
  $this->{plotr}        -> Enable(1) if ($this->{LCF}->space =~ m{\Achi});
  $::app->{main}->status(sprintf("Finished LCF fit to %s", $this->{LCF}->data->name));
  $::app->heap_check(0);
  undef $busy;
};

sub combi {
  my ($this, $event) = @_;
  my $trouble = $this->_prep(0);
  my $busy = Wx::BusyCursor->new();
  if ($trouble) {
    $::app->{main}->status("Not doing LCF -- the $trouble parameter value is not a number!", 'error|nobuffer');
    return;
  };
  my $size = $this->{LCF}->combi_size;
  if ($size > 70) {
    my $yesno = Demeter::UI::Wx::VerbDialog->new($::app->{main}, -1,
						 "You have asked to do $size fits!  Really perform this many fits?",
						 "Perform $size fits?",
						 "Perform fits");
    my $result = $yesno->ShowModal;
    if ($result == wxID_NO) {
      $::app->{main}->status("Not doing combinatorial sequence of $size fits.");
      return 0;
    };
  };
  $::app->{main}->status("Doing $size combinatorial fits", 'wait');
  my $start = DateTime->now( time_zone => 'floating' );
  $this->{LCF} -> sentinal(sub{$this->combi_sentinal($size)});
  $this->{LCF} -> combi;
  $this->{LCF} -> plot_fit;

  $this->{result}->Clear;
  $this->{result}->SetValue($this->{LCF}->report);

  $this->_remove_all;
  my $i = 0;
  foreach my $st (@{ $this->{LCF}->standards }) {
    $this->{'standard'.$i}->SetStringSelection($st->name);
    my $w = sprintf("%.3f", $this->{LCF}->weight($st));
    my $e = sprintf("%.3f", $this->{LCF}->e0($st));
    $this->{'weight'.$i}  -> SetValue($w);
    $this->{'e0'.$i}      -> SetValue($e);
    $this->{'fite0'.$i}   -> SetValue($this->{LCF}->is_e0_floated($st));
    $this->{'require'.$i} -> SetValue($this->{LCF}->is_required($st));
    ++$i;
  };
  $this->combi_results;
  $this->{make}         -> Enable(1);
  $this->{report}       -> Enable(1);
  $this->{fitmarked}    -> Enable(1);
  $this->{resultplot}   -> Enable(1);
  $this->{resultreport} -> Enable(1);
  $this->{combireport}  -> Enable(1);

  $this->{stats}->SetItemState(0, wxLIST_STATE_SELECTED, wxLIST_STATE_SELECTED );
  $this->{notebook}->ChangeSelection(2);

  my $finishtext = Demeter->howlong($start, sprintf("%d combinatorial fits",$size));
  $::app->{main}->status($finishtext);

  undef $busy;
};

sub combi_sentinal {
  my ($this, $size) = @_;
  $::app->{main}->status($this->{LCF}->combi_count." of $size combinatorial fits", 'wait|nobuffer');
};

sub combi_results {
  my ($this) = @_;

  $this->{stats}->DeleteAllItems;
  $this->{fitresults}->DeleteAllItems;

  my @stand = keys %{ $this->{LCF}->options };
  my %map = ();
  my %idx = ();
  my $i = 0;
  my $row = 0;
  foreach my $s (sort by_position @stand) {
    $map{$s} = chr($row+65);	# A B C ...
    $idx{$s} = $this->{fitresults}->InsertStringItem($i, $row);
    $this->{fitresults}->SetItemData($idx{$s}, $i++);
    $this->{fitresults}->SetItem( $idx{$s}, 0, $map{$s} );
    $this->{fitresults}->SetItem( $idx{$s}, 1, $this->{LCF}->mo->fetch('Data', $s)->name );
    ++$row;
  };
  $this->{index_map} = \%idx;

  $row = 0;
  $i = 0;
  foreach my $res (@{ $this->{LCF}->combi_results }) {
    my $rfact = $res->{Rfactor};
    my $chinu = $res->{Chinu};
    my @included = ();
    foreach my $s (sort by_position @stand) {
      if (exists $res->{$s}) {
	push @included, $map{$s};
      };
    };

    my $idx = $this->{stats}->InsertStringItem($i, $row);
    $this->{stats}->SetItemData($idx, $i++);
    $this->{stats}->SetItem( $idx, 0, join(',', @included) );
    $this->{stats}->SetItem( $idx, 1, sprintf("%.5g", $rfact) );
    $this->{stats}->SetItem( $idx, 2, sprintf("%.5g", $chinu) );
    ++$row;
  };
};

sub combi_select {
  my ($this, $event) = @_;
  my $busy = Wx::BusyCursor->new();
  my @all = @{ $this->{LCF}->combi_results };
  my $result = $all[$event->GetIndex];
  $this->{LCF} -> restore($result);
  my @stand = keys %{ $this->{LCF}->options };

  my %idx = %{ $this->{index_map} };
  foreach my $s (sort by_position @stand) {
    if (exists $result->{$s}) {
      my @here = @{ $result->{$s} };
      $this->{fitresults}->SetItem( $idx{$s}, 2, sprintf("%.3f (%.3f)", @here[0,1]) );
      $this->{fitresults}->SetItem( $idx{$s}, 3, sprintf("%.3f (%.3f)", @here[2,3]) );
    } else {
      $this->{fitresults}->SetItem( $idx{$s}, 2, q{} );
      $this->{fitresults}->SetItem( $idx{$s}, 3, q{} );
    };
  };

  $this->{LCF} -> plot_fit;
  $this->{result}->Clear;
  $this->{result}->SetValue($this->{LCF}->report);
  $this->_remove_all;
  my $i = 0;
  foreach my $st (sort by_data @{ $this->{LCF}->standards }) {
    #next if not $this->{LCF}->option_exists($st->name);
    $this->{'standard'.$i}->SetStringSelection($st->name);
    my $w = sprintf("%.3f", scalar($this->{LCF}->weight($st)));
    my $e = sprintf("%.3f", scalar($this->{LCF}->e0($st)));
    $this->{'weight'.$i}  -> SetValue($w);
    $this->{'e0'.$i}      -> SetValue($e);
    $this->{'fite0'.$i}   -> SetValue($this->{LCF}->is_e0_floated($st));
    $this->{'require'.$i} -> SetValue($this->{LCF}->is_required($st));
    ++$i;
  };
  undef $busy;
};

sub combi_report {
  my ($this, $event) = @_;
  my $init = $::app->current_data->name . '_combinatorial.xls';
  my $fd = Wx::FileDialog->new( $::app->{main}, "Save combinatorial results", cwd, $init,
				"Excel (*.xls)|*.xls|All files (*)|*",
				wxFD_SAVE|wxFD_CHANGE_DIR|wxFD_OVERWRITE_PROMPT,
				wxDefaultPosition);
  if ($fd->ShowModal == wxID_CANCEL) {
    $::app->{main}->status("Saving combinatorial results has been canceled.");
    return 0;
  };
  my $fname = $fd->GetPath;
  #return if $::app->{main}->overwrite_prompt($fname); # work-around gtk's wxFD_OVERWRITE_PROMPT bug (5 Jan 2011)
  $this->{LCF}->combi_report($fname);
  $::app->{main}->status("Wrote combinatorial report as an Excel spreadsheet to $fname");
};


sub sequence {
  my ($this, $event) = @_;
  my $trouble = $this->_prep(0);
  my $busy = Wx::BusyCursor->new();
  if ($trouble) {
    $::app->{main}->status("Not doing sequence -- the $trouble parameter value is not a number!", 'error|nobuffer');
    return;
  };

  my @groups = $::app->marked_groups;
  my $i = 0;
  foreach my $g (@groups) {
    last if ($g->group eq $::app->current_data->group);
    ++$i;
  };
  $::app->{main}->status(sprintf("Fitting %d marked groups", $#groups+1), 'wait');
  my $start = DateTime->now( time_zone => 'floating' );
  $this->{LCF} -> sentinal(sub{$this->seq_sentinal($#groups+1)});
  $this->{LCF} -> sequence(@groups);

  $this->{result}->Clear;
  $this->{result}->SetValue($this->{LCF}->report);

  $this->seq_results(@groups);
  $this->{markedresults} -> SetItemState(0, wxLIST_STATE_SELECTED, wxLIST_STATE_SELECTED );
  $this->seq_select($i);
  $this->{markedresults} -> SetItemState(0, 0, wxLIST_STATE_SELECTED);
  $this->{markedresults} -> SetItemState($i, wxLIST_STATE_SELECTED, wxLIST_STATE_SELECTED);

  my $finishtext = Demeter->howlong($start, sprintf("Fitting %d groups",$#groups+1));
  $this->{plotmarked}    -> Enable(1);
  $this->{markedreport}  -> Enable(1);
  $::app->{main}->status($finishtext);

  undef $busy;
};

sub seq_sentinal {
  my ($this, $size) = @_;
  $::app->{main}->status($this->{LCF}->seq_count." of $size LCF fits", 'wait|nobuffer');
};

sub seq_results {
  my ($this, @data) = @_;

  $this->{markedresults}->DeleteAllItems;
  $this->{mreport}->Clear;
  my @standards = @{ $this->{LCF}->standards };

  my $ncol = $this->{markedresults}->GetColumnCount;
  foreach my $nc (reverse(4..$ncol)) {
    $this->{markedresults}->DeleteColumn($nc-1);
  };
  my $c = 3;
  foreach my $st (@standards) {
    $this->{markedresults}->InsertColumn($c++ , $st->name, wxLIST_FORMAT_LEFT, 80 );
  };

  my ($i, $row) = (0,0);
  foreach my $res (@{ $this->{LCF}->seq_results }) {
    my $rfact = $res->{Rfactor};
    my $chinu = $res->{Chinu};

    my $idx = $this->{markedresults}->InsertStringItem($i, $row);
    $this->{markedresults}->SetItemData($idx, $i);
    $this->{markedresults}->SetItem( $idx, 0, $data[$i]->name );
    $this->{markedresults}->SetItem( $idx, 1, sprintf("%.5g", $rfact) );
    $this->{markedresults}->SetItem( $idx, 2, sprintf("%.5g", $chinu) );
    ++$i;
    my $c = 3;
    foreach my $st (@standards) {
      $this->{markedresults}->SetItem( $idx, $c, sprintf("%.3f(%.3f)", $res->{$st->group}->[0], $res->{$st->group}->[1]) );
      ++$c;
      last if $c>6;
    };
    ++$row;
  };
  $this->{notebook}->ChangeSelection(3);
};


sub seq_select {
  my ($this, $event) = @_;
  my $busy = Wx::BusyCursor->new();
  my $index  = (ref($event) =~ m{Event}) ? $event->GetIndex : $event;
  my $result = $this->{LCF}->seq_results->[$index];
  my $data   = $this->{LCF}->mo->fetch('Data', $result->{Data});
  $this->{LCF}->data($data);
  $this->{LCF}->restore($result);
  my $which = ($this->{LCF}->space =~ m{\Achi}) ? "lcf_prep_k" : "lcf_prep";
  $this->{LCF}->dispense("analysis", $which);
  $this->{mreport}->SetValue($this->{LCF}->report);

  $this->_remove_all;
  my $i = 0;
  foreach my $st (@{ $this->{LCF}->standards }) {
    $this->{'standard'.$i}->SetStringSelection($st->name);
    my $w = sprintf("%.3f", scalar($this->{LCF}->weight($st)));
    my $e = sprintf("%.3f", scalar($this->{LCF}->e0($st)));
    $this->{'weight'.$i}  -> SetValue($w);
    $this->{'e0'.$i}      -> SetValue($e);
    $this->{'fite0'.$i}   -> SetValue($this->{LCF}->is_e0_floated($st));
    $this->{'require'.$i} -> SetValue($this->{LCF}->is_required($st));
    ++$i;
  };

  my $j = 0;
  foreach my $n (0 .. $::app->{main}->{list}->GetCount-1) {
    last if ($::app->{main}->{list}->GetIndexedData($n)->group eq $data->group);
    ++$j;
  };
  $::app->{main}->{list}->SetSelection($j);
  $::app->OnGroupSelect(0,0,0);
  $this->{result}->Clear;
  $this->{result}->SetValue($this->{LCF}->report);

  $this->{LCF}->plot_fit;
  undef $busy;
};

sub seq_report {
  my ($this, $event) = @_;
  my $init = ($::app->{main}->{project}->GetLabel eq '<untitled>') ? 'lcf_sequence' : $::app->{main}->{project}->GetLabel.'_lcf_sequence';
  $init .= '.xls';
  my $fd = Wx::FileDialog->new( $::app->{main}, "Save LCF fit sequence results", cwd, $init,
				"Excel (*.xls)|*.xls|All files (*)|*",
				wxFD_SAVE|wxFD_CHANGE_DIR|wxFD_OVERWRITE_PROMPT,
				wxDefaultPosition);
  if ($fd->ShowModal == wxID_CANCEL) {
    $::app->{main}->status("Saving fit sequence results has been canceled.");
    return 0;
  };
  my $fname = $fd->GetPath;
  #return if $::app->{main}->overwrite_prompt($fname); # work-around gtk's wxFD_OVERWRITE_PROMPT bug (5 Jan 2011)
  $this->{LCF}->sequence_report($fname);
  $::app->{main}->status("Wrote LCF fit sequence report as an Excel spreadsheet to $fname");
};

sub seq_plot {
  my ($this, $event) = @_;
  $this->{LCF}->sequence_plot;
  $::app->{main}->status("Plotted components from the fit sequence");
};


sub _remove_all {
  my ($this) = @_;
  foreach my $i (0 .. $this->{nstan}-1) {
    $this->{'standard'.$i}->SetSelection(0);
    $this->{'weight'.$i}->SetValue(0);
    $this->{'e0'.$i}->SetValue(0);
  };
};

sub plot {
  my ($this, $event) = @_;
  $this->_prep;
  $this->{LCF}->plot_fit;
  $::app->{main}->status(sprintf("Plotted %s and LCF fit", $this->{LCF}->data->name));
  $::app->heap_check(0);
};

sub save {
  my ($this, $event) = @_;

  my $data = $::app->current_data;
  (my $name = $data->name) =~ s{\s+}{_}g;
  my $fd = Wx::FileDialog->new( $::app->{main}, "Save LCF fit to a file", cwd, $name.".lcf",
				"LCF (*.lcf)|*.lcf|All files (*)|*",
				wxFD_SAVE|wxFD_CHANGE_DIR|wxFD_OVERWRITE_PROMPT,
				wxDefaultPosition);
  if ($fd->ShowModal == wxID_CANCEL) {
    $::app->{main}->status("Saving LCF results to a file has been canceled.");
    return 0;
  };
  my $fname = $fd->GetPath;
  #return if $::app->{main}->overwrite_prompt($fname); # work-around gtk's wxFD_OVERWRITE_PROMPT bug (5 Jan 2011)
  $this->{LCF}->save($fname);
  $::app->{main}->status("Saved LCF results to $fname");
};


sub make {
  my ($this, $event) = @_;
  my $new = $this->{LCF}->make_group;

  my $index = $::app->current_index;
  if ($index == $::app->{main}->{list}->GetCount-1) {
    $::app->{main}->{list}->AddData($new->name, $new);
  } else {
    $::app->{main}->{list}->InsertData($new->name, $index+1, $new);
  };
  $::app->{main}->status("Made a new data group fromLCF fit to " . $::app->current_data->name);
  $::app->modified(1);
};


sub fft {
  my ($this, $event) = @_;
  $this->_prep;
  my $busy = Wx::BusyCursor->new();
  $::app->{main}->{'PlotR'}->pull_marked_values;
  $this->{LCF}->data->po->start_plot;
  $this->{LCF}->data->plot('R');
  $this->{LCF}->fft;
  $this->{LCF}->plot('R');
  undef $busy;
};

sub by_position {
  my %hash = ();
  foreach my $i (0 .. $::app->{main}->{list}->GetCount-1) {
    my $g = $::app->{main}->{list}->GetIndexedData($i)->group;
    $hash{$g} = $i;
  };
  $hash{$a} <=> $hash{$b};
};
sub by_data {
  my %hash = ();
  foreach my $i (0 .. $::app->{main}->{list}->GetCount-1) {
    my $g = $::app->{main}->{list}->GetIndexedData($i);
    $hash{$g->group} = $i;
  };
  $hash{$a->group} <=> $hash{$b->group};
};

## restore persistent information from a project file
sub reinstate {
  my ($this, $hash) = @_;
  #print Data::Dumper->Dump([$hash], [qw/*LCF/]);
  ## booleans
  $this->{components}->SetValue($hash->{plot_components});
  $this->{residual}->SetValue($hash->{plot_difference});
  foreach my $k (qw(inclusive unity linear one_e0)) {
    $this->{$k}->SetValue($hash->{$k});
  };
  ## fitting space
  $this->{space}->SetSelection(2);
  $this->{space}->SetSelection(0) if ($hash->{space} eq 'norm');
  $this->{space}->SetSelection(1) if ($hash->{space} eq 'deriv');
  $this->OnSpace(q());
  ## fit range
  my $e0  = 0;
  if ($this->{LCF}->mo->fetch('Data', $hash->{datagroup})) {
    $e0 = $this->{LCF}->mo->fetch('Data', $hash->{datagroup})->bkg_e0;
  };
  $this->{xmin}->SetValue($hash->{xmin} - $e0) if $hash->{xmin} != 0;
  $this->{xmax}->SetValue($hash->{xmax} - $e0) if $hash->{xmax} != 0;
  ## artificial noise, info content, combi
  $this->{noise}->SetValue($hash->{noise});
  $this->{ninfo}->SetValue($hash->{ninfo});
  $this->{max}  ->SetValue($hash->{max_standards});

  $this->_remove_all;
  my $count = 0;
  foreach my $g (keys %{ $hash->{options} }) {
    my $d = $this->{LCF}->mo->fetch('Data', $g);
    $this->{'standard'.$count}->SetStringSelection($d->name);
    $this->{'fite0'.$count}   -> SetValue($hash->{options}->{$g}->[0]);
    $this->{'require'.$count} -> SetValue($hash->{options}->{$g}->[1]);
    $this->{'weight'.$count}  -> SetValue($hash->{options}->{$g}->[2]);
    $this->{'e0'.$count}      -> SetValue($hash->{options}->{$g}->[4]);
    ++$count;
  };
  $::app->{main}->status("Restored LCF state from project file");


};


1;


=head1 NAME

Demeter::UI::Athena::LCF - A linear combination fitting tool for Athena

=head1 VERSION

This documentation refers to Demeter version 0.9.26.

=head1 SYNOPSIS

This module provides a

=head1 CONFIGURATION


=head1 DEPENDENCIES

Demeter's dependencies are in the F<Build.PL> file.

=head1 BUGS AND LIMITATIONS

=over 4

=item *

This 'n' that

=back

Please report problems to the Ifeffit Mailing List
(L<http://cars9.uchicago.edu/mailman/listinfo/ifeffit/>)

Patches are welcome.

=head1 AUTHOR

Bruce Ravel, L<http://bruceravel.github.io/home>

L<http://bruceravel.github.io/demeter/>

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2017 Bruce Ravel (L<http://bruceravel.github.io/home>). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
