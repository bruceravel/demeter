package Demeter::UI::Athena::Plot::Other;

use strict;
use warnings;

use Wx qw( :everything );
use base 'Wx::Panel';
use Wx::Event qw(EVT_TOGGLEBUTTON EVT_CHECKBOX EVT_RADIOBOX EVT_TEXT_ENTER);
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
  $this->{title}     = Wx::TextCtrl->new($this, -1, q{}, wxDefaultPosition, wxDefaultSize, wxTE_PROCESS_ENTER);
  $titleboxsizer    -> Add($this->{title}, 1, wxALL|wxGROW, 0);
  EVT_TEXT_ENTER($this, $this->{title}, sub{
		   $app->plot(q{}, q{}, @{$app->{lastplot}});
		 });

  $this->{location}  = Wx::RadioBox->new($this, -1, 'Legend location', wxDefaultPosition, wxDefaultSize,
					 ["top left", "top right", "bottom left", "bottom right"], 2, wxRA_SPECIFY_COLS);
  $this->{location}  -> SetStringSelection($app->current_data->co->default('gnuplot', 'keylocation'));
  EVT_RADIOBOX($this, $this->{location}, sub{location(@_,$app)});
  $box               -> Add($this->{location},   0, wxGROW|wxALL, 5);

  $this->{nokey}      = Wx::CheckBox->new($this, -1, "Suppress plot legend");
  $this->{singlefile} = Wx::ToggleButton->new($this, -1, "Save next plot to a file");
  $box               -> Add($this->{nokey},      0, wxGROW|wxALL, 5);
  $box               -> Add($this->{singlefile}, 0, wxGROW|wxALL, 5);
  EVT_CHECKBOX($this, $this->{nokey}, sub{
		 $app->current_data->po->showlegend(not $_[0]->{nokey}->IsChecked);
		 $app->plot(q{}, q{}, @{$app->{lastplot}});
	       });
  $app->mouseover($this->{title},      "Specify a title for a marked group plot.");
  $app->mouseover($this->{nokey},      "Turn off the legend in subsequent plots.");
  $app->mouseover($this->{singlefile}, "Write the next plot to a column data file.  (Does not yet work for quad, stddev, or variance plots.)");

  $this->SetSizerAndFit($box);
  return $this;
};

sub location {
  my ($this, $event, $app) = @_;
  $app->current_data->co->set_default('gnuplot', 'keylocation', $this->{location}->GetStringSelection);
  $app->plot(q{}, q{}, @{$app->{lastplot}});
};

sub label {
  return 'Title, legend, single file';
};

1;

