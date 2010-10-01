package Demeter::UI::Athena::Plot::Other;

use Wx qw( :everything );
use base 'Wx::Panel';
use Wx::Event qw(EVT_TOGGLEBUTTON EVT_CHECKBOX);
use Wx::Perl::TextValidator;

use Demeter::UI::Wx::SpecialCharacters qw(:all);
#use Demeter::UI::Athena::Replot;

sub new {
  my ($class, $parent, $app) = @_;
  my $this = $class->SUPER::new($parent, -1, wxDefaultPosition, wxDefaultSize, wxMAXIMIZE_BOX );

  my $box = Wx::BoxSizer->new( wxVERTICAL );

  my $titlebox       = Wx::StaticBox->new($this, -1, 'Title for marked group plot', wxDefaultPosition, wxDefaultSize);
  my $titleboxsizer  = Wx::StaticBoxSizer->new( $titlebox, wxHORIZONTAL );
  $box              -> Add($titleboxsizer, 0, wxGROW|wxALL, 5);
  $this->{title}     = Wx::TextCtrl->new($this, -1, q{});
  $titleboxsizer    -> Add($this->{title}, 1, wxALL|wxGROW, 0);

  $this->{nokey}      = Wx::CheckBox->new($this, -1, "Suppress plot legend");
  $this->{singlefile} = Wx::ToggleButton->new($this, -1, "Save next plot to a file");
  $box               -> Add($this->{nokey},      0, wxGROW|wxALL, 5);
  $box               -> Add($this->{singlefile}, 0, wxGROW|wxALL, 5);
  EVT_CHECKBOX($this, $this->{nokey}, sub{$app->current_data->po->showlegend(not $_[0]->{nokey}->IsChecked)});

  $this->SetSizerAndFit($box);
  return $this;
};

1;

