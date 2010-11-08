package Demeter::UI::Athena::LCF;
use strict;
use warnings;

use Wx qw( :everything );
use base 'Wx::Panel';
use Wx::Event qw(EVT_BUTTON EVT_CHECKBOX EVT_COMBOBOX EVT_RADIOBOX);

use Demeter::UI::Wx::SpecialCharacters qw(:all);
use Cwd;

use vars qw($label);
$label = "Linear combination fitting";	# used in the Choicebox and in status bar messages to identify this tool

my $tcsize = [60,-1];
my $demeter = $Demeter::UI::Athena::demeter;

sub new {
  my ($class, $parent, $app) = @_;
  my $this = $class->SUPER::new($parent, -1, wxDefaultPosition, wxDefaultSize, wxMAXIMIZE_BOX );

  my $box = Wx::BoxSizer->new( wxVERTICAL);
  $this->{sizer}  = $box;

  $this->{LCF} = Demeter::LCF->new;
  $this->{emin} = $demeter->co->default('lcf', 'emin');
  $this->{emax} = $demeter->co->default('lcf', 'emax');
  $this->{kmin} = $demeter->co->default('lcf', 'kmin');
  $this->{kmax} = $demeter->co->default('lcf', 'kmax');
  $this->{pastspace} = 0;

  my $hbox = Wx::BoxSizer->new( wxHORIZONTAL );
  $box->Add($hbox, 0, wxGROW|wxLEFT|wxRIGHT, 5);
  $hbox->Add(Wx::StaticText->new($this, -1, 'Fit range:'), 0, wxRIGHT|wxALIGN_CENTRE, 5);
  $this->{xmin} = Wx::TextCtrl->new($this, -1, $this->{emin}, wxDefaultPosition, $tcsize);
  $hbox->Add($this->{xmin}, 0, wxLEFT|wxRIGHT|wxALIGN_CENTRE, 5);
  $hbox->Add(Wx::StaticText->new($this, -1, 'to'), 0, wxRIGHT|wxALIGN_CENTRE, 5);
  $this->{xmax} = Wx::TextCtrl->new($this, -1, $this->{emax}, wxDefaultPosition, $tcsize);
  $hbox->Add($this->{xmax}, 0, wxLEFT|wxRIGHT|wxALIGN_CENTRE, 5);
  $this->{space} = Wx::RadioBox->new($this, -1, 'Fitting space', wxDefaultPosition, wxDefaultSize,
				     ["norm $MU(E)", "deriv $MU(E)", "$CHI(k)"],
				     1, wxRA_SPECIFY_ROWS);
  $hbox->Add($this->{space}, 0, wxLEFT|wxRIGHT|wxALIGN_CENTRE, 5);
  $this->{space}->SetSelection(0);
  EVT_RADIOBOX($this, $this->{space}, sub{OnSpace(@_)});

  $this->{notebook} = Wx::Notebook->new($this, -1, wxDefaultPosition, wxDefaultSize, wxNB_TOP);
  $box -> Add($this->{notebook}, 1, wxGROW|wxALL, 2);
  my $main  = $this->main_page($this->{notebook});
  my $fits  = $this->fit_page($this->{notebook});
  my $combi = $this->combi_page($this->{notebook});
  $this->{notebook} ->AddPage($main,  'Standards',     1);
  $this->{notebook} ->AddPage($fits,  'Fit results',   0);
  $this->{notebook} ->AddPage($combi, 'Combinatorics', 0);

  $this->{document} = Wx::Button->new($this, -1, 'Document section: linear combination fitting');
  $this->{return}   = Wx::Button->new($this, -1, 'Return to main window');
  $box -> Add($this->{$_}, 0, wxGROW|wxALL, 2) foreach (qw(document return));
  EVT_BUTTON($this, $this->{document}, sub{  $app->document("lcf")});
  EVT_BUTTON($this, $this->{return},   sub{  $app->{main}->{views}->SetSelection(0); $app->OnGroupSelect});

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

  $this->{nstan} = 12;
  foreach my $i (0 .. $this->{nstan}-1) {
    $this->add_standard($this->{window}, $winbox, $i);
  };
  $box -> Add($this->{window}, 1, wxALL|wxGROW, 5);

  $hbox = Wx::BoxSizer->new( wxHORIZONTAL );
  $box -> Add($hbox, 2, wxLEFT|wxRIGHT|wxGROW, 5);

  my $optionsbox       = Wx::StaticBox->new($panel, -1, 'Options', wxDefaultPosition, wxDefaultSize);
  my $optionsboxsizer  = Wx::StaticBoxSizer->new( $optionsbox, wxVERTICAL );
  $hbox -> Add($optionsboxsizer, 1, wxGROW|wxALL, 5);
  $this->{components} = Wx::CheckBox->new($panel, -1, 'Plot weighted components');
  $this->{residual}   = Wx::CheckBox->new($panel, -1, 'Plot residual');
  $this->{linear}     = Wx::CheckBox->new($panel, -1, 'Add a linear term after E0');
  $this->{inclusive}  = Wx::CheckBox->new($panel, -1, 'All weights between 0 and 1');
  $this->{unity}      = Wx::CheckBox->new($panel, -1, 'Force weights to sum to 1');
  $this->{one_e0}     = Wx::CheckBox->new($panel, -1, 'All standards share an e0');
  $this->{usemarked}  = Wx::Button->new($panel, -1, 'Use marked groups', wxDefaultPosition, wxDefaultSize, wxBU_EXACTFIT);
  $this->{reset}      = Wx::Button->new($panel, -1, 'Reset', wxDefaultPosition, wxDefaultSize, wxBU_EXACTFIT);
  $optionsboxsizer->Add($this->{$_}, 0, wxGROW|wxALL, 0)
    foreach (qw(components residual linear inclusive unity one_e0 usemarked reset));

  $this->{components} -> SetValue($demeter->co->default('lcf', 'components'));
  $this->{residual}   -> SetValue($demeter->co->default('lcf', 'difference'));
  $this->{$_} -> SetValue(0) foreach (qw(linear one_e0));
  $this->{$_} -> SetValue($demeter->co->default('lcf', $_)) foreach (qw(inclusive unity));

  my $noisebox = Wx::BoxSizer->new( wxHORIZONTAL );
  $optionsboxsizer->Add($noisebox, 0, wxGROW|wxALL, 1);
  $noisebox->Add(Wx::StaticText->new($panel, -1, 'Add noise'), 0, wxRIGHT|wxALIGN_CENTRE, 5);
  $this->{noise} = Wx::TextCtrl->new($panel, -1, 0, wxDefaultPosition, $tcsize);
  $noisebox->Add($this->{noise}, 0, wxLEFT|wxRIGHT|wxALIGN_CENTRE, 5);
  $noisebox->Add(Wx::StaticText->new($panel, -1, 'to data'), 0, wxRIGHT|wxALIGN_CENTRE, 5);
  my $maxbox = Wx::BoxSizer->new( wxHORIZONTAL );
  $optionsboxsizer->Add($maxbox, 0, wxGROW|wxALL, 1);
  $maxbox->Add(Wx::StaticText->new($panel, -1, 'Use at most'), 0, wxRIGHT|wxALIGN_CENTRE, 5);
  $this->{max} = Wx::SpinCtrl->new($panel, -1, 4, wxDefaultPosition, $tcsize, wxSP_ARROW_KEYS, 2, 6);
  $maxbox->Add($this->{max}, 0, wxLEFT|wxRIGHT|wxALIGN_CENTRE, 5);
  $maxbox->Add(Wx::StaticText->new($panel, -1, 'standards'), 0, wxRIGHT|wxALIGN_CENTRE, 5);

  EVT_CHECKBOX($this, $this->{components}, sub{$this->{LCF}->plot_components($this->{components}->GetValue)});
  EVT_CHECKBOX($this, $this->{residual},   sub{$this->{LCF}->plot_difference($this->{residual}  ->GetValue)});
  EVT_CHECKBOX($this, $this->{linear},     sub{$this->{LCF}->linear   ($this->{linear}          ->GetValue)});
  EVT_CHECKBOX($this, $this->{inclusive},  sub{$this->{LCF}->inclusive($this->{inclusive}       ->GetValue)});
  EVT_CHECKBOX($this, $this->{unity},      sub{$this->{LCF}->unity    ($this->{unity}           ->GetValue)});
  EVT_CHECKBOX($this, $this->{one_e0},     sub{$this->{LCF}->one_e0   ($this->{one_e0}          ->GetValue)});
  EVT_BUTTON($this, $this->{usemarked},    sub{use_marked(@_)});
  EVT_BUTTON($this, $this->{reset},        sub{Reset(@_)});

  my $actionsbox       = Wx::StaticBox->new($panel, -1, 'Actions', wxDefaultPosition, wxDefaultSize);
  my $actionsboxsizer  = Wx::StaticBoxSizer->new( $actionsbox, wxVERTICAL );
  $hbox -> Add($actionsboxsizer, 1, wxGROW|wxALL, 5);
  $this->{fit}		 = Wx::Button->new($panel, -1, 'Fit this group');
  $this->{combi}	 = Wx::Button->new($panel, -1, 'Fit all combinations');
  $this->{fitmarked}	 = Wx::Button->new($panel, -1, 'Fit marked groups');
  $this->{report}	 = Wx::Button->new($panel, -1, 'Save fit as column data');
  $this->{markedreport}	 = Wx::Button->new($panel, -1, 'Marked fits report');
  $this->{plot}		 = Wx::Button->new($panel, -1, 'Plot data and sum');
  $this->{plotr}	 = Wx::Button->new($panel, -1, 'Plot data and sum in R');
  $this->{make}		 = Wx::Button->new($panel, -1, 'Make group from fit');
  foreach my $w (qw(fit combi fitmarked report markedreport plot plotr make)) {
    $actionsboxsizer->Add($this->{$w}, 0, wxGROW|wxALL, 0);
    $this->{$w}->Enable(0);
  };
  EVT_BUTTON($this, $this->{fit},    sub{fit(@_, 0)});
  EVT_BUTTON($this, $this->{plot},   sub{fit(@_, 1)});
  EVT_BUTTON($this, $this->{report}, sub{save(@_)});
  EVT_BUTTON($this, $this->{combi},  sub{combi(@_)});


  $panel->SetSizerAndFit($box);
  return $panel;
};

sub fit_page {
  my ($this, $nb) = @_;
  my $panel = Wx::Panel->new($nb, -1, wxDefaultPosition, wxDefaultSize, wxMAXIMIZE_BOX );
  my $box = Wx::BoxSizer->new( wxVERTICAL);

  $this->{result} = Wx::TextCtrl->new($panel, -1, q{}, wxDefaultPosition, wxDefaultSize,
				       wxTE_MULTILINE|wxTE_WORDWRAP|wxTE_AUTO_URL);
  my $size = Wx::SystemSettings::GetFont(wxSYS_DEFAULT_GUI_FONT)->GetPointSize - 1;
  $this->{result}->SetFont( Wx::Font->new( $size, wxTELETYPE, wxNORMAL, wxNORMAL, 0, "" ) );
  $box->Add($this->{result}, 1, wxGROW|wxALL, 5);

  $this->{resultplot} = Wx::Button->new($panel, -1, 'Plot data and fit');
  $box->Add($this->{resultplot}, 0, wxGROW|wxALL, 2);
  $this->{resultreport} = Wx::Button->new($panel, -1, 'Save fit as column data');
  $box->Add($this->{resultreport}, 0, wxGROW|wxALL, 2);
  EVT_BUTTON($this, $this->{resultplot},   sub{fit(@_, 1)});
  EVT_BUTTON($this, $this->{resultreport}, sub{save(@_)});

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

  $this->{fitresults} = Wx::ListCtrl->new($panel, -1, wxDefaultPosition, wxDefaultSize, wxLC_REPORT|wxLC_HRULES||wxLC_SINGLE_SEL);
  $this->{fitresults}->InsertColumn( 0, "#",        wxLIST_FORMAT_LEFT, 20 );
  $this->{fitresults}->InsertColumn( 1, "Standard", wxLIST_FORMAT_LEFT, 100 );
  $this->{fitresults}->InsertColumn( 2, "Weight",   wxLIST_FORMAT_LEFT, 100 );
  $this->{fitresults}->InsertColumn( 3, "E0",       wxLIST_FORMAT_LEFT, 100 );
  $box->Add($this->{fitresults}, 1, wxALL|wxGROW, 3);


  $panel->SetSizerAndFit($box);
  return $panel;
};


sub add_standard {
  my ($this, $panel, $gbs, $i) = @_;
  my $box = Wx::BoxSizer->new( wxHORIZONTAL );
  $this->{'standard'.$i} = Demeter::UI::Athena::GroupList -> new($panel, $::app, 0, 0);
  $this->{'weight'.$i}   = Wx::TextCtrl -> new($panel, -1, 0, wxDefaultPosition, $tcsize);
  $this->{'e0'.$i}       = Wx::TextCtrl -> new($panel, -1, 0, wxDefaultPosition, $tcsize);
  $this->{'fite0'.$i}    = Wx::CheckBox -> new($panel, -1, q{ });
  $this->{'require'.$i}  = Wx::CheckBox -> new($panel, -1, q{ });
  $gbs -> Add(Wx::StaticText->new($panel, -1, sprintf("%2d: ",$i+1)), Wx::GBPosition->new($i,0));
  $gbs -> Add($this->{'standard'.$i}, Wx::GBPosition->new($i,1));
  $gbs -> Add($this->{'weight'.$i},   Wx::GBPosition->new($i,2));
  $gbs -> Add($this->{'e0'.$i},       Wx::GBPosition->new($i,3));
  $gbs -> Add($this->{'fite0'.$i},    Wx::GBPosition->new($i,4));
  $gbs -> Add($this->{'require'.$i},  Wx::GBPosition->new($i,5));
  $this->{'standard'.$i}->SetSelection(0);
  EVT_COMBOBOX($this, $this->{'standard'.$i}, sub{OnSelect(@_)});
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
    $this->{'standard'.$i}->fill($::app, 0, 0);
    $this->{'standard'.$i}->SetStringSelection($str);
  };
  $this->{$_} -> Enable(0) foreach (qw(make report fitmarked markedreport));
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
    ++$count if ($this->{'standard'.$i}->GetSelection > 0);
  };
  foreach my $i (0 .. $this->{nstan}-1) {
    if ($this->{'standard'.$i}->GetSelection > 0) {
      $this->{'weight'.$i}->SetValue(sprintf("%.3f", 1/$count));
    } else {
      $this->{'weight'.$i}->SetValue(0);
    };
  };
  $this->{fit}   -> Enable($count > 1);
  $this->{combi} -> Enable($count > 2);
  $this->{plot}  -> Enable($count > 0);
  $this->{plotr} -> Enable($count > 0) if ($this->{space}->GetSelection == 2);

  $this->{make}      -> Enable(0);
  $this->{report}    -> Enable(0);
  $this->{fitmarked} -> Enable(0);
};

sub use_marked {
  my ($this, $event) = @_;
  my $count = 0;
  foreach my $i (0 .. $::app->{main}->{list}->GetCount-1) {
    next if not $::app->{main}->{list}->IsChecked($i);
    $this->{'standard'.$count}->SetStringSelection($::app->{main}->{list}->GetClientData($i)->name);
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
  $this->{$_} -> SetValue($demeter->co->default('lcf', $_)) foreach (qw(inclusive unity));
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
    #$this->{plotr} -> Enable(1);
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

  $this->{LCF}->max_standards($this->{max}->GetValue);
  my $noise = $this->{noise}->GetValue;
  $noise = 0 if ($noise < 0);
  $this->{LCF}->noise($noise);
};

sub _prep {
  my ($this, $nofit) = @_;
  $nofit ||= 0;
  $this->fetch;
  $this->{LCF}->clear;
  $this->{LCF}->clean if not $nofit;
  $this->{LCF}->data($::app->current_data);
  foreach my $i (0 .. $this->{nstan}-1) {
    my $n = $this->{'standard'.$i}->GetSelection;
    my $stan = $this->{'standard'.$i}->GetClientData($n);
    next if not defined($stan);
    #print join("|", $i, $n, $stan), $/;
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
  $this->{LCF}->xmin($this->{xmin}->GetValue + $e0);
  $this->{LCF}->xmax($this->{xmax}->GetValue + $e0);
  if ($this->{LCF}->space eq 'chi') {
    $this->{LCF}->po->set(kmin=>0, kmax=>$this->{xmax}->GetValue+1);
  } else {
    $this->{LCF}->po->set(emin=>$this->{xmin}->GetValue-10, emax=>$this->{xmax}->GetValue+10);
  };
};

sub _results {
  my ($this) = @_;
  foreach my $i (0 .. $this->{nstan}-1) {
    my $n = $this->{'standard'.$i}->GetSelection;
    my $stan = $this->{'standard'.$i}->GetClientData($n);
    next if not defined($stan);
    my $w = sprintf("%.3f", $this->{LCF}->weight($stan));
    my $e = sprintf("%.3f", $this->{LCF}->e0($stan));
    $this->{'weight'.$i}->SetValue($w);
    $this->{'e0'.$i}    ->SetValue($e);
  };
  $this->{result}->Clear;
  $this->{result}->SetValue($this->{LCF}->report);
};

sub fit {
  my ($this, $event, $nofit) = @_;
  my $busy = Wx::BusyCursor->new();
  $this->_prep($nofit);
  $this->{LCF} -> fit if not $nofit;
  $this->{LCF} -> plot_fit;
  $this->_results if not $nofit;
  $this->{make}         -> Enable(1);
  $this->{report}       -> Enable(1);
  $this->{fitmarked}    -> Enable(1);
  $this->{markedreport} -> Enable(1);
  undef $busy;
};

sub combi {
  my ($this, $event) = @_;
  my $busy = Wx::BusyCursor->new();
  $this->_prep(0);
  my $size = $this->{LCF}->combi_size;
  if ($size > 70) {
    my $yesno = Wx::MessageDialog->new($::app->{main},
				       "Really perform $size fits?",
				       "Perform $size fits?",
				       wxYES_NO|wxYES_DEFAULT|wxICON_QUESTION);
    my $result = $yesno->ShowModal;
    if ($result == wxID_NO) {
      $::app->{main}->status("Not doing combinatorial sequence of $size fits.");
      return 0;
    };
  };
  $::app->{main}->status("Doing $size combinatorial fits ... this may take a while", 'wait');
  my $start = DateTime->now( time_zone => 'floating' );
  $this->{LCF} -> combi;
  $this->{LCF}->plot_fit;

  $this->{result}->Clear;
  $this->{result}->SetValue($this->{LCF}->report);

  $this->_remove_all;
  my $i = 0;
  foreach my $st (@{ $this->{LCF}->standards }) {
    $this->{'standard'.$i}->SetStringSelection($st->name);
    my $w = sprintf("%.3f", $this->{LCF}->weight($st));
    my $e = sprintf("%.3f", $this->{LCF}->e0($st));
    $this->{'weight'.$i}->SetValue($w);
    $this->{'e0'.$i}    ->SetValue($e);
    ++$i;
  };

  my $finish = DateTime->now( time_zone => 'floating' );
  my $dur = $finish->subtract_datetime($start);
  my $finishtext = sprintf "Did %d combinatorial fits in %d minutes, %d seconds.", $size, $dur->minutes, $dur->seconds;
  $::app->{main}->status($finishtext);

  undef $busy;
};

sub _remove_all {
  my ($this) = @_;
  foreach my $i (0 .. $this->{nstan}-1) {
    $this->{'standard'.$i}->SetSelection(0);
    $this->{'weight'.$i}->SetValue(0);
    $this->{'e0'.$i}->SetValue(0);
  };
};

sub save {
  my ($this, $event) = @_;

  my $data = $::app->current_data;
  (my $name = $data->name) =~ s{\s+}{_}g;
  my $fd = Wx::FileDialog->new( $::app->{main}, "Save LCF fit to a file", cwd, $name.".lcf",
				"LCF (*.lcf)|*.lcf|All files|*.*",
				wxFD_SAVE|wxFD_CHANGE_DIR|wxFD_OVERWRITE_PROMPT,
				wxDefaultPosition);
  if ($fd->ShowModal == wxID_CANCEL) {
    $::app->{main}->status("Saving LCF results to a file has been cancelled.");
    return 0;
  };
  my $fname = File::Spec->catfile($fd->GetDirectory, $fd->GetFilename);
  $this->{LCF}->save($fname);
  $::app->{main}->status("Saved LCF results to $fname");
};

1;


=head1 NAME

Demeter::UI::Athena::LCF - A linear combination fitting tool for Athena

=head1 VERSION

This documentation refers to Demeter version 0.4.

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

L<http://cars9.uchicago.edu/~ravel/software/>

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2010 Bruce Ravel (bravel AT bnl DOT gov). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
