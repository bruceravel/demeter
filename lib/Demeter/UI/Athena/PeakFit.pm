package Demeter::UI::Athena::PeakFit;

use strict;
use warnings;

use Wx qw( :everything );
use base 'Wx::Panel';
use Wx::Event qw(EVT_BUTTON EVT_LIST_ITEM_SELECTED EVT_CHECKBOX EVT_HYPERLINK EVT_CHOICE
		 EVT_LEFT_DOWN EVT_RIGHT_DOWN EVT_MENU);

use Const::Fast;
const my $STEPLIKE => qr(atan|erf|logistic)i;
const my $PEAKLIKE => qr(gaussian|lorentzian|voigt|pvoit|pseudo_voigt|pseudo-voigt|pearson7|students_t)i;
const my $PEAK3    => qr(gaussian|lorentzian|students_t)i;

use Cwd;
use File::Basename;
use File::Spec;
use Scalar::Util qw(looks_like_number);
use List::MoreUtils qw(any firstidx);
use List::Util qw(max);

use Demeter::UI::Wx::SpecialCharacters qw(:greek);
use Demeter::UI::Wx::VerbDialog;

use vars qw($label);
$label = "Peak fitting";	# used in the Choicebox and in status bar messages to identify this tool


our $steps = ($ENV{DEMETER_BACKEND} eq 'larch') ? ['Atan', 'Erf', 'Logistic'] : ['Atan', 'Erf'];
our $peaks = ($ENV{DEMETER_BACKEND} eq 'larch')
  ? ['Gaussian', 'Lorentzian', 'Voigt', 'Pseudo_Voigt', 'Pearson7', 'Students_t']
  : ['Gaussian', 'Lorentzian', 'Pseudo_Voigt'];

const my %SWAPHASH => (Gaussian	    => Wx::NewId(),
		       Lorentzian   => Wx::NewId(),
		       Voigt	    => Wx::NewId(),
		       Pseudo_Voigt => Wx::NewId(),
		       Pearson7	    => Wx::NewId(),
		       Students_t   => Wx::NewId(),
		       Atan	    => Wx::NewId(),
		       Erf	    => Wx::NewId(),
		       Logistic	    => Wx::NewId(),);


my $tcsize = [60,-1];
my $icon     = File::Spec->catfile(dirname($INC{"Demeter/UI/Athena.pm"}), 'Athena', , 'icons', "bullseye.png");
my $bullseye = Wx::Bitmap->new($icon, wxBITMAP_TYPE_PNG);

my %map  = (atan => "Arctan", erf => "Error fun.", logistic => 'Logistic',
	    gaussian => "Gaussian", lorentzian => "Lorentzian", voigt => 'Voigt',
	    pvoigt => 'Pseudo-Voigt', pseudo_voigt => 'Pseudo-Voigt',
	    pearson7 => 'Pearson7', breit_wigner => 'Breit-Wigner', lognormal => 'LogNormal',
	    students_t => 'Student\'s T');
my %swap = (atan => "erf", erf => "atan", gaussian => "lorentzian", lorentzian => "gaussian");

sub new {
  my ($class, $parent, $app) = @_;
  my $this = $class->SUPER::new($parent, -1, wxDefaultPosition, wxDefaultSize, wxMAXIMIZE_BOX );

  $this->{PEAK}   = Demeter::PeakFit->new(backend=>$ENV{DEMETER_BACKEND});
  $this->{emin}   = -15; #Demeter->co->default('peakfit', 'emin');
  $this->{emax}   =  15; #Demeter->co->default('peakfit', 'emax');
  $this->{count}  =  0;
  $this->{fitted} =  0;

  my $box = Wx::BoxSizer->new( wxVERTICAL);
  $this->{sizer}  = $box;


  my $hbox = Wx::BoxSizer->new( wxHORIZONTAL );
  $box->Add($hbox, 0, wxGROW|wxLEFT|wxRIGHT, 5);
  $hbox->Add(Wx::StaticText->new($this, -1, 'Fit range:'), 0, wxRIGHT|wxALIGN_CENTRE, 5);
  $this->{emin} = Wx::TextCtrl->new($this, -1, $this->{emin}, wxDefaultPosition, $tcsize, wxTE_PROCESS_ENTER);
  $hbox->Add($this->{emin}, 0, wxLEFT|wxRIGHT|wxALIGN_CENTRE, 5);
  $this->{emin_pluck} = Wx::BitmapButton -> new($this, -1, $bullseye);
  $hbox->Add($this->{emin_pluck}, 0, wxRIGHT|wxALIGN_CENTRE, 5);

  $hbox->Add(Wx::StaticText->new($this, -1, 'to'), 0, wxRIGHT|wxALIGN_CENTRE, 5);
  $this->{emax} = Wx::TextCtrl->new($this, -1, $this->{emax}, wxDefaultPosition, $tcsize, wxTE_PROCESS_ENTER);
  $hbox->Add($this->{emax}, 0, wxLEFT|wxRIGHT|wxALIGN_CENTRE, 5);
  $this->{emax_pluck} = Wx::BitmapButton -> new($this, -1, $bullseye);
  $hbox->Add($this->{emax_pluck}, 0, wxRIGHT|wxALIGN_CENTRE, 5);

  EVT_BUTTON($this, $this->{emin_pluck}, sub{ $this->grab_bound('emin') });
  EVT_BUTTON($this, $this->{emax_pluck}, sub{ $this->grab_bound('emax') });


  $this->{components} = Wx::CheckBox->new($this, -1, "Plot components");
  $this->{residual}   = Wx::CheckBox->new($this, -1, "Plot residual");
  $hbox->Add($this->{components}, 0, wxLEFT|wxRIGHT|wxALIGN_CENTRE, 5);
  $hbox->Add($this->{residual},   0, wxLEFT|wxRIGHT|wxALIGN_CENTRE, 5);

  $this->{notebook} = Wx::Notebook->new($this, -1, wxDefaultPosition, wxDefaultSize, wxNB_TOP);
  $box -> Add($this->{notebook}, 1, wxGROW|wxALL, 2);
  $this->{mainpage} = $this->main_page($this->{notebook});
  $this->{fitspage} = $this->fit_page($this->{notebook});
  $this->{markedpage} = $this->marked_page($this->{notebook});
  $this->{notebook} ->AddPage($this->{mainpage}, 'Lineshapes',    1);
  $this->{notebook} ->AddPage($this->{fitspage}, 'Fit results',   0);
  $this->{notebook} ->AddPage($this->{markedpage}, 'Sequence',      0);


  $this->{document} = Wx::Button->new($this, -1, 'Document section: peak fitting');
  $box -> Add($this->{document}, 0, wxGROW|wxALL, 2);
  EVT_BUTTON($this, $this->{document}, sub{  $app->document("analysis.peak")});

  $this->SetSizerAndFit($box);
  return $this;
};

sub main_page {
  my ($this, $nb) = @_;

  my $panel = Wx::Panel->new($nb, -1, wxDefaultPosition, wxDefaultSize, wxMAXIMIZE_BOX );
  $this->{panel} = $panel;
  $this->{vbox} = Wx::BoxSizer->new( wxVERTICAL);
  $this->{increment} =  0;

  my $actionsbox       = Wx::StaticBox->new($panel, -1, 'Actions', wxDefaultPosition, wxDefaultSize);
  my $actionsboxsizer  = Wx::StaticBoxSizer->new( $actionsbox, wxHORIZONTAL );
  $this->{vbox}   -> Add($actionsboxsizer, 0, wxGROW|wxALL, 5);
  $this->{fit}         = Wx::Button->new($panel, -1, "Fit");
  $this->{plot}        = Wx::Button->new($panel, -1, "Plot sum");
  $this->{fitmarked}   = Wx::Button->new($panel, -1, "Fit marked");
  $this->{reset}       = Wx::Button->new($panel, -1, "Reset");
  $this->{save}        = Wx::Button->new($panel, -1, "Save fit");
  #$this->{make}        = Wx::Button->new($panel, -1, "Make group");
  foreach my $ac (qw(fit plot fitmarked reset save)) { #  make
    $actionsboxsizer -> Add($this->{$ac}, 1, wxLEFT|wxRIGHT, 3);
    $this->{$ac}->Enable(0);
  };
  EVT_BUTTON($this, $this->{fit},   sub{ $this->fit(0) });
  EVT_BUTTON($this, $this->{plot},  sub{ $this->fit(1) });
  EVT_BUTTON($this, $this->{fitmarked},  sub{ $this->sequence });
  EVT_BUTTON($this, $this->{reset}, sub{ $this->reset_all });
  EVT_BUTTON($this, $this->{save},  sub{ $this->save });
  #EVT_BUTTON($this, $this->{make},  sub{ $this->make });

  my $hbox = Wx::BoxSizer->new( wxHORIZONTAL);
  $this->{vbox} -> Add($hbox, 0, wxGROW|wxALL, 0);

  my $stepbox      = Wx::StaticBox->new($panel, -1, 'Step functions', wxDefaultPosition, wxDefaultSize);
  my $stepboxsizer = Wx::StaticBoxSizer->new( $stepbox, wxHORIZONTAL );
  $hbox -> Add($stepboxsizer, 1, wxGROW|wxALL, 5);
  $this->{steps}   = Wx::Choice->new($panel, -1, wxDefaultPosition, wxDefaultSize, $steps);
  $this->{addstep} = Wx::Button->new($panel, -1, "Add step");
  $stepboxsizer->Add($this->{steps},   0, wxALL, 5);
  $stepboxsizer->Add($this->{addstep}, 1, wxGROW|wxALL, 5);
  EVT_BUTTON($this, $this->{addstep}, sub{OnShape(@_, 'steps')});
  $this->{steps}->SetSelection(0);

  my $peakbox      = Wx::StaticBox->new($panel, -1, 'Peak functions', wxDefaultPosition, wxDefaultSize);
  my $peakboxsizer = Wx::StaticBoxSizer->new( $peakbox, wxHORIZONTAL );
  $hbox -> Add($peakboxsizer, 1, wxGROW|wxALL, 5);
  $this->{peaks}   = Wx::Choice->new($panel, -1, wxDefaultPosition, wxDefaultSize, $peaks);
  $this->{addpeak} = Wx::Button->new($panel, -1, "Add peak");
  $peakboxsizer->Add($this->{peaks},   0, wxALL, 5);
  $peakboxsizer->Add($this->{addpeak}, 1, wxGROW|wxALL, 5);
  EVT_BUTTON($this, $this->{addpeak}, sub{OnShape(@_, 'peaks')});
  $this->{peaks}->SetSelection(0);



  # $this->{atan}         = Wx::Button->new($panel, -1, "Arctangent");
  # $this->{erf}          = Wx::Button->new($panel, -1, "Error function");
  # $this->{gaussian}     = Wx::Button->new($panel, -1, "Gaussian");
  # $this->{lorentzian}   = Wx::Button->new($panel, -1, "Lorentzian");
  # $this->{pseudovoight} = Wx::Button->new($panel, -1, "Pseudo Voight");
  # foreach my $ls (qw(atan erf gaussian lorentzian pseudovoight)) {
  #   $addboxsizer -> Add($this->{$ls}, 1, wxLEFT|wxRIGHT, 3);
  #   EVT_BUTTON($this, $this->{$ls}, sub{ $this->add($ls) });
  # };

  $this->{main}  = Wx::ScrolledWindow->new($panel, -1, wxDefaultPosition, wxDefaultSize, wxALWAYS_SHOW_SB);
  $this->{lsbox} = Wx::BoxSizer->new( wxVERTICAL );
  $this->{main} -> SetScrollbars(10, 5, 30, 72);
  $this->{main} -> SetSizer($this->{lsbox});
  $this->{vbox} -> Add($this->{main}, 1, wxGROW|wxALL, 5);

  $panel->SetSizerAndFit($this->{vbox});
  return $panel;
};

sub fit_page {
  my ($this, $nb) = @_;
  my $panel = Wx::Panel->new($nb, -1, wxDefaultPosition, wxDefaultSize, wxMAXIMIZE_BOX );
  my $box = Wx::BoxSizer->new( wxVERTICAL);

  $this->{result} = Wx::TextCtrl->new($panel, -1, q{}, wxDefaultPosition, wxDefaultSize,
				       wxTE_MULTILINE|wxHSCROLL|wxTE_AUTO_URL|wxTE_READONLY|wxTE_RICH2);
  my $size = Wx::SystemSettings::GetFont(wxSYS_DEFAULT_GUI_FONT)->GetPointSize;
  $this->{result}->SetFont( Wx::Font->new( $size, wxTELETYPE, wxNORMAL, wxNORMAL, 0, "" ) );
  $box->Add($this->{result}, 1, wxGROW|wxALL, 5);

  $this->{resultplot} = Wx::Button->new($panel, -1, 'Plot data and fit');
  $box->Add($this->{resultplot}, 0, wxGROW|wxALL, 2);
  $this->{resultreport} = Wx::Button->new($panel, -1, 'Save fit as column data');
  $box->Add($this->{resultreport}, 0, wxGROW|wxALL, 2);
  EVT_BUTTON($this, $this->{resultplot},   sub{ $this->fit(1) });
  EVT_BUTTON($this, $this->{resultreport}, sub{ $this->save });
  $this->{resultplot}->Enable(0);
  $this->{resultreport}->Enable(0);

  $panel->SetSizerAndFit($box);
  return $panel;
};

sub marked_page {
  my ($this, $nb) = @_;
  my $panel = Wx::Panel->new($nb, -1, wxDefaultPosition, wxDefaultSize, wxMAXIMIZE_BOX );
  my $box = Wx::BoxSizer->new( wxVERTICAL);

  $this->{markedresults} = Wx::ListCtrl->new($panel, -1, wxDefaultPosition, wxDefaultSize, wxLC_REPORT|wxLC_HRULES||wxLC_SINGLE_SEL);
  $this->{markedresults}->InsertColumn( 0, "Data",            wxLIST_FORMAT_LEFT, 200 );
  $this->{markedresults}->InsertColumn( 1, "R-factor",        wxLIST_FORMAT_LEFT, 120 );
  $this->{markedresults}->InsertColumn( 2, "Red. chi-square", wxLIST_FORMAT_LEFT, 120 );
  $box->Add($this->{markedresults}, 1, wxALL|wxGROW, 3);
  EVT_LIST_ITEM_SELECTED($this, $this->{markedresults}, sub{seq_select(@_)});

  $this->{mresult} = Wx::TextCtrl->new($panel, -1, q{}, wxDefaultPosition, wxDefaultSize,
				       wxTE_MULTILINE|wxHSCROLL|wxTE_AUTO_URL|wxTE_READONLY|wxTE_RICH2);
  my $size = Wx::SystemSettings::GetFont(wxSYS_DEFAULT_GUI_FONT)->GetPointSize;
  $this->{mresult}->SetFont( Wx::Font->new( $size, wxTELETYPE, wxNORMAL, wxNORMAL, 0, "" ) );
  $box->Add($this->{mresult}, 1, wxGROW|wxALL, 3);

  my $hbox = Wx::BoxSizer->new( wxHORIZONTAL);
  $box->Add($hbox, 0, wxGROW|wxALL, 2);
  $this->{mchoices} = Wx::Choice->new($panel, -1, wxDefaultPosition, wxDefaultSize, ['a', 'b', 'c']);
  $hbox->Add($this->{mchoices},   1, wxALL, 0);
  $this->{plotmarked}	 = Wx::Button->new($panel, -1, 'Plot components from fit sequence');
  $hbox->Add($this->{plotmarked},   2, wxGROW|wxLEFT, 5);

  $this->{markedreport}	 = Wx::Button->new($panel, -1, 'Save fit sequence report as an Excel file');
  $box->Add($this->{markedreport}, 0, wxGROW|wxALL, 2);
  EVT_BUTTON($this, $this->{markedreport}, sub{seq_report(@_)});
  EVT_BUTTON($this, $this->{plotmarked},   sub{seq_plot(@_)});
  $this->{mchoices}->Enable(0);
  $this->{plotmarked}->Enable(0);
  $this->{markedreport}->Enable(0);

  $panel->SetSizerAndFit($box);
  return $panel;
};


## deprecated?
sub pull_values {
  my ($this, $data) = @_;
  1;
};

## this subroutine fills the controls when an item is selected from the Group list
sub push_values {
  my ($this, $data) = @_;
  $this->{PEAK}->data($::app->current_data);
  if (not $this->{fitted}) {
    foreach my $ac (qw(fit plot reset save resultreport resultplot)) { # make 
      $this->{$ac}->Enable(0);
    };
  };
  return if ($::app->{plotting});
  $this->{PEAK} -> po -> set(e_norm   => 1,
			     e_markers=> 1,
			     e_bkg    => 0,
			     e_der    => 0,
			     e_sec    => 0,
			     emin     => $this->{emin}->GetValue - 10,
			     emax     => $this->{emax}->GetValue + 10,);
  $this->{PEAK}->po->start_plot;
  $::app->current_data->plot('e');
  $::app->{lastplot} = ['E', 'single'];
};

## this subroutine sets the enabled/frozen state of the controls
sub mode {
  my ($this, $data, $enabled, $frozen) = @_;
  1;
};

sub tilt {
  my ($this, $text, $no_result) = @_;
  $this->{result}->SetValue($text) if not $no_result;
  $::app->{main}->status($text, 'error');
  return 0;
};


sub OnShape {
  my ($this, $event, $which) = @_;
  my $sel = $this->{$which}->GetStringSelection;
  $this->add($sel);
};

sub add {
  my ($this, $function) = @_;
  ++$this->{count};
  my $box;
  my $str;
  my @list = (@$steps, @$peaks);
  if (any {$function eq $_} @list) {
    my $func = lc($function);
    $str = Demeter->randomstring(3);
    ($box, $this->{'func'.$str}) = $this->threeparam($func, $str);
  } else {
    $this->tilt("$function is not yet implemented",1);
    --$this->{count};
    return;
  };

#  $this->{lsbox} -> Add($this->{'func'.$this->{count}}, 0, wxGROW|wxALL, 5);
#  $this->{main}  -> SetScrollbars(0, 72, 0, $this->{count});
#  $this->{main}  -> SetSizer($this->{lsbox});
  $this->{main}  -> Scroll(0,0);
  $this->{lsbox} -> Add($this->{'func'.$str}, 0, wxGROW|wxALL, 5);
  $this->{main}  -> SetSizer($this->{lsbox});
  my $nn = grep {$_ =~ m{func\w{3}}} (keys %$this);
  my $n               = ($nn<5) ? 5 : $nn;
  my ($x,$y)          = $box->GetSizeWH;
  $this->{increment}  = max($y, $this->{increment});
  $this->{main}  -> SetScrollbars(10, $n, 30, $this->{increment}+11);
  $this->{main}  -> Refresh;
  ($x,$y)             = $box->GetSizeWH;
  $this->{increment}  = max($y, $this->{increment});
  if ($nn>4) {
    $this->{main}  -> Scroll(0,$n*$this->{increment});
  };

  foreach my $ac (qw(fit plot)) {
    $this->{$ac}->Enable(1);
  };

  return $str;
};


sub threeparam {
  my ($this, $fun, $n) = @_;

  #my $index = $this->increment($fun);

  my $box       = Wx::StaticBox->new($this->{main}, -1, $map{$fun}, wxDefaultPosition, wxDefaultSize);
  my $boxsizer  = Wx::StaticBoxSizer->new( $box, wxVERTICAL );

  $this->{'box'.$n} = $box;
  $this->{'type'.$n} = $fun;

  my $hbox = Wx::BoxSizer->new( wxHORIZONTAL );
  $boxsizer->Add($hbox, 0, wxGROW|wxLEFT|wxRIGHT|wxTOP, 3);
  $hbox -> Add(Wx::StaticText->new($this->{main}, -1, "Name"), 0, wxALL, 3);
  $this->{'name'.$n} = Wx::TextCtrl->new($this->{main}, -1, lc($map{$fun})." ".$n, wxDefaultPosition, [120,-1], wxTE_PROCESS_ENTER);
  $hbox -> Add($this->{'name'.$n}, 0, wxGROW|wxLEFT|wxRIGHT, 5);

  if (($ENV{DEMETER_BACKEND} eq 'ifeffit') and ($fun =~ m{$STEPLIKE})) {
    $this->{'swap'.$n} = Wx::HyperlinkCtrl->new($this->{main}, -1, 'change to '.lc($map{$swap{$fun}}),
						q{}, wxDefaultPosition, wxDefaultSize, wxNO_BORDER);
    $this->{'swap'.$n}->SetNormalColour(wxBLACK);
    $this->{'swap'.$n}->SetVisitedColour(wxBLACK);
    EVT_HYPERLINK($this, $this->{"swap$n"}, sub{ $this->swap($_[1], $n) });
    EVT_RIGHT_DOWN($this->{"swap$n"}, sub{$this->swap($_[1], $n)});
  } else {
    $this->{'swap'.$n} = Wx::HyperlinkCtrl->new($this->{main}, -1, 'change function',
						q{}, wxDefaultPosition, wxDefaultSize, wxNO_BORDER);
    $this->{'swap'.$n}->SetNormalColour(wxBLACK);
    $this->{'swap'.$n}->SetVisitedColour(wxBLACK);
    EVT_HYPERLINK($this, $this->{"swap$n"}, sub{ $this->swap($_[1], $n) });
    #EVT_LEFT_DOWN($this->{"swap$n"}, sub{$this->swap($_[1], $n)});
    EVT_RIGHT_DOWN($this->{"swap$n"}, sub{$this->swap($_[1], $n)});
    EVT_MENU($this->{"swap$n"}, -1, sub{ $this->do_swap_peak(@_, $n) });
  };
  $hbox -> Add($this->{'swap'.$n}, 0, wxGROW|wxLEFT|wxRIGHT, 5);
  $hbox->Add(1,1,1);
  $this->{'skip'.$n} = Wx::CheckBox->new($this->{main}, -1, 'exclude');
  $hbox -> Add($this->{'skip'.$n}, 0, wxGROW|wxLEFT|wxRIGHT, 5);
  $this->{'del'.$n} = Wx::Button->new($this->{main}, -1, 'delete', wxDefaultPosition, wxDefaultSize, wxBU_EXACTFIT);
  $hbox -> Add($this->{'del'.$n}, 0, wxLEFT|wxRIGHT, 5);

  $hbox = Wx::BoxSizer->new( wxHORIZONTAL );
  $boxsizer->Add($hbox, 0, wxGROW|wxALL, 3);

  $hbox -> Add(Wx::StaticText->new($this->{main}, -1, "Height"), 0, wxALL, 3);
  $this->{'val0'.$n} = Wx::TextCtrl->new($this->{main}, -1, 1, wxDefaultPosition, [40,-1], wxTE_PROCESS_ENTER);
  $hbox -> Add($this->{'val0'.$n}, 0, wxGROW|wxLEFT|wxRIGHT, 0);
  $this->{'fix0'.$n} = Wx::CheckBox->new($this->{main}, -1, 'fix');
  $hbox -> Add($this->{'fix0'.$n}, 0, wxGROW|wxLEFT|wxRIGHT, 1);

  $hbox->Add(1,1,1);

  my $lab = ($fun =~ m{$STEPLIKE}) ? 'Center' : $E0;
  $hbox -> Add(Wx::StaticText->new($this->{main}, -1, $lab), 0, wxALL, 3);
  $this->{'val1'.$n} = Wx::TextCtrl->new($this->{main}, -1, 0, wxDefaultPosition, $tcsize, wxTE_PROCESS_ENTER);
  $hbox -> Add($this->{'val1'.$n}, 0, wxGROW|wxLEFT|wxRIGHT, 0);
  $this->{'grab'.$n} = Wx::BitmapButton -> new($this->{main}, -1, $bullseye);
  $hbox->Add($this->{'grab'.$n}, 0, wxGROW|wxLEFT|wxRIGHT, 0);
  $this->{'fix1'.$n} = Wx::CheckBox->new($this->{main}, -1, 'fix');
  $hbox -> Add($this->{'fix1'.$n}, 0, wxGROW|wxLEFT|wxRIGHT, 1);

  $hbox->Add(1,1,1);

  $lab = ($fun =~ m{$STEPLIKE}) ? 'Width' : $SIGMA;
  my $value = ($fun =~ m{$STEPLIKE}) ? sprintf("%.3f", Xray::Absorption->get_gamma($this->{PEAK}->data->bkg_z, $this->{PEAK}->data->fft_edge)) : $this->{PEAK}->defwidth;
  $hbox -> Add(Wx::StaticText->new($this->{main}, -1, $lab), 0, wxALL, 3);
  $this->{'val2'.$n} = Wx::TextCtrl->new($this->{main}, -1, $value, wxDefaultPosition, [40,-1], wxTE_PROCESS_ENTER);
  $hbox -> Add($this->{'val2'.$n}, 0, wxGROW|wxLEFT|wxRIGHT, 0);
  $this->{'fix2'.$n} = Wx::CheckBox->new($this->{main}, -1, 'fix');
  $hbox -> Add($this->{'fix2'.$n}, 0, wxGROW|wxLEFT|wxRIGHT, 1);

  if ($fun !~ m{$STEPLIKE}) {
    $hbox->Add(1,1,1);
    $this->{'lab3'.$n} = Wx::StaticText->new($this->{main}, -1, $GAMMA);
    $hbox -> Add($this->{'lab3'.$n}, 0, wxALL, 3);
    $this->{'val3'.$n} = Wx::TextCtrl->new($this->{main}, -1, 0.5, wxDefaultPosition, [40,-1], wxTE_PROCESS_ENTER);
    $hbox -> Add($this->{'val3'.$n}, 0, wxGROW|wxLEFT|wxRIGHT, 0);
    $this->{'fix3'.$n} = Wx::CheckBox->new($this->{main}, -1, 'fix');
    $hbox -> Add($this->{'fix3'.$n}, 0, wxGROW|wxLEFT|wxRIGHT, 1);
    if ($fun =~ m{$PEAK3}) {
      $this->{'lab3'.$n}->Enable(0);
      $this->{'val3'.$n}->Enable(0);
      $this->{'fix3'.$n}->Enable(0);
    };

  };

  $this->{'fix0'.$n}->SetValue(0);
  $this->{'fix1'.$n}->SetValue(1);
  $this->{'fix2'.$n}->SetValue(0);
  $this->{'fix3'.$n}->SetValue(0) if ($fun !~ m{$STEPLIKE});


  EVT_BUTTON($this, $this->{'grab'.$n}, sub{ $this->grab_center($n) });
  EVT_BUTTON($this, $this->{'del'.$n},  sub{ $this->discard($n) });

  return ($box, $boxsizer);
};

sub increment {
  my ($this, $fun) = @_;
  my $index = 0;
  foreach my $k (keys %$this) {
    next if ($k !~ m{func(\w{3})});
    next if ($this->{'type'.$1} ne $fun);
    $index = $1 if ($this->{'name'.$1}->GetValue =~ m{$fun\s*(\d+)}i);
  };
  ++$index;
  return $index;
};

sub grab_bound {
  my ($this, $which) = @_;
  my $on_screen = lc($::app->{lastplot}->[0]);
  if ($on_screen ne 'e') {
    $::app->{main}->status("You can only pluck for a peakfit from an energy plot.");
    return;
  };

  my ($ok, $x, $y) = $::app->cursor;
  return if not $ok;
  $::app->{main}->status(q{Pluck canceled}), return if ($x < -90000);

  $this->{$which}->SetValue(sprintf("%.3f", $x-$this->{PEAK}->data->bkg_e0));

  $::app->{main}->status("Plucked $x for $which");
};


sub grab_center {
  my ($this, $n) = @_;
  my $on_screen = lc($::app->{lastplot}->[0]);
  if ($on_screen ne 'e') {
    $::app->{main}->status("You can only pluck for a peakfit from an energy plot.");
    return;
  };

  my ($ok, $x, $y) = $::app->cursor;
  return if not $ok;
  $::app->{main}->status(q{Pluck canceled}), return if ($x < -90000);
  $y = $this->{PEAK}->data->yofx($this->{PEAK}->data->nsuff, q{}, $x);

  $this->{'val1'.$n}->SetValue($x);
  $this->{'val0'.$n}->SetValue(sprintf("%.3f",$y));

  $::app->{main}->status("Plucked $x for ".$this->{'type'.$n}." center");
};


sub fetch {
  my ($this) = @_;

  my $peak = $this->{PEAK};
  my $string = q{};
  $peak -> xmin($this->{emin}->GetValue);
  $peak -> xmax($this->{emax}->GetValue);
  ## sanity checks
  if (abs($this->{emin}->GetValue) > 200) {
    $string .= "The lower bound of the fit is very far from E0\n\n";
  };
  if (abs($this->{emax}->GetValue) > 200) {
    $string .= "The upper bound of the fit is very far from E0\n\n";
  };

  $peak -> plot_components($this->{components}->GetValue);
  $peak -> plot_residual($this->{residual}->GetValue);
  my $nls = 0;
  foreach my $k (keys %$this) {
    next if ($k !~ m{func(\w{3})});
    my $key = $1;
    next if $this->{'skip'.$key}->GetValue;
    ++$nls;
    my $fun = $this->{'type'.$key};
    $fun = 'pvoigt' if $fun =~ m{pseudo[-_]voigt}i;
    $this->{'lineshape'.$key} = $peak -> add($fun,
					     name  => $this->{'name'.$key}->GetValue,
					     a0    => $this->{'val0'.$key}->GetValue,
					     fix0  => $this->{'fix0'.$key}->GetValue,
					     a1    => $this->{'val1'.$key}->GetValue,
					     fix1  => $this->{'fix1'.$key}->GetValue,
					     a2    => $this->{'val2'.$key}->GetValue,
					     fix2  => $this->{'fix2'.$key}->GetValue,
					     a3    => 0,
					     fix3  => 1,
					    );
    ## sanity checks
    if ($this->{'val1'.$key}->GetValue < ($this->{PEAK}->data->bkg_e0-30)) {
      $string .= sprintf("The centroid of %s appears to be well below the XANES data range.\n\n",
			 $this->{'lineshape'.$key}->name);
    };
    if ($this->{'val1'.$key}->GetValue > ($this->{PEAK}->data->bkg_e0+200)) {
      $string .= sprintf("The centroid of %s appears to be well above the XANES data range.\n\n",
			 $this->{'lineshape'.$key}->name);
    };
    if ($this->{'val2'.$key}->GetValue < 0) {
      $string .= sprintf("The width of %s is negative.\n\n",
			 $this->{'lineshape'.$key}->name);
    };
    if ($this->{'lineshape'.$key}->nparams == 4) {
      $this->{'lineshape'.$key}->a3($this->{'val3'.$key}->GetValue);
      $this->{'lineshape'.$key}->fix3($this->{'fix3'.$key}->GetValue);
      ## sanity checks
      if ($this->{'val3'.$key}->GetValue < 0) {
	$string .= sprintf("The 4th parameter of %s is negative.\n\n",
			   $this->{'lineshape'.$key}->name);
      };
    };
  };
  return ($nls, $string);
};

sub fit {
  my ($this, $nofit) = @_;
  $nofit ||= 0;
  my $busy = Wx::BusyCursor->new();
  my $peak = $this->{PEAK};
  $peak -> data($::app->current_data);
  $peak -> clean;
  $this->{markedresults}->DeleteAllItems;
  $this->{mresult}->Clear;
  my ($nls, $warning) = $this -> fetch;
  if ($warning) {
    my $yesno = Demeter::UI::Wx::VerbDialog->new($::app->{main}, -1,
						 $warning,
						 "Continue anyway?",
						 "Continue");
    my $result = $yesno->ShowModal;
    if ($result == wxID_NO) {
      $::app->{main}->status("Peak fit canceled");
      return;
    };
  };

  $peak -> fit($nofit);
  if (not $nofit) {
    $this->{result}->Clear;
    $this->{result}->SetValue($peak->report);
    foreach my $k (keys %$this) {
      next if ($k !~ m{func(\w{3})});
      my $key = $1;
      next if $this->{'skip'.$key}->GetValue;
      $this->{'val0'.$key}->SetValue(sprintf("%.3f", $this->{'lineshape'.$key}->a0));
      $this->{'val1'.$key}->SetValue(sprintf("%.3f", $this->{'lineshape'.$key}->a1));
      $this->{'val2'.$key}->SetValue(sprintf("%.3f", $this->{'lineshape'.$key}->a2));
      if ($this->{'lineshape'.$key}->nparams == 4) {
	$this->{'val3'.$key}->SetValue(sprintf("%.3f", $this->{'lineshape'.$key}->a3));
      };
    };
    $this->{fitted} = 1;
  };
  #my $save = $peak->po->title;
  #$peak->po->title($::app->{main}->{Other}->{title}->GetValue);
  $peak -> plot('e');
  #$peak->po->title($save);
  $::app->{lastplot} = ['E', 'single'];


  if (not $nofit) {
    foreach my $ac (qw(save reset fitmarked resultreport resultplot)) {
      $this->{$ac}->Enable(1);
    };
    $::app->{main}->status(sprintf("Performed peak fitting on %s using %d lineshapes and %d variables",
				   $peak->data->name, $nls, $peak->nparam));
  };
  undef $busy;
};

sub sequence {
  my ($this) = @_;
  my $busy = Wx::BusyCursor->new();
  my @groups = $::app->marked_groups;
  my $i = 0;
  my $start = DateTime->now( time_zone => 'floating' );
  $this->{PEAK} -> sentinal(sub{$this->seq_sentinal($#groups+1)});
  $this->{PEAK} -> clean;
  my $nls = $this -> fetch;
  my $save = $this->{PEAK} -> include_caller;
  $this->{PEAK} -> include_caller(0);
  $this->{PEAK} -> sequence(@groups);
  $this->{PEAK} -> include_caller($save);

  ## restore the proper fit
  $this->{result}->Clear;
  $this->{result}->SetValue($this->{PEAK}->report);
  foreach my $k (keys %$this) {
    next if ($k !~ m{func(\w{3})});
    my $key = $1;
    next if $this->{'skip'.$key}->GetValue;
    $this->{'val0'.$key}->SetValue(sprintf("%.3f", $this->{'lineshape'.$key}->a0));
    $this->{'val1'.$key}->SetValue(sprintf("%.3f", $this->{'lineshape'.$key}->a1));
    $this->{'val2'.$key}->SetValue(sprintf("%.3f", $this->{'lineshape'.$key}->a2));
    if ($this->{'lineshape'.$key}->nparams == 4) {
      $this->{'val3'.$key}->SetValue(sprintf("%.3f", $this->{'lineshape'.$key}->a3));
    };
  };

  ## fill in the sequence notebook page
  $this->seq_results(@groups);

  my $finishtext = Demeter->howlong($start, sprintf("Peak fitting %d groups", $#groups+1));
  $this->{mchoices}     -> Enable(1);
  $this->{plotmarked}   -> Enable(1);
  $this->{markedreport} -> Enable(1);
  $::app->{main}->status($finishtext);
  undef $busy;
};
sub seq_sentinal {
  my ($this, $size) = @_;
  $::app->{main}->status($this->{PEAK}->seq_count." of $size peak fits", 'wait|nobuffer');
};

sub seq_results {
  my ($this, @data) = @_;
  #Demeter->Dump($this->{PEAK}->seq_results);

  $this->{markedresults}->DeleteAllItems;
  $this->{mresult}->Clear;

  my ($i, $row) = (0,0);
  foreach my $res (@{ $this->{PEAK}->seq_results }) {
    my $rfact = $res->{Rfactor};
    my $chinu = $res->{Chinu};

    my $idx = $this->{markedresults}->InsertStringItem($i, $row);
    $this->{markedresults}->SetItemData($idx, $i);
    $this->{markedresults}->SetItem( $idx, 0, $data[$i]->name );
    $this->{markedresults}->SetItem( $idx, 1, sprintf("%.5g", $rfact) );
    $this->{markedresults}->SetItem( $idx, 2, sprintf("%.5g", $chinu) );
    ++$i;
  };
  $this->{PEAK}->restore($this->{PEAK}->seq_results->[0]);
  $this->{mresult}->SetValue($this->{PEAK}->report);
  $this->{notebook}->ChangeSelection(2);

  $this->{mchoices}->Clear;
  foreach my $ls (@{$this->{PEAK}->lineshapes}) {
    $this->{mchoices}->Append(sprintf("%s - %s", $ls->name, 'height'),   [$ls->group, 0]) if not $ls->fix0;
    $this->{mchoices}->Append(sprintf("%s - %s", $ls->name, 'centroid'), [$ls->group, 1]) if not $ls->fix1;
    $this->{mchoices}->Append(sprintf("%s - %s", $ls->name, 'width'),    [$ls->group, 2]) if not $ls->fix2;
    $this->{mchoices}->Append(sprintf("%s - %s", $ls->name, 'gamma'),    [$ls->group, 3]) if not $ls->fix3;
  };
  $this->{mchoices}->SetSelection(0);

};

sub seq_plot {
  my ($this, $event) = @_;
  my $i = $this->{mchoices}->GetSelection;
  my $param = $this->{mchoices}->GetClientData($i); # this return [lineshape group, 0 to 3]

  Demeter->po->start_plot;
  my $tempfile = Demeter->po->tempfile;
  open my $T, '>'.$tempfile;
  my $j = -1;

  foreach my $res (@{ $this->{PEAK}->seq_results }) {
    my $rarr = $res->{$param->[0]};
    my $n = 2 + 3*$param->[1];
    my ($val, $err) = ($rarr->[$n], $rarr->[$n+1]);
    print $T ++$j, "  ", $val, "  ", $err, $/;
  };
  close $T;
  my ($t, $p) = split(/ - /, $this->{mchoices}->GetStringSelection);
  Demeter->chart('plot', 'plot_file', {file=>$tempfile, xmin=>-0.2, xmax=>$j+0.2,
				       xlabel=>'data set', title=>$t,
				       param=>$p, showy=>0});

};
sub seq_report {
  my ($this, $event) = @_;
  my $init = ($::app->{main}->{project}->GetLabel eq '<untitled>') ? 'peak_sequence' : $::app->{main}->{project}->GetLabel.'_peak_sequence';
  $init .= '.xls';
  my $fd = Wx::FileDialog->new( $::app->{main}, "Save peak fit sequence results", cwd, $init,
				"Excel (*.xls)|*.xls|All files (*)|*",
				wxFD_SAVE|wxFD_CHANGE_DIR|wxFD_OVERWRITE_PROMPT,
				wxDefaultPosition);
  if ($fd->ShowModal == wxID_CANCEL) {
    $::app->{main}->status("Saving peak fit sequence results has been canceled.");
    return 0;
  };
  my $fname = $fd->GetPath;
  #return if $::app->{main}->overwrite_prompt($fname); # work-around gtk's wxFD_OVERWRITE_PROMPT bug (5 Jan 2011)
  $this->{PEAK}->report_excel($fname);
  $::app->{main}->status("Wrote peak fit sequence report as an Excel spreadsheet to $fname");
};

sub seq_select {
  my ($this, $event) = @_;
  my $busy = Wx::BusyCursor->new();
  my $index  = (ref($event) =~ m{Event}) ? $event->GetIndex : $event;
  $this->{PEAK}    -> restore($this->{PEAK}->seq_results->[$index]);
  $this->{mresult} -> SetValue($this->{PEAK}->report);
  $this->{PEAK}    -> plot_components($this->{components}->GetValue);
  $this->{PEAK}    -> plot_residual($this->{residual}->GetValue);
  $this->{PEAK}    -> plot;
  undef $busy;
};

sub save {
  my ($this) = @_;
  my $data = $::app->current_data;
  (my $name = $data->name) =~ s{\s+}{_}g;
  my $fd = Wx::FileDialog->new( $::app->{main}, "Save peak fit to a file", cwd, $name.".peak",
				"peak fit (*.peak)|*.peak|All files (*)|*",
				wxFD_SAVE|wxFD_CHANGE_DIR|wxFD_OVERWRITE_PROMPT,
				wxDefaultPosition);
  if ($fd->ShowModal == wxID_CANCEL) {
    $::app->{main}->status("Saving peak fitting results to a file has been canceled.");
    return 0;
  };
  my $fname = $fd->GetPath;
  #return if $::app->{main}->overwrite_prompt($fname); # work-around gtk's wxFD_OVERWRITE_PROMPT bug (5 Jan 2011)
  $this->{PEAK}->save($fname);
  $::app->{main}->status("Saved peak fitting results to $fname");
};

sub reset_all {
  my ($this) = @_;
  $this->{result}->Clear;
  foreach my $k (keys %$this) {
    next if ($k !~ m{func(\w{3})});
    my $key = $1;
    ## height of data at centroid
    my $y = $this->{PEAK}->data->yofx($this->{PEAK}->data->nsuff, q{}, $this->{'val1'.$key}->GetValue);
    $this->{'val0'.$key}->SetValue(sprintf("%.3f", $y));
    ## width=0.5 or gamma_ch for $STEPLIKE
    $this->{'val2'.$key}->SetValue(0.5);
    if ($this->{"type$key"} =~ m{$STEPLIKE}) {
      $this->{'val2'.$key}->SetValue(sprintf("%.3f", Xray::Absorption->get_gamma($this->{PEAK}->data->bkg_z,
										$this->{PEAK}->data->fft_edge)))
    };
    if ($this->{'lineshape'.$key}->nparams == 4) {
      $this->{'val3'.$key}->SetValue(0.5);
    };
    $this->{'fix0'.$key}->SetValue(0);
    $this->{'fix1'.$key}->SetValue(1);
    $this->{'fix2'.$key}->SetValue(0);
    $this->{'fix3'.$key}->SetValue(0) if ($this->{"type$key"} !~ m{$STEPLIKE});
  };
};

sub make {
  my ($this) = @_;
  $this->tilt("Making a data group is not yet implemented",1);
};

sub discard {
  my ($this, $n) = @_;
  my $name = $this->{'name'.$n}->GetValue;
  my $yesno = Demeter::UI::Wx::VerbDialog->new($::app->{main}, -1,
					       "Really delete $name?",
					       "Delete lineshape?",
					       "Delete lineshape");
  my $result = $yesno->ShowModal;
  if ($result == wxID_NO) {
    $::app->{main}->status("Not deleting lineshape.");
    return 0;
  };
  ## demolish the LineShape object, if it exists
  $this->{'lineshape'.$n}->DEMOLISH if exists $this->{'lineshape'.$n};
  ## dig through the hierarchy of the StaticBox and Remove/Destroy each element
  foreach my $s ($this->{'func'.$n}->GetChildren) {
    foreach my $w ($s->GetSizer->GetChildren) {
      $w->GetWindow->Destroy if defined($w->GetWindow);
    };
    $this->{'func'.$n}->Remove($s->GetSizer);
  };
  $this->{'func'.$n}->GetStaticBox->Destroy;
  $this->{lsbox} -> Remove($this->{'func'.$n});
  delete $this->{'lineshape'.$n};
  delete $this->{'type'.$n};
  delete $this->{"func$n"};
  delete $this->{"box$n"};
  ## Refit the containiner
  $this->{main}  -> Scroll(0,0);
  #$this->{lsbox} -> Fit($this->{main});
  #$this->{vbox}  -> Fit($this->{panel});
  $this->{lsbox} -> Layout;
  $this->{vbox}  -> Layout;

  if (not grep {$_ =~ m{func\w{3}}} (keys %$this)) {
    foreach my $ac (qw(fit plot fitmarked reset save)) {
      $this->{$ac}->Enable(0);
    };
  };

  $::app->{main}->status("Deleted $name (lineshape #$n)");
};

sub swap {
  my ($this, $event, $n) = @_;
  if (($ENV{DEMETER_BACKEND} eq 'ifeffit') and ($this->{'type'.$n} =~ m{$STEPLIKE})) {
    $this->swap_ifeffit_step($n);
  } else {
    $this->swap_peak($n, $event);
  };
};

sub swap_ifeffit_step {
  my ($this, $n) = @_;
  my $name = $this->{'name'.$n}->GetValue;
  my $type = $this->{'type'.$n};
  if ($name =~ lc($map{$type})) {
    my $to = lc($map{$swap{$type}});
    $name =~ s{$map{$type}}{$to}i;
  };
  $this->{'name'.$n}->SetValue($name);
  $this->{'type'.$n} = $swap{$this->{'type'.$n}};
  $this->{"box$n"} -> SetLabel($map{$this->{'type'.$n}});
  $this->{"swap$n"} -> SetLabel("change to $type");
  $::app->{main} -> Update;
};

sub swap_peak {
  my ($this, $n, $event) = @_;
  my $type = $this->{'type'.$n};
  $this->{curentn} = $n;

  my $menu  = Wx::Menu->new(q{});
  if (any {$type eq lc($_)} @$peaks) {
    foreach my $p (@$peaks) {
      next if $type eq lc($p);
      if ($p eq 'pseudo_voigt') {
	$menu->Append($SWAPHASH{Pseudo_Voigt}, $p);
      } else {
	$menu->Append($SWAPHASH{ucfirst($p)}, $p);
      };
    };
  } elsif (any {$type eq lc($_)} @$steps) {
    foreach my $p (@$steps) {
      next if $type eq lc($p);
      $menu->Append($SWAPHASH{ucfirst($p)}, $p);
    };
  };
  $this->{'swap'.$n} -> PopupMenu($menu, Wx::Point->new(10,10));
};

sub do_swap_peak {
  my ($this, $text, $event, $n) = @_;
  my $id = $event->GetId;
  my %hash = reverse(%SWAPHASH);
  my $selection = $hash{$id};
  $this->{'name'.$n}->SetValue(lc($selection)." $n");
  $this->{'type'.$n} = lc($selection);
  $this->{'box'.$n} -> SetLabel($selection);
  $::app->{main} -> Update;
  if (lc($selection) =~ m{$PEAK3}) {
    $this->{'lab3'.$n}->Enable(0);
    $this->{'val3'.$n}->Enable(0);
    $this->{'fix3'.$n}->Enable(0);
  } else {
    $this->{'lab3'.$n}->Enable(1);
    $this->{'val3'.$n}->Enable(1);
    $this->{'fix3'.$n}->Enable(1);
  };
};


## restore persistent information from a project file
sub reinstate {
  my ($this, $hash, $lineshapes) = @_;

  ## fit range
  my $data  = $this->{PEAK}->mo->fetch('Data', $hash->{datagroup});
  my $e0  = $data->bkg_e0 || 0;
  $this->{PEAK}->data($data);
  $this->{emin}->SetValue($hash->{xmin}-$e0);
  $this->{emax}->SetValue($hash->{xmax}-$e0);

  $this->{components}->SetValue($hash->{plot_components});
  $this->{residual}->SetValue($hash->{plot_residual});

  foreach my $ls (@{ $lineshapes }) {
    my $hash = {@$ls};
    my $func = ucfirst(lc($hash->{function}));
    $func = 'Pseudo_Voigt' if (lc($hash->{function}) =~ m{pseudo});
    my $str = $this->add($func);
    $this->{'val0'.$str}->SetValue($hash->{a0});
    $this->{'val1'.$str}->SetValue($hash->{a1});
    $this->{'val2'.$str}->SetValue($hash->{a2});
    $this->{'fix0'.$str}->SetValue($hash->{fix0});
    $this->{'fix1'.$str}->SetValue($hash->{fix1});
    $this->{'fix2'.$str}->SetValue($hash->{fix2});
    #if (lc($selection) =~ m{$PEAK3}) {
    #  $this->{'val3'.$str}->SetValue($hash->{a3});
    #  $this->{'fix3'.$str}->SetValue($hash->{fix3});
    #};
    $this->{fitted} = 1;
  };

  $::app->{main}->status("Restored Peak Fit state from project file");
};

1;


=head1 NAME

Demeter::UI::Athena::PeakFit - A peak fitting for Athena

=head1 VERSION

This documentation refers to Demeter version 0.9.25.

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

Bruce Ravel (http://bruceravel.github.io/home)

L<http://bruceravel.github.io/demeter/>

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2016 Bruce Ravel, (L<http://bruceravel.github.io/home>). All rights reserved>

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
