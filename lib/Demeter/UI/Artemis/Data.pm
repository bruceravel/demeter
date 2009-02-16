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
  my $splitter = Wx::SplitterWindow->new($this, -1, wxDefaultPosition, wxDefaultSize, wxSP_3D);
  $hbox->Add($splitter, 0, wxGROW|wxALL, 0);

  my $leftpane = Wx::Panel->new($splitter, -1);
  my $left = Wx::BoxSizer->new( wxVERTICAL );

  ## -------- name
  my $namebox  = Wx::BoxSizer->new( wxHORIZONTAL );
  $left    -> Add($namebox, 0, wxGROW|wxTOP|wxBOTTOM, 5);
  $namebox -> Add(Wx::StaticText->new($leftpane, -1, "Name"), 0, wxLEFT|wxRIGHT|wxTOP, 5);
  $this->{name} = Wx::TextCtrl->new($leftpane, -1, q{}, wxDefaultPosition, wxDefaultSize,);
  $namebox -> Add($this->{name}, 1, wxGROW|wxLEFT|wxRIGHT|wxTOP, 2);

  ## -------- file name and record number
  my $filebox  = Wx::BoxSizer->new( wxHORIZONTAL );
  $left    -> Add($filebox, 0, wxGROW|wxALL, 0);
  $filebox -> Add(Wx::StaticText->new($leftpane, -1, "Data source: "), 0, wxALL, 5);
  $this->{datasource} = Wx::TextCtrl->new($leftpane, -1, q{}, wxDefaultPosition, wxDefaultSize, wxTE_READONLY);
  $filebox -> Add($this->{datasource}, 1, wxGROW|wxLEFT|wxRIGHT|wxTOP, 2);

  ## -------- title lines
  my $titlesbox      = Wx::StaticBox->new($leftpane, -1, 'Title lines', wxDefaultPosition, wxDefaultSize);
  my $titlesboxsizer = Wx::StaticBoxSizer->new( $titlesbox, wxHORIZONTAL );
  $this->{titles}      = Wx::TextCtrl->new($leftpane, -1, q{}, wxDefaultPosition, wxDefaultSize,
					  wxVSCROLL|wxHSCROLL|wxTE_MULTILINE|wxTE_READONLY|wxNO_BORDER);
  $titlesboxsizer -> Add($this->{titles}, 1, wxGROW|wxALL, 0);
  $left           -> Add($titlesboxsizer, 0, wxGROW|wxALL, 5);

  ## --------- toggles
  my $togglebox  = Wx::BoxSizer->new( wxHORIZONTAL );
  $left    -> Add($togglebox, 0, wxGROW|wxALL, 0);
  $this->{include}    = Wx::CheckBox->new($leftpane, -1, "Include in fit", wxDefaultPosition, wxDefaultSize);
  $this->{plot_after} = Wx::CheckBox->new($leftpane, -1, "Plot after fit", wxDefaultPosition, wxDefaultSize);
  $this->{fit_bkg}    = Wx::CheckBox->new($leftpane, -1, "Fit background", wxDefaultPosition, wxDefaultSize);
  $togglebox -> Add($this->{include},    1, wxALL, 5);
  $togglebox -> Add($this->{plot_after}, 1, wxALL, 5);
  $togglebox -> Add($this->{fit_bkg},    1, wxALL, 5);
  $this->{include}   -> SetValue(1);

  ## -------- Fourier transform parameters
  my $ftbox      = Wx::StaticBox->new($leftpane, -1, 'Fourier transform parameters', wxDefaultPosition, wxDefaultSize);
  my $ftboxsizer = Wx::StaticBoxSizer->new( $ftbox, wxVERTICAL );
  $left         -> Add($ftboxsizer, 0, wxALL, 5);

  my $gbs = Wx::GridBagSizer->new( 5, 10 );

  my $label     = Wx::StaticText->new($leftpane, -1, "kmin");
  $this->{kmin} = Wx::TextCtrl  ->new($leftpane, -1, $Demeter::UI::Artemis::demeter->co->default("fft", "kmin"),
				      wxDefaultPosition, [50,-1]);
  $gbs     -> Add($label,      Wx::GBPosition->new(0,1));
  $gbs     -> Add($this->{kmin}, Wx::GBPosition->new(0,2));

  $label        = Wx::StaticText->new($leftpane, -1, "kmax");
  $this->{kmax} = Wx::TextCtrl  ->new($leftpane, -1, $Demeter::UI::Artemis::demeter->co->default("fft", "kmax"),
				      wxDefaultPosition, [50,-1]);
  $gbs     -> Add($label,      Wx::GBPosition->new(0,3));
  $gbs     -> Add($this->{kmax}, Wx::GBPosition->new(0,4));

  $label      = Wx::StaticText->new($leftpane, -1, "dk");
  $this->{dk} = Wx::TextCtrl  ->new($leftpane, -1, $Demeter::UI::Artemis::demeter->co->default("fft", "dk"),
				      wxDefaultPosition, [50,-1]);
  $gbs     -> Add($label,      Wx::GBPosition->new(0,5));
  $gbs     -> Add($this->{dk}, Wx::GBPosition->new(0,6));

  $label        = Wx::StaticText->new($leftpane, -1, "rmin");
  $this->{rmin} = Wx::TextCtrl  ->new($leftpane, -1, $Demeter::UI::Artemis::demeter->co->default("bft", "rmin"),
				      wxDefaultPosition, [50,-1]);
  $gbs     -> Add($label,        Wx::GBPosition->new(1,1));
  $gbs     -> Add($this->{rmin}, Wx::GBPosition->new(1,2));

  $label        = Wx::StaticText->new($leftpane, -1, "rmax");
  $this->{rmax} = Wx::TextCtrl  ->new($leftpane, -1, $Demeter::UI::Artemis::demeter->co->default("bft", "rmax"),
				      wxDefaultPosition, [50,-1]);
  $gbs     -> Add($label,        Wx::GBPosition->new(1,3));
  $gbs     -> Add($this->{rmax}, Wx::GBPosition->new(1,4));

  $label      = Wx::StaticText->new($leftpane, -1, "dr");
  $this->{dr} = Wx::TextCtrl  ->new($leftpane, -1, $Demeter::UI::Artemis::demeter->co->default("bft", "dr"),
				    wxDefaultPosition, [50,-1]);
  $gbs     -> Add($label,      Wx::GBPosition->new(1,5));
  $gbs     -> Add($this->{dr}, Wx::GBPosition->new(1,6));


  $ftboxsizer -> Add($gbs, 1, wxGROW|wxALL, 5);

  my $windowsbox  = Wx::BoxSizer->new( wxHORIZONTAL );
  $ftboxsizer -> Add($windowsbox, 0, wxALL, 0);

  my $windows = [qw(hanning kaiser-bessel welch parzen sine)];
  $label     = Wx::StaticText->new($leftpane, -1, "k window");
  $this->{kwindow} = Wx::Choice  ->new($leftpane, -1, , wxDefaultPosition, wxDefaultSize, $windows);
  $windowsbox -> Add($label, 0, wxALL, 5);
  $windowsbox -> Add($this->{kwindow}, 0, wxALL, 2);

  $label     = Wx::StaticText->new($leftpane, -1, "R window");
  $this->{rwindow} = Wx::Choice  ->new($leftpane, -1, , wxDefaultPosition, wxDefaultSize, $windows);
  $windowsbox -> Add($label, 0, wxALL, 5);
  $windowsbox -> Add($this->{rwindow}, 0, wxALL, 2);

  ## -------- k-weights
  my $kwbox      = Wx::StaticBox->new($leftpane, -1, 'Fitting k weights', wxDefaultPosition, wxDefaultSize);
  my $kwboxsizer = Wx::StaticBoxSizer->new( $kwbox, wxHORIZONTAL );
  $left         -> Add($kwboxsizer, 1, wxGROW|wxALL, 5);

  $this->{k1}   = Wx::CheckBox->new($leftpane, -1, "1",     wxDefaultPosition, wxDefaultSize);
  $this->{k2}   = Wx::CheckBox->new($leftpane, -1, "2",     wxDefaultPosition, wxDefaultSize);
  $this->{k3}   = Wx::CheckBox->new($leftpane, -1, "3",     wxDefaultPosition, wxDefaultSize);
  $this->{karb} = Wx::CheckBox->new($leftpane, -1, "other", wxDefaultPosition, wxDefaultSize);
  $this->{karb_value} = Wx::TextCtrl->new($leftpane, -1, q{}, wxDefaultPosition, wxDefaultSize);
  $kwboxsizer -> Add($this->{k1}, 1, wxALL, 5);
  $kwboxsizer -> Add($this->{k2}, 1, wxALL, 5);
  $kwboxsizer -> Add($this->{k3}, 1, wxALL, 5);
  $kwboxsizer -> Add($this->{karb}, 0, wxALL, 5);
  $kwboxsizer -> Add($this->{karb_value}, 0, wxALL, 5);
  $this->{k1}->SetValue(1);
  $this->{k3}->SetValue(1);

  ## -------- epsilon and phase correction
  my $extrabox  = Wx::BoxSizer->new( wxHORIZONTAL );
  $left        -> Add($extrabox, 0, wxGROW|wxALL, 0);

  $extrabox -> Add(Wx::StaticText->new($leftpane, -1, "ε(k)"), 0, wxALL, 5);
  $this->{epsilon} = Wx::TextCtrl->new($leftpane, -1, 0, wxDefaultPosition, [50,-1]);
  $extrabox  -> Add($this->{epsilon}, 0, wxALL, 2);
  $extrabox  -> Add(Wx::StaticText->new($leftpane, -1, q{}), 1, wxALL, 5);
  $this->{pcplot}  = Wx::CheckBox->new($leftpane, -1, "Plot with phase correction", wxDefaultPosition, wxDefaultSize);
  $extrabox  -> Add($this->{pcplot}, 0, wxALL, 5);

  $leftpane -> SetSizerAndFit($left);


  my $rightpane = Wx::Panel->new($splitter, -1);
  my $right = Wx::BoxSizer->new( wxVERTICAL );

  $this->{pathlist} = Wx::Treebook->new( $rightpane, -1, wxDefaultPosition, wxDefaultSize, wxBK_LEFT );
  $right -> Add($this->{pathlist}, 1, wxGROW|wxALL, 5);

  my $page = Wx::Panel->new($this->{pathlist}, -1);
  my $hh = Wx::BoxSizer->new( wxHORIZONTAL );
  $page -> SetSizer($hh);

  $hh -> Add(Wx::StaticText -> new($page, -1, "Drag paths from the Feff interpretation\nlist and drop them in this space\nto add paths to this data set."),
	     1, wxGROW|wxALL, 5);
  $this->{pathlist}->AddPage($page, "Path list", 1);

  $rightpane -> SetSizerAndFit($right);


  $splitter -> SplitVertically($leftpane, $rightpane, 0);
  #$splitter -> SetSashSize(10);

  $this -> SetSizerAndFit( $hbox );
  return $this;
};

sub populate {
  my ($self, $data) = @_;
  $self->{name}->SetValue($data->name);
  $self->{datasource}->SetValue($data->prjrecord);
  #$self->{datasource}->ShowPosition($self->{datasource}->GetLastPosition);
  $self->{titles}->SetValue(join("\n", @{ $data->titles }));
  $self->{kmin}->SetValue($data->fft_kmin);
  $self->{kmax}->SetValue($data->fft_kmax);
  $self->{dk}->SetValue($data->fft_dk);
  $self->{rmin}->SetValue($data->bft_rmin);
  $self->{rmax}->SetValue($data->bft_rmax);
  $self->{dr}->SetValue($data->bft_dr);
  return $self;
}


1;
