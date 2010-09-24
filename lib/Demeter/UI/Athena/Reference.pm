package Demeter::UI::Athena::Reference;

use Wx qw( :everything );
use base 'Wx::Panel';
use Wx::Event qw(EVT_CHECKBOX EVT_RADIOBUTTON EVT_BUTTON);
use Wx::Perl::TextValidator;

sub new {
  my ($class, $parent, $data) = @_;
  my $this = $class->SUPER::new($parent, -1, wxDefaultPosition, wxDefaultSize, wxMAXIMIZE_BOX );
  $this->{numerator}   ||= 3;
  $this->{denominator} ||= 4;
  $this->{reference}     = q{};

  my $box = Wx::BoxSizer->new( wxVERTICAL );

  my @cols = split(" ", $data->columns);

  $this->{do_ref} = Wx::CheckBox->new($this, -1, "Import reference channel");
  $box -> Add($this->{do_ref}, 0, wxALL, 10);
  $this->{controls} = ();
  EVT_CHECKBOX($this, $this->{do_ref}, sub{EnableReference(@_, $this, $data)});

  my $columnbox = Wx::ScrolledWindow->new($this, -1, wxDefaultPosition, [300, -1], wxHSCROLL);
  $columnbox->SetScrollbars(30, 0, 50, 0);
  $box -> Add($columnbox, 0, wxGROW|wxALL, 10);
  push @{$this->{controls}}, $columnbox;

  my $gbs = Wx::GridBagSizer->new( 3, 3 );

  my $label    = Wx::StaticText->new($columnbox, -1, 'Numerator');
  $gbs -> Add($label, Wx::GBPosition->new(1,0));
  push @{$this->{controls}}, $label;
  $label    = Wx::StaticText->new($columnbox, -1, 'Denominator');
  $gbs -> Add($label, Wx::GBPosition->new(2,0));
  push @{$this->{controls}}, $label;


  my $count = 1;
  my @args = (wxDefaultPosition, wxDefaultSize, wxRB_GROUP);
  foreach my $c (@cols) {
    my $i = $count;
    $label    = Wx::StaticText->new($columnbox, -1, $c);
    $gbs -> Add($label, Wx::GBPosition->new(0,$count));
    push @{$this->{controls}}, $label;

    $this->{'n'.$i} = Wx::RadioButton->new($columnbox, -1, q{}, @args);
    $gbs -> Add($this->{'n'.$i}, Wx::GBPosition->new(1,$count));
    $this->{'n'.$i} -> SetValue($i==$this->{numerator});
    push @{$this->{controls}}, $this->{'n'.$i};
    EVT_RADIOBUTTON($parent, $this->{'n'.$i}, sub{OnNumerClick(@_, $this, $i)});
    @args = ();
    ++$count;
  };

  $count = 1;
  @args = (wxDefaultPosition, wxDefaultSize, wxRB_GROUP);
  foreach my $c (@cols) {
    my $i = $count;
    $this->{'d'.$i} = Wx::RadioButton->new($columnbox, -1, q{}, @args);
    $gbs -> Add($this->{'d'.$i}, Wx::GBPosition->new(2,$count));
    $this->{'d'.$i} -> SetValue($i==$this->{denominator});
    push @{$this->{controls}}, $this->{'d'.$i};
    EVT_RADIOBUTTON($parent, $this->{'d'.$i}, sub{OnDenomClick(@_, $this, $i)});
    @args = ();
    ++$count;
  };

  $columnbox->SetSizer($gbs);

  my $hbox = Wx::BoxSizer->new( wxHORIZONTAL );

  $this->{ln}     = Wx::CheckBox->new($this, -1, "Natural log");
  $this->{same}   = Wx::CheckBox->new($this, -1, "Same element");
  $this->{replot} = Wx::Button->new($this, -1, "Replot reference");
  $hbox -> Add($this->{ln},     0, wxGROW|wxLEFT|wxRIGHT, 5);
  $hbox -> Add($this->{same},   0, wxGROW|wxLEFT|wxRIGHT, 5);
  $hbox -> Add($this->{replot}, 0, wxGROW|wxLEFT|wxRIGHT, 5);
  push @{$this->{controls}}, $this->{ln};
  push @{$this->{controls}}, $this->{same};
  push @{$this->{controls}}, $this->{replot};
  EVT_CHECKBOX($this, $this->{ln}, sub{OnLnClick(@_, $this)} );
  EVT_BUTTON($this, $this->{replot}, sub{  $this->display_plot });

  $this->{ln}   -> SetValue(1);
  $this->{same} -> SetValue(1);

  $box -> Add($hbox, 0, wxALL, 10);

  EnableReference($this, 0);

  $this->SetSizerAndFit($box);
  return $this;
};

sub EnableReference {
  my ($this, $event, $data) = @_;
  my $onoff = $this->{do_ref}->GetValue;
  $_->Enable($onoff) foreach @{$this->{controls}};
  if ($onoff) {
    $this->{reference} ||= Demeter::Data->new(file => $data->file,
					      name => "  Ref " . $data->name);
    $this->{reference} -> set(energy	  => $data->energy,
			      numerator	  => '$'.$this->{numerator},
			      denominator => '$'.$this->{denominator},
			      ln          => $this->{ln}->GetValue,
			      is_col	  => 1,
			      display	  => 1);
    $this->{reference} -> _update('data');
  };
};

sub OnLnClick {
  my ($nb, $event, $this) = @_;
  $this->{reference} -> ln($this->{ln}->GetValue);
  $this->display_plot;
};
sub OnNumerClick {
  my ($nb, $event, $this, $i) = @_;
  $this->{numerator}   = $i;
  $this->{reference}  -> numerator('$'.$i);
  $this->display_plot;
};
sub OnDenomClick {
  my ($nb, $event, $this, $i) = @_;
  $this->{denominator} = $i;
  $this->{reference}  -> denominator('$'.$i);
  $this->display_plot;
};

sub display_plot {
  my ($this) = @_;
  $this->{reference}  -> _update('normalize');
  $this->{reference}  -> po -> start_plot;
  $this->{reference}  -> plot('e');
};


1;
