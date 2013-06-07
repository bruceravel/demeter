package Demeter::UI::Wx::Config;

=for Copyright
 .
 Copyright (c) 2006-2013 Bruce Ravel (bravel AT bnl DOT gov).
 All rights reserved.
 .
 This file is free software; you can redistribute it and/or
 modify it under the same terms as Perl itself. See The Perl
 Artistic License.
 .
 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut

use strict;
use warnings;
use Carp;
use List::MoreUtils qw(firstidx uniq);
use Text::Wrap;

use Wx qw( :everything );
use Wx::Event qw(EVT_BUTTON EVT_TREE_SEL_CHANGED EVT_TEXT_ENTER);

use Demeter qw(:none);

use Demeter::UI::Wx::ColourDatabase;
my $cdb = Demeter::UI::Wx::ColourDatabase->new;
my $aleft = Wx::TextAttr->new();
$aleft->SetAlignment(wxTEXT_ALIGNMENT_LEFT);

use base 'Wx::Panel';

sub new {
  my ($class, $parent, $callback) = @_;
  my $self = $class->SUPER::new($parent, -1, wxDefaultPosition, wxDefaultSize, wxMAXIMIZE_BOX );

  my $mainsizer = Wx::BoxSizer->new( wxHORIZONTAL );
  $self -> SetSizer($mainsizer);

  my $font = wxNullFont;
  $font->SetStyle(wxBOLD);

  ## -------- list of parameters
  $self->{paramsbox} = Wx::StaticBox->new($self, -1, 'Parameters', wxDefaultPosition, wxDefaultSize);
  $self->{paramsboxsizer} = Wx::StaticBoxSizer->new( $self->{paramsbox}, wxVERTICAL );
  my $style = (Demeter->is_windows) ? wxTR_SINGLE|wxTR_HAS_BUTTONS : wxTR_SINGLE|wxTR_HAS_BUTTONS|wxTR_HIDE_ROOT;
  $self->{params} = Wx::TreeCtrl->new($self, -1, wxDefaultPosition, wxDefaultSize, $style);
  $self->{paramsboxsizer} -> Add($self->{params}, 1, wxEXPAND|wxALL, 0);
  $mainsizer -> Add($self->{paramsboxsizer}, 1, wxEXPAND|wxALL, 5);
  EVT_TREE_SEL_CHANGED( $self, $self->{params}, \&tree_select );

  my $right = Wx::BoxSizer->new( wxVERTICAL );
  $mainsizer -> Add($right, 3, wxEXPAND|wxALL, 5);

  ## -------- Grid of controls
  $self->{grid} = Wx::GridBagSizer -> new(5,10);

  my $this = Wx::GBPosition->new(0, 0);
  my $label = Wx::StaticText->new( $self, -1, 'Selection');
  $label -> SetFont( $font );
  $self->{grid} -> Add($label, $this); # wxDefaultSpan, wxALIGN_CENTER);
  $this = Wx::GBPosition->new(0, 1);
  my $span       = Wx::GBSpan->new(1,4);
  $self->{Name}  = Wx::StaticText->new( $self, -1, q{});
  $self->{grid} -> Add($self->{Name}, $this, $span);

  $this = Wx::GBPosition->new(1, 0);
  $label = Wx::StaticText->new( $self, -1, 'Type');
  $label -> SetFont( $font );
  $self->{grid} -> Add($label, $this);
  $this = Wx::GBPosition->new(1, 1);
  $self->{Type} = Wx::StaticText->new( $self, -1, q{});
  $self->{grid} -> Add($self->{Type}, $this);

  $this = Wx::GBPosition->new(2, 0);
  $label = Wx::StaticText->new( $self, -1, 'Your value');
  $label -> SetFont( $font );
  $self->{grid} -> Add($label, $this);
  $this = Wx::GBPosition->new(2, 1);
  $self->{Value} = Wx::Button->new( $self, -1, q{});
  $self->{grid} -> Add($self->{Value}, $this);
  EVT_BUTTON( $self, $self->{Value}, sub{my($self, $event) = @_; set_value($self, $event, 'default')} );

#   $this = Wx::GBPosition->new(2, 2);
#   $label = Wx::StaticText->new( $self, -1, q{      });
#   $self->{grid} -> Add($label, $this);

  $this = Wx::GBPosition->new(3, 0);
  $label = Wx::StaticText->new( $self, -1, 'Demeter\'s value');
  $label -> SetFont( $font );
  $self->{grid} -> Add($label, $this);
  $this = Wx::GBPosition->new(3, 1);
  $self->{Default} = Wx::Button->new( $self, -1, q{});
  $self->{grid} -> Add($self->{Default}, $this);
  EVT_BUTTON( $self, $self->{Default}, sub{my($self, $event) = @_; set_value($self, $event, 'demeter')} );

  $this = Wx::GBPosition->new(4, 0);
  $label = Wx::StaticText->new( $self, -1, 'Set');
  $label -> SetFont( $font );
  $self -> {grid} -> Add($label, $this);
  $self -> {SetPosition} = Wx::GBPosition->new(4, 1);
  $self -> set_stub;

  $right -> Add($self->{grid}, 0, wxEXPAND|wxALL, 10);
  
  ## -------- Description text
  $self->{descbox} = Wx::StaticBox->new($self, -1, 'Description', wxDefaultPosition, wxDefaultSize);
  $self->{descboxsizer} = Wx::StaticBoxSizer->new( $self->{descbox}, wxVERTICAL );
  $self->{desc} = Wx::TextCtrl->new($self, -1, q{}, wxDefaultPosition, wxDefaultSize,
				    wxHSCROLL|wxTE_WORDWRAP|wxTE_READONLY|wxTE_MULTILINE|wxTE_RICH2);
  $self->{descboxsizer} -> Add($self->{desc}, 1, wxEXPAND|wxALL, 2);
  $self->{desc}->SetFont( Wx::Font->new( Wx::SystemSettings::GetFont(wxSYS_DEFAULT_GUI_FONT)->GetPointSize, wxTELETYPE, wxNORMAL, wxNORMAL, 0, "" ) );
  $self->{desc}->SetDefaultStyle($aleft);
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
  my @removelist;
  my @templist = (ref($grouplist) eq 'ARRAY') ? @$grouplist : ($grouplist);
  foreach my $t (@templist) {
    if ($t eq 'base') {
      push @grouplist,  @{ Demeter->co->main_groups };
    } elsif ($t eq 'all' ) {
      push @grouplist,  Demeter->co->groups;
    } elsif ($t =~ m{\A\!(\w+)}) {
      push @removelist, $1;
    } else {
      push @grouplist, $t;
    };
  };

  @grouplist = uniq(@grouplist);
#  print join(" ", @grouplist), $/;
#  print join(" ", @removelist), $/;
  if (@removelist) {
    my $regex = join("|", @removelist);
    @grouplist = grep { $_ !~ m{(?:$regex)}  } @grouplist;
  };

  my $root = $self->{params} -> AddRoot('Root');
  foreach my $g (@grouplist) {
    my @params = Demeter->co->parameters($g);
    my $branch = $self->{params} -> AppendItem($root, $g);
    map {$self->{params} -> AppendItem($branch, $_) if ($_ !~ m{\Ac\d{1,2}\z})} @params;
  };
  if ($#grouplist == 0) {
    $self->{params}->ExpandAll;
    my ($first, $toss) = $self->{params}->GetFirstChild($root);
    $self->{params}->SelectItem($first);
    my $this = $self->{params}->GetItemText( $self->{params}->GetSelection );
    $self->{desc}->Clear;
    {				# this shouldnot be necessary, why doesn't wrapping work in TextCtrl?
      local $Text::Wrap::columns = 47;
      $self->{desc}  -> WriteText(wrap(q{}, q{}, Demeter->co->description($this)));
    };
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

    my $description = Demeter->co->description($parent, $param);
    if (Demeter->co->units($parent, $param)) {
      $description .= $/ x 3 . "Units: " . Demeter->co->units($parent, $param);
    };
    if (Demeter->co->restart($parent, $param)) {
      $description .= $/ x 3 . "A change in this parameter will take effect the next time you start this application.";
    };
    {				# this shouldnot be necessary, why doesn't wrapping work in TextCtrl?
      local $Text::Wrap::columns = 47;
      $self->{desc}  -> WriteText(wrap(q{}, q{}, $description));
    };
    $self->{Name}  -> SetLabel(join(' --> ', $parent, $param));
    $self->{Type}  -> SetLabel(Demeter->co->Type($parent, $param));
    my $type = Demeter->co->Type($parent, $param);

    if ($type eq 'boolean') {
      $self->{Value}   -> SetLabel(Demeter->truefalse( Demeter->co->default($parent, $param) ));
      $self->{Default} -> SetLabel(Demeter->truefalse( Demeter->co->demeter($parent, $param) ));
    } else {
      $self->{Value} -> SetLabel(Demeter->co->default($parent, $param));
      $self->{Default} -> SetLabel(Demeter->co->demeter($parent, $param));
    };
    $self->{Value}   -> SetOwnBackgroundColour(wxNullColour);
    $self->{Value}   -> Enable;
    $self->{Default} -> SetOwnBackgroundColour(wxNullColour);
    $self->{Default} -> Enable;
    $self->{apply}   -> Enable;
    $self->{save}    -> Enable;
    $self->{apply}   -> Disable if Demeter->co->restart($parent, $param);

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
    $self->{Name}    -> SetLabel($param);
    $self->{Type}    -> SetLabel('Parameter group');
    $self->{Value}   -> SetLabel(q{});
    $self->{Value}   -> SetOwnBackgroundColour(wxNullColour);
    $self->{Value}   -> Disable;
    $self->{Default} -> SetLabel(q{});
    $self->{Default} -> SetOwnBackgroundColour(wxNullColour);
    $self->{Default} -> Disable;
    { # this shouldnot be necessary, why doesn't wrapping work in TextCtrl?
      local $Text::Wrap::columns = 47;
      $self->{desc}  -> WriteText(wrap(q{}, q{}, Demeter->co->description($param)));
    };
    $self->{apply}   -> Disable;
    $self->{save}    -> Disable;
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
  my $type = Demeter->co->Type($parent, $param);
 WIDGET: {
    $value = $self->{Set}->GetValue,           last WIDGET if ($type =~ m{(?:string|real|regex|absolute energy)});
    $value = $self->{Set}->GetStringSelection, last WIDGET if ($type eq 'list');
    $value = $self->{Set}->GetValue,           last WIDGET if ($type eq 'positive integer');
    $value = Demeter->onezero($self->{Set}->GetValue), last WIDGET if ($type eq 'boolean');
    $value = $self->{Set}->GetColour->GetAsString(wxC2S_HTML_SYNTAX), last WIDGET if ($type eq 'color');
  };

  Demeter->co->set_default($parent, $param, $value);
  Demeter->co->write_ini if $save;
  $self->$callback($parent, $param, $value, $save);
};

sub set_value {
  my ($self, $event, $which) = @_;
  my $selected = $self->{params}->GetSelection;
  my $param    = $self->{params}->GetItemText($selected);
  my $parent   = $self->{params}->GetItemParent($selected);
  $parent      = $self->{params}->GetItemText($parent);
  my $value    = Demeter->co->$which($parent, $param);
  #print join(" ", $which, $param, $parent, $value), $/;

  my $type = Demeter->co->Type($parent, $param);
 WIDGET: {
    $self->{Set}->SetValue($value),                     last WIDGET if ($type =~ m{(?:string|real|regex|absolute energy)});

    ($type eq 'list') and do {
      $self->{Set}->SetSelection(firstidx {$_ eq $value} split(" ", Demeter->co->options($parent, $param)));
      last WIDGET;
    };

    $self->{Set}->SetValue($value),                     last WIDGET if ($type eq 'positive integer');

    $self->{Set}->SetValue(Demeter->onezero($value)),  last WIDGET if ($type eq 'boolean');

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
  my $this = Demeter->co->default($parent, $param);
  $self->{Set} = Wx::TextCtrl->new( $self, -1, $this, [-1, -1], [200, -1], wxTE_PROCESS_ENTER );
  EVT_TEXT_ENTER($self, $self->{Set}, sub{1});
  ## use $type to set validation

  return $self->{Set};
};


sub set_list_widget {
  my ($self, $parent, $param) = @_;
  my @choices  = split(" ", Demeter->co->options($parent, $param));
  $self->{Set} = Wx::Choice->new( $self, -1, [-1, -1], [-1, -1], \@choices );
  my $value    = Demeter->co->default($parent, $param);
  $self->{Set}->SetSelection(firstidx {$_ eq $value} split(" ", Demeter->co->options($parent, $param)));
  return $self->{Set};
};

sub set_spin_widget {
  my ($self, $parent, $param) = @_;
  my $this = Demeter->co->default($parent, $param);
  $self->{Set} = Wx::SpinCtrl->new($self, -1, $this, wxDefaultPosition, [-1,-1]);
  $self->{Set} -> SetRange(Demeter->co->minint($parent, $param),
			   Demeter->co->maxint($parent, $param));
  return $self->{Set};
};

sub set_boolean_widget {
  my ($self, $parent, $param) = @_;
  my $this = Demeter->co->default($parent, $param);
  $self->{Set} = Wx::CheckBox->new($self, -1, $param, wxDefaultPosition, [-1,-1]);
  $self->{Set}->SetValue($this);
  return $self->{Set};
};

sub set_color_widget {
  my ($self, $parent, $param) = @_;

  my $color;
  my $this = Demeter->co->default($parent, $param);
  if ($this =~ m{\A\#}) {
    my $col = Wx::Colour->new($this);
    $self->{Value} -> SetOwnBackgroundColour( $col );
    $color = $col;
  } else {
    $self->{Value} -> SetOwnBackgroundColour( $cdb->Find($this) );
    $color = $cdb->Find($this);
  };

  $this = Demeter->co->demeter($parent, $param);
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

This documentation refers to Demeter version 0.9.17.

=head1 SYNOPSIS

A configuration widget can be added to a Wx application:

  my $config = Demeter::UI::Wx::Config -> new($parent, \&callback);
  $sizer -> Add($config, 0, wxALIGN_CENTER_HORIZONTAL|wxALL, 5);

The first argument is the window in which the configuration widget is
to be packed.  The second is a reference to a callback that will be
called whenever a parameter is altered.

=head1 DESCRIPTION

This is a widget for managing the rather dizzying array of
configuration parameters controled by the L<Demeter::Config> object.
Creating and packing the widget will give your user a way of examining
the various parameters and and altering their values.

To use this widget, you must provide a reference to a callback that
will be called when a parameter value is changed.  For the example in
the synopsis, the callback will be called like so:

  $config -> &$callback($group, $parameter, $value, $save);

Thus the callback must be a method of the object using this widget.
The other things passed are the group and name of the configuration
parameter, its new value, and a flag which is true if the ini file was
saved.

=head1 METHODS

=over 4

=item populate

This is the only user servicable method of this widget.  It is used to
populate the parameter tree with the desired subset of parameters.

   $config->populate('all');
     or
   $config->populate('plot', 'bkg', 'fft', 'bft');
     or
   $config->populate('hephaestus');

The second example might be used for a simple Athena-like application
while the third example is what is actually used in Hephaestus.

=over 4

=item C<all>

Display all groups known to the Config object.

=item C<base>

Display all groups known that are part of Demeter's principle set of
groups.  Those are the ones that are imported into the Config object
regardless of what the application is.  As an example of the
difference between C<all> and C<base>, Hephaestus defines an
application-specific parameter group called C<hephaestus>.  The
C<hephaestus> group will be included in C<all> but not in C<base>.

=item a list of specific groups

The other option is to specify a list of one or more specific
parameter groups to display in the tree.

=back

The default is to display all groups.

=back

=head1 USING THE CONFIGURATION WIDGET

=head2 Using the tree

Each parameter group is displayed to the right of an expander button.
Under wxGtk, this is a little triangle that points down when the group
is expaned and to the right when the group is collapsed.  Click on
this button to open or close the parameter group.

When you click on a parameter group, its description will be displayed
in the description box.

When you click on a parameter from a group that has been expanded in
the list, its description will be displayed in the description box and
other information will be displayed in the other controls on the right
side of the window.

You can only alter the value of a parameter that is selected in the
tree.

=head2 Using the controls

A control appropriate to the type of widget will be displayed just
above the description box.  For many parameter types, this is a box
for entering text.  For integer-valued parameters, this is spin box
that you can alter by typing in it directly or by clicking the little
up and down arrows.  For true/false parameters, a check box is used.
For color-valued parameters, a button which pops up a color picker is
used.

The buttons labeled as "your value" and "Demeter's value" can be used
to restore the value of the control used to set the parameter value.
"Demeter's value" is the system-wide default read from Demeter's
configuration files, while the other value is the user's own value
read from the user's ini file.

=head2 Applying and saving parameter values

To alter a parameter value for use within the current instance of a
Demeter-based application, click the "Apply" button.  This will set
the current parameter value in the Config object.  To alter a
paremeter value I<and> save it for future use, click the button which
says "Apply and save".  This will also write out the user's ini file.

If a parameter is flagged as only taking effect when the application
is restarted, the "Apply" button will be disabled.

=head1 DEPENDENCIES

Demeter's dependencies are in the F<Bundle/DemeterBundle.pm> file.

=head1 BUGS AND LIMITATIONS

Please report problems to Bruce Ravel (bravel AT bnl DOT gov)

Patches are welcome.

=head1 AUTHOR

Bruce Ravel (bravel AT bnl DOT gov)

L<http://bruceravel.github.com/demeter/>

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2013 Bruce Ravel (bravel AT bnl DOT gov). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
