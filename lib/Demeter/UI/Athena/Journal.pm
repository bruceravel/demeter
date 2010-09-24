package Demeter::UI::Athena::Journal;

use Wx qw( :everything );
use base 'Wx::Panel';
use Wx::Event qw(EVT_LIST_ITEM_ACTIVATED EVT_LIST_ITEM_SELECTED EVT_BUTTON  EVT_KEY_DOWN);

use vars qw($label $tag);
$label = "Journal";
$tag = 'Journal';

sub new {
  my ($class, $parent, $app) = @_;
  my $this = $class->SUPER::new($parent, -1, wxDefaultPosition, wxDefaultSize, wxMAXIMIZE_BOX );

  my $box = Wx::BoxSizer->new( wxVERTICAL);
  $this->{sizer}  = $box;
  $this->{parent} = $parent;

  $this->{object} = Demeter::Journal->new;
  $this->{journal} = Wx::TextCtrl->new($this, -1, q{}, wxDefaultPosition, wxDefaultSize,
				       wxTE_MULTILINE|wxTE_WORDWRAP|wxTE_AUTO_URL);
  $box->Add($this->{journal}, 1, wxGROW|wxADD, 5);

  $this->SetSizerAndFit($box);
  return $this;
};

sub pull_values {
  my ($this, $data) = @_;
  1;
};
sub push_values {
  my ($this, $data) = @_;
  1;
};
sub mode {
  my ($this, $data, $enabled, $frozen) = @_;
  1;
};

1;
