package Demeter::UI::Athena::PlotQ;

use Wx qw( :everything );
use base 'Wx::Panel';
use Wx::Event qw(EVT_LIST_ITEM_ACTIVATED EVT_LIST_ITEM_SELECTED EVT_BUTTON  EVT_KEY_DOWN
		 EVT_CHECKBOX);
use Wx::Perl::TextValidator;

use Demeter::UI::Athena::Replot;

sub new {
  my ($class, $parent, $app) = @_;
  my $this = $class->SUPER::new($parent, -1, wxDefaultPosition, wxDefaultSize, wxMAXIMIZE_BOX );

  my $box = Wx::BoxSizer->new( wxVERTICAL );

  my $hbox = Wx::BoxSizer->new( wxVERTICAL );
  $box -> Add($hbox, 0, wxALL|wxALIGN_CENTER_HORIZONTAL, 4);

  my $slot = Wx::BoxSizer->new( wxHORIZONTAL );
  $hbox -> Add($slot, 1, wxGROW|wxALL, 0);
  $this->{mag} = Wx::CheckBox->new($this, -1, 'Magnitude');
  $slot -> Add($this->{mag}, 1,  wxALL, 1);
  $this->{mmag} = Wx::RadioButton->new($this, -1, '', wxDefaultPosition, wxDefaultSize, wxRB_GROUP);
  $slot -> Add($this->{mmag}, 0, wxALL, 1);
  EVT_CHECKBOX($this, $this->{mag},
	       sub{my ($this, $event) = @_;
		   if ($this->{mag}->GetValue) {
		     $this->{env}->SetValue(0);
		   };
		   $this->replot(qw(q single));
		 });
  EVT_CHECKBOX($this, $this->{mmag}, sub{$_[0]->replot(qw(q marked))});
  $app->mouseover($this->{mag},  "Plot the magnitude of $CHI(q) when ploting the current group in filtered k-space.");
  $app->mouseover($this->{mmag}, "Plot the magnitude of $CHI(q) when ploting the marked groups in filtered k-space.");

  $slot = Wx::BoxSizer->new( wxHORIZONTAL );
  $hbox -> Add($slot, 1, wxGROW|wxALL, 0);
  $this->{env} = Wx::CheckBox->new($this, -1, 'Envelope');
  $slot -> Add($this->{env}, 0, wxALL, 1);
  EVT_CHECKBOX($this, $this->{env},
	       sub{my ($this, $event) = @_;
		   if ($this->{env}->GetValue) {
		     $this->{mag}->SetValue(0);
		   };
		   $this->replot(qw(q single));
		 });
  $app->mouseover($this->{mag},  "Plot the envelope of $CHI(q) when ploting the current group in filtered k-space.");

  $slot = Wx::BoxSizer->new( wxHORIZONTAL );
  $hbox -> Add($slot, 1, wxGROW|wxALL, 0);
  $this->{re} = Wx::CheckBox->new($this, -1, 'Real part');
  $slot -> Add($this->{re}, 1, wxALL, 1);
  $this->{mre} = Wx::RadioButton->new($this, -1, '');
  $slot -> Add($this->{mre}, 0, wxALL, 1);
  EVT_CHECKBOX($this, $this->{re}, sub{$_[0]->replot(qw(q single))});
  EVT_CHECKBOX($this, $this->{mre}, sub{$_[0]->replot(qw(q marked))});
  $app->mouseover($this->{re},  "Plot the real part of $CHI(q) when ploting the current group in filtered k-space.");
  $app->mouseover($this->{mre}, "Plot the real part of $CHI(q) when ploting the marked groups in filtered k-space.");

  $slot = Wx::BoxSizer->new( wxHORIZONTAL );
  $hbox -> Add($slot, 1, wxGROW|wxALL, 0);
  $this->{im} = Wx::CheckBox->new($this, -1, 'Imaginary part');
  $slot -> Add($this->{im}, 1, wxALL, 1);
  $this->{mim} = Wx::RadioButton->new($this, -1, '');
  $slot -> Add($this->{mim}, 0, wxALL, 1);
  EVT_CHECKBOX($this, $this->{im}, sub{$_[0]->replot(qw(q single))});
  EVT_CHECKBOX($this, $this->{mim}, sub{$_[0]->replot(qw(q marked))});
  $app->mouseover($this->{im},  "Plot the imaginary part of $CHI(q) when ploting the current group in filtered k-space.");
  $app->mouseover($this->{mim}, "Plot the imaginary part of $CHI(q) when ploting the marked groups in filtered k-space.");

  $slot = Wx::BoxSizer->new( wxHORIZONTAL );
  $hbox -> Add($slot, 1, wxGROW|wxALL, 0);
  $this->{pha} = Wx::CheckBox->new($this, -1, 'Phase');
  $slot -> Add($this->{pha}, 1, wxALL, 1);
  $this->{mpha} = Wx::RadioButton->new($this, -1, '');
  $slot -> Add($this->{mpha}, 0, wxALL, 1);
  EVT_CHECKBOX($this, $this->{pha}, sub{$_[0]->replot(qw(q single))});
  EVT_CHECKBOX($this, $this->{mpha}, sub{$_[0]->replot(qw(q marked))});
  $app->mouseover($this->{pha},  "Plot the phase of $CHI(q) when ploting the current group in filtered k-space.");
  $app->mouseover($this->{mpha}, "Plot the phase of $CHI(q) when ploting the marked groups in filtered k-space.");

  $slot = Wx::BoxSizer->new( wxHORIZONTAL );
  $hbox -> Add($slot, 1, wxGROW|wxALL, 0);
  $this->{win} = Wx::CheckBox->new($this, -1, 'Window');
  $slot -> Add($this->{win}, 0, wxALL, 1);
  EVT_CHECKBOX($this, $this->{win}, sub{$_[0]->replot(qw(q single))});
  $app->mouseover($this->{win}, "Plot the k-space window function when ploting the current group in filtered k-space.");

  SWITCH: {
      ($Demeter::UI::Athena::demeter->co->default("plot", "q_pl") eq 'm') and do {
	$this->{mag} ->SetValue(1);
	$this->{mmag}->SetValue(1);
	last SWITCH;
      };
      ($Demeter::UI::Athena::demeter->co->default("plot", "q_pl") eq 'e') and do {
	$this->{env} ->SetValue(1);
	last SWITCH;
      };
      ($Demeter::UI::Athena::demeter->co->default("plot", "q_pl") eq 'r') and do {
	$this->{re} ->SetValue(1);
	$this->{mre}->SetValue(1);
	last SWITCH;
      };
      ($Demeter::UI::Athena::demeter->co->default("plot", "q_pl") eq 'i') and do {
	$this->{im} ->SetValue(1);
	$this->{mim}->SetValue(1);
	last SWITCH;
      };
      ($Demeter::UI::Athena::demeter->co->default("plot", "q_pl") eq 'p') and do {
	$this->{pha} ->SetValue(1);
	$this->{mpha}->SetValue(1);
	last SWITCH;
      };
    };

  $this->{$_}->SetBackgroundColour( Wx::Colour->new($Demeter::UI::Athena::demeter->co->default("athena", "single")) )
    foreach (qw(mag env re im pha win));
  $this->{$_}->SetBackgroundColour( Wx::Colour->new($Demeter::UI::Athena::demeter->co->default("athena", "marked")) )
    foreach (qw(mmag mre mim mpha));

  $hbox -> Add(0, 0, 1);

  my $right = Wx::BoxSizer->new( wxVERTICAL );
  $hbox -> Add($right, 0, wxALL, 4);

  my $range = Wx::BoxSizer->new( wxHORIZONTAL );
  $box -> Add($range, 0, wxALL, 0);
  my $label = Wx::StaticText->new($this, -1, "qmin");
  $this->{qmin} = Wx::TextCtrl ->new($this, -1, $Demeter::UI::Athena::demeter->co->default("plot", "qmin"),
				     wxDefaultPosition, [50,-1]);
  $range -> Add($label,        0, wxALL, 5);
  $range -> Add($this->{qmin}, 0, wxRIGHT, 10);
  $label = Wx::StaticText->new($this, -1, "qmax");
  $this->{qmax} = Wx::TextCtrl ->new($this, -1, $Demeter::UI::Athena::demeter->co->default("plot", "qmax"),
				     wxDefaultPosition, [50,-1]);
  $range -> Add($label,        0, wxALL, 5);
  $range -> Add($this->{qmax}, 0, wxRIGHT, 10);

  $this->{$_} -> SetValidator( Wx::Perl::TextValidator->new( qr([0-9.]) ) )
    foreach (qw(qmin qmax));

  $this->SetSizerAndFit($box);
  return $this;

};


sub pull_single_values {
  my ($this) = @_;
  my $po = $Demeter::UI::Athena::demeter->po;
  $po->qmin($this->{qmin} -> GetValue);
  $po->qmax($this->{qmax} -> GetValue);
};

sub pull_marked_values {
  my ($this) = @_;
  my $po = $Demeter::UI::Athena::demeter->po;
  my $val = ($this->{mmag} -> GetValue) ? 'm'
          : ($this->{mre}  -> GetValue) ? 'r'
          : ($this->{mim}  -> GetValue) ? 'i'
          : ($this->{mpha} -> GetValue) ? 'p'
	  :                               'm';
  $po->q_pl($val);
  $po->qmin($this->{qmin} -> GetValue);
  $po->qmax($this->{qmax} -> GetValue);
};

1;
