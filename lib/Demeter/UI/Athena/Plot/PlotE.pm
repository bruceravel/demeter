package Demeter::UI::Athena::Plot::PlotE;

use Wx qw( :everything );
use base 'Wx::Panel';
use Wx::Event qw(EVT_CHECKBOX EVT_RADIOBUTTON);
use Wx::Perl::TextValidator;

use Demeter::UI::Wx::SpecialCharacters qw(:all);
use Demeter::UI::Athena::Replot;

use Scalar::Util qw(looks_like_number);

sub new {
  my ($class, $parent, $app) = @_;
  my $this = $class->SUPER::new($parent, -1, wxDefaultPosition, wxDefaultSize, wxMAXIMIZE_BOX );

  my $box = Wx::BoxSizer->new( wxVERTICAL );

  my $hbox = Wx::BoxSizer->new( wxVERTICAL );
  $box -> Add($hbox, 0, wxALL|wxALIGN_CENTER_HORIZONTAL, 4);

  my $slot = Wx::BoxSizer->new( wxHORIZONTAL );
  $hbox -> Add($slot, 1, wxGROW|wxALL, 0);
  $this->{mu} = Wx::CheckBox->new($this, -1, $MU.'(E)');
  $this->{mu} -> SetValue($Demeter::UI::Athena::demeter->co->default("plot", "e_mu"));
  $slot -> Add($this->{mu}, 1, wxALL, 1);
  $this->{mmu} = Wx::RadioButton->new($this, -1, '', wxDefaultPosition, wxDefaultSize, wxRB_GROUP);
  $this->{mmu} -> SetValue($Demeter::UI::Athena::demeter->co->default("plot", "e_mu"));
  $slot -> Add($this->{mmu}, 0, wxALL, 1);
  EVT_CHECKBOX($this, $this->{mu}, sub{$_[0]->replot(qw(E single))});
  EVT_RADIOBUTTON($this, $this->{mmu}, sub{$_[0]->replot(qw(E marked))});
  $app->mouseover($this->{mu},  "Plot $MU(E) when ploting the current group in energy.");
  $app->mouseover($this->{mmu}, "Plot $MU(E) when ploting the marked groups in energy.");

  $slot = Wx::BoxSizer->new( wxHORIZONTAL );
  $hbox -> Add($slot, 1, wxGROW|wxALL, 0);
  $this->{bkg} = Wx::CheckBox->new($this, -1, 'Background');
  $this->{bkg} -> SetValue($Demeter::UI::Athena::demeter->co->default("plot", "e_bkg"));
  $slot -> Add($this->{bkg}, 0, wxALL, 1);
  EVT_CHECKBOX($this, $this->{bkg},
	       sub{my ($this, $event) = @_;
		   if ($this->{bkg}->GetValue) {
		     $this->{der}->SetValue(0);
		     $this->{sec}->SetValue(0);
		   };
		   $this->replot(qw(E single));
		 });
  EVT_CHECKBOX($this, $this->{mbkg}, sub{$_[0]->replot(qw(E marked))});
  $app->mouseover($this->{bkg},  "Plot the background when ploting the current group in energy.");

  $slot = Wx::BoxSizer->new( wxHORIZONTAL );
  $hbox -> Add($slot, 1, wxGROW|wxALL, 0);
  $this->{pre} = Wx::CheckBox->new($this, -1, 'pre-edge line');
  $this->{pre} -> SetValue($Demeter::UI::Athena::demeter->co->default("plot", "e_pre"));
  $slot -> Add($this->{pre}, 0, wxALL, 1);
  EVT_CHECKBOX($this, $this->{pre},
	       sub{my ($this, $event) = @_;
		   if ($this->{pre}->GetValue) {
		     $this->{norm}->SetValue(0);
		   };
		   $this->replot(qw(E single));
		 });
  $app->mouseover($this->{pre},  "Plot the pre-edge line when ploting the current group in energy.");

  $slot = Wx::BoxSizer->new( wxHORIZONTAL );
  $hbox -> Add($slot, 1, wxGROW|wxALL, 0);
  $this->{post} = Wx::CheckBox->new($this, -1, 'post-edge line');
  $this->{post} -> SetValue($Demeter::UI::Athena::demeter->co->default("plot", "e_post"));
  $slot -> Add($this->{post}, 0, wxALL, 1);
  EVT_CHECKBOX($this, $this->{post},
	       sub{my ($this, $event) = @_;
		   if ($this->{post}->GetValue) {
		     $this->{norm}->SetValue(0);
		   };
		   $this->replot(qw(E single));
		 });
  $app->mouseover($this->{post},  "Plot the post-edge line when ploting the current group in energy.");

  $slot = Wx::BoxSizer->new( wxHORIZONTAL );
  $hbox -> Add($slot, 1, wxGROW|wxALL, 0);
  $this->{norm} = Wx::CheckBox->new($this, -1, 'Normalized');
  $this->{norm} -> SetValue($Demeter::UI::Athena::demeter->co->default("plot", "e_norm"));
  $slot -> Add($this->{norm}, 1, wxALL, 1);
  $this->{mnorm} = Wx::RadioButton->new($this, -1, '');
  $this->{mnorm} -> SetValue($Demeter::UI::Athena::demeter->co->default("plot", "e_norm"));
  $slot -> Add($this->{mnorm}, 0, wxALL, 1);
  EVT_CHECKBOX($this, $this->{norm},
	       sub{my ($this, $event) = @_;
		   if ($this->{norm}->GetValue) {
		     $this->{pre}->SetValue(0);
		     $this->{post}->SetValue(0);
		   };
		   $this->replot(qw(E single));
		 });
  EVT_RADIOBUTTON($this, $this->{mnorm}, sub{$_[0]->replot(qw(E marked))});
  $app->mouseover($this->{norm},  "Plot normalized data when ploting the current group in energy.");
  $app->mouseover($this->{mnorm}, "Plot normalized data when ploting the marked groups in energy.");

  $slot = Wx::BoxSizer->new( wxHORIZONTAL );
  $hbox -> Add($slot, 1, wxGROW|wxALL, 0);
  $this->{der} = Wx::CheckBox->new($this, -1, 'Derivative');
  $this->{der} -> SetValue($Demeter::UI::Athena::demeter->co->default("plot", "e_der"));
  $slot -> Add($this->{der}, 1, wxALL, 1);
  $this->{mder} = Wx::CheckBox->new($this, -1, '');
  $this->{mder} -> SetValue($Demeter::UI::Athena::demeter->co->default("plot", "e_der"));
  $slot -> Add($this->{mder}, 0, wxALL, 1);
  EVT_CHECKBOX($this, $this->{der},
	       sub{my ($this, $event) = @_;
		   if ($this->{der}->GetValue) {
		     $this->{bkg}->SetValue(0);
		     $this->{sec}->SetValue(0);
		   };
		   $this->replot(qw(E single));
		 });
  EVT_CHECKBOX($this, $this->{mder}, sub{$_[0]->replot(qw(E marked))});
  $app->mouseover($this->{der},  "Plot first derivative data when ploting the current group in energy.");
  $app->mouseover($this->{mder}, "Plot first derivative data when ploting the marked groups in energy.");

  $slot = Wx::BoxSizer->new( wxHORIZONTAL );
  $hbox -> Add($slot, 1, wxGROW|wxALL, 0);
  $this->{sec} = Wx::CheckBox->new($this, -1, 'Second derivative');
  $this->{sec} -> SetValue($Demeter::UI::Athena::demeter->co->default("plot", "e_sec"));
  $slot -> Add($this->{sec}, 1, wxALL, 1);
  $this->{msec} = Wx::CheckBox->new($this, -1, '');
  $this->{msec} -> SetValue($Demeter::UI::Athena::demeter->co->default("plot", "e_sec"));
  $slot -> Add($this->{msec}, 0, wxALL, 1);
  EVT_CHECKBOX($this, $this->{sec},
	       sub{my ($this, $event) = @_;
		   if ($this->{sec}->GetValue) {
		     $this->{bkg}->SetValue(0);
		     $this->{der}->SetValue(0);
		   };
		   $this->replot(qw(E single));
		 });
  EVT_CHECKBOX($this, $this->{msec}, sub{$_[0]->replot(qw(E marked))});
  $app->mouseover($this->{sec},  "Plot second derivative data when ploting the current group in energy.");
  $app->mouseover($this->{msec}, "Plot second derivative data when ploting the marked groups in energy.");

  $this->{$_}->SetBackgroundColour( Wx::Colour->new($Demeter::UI::Athena::demeter->co->default("athena", "single")) )
    foreach (qw(mu bkg pre post norm der sec));
  $this->{$_}->SetBackgroundColour( Wx::Colour->new($Demeter::UI::Athena::demeter->co->default("athena", "marked")) )
    foreach (qw(mmu mnorm mder msec));

  my $right = Wx::BoxSizer->new( wxVERTICAL );
  $hbox -> Add($right, 0, wxALL, 4);

  my $range = Wx::BoxSizer->new( wxHORIZONTAL );
  $box -> Add($range, 0, wxALL, 0);
  my $label = Wx::StaticText->new($this, -1, "Emin");
  $this->{emin} = Wx::TextCtrl ->new($this, -1, $Demeter::UI::Athena::demeter->co->default("plot", "emin"),
				     wxDefaultPosition, [50,-1]);
  $range -> Add($label,        0, wxALL, 5);
  $range -> Add($this->{emin}, 0, wxRIGHT, 10);
  $label = Wx::StaticText->new($this, -1, "Emax");
  $this->{emax} = Wx::TextCtrl ->new($this, -1, $Demeter::UI::Athena::demeter->co->default("plot", "emax"),
				     wxDefaultPosition, [50,-1]);
  $range -> Add($label,        0, wxALL, 5);
  $range -> Add($this->{emax}, 0, wxRIGHT, 10);

  $this->{$_} -> SetValidator( Wx::Perl::TextValidator->new( qr([-0-9.]) ) )
    foreach (qw(emin emax));

  $this->SetSizerAndFit($box);
  return $this;
};

sub pull_single_values {
  my ($this) = @_;
  my $po = $Demeter::UI::Athena::demeter->po;
  $po->e_mu  ($this->{mu}  -> GetValue);
  $po->e_bkg ($this->{bkg} -> GetValue);
  $po->e_pre ($this->{pre} -> GetValue);
  $po->e_post($this->{post}-> GetValue);
  $po->e_norm($this->{norm}-> GetValue);
  $po->e_der ($this->{der} -> GetValue);
  $po->e_sec ($this->{sec} -> GetValue);
  my $emin = $this->{emin}-> GetValue;
  my $emax = $this->{emax}-> GetValue;
  $emin = 0 if not looks_like_number($emin);
  $emax = 0 if not looks_like_number($emax);
  $po->emin($emin);
  $po->emax($emax);
  $po->e_markers(1);
};

sub pull_marked_values {
  my ($this) = @_;
  my $po = $Demeter::UI::Athena::demeter->po;
  $po->e_mu  ($this->{mmu}  -> GetValue);
  $po->e_bkg (0);
  $po->e_pre (0);
  $po->e_post(0);
  $po->e_norm($this->{mnorm}-> GetValue);
  $po->e_der ($this->{mder} -> GetValue);
  $po->e_sec ($this->{msec} -> GetValue);
  my $emin = $this->{emin}-> GetValue;
  my $emax = $this->{emax}-> GetValue;
  $emin = 0 if not looks_like_number($emin);
  $emax = 0 if not looks_like_number($emax);
  $po->emin($emin);
  $po->emax($emax);
  $po->e_mu(1) if $po->e_norm;
  $po->e_markers(0);
};

1;
