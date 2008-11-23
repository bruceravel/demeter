package Demeter::UI::Wx::Config;
use strict;
use warnings;
use Carp;
use Wx qw( :everything );
use Wx::Event qw(EVT_BUTTON);

use Demeter;

use base 'Wx::Panel';

sub new {
  my ($class, $parent) = @_;
  my $self = $class->SUPER::new($parent, -1, wxDefaultPosition, wxDefaultSize, wxMAXIMIZE_BOX );

  my $mainsizer = Wx::BoxSizer->new( wxHORIZONTAL );
  $self -> SetSizer($mainsizer);

  ## -------- list of materials
  $self->{paramsbox} = Wx::StaticBox->new($self, -1, 'Parameters', wxDefaultPosition, wxDefaultSize);
  $self->{paramsboxsizer} = Wx::StaticBoxSizer->new( $self->{paramsbox}, wxVERTICAL );
  $self->{params} = Wx::TreeCtrl->new($self, -1, wxDefaultPosition, wxDefaultSize,
				      wxTR_SINGLE|wxTR_HAS_BUTTONS);
  $self->{paramsboxsizer} -> Add($self->{params}, 1, wxEXPAND|wxALL, 0);
  $mainsizer -> Add($self->{paramsboxsizer}, 1, wxEXPAND|wxALL, 5);
  #EVT_LISTBOX( $self, $self->{params}, sub{1;} );

  my $right = Wx::BoxSizer->new( wxVERTICAL );
  $mainsizer -> Add($right, 3, wxEXPAND|wxALL, 5);

  ## -------- Grid of controls
  my $grid = Wx::GridBagSizer -> new(2,2);
  my $row = 0;
  foreach my $which (qw(Name Type Default Set)) {
    my $this = Wx::GBPosition->new($row, 0);
    my $label = Wx::StaticText->new( $self, -1, $which, [-1,-1], [-1,-1] );
    my $cell = $grid -> Add($label, $this);
    $this = Wx::GBPosition->new($row, 1);
    my $widget = Wx::TextCtrl->new( $self, -1, q{});
    $cell = $grid -> Add($widget, $this);
    $row++;
  };
  $right -> Add($grid, 0, wxEXPAND|wxALL, 5);

  ## -------- Description text
  $self->{descbox} = Wx::StaticBox->new($self, -1, 'Description', wxDefaultPosition, wxDefaultSize);
  $self->{descboxsizer} = Wx::StaticBoxSizer->new( $self->{descbox}, wxVERTICAL );
  $self->{desc} = Wx::TextCtrl->new($self, -1, q{}, wxDefaultPosition, wxDefaultSize,
				    wxVSCROLL|wxTE_MULTILINE|wxTE_READONLY|wxNO_BORDER);
  $self->{descboxsizer} -> Add($self->{desc}, 1, wxEXPAND|wxALL, 2);
  $self->{desc}->SetFont( Wx::Font->new( 10, wxTELETYPE, wxNORMAL, wxNORMAL, 0, "" ) );
  $right -> Add($self->{descboxsizer}, 1, wxEXPAND|wxALL, 5);

  ## -------- Button box
  my $buttonbox = Wx::BoxSizer->new( wxHORIZONTAL );
  $self->{apply} = Wx::Button->new( $self, -1, 'Apply', wxDefaultPosition, wxDefaultSize );
  $buttonbox -> Add($self->{apply}, 1, wxEXPAND|wxALL, 5);
  $self->{save} = Wx::Button->new( $self, -1, 'Save', wxDefaultPosition, wxDefaultSize );
  $buttonbox -> Add($self->{save}, 1, wxEXPAND|wxALL, 5);
  $right -> Add($buttonbox, 0, wxEXPAND|wxALL, 5);

  return $self;
};

# sub populate {
#   my ($self, $grouplist) = @_;
#   $demeter = Demeter->new;
#   foreach my (@$grouplist) {
    
#   };
# };

1;

