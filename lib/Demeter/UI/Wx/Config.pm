package Demeter::UI::Wx::Config;
use strict;
use warnings;
use Carp;
use Wx qw( :everything );
use Wx::Event qw(EVT_BUTTON EVT_TREE_SEL_CHANGED);

use Demeter;
my $demeter = Demeter->new;

use base 'Wx::Panel';

sub new {
  my ($class, $parent) = @_;
  my $self = $class->SUPER::new($parent, -1, wxDefaultPosition, wxDefaultSize, wxMAXIMIZE_BOX );

  my $mainsizer = Wx::BoxSizer->new( wxHORIZONTAL );
  $self -> SetSizer($mainsizer);

  ## -------- list of parameters
  $self->{paramsbox} = Wx::StaticBox->new($self, -1, 'Parameters', wxDefaultPosition, wxDefaultSize);
  $self->{paramsboxsizer} = Wx::StaticBoxSizer->new( $self->{paramsbox}, wxVERTICAL );
  $self->{params} = Wx::TreeCtrl->new($self, -1, wxDefaultPosition, wxDefaultSize,
				      wxTR_SINGLE|wxTR_HAS_BUTTONS);
  $self->{paramsboxsizer} -> Add($self->{params}, 1, wxEXPAND|wxALL, 0);
  $mainsizer -> Add($self->{paramsboxsizer}, 1, wxEXPAND|wxALL, 5);
  #EVT_LISTBOX( $self, $self->{params}, sub{1;} );
  EVT_TREE_SEL_CHANGED( $self, $self->{params}, \&tree_select );

  my $right = Wx::BoxSizer->new( wxVERTICAL );
  $mainsizer -> Add($right, 3, wxEXPAND|wxALL, 5);

  ## -------- Grid of controls
  my $grid = Wx::GridBagSizer -> new(5,10);

  my $this = Wx::GBPosition->new(0, 0);
  my $label = Wx::StaticText->new( $self, -1, 'Parameter');
  $grid -> Add($label, $this);
  $this = Wx::GBPosition->new(0, 1);
  $self->{Name} = Wx::StaticText->new( $self, -1, q{});
  $grid -> Add($self->{Name}, $this);

  $this = Wx::GBPosition->new(1, 0);
  $label = Wx::StaticText->new( $self, -1, 'Type');
  $grid -> Add($label, $this);
  $this = Wx::GBPosition->new(1, 1);
  $self->{Type} = Wx::StaticText->new( $self, -1, q{});
  $grid -> Add($self->{Type}, $this);

  $this = Wx::GBPosition->new(2, 0);
  $label = Wx::StaticText->new( $self, -1, 'Your value');
  $grid -> Add($label, $this);
  $this = Wx::GBPosition->new(2, 1);
  $self->{Value} = Wx::Button->new( $self, -1, q{});
  $grid -> Add($self->{Value}, $this);

  $this = Wx::GBPosition->new(2, 2);
  $label = Wx::StaticText->new( $self, -1, q{      });
  $grid -> Add($label, $this);

  $this = Wx::GBPosition->new(2, 3);
  $label = Wx::StaticText->new( $self, -1, 'Demeter\'s value');
  $grid -> Add($label, $this);
  $this = Wx::GBPosition->new(2, 4);
  $self->{Default} = Wx::Button->new( $self, -1, q{});
  $grid -> Add($self->{Default}, $this);

  $this = Wx::GBPosition->new(3, 0);
  $label = Wx::StaticText->new( $self, -1, 'Set');
  $grid -> Add($label, $this);
  $this = Wx::GBPosition->new(3, 1);
  $self->{Set} = Wx::StaticText->new( $self, -1, q{});
  $grid -> Add($self->{Set}, $this);


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

sub populate {
  my ($self, $grouplist) = @_;

  my @grouplist;
 LIST: {
    ($grouplist eq 'base') and do {
      @grouplist = $demeter->co->main_groups;
      last LIST;
    };
    ($grouplist eq 'all') and do {
      @grouplist = $demeter->co->groups;
      last LIST;
    };
    (ref($grouplist) eq 'ARRAY') and do {
      @grouplist = @$grouplist;
      last LIST;
    };
    @grouplist = ($grouplist);
  };
  foreach my $g (@grouplist) {
    my @params = $demeter->co->parameters($g);
    my $root = $self->{params} -> AddRoot($g);
    map {$self->{params} -> AppendItem($root, $_)} @params;
  };
  if ($#grouplist == 0) {
    $self->{params}->ExpandAll;
    my $this = $self->{params}->GetItemText( $self->{params}->GetSelection );
    $self->{desc}->WriteText($demeter->co->description($this))
  };
};

sub tree_select {
  my ($self, $event) = @_;
  my $clickedon = $event->GetItem;
  my $param     = $self->{params}->GetItemText($clickedon);
  my $parent    = q{};
  my $is_parent = $self->{params}->ItemHasChildren($clickedon);
  $self->{desc}->Clear;
  if (not $is_parent) {
    $parent = $self->{params}->GetItemParent($clickedon);
    $parent = $self->{params}->GetItemText($parent);
    $self->{desc}  -> WriteText($demeter->co->description($parent, $param));
    $self->{Name}  -> SetLabel($param);
    $self->{Type}  -> SetLabel($demeter->co->Type($parent, $param));
    $self->{Value} -> SetLabel($demeter->co->default($parent, $param));
    $self->{Default} -> SetLabel($demeter->co->demeter($parent, $param));
  } else {
    $self->{desc}->WriteText($demeter->co->description($param));
  };

}

1;

