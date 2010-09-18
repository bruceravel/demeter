package Demeter::UI::Athena::PlotR;

use Wx qw( :everything );
use base 'Wx::Panel';
use Wx::Event qw(EVT_LIST_ITEM_ACTIVATED EVT_LIST_ITEM_SELECTED EVT_BUTTON  EVT_KEY_DOWN);


sub new {
  my ($class, $parent) = @_;
  my $this = $class->SUPER::new($parent, -1, wxDefaultPosition, wxDefaultSize, wxMAXIMIZE_BOX );

  my $box = Wx::BoxSizer->new( wxVERTICAL );

  my $hbox = Wx::BoxSizer->new( wxVERTICAL );
  $box -> Add($hbox, 0, wxALL|wxALIGN_CENTER_HORIZONTAL, 4);

  my $slot = Wx::BoxSizer->new( wxHORIZONTAL );
  $hbox -> Add($slot, 1, wxGROW|wxALL, 0);
  $this->{mag} = Wx::CheckBox->new($this, -1, 'Magnitude');
  $slot -> Add($this->{mag}, 1, wxALL, 1);
  $this->{mmag} = Wx::RadioButton->new($this, -1, '', , wxDefaultPosition, wxDefaultSize, wxRB_GROUP);
  $slot -> Add($this->{mmag}, 0, wxALL, 1);

  $slot = Wx::BoxSizer->new( wxHORIZONTAL );
  $hbox -> Add($slot, 1, wxGROW|wxALL, 0);
  $this->{env} = Wx::CheckBox->new($this, -1, 'Envelope');
  $slot -> Add($this->{env}, 0, wxALL, 1);

  $slot = Wx::BoxSizer->new( wxHORIZONTAL );
  $hbox -> Add($slot, 1, wxGROW|wxALL, 0);
  $this->{re} = Wx::CheckBox->new($this, -1, 'Real part');
  $slot -> Add($this->{re}, 1, wxALL, 1);
  $this->{mre} = Wx::RadioButton->new($this, -1, '');
  $slot -> Add($this->{mre}, 0, wxALL, 1);

  $slot = Wx::BoxSizer->new( wxHORIZONTAL );
  $hbox -> Add($slot, 1, wxGROW|wxALL, 0);
  $this->{im} = Wx::CheckBox->new($this, -1, 'Imaginary part');
  $slot -> Add($this->{im}, 1, wxALL, 1);
  $this->{mim} = Wx::RadioButton->new($this, -1, '');
  $slot -> Add($this->{mim}, 0, wxALL, 1);

  $slot = Wx::BoxSizer->new( wxHORIZONTAL );
  $hbox -> Add($slot, 1, wxGROW|wxALL, 0);
  $this->{pha} = Wx::CheckBox->new($this, -1, 'Phase');
  $slot -> Add($this->{pha}, 1, wxALL, 1);
  $this->{mpha} = Wx::RadioButton->new($this, -1, '');
  $slot -> Add($this->{mpha}, 0, wxALL, 1);

  $slot = Wx::BoxSizer->new( wxHORIZONTAL );
  $hbox -> Add($slot, 1, wxGROW|wxALL, 0);
  $this->{win} = Wx::CheckBox->new($this, -1, 'Window');
  $slot -> Add($this->{win}, 0, wxALL, 1);

  SWITCH: {
      ($Demeter::UI::Athena::demeter->co->default("plot", "r_pl") eq 'm') and do {
	$this->{mag} ->SetValue(1);
	$this->{mmag}->SetValue(1);
	last SWITCH;
      };
      ($Demeter::UI::Athena::demeter->co->default("plot", "r_pl") eq 'e') and do {
	$this->{env} ->SetValue(1);
	last SWITCH;
      };
      ($Demeter::UI::Athena::demeter->co->default("plot", "r_pl") eq 'r') and do {
	$this->{re} ->SetValue(1);
	$this->{mre}->SetValue(1);
	last SWITCH;
      };
      ($Demeter::UI::Athena::demeter->co->default("plot", "r_pl") eq 'i') and do {
	$this->{im} ->SetValue(1);
	$this->{mim}->SetValue(1);
	last SWITCH;
      };
      ($Demeter::UI::Athena::demeter->co->default("plot", "r_pl") eq 'p') and do {
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
  my $label = Wx::StaticText->new($this, -1, "Rmin");
  $this->{rmin} = Wx::TextCtrl ->new($this, -1, $Demeter::UI::Athena::demeter->co->default("plot", "rmin"),
				     wxDefaultPosition, [50,-1]);
  $range -> Add($label,        0, wxALL, 5);
  $range -> Add($this->{rmin}, 0, wxRIGHT, 10);
  $label = Wx::StaticText->new($this, -1, "Rmax");
  $this->{rmax} = Wx::TextCtrl ->new($this, -1, $Demeter::UI::Athena::demeter->co->default("plot", "rmax"),
				     wxDefaultPosition, [50,-1]);
  $range -> Add($label,        0, wxALL, 5);
  $range -> Add($this->{rmax}, 0, wxRIGHT, 10);


  $this->SetSizerAndFit($box);
  return $this;
};

1;
