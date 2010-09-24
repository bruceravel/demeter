package Demeter::UI::Athena::ColumnSelection::Preprocess;

use Wx qw( :everything );
use base 'Wx::Panel';
use Wx::Event qw(EVT_CHECKBOX EVT_RADIOBUTTON);
use Wx::Perl::TextValidator;

use Demeter::UI::Wx::SpecialCharacters qw(:all);
#use Demeter::UI::Athena::Replot;

sub new {
  my ($class, $parent, $app) = @_;
  my $this = $class->SUPER::new($parent, -1, wxDefaultPosition, wxDefaultSize, wxMAXIMIZE_BOX );

  my $box = Wx::BoxSizer->new( wxVERTICAL );

  $this->SetSizerAndFit($box);
  return $this;

};

1;
