package  Demeter::UI::Artemis::Data;

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

use Wx qw( :everything);
use base qw(Wx::Frame);

sub new {
  my ($class, $parent) = @_;

  my $this = $class->SUPER::new($parent, -1, "Artemis: Data controls",
				wxDefaultPosition, wxDefaultSize,
				wxCAPTION|wxMINIMIZE_BOX|wxSYSTEM_MENU|wxRESIZE_BORDER);
  my $statusbar = $this->CreateStatusBar;
  $statusbar -> SetStatusText(q{});
  my $hbox  = Wx::BoxSizer->new( wxHORIZONTAL );

  my $left = Wx::BoxSizer->new( wxVERTICAL );
  $hbox -> Add($left, 3, wxGROW|wxALL, 0);

  ## -------- name
  my $namebox  = Wx::BoxSizer->new( wxHORIZONTAL );
  $left    -> Add($namebox, 0, wxGROW|wxTOP|wxBOTTOM, 5);
  $namebox -> Add(Wx::StaticText->new($this, -1, "Name"), 0, wxLEFT|wxRIGHT, 5);
  my $name = Wx::TextCtrl->new($this, -1, q{}, wxDefaultPosition, wxDefaultSize,);
  $namebox -> Add($name, 1, wxGROW|wxLEFT|wxRIGHT|wxTOP, 2);

  ## -------- file name and record number
  my $filebox  = Wx::BoxSizer->new( wxHORIZONTAL );
  $left    -> Add($filebox, 0, wxGROW|wxALL, 0);
  $filebox -> Add(Wx::StaticText->new($this, -1, "Data source: "), 0, wxALL, 5);
  $this->{datasource} = Wx::StaticText->new($this, -1, q{});
  $filebox -> Add($this->{datasource}, 0, wxGROW|wxLEFT|wxRIGHT, 5);

  ## -------- title lines
  my $titlesbox      = Wx::StaticBox->new($this, -1, 'Title lines', wxDefaultPosition, wxDefaultSize);
  my $titlesboxsizer = Wx::StaticBoxSizer->new( $titlesbox, wxHORIZONTAL );
  $this->{titles}      = Wx::TextCtrl->new($this, -1, q{}, wxDefaultPosition, wxDefaultSize,
					  wxVSCROLL|wxHSCROLL|wxTE_MULTILINE|wxTE_READONLY|wxNO_BORDER);
  $titlesboxsizer -> Add($this->{titles}, 1, wxGROW|wxALL, 0);
  $left           -> Add($titlesboxsizer, 0, wxGROW|wxALL, 5);

  ## --------- toggles
  my $togglebox  = Wx::BoxSizer->new( wxHORIZONTAL );
  $left    -> Add($togglebox, 0, wxGROW|wxALL, 0);
  my $include    = Wx::CheckBox->new($this, -1, "Include in fit", wxDefaultPosition, wxDefaultSize);
  my $plot_after = Wx::CheckBox->new($this, -1, "Plot after fit", wxDefaultPosition, wxDefaultSize);
  my $fit_bkg    = Wx::CheckBox->new($this, -1, "Fit background", wxDefaultPosition, wxDefaultSize);
  $togglebox -> Add($include,    1, wxALL, 5);
  $togglebox -> Add($plot_after, 1, wxALL, 5);
  $togglebox -> Add($fit_bkg,    1, wxALL, 5);
  $include   -> SetValue(1);

  ## -------- Fourier transform parameters
  my $ftbox      = Wx::StaticBox->new($this, -1, 'Fourier transform parameters', wxDefaultPosition, wxDefaultSize);
  my $ftboxsizer = Wx::StaticBoxSizer->new( $ftbox, wxVERTICAL );
  $left         -> Add($ftboxsizer, 0, wxALL, 5);

  my $gbs = Wx::GridBagSizer->new( 5, 10 );

  my $label     = Wx::StaticText->new($this, -1, "kmin");
  $this->{kmin} = Wx::TextCtrl  ->new($this, -1, $Demeter::UI::Artemis::demeter->co->default("fft", "kmin"),
				      wxDefaultPosition, [50,-1]);
  $gbs     -> Add($label,      Wx::GBPosition->new(0,1));
  $gbs     -> Add($this->{kmin}, Wx::GBPosition->new(0,2));

  $label        = Wx::StaticText->new($this, -1, "kmax");
  $this->{kmax} = Wx::TextCtrl  ->new($this, -1, $Demeter::UI::Artemis::demeter->co->default("fft", "kmax"),
				      wxDefaultPosition, [50,-1]);
  $gbs     -> Add($label,      Wx::GBPosition->new(0,3));
  $gbs     -> Add($this->{kmax}, Wx::GBPosition->new(0,4));

  $label      = Wx::StaticText->new($this, -1, "dk");
  $this->{dk} = Wx::TextCtrl  ->new($this, -1, $Demeter::UI::Artemis::demeter->co->default("fft", "dk"),
				      wxDefaultPosition, [50,-1]);
  $gbs     -> Add($label,      Wx::GBPosition->new(0,5));
  $gbs     -> Add($this->{dk}, Wx::GBPosition->new(0,6));

  $label        = Wx::StaticText->new($this, -1, "rmin");
  $this->{rmin} = Wx::TextCtrl  ->new($this, -1, $Demeter::UI::Artemis::demeter->co->default("bft", "rmin"),
				      wxDefaultPosition, [50,-1]);
  $gbs     -> Add($label,        Wx::GBPosition->new(1,1));
  $gbs     -> Add($this->{rmin}, Wx::GBPosition->new(1,2));

  $label        = Wx::StaticText->new($this, -1, "rmax");
  $this->{rmax} = Wx::TextCtrl  ->new($this, -1, $Demeter::UI::Artemis::demeter->co->default("bft", "rmax"),
				      wxDefaultPosition, [50,-1]);
  $gbs     -> Add($label,        Wx::GBPosition->new(1,3));
  $gbs     -> Add($this->{rmax}, Wx::GBPosition->new(1,4));

  $label      = Wx::StaticText->new($this, -1, "dr");
  $this->{dr} = Wx::TextCtrl  ->new($this, -1, $Demeter::UI::Artemis::demeter->co->default("bft", "dr"),
				    wxDefaultPosition, [50,-1]);
  $gbs     -> Add($label,      Wx::GBPosition->new(1,5));
  $gbs     -> Add($this->{dr}, Wx::GBPosition->new(1,6));


  $ftboxsizer -> Add($gbs, 1, wxGROW|wxALL, 5);

  my $windowsbox  = Wx::BoxSizer->new( wxHORIZONTAL );
  $ftboxsizer -> Add($windowsbox, 0, wxALL, 0);

  my $windows = [qw(hanning kaiser-bessel welch parzen sine)];
  $label     = Wx::StaticText->new($this, -1, "k window");
  $this->{kwindow} = Wx::Choice  ->new($this, -1, , wxDefaultPosition, wxDefaultSize, $windows);
  $windowsbox -> Add($label, 0, wxALL, 5);
  $windowsbox -> Add($this->{kwindow}, 0, wxALL, 2);

  $label     = Wx::StaticText->new($this, -1, "R window");
  $this->{rwindow} = Wx::Choice  ->new($this, -1, , wxDefaultPosition, wxDefaultSize, $windows);
  $windowsbox -> Add($label, 0, wxALL, 5);
  $windowsbox -> Add($this->{rwindow}, 0, wxALL, 2);

  ## -------- k-weights
  my $kwbox      = Wx::StaticBox->new($this, -1, 'Fitting k weights', wxDefaultPosition, wxDefaultSize);
  my $kwboxsizer = Wx::StaticBoxSizer->new( $kwbox, wxHORIZONTAL );
  $left         -> Add($kwboxsizer, 1, wxGROW|wxALL, 5);

  my $k1   = Wx::CheckBox->new($this, -1, "1",     wxDefaultPosition, wxDefaultSize);
  my $k2   = Wx::CheckBox->new($this, -1, "2",     wxDefaultPosition, wxDefaultSize);
  my $k3   = Wx::CheckBox->new($this, -1, "3",     wxDefaultPosition, wxDefaultSize);
  my $karb = Wx::CheckBox->new($this, -1, "other", wxDefaultPosition, wxDefaultSize);
  my $karb_value = Wx::TextCtrl->new($this, -1, q{}, wxDefaultPosition, wxDefaultSize);
  $kwboxsizer -> Add($k1, 1, wxALL, 5);
  $kwboxsizer -> Add($k2, 1, wxALL, 5);
  $kwboxsizer -> Add($k3, 1, wxALL, 5);
  $kwboxsizer -> Add($karb, 0, wxALL, 5);
  $kwboxsizer -> Add($karb_value, 0, wxALL, 5);
  $k1->SetValue(1);
  $k3->SetValue(1);

  my $right = Wx::BoxSizer->new( wxVERTICAL );
  $hbox -> Add($right, 1, wxGROW|wxALL, 0);

  $right->Add(Wx::StaticText->new($this, -1, "Paths!"), 0, wxALL, 5);

  $this -> SetSizerAndFit( $hbox );
  return $this;
};

1;
