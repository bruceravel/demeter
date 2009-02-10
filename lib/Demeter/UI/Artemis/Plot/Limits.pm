package  Demeter::UI::Artemis::Plot::Limits;


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

use Wx qw( :everything );
use base qw(Wx::Panel);

my $parts = ['Magnitude', 'Real part', 'Imaginary part'];

sub new {
  my ($class, $parent) = @_;
  my $this = $class->SUPER::new($parent, -1, wxDefaultPosition, wxDefaultSize);

  my $szr = Wx::BoxSizer->new( wxVERTICAL );

  ## -------- plotting part for chi(R)
  my $hh = Wx::BoxSizer->new( wxHORIZONTAL );
  $szr  -> Add($hh, 0, wxGROW|wxALL, 5);
  my $label  = Wx::StaticText->new($this, -1, "Plot χ(R) as: ");
  $po{rpart} = Wx::Choice->new($this, -1, wxDefaultPosition, wxDefaultSize, $parts);
  my $which = 0;
  ($which = 1) if ($Demeter::UI::Artemis::demeter->co->default("plot", "r_pl") eq 'r');
  ($which = 2) if ($Demeter::UI::Artemis::demeter->co->default("plot", "r_pl") eq 'i');
  $po{rpart} -> Select($which);
  $hh -> Add($label, 0, wxLEFT|wxRIGHT, 5);
  $hh -> Add($po{rpart}, 1, wxRIGHT, 5);

  ## -------- plotting part for chi(q)
  $hh   = Wx::BoxSizer->new( wxHORIZONTAL );
  $szr -> Add($hh, 0, wxGROW|wxALL, 5);
  my $label  = Wx::StaticText->new($this, -1, "Plot χ(q) as: ");
  $po{qpart} = Wx::Choice->new($this, -1, wxDefaultPosition, wxDefaultSize, $parts);
  my $which = 1;
  ($which = 0) if ($Demeter::UI::Artemis::demeter->co->default("plot", "q_pl") eq 'm');
  ($which = 2) if ($Demeter::UI::Artemis::demeter->co->default("plot", "q_pl") eq 'i');
  $po{qpart} -> Select($which);
  $hh -> Add($label, 0, wxLEFT|wxRIGHT, 5);
  $hh -> Add($po{qpart}, 1, wxRIGHT, 5);

  ## -------- toggles for win, bkg, res
  $po{window} = Wx::CheckBox->new($this, -1, "Plot window");
  $szr -> Add($po{window}, 0, wxGROW|wxALL, 2);
  $po{background} = Wx::CheckBox->new($this, -1, "Plot background");
  $szr -> Add($po{background}, 0, wxGROW|wxALL, 2);
  $po{residual} = Wx::CheckBox->new($this, -1, "Plot residual");
  $szr -> Add($po{residual}, 0, wxGROW|wxALL, 2);

  ## -------- limits in k, R, and q
  my $gbs  =  Wx::GridBagSizer->new( 10,5 );
  $szr -> Add($gbs, 0, wxGROW|wxTOP, 15);
  my %po;

  $label    = Wx::StaticText->new($this, -1, "kmin");
  $po{kmin} = Wx::TextCtrl  ->new($this, -1, $Demeter::UI::Artemis::demeter->co->default("plot", "kmin"));
  $gbs     -> Add($label,    Wx::GBPosition->new(0,1));
  $gbs     -> Add($po{kmin}, Wx::GBPosition->new(0,2));
  $label    = Wx::StaticText->new($this, -1, "kmax");
  $po{kmax} = Wx::TextCtrl  ->new($this, -1, $Demeter::UI::Artemis::demeter->co->default("plot", "kmax"));
  $gbs     -> Add($label,    Wx::GBPosition->new(0,3));
  $gbs     -> Add($po{kmax}, Wx::GBPosition->new(0,4));

  $label    = Wx::StaticText->new($this, -1, "rmin");
  $po{rmin} = Wx::TextCtrl  ->new($this, -1, $Demeter::UI::Artemis::demeter->co->default("plot", "rmin"));
  $gbs     -> Add($label,    Wx::GBPosition->new(1,1));
  $gbs     -> Add($po{rmin}, Wx::GBPosition->new(1,2));
  $label    = Wx::StaticText->new($this, -1, "rmax");
  $po{rmax} = Wx::TextCtrl  ->new($this, -1, $Demeter::UI::Artemis::demeter->co->default("plot", "rmax"));
  $gbs     -> Add($label,    Wx::GBPosition->new(1,3));
  $gbs     -> Add($po{rmax}, Wx::GBPosition->new(1,4));

  $label    = Wx::StaticText->new($this, -1, "qmin");
  $po{qmin} = Wx::TextCtrl  ->new($this, -1, $Demeter::UI::Artemis::demeter->co->default("plot", "qmin"));
  $gbs     -> Add($label,    Wx::GBPosition->new(2,1));
  $gbs     -> Add($po{qmin}, Wx::GBPosition->new(2,2));
  $label    = Wx::StaticText->new($this, -1, "qmax");
  $po{qmax} = Wx::TextCtrl  ->new($this, -1, $Demeter::UI::Artemis::demeter->co->default("plot", "qmax"));
  $gbs     -> Add($label,    Wx::GBPosition->new(2,3));
  $gbs     -> Add($po{qmax}, Wx::GBPosition->new(2,4));


  $this -> SetSizer($szr);
  return $this;
};

1;
