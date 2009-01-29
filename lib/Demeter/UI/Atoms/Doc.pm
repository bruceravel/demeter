package  Demeter::UI::Atoms::Doc;

use Cwd;
use File::Spec;

use Wx qw( :everything );
use base 'Wx::Panel';

use Wx::Event qw(EVT_CHOICE EVT_KEY_DOWN EVT_MENU EVT_TOOL_ENTER EVT_ENTER_WINDOW EVT_LEAVE_WINDOW);


sub new {
  my ($class, $page, $parent, $statusbar) = @_;
  my $self = $class->SUPER::new($page, -1, wxDefaultPosition, wxDefaultSize, wxMAXIMIZE_BOX );
  $self->{parent}    = $parent;
  $self->{statusbar} = $statusbar;
  my $vbox = Wx::BoxSizer->new( wxVERTICAL );

  $self->{docbox}       = Wx::StaticBox->new($self, -1, 'Document', wxDefaultPosition, wxDefaultSize);
  $self->{docboxsizer}  = Wx::StaticBoxSizer->new( $self->{docbox}, wxVERTICAL );
  $self->{doc} = Wx::TextCtrl->new($self, -1, q{}, wxDefaultPosition, wxDefaultSize,
				   wxTE_MULTILINE|wxHSCROLL|wxALWAYS_SHOW_SB_READONLY);
  $self->{doc}->SetFont( Wx::Font->new( 9, wxTELETYPE, wxNORMAL, wxNORMAL, 0, "" ) );
  $self->{docboxsizer} -> Add($self->{doc}, 1, wxEXPAND|wxALL, 0);

  $self->{doc}->SetEditable(1);
  $self->{doc}->SetValue("Nothing yet...");
  $self->{doc}->SetEditable(0);

  $vbox -> Add($self->{docboxsizer}, 1, wxEXPAND|wxALL, 5);

  $self -> SetSizerAndFit( $vbox );
  return $self;
};

1;
