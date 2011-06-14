package Demeter::UI::Athena::Plot::Stack;

use strict;
use warnings;

use Wx qw( :everything );
use base 'Wx::Panel';
use Wx::Event qw(EVT_BUTTON EVT_TEXT_ENTER);
use Wx::Perl::TextValidator;

use Demeter::UI::Wx::SpecialCharacters qw(:all);
#use Demeter::UI::Athena::Replot;

sub new {
  my ($class, $parent, $app) = @_;
  my $this = $class->SUPER::new($parent, -1, wxDefaultPosition, wxDefaultSize, wxMAXIMIZE_BOX );

  my $box = Wx::BoxSizer->new( wxVERTICAL );

  $box -> Add(Wx::StaticText->new($this, -1, "Set y-offset values for"), 0, wxALIGN_CENTER_HORIZONTAL|wxTOP, 5);
  $box -> Add(Wx::StaticText->new($this, -1, "all marked groups"), 0, wxALIGN_CENTER_HORIZONTAL|wxBOTTOM, 5);

  my $gbs = Wx::GridBagSizer->new( 5, 5 );

  $gbs -> Add(Wx::StaticText->new($this, -1, "Initial value"), Wx::GBPosition->new(0,0));
  $gbs -> Add(Wx::StaticText->new($this, -1, "Increment"),     Wx::GBPosition->new(1,0));

  $this->{initial}   = Wx::TextCtrl->new($this, -1, 0, wxDefaultPosition, [60,-1], wxTE_PROCESS_ENTER);
  $this->{increment} = Wx::TextCtrl->new($this, -1, 0, wxDefaultPosition, [60,-1], wxTE_PROCESS_ENTER);
  $this->{apply}     = Wx::Button  ->new($this, -1, "Apply");
  $gbs -> Add($this->{initial},   Wx::GBPosition->new(0,1));
  $gbs -> Add($this->{increment}, Wx::GBPosition->new(1,1));
  $app->mouseover($this->{initial},   "The y_offset value of the first marked group.");
  $app->mouseover($this->{increment}, "The step of each subsequent marked group.  (I recommend using a negative value.)");

  $box -> Add($gbs, 0, wxALIGN_CENTER_HORIZONTAL|wxALL, 5);
  $box -> Add($this->{apply}, 0, wxALIGN_CENTER_HORIZONTAL|wxALL, 5);

  foreach my $x (qw(initial increment)) {
    $this->{$x} -> SetValidator( Wx::Perl::TextValidator->new( qr([-0-9.]) ) );
    EVT_TEXT_ENTER($this, $this->{$x}, sub{apply(@_, $app)});
  };
  $this->EVT_BUTTON($this->{apply}, sub{apply(@_, $app)});

  $this->SetSizerAndFit($box);
  return $this;
};

sub label {
  return 'Stack plots';
};

sub apply {
  my ($this, $event, $app) = @_;
  my $offset = $this->{initial}->GetValue;
  my $step   = $this->{increment}->GetValue;
  foreach my $i (0 .. $app->{main}->{list}->GetCount-1) {
    next if not $app->{main}->{list}->IsChecked($i);
    $app->{main}->{list}->GetIndexedData($i)->y_offset($offset);
    $offset += $step;
  };
  $app->{main}->{Main}->{y_offset}->SetValue($app->current_data->y_offset)
    if $app->{main}->{list}->IsChecked($app->current_index);
  $app->modified(1);
};

1;
