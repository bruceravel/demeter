package Demeter::UI::Athena::PlotE;

use Wx qw( :everything );
use base 'Wx::Panel';
use Wx::Event qw(EVT_LIST_ITEM_ACTIVATED EVT_LIST_ITEM_SELECTED EVT_BUTTON  EVT_KEY_DOWN);

use Demeter::UI::Wx::SpecialCharacters qw(:all);

sub new {
  my ($class, $parent) = @_;
  my $this = $class->SUPER::new($parent, -1, wxDefaultPosition, wxDefaultSize, wxMAXIMIZE_BOX );

  my $box = Wx::BoxSizer->new( wxVERTICAL );

  my $hbox = Wx::BoxSizer->new( wxVERTICAL );
  $box -> Add($hbox, 0, wxALL|wxALIGN_CENTER_HORIZONTAL, 4);

  my $slot = Wx::BoxSizer->new( wxHORIZONTAL );
  $hbox -> Add($slot, 1, wxGROW|wxALL, 0);
  $this->{mu} = Wx::CheckBox->new($this, -1, $MU.'(E)');
  $this->{mu} -> SetValue($Demeter::UI::Athena::demeter->co->default("plot", "e_mu"));
  $slot -> Add($this->{mu}, 1, wxALL, 1);
  $this->{mmu} = Wx::CheckBox->new($this, -1, '');
  $this->{mmu} -> SetValue($Demeter::UI::Athena::demeter->co->default("plot", "e_mu"));
  $slot -> Add($this->{mmu}, 0, wxALL, 1);

  $slot = Wx::BoxSizer->new( wxHORIZONTAL );
  $hbox -> Add($slot, 1, wxGROW|wxALL, 0);
  $this->{bkg} = Wx::CheckBox->new($this, -1, 'Background');
  $this->{bkg} -> SetValue($Demeter::UI::Athena::demeter->co->default("plot", "e_bkg"));
  $slot -> Add($this->{bkg}, 0, wxALL, 1);

  $slot = Wx::BoxSizer->new( wxHORIZONTAL );
  $hbox -> Add($slot, 1, wxGROW|wxALL, 0);
  $this->{pre} = Wx::CheckBox->new($this, -1, 'pre-edge line');
  $this->{pre} -> SetValue($Demeter::UI::Athena::demeter->co->default("plot", "e_pre"));
  $slot -> Add($this->{pre}, 0, wxALL, 1);

  $slot = Wx::BoxSizer->new( wxHORIZONTAL );
  $hbox -> Add($slot, 1, wxGROW|wxALL, 0);
  $this->{post} = Wx::CheckBox->new($this, -1, 'post-edge line');
  $this->{post} -> SetValue($Demeter::UI::Athena::demeter->co->default("plot", "e_post"));
  $slot -> Add($this->{post}, 0, wxALL, 1);

  $slot = Wx::BoxSizer->new( wxHORIZONTAL );
  $hbox -> Add($slot, 1, wxGROW|wxALL, 0);
  $this->{norm} = Wx::CheckBox->new($this, -1, 'Normalized');
  $this->{norm} -> SetValue($Demeter::UI::Athena::demeter->co->default("plot", "e_norm"));
  $slot -> Add($this->{norm}, 1, wxALL, 1);
  $this->{mnorm} = Wx::CheckBox->new($this, -1, '');
  $this->{mnorm} -> SetValue($Demeter::UI::Athena::demeter->co->default("plot", "e_norm"));
  $slot -> Add($this->{mnorm}, 0, wxALL, 1);

  $slot = Wx::BoxSizer->new( wxHORIZONTAL );
  $hbox -> Add($slot, 1, wxGROW|wxALL, 0);
  $this->{der} = Wx::CheckBox->new($this, -1, 'Derivative');
  $this->{der} -> SetValue($Demeter::UI::Athena::demeter->co->default("plot", "e_der"));
  $slot -> Add($this->{der}, 1, wxALL, 1);
  $this->{mder} = Wx::CheckBox->new($this, -1, '');
  $this->{mder} -> SetValue($Demeter::UI::Athena::demeter->co->default("plot", "e_der"));
  $slot -> Add($this->{mder}, 0, wxALL, 1);

  $slot = Wx::BoxSizer->new( wxHORIZONTAL );
  $hbox -> Add($slot, 1, wxGROW|wxALL, 0);
  $this->{sec} = Wx::CheckBox->new($this, -1, 'Second derivative');
  $this->{sec} -> SetValue($Demeter::UI::Athena::demeter->co->default("plot", "e_sec"));
  $slot -> Add($this->{sec}, 1, wxALL, 1);
  $this->{msec} = Wx::CheckBox->new($this, -1, '');
  $this->{msec} -> SetValue($Demeter::UI::Athena::demeter->co->default("plot", "e_sec"));
  $slot -> Add($this->{msec}, 0, wxALL, 1);

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


  $this->SetSizerAndFit($box);
  return $this;
};

1;
