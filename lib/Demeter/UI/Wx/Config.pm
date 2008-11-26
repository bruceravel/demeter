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
  $self->{grid} = Wx::GridBagSizer -> new(5,10);

  my $this = Wx::GBPosition->new(0, 0);
  my $label = Wx::StaticText->new( $self, -1, 'Parameter');
  $self->{grid} -> Add($label, $this); #, wxALIGN_CENTER);
  $this = Wx::GBPosition->new(0, 1);
  $self->{Name} = Wx::StaticText->new( $self, -1, q{});
  $self->{grid} -> Add($self->{Name}, $this);

  $this = Wx::GBPosition->new(1, 0);
  $label = Wx::StaticText->new( $self, -1, 'Type');
  $self->{grid} -> Add($label, $this);
  $this = Wx::GBPosition->new(1, 1);
  $self->{Type} = Wx::StaticText->new( $self, -1, q{});
  $self->{grid} -> Add($self->{Type}, $this);

  $this = Wx::GBPosition->new(2, 0);
  $label = Wx::StaticText->new( $self, -1, 'Your value');
  $self->{grid} -> Add($label, $this);
  $this = Wx::GBPosition->new(2, 1);
  $self->{Value} = Wx::Button->new( $self, -1, q{});
  $self->{grid} -> Add($self->{Value}, $this);

  $this = Wx::GBPosition->new(2, 2);
  $label = Wx::StaticText->new( $self, -1, q{      });
  $self->{grid} -> Add($label, $this);

  $this = Wx::GBPosition->new(2, 3);
  $label = Wx::StaticText->new( $self, -1, 'Demeter\'s value');
  $self->{grid} -> Add($label, $this);
  $this = Wx::GBPosition->new(2, 4);
  $self->{Default} = Wx::Button->new( $self, -1, q{});
  $self->{grid} -> Add($self->{Default}, $this);

  $this = Wx::GBPosition->new(3, 0);
  $label = Wx::StaticText->new( $self, -1, 'Set');
  $self -> {grid} -> Add($label, $this);
  $self -> {SetPosition} = Wx::GBPosition->new(3, 1);
  $self -> set_stub;

  $right -> Add($self->{grid}, 0, wxEXPAND|wxALL, 5);

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
  my $root = $self->{params} -> AddRoot('Root');
  foreach my $g (@grouplist) {
    my @params = $demeter->co->parameters($g);
    my $branch = $self->{params} -> AppendItem($root, $g);
    map {$self->{params} -> AppendItem($branch, $_)} @params;
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
  $self->{grid}->Detach($self->{Set});
  $self->{Set} ->Destroy;
  $self->{grid}->Layout;

  if (not $is_parent) {
    $parent = $self->{params}->GetItemParent($clickedon);
    $parent = $self->{params}->GetItemText($parent);
    $self->{desc}  -> WriteText($demeter->co->description($parent, $param));
    $self->{Name}  -> SetLabel($param);
    $self->{Type}  -> SetLabel($demeter->co->Type($parent, $param));
    $self->{Value} -> SetLabel($demeter->co->default($parent, $param));
    $self->{Default} -> SetLabel($demeter->co->demeter($parent, $param));

    my $type = $demeter->co->Type($parent, $param);

  WIDGET: {
      $self->set_string_widget($parent, $param, $type), last WIDGET if ($type =~ m{(?:string|real|regex|absolute energy)});
      $self->set_list_widget($parent, $param),          last WIDGET if ($type eq 'list');
      $self->set_spin_widget($parent, $param),          last WIDGET if ($type eq 'positive integer');
      $self->set_boolean_widget($parent, $param),       last WIDGET if ($type eq 'boolean');
      $self->set_color_widget($parent, $param),         last WIDGET if ($type eq 'boolean');

      ## fall back
      $self->set_stub;
    };

  } else {
    $self->set_stub;
    $self->{desc}->WriteText($demeter->co->description($param));
  };
  $self->{grid} -> Add($self->{Set}, $self->{SetPosition});
  $self->{grid} -> Layout;

}

sub set_stub {
  my ($self) = @_;
  $self->{Set} = Wx::StaticText->new( $self, -1, q{});
  return $self->{Set};
};

## x  string                Entry
## x  regex                 Entry
## x  real                  Entry  -- validates to accept only numbers
## x  positive integer      Entry with incrementers, restricted to be >= 0
## x  list                  Menubutton or some other multiple selection widget
## x  boolean               Checkbutton
##   keypress              Entry  -- rigged to display one character at a time
##   color                 Button -- launches color browser
##   font                  Button -- does nothing at this time
## x  absolute energy

sub set_string_widget {
  my ($self, $parent, $param, $type) = @_;
  my $this = $demeter->co->default($parent, $param);
  $self->{Set} = Wx::TextCtrl->new( $self, -1, $this, [-1, -1], [-1, -1] );

  ## use $type to set validation

  return $self->{Set};
};


sub set_list_widget {
  my ($self, $parent, $param) = @_;
  my @choices = split(" ", $demeter->co->options($parent, $param));
  $self->{Set} = Wx::Choice->new( $self, -1, [-1, -1], [-1, -1], \@choices );
  return $self->{Set};
};

sub set_spin_widget {
  my ($self, $parent, $param) = @_;
  my $this = $demeter->co->default($parent, $param);
  $self->{Set} = Wx::SpinCtrl->new($self, -1, $this, wxDefaultPosition, [-1,-1]);
  $self->{Set} -> SetRange($demeter->co->minint($parent, $param),
			   $demeter->co->maxint($parent, $param));
  return $self->{Set};
};

sub set_boolean_widget {
  my ($self, $parent, $param) = @_;
  my $this = $demeter->co->default($parent, $param);
  $self->{Set} = Wx::CheckBox->new($self, -1, $param, wxDefaultPosition, [-1,-1]);
  $self->{Set}->SetValue($this);
  return $self->{Set};
};

sub set_color_widget {
  my ($self, $parent, $param) = @_;
  my $this = $demeter->co->default($parent, $param);
  $self->{Set} = Wx::Button->new($self, -1, "Color dialog", wxDefaultPosition, [-1,-1]);
  $self->{Default}->SetOwnBackgroundColour( WxColour->new(175, 0, 0) );
  $self->{Default}->ClearBackground;
  $self->{Default}->Update;
  return $self->{Set};
};


1;

