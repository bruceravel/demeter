package  Demeter::UI::Artemis::Path;

=for Copyright
 .
 Copyright (c) 2006-2009 Bruce Ravel (bravel AT bnl DOT gov).
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

use Wx qw( :everything );
use base qw(Wx::Panel);

sub new {
  my ($class, $parent, $pathobject) = @_;
  my $this = $class->SUPER::new($parent, -1, wxDefaultPosition, [390,-1]);

  my $vbox = Wx::BoxSizer->new( wxVERTICAL );
  $this -> SetSizer($vbox);

  ## -------- identifier string
  $this->{idlabel} = Wx::StaticText -> new($this, -1, "Feff name : Path name");
  $this->{idlabel}->SetFont( Wx::Font->new( 10, wxDEFAULT, wxNORMAL, wxBOLD, 0, "" ) );
  $vbox -> Add($this->{idlabel}, 0, wxGROW|wxALL, 5);

  ## -------- show feff button and various check buttons
  my $hbox = Wx::BoxSizer->new( wxHORIZONTAL );
  $vbox -> Add($hbox, 0, wxGROW|wxALL, 0);

  my $left  = Wx::BoxSizer->new( wxVERTICAL );
  $hbox -> Add($left,  0, wxGROW|wxALL, 5);
  $this->{showfeff} = Wx::ToggleButton->new($this, -1, "Show feff");
  $left -> Add($this->{showfeff}, 0, wxALL, 0);

  my $right = Wx::BoxSizer->new( wxVERTICAL );
  $hbox -> Add($right, 0, wxGROW|wxALL, 5);
  $this->{include}      = Wx::CheckBox->new($this, -1, "Include this path in the fit");
  $this->{plotafter}    = Wx::CheckBox->new($this, -1, "Plot this path after fit");
  $this->{useasdefault} = Wx::CheckBox->new($this, -1, "Use this path as the default after the fit");
  $right -> Add($this->{include},      0, wxALL, 0);
  $right -> Add($this->{plotafter},    0, wxTOP|wxBOTTOM, 3);
  $right -> Add($this->{useasdefault}, 0, wxALL, 0);


  ## -------- geometry
  $this->{geombox}  = Wx::StaticBox->new($this, -1, 'Geometry ', wxDefaultPosition, wxDefaultSize);
  my $geomboxsizer  = Wx::StaticBoxSizer->new( $this->{geombox}, wxHORIZONTAL );
  $this->{geometry} = Wx::TextCtrl->new($this, -1, q{}, wxDefaultPosition, wxDefaultSize,
					wxVSCROLL|wxHSCROLL|wxTE_MULTILINE|wxTE_READONLY|wxNO_BORDER);
  $this->{geometry} -> SetFont( Wx::Font->new( 9, wxTELETYPE, wxNORMAL, wxNORMAL, 0, "" ) );
  $geomboxsizer -> Add($this->{geometry}, 1, wxGROW|wxALL, 0);
  $vbox         -> Add($geomboxsizer, 1, wxGROW|wxALL, 0);

  ## -------- path parameters
  my $gbs = Wx::GridBagSizer->new( 3, 10 );

  my %labels = (label  => 'Label',
		degen  => 'N',
		s02    => 'S02',
		e0     => 'ΔE0',
		dr     => 'ΔR',
		ss     => 'σ²',
		ei     => 'Ei',
		third  => '3rd',
		fourth => '4th',
	       );
  my $i = 0;
  foreach my $k (qw(label degen s02 e0 dr ss ei third fourth)) {
    my $label        = Wx::StaticText->new($this, -1, $labels{$k}, wxDefaultPosition, wxDefaultSize, wxALIGN_RIGHT);
    my $w = ($k eq 'degen') ? 50 : 290;
    $this->{"pp_$k"} = Wx::TextCtrl  ->new($this, -1, q{}, wxDefaultPosition, [$w,-1]);
    $gbs     -> Add($label,           Wx::GBPosition->new($i,1));
    $gbs     -> Add($this->{"pp_$k"}, Wx::GBPosition->new($i,2));
    ++$i;
  };
  $vbox -> Add($gbs, 2, wxGROW|wxALL, 10);

  $this -> populate($parent, $pathobject);

  return $this;
};

sub populate {
  my ($this, $parent, $pathobject) = @_;

  my $label = "Path: " . $pathobject->parent->name . " - " . $pathobject->name;
  $this->{idlabel} -> SetLabel($label);

  $this->{geombox} -> SetLabel(" " . $pathobject->sp->intrplist . " ");

  my $geometry = $pathobject->sp->pathsdat;
  $geometry =~ s{.*\n}{};
  #$geometry =~ s{\d+\s* }{};
  #$geometry =~ s{index, }{};
  $this->{geometry} -> SetValue($geometry);

  $this->{include} -> SetValue(1);

  $this->{pp_label} -> SetValue($pathobject->sp->labelline);
  $this->{pp_degen} -> SetValue($pathobject->degen);
};


1;
