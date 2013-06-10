package Demeter::UI::Athena::PeakFit;

use strict;
use warnings;

use Wx qw( :everything );
use base 'Wx::Panel';
use Wx::Event qw(EVT_BUTTON EVT_LIST_ITEM_SELECTED EVT_CHECKBOX EVT_HYPERLINK EVT_CHOICE EVT_LEFT_DOWN EVT_MENU);

use Const::Fast;
use Cwd;
use File::Basename;
use File::Spec;
use Scalar::Util qw(looks_like_number);
use List::MoreUtils qw(any firstidx);
use List::Util qw(max);

use Demeter::UI::Wx::SpecialCharacters qw(:greek);

use vars qw($label);
$label = "Peak fitting";	# used in the Choicebox and in status bar messages to identify this tool


our $steps = ($ENV{DEMETER_BACKEND} eq 'larch') ? ['Atan', 'Erf', 'Logistic'] : ['Atan', 'Erf'];
our $peaks = ($ENV{DEMETER_BACKEND} eq 'larch')
  ? ['Gaussian', 'Lorentzian', 'Voigt', 'Pseudo_Voigt', 'Pearson7', 'Students_t']
  : ['Gaussian', 'Lorentzian'];

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
my $demeter  = $Demeter::UI::Athena::demeter;
my $icon     = File::Spec->catfile(dirname($INC{"Demeter/UI/Athena.pm"}), 'Athena', , 'icons', "bullseye.png");
my $bullseye = Wx::Bitmap->new($icon, wxBITMAP_TYPE_PNG);

my %map  = (atan => "Arctangent", erf => "Error function",
	    gaussian => "Gaussian", lorentzian => "Lorentzian");
my %swap = (atan => "erf", erf => "atan", gaussian => "lorentzian", lorentzian => "gaussian");

sub new {
  my ($class, $parent, $app) = @_;
  my $this = $class->SUPER::new($parent, -1, wxDefaultPosition, wxDefaultSize, wxMAXIMIZE_BOX );

  $this->{PEAK}   = Demeter::PeakFit->new(backend=>$ENV{DEMETER_BACKEND});
  $this->{emin}   = -15; #$demeter->co->default('peakfit', 'emin');
  $this->{emax}   =  15; #$demeter->co->default('peakfit', 'emax');
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

  $this->{components} = Wx::CheckBox->new($this, -1, "Plot components");
  $this->{residual}   = Wx::CheckBox->new($this, -1, "Plot residual");
  $hbox->Add($this->{components}, 0, wxLEFT|wxRIGHT|wxALIGN_CENTRE, 5);
  $hbox->Add($this->{residual},   0, wxLEFT|wxRIGHT|wxALIGN_CENTRE, 5);

  $this->{notebook} = Wx::Notebook->new($this, -1, wxDefaultPosition, wxDefaultSize, wxNB_TOP);
  $box -> Add($this->{notebook}, 1, wxGROW|wxALL, 2);
  $this->{mainpage} = $this->main_page($this->{notebook});
  $this->{fitspage} = $this->fit_page($this->{notebook});
  #this->{$markedpage} = $this->marked_page($this->{notebook});
  $this->{notebook} ->AddPage($this->{mainpage}, 'Lineshapes',    1);
  $this->{notebook} ->AddPage($this->{fitspage}, 'Fit results',   0);
  #$this->{notebook} ->AddPage($this->{markedpage}, 'Sequence',      0);

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
  $this->{reset}       = Wx::Button->new($panel, -1, "Reset");
  $this->{save}        = Wx::Button->new($panel, -1, "Save fit");
  #$this->{make}        = Wx::Button->new($panel, -1, "Make group");
  foreach my $ac (qw(fit plot reset save)) { #  make
    $actionsboxsizer -> Add($this->{$ac}, 1, wxLEFT|wxRIGHT, 3);
    $this->{$ac}->Enable(0);
  };
  EVT_BUTTON($this, $this->{fit},   sub{ $this->fit(0) });
  EVT_BUTTON($this, $this->{plot},  sub{ $this->fit(1) });
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

  my $peakbox      = Wx::StaticBox->new($panel, -1, 'Peak functions', wxDefaultPosition, wxDefaultSize);
  my $peakboxsizer = Wx::StaticBoxSizer->new( $peakbox, wxHORIZONTAL );
  $hbox -> Add($peakboxsizer, 1, wxGROW|wxALL, 5);
  $this->{peaks}   = Wx::Choice->new($panel, -1, wxDefaultPosition, wxDefaultSize, $peaks);
  $this->{addpeak} = Wx::Button->new($panel, -1, "Add peak");
  $peakboxsizer->Add($this->{peaks},   0, wxALL, 5);
  $peakboxsizer->Add($this->{addpeak}, 1, wxGROW|wxALL, 5);
  EVT_BUTTON($this, $this->{addpeak}, sub{OnShape(@_, 'peaks')});



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
  $this->{markedresults}->InsertColumn( 0, "Data",            wxLIST_FORMAT_LEFT, 100 );
  $this->{markedresults}->InsertColumn( 1, "R-factor",        wxLIST_FORMAT_LEFT, 120 );
  $this->{markedresults}->InsertColumn( 2, "Red. chi-square", wxLIST_FORMAT_LEFT, 120 );
  $box->Add($this->{markedresults}, 1, wxALL|wxGROW, 3);
  EVT_LIST_ITEM_SELECTED($this, $this->{markedresults}, sub{seq_select(@_)});

  $this->{mreport} = Wx::ListCtrl->new($panel, -1, wxDefaultPosition, wxDefaultSize, wxLC_REPORT|wxLC_HRULES||wxLC_SINGLE_SEL);
  $this->{mreport}->InsertColumn( 0, "Data", wxLIST_FORMAT_LEFT, 100 );
  $this->{mreport}->InsertColumn( 1, "LS 1", wxLIST_FORMAT_LEFT, 120 );
  $this->{mreport}->InsertColumn( 2, "LS 2", wxLIST_FORMAT_LEFT, 120 );
  $this->{mreport}->InsertColumn( 2, "LS 2", wxLIST_FORMAT_LEFT, 120 );
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
  my @list = (@$steps, @$peaks);
  if (any {$function eq $_} @list) {
    my $func = lc($function);
    ($box, $this->{'func'.$this->{count}}) = $this->threeparam($func, $this->{count});
  } else {
    $this->tilt("$function is not yet implemented",1);
    --$this->{count};
    return;
  };

#  $this->{lsbox} -> Add($this->{'func'.$this->{count}}, 0, wxGROW|wxALL, 5);
#  $this->{main}  -> SetScrollbars(0, 72, 0, $this->{count});
#  $this->{main}  -> SetSizer($this->{lsbox});
  $this->{main}  -> Scroll(0,0);
  $this->{lsbox} -> Add($this->{'func'.$this->{count}}, 0, wxGROW|wxALL, 5);
  $this->{main}  -> SetSizer($this->{lsbox});
  my $n               = ($this->{count}<5) ? 5 : $this->{count};
  my ($x,$y)          = $box->GetSizeWH;
  $this->{increment}  = max($y, $this->{increment});
  $this->{main}  -> SetScrollbars(10, $n, 30, $this->{increment}+11);
  $this->{main}  -> Refresh;
  ($x,$y)             = $box->GetSizeWH;
  $this->{increment}  = max($y, $this->{increment});
  if ($this->{count}>4) {
    $this->{main}  -> Scroll(0,$n*$this->{increment});
  };

  foreach my $ac (qw(fit plot reset)) {
    $this->{$ac}->Enable(1);
  };

};


sub threeparam {
  my ($this, $fun, $n) = @_;

  my $index = $this->increment($fun);

  my $box       = Wx::StaticBox->new($this->{main}, -1, $map{$fun}, wxDefaultPosition, wxDefaultSize);
  my $boxsizer  = Wx::StaticBoxSizer->new( $box, wxVERTICAL );

  $this->{'box'.$n} = $box;
  $this->{'type'.$n} = $fun;

  my $hbox = Wx::BoxSizer->new( wxHORIZONTAL );
  $boxsizer->Add($hbox, 0, wxGROW|wxLEFT|wxRIGHT, 5);
  $hbox -> Add(Wx::StaticText->new($this->{main}, -1, "Name"), 0, wxALL, 3);
  $this->{'name'.$n} = Wx::TextCtrl->new($this->{main}, -1, lc($map{$fun})." ".$index, wxDefaultPosition, [120,-1], wxTE_PROCESS_ENTER);
  $hbox -> Add($this->{'name'.$n}, 0, wxGROW|wxLEFT|wxRIGHT, 5);

  if ($ENV{DEMETER_BACKEND} eq 'ifeffit') {
    $this->{'swap'.$n} = Wx::HyperlinkCtrl->new($this->{main}, -1, 'change to '.lc($map{$swap{$fun}}),
						q{}, wxDefaultPosition, wxDefaultSize, wxNO_BORDER);
    $this->{'swap'.$n}->SetNormalColour(wxBLACK);
    EVT_HYPERLINK($this, $this->{"swap$n"}, sub{ $this->swap($_[1], $n) });
  } else {
    $this->{'swap'.$n} = Wx::StaticText->new($this->{main}, -1, 'change function');
    $this->{'swap'.$n} -> SetFont(Wx::Font->new( Wx::SystemSettings::GetFont(wxSYS_DEFAULT_GUI_FONT)->GetPointSize,
						 wxDEFAULT, wxNORMAL, wxBOLD, 1, "" ));
    EVT_LEFT_DOWN($this->{"swap$n"}, sub{$this->swap($_[1], $n)});
    EVT_MENU($this->{"swap$n"}, -1, sub{ $this->do_swap_larch(@_, $n) });
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

  $hbox -> Add(Wx::StaticText->new($this->{main}, -1, "Cen"), 0, wxALL, 3);
  $this->{'val1'.$n} = Wx::TextCtrl->new($this->{main}, -1, 0, wxDefaultPosition, $tcsize, wxTE_PROCESS_ENTER);
  $hbox -> Add($this->{'val1'.$n}, 0, wxGROW|wxLEFT|wxRIGHT, 0);
  $this->{'grab'.$n} = Wx::BitmapButton -> new($this->{main}, -1, $bullseye);
  $hbox->Add($this->{'grab'.$n}, 0, wxGROW|wxLEFT|wxRIGHT, 0);
  $this->{'fix1'.$n} = Wx::CheckBox->new($this->{main}, -1, 'fix');
  $hbox -> Add($this->{'fix1'.$n}, 0, wxGROW|wxLEFT|wxRIGHT, 1);

  $hbox->Add(1,1,1);

  $hbox -> Add(Wx::StaticText->new($this->{main}, -1, "Wid"), 0, wxALL, 3);
  $this->{'val2'.$n} = Wx::TextCtrl->new($this->{main}, -1, $this->{PEAK}->defwidth, wxDefaultPosition, [40,-1], wxTE_PROCESS_ENTER);
  $hbox -> Add($this->{'val2'.$n}, 0, wxGROW|wxLEFT|wxRIGHT, 0);
  $this->{'fix2'.$n} = Wx::CheckBox->new($this->{main}, -1, 'fix');
  $hbox -> Add($this->{'fix2'.$n}, 0, wxGROW|wxLEFT|wxRIGHT, 1);

  if ($fun !~ m{atan|erf|logistic}) {
    $this->{'lab3'.$n} = Wx::StaticText->new($this->{main}, -1, "S");
    $hbox -> Add($this->{'lab3'.$n}, 0, wxALL, 3);
    $this->{'val3'.$n} = Wx::TextCtrl->new($this->{main}, -1, $this->{PEAK}->defwidth, wxDefaultPosition, [40,-1], wxTE_PROCESS_ENTER);
    $hbox -> Add($this->{'val3'.$n}, 0, wxGROW|wxLEFT|wxRIGHT, 0);
    $this->{'fix3'.$n} = Wx::CheckBox->new($this->{main}, -1, 'fix');
    $hbox -> Add($this->{'fix3'.$n}, 0, wxGROW|wxLEFT|wxRIGHT, 1);
    if ($fun =~ m{gaussian|lorentzian|strudents_t}) {
      $this->{'lab3'.$n}->Enable(0);
      $this->{'val3'.$n}->Enable(0);
      $this->{'fix3'.$n}->Enable(0);
    };

  };

  $this->{'fix0'.$n}->SetValue(0);
  $this->{'fix1'.$n}->SetValue(1);
  $this->{'fix2'.$n}->SetValue(0);
  $this->{'fix3'.$n}->SetValue(0) if ($fun !~ m{atan|erf|logistic});


  EVT_BUTTON($this, $this->{'grab'.$n}, sub{ $this->grab_center($n) });
  EVT_BUTTON($this, $this->{'del'.$n},  sub{ $this->discard($n) });

  return ($box, $boxsizer);
};

sub increment {
  my ($this, $fun) = @_;
  my $index = 0;
  foreach my $i (1 .. $this->{count}) {
    next if (not exists $this->{"func$i"});
    next if ($this->{'type'.$i} ne $fun);
    $index = $1 if ($this->{'name'.$i}->GetValue =~ m{$fun\s*(\d+)}i);
  };
  ++$index;
  return $index;
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
  $y = $this->{PEAK}->data->yofx($this->{PEAK}->data->nsuff, q{}, $x);

  $this->{'val1'.$n}->SetValue($x);
  $this->{'val0'.$n}->SetValue(sprintf("%.2f",$y));

  $::app->{main}->status("Plucked $x for ".$this->{'type'.$n}." center");
};


sub fit {
  my ($this, $nofit) = @_;
  $nofit ||= 0;
  my $busy = Wx::BusyCursor->new();
  my $peak = $this->{PEAK};
  $peak -> data($::app->current_data);
  $peak -> xmin($this->{emin}->GetValue);
  $peak -> xmax($this->{emax}->GetValue);
  $peak -> plot_components($this->{components}->GetValue);
  $peak -> plot_residual($this->{residual}->GetValue);

  $peak -> clean;
  my $nls = 0;
  foreach my $i (1 .. $this->{count}) {
    next if (not exists $this->{"func$i"});
    next if $this->{'skip'.$i}->GetValue;
    ++$nls;
    $this->{'lineshape'.$i} = $peak -> add($this->{'type'.$i},
					   name  => $this->{'name'.$i}->GetValue,
					   a0    => $this->{'val0'.$i}->GetValue,
					   fix0  => $this->{'fix0'.$i}->GetValue,
					   a1    => $this->{'val1'.$i}->GetValue,
					   fix1  => $this->{'fix1'.$i}->GetValue,
					   a2    => $this->{'val2'.$i}->GetValue,
					   fix2  => $this->{'fix2'.$i}->GetValue,
					  );
    if ($this->{'lineshape'.$i}->nparams == 4) {
      $this->{'lineshape'.$i}->a3($this->{'val3'.$i}->GetValue);
      $this->{'lineshape'.$i}->fix3($this->{'fix3'.$i}->GetValue);
    };
  };


  $peak -> fit($nofit);
  if (not $nofit) {
    $this->{result}->Clear;
    $this->{result}->SetValue($peak->report);
    foreach my $i (1 .. $this->{count}) {
      next if not exists $this->{"func$i"};
      next if $this->{'skip'.$i}->GetValue;
      $this->{'val0'.$i}->SetValue(sprintf("%.3f", $this->{'lineshape'.$i}->a0));
      $this->{'val1'.$i}->SetValue(sprintf("%.3f", $this->{'lineshape'.$i}->a1));
      $this->{'val2'.$i}->SetValue(sprintf("%.3f", $this->{'lineshape'.$i}->a2));
      if ($this->{'type'.$i} eq 'pseudovoight') {
	$this->{'val3'.$i}->SetValue(sprintf("%.3f", $this->{'lineshape'.$i}->a3));
      };
    };
    $this->{fitted} = 1;
  };
  $peak -> plot('e');
  $::app->{lastplot} = ['E', 'single'];


  if (not $nofit) {
    foreach my $ac (qw(save resultreport resultplot)) {
      $this->{$ac}->Enable(1);
    };
    $::app->{main}->status(sprintf("Performed peak fitting on %s using %d lineshapes and %d variables",
				   $peak->data->name, $nls, $peak->nparam));
  };
  undef $busy;
};

sub save {
  my ($this) = @_;
  my $data = $::app->current_data;
  (my $name = $data->name) =~ s{\s+}{_}g;
  my $fd = Wx::FileDialog->new( $::app->{main}, "Save peak fit to a file", cwd, $name.".peak",
				"peak fit (*.peak)|*.peak|All files (*)|*",
				wxFD_SAVE|wxFD_CHANGE_DIR, #|wxFD_OVERWRITE_PROMPT,
				wxDefaultPosition);
  if ($fd->ShowModal == wxID_CANCEL) {
    $::app->{main}->status("Saving peak fitting results to a file has been canceled.");
    return 0;
  };
  my $fname = $fd->GetPath;
  return if $::app->{main}->overwrite_prompt($fname); # work-around gtk's wxFD_OVERWRITE_PROMPT bug (5 Jan 2011)
  $this->{PEAK}->save($fname);
  $::app->{main}->status("Saved peak fitting results to $fname");
};

sub reset_all {
  my ($this) = @_;
  $this->tilt("Resetting is not yet implemented",1);
};

sub make {
  my ($this) = @_;
  $this->tilt("Making a data group is not yet implemented",1);
};

sub discard {
  my ($this, $n) = @_;
  my $name = $this->{'name'.$n}->GetValue;
  my $yesno = Demeter::UI::Wx::VerbDialog->new($::app->{main}, -1,
					       "Really delete $name (lineshape #$n)?",
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
  $this->{lsbox} -> Fit($this->{main});
  $this->{vbox}  -> Fit($this->{panel});
  $::app->{main}->status("Deleted $name (lineshape #$n)");
};

sub swap {
  my ($this, $event, $n) = @_;
  if ($ENV{DEMETER_BACKEND} eq 'ifeffit') {
    $this->swap_ifeffit($n);
  } else {
    $this->swap_larch($n, $event);
  };
};

sub swap_ifeffit {
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

sub swap_larch {
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

  my $here = $event->GetPosition;
  $this->{'swap'.$n} -> PopupMenu($menu, $here);
};

sub do_swap_larch {
  my ($this, $text, $event, $n) = @_;
  my $id = $event->GetId;
  my %hash = reverse(%SWAPHASH);
  my $selection = $hash{$id};
  $this->{'name'.$n}->SetValue(lc($selection)." $n");
  $this->{'type'.$n} = lc($selection);
  $this->{'box'.$n} -> SetLabel($selection);
  $::app->{main} -> Update;
};


1;


=head1 NAME

Demeter::UI::Athena::PeakFit - A peak fitting for Athena

=head1 VERSION

This documentation refers to Demeter version 0.9.17.

=head1 SYNOPSIS

This module provides a

=head1 CONFIGURATION


=head1 DEPENDENCIES

Demeter's dependencies are in the F<Bundle/DemeterBundle.pm> file.

=head1 BUGS AND LIMITATIONS

=over 4

=item *

This 'n' that

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
