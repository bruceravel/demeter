package  Demeter::UI::Athena::ColumnSelection;

=for Copyright
 .
 Copyright (c) 2006-2014 Bruce Ravel (bravel AT bnl DOT gov).
 All rights reserved.
 .
 This file is free software; you can redistribute it and/or
 modify it under the same terms as Perl itself. See The Perl
 Artistic License.
 .
 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut

use strict;
use warnings;

use Wx qw( :everything);
use base qw(Wx::Dialog);
use Wx::Event qw(EVT_RADIOBUTTON EVT_CHECKBOX EVT_CHOICE EVT_BUTTON EVT_TEXT_ENTER);
use Wx::Perl::Carp;
use Wx::Perl::TextValidator;
use Demeter::UI::Wx::SpecialCharacters qw(:all);

use Demeter::UI::Athena::ColumnSelection::Preprocess;
use Demeter::UI::Athena::ColumnSelection::Rebin;
use Demeter::UI::Athena::ColumnSelection::Reference;

use Scalar::Util qw{looks_like_number};
use Encoding::FixLatin qw(fix_latin);
use List::MoreUtils qw(minmax);

my $contents_font_size = Wx::SystemSettings::GetFont(wxSYS_DEFAULT_GUI_FONT)->GetPointSize; # - 1;

sub new {
  my ($class, $parent, $app, $data) = @_;

  my $this = $class->SUPER::new($parent, -1, "Athena: Column selection",
				wxDefaultPosition, [-1,-1],
				wxMINIMIZE_BOX|wxCAPTION|wxSYSTEM_MENU|wxSTAY_ON_TOP);

  $data->po->set(e_mu=>1, e_bkg=>0, e_pre=>0, e_post=>0,
		 e_norm=>0, e_der=>0, e_sec=>0, e_markers=>0,
		 e_i0 => 0, e_signal => 0);

  my $hbox  = Wx::BoxSizer->new( wxHORIZONTAL );

  my $leftpane = Wx::Panel->new($this, -1, wxDefaultPosition, [350,-1],); #wxDefaultSize);
  my $left = Wx::BoxSizer->new( wxVERTICAL );
  $hbox->Add($leftpane, 1, wxGROW|wxALL, 0);


  my $select = Wx::BoxSizer->new( wxHORIZONTAL );
  $this->{selectrange} = Wx::Button->new($leftpane, -1, 'Select range', wxDefaultPosition, wxDefaultSize, wxBU_EXACTFIT);
  #$this->{selectrange}->SetToolTip("hello");
  $select -> Add($this->{selectrange}, 1, wxGROW|wxLEFT|wxRIGHT, 2);
  $this->{deselect}  = Wx::Button->new($leftpane, -1, 'Clear numerator', wxDefaultPosition, wxDefaultSize, wxBU_EXACTFIT);
  $select -> Add($this->{deselect},  1, wxGROW|wxLEFT|wxRIGHT, 2);
  $this->{pauseplot} = Wx::ToggleButton->new($leftpane, -1, 'Pause plotting', wxDefaultPosition, wxDefaultSize, wxBU_EXACTFIT);
  $select -> Add($this->{pauseplot},  1, wxGROW|wxLEFT|wxRIGHT, 2);
  $left->Add($select, 0, wxGROW|wxALL, 0);
  EVT_BUTTON($this, $this->{selectrange}, sub{selectrange(@_, $this, $data)});
  EVT_BUTTON($this, $this->{deselect},  sub{deselect (@_, $this, $data)});


  $this->{left} = $left;
  ## the ln checkbox goes below the column selection widget, but if
  ## refered to in the columns method, so I need to define it here.
  ## it will be placed in the other_parameters method.
  $this->{ln}       = Wx::CheckBox->new($leftpane, -1, 'Natural log');
  $this->{inv}      = Wx::CheckBox->new($leftpane, -1, 'Invert');
  $this->{energy}   = Wx::TextCtrl->new($leftpane, -1, q{}, wxDefaultPosition, [350,-1], wxTE_READONLY);
  $this->{mue}      = Wx::TextCtrl->new($leftpane, -1, q{}, wxDefaultPosition, [350,-1], wxTE_READONLY);
  $this->{constant} = Wx::TextCtrl->new($leftpane, -1, q{1}, wxDefaultPosition, [-1,-1], wxTE_PROCESS_ENTER);
  $this->{constant}-> SetValidator( Wx::Perl::TextValidator->new( qr([0-9.]) ) );
  EVT_TEXT_ENTER($this, $this->{constant}, sub{OnMultiplierEnter(@_, $this, $data)});

  $this->{each} = Wx::CheckBox->new($leftpane, -1, 'Save each channel as its own group');

  $this->columns($leftpane, $data);
  #$this->do_the_size_dance;
  $this->other_parameters($leftpane, $data);
  $this->strings($leftpane, $data);
  $this->tabs($leftpane, $data);


  my $buttons = Wx::BoxSizer->new( wxHORIZONTAL );
  $this->{ok} = Wx::Button->new($leftpane, wxID_OK, "OK", wxDefaultPosition, wxDefaultSize, 0, );
  $buttons -> Add($this->{ok}, 1, wxGROW|wxALL, 5);
  $this->{cancel} = Wx::Button->new($leftpane, wxID_CANCEL, "Cancel", wxDefaultPosition, wxDefaultSize);
  $buttons -> Add($this->{cancel}, 1, wxGROW|wxALL, 5);
  $this->{about} = Wx::Button->new($leftpane, wxID_ABOUT, "About", wxDefaultPosition, wxDefaultSize);
  $buttons -> Add($this->{about}, 1, wxGROW|wxALL, 5);
  $left -> Add($buttons, 0, wxGROW|wxALL, 5);
  EVT_BUTTON($this, $this->{about}, sub{  $app->document("import.columns")});

  my $rightpane = Wx::Panel->new($this, -1, wxDefaultPosition, [-1,-1]);
  my $right = Wx::BoxSizer->new( wxVERTICAL );
  $hbox->Add($rightpane, 1, wxGROW|wxALL, 0);

  $this->{contents} = Wx::TextCtrl->new($rightpane, -1, q{}, wxDefaultPosition, [-1,-1],
  					wxTE_MULTILINE|wxTE_RICH2|wxTE_DONTWRAP|wxALWAYS_SHOW_SB);
  $this->{contents} -> SetFont( Wx::Font->new( $contents_font_size, wxTELETYPE, wxNORMAL, wxNORMAL, 0, "", ) );
  $right -> Add($this->{contents}, 1, wxGROW|wxALL, 5);
  my $fixed = fix_latin(Demeter->slurp($data->file));
  $this->{contents}->SetValue($fixed);
  #$this->{contents}->LoadFile($data->file);

  $leftpane  -> SetSizerAndFit($left);
  $rightpane -> SetSizerAndFit($right);
  $this      -> SetSizerAndFit($hbox);
  return $this;
};

sub columns {
  my ($this, $parent, $data) = @_;
  $data -> _update('data');
  $this->{ln}->SetValue($data->ln);
  my $numerator_string   = ($data->ln) ? $data->i0_string     : $data->signal_string;
  my $denominator_string = ($data->ln) ? $data->signal_string : $data->i0_string;

  #my $column_string = $self->fetch_string('column_label');
  my @cols = split(" ", $data->columns);

  my $columnbox = Wx::ScrolledWindow->new($parent, -1, wxDefaultPosition, [350, 150], wxHSCROLL);
  $columnbox->SetScrollbars(30, 0, 50, 0);
  $this->{left}     -> Add($columnbox, 1, wxGROW|wxALL, 10);

  #my $columnbox      = Wx::StaticBox->new($parent, -1, 'Columns', wxDefaultPosition, wxDefaultSize);
  #my $columnboxsizer = Wx::StaticBoxSizer->new( $columnbox, wxVERTICAL );
  #$this->{left}     -> Add($columnboxsizer, 0, wxALL|wxGROW, 0);

  my $gbs = Wx::GridBagSizer->new( 3, 3 );

  my $label = Wx::StaticText->new($columnbox, -1, 'Energy');
  $gbs  -> Add($label, Wx::GBPosition->new(1,0));
  $label = Wx::StaticText->new($columnbox, -1, 'Numerator');
  $gbs  -> Add($label, Wx::GBPosition->new(2,0));
  $label = Wx::StaticText->new($columnbox, -1, 'Denominator');
  $gbs  -> Add($label, Wx::GBPosition->new(3,0));

  my @energy; $#energy = $#cols+1;
  my @numer;  $#numer  = $#cols+1;
  my @denom;  $#denom  = $#cols+1;
  my @energy_widgets;
  my @numer_widgets;
  my @denom_widgets;

  my $count = 1;
  my $med = 0;
  my @args = (wxDefaultPosition, wxDefaultSize, wxRB_GROUP);
  foreach my $c (@cols) {
    my $i = $count;
    $label    = Wx::StaticText->new($columnbox, -1, $c);
    $gbs -> Add($label, Wx::GBPosition->new(0,$count));

    my $radio = Wx::RadioButton->new($columnbox, -1, q{}, @args);
    $gbs -> Add($radio, Wx::GBPosition->new(1,$count));
    EVT_RADIOBUTTON($parent, $radio, sub{OnEnergyClick(@_, $this, $data, $i)});
    push @energy_widgets, $radio;
    if ($data->energy =~ m{(?<=\$)$count\b}) {
      $energy[$i] = 1;
      $radio->SetValue(1);
    };

    my $ncheck = Wx::CheckBox->new($columnbox, -1, q{});
    $gbs -> Add($ncheck, Wx::GBPosition->new(2,$count));
    EVT_CHECKBOX($parent, $ncheck, sub{OnNumerClick(@_, $this, $data, $i, \@numer)});
    push @numer_widgets, $ncheck;
    if ($data->numerator =~ m{(?<=\$)$count\b}) {
      $numer[$i] = 1;
      $ncheck->SetValue(1);
      ++$med;
    };

    my $dcheck = Wx::CheckBox->new($columnbox, -1, q{});
    $gbs -> Add($dcheck, Wx::GBPosition->new(3,$count));
    EVT_CHECKBOX($parent, $dcheck, sub{OnDenomClick(@_, $this, $data, $i, \@denom)});
    push @denom_widgets, $dcheck;
    if ($data->denominator =~ m{(?<=\$)$count\b}) {
      $denom[$i] = 1;
      $dcheck->SetValue(1);
    };

    @args = ();
    ++$count;
  };
  $this->{energy_widgets} = \@energy_widgets;
  $this->{numer_widgets}  = \@numer_widgets;
  $this->{denom_widgets}  = \@denom_widgets;
  $this->{each}->Enable($med>1);

  $this->display_plot($data) if (($data->numerator ne '1') or ($data->denominator ne '1'));
  #$columnbox->SetVirtualSize([200,300]);
  $columnbox->SetSizer($gbs);
  #$columnbox->SetMaxSize(Wx::Size->new(350,-1));
  return $this;
};
## note: (?<=\$) is a zero-width positive look-behind assertion to
## match a number ($count) following a doller sign.  see "perldoc
## perlre" for details.


sub other_parameters {
  my ($this, $parent, $data) = @_;

  my $others = Wx::BoxSizer->new( wxHORIZONTAL );
  $others -> Add($this->{ln},   0, wxGROW|wxALL, 5);
  EVT_CHECKBOX($parent, $this->{ln}, sub{OnLnClick(@_, $this, $data)});
  $others -> Add(1,1,1);
  $others -> Add($this->{inv},  0, wxGROW|wxALL, 5); # defined in new
  EVT_CHECKBOX($parent, $this->{inv}, sub{OnInvClick(@_, $this, $data)});
  $others -> Add(1,1,1);

  $others -> Add(Wx::StaticText->new($parent, -1, 'Multiplicative constant'), 0, wxGROW|wxTOP, 8);
  $others -> Add($this->{constant}, 0, wxGROW|wxALL, 5);
  $this->{constant} -> SetValue(1);

  $this->{left}->Add($others, 0, wxGROW|wxALL, 0);



  $others = Wx::BoxSizer->new( wxHORIZONTAL );
  $others -> Add(1,1,1);
  $others -> Add($this->{each}, 0, wxGROW|wxALL, 5); # defined in new
  $this->{left}->Add($others, 0, wxGROW|wxALL, 0);


  $others = Wx::BoxSizer->new( wxHORIZONTAL );
  $this->{datatype} = Wx::Choice->new($parent,-1, wxDefaultPosition, wxDefaultSize,
				     ["$MU(E)", 'xanes', 'norm(E)', 'chi(k)', 'xmu.dat']);
  $this->{units}    = Wx::Choice->new($parent,-1, wxDefaultPosition, wxDefaultSize, ['eV', 'keV']);
  $this->{replot}   = Wx::Button->new($parent, -1, 'Replot');
  $others -> Add(Wx::StaticText->new($parent,-1, "Data type"), 0, wxGROW|wxALL, 7);
  $others -> Add($this->{datatype}, 0, wxRIGHT, 25);
  $others -> Add(Wx::StaticText->new($parent,-1, "Energy units"), 0, wxGROW|wxTOP|wxRIGHT, 7);
  $others -> Add($this->{units}, 0, wxALL, 0);
  $others -> Add(1,1,1);
  $others -> Add($this->{replot}, 0, wxALL, 0);
  $this->{$_}->SetSelection(0) foreach (qw(datatype units));
  $this->{left}->Add($others, 0, wxGROW|wxALL, 0);

  EVT_BUTTON($this, $this->{replot}, sub{  $this->display_plot($data) });
  EVT_CHOICE($parent, $this->{datatype}, sub{OnDatatype(@_, $this, $data)});
  EVT_CHOICE($parent, $this->{units},    sub{OnUnits(@_, $this, $data)});

  $this->{datatype}->SetSelection(0);
  $this->{datatype}->SetSelection(1) if ($data->datatype eq 'xanes');
  $this->{datatype}->SetSelection(2) if (($data->datatype eq 'xanes') and $data->is_nor);
  $this->{datatype}->SetSelection(3) if ($data->datatype eq 'chi');
  $this->{datatype}->SetSelection(4) if ($data->datatype eq 'xmudat');


  return $this;
};

sub strings {
  my ($this, $parent, $data) = @_;

  my $gbs = Wx::GridBagSizer->new( 5, 5 );

  $gbs -> Add(Wx::StaticText->new($parent, -1, 'Energy'), Wx::GBPosition->new(0,0));
  $gbs -> Add($this->{energy},                            Wx::GBPosition->new(0,1));
  $this->{energy} -> SetValue($data->energy_string);

  $this->{muchi_label} = Wx::StaticText->new($parent, -1, "$MU(E)");
  $gbs -> Add($this->{muchi_label}, Wx::GBPosition->new(1,0));
  $gbs -> Add($this->{mue},         Wx::GBPosition->new(1,1));
  $this->{mue} -> SetValue($data->xmu_string);

  $this->{left}->Add($gbs, 0, wxGROW|wxALL, 5);

  return $this;
};

sub tabs {
  my ($this, $parent, $data) = @_;

  $this->{tabs} = Wx::Notebook->new($parent, -1, wxDefaultPosition, wxDefaultSize, wxNB_TOP);
  foreach my $m (qw(Preprocess Rebin Reference)) {
    $this->{$m} = "Demeter::UI::Athena::ColumnSelection::$m"->new($this->{tabs}, $data);
    $this->{tabs} -> AddPage($this->{$m}, $m, ($m eq 'Reference'));
  };

  $this->{left}->Add($this->{tabs}, 0, wxGROW|wxALL, 5);

};

sub OnMultiplierEnter {
  my ($parent, $event, $this, $data) = @_;
  my $const = $this->{constant}->GetValue;
  $const ||= 1;
  $const = 1 if not looks_like_number($const);
  $data->multiplier($const);
  $this->display_plot($data);
};
sub OnLnClick {
  my ($parent, $event, $this, $data) = @_;
  $data->ln($event->IsChecked);
  $this->display_plot($data);
};
sub OnInvClick {
  my ($parent, $event, $this, $data) = @_;
  $data->inv($event->IsChecked);
  $this->display_plot($data);
};

sub OnEnergyClick {
  my ($parent, $event, $this, $data, $i) = @_;
  $data -> energy('$'.$i);
  $data -> update_data(1);
  $data -> _update('data');
  my $untext = $data->guess_units;
  my $un = ($untext eq 'eV')     ? 0
         : ($untext eq 'keV')    ? 1
         : ($untext eq 'lambda') ? 2
	 :                         0;
  $this->{units}->SetSelection($un);
  $data->is_kev(0) if ($this->{units}->GetSelection == 0);
  $data->is_kev(1) if ($this->{units}->GetSelection == 1);
  $this -> display_plot($data);
};

sub OnNumerClick {
  my ($parent, $event, $this, $data, $i, $aref) = @_;
  #$aref->[$i] = $event->IsChecked;
  foreach my $ii (0..$#{$this->{numer_widgets}}) {
    $aref->[$ii+1] = $this->{numer_widgets}->[$ii]->IsChecked;
  };
  my $string = q{};
  my $n = 0;
  foreach my $count (1 .. $#$aref) {
    if ($aref->[$count]) {
      $string .= '$'.$count.'+';
      ++$n;
    };
  };
  $this->{each}->Enable($n>1);
  chop $string;
  #print "numerator is ", $string, $/;
  $string = "1" if not $string;
  ($data->datatype ne 'chi') ? $data -> numerator($string) : $data -> chi_column($string);
  $this -> display_plot($data);
};

sub OnDenomClick {
  my ($parent, $event, $this, $data, $i, $aref) = @_;
  return if ($data->datatype eq 'chi');
  $aref->[$i] = $event->IsChecked;
  my $string = q{};
  foreach my $count (1 .. $#$aref) {
    $string .= '$'.$count.'+' if $aref->[$count];
  };
  chop $string;
  #print "denomintor is ", $string, $/;
  $string = "1" if not $string;
  $data -> denominator($string);
  $this -> display_plot($data);
};

sub OnDatatype {
  my ($parent, $event, $this, $data) = @_;
  $data->set(datatype=>'xmu', is_nor=>0)      if ($this->{datatype}->GetSelection == 0);
  $data->set(datatype=>'xanes', bkg_nnorm=>$data->co->default('xanes', 'nnorm'), is_nor=>0) if ($this->{datatype}->GetSelection == 1);
  $data->set(datatype=>'xmu', is_nor=>1)      if ($this->{datatype}->GetSelection == 2);
  $data->datatype('chi')                      if ($this->{datatype}->GetSelection == 3);
  $data->set(datatype=>'xmudat', is_nor=>1)   if ($this->{datatype}->GetSelection == 4);

  if ($this->{datatype}->GetSelection == 3) { # chi data
    ## disable widgets needed for processing mu(E) data
    $this->{units}                 -> SetSelection(0);
    $this->{units}                 -> Enable(0);
    $this->{ln}                    -> SetValue(0);
    $this->{ln}                    -> Enable(0);
    $this->{inv}                   -> SetValue(0);
    $this->{inv}                   -> Enable(0);
    $this->{muchi_label}           -> SetLabel("$CHI(k)");
    $this->{Reference}->{do_ref}   -> SetValue(0);
    $this->{Reference}->{do_ref}   -> Enable(0);
    $this->{Reference}             -> EnableReference(q{}, $data);
    $this->{Rebin}->{do_rebin}     -> SetValue(0);
    $this->{Rebin}->{do_rebin}     -> Enable(0);
    $this->{Rebin}                 -> EnableRebin(q{}, $data);
    $this->{Preprocess}->{standard}-> SetStringSelection('None');
    $this->{Preprocess}->{standard}-> Enable(0);
    $this->{Preprocess}->{align}   -> SetValue(0);
    $this->{Preprocess}->{align}   -> Enable(0);
    foreach my $d (@{$this->{denom_widgets}}) {
      $d->Enable(0);
    };

    my $num = $data->numerator;
    $data->set(numerator=>q{1}, denominator=>q{1}, ln=>0, is_kev=>0);
    $data->chi_column($num);
  } else {
    ## re-enable widgets needed for processing mu(E) data
    $this->{units}                 -> Enable(1);
    $this->{ln}                    -> Enable(1);
    $this->{inv}                   -> Enable(1);
    $this->{muchi_label}           -> SetLabel("$MU(E)");
    $this->{Reference}->{do_ref}   -> Enable(1);
    $this->{Reference}             -> EnableReference(q{}, $data);
    $this->{Rebin}->{do_rebin}     -> Enable(1);
    $this->{Rebin}                 -> EnableRebin(q{}, $data);
    $this->{Preprocess}->{standard}-> Enable(1);
    $this->{Preprocess}->{align}   -> Enable(1);
    foreach my $d (@{$this->{denom_widgets}}) {
      $d->Enable(1);
    };

    my $num = ($data->chi_column eq q{}) ? $data->numerator : $data->chi_column;
    $data->chi_column(q{});
    $data->numerator($num);
  };
  $this -> display_plot($data);
};

sub OnUnits {
  my ($parent, $event, $this, $data) = @_;
  $data->is_kev(0) if ($this->{units}->GetSelection == 0);
  $data->is_kev(1) if ($this->{units}->GetSelection == 1);
  $this -> display_plot($data);
};

  #my @energy_widgets = @{$this->{energy_widgets}};
  #my @numer_widgets  = @{$this->{numer_widgets}};
  #my @denom_widgets  = @{$this->{denom_widgets}};

sub selectrange {
  my ($parent, $event, $this, $data) = @_;

  ## take care not to have the TextEntryDialog hidden beneath the column selection dialog
  my $place_x = $parent->GetScreenPosition->x - 300;
  my $place_y = $parent->GetScreenPosition->y - 80;
  $place_x = 0 if $place_x < 0;
  $place_y = 0 if $place_y < 0;
  my $ted = Wx::TextEntryDialog->new( $::app->{main},
				      "Select a range of columns (e.g. 8-20 or 7,9,12-15)",
				      "Select a range of columns", q{}, wxOK|wxCANCEL,
				      Wx::Point->new($place_x, $place_y));
  my $st = $ted->ShowModal;
  $ted -> Raise;
  if ($st == wxID_CANCEL) {
    $ted->Destroy;
    $::app->{main}->status("Column range selection canceled");
    return;
  };
  my $range = $ted->GetValue;
  $ted->Destroy;
  $range =~ s{\s}{}g;
  my @cols = ();
  foreach my $c (split(m{,}, $range)) {
    if ($c =~ m{(\d+)\-(\d+)}) {
      my ($i,$j) = sort {$a <=> $b} ($1, $2);
      push @cols, ($i .. $j);
    } else {
      push @cols, $c;
    };
  };

  return if not @cols;
  my $string = q{};
  foreach my $i (@cols) {
    next if ($i !~ m{\A\d+\z});
    next if $this->{energy_widgets}->[$i]->GetValue;
    $this->{numer_widgets}->[$i-1]->SetValue(1);
    #my $count = $i+1;
    $string .= '$'.$i.'+';
  };
  $string =~ s{\+\z}{};
  $this->{each}->Enable(1) if $#cols > 0;
  ($data->datatype ne 'chi') ? $data -> numerator($string) : $data -> chi_column($string);
  $this -> display_plot($data);
};
sub deselect {
  my ($parent, $event, $this, $data) = @_;
  foreach my $w (@{$this->{numer_widgets}}) {
    $w->SetValue(0);
  };
  $this->{each}->Enable(0);
  ($data->datatype ne 'chi') ? $data -> numerator('1') : $data -> chi_column('1');
  $this -> display_plot($data);
};

sub display_plot {
  my ($this, $data) = @_;
  my $const = $this->{constant}->GetValue;
  $const ||= 1;
  $const = 1 if not looks_like_number($const);
  $data->multiplier($const);
  if (($data->columns =~ m{\bxmu\b}) and (not $this->{pauseplot}->GetValue)) {
    $data -> update_data(1);
  };
  if ($data->datatype ne 'chi') {
    $data -> _update('normalize');
    $this->{energy} -> SetValue($data->energy_string);
    $this->{mue}    -> SetValue($data->xmu_string);
    return if $this->{pauseplot}->GetValue;
    return if ($this->{energy}->GetValue !~ $data->group);
    return if ($this->{mue}->GetValue    !~ $data->group);
    my @energy = $data->get_array('energy');
    my ($emin, $emax) = minmax(@energy);
    $data -> po -> set(emin=>$emin, emax=>$emax);
    $data -> po -> start_plot;
    $data -> plot('e');
  } else {
    $data -> _update('normalize');
    $this->{energy} -> SetValue($data->energy_string);
    $this->{mue}    -> SetValue($data->chi_string);
    return if $this->{pauseplot}->GetValue;
    my @k = $data->get_array('k');
    my ($kmin, $kmax) = minmax(@k);
    $data -> po -> set(kmin=>0, kmax=>$kmax);
    $data -> po -> start_plot;
    $data -> plot('k') if ($data->chi_string ne '1');
    $data -> update_data(1) if ($data->chi_string eq '1');
  };
};

sub ShouldPreventAppExit {
  0
};

1;

=head1 NAME

Demeter::UI::Athena::ColumnSelection - Athena's column selection dialog

=head1 VERSION

This documentation refers to Demeter version 0.9.21.

=head1 SYNOPSIS

This module provides a Athena's column selection dialog

=head1 DEPENDENCIES

Demeter's dependencies are in the F<Build.PL> file.

=head1 BUGS AND LIMITATIONS

Please report problems to the Ifeffit Mailing List
(L<http://cars9.uchicago.edu/mailman/listinfo/ifeffit/>)

Patches are welcome.

=head1 AUTHOR

Bruce Ravel (bravel AT bnl DOT gov)

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2014 Bruce Ravel (bravel AT bnl DOT gov). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
