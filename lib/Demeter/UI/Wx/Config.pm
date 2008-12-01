package Demeter::UI::Wx::Config;
use strict;
use warnings;
use Carp;
use List::MoreUtils qw(firstidx);

use Wx qw( :everything );
use Wx::Event qw(EVT_BUTTON EVT_TREE_SEL_CHANGED);

use Demeter;
my $demeter = Demeter->new;

use Demeter::UI::Wx::ColourDatabase;
my $cdb = Demeter::UI::Wx::ColourDatabase->new;

use base 'Wx::Panel';

sub new {
  my ($class, $parent, $callback) = @_;
  my $self = $class->SUPER::new($parent, -1, wxDefaultPosition, wxDefaultSize, wxMAXIMIZE_BOX );

  my $mainsizer = Wx::BoxSizer->new( wxHORIZONTAL );
  $self -> SetSizer($mainsizer);

  ## -------- list of parameters
  $self->{paramsbox} = Wx::StaticBox->new($self, -1, 'Parameters', wxDefaultPosition, wxDefaultSize);
  $self->{paramsboxsizer} = Wx::StaticBoxSizer->new( $self->{paramsbox}, wxVERTICAL );
  $self->{params} = Wx::TreeCtrl->new($self, -1, wxDefaultPosition, wxDefaultSize,
				      wxTR_SINGLE|wxTR_HAS_BUTTONS|wxTR_HIDE_ROOT);
  $self->{paramsboxsizer} -> Add($self->{params}, 1, wxEXPAND|wxALL, 0);
  $mainsizer -> Add($self->{paramsboxsizer}, 1, wxEXPAND|wxALL, 5);
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
  EVT_BUTTON( $self, $self->{Value}, sub{my($self, $event) = @_; set_value($self, $event, 'default')} );

  $this = Wx::GBPosition->new(2, 2);
  $label = Wx::StaticText->new( $self, -1, q{      });
  $self->{grid} -> Add($label, $this);

  $this = Wx::GBPosition->new(2, 3);
  $label = Wx::StaticText->new( $self, -1, 'Demeter\'s value');
  $self->{grid} -> Add($label, $this);
  $this = Wx::GBPosition->new(2, 4);
  $self->{Default} = Wx::Button->new( $self, -1, q{});
  $self->{grid} -> Add($self->{Default}, $this);
  EVT_BUTTON( $self, $self->{Default}, sub{my($self, $event) = @_; set_value($self, $event, 'demeter')} );

  $this = Wx::GBPosition->new(3, 0);
  $label = Wx::StaticText->new( $self, -1, 'Set');
  $self -> {grid} -> Add($label, $this);
  $self -> {SetPosition} = Wx::GBPosition->new(3, 1);
  $self -> set_stub;

  $right -> Add($self->{grid}, 0, wxEXPAND|wxALL, 10);

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
  $self->{save} = Wx::Button->new( $self, -1, 'Apply and Save', wxDefaultPosition, wxDefaultSize );
  $buttonbox -> Add($self->{save}, 1, wxEXPAND|wxALL, 5);
  $right -> Add($buttonbox, 0, wxEXPAND|wxALL, 5);

  EVT_BUTTON( $self, $self->{apply}, sub{my($self, $event) = @_; $self->apply($callback, 0)} );
  EVT_BUTTON( $self, $self->{save},  sub{my($self, $event) = @_; $self->apply($callback, 1)} );

  return $self;
};

sub populate {
  my ($self, $grouplist) = @_;

  $grouplist ||= 'all';
  my @grouplist;
 LIST: {
    ($grouplist eq 'base') and do {
      @grouplist = @{ $demeter->co->main_groups };
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
    map {$self->{params} -> AppendItem($branch, $_) if ($_ !~ m{\Ac\d{1,2}\z})} @params;
  };
  if ($#grouplist == 0) {
    $self->{params}->ExpandAll;
    my ($first, $toss) = $self->{params}->GetFirstChild($root);
    $self->{params}->SelectItem($first);
    my $this = $self->{params}->GetItemText( $self->{params}->GetSelection );
    $self->{desc}->Clear;
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

    my $description = $demeter->co->description($parent, $param);
    if ($demeter->co->units($parent, $param)) {
      $description .= $/ x 3 . "This parameter is in units of " . $demeter->co->units($parent, $param) . ".";
    };
    if ($demeter->co->restart($parent, $param)) {
      $description .= $/ x 3 . "A change in this parameter will take effect the next time you start this application";
    };
    $self->{desc}  -> WriteText($description);
    $self->{Name}  -> SetLabel($param);
    $self->{Type}  -> SetLabel($demeter->co->Type($parent, $param));
    my $type = $demeter->co->Type($parent, $param);

    if ($type eq 'boolean') {
      $self->{Value}   -> SetLabel($demeter->truefalse( $demeter->co->default($parent, $param) ));
      $self->{Default} -> SetLabel($demeter->truefalse( $demeter->co->demeter($parent, $param) ));
    } else {
      $self->{Value} -> SetLabel($demeter->co->default($parent, $param));
      $self->{Default} -> SetLabel($demeter->co->demeter($parent, $param));
    };
    $self->{Value}   -> SetOwnBackgroundColour(wxNullColour);
    $self->{Default} -> SetOwnBackgroundColour(wxNullColour);

  WIDGET: {
      $self->set_string_widget($parent, $param, $type), last WIDGET if ($type =~ m{(?:string|real|regex|absolute energy)});
      $self->set_list_widget($parent, $param),          last WIDGET if ($type eq 'list');
      $self->set_spin_widget($parent, $param),          last WIDGET if ($type eq 'positive integer');
      $self->set_boolean_widget($parent, $param),       last WIDGET if ($type eq 'boolean');
      $self->set_color_widget($parent, $param),         last WIDGET if ($type eq 'color');

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


sub apply {
  my ($self, $callback, $save) = @_;
  my $selected = $self->{params}->GetSelection;
  my $param    = $self->{params}->GetItemText($selected);
  my $parent   = $self->{params}->GetItemParent($selected);
  $parent      = $self->{params}->GetItemText($parent);

  my $value;
  my $type = $demeter->co->Type($parent, $param);
 WIDGET: {
    $value = $self->{Set}->GetValue,           last WIDGET if ($type =~ m{(?:string|real|regex|absolute energy)});
    $value = $self->{Set}->GetStringSelection, last WIDGET if ($type eq 'list');
    $value = $self->{Set}->GetValue,           last WIDGET if ($type eq 'positive integer');
    $value = $demeter->onezero($self->{Set}->GetValue), last WIDGET if ($type eq 'boolean');
    $value = $self->{Set}->GetColour->GetAsString(wxC2S_HTML_SYNTAX), last WIDGET if ($type eq 'color');
  };

  $demeter->co->set_default($parent, $param, $value);
  $demeter->co->write_ini if $save;
  $self->$callback($parent, $param, $value, $save);
};

sub set_value {
  my ($self, $event, $which) = @_;
  my $selected = $self->{params}->GetSelection;
  my $param    = $self->{params}->GetItemText($selected);
  my $parent   = $self->{params}->GetItemParent($selected);
  $parent      = $self->{params}->GetItemText($parent);
  my $value    = $demeter->co->$which($parent, $param);
  #print join(" ", $which, $param, $parent, $value), $/;

  my $type = $demeter->co->Type($parent, $param);
 WIDGET: {
    $self->{Set}->SetValue($value),                     last WIDGET if ($type =~ m{(?:string|real|regex|absolute energy)});

    ($type eq 'list') and do {
      $self->{Set}->SetSelection(firstidx {$_ eq $value} split(" ", $demeter->co->options($parent, $param)));
      last WIDGET;
    };

    $self->{Set}->SetValue($value),                     last WIDGET if ($type eq 'positive integer');

    $self->{Set}->SetValue($demeter->onezero($value)),  last WIDGET if ($type eq 'boolean');

    ($type eq 'color') and do {
      if ($value =~ m{\A\#}) {
	my $col = Wx::Colour->new($value);
	$self->{Set}   -> SetColour( $col );
      } else {
	$self->{Set}   -> SetColour( $cdb->Find($value) );
      };
      last WIDGET;
    };

  };
};

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
  my @choices  = split(" ", $demeter->co->options($parent, $param));
  $self->{Set} = Wx::Choice->new( $self, -1, [-1, -1], [-1, -1], \@choices );
  my $value    = $demeter->co->default($parent, $param);
  $self->{Set}->SetSelection(firstidx {$_ eq $value} split(" ", $demeter->co->options($parent, $param)));
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

  my $color;
  my $this = $demeter->co->default($parent, $param);
  if ($this =~ m{\A\#}) {
    my $col = Wx::Colour->new($this);
    $self->{Value} -> SetOwnBackgroundColour( $col );
    $color = $col;
  } else {
    $self->{Value} -> SetOwnBackgroundColour( $cdb->Find($this) );
    $color = $cdb->Find($this);
  };

  $this = $demeter->co->demeter($parent, $param);
  if ($this =~ m{\A\#}) {
    my $col = Wx::Colour->new($this);
    $self->{Default}->SetOwnBackgroundColour( $col );
  } else {
    $self->{Default}->SetOwnBackgroundColour( $cdb->Find($this) );
  };

  $self->{Set} = Wx::ColourPickerCtrl->new( $self, -1, $color, [-1, -1],
					    [-1, -1] );

  #EVT_COLOURPICKER_CHANGED( $self, $self->{Set}, sub{ my ($self, $event) = @_; $self->color_picker; } );

  return $self->{Set};
};


1;

=head1 NAME

Demeter::UI::Wx::Config - A configuration widget for Demeter applications

=head1 VERSION

This documentation refers to Demeter version 0.2.

=head1 SYNOPSIS

A configuration widget can be added to a Wx application:

  my $config = Demeter::UI::Wx::Config -> new($parent, \&callback);
  $sizer -> Add($config, 0, wxALIGN_CENTER_HORIZONTAL|wxALL, 5);

=head1 DESCRIPTION

This is a configuration widget ...

=head1 METHODS

=over 4

=item populate

 all base list

=back

=head1 USING THE CONFIGURATION WIDGET

=head2 Using the tree

=head2 Using the controls

=head2 Applying and saving parameter values

=head1 DEPENDENCIES

Demeter's dependencies are in the F<Bundle/DemeterBundle.pm> file.

=head1 BUGS AND LIMITATIONS

Please report problems to Bruce Ravel (bravel AT bnl DOT gov)

Patches are welcome.

=head1 AUTHOR

Bruce Ravel (bravel AT bnl DOT gov)

L<http://cars9.uchicago.edu/~ravel/software/>

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2008 Bruce Ravel (bravel AT bnl DOT gov). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
