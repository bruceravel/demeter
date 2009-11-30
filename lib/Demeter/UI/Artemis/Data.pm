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
use Wx::Event qw(EVT_MENU EVT_CLOSE EVT_TOOL_ENTER EVT_CHECKBOX EVT_CHOICE
		 EVT_BUTTON EVT_ENTER_WINDOW EVT_LEAVE_WINDOW
		 EVT_HYPERLINK);
use Wx::DND;
use Wx::Perl::TextValidator;

use Wx::Perl::Carp;

use Demeter::UI::Artemis::Project;
use Demeter::UI::Artemis::Data::AddParameter;
use Demeter::UI::Artemis::Data::Histogram;
use Demeter::UI::Artemis::Data::Quickfs;
use Demeter::UI::Artemis::ShowText;
use Demeter::UI::Wx::CheckListBook;
use Demeter::UI::Wx::SpecialCharacters qw(:all);

use Cwd;
use List::MoreUtils qw(firstidx);

my $windows = [qw(hanning kaiser-bessel welch parzen sine)];
my $demeter = $Demeter::UI::Artemis::demeter;

use Regexp::List;
use Regexp::Optimizer;
my $reopt  = Regexp::List->new;
use Regexp::Common;
use Readonly;
Readonly my $NUMBER		=> $RE{num}{real};

Readonly my $DATA_RENAME	=> Wx::NewId();
Readonly my $DATA_DIFF		=> Wx::NewId();
Readonly my $DATA_TRANSFER	=> Wx::NewId();
Readonly my $DATA_VPATH		=> Wx::NewId();
Readonly my $DATA_BALANCE	=> Wx::NewId();
Readonly my $DATA_DEGEN_N	=> Wx::NewId();
Readonly my $DATA_DEGEN_1	=> Wx::NewId();
Readonly my $DATA_DISCARD	=> Wx::NewId();
Readonly my $DATA_REPLACE	=> Wx::NewId();
Readonly my $DATA_KMAXSUGEST	=> Wx::NewId();
Readonly my $DATA_EPSK		=> Wx::NewId();
Readonly my $DATA_NIDP		=> Wx::NewId();
Readonly my $DATA_SHOW		=> Wx::NewId();
Readonly my $DATA_YAML		=> Wx::NewId();

Readonly my $PATH_FSPATH	=> Wx::NewId();
Readonly my $PATH_RENAME	=> Wx::NewId();
Readonly my $PATH_SHOW		=> Wx::NewId();
Readonly my $PATH_ADD		=> Wx::NewId();
Readonly my $PATH_CLONE		=> Wx::NewId();
Readonly my $PATH_YAML		=> Wx::NewId();
Readonly my $PATH_TYPE		=> Wx::NewId();
Readonly my $PATH_HISTO		=> Wx::NewId();

Readonly my $PATH_EXPORT_FEFF	=> Wx::NewId();
Readonly my $PATH_EXPORT_DATA	=> Wx::NewId();
Readonly my $PATH_EXPORT_EACH	=> Wx::NewId();
Readonly my $PATH_EXPORT_MARKED	=> Wx::NewId();

Readonly my $PATH_SAVE_K	=> Wx::NewId();
Readonly my $PATH_SAVE_R	=> Wx::NewId();
Readonly my $PATH_SAVE_Q	=> Wx::NewId();

Readonly my $PATH_EXP_LABEL     => Wx::NewId();
Readonly my $PATH_EXP_N         => Wx::NewId();
Readonly my $PATH_EXP_S02       => Wx::NewId();
Readonly my $PATH_EXP_E0        => Wx::NewId();
Readonly my $PATH_EXP_DELR      => Wx::NewId();
Readonly my $PATH_EXP_SIGMA2    => Wx::NewId();
Readonly my $PATH_EXP_EI        => Wx::NewId();
Readonly my $PATH_EXP_THIRD     => Wx::NewId();
Readonly my $PATH_EXP_FOURTH    => Wx::NewId();

Readonly my $MARK_ALL		=> Wx::NewId();
Readonly my $MARK_NONE		=> Wx::NewId();
Readonly my $MARK_INVERT	=> Wx::NewId();
Readonly my $MARK_REGEXP	=> Wx::NewId();
Readonly my $MARK_SS		=> Wx::NewId();
Readonly my $MARK_MS		=> Wx::NewId();
Readonly my $MARK_HIGH		=> Wx::NewId();
Readonly my $MARK_MID		=> Wx::NewId();
Readonly my $MARK_LOW		=> Wx::NewId();
Readonly my $MARK_RBELOW	=> Wx::NewId();
Readonly my $MARK_RABOVE	=> Wx::NewId();
Readonly my $MARK_BEFORE	=> Wx::NewId();
Readonly my $MARK_AFTER  	=> Wx::NewId();
Readonly my $MARK_INC		=> Wx::NewId();
Readonly my $MARK_EXC		=> Wx::NewId();

Readonly my $ACTION_INCLUDE     => Wx::NewId();
Readonly my $ACTION_EXCLUDE     => Wx::NewId();
Readonly my $ACTION_DISCARD     => Wx::NewId();
Readonly my $ACTION_VPATH       => Wx::NewId();
Readonly my $ACTION_TRANSFER    => Wx::NewId();

Readonly my $INCLUDE_ALL	=> Wx::NewId();
Readonly my $EXCLUDE_ALL	=> Wx::NewId();
Readonly my $INCLUDE_INVERT	=> Wx::NewId();
Readonly my $INCLUDE_MARKED	=> Wx::NewId();
Readonly my $EXCLUDE_MARKED	=> Wx::NewId();
Readonly my $EXCLUDE_AFTER	=> Wx::NewId();
Readonly my $INCLUDE_SS     	=> Wx::NewId();
Readonly my $INCLUDE_HIGH	=> Wx::NewId();
Readonly my $INCLUDE_R  	=> Wx::NewId();

Readonly my $DISCARD_THIS	=> Wx::NewId();
Readonly my $DISCARD_ALL	=> Wx::NewId();
Readonly my $DISCARD_MARKED	=> Wx::NewId();
Readonly my $DISCARD_UNMARKED	=> Wx::NewId();
Readonly my $DISCARD_EXCLUDED	=> Wx::NewId();
Readonly my $DISCARD_AFTER	=> Wx::NewId();
Readonly my $DISCARD_MS	        => Wx::NewId();
Readonly my $DISCARD_LOW	=> Wx::NewId();
Readonly my $DISCARD_R  	=> Wx::NewId();


sub new {
  my ($class, $parent, $nset) = @_;

  my $this = $class->SUPER::new($parent, -1, "Artemis: Data controls",
				wxDefaultPosition, [810,520],
				wxCAPTION|wxMINIMIZE_BOX|wxCLOSE_BOX|wxSYSTEM_MENU); #|wxRESIZE_BORDER
  $this ->{PARENT} = $parent;
  $this->make_menubar;
  $this->SetMenuBar( $this->{menubar} );
  EVT_MENU($this, -1, sub{OnMenuClick(@_)} );
  EVT_CLOSE($this, \&on_close);

  $this->{statusbar} = $this->CreateStatusBar;
  $this->{statusbar} -> SetStatusText(q{});
  #$this->{statusbar}->SetForegroundColour(Wx::Colour->new("#00ff00")); ??????
  my $hbox  = Wx::BoxSizer->new( wxHORIZONTAL );
  #my $splitter = Wx::SplitterWindow->new($this, -1, wxDefaultPosition, [900,-1], wxSP_3D);
  #$hbox->Add($splitter, 1, wxGROW|wxALL, 1);

  my $leftpane = Wx::Panel->new($this, -1, wxDefaultPosition, wxDefaultSize);
  my $left = Wx::BoxSizer->new( wxVERTICAL );
  $hbox->Add($leftpane, 0, wxGROW|wxALL, 0);

  #$left -> Add(Wx::StaticLine->new($this, -1, wxDefaultPosition, [-1, -1], wxLI_HORIZONTAL), 0, wxGROW|wxALL, 5);

  ## -------- name
  my $namebox  = Wx::BoxSizer->new( wxHORIZONTAL );
  $left    -> Add($namebox, 0, wxGROW|wxTOP|wxBOTTOM, 5);
  #$namebox -> Add(Wx::StaticText->new($leftpane, -1, "Name"), 0, wxLEFT|wxRIGHT|wxTOP, 5);

  $this->{plotgrab} = Wx::BitmapButton->new($leftpane, -1, Demeter::UI::Artemis::icon('plotgrab'));
  $namebox -> Add($this->{plotgrab}, 0, wxLEFT|wxRIGHT|wxTOP, 3);
  $this->{name} = Wx::StaticText->new($leftpane, -1, q{}, wxDefaultPosition, wxDefaultSize, wxRAISED_BORDER );
  $this->{name}->SetFont( Wx::Font->new( 12, wxDEFAULT, wxNORMAL, wxBOLD, 0, "" ) );
  $namebox -> Add($this->{name}, 1, wxLEFT|wxRIGHT|wxTOP, 5);
  $namebox -> Add(Wx::StaticText->new($leftpane, -1, "CV"), 0, wxLEFT|wxRIGHT|wxTOP, 5);
  $this->{cv} = Wx::TextCtrl->new($leftpane, -1, $nset, wxDefaultPosition, [60,-1],);
  $namebox -> Add($this->{cv}, 0, wxLEFT|wxRIGHT|wxTOP, 3);
  EVT_BUTTON($this, $this->{plotgrab}, sub{transfer(@_)});

  $this->mouseover("plotgrab", "Transfer this data set to the plotting list.");
  $this->mouseover("cv",       "The characteristic value for this data set, which is used in certain advanced modeling features.  (The CV must be a number.)");

  ## -------- file name and record number
  my $filebox  = Wx::StaticBox->new($leftpane, -1, 'Data source ', wxDefaultPosition, [-1,-1]);
  my $fileboxsizer = Wx::StaticBoxSizer->new( $filebox, wxHORIZONTAL );
  $left    -> Add($fileboxsizer, 0, wxGROW|wxALL, 5);
  $this->{datasource} = Wx::TextCtrl->new($leftpane, -1, q{}, wxDefaultPosition, wxDefaultSize, wxTE_READONLY);
  $fileboxsizer -> Add($this->{datasource}, 1, wxGROW|wxLEFT|wxRIGHT|wxTOP, 0);
  ##$this->{datasource} -> SetInsertionPointEnd;

  ## -------- single data set plot buttons
  my $buttonbox  = Wx::StaticBox->new($leftpane, -1, 'Plot this data set as ', wxDefaultPosition, [-1,-1]);
  my $buttonboxsizer = Wx::StaticBoxSizer->new( $buttonbox, wxHORIZONTAL );
  $left -> Add($buttonboxsizer, 0, wxGROW|wxALL, 5);
  $this->{plot_rmr}  = Wx::Button->new($leftpane, -1, "R&mr",  wxDefaultPosition, [70,-1]);
  $this->{plot_k123} = Wx::Button->new($leftpane, -1, "&k123", wxDefaultPosition, [70,-1]);
  $this->{plot_r123} = Wx::Button->new($leftpane, -1, "&R123", wxDefaultPosition, [70,-1]);
  $this->{plot_kq}   = Wx::Button->new($leftpane, -1, "k&q",   wxDefaultPosition, [70,-1]);
  foreach my $b (qw(plot_k123 plot_r123 plot_rmr plot_kq)) {
    $buttonboxsizer -> Add($this->{$b}, 1, wxGROW|wxALL, 2);
    $this->{$b} -> SetForegroundColour(Wx::Colour->new("#000000"));
    $this->{$b} -> SetBackgroundColour(Wx::Colour->new($Demeter::UI::Artemis::demeter->co->default("happiness", "average_color")));
    $this->{$b} -> SetFont(Wx::Font->new( 10, wxDEFAULT, wxNORMAL, wxNORMAL, 0, "" ) );
  };
  EVT_BUTTON($this, $this->{plot_rmr},  sub{plot(@_, 'rmr')});
  EVT_BUTTON($this, $this->{plot_k123}, sub{plot(@_, 'k123')});
  EVT_BUTTON($this, $this->{plot_r123}, sub{plot(@_, 'r123')});
  EVT_BUTTON($this, $this->{plot_kq},   sub{plot(@_, 'kqfit')});

  $this->mouseover("plot_rmr",  "Plot this data set as |$CHI(R)| and Re[$CHI(R)].");
  $this->mouseover("plot_k123", "Plot this data set as $CHI(k) with all three k-weights and scaled to the same size.");
  $this->mouseover("plot_r123", "Plot this data set as $CHI(R) with all three k-weights and scaled to the same size.");
  $this->mouseover("plot_kq",   "Plot this data set as both $CHI(k) and Re[$CHI(q)].");


  ## -------- title lines
  my $titlesbox      = Wx::StaticBox->new($leftpane, -1, 'Title lines ', wxDefaultPosition, wxDefaultSize);
  my $titlesboxsizer = Wx::StaticBoxSizer->new( $titlesbox, wxHORIZONTAL );
  $this->{titles}      = Wx::TextCtrl->new($leftpane, -1, q{}, wxDefaultPosition, [300,-1],
					   wxVSCROLL|wxHSCROLL|wxTE_MULTILINE|wxTE_READONLY|wxNO_BORDER);
  $titlesboxsizer -> Add($this->{titles}, 1, wxALL|wxGROW, 0);
  $left           -> Add($titlesboxsizer, 1, wxALL|wxGROW, 5);
  $this->mouseover("titles", "These lines will be written to output files.  Use them to describe this data set.");


  ## -------- Fourier transform parameters
  my $ftbox      = Wx::StaticBox->new($leftpane, -1, 'Fourier transform parameters ', wxDefaultPosition, wxDefaultSize);
  my $ftboxsizer = Wx::StaticBoxSizer->new( $ftbox, wxVERTICAL );
  $left         -> Add($ftboxsizer, 0, wxGROW|wxALL|wxALIGN_CENTER_HORIZONTAL, 5);

  my $gbs = Wx::GridBagSizer->new( 5, 10 );

  my $label     = Wx::StaticText->new($leftpane, -1, "kmin");
  $this->{kmin} = Wx::TextCtrl  ->new($leftpane, -1, $demeter->co->default("fft", "kmin"),
				      wxDefaultPosition, [50,-1]);
  $gbs     -> Add($label,      Wx::GBPosition->new(0,1));
  $gbs     -> Add($this->{kmin}, Wx::GBPosition->new(0,2));

  $label        = Wx::StaticText->new($leftpane, -1, "kmax");
  $this->{kmax} = Wx::TextCtrl  ->new($leftpane, -1, $demeter->co->default("fft", "kmax"),
				      wxDefaultPosition, [50,-1]);
  $gbs     -> Add($label,      Wx::GBPosition->new(0,3));
  $gbs     -> Add($this->{kmax}, Wx::GBPosition->new(0,4));

  $label      = Wx::StaticText->new($leftpane, -1, "dk");
  $this->{dk} = Wx::TextCtrl  ->new($leftpane, -1, $demeter->co->default("fft", "dk"),
				      wxDefaultPosition, [50,-1]);
  $gbs     -> Add($label,      Wx::GBPosition->new(0,5));
  $gbs     -> Add($this->{dk}, Wx::GBPosition->new(0,6));

  $label        = Wx::StaticText->new($leftpane, -1, "rmin");
  $this->{rmin} = Wx::TextCtrl  ->new($leftpane, -1, $demeter->co->default("bft", "rmin"),
				      wxDefaultPosition, [50,-1]);
  $gbs     -> Add($label,        Wx::GBPosition->new(1,1));
  $gbs     -> Add($this->{rmin}, Wx::GBPosition->new(1,2));

  $label        = Wx::StaticText->new($leftpane, -1, "rmax");
  $this->{rmax} = Wx::TextCtrl  ->new($leftpane, -1, $demeter->co->default("bft", "rmax"),
				      wxDefaultPosition, [50,-1]);
  $gbs     -> Add($label,        Wx::GBPosition->new(1,3));
  $gbs     -> Add($this->{rmax}, Wx::GBPosition->new(1,4));

  $label      = Wx::StaticText->new($leftpane, -1, "dr");
  $this->{dr} = Wx::TextCtrl  ->new($leftpane, -1, $demeter->co->default("bft", "dr"),
				    wxDefaultPosition, [50,-1]);
  $gbs     -> Add($label,      Wx::GBPosition->new(1,5));
  $gbs     -> Add($this->{dr}, Wx::GBPosition->new(1,6));

  $this->{cv}   -> SetValidator( Wx::Perl::TextValidator->new( qr([0-9.\-]) ) );
  $this->{kmin} -> SetValidator( Wx::Perl::TextValidator->new( qr([0-9.]) ) );
  $this->{kmax} -> SetValidator( Wx::Perl::TextValidator->new( qr([0-9.]) ) );
  $this->{dk}   -> SetValidator( Wx::Perl::TextValidator->new( qr([0-9.]) ) );
  $this->{rmin} -> SetValidator( Wx::Perl::TextValidator->new( qr([0-9.]) ) );
  $this->{rmax} -> SetValidator( Wx::Perl::TextValidator->new( qr([0-9.]) ) );
  $this->{dr}   -> SetValidator( Wx::Perl::TextValidator->new( qr([0-9.]) ) );

  $this->mouseover("kmin", "The lower bound in k-space for the Fourier transform and fit.");
  $this->mouseover("kmax", "The upper bound in k-space for the Fourier transform and fit.");
  $this->mouseover("dk",   "The width of the window sill in k-space for the Fourier transform.");
  $this->mouseover("rmin", "The lower bound in R-space for the fit and the backwards Fourier transform.");
  $this->mouseover("rmax", "The upper bound in R-space for the fit and the backwards Fourier transform.");
  $this->mouseover("dr",   "The width of the window sill in R-space for the backwards Fourier transform.");


  $ftboxsizer -> Add($gbs, 0, wxALL, 5);

  my $windowsbox  = Wx::BoxSizer->new( wxHORIZONTAL );
  $ftboxsizer -> Add($windowsbox, 0, wxALIGN_LEFT|wxALL, 0);

  $label     = Wx::StaticText->new($leftpane, -1, "FT window");
  $this->{kwindow} = Wx::Choice  ->new($leftpane, -1, , wxDefaultPosition, wxDefaultSize, $windows);
  $windowsbox -> Add($label, 0, wxALL, 5);
  $windowsbox -> Add($this->{kwindow}, 0, wxALL, 2);
  $this->{kwindow}->SetSelection(firstidx {$_ eq $demeter->co->default("fft", "kwindow")} @$windows);

  $this->mouseover("kwindow", "The functional form of the window used for both forwards and backwards Fourier transforms.");


#   $label     = Wx::StaticText->new($leftpane, -1, "R window");
#   $this->{rwindow} = Wx::Choice  ->new($leftpane, -1, , wxDefaultPosition, wxDefaultSize, $windows);
#   $windowsbox -> Add($label, 0, wxALL, 5);
#   $windowsbox -> Add($this->{rwindow}, 0, wxALL, 2);
#   $this->{rwindow}->SetSelection(firstidx {$_ eq $demeter->co->default("bft", "rwindow")} @$windows);

  ## -------- k-weights
  my $kwbox      = Wx::StaticBox->new($leftpane, -1, 'Fitting k weights ', wxDefaultPosition, wxDefaultSize);
  my $kwboxsizer = Wx::StaticBoxSizer->new( $kwbox, wxHORIZONTAL );
  $left         -> Add($kwboxsizer, 0, wxALL|wxGROW|wxALIGN_CENTER_HORIZONTAL, 5);

  $this->{k1}   = Wx::CheckBox->new($leftpane, -1, "1",     wxDefaultPosition, wxDefaultSize);
  $this->{k2}   = Wx::CheckBox->new($leftpane, -1, "2",     wxDefaultPosition, wxDefaultSize);
  $this->{k3}   = Wx::CheckBox->new($leftpane, -1, "3",     wxDefaultPosition, wxDefaultSize);
  $this->{karb} = Wx::CheckBox->new($leftpane, -1, "other", wxDefaultPosition, wxDefaultSize);
  $this->{karb_value} = Wx::TextCtrl->new($leftpane, -1, $demeter->co->default('fit', 'karb_value'), wxDefaultPosition, wxDefaultSize);
  $kwboxsizer -> Add($this->{k1}, 1, wxLEFT|wxRIGHT, 5);
  $kwboxsizer -> Add($this->{k2}, 1, wxLEFT|wxRIGHT, 5);
  $kwboxsizer -> Add($this->{k3}, 1, wxLEFT|wxRIGHT, 5);
  $kwboxsizer -> Add($this->{karb}, 0, wxLEFT|wxRIGHT, 5);
  $kwboxsizer -> Add($this->{karb_value}, 0, wxLEFT|wxRIGHT, 5);
  $this->{k1}   -> SetValue($demeter->co->default('fit', 'k1'));
  $this->{k2}   -> SetValue($demeter->co->default('fit', 'k2'));
  $this->{k3}   -> SetValue($demeter->co->default('fit', 'k3'));
  $this->{karb} -> SetValue($demeter->co->default('fit', 'karb'));
  $this->{karb_value} -> SetValidator( Wx::Perl::TextValidator->new( qr([0-9.]) ) );

  $this->mouseover("k1", "Use a k-weight of 1 when evaluating the fit.  You may choose any or all k-weights for fitting.");
  $this->mouseover("k2", "Use a k-weight of 2 when evaluating the fit.  You may choose any or all k-weights for fitting.");
  $this->mouseover("k3", "Use a k-weight of 3 when evaluating the fit.  You may choose any or all k-weights for fitting.");
  $this->mouseover("karb", "Use the supplied value of k-weight when evaluating the fit.  You may choose any or all k-weights for fitting.");
  $this->mouseover("karb_value", "The user-supplied value of k-weight for use in the fit.  You may choose any or all k-weights for fitting.");

  my $otherbox      = Wx::StaticBox->new($leftpane, -1, 'Other parameters ', wxDefaultPosition, wxDefaultSize);
  my $otherboxsizer = Wx::StaticBoxSizer->new( $otherbox, wxVERTICAL );
  $left            -> Add($otherboxsizer, 0, wxALL|wxGROW|wxALIGN_CENTER_HORIZONTAL, 5);


  ## --------- toggles
  my $togglebox  = Wx::BoxSizer->new( wxHORIZONTAL );
  $otherboxsizer -> Add($togglebox, 0, wxALIGN_CENTER_HORIZONTAL|wxALL, 0);
  $this->{include}    = Wx::CheckBox->new($leftpane, -1, "Include in fit", wxDefaultPosition, wxDefaultSize);
  $this->{plot_after} = Wx::CheckBox->new($leftpane, -1, "Plot after fit", wxDefaultPosition, wxDefaultSize);
  $this->{fit_bkg}    = Wx::CheckBox->new($leftpane, -1, "Fit background", wxDefaultPosition, wxDefaultSize);
  $togglebox -> Add($this->{include},    0, wxALL, 5);
  $togglebox -> Add($this->{plot_after}, 0, wxALL, 5);
  $togglebox -> Add($this->{fit_bkg},    0, wxALL, 5);
  $this->{include}    -> SetValue(1);
  $this->{plot_after} -> SetValue(1);

  $this->mouseover("include",    "Click here to include this data in the fit.  Unclick to exclude it.");
  $this->mouseover("plot_after", "Click here to have this data set automatically transfered tothe plotting list after the fit.");
  $this->mouseover("fit_bkg",    "Click here to co-refine a background spline during the fit.");


  ## -------- epsilon and phase correction
  my $extrabox    = Wx::BoxSizer->new( wxHORIZONTAL );
  $otherboxsizer -> Add($extrabox, 0, wxALL|wxGROW|wxALIGN_CENTER_HORIZONTAL, 0);

  $extrabox -> Add(Wx::StaticText->new($leftpane, -1, "$EPSILON(k)"), 0, wxALL, 5);
  $this->{epsilon} = Wx::TextCtrl->new($leftpane, -1, 0, wxDefaultPosition, [50,-1]);
  $extrabox  -> Add($this->{epsilon}, 0, wxALL, 2);
  $extrabox  -> Add(Wx::StaticText->new($leftpane, -1, q{}), 1, wxALL, 0);
  $this->{pcplot}  = Wx::CheckBox->new($leftpane, -1, "Plot with phase correction", wxDefaultPosition, wxDefaultSize);
  $extrabox  -> Add($this->{pcplot}, 0, wxALL, 0);
  $this->{pcplot}->Enable(0);

  $this->{epsilon} -> SetValidator( Wx::Perl::TextValidator->new( qr([0-9.]) ) );
  $this->mouseover("epsilon", "A user specified value for the measurement uncertainty.  A value of 0 means to let Ifeffit determine the uncertainty.");

  $leftpane -> SetSizerAndFit($left);


  $hbox -> Add(Wx::StaticLine->new($this, -1, wxDefaultPosition, [4, -1], wxLI_VERTICAL), 0, wxGROW|wxALL, 5);


  ##-------- paths list for this data

  my $rightpane = Wx::Panel->new($this, -1, wxDefaultPosition, [-1,-1]);
  my $right = Wx::BoxSizer->new( wxVERTICAL );
  $hbox->Add($rightpane, 1, wxGROW|wxALL, 0);


  my $imagelist = Wx::ImageList->new( 1,1 );
  foreach my $i (0 .. 1) {
    my $icon = File::Spec->catfile($Demeter::UI::Artemis::artemis_base, 'Artemis', 'icons', "pixel.png");
    $imagelist->Add( Wx::Bitmap->new($icon, wxBITMAP_TYPE_PNG) );
  };

  my $panel = $this->initial_page_panel;
  $this->{pathlist} = Demeter::UI::Wx::CheckListBook->new( $rightpane, -1, wxDefaultPosition, wxDefaultSize, $panel, wxBK_LEFT );
  $right -> Add($this->{pathlist}, 1, wxGROW|wxALL, 5);

  my $pathbuttons = Wx::BoxSizer->new( wxHORIZONTAL );
  $right -> Add($pathbuttons, 0, wxGROW|wxALL, 5);

  if (0) {
    $this->{up}        = Wx::Button->new($rightpane, wxID_UP,   q{},        wxDefaultPosition, wxDefaultSize, wxBU_EXACTFIT);
    $this->{down}      = Wx::Button->new($rightpane, wxID_DOWN, q{},        wxDefaultPosition, wxDefaultSize, wxBU_EXACTFIT);
    $this->{makevpath} = Wx::Button->new($rightpane, -1, 'Make &VPath',     wxDefaultPosition, wxDefaultSize, wxBU_EXACTFIT);
    $this->{transfer}  = Wx::Button->new($rightpane, -1, 'Transfer marked', wxDefaultPosition, wxDefaultSize, wxBU_EXACTFIT);
    $pathbuttons -> Add($this->{up},        0, wxLEFT|wxRIGHT, 5);
    $pathbuttons -> Add($this->{down},      0, wxLEFT|wxRIGHT, 5);
    $pathbuttons -> Add($this->{makevpath}, 0, wxLEFT|wxRIGHT, 5);
    $pathbuttons -> Add($this->{transfer},  0, wxLEFT|wxRIGHT, 5);
    $this->mouseover("up",        "Move the current path up in the path list");
    $this->mouseover("down",      "Move the current path up in the path list");
    $this->mouseover("makevpath", "Make a VPath out of the marked paths");
    $this->mouseover("transfer",  "Transfer each of the marked paths to the plotting list");
    EVT_BUTTON($this, $this->{up},        sub{$this->OnUpButton});
    EVT_BUTTON($this, $this->{down},      sub{$this->OnDownButton});
    EVT_BUTTON($this, $this->{makevpath}, sub{$this->OnMakeVPathButton});
    EVT_BUTTON($this, $this->{transfer},  sub{$this->OnTransferButton});
  };

  $this->{pathlist}->SetDropTarget( Demeter::UI::Artemis::Data::DropTarget->new( $this, $this->{pathlist} ) );

  $rightpane -> SetSizerAndFit($right);


  #$splitter -> SplitVertically($leftpane, $rightpane, -500);
  #$splitter -> SetSashSize(10);

  $this -> SetSizerAndFit( $hbox );
  return $this;
};

sub mouseover {
  my ($self, $widget, $text) = @_;                                         # $event --v
  EVT_ENTER_WINDOW($self->{$widget}, sub{$self->{statusbar}->PushStatusText($text); $_[1]->Skip});
  EVT_LEAVE_WINDOW($self->{$widget}, sub{$self->{statusbar}->PopStatusText;         $_[1]->Skip});
};

sub initial_page_panel {
  my ($self) = @_;
  my $panel = Wx::Panel->new($self, -1, wxDefaultPosition, wxDefaultSize);

  my $vv = Wx::BoxSizer->new( wxVERTICAL );

  my $dndtext = Wx::StaticText    -> new($panel, -1, "Drag paths from a Feff interpretation list and drop them in this space to add paths to this data set", wxDefaultPosition, [300,-1]);
  $dndtext   -> Wrap(280);
  my $atoms   = Wx::HyperlinkCtrl -> new($panel, -1, 'Import crystal data',           q{}, wxDefaultPosition, wxDefaultSize );
  my $qfs     = Wx::HyperlinkCtrl -> new($panel, -1, 'Start a quick first shell fit', q{}, wxDefaultPosition, wxDefaultSize );
  my $su      = Wx::StaticText    -> new($panel, -1, 'Import a structural unit',           wxDefaultPosition, wxDefaultSize );
  my $feff    = Wx::StaticText    -> new($panel, -1, 'Import a Feff calculation',          wxDefaultPosition, wxDefaultSize );

  EVT_HYPERLINK($self, $atoms, sub{Demeter::UI::Artemis::new_feff($Demeter::UI::Artemis::frames{main});});
  EVT_HYPERLINK($self, $qfs,   sub{$self->quickfs;});
  $_ -> SetFont( Wx::Font->new( 10, wxDEFAULT, wxITALIC, wxNORMAL, 0, "" ) ) foreach ($dndtext, $qfs, $atoms, $su, $feff);
  $_ -> Enable(0) foreach ($su, $feff);
  $_ -> SetVisitedColour($_->GetNormalColour) foreach ($qfs, $atoms); #, $su, $feff);

  ##my $or = Wx::StaticText -> new($panel, -1, "\tor");

  $vv -> Add($dndtext,                                  0, wxALL, 5 );
  $vv -> Add(Wx::StaticText -> new($panel, -1, "\tor"), 0, wxALL, 10);
  $vv -> Add($atoms,                                    0, wxALL, 5 );
  $vv -> Add(Wx::StaticText -> new($panel, -1, "\tor"), 0, wxALL, 10);
  $vv -> Add($qfs,                                      0, wxALL, 5 );
  $vv -> Add(Wx::StaticText -> new($panel, -1, "\tor"), 0, wxALL, 10);
  $vv -> Add($su,                                       0, wxALL, 5 );
  $vv -> Add(Wx::StaticText -> new($panel, -1, "\tor"), 0, wxALL, 10);
  $vv -> Add($feff,                                     0, wxALL, 5 );

  $panel -> SetSizer($vv);
  return $panel;
};


sub on_close {
  my ($self) = @_;
  $self->Show(0);
  $self->{PARENT}->{$self->{dnum}}->SetValue(0);
  (my $label = $self->{PARENT}->{$self->{dnum}}->GetLabel) =~ s{Hide}{Show};;
  $self->{PARENT}->{$self->{dnum}}->SetLabel($label);
};

sub OnUpButton {
  my ($self, $event) = @_;
  my $pathpage = $self->{pathlist}->GetPage($self->{pathlist}->GetSelection);
  return if ($pathpage !~ m{Path});
  my $pos = $self->{pathlist}->GetSelection;
  print "clicked up button -- position $pos shown\n";
};
sub OnDownButton {
  my ($self, $event) = @_;
  my $pathpage = $self->{pathlist}->GetPage($self->{pathlist}->GetSelection);
  return if ($pathpage !~ m{Path});
  my $pos = $self->{pathlist}->GetSelection;
  print "clicked down button -- position $pos shown\n";
};

sub OnTransferButton {
  my ($self, $event) = @_;
  my $pathpage = $self->{pathlist}->GetPage($self->{pathlist}->GetSelection);
  return if ($pathpage !~ m{Path});
  foreach my $p (0 .. $self->{pathlist}->GetPageCount - 1) {
    $self->{pathlist}->GetPage($p)->transfer if $self->{pathlist}->IsChecked($p);
  };
  $self->{statusbar}->SetStatusText("Transfered marked groups to plotting list");
};

sub OnMakeVPathButton {
  my ($self, $event) = @_;
  my $pathpage = $self->{pathlist}->GetPage($self->{pathlist}->GetSelection);
  return if ($pathpage !~ m{Path});

  my @list = ();
  foreach my $p (0 .. $self->{pathlist}->GetPageCount - 1) {
    push(@list, $self->{pathlist}->GetPage($p)->{path}) if $self->{pathlist}->IsChecked($p);
  };
  return if ($#list == -1);
  $Demeter::UI::Artemis::frames{Plot}->{VPaths}->add_vpath(@list);
  autosave();
  $self->{statusbar}->SetStatusText("Made a VPath from the marked groups");
};

sub make_menubar {
  my ($self) = @_;
  $self->{menubar}   = Wx::MenuBar->new;

  ## -------- chi(k) menu
  $self->{datamenu}  = Wx::Menu->new;
  $self->{datamenu}->Append($DATA_RENAME,      "Rename this $CHI(k)",         "Rename this data set",  wxITEM_NORMAL );
  $self->{datamenu}->Append($DATA_REPLACE,     "Replace this $CHI(k)",        "Replace this data set",  wxITEM_NORMAL );
  $self->{datamenu}->Append($DATA_DIFF,        "Make difference spectrum", "Make a difference spectrum using the marked paths", wxITEM_NORMAL );
  #$self->{datamenu}->Append($DATA_TRANSFER,    "Transfer marked paths",    "Transfer marked paths to the plotting list", wxITEM_NORMAL );
  #$self->{datamenu}->Append($DATA_VPATH,       "Make VPath",               "Make a virtual path from the set of marked paths", wxITEM_NORMAL );
  $self->{datamenu}->AppendSeparator;
  $self->{datamenu}->Append($PATH_FSPATH,      "Quick first shell model", "Generate a quick first shell fitting model", wxITEM_NORMAL );
  $self->{datamenu}->AppendSeparator;
  $self->{datamenu}->Append($DATA_BALANCE,     "Balance interstitial energies", "Adjust E0 for every path so that the interstitial energies for each Feff calculation are balanced",  wxITEM_NORMAL );
  $self->{datamenu}->Append($DATA_DEGEN_N,     "Set all degens to Feff",   "Set degeneracies for all paths in this data set to values from Feff",  wxITEM_NORMAL );
  $self->{datamenu}->Append($DATA_DEGEN_1,     "Set all degens to one",    "Set degeneracies for all paths in this data set to one (1)",  wxITEM_NORMAL );
  $self->{datamenu}->AppendSeparator;
  $self->{datamenu}->Append($DATA_DISCARD,     "Discard this $CHI(k)",        "Discard this data set", wxITEM_NORMAL );
  $self->{datamenu}->AppendSeparator;
  $self->{datamenu}->Append($DATA_KMAXSUGEST, "Set kmax to Ifeffit's suggestion", "Set kmax to Ifeffit's suggestion, which is computed based on the staistical noise", wxITEM_NORMAL );
  $self->{datamenu}->Append($DATA_EPSK,       "Show $EPSILON",                    "Show statistical noise for these data", wxITEM_NORMAL );
  $self->{datamenu}->Append($DATA_NIDP,       "Show Nidp",                        "Show the number of independent points in these data", wxITEM_NORMAL );


  ## -------- paths menu
  my $export_menu   = Wx::Menu->new;
  $export_menu->Append($PATH_EXPORT_FEFF, "each path THIS Feff calculation",
		       "Export all path parameters from the currently displayed path to all paths in this Feff calculation", wxITEM_NORMAL );
  $export_menu->Append($PATH_EXPORT_DATA, "each path THIS data set",
		       "Export all path parameters from the currently displayed path to all paths in this data set", wxITEM_NORMAL );
  $export_menu->Append($PATH_EXPORT_EACH, "each path EVERY data set",
		       "Export all path parameters from the currently displayed path to all paths in every data set", wxITEM_NORMAL );
  $export_menu->Append($PATH_EXPORT_MARKED,  "each marked path in THIS data set",
		       "Export all path parameters from the currently displayed path to all marked paths", wxITEM_NORMAL );

  my $save_menu     = Wx::Menu->new;
  $save_menu->Append($PATH_SAVE_K, "k-space", "Save the currently displayed path as $CHI(k) with all path parameters evaluated", wxITEM_NORMAL);
  $save_menu->Append($PATH_SAVE_R, "R-space", "Save the currently displayed path as $CHI(R) with all path parameters evaluated", wxITEM_NORMAL);
  $save_menu->Append($PATH_SAVE_Q, "q-space", "Save the currently displayed path as $CHI(q) with all path parameters evaluated", wxITEM_NORMAL);

#   my $explain_menu   = Wx::Menu->new;
#   $explain_menu->Append($PATH_EXP_LABEL,  'label',   'Explain the path label');
#   $explain_menu->Append($PATH_EXP_N,      'N',       'Explain the path degeneracy');
#   $explain_menu->Append($PATH_EXP_S02,    'S02',     'Explain the S02 path parameter');
#   $explain_menu->Append($PATH_EXP_E0,     'ΔE0',     'Explain the e0 shift');
#   $explain_menu->Append($PATH_EXP_DELR,   'ΔR',      'Explain the change in path length');
#   $explain_menu->Append($PATH_EXP_SIGMA2, 'σ²',      'Explain the sigma^2 path parameter');
#   $explain_menu->Append($PATH_EXP_EI,     'Ei',      'Explain the imaginary energy correction');
#   $explain_menu->Append($PATH_EXP_THIRD,  '3rd',     'Explain the third cumulant');
#   $explain_menu->Append($PATH_EXP_FOURTH, '4th',     'Explain the fourth cumulant');

  $self->{pathsmenu} = Wx::Menu->new;
  $self->{pathsmenu}->Append($PATH_RENAME, "Rename path",            "Rename the path currently on display", wxITEM_NORMAL );
  $self->{pathsmenu}->Append($PATH_SHOW,   "Show path",              "Evaluate and show the path parameters for the path currently on display", wxITEM_NORMAL );
  $self->{pathsmenu}->AppendSeparator;
  $self->{pathsmenu}->Append($DISCARD_THIS, "Discard this path",     "Discard the path currently on display", wxITEM_NORMAL );
  $self->{pathsmenu}->AppendSeparator;
  $self->{pathsmenu}->Append($PATH_ADD,    "Add path parameter",     "Add path parameter to many paths", wxITEM_NORMAL );
  $self->{pathsmenu}->AppendSubMenu($export_menu, "Export all path parameters to");
  $self->{pathsmenu}->AppendSeparator;
  $self->{pathsmenu}->AppendSubMenu($save_menu, "Save this path in ..." );
  $self->{pathsmenu}->Append($PATH_CLONE, "Clone this path", "Make a copy of the currently displayed path", wxITEM_NORMAL );
  $self->{pathsmenu}->Append($PATH_HISTO, "Make histogram", "Generate a histogram using the currently displayed path", wxITEM_NORMAL );
#  $self->{pathsmenu}->AppendSeparator;
#  $self->{pathsmenu}->AppendSubMenu($explain_menu, "Explain path parameter ..." );

  $self->{debugmenu}  = Wx::Menu->new;
  $self->{debugmenu}->Append($DATA_SHOW, "Show this Ifeffit group",  "Show the arrays associated with this group in Ifeffit",  wxITEM_NORMAL );
  $self->{debugmenu}->Append($PATH_SHOW, "Show path",                "Evaluate and show the path parameters for the currently display path", wxITEM_NORMAL );
  $self->{debugmenu}->AppendSeparator;
  $self->{debugmenu}->Append($DATA_YAML, "Show YAML for this data set",  "Show YAML for this data set",  wxITEM_NORMAL );
  $self->{debugmenu}->Append($PATH_YAML, "Show YAML for displayed path", "Show YAML for displayed path", wxITEM_NORMAL );
  $self->{debugmenu}->Append($PATH_TYPE, "Identify displayed path",      "Show the object type of the displayed path (Path | FSPath | SSPath | MSPath | ThreeBody)", wxITEM_NORMAL );


  ## -------- marks menu
  $self->{markmenu}  = Wx::Menu->new;
  $self->{markmenu}->Append($MARK_ALL,    "Mark all",      "Mark all paths for this $CHI(k)",             wxITEM_NORMAL );
  $self->{markmenu}->Append($MARK_NONE,   "Unmark all",    "Unmark all paths for this $CHI(k)",           wxITEM_NORMAL );
  $self->{markmenu}->Append($MARK_INVERT, "Invert marks",  "Invert all marks for this $CHI(k)",           wxITEM_NORMAL );
  $self->{markmenu}->Append($MARK_REGEXP, "Mark regexp",   "Mark by regular expression for this $CHI(k)", wxITEM_NORMAL );
  $self->{markmenu}->AppendSeparator;
  $self->{markmenu}->Append($MARK_INC,    "Mark included", "Mark all paths included in the fit",   wxITEM_NORMAL );
  $self->{markmenu}->Append($MARK_EXC,    "Mark excluded", "Mark all paths excluded from the fit", wxITEM_NORMAL );
  $self->{markmenu}->AppendSeparator;
  $self->{markmenu}->Append($MARK_BEFORE, "Mark before current",   "Mark this path and all paths above it in the path list for this $CHI(k)", wxITEM_NORMAL );
  $self->{markmenu}->Append($MARK_AFTER,  "Mark after current",    "Mark all paths after this one in the path list for this $CHI(k)", wxITEM_NORMAL );
  $self->{markmenu}->AppendSeparator;
  $self->{markmenu}->Append($MARK_SS,     "Mark SS paths",         "Mark all single scattering paths for this $CHI(k)", wxITEM_NORMAL );
  $self->{markmenu}->Append($MARK_MS,     "Mark MS paths",         "Mark all multiple scattering paths for this $CHI(k)", wxITEM_NORMAL );
  $self->{markmenu}->AppendSeparator;
  $self->{markmenu}->Append($MARK_HIGH,   "Mark high importance",  "Mark all high importance paths for this $CHI(k)", wxITEM_NORMAL );
  $self->{markmenu}->Append($MARK_MID,    "Mark mid importance",   "Mark all mid importance paths for this $CHI(k)", wxITEM_NORMAL );
  $self->{markmenu}->Append($MARK_LOW,    "Mark low importance",   "Mark all low importance paths for this $CHI(k)", wxITEM_NORMAL );
  $self->{markmenu}->AppendSeparator;
  $self->{markmenu}->Append($MARK_RBELOW, "Mark all paths < R",    "Mark all paths shorter than a specified path length for this $CHI(k)", wxITEM_NORMAL );
  $self->{markmenu}->Append($MARK_RABOVE, "Mark all paths > R",    "Mark all paths longer than a specified path length for this $CHI(k)", wxITEM_NORMAL );

#   ## -------- include menu
#   $self->{includemenu}  = Wx::Menu->new;
#   $self->{includemenu}->Append($INCLUDE_ALL,    "Include all", "Include all paths in the fit",                     wxITEM_NORMAL );
#   $self->{includemenu}->Append($EXCLUDE_ALL,    "Exclude all", "Exclude all paths from the fit",                   wxITEM_NORMAL );
#   $self->{includemenu}->Append($INCLUDE_INVERT, "Invert all",  "Invert whether all paths are included in the fit", wxITEM_NORMAL );
#   $self->{includemenu}->AppendSeparator;
#   $self->{includemenu}->Append($INCLUDE_MARKED, "Include marked", "Include all marked paths in the fit",   wxITEM_NORMAL );
#   $self->{includemenu}->Append($EXCLUDE_MARKED, "Exclude marked", "Exclude all marked paths from the fit", wxITEM_NORMAL );
#   $self->{includemenu}->AppendSeparator;
#   $self->{includemenu}->Append($EXCLUDE_AFTER,  "Exclude after current",   "Exclude all paths after the current from the fit", wxITEM_NORMAL );
#   $self->{includemenu}->Append($INCLUDE_SS,     "Include all SS paths",    "Include all single scattering paths in the fit", wxITEM_NORMAL );
#   $self->{includemenu}->Append($INCLUDE_HIGH,   "Include high importance", "Include all high importance paths in the fit", wxITEM_NORMAL );
#   $self->{includemenu}->Append($INCLUDE_R,      "Include all paths < R",   "Include all paths shorter than a specified length in the fit", wxITEM_NORMAL );

#   ## -------- discard menu
#   $self->{discardmenu}  = Wx::Menu->new;
#   $self->{discardmenu}->Append($DISCARD_THIS,     "Discard this path", "Discard the currently displayed path", wxITEM_NORMAL );
#   $self->{discardmenu}->AppendSeparator;
#   $self->{discardmenu}->Append($DISCARD_ALL,      "Discard all",      "Discard all paths",          wxITEM_NORMAL );
#   $self->{discardmenu}->Append($DISCARD_MARKED,   "Discard marked",   "Discard all marked paths",   wxITEM_NORMAL );
#   $self->{discardmenu}->Append($DISCARD_UNMARKED, "Discard unmarked", "Discard all UNmarked paths", wxITEM_NORMAL );
#   $self->{discardmenu}->Append($DISCARD_EXCLUDED, "Discard excluded", "Discard all excluded paths", wxITEM_NORMAL );
#   $self->{discardmenu}->AppendSeparator;
#   $self->{discardmenu}->Append($DISCARD_AFTER,  "Discard after current",  "Discard all paths after the current from the fit", wxITEM_NORMAL );
#   $self->{discardmenu}->Append($DISCARD_MS,     "Discard all MS paths",   "Discard all multiple scattering paths in the fit", wxITEM_NORMAL );
#   $self->{discardmenu}->Append($DISCARD_LOW,    "Discard low importance", "Discard all low importance paths in the fit", wxITEM_NORMAL );
#   $self->{discardmenu}->Append($DISCARD_R,      "Discard all paths > R",  "Discard all paths shorter than a specified length in the fit", wxITEM_NORMAL );

   ## -------- actions menu
  $self->{actionsmenu} = Wx::Menu->new;
  $self->{actionsmenu}->Append($ACTION_VPATH,     "Make VPath from marked",  "Make a virtual path from all marked paths", wxITEM_NORMAL );
  $self->{actionsmenu}->Append($ACTION_TRANSFER,  "Transfer marked",  "Transfer all marked paths to the plotting list",   wxITEM_NORMAL );
  $self->{actionsmenu}->AppendSeparator;
  $self->{actionsmenu}->Append($ACTION_INCLUDE,   "Include marked",   "Include all marked paths in the fit",   wxITEM_NORMAL );
  $self->{actionsmenu}->Append($ACTION_EXCLUDE,   "Exclude marked",   "Exclude all marked paths from the fit", wxITEM_NORMAL );
  $self->{actionsmenu}->AppendSeparator;
  $self->{actionsmenu}->Append($ACTION_DISCARD,   "Discard marked",   "Discard all marked paths",              wxITEM_NORMAL );

  $self->{menubar}->Append( $self->{datamenu},    "Da&ta" );
  $self->{menubar}->Append( $self->{pathsmenu},   "&Path" );
  $self->{menubar}->Append( $self->{markmenu},    "M&arks" );
  $self->{menubar}->Append( $self->{actionsmenu}, "Actions" );
  #$self->{menubar}->Append( $self->{includemenu}, "&Include" );
  #$self->{menubar}->Append( $self->{discardmenu}, "Dis&card" );
  $self->{menubar}->Append( $self->{debugmenu},   "Debu&g" ) if ($demeter->co->default("artemis", "debug_menus"));

  map { $self->{datamenu} ->Enable($_,0) } ($DATA_DIFF, $DATA_REPLACE, $DATA_BALANCE);
  #map { $self->{summenu}  ->Enable($_,0) } ($SUM_MARKED, $SUM_INCLUDED, $SUM_IM);
  map { $self->{pathsmenu}->Enable($_,0) } ($PATH_CLONE);

};

sub populate {
  my ($self, $data) = @_;
  $self->{data} = $data;
  $self->{name}->SetLabel($data->name);
  $self->{cv}->SetValue($data->cv);
  $self->{datasource}->SetValue($data->prjrecord);
  #$self->{datasource}->ShowPosition($self->{datasource}->GetLastPosition);
  $self->{titles}->SetValue(join("\n", @{ $data->titles }));
  $self->{kmin}->SetValue($data->fft_kmin);
  $self->{kmax}->SetValue($data->fft_kmax);
  $self->{dk}->SetValue($data->fft_dk);
  $self->{rmin}->SetValue($data->bft_rmin);
  $self->{rmin}->SetValue($data->bkg_rbkg + 0.05) if ($data->bft_rmin < $data->bkg_rbkg);
  $self->{rmax}->SetValue($data->bft_rmax);
  $self->{dr}->SetValue($data->bft_dr);

  $self->{k1}->SetValue($data->fit_k1);
  $self->{k2}->SetValue($data->fit_k2);
  $self->{k3}->SetValue($data->fit_k3);
  $self->{karb}->SetValue($data->fit_karb);
  $self->{karb_value}->SetValue($data->fit_karb_value);

  $self->{include}->SetValue($data->fit_include);
  $self->{fit_bkg}->SetValue($data->fit_do_bkg);
  $self->{epsilon}->SetValue($data->fit_epsilon);

  $self->{titles}->SetValue(join($/, @{$data->titles}));

  EVT_CHECKBOX($self, $self->{include},    sub{$data->fit_include       ($self->{include}   ->GetValue)});
  EVT_CHECKBOX($self, $self->{plot_after}, sub{$data->fit_plot_after_fit($self->{plot_after}->GetValue)});
  EVT_CHECKBOX($self, $self->{fit_bkg},    sub{$data->fit_do_bkg        ($self->{fit_bkg}   ->GetValue)});

  EVT_CHECKBOX($self, $self->{k1},   sub{$data->fit_k1($self->{k1}->GetValue)});
  EVT_CHECKBOX($self, $self->{k2},   sub{$data->fit_k2($self->{k2}->GetValue)});
  EVT_CHECKBOX($self, $self->{k3},   sub{$data->fit_k3($self->{k3}->GetValue)});
  EVT_CHECKBOX($self, $self->{karb}, sub{$data->fit_karb($self->{karb}->GetValue)});

  EVT_CHECKBOX($self, $self->{pcplot}, sub{$data->fit_do_pcpath($self->{pcplot}->GetValue)});

  EVT_CHOICE($self, $self->{kwindow}, sub{$data->fft_kwindow($self->{kwindow}->GetStringSelection);
					  $data->bft_rwindow($self->{kwindow}->GetStringSelection);
					});
  #EVT_CHOICE($self, $self->{rwindow}, sub{$data->bft_rwindow($self->{rwindow}->GetStringSelection)});

  return $self;
}

sub fetch_parameters {
  my ($this) = @_;
  #$this->{data}->name($this->{name}->GetValue);

  my $titles = $this->{titles}->GetValue;
  my @list   = split(/\n/, $titles);
  $this->{data}->titles(\@list);

  $this->{data}->fft_kmin	    ($this->{kmin}      ->GetValue	    );
  $this->{data}->fft_kmax	    ($this->{kmax}      ->GetValue	    );
  $this->{data}->fft_dk		    ($this->{dk}        ->GetValue	    );
  $this->{data}->bft_rmin	    ($this->{rmin}      ->GetValue	    );
  $this->{data}->bft_rmax	    ($this->{rmax}      ->GetValue	    );
  $this->{data}->bft_dr		    ($this->{dr}        ->GetValue	    );
  $this->{data}->fft_kwindow	    ($this->{kwindow}   ->GetStringSelection);
  $this->{data}->bft_rwindow	    ($this->{kwindow}   ->GetStringSelection);
  $this->{data}->fit_k1		    ($this->{k1}        ->GetValue	    );
  $this->{data}->fit_k2		    ($this->{k2}        ->GetValue	    );
  $this->{data}->fit_k3		    ($this->{k3}        ->GetValue	    );
  $this->{data}->fit_karb	    ($this->{karb}      ->GetValue	    );
  $this->{data}->fit_karb_value	    ($this->{karb_value}->GetValue	    );
  $this->{data}->fit_epsilon	    ($this->{epsilon}   ->GetValue	    );

  $this->{data}->fit_include	    ($this->{include}    ->GetValue         );
  $this->{data}->fit_plot_after_fit ($this->{plot_after} ->GetValue         );
  $this->{data}->fit_do_bkg	    ($this->{fit_bkg}    ->GetValue         );
  $this->{data}->fit_do_pcpath	    ($this->{pcplot}     ->GetValue         );

  my $cv = $this->{cv}->GetValue;
  # things that are not caught by $RE{num}{real} or the validator
  if (($cv =~ m{\-.*\-}) or ($cv =~ m{\..*\.}) or ($cv =~ m{[^-]+-})) {
    carp(sprintf("Oops. The CV for data set \"%s\" is not a number ($cv).\n\n", $this->{data}->name));
    return 0;
  } else {
    $this->{data}->cv($cv);
  };
  return 1;
};

sub plot {
  my ($self, $event, $how) = @_;
  $self->fetch_parameters;
  $Demeter::UI::Artemis::frames{Plot}->fetch_parameters;
  $self->{data}->po->start_plot;
  $self->{data}->plot($how);
  my $text = ($how eq 'rmr')   ? "as the magnitude and real part of chi(R)"
           : ($how eq 'r123')  ? "in R with three k-weights"
           : ($how eq 'k123')  ? "in k with three k-weights"
           : ($how eq 'kqfit') ? "in k- and q-space"
	   :                     q{};
  $self->{statusbar}->SetStatusText(sprintf("Plotted \"%s\" %s.",
					    $self->{data}->name, $text));
  $Demeter::UI::Artemis::frames{Plot}->{indicators}->plot($self->{data});
};

sub OnMenuClick {
  my ($datapage, $event)  = @_;
  my $id = $event->GetId;
  #print "1  $id  $PATH_ADD\n";
 SWITCH: {

    ($id == $DATA_RENAME) and do {
      $datapage->Rename;
      last SWITCH;
    };

    ($id == $DATA_DISCARD) and do {
      $datapage->discard_data;
      last SWITCH;
    };

    ($id == $DATA_SHOW) and do {
      Demeter::UI::Artemis::show_ifeffit($datapage->{data}->group);
      last SWITCH;
    };

    (($id == $DATA_DEGEN_N) or ($id == $DATA_DEGEN_1)) and do {
      $datapage->set_degens($id);
      last SWITCH;
    };

    ($id == $DATA_TRANSFER) and do {
      $datapage->OnTransferButton;
      last SWITCH;
    };

    ($id == $DATA_VPATH) and do {
      $datapage->OnMakeVPathButton;
      last SWITCH;
    };

    ($id == $DATA_KMAXSUGEST) and do {
      $datapage->fetch_parameters;
      $datapage->{data}->chi_noise;
      $datapage->{kmax}->SetValue($datapage->{data}->recommended_kmax);
      $datapage->{data}->fft_kmax($datapage->{data}->recommended_kmax);
      my $text = sprintf("The number of independent points in this data set is now %.2f", $datapage->{data}->nidp);
      $datapage->{statusbar}->SetStatusText($text);
      last SWITCH;
    };
    ($id == $DATA_EPSK) and do {
      $datapage->fetch_parameters;
      $datapage->{data}->chi_noise;
      my $text = sprintf("Statistical noise: $EPSILON(k) = %.2e and $EPSILON(R) = %.2e", $datapage->{data}->epsk, $datapage->{data}->epsr);
      $datapage->{statusbar}->SetStatusText($text);
      last SWITCH;
    };
    ($id == $DATA_NIDP) and do {
      $datapage->fetch_parameters;
      my $text = sprintf("The number of independent points in this data set is %.2f", $datapage->{data}->nidp);
      $datapage->{statusbar}->SetStatusText($text);
      last SWITCH;
    };

    ($id == $PATH_SHOW) and do { # show a dialog with the path paragraph
      my $pathobject = $datapage->{pathlist}->GetPage($datapage->{pathlist}->GetSelection)->{path};
      my ($abort, $rdata, $rpaths) = Demeter::UI::Artemis::uptodate(\%Demeter::UI::Artemis::frames);
      $pathobject->_update("fft");
      my $dialog = Demeter::UI::Artemis::ShowText->new($datapage, $pathobject->paragraph, $pathobject->label.', evaluated')
	-> Show;
      last SWITCH;
    };

    ($id == $DATA_YAML) and do {
      $datapage->fetch_parameters;
      my $dataobject = $datapage->{data};
      my $yaml = $dataobject->serialization;
      my $dialog = Demeter::UI::Artemis::ShowText->new($datapage, $yaml, 'YAML of ' . $dataobject->name)
	-> Show;
      last SWITCH;
    };

    ($id == $PATH_YAML) and do {
      my $pathobject = $datapage->{pathlist}->GetPage($datapage->{pathlist}->GetSelection)->{path};
      my ($abort, $rdata, $rpaths) = Demeter::UI::Artemis::uptodate(\%Demeter::UI::Artemis::frames);
      $pathobject->_update("fft");
      my $dialog = Demeter::UI::Artemis::ShowText->new($datapage, $pathobject->serialization, 'YAML of '.$pathobject->label)
	-> Show;
      last SWITCH;
    };

    ($id == $PATH_TYPE) and do {
      my $type = ref($datapage->{pathlist}->GetPage($datapage->{pathlist}->GetSelection)->{path});
      $type =~ s{Demeter::}{};
      $datapage->{statusbar}->SetStatusText("This path is a $type");
      last SWITCH;
    };

    ($id == $PATH_FSPATH) and do {
      $datapage -> quickfs;
      last SWITCH;
    };

    ($id == $PATH_RENAME) and do {
      $datapage->{pathlist}->RenameSelection;
      last SWITCH;
    };

    ($id == $PATH_ADD) and do {
      my $param_dialog = Demeter::UI::Artemis::Data::AddParameter->new($datapage);
      my $result = $param_dialog -> ShowModal;
      if ($result == wxID_CANCEL) {
	$datapage->{statusbar}->SetStatusText("Path parameter editing cancelled.");
	return;
      };
      my ($param, $me, $how) = ($param_dialog->{param}, $param_dialog->{me}->GetValue, $param_dialog->{apply}->GetSelection);
      $datapage->add_parameters($param, $me, $how);
      last SWITCH;
    };

    (($id == $PATH_EXPORT_FEFF) or ($id == $PATH_EXPORT_DATA) or ($id == $PATH_EXPORT_EACH) or ($id == $PATH_EXPORT_MARKED)) and do {
      $datapage->export_pp($id);
      last SWITCH;
    };

    (($id == $PATH_SAVE_K) or ($id == $PATH_SAVE_R) or ($id == $PATH_SAVE_Q)) and do {
      $datapage->save_path($id);
      last SWITCH;
    };


    (($id == $MARK_ALL)    or ($id == $MARK_NONE)   or ($id == $MARK_INVERT) or ($id == $MARK_REGEXP) or
     ($id == $MARK_SS)     or ($id == $MARK_MS)     or ($id == $MARK_HIGH)   or ($id == $MARK_MID)    or ($id == $MARK_LOW)    or
     ($id == $MARK_RBELOW) or ($id == $MARK_RABOVE) or ($id == $MARK_BEFORE) or ($id == $MARK_AFTER)  or
     ($id == $MARK_INC)    or ($id == $MARK_EXC)) and do {
      $datapage->mark($id);
      last SWITCH;
    };

    #(($id == $INCLUDE_ALL)    or ($id == $EXCLUDE_ALL)    or ($id == $INCLUDE_INVERT) or
    # ($id == $INCLUDE_MARKED) or ($id == $EXCLUDE_MARKED) or ($id == $EXCLUDE_AFTER) or
    # ($id == $INCLUDE_SS)     or ($id == $INCLUDE_HIGH)   or ($id == $INCLUDE_R)) and do {
    #   $datapage->include($id);
    #   last SWITCH;
    #};

    #(($id == $DISCARD_THIS)     or ($id == $DISCARD_ALL)      or ($id == $DISCARD_MARKED) or
    # ($id == $DISCARD_UNMARKED) or ($id == $DISCARD_EXCLUDED) or ($id == $DISCARD_AFTER)  or
    # ($id == $DISCARD_MS)       or ($id == $DISCARD_LOW  )    or ($id == $DISCARD_R)        ) and do {
    #   $datapage->discard($id);
    #   last SWITCH;
    #};

    ($id == $ACTION_TRANSFER) and do {
      $datapage->OnTransferButton;
      last SWITCH;
    };

    ($id == $ACTION_VPATH) and do {
      $datapage->OnMakeVPathButton;
      last SWITCH;
    };

    ($id == $ACTION_INCLUDE) and do {
      $datapage->include('marked');
      last SWITCH;
    };

    ($id == $ACTION_EXCLUDE) and do {
      $datapage->include('marked_none');
      last SWITCH;
    };

    ($id == $DISCARD_THIS) and do {
      $datapage->discard('this');
      last SWITCH;
    };
    ($id == $ACTION_DISCARD) and do {
      $datapage->discard('marked');
      last SWITCH;
    };

    ($id == $PATH_HISTO) and do {
      my $histo_dialog = Demeter::UI::Artemis::Data::Histogram->new($datapage);
      my $result = $histo_dialog -> ShowModal;
      if ($result == wxID_CANCEL) {
	$datapage->{statusbar}->SetStatusText("Cancelled histogram creation.");
	return;
      };
      $datapage -> process_histogram($histo_dialog);
      last SWITCH;
    };


    ($id == $PATH_EXP_LABEL) and do {
      $datapage->{statusbar}->SetStatusText($Demeter::UI::Artemis::Pathexplanation{label});
      last SWITCH;
    };
    ($id == $PATH_EXP_N) and do {
      $datapage->{statusbar}->SetStatusText($Demeter::UI::Artemis::Path::explanation{n});
      last SWITCH;
    };
    ($id == $PATH_EXP_S02) and do {
      $datapage->{statusbar}->SetStatusText($Demeter::UI::Artemis::Path::explanation{s02});
      last SWITCH;
    };
    ($id == $PATH_EXP_E0) and do {
      $datapage->{statusbar}->SetStatusText($Demeter::UI::Artemis::Path::explanation{e0});
      last SWITCH;
    };
    ($id == $PATH_EXP_DELR) and do {
      $datapage->{statusbar}->SetStatusText($Demeter::UI::Artemis::Path::explanation{delr});
      last SWITCH;
    };
    ($id == $PATH_EXP_SIGMA2) and do {
      $datapage->{statusbar}->SetStatusText($Demeter::UI::Artemis::Path::explanation{sigma2});
      last SWITCH;
    };
    ($id == $PATH_EXP_EI) and do {
      $datapage->{statusbar}->SetStatusText($Demeter::UI::Artemis::Path::explanation{ei});
      last SWITCH;
    };
    ($id == $PATH_EXP_THIRD) and do {
      $datapage->{statusbar}->SetStatusText($Demeter::UI::Artemis::Path::explanation{third});
      last SWITCH;
    };
    ($id == $PATH_EXP_FOURTH) and do {
      $datapage->{statusbar}->SetStatusText($Demeter::UI::Artemis::Path::explanation{fourth});
      last SWITCH;
    };


  };
};

# sub show_text {
#   my ($parent, $content, $title) = @_;
#   my $show = Wx::Dialog->new($parent, -1, $title, wxDefaultPosition, [450,350],
# 			     wxOK|wxICON_INFORMATION);
#   my $box  = Wx::BoxSizer->new( wxVERTICAL );
#   my $text = Wx::TextCtrl->new($show, -1, q{}, wxDefaultPosition, wxDefaultSize,
# 			       wxVSCROLL|wxHSCROLL|wxTE_MULTILINE|wxTE_READONLY|wxNO_BORDER);
#   $text -> SetFont(Wx::Font->new( 10, wxTELETYPE, wxNORMAL, wxNORMAL, 0, "" ) );
#   $text -> SetValue($content);
#   $box  -> Add($text, 1, wxGROW|wxALL, 5);
#   my $button = Wx::Button->new($show, wxID_OK, "OK", wxDefaultPosition, wxDefaultSize, 0,);
#   $box -> Add($button, 0, wxGROW|wxALL, 5);
#   $show -> SetSizer( $box );
#   $show -> ShowModal;
# };

sub Rename {
  my ($datapage) = @_;
  my $dnum = $datapage->{dnum};
  (my $id = $dnum) =~ s{data}{};

  my $name = $datapage->{data}->name;
  my $ted = Wx::TextEntryDialog->new($datapage, "Enter a new name for \"$name\":", "Rename \"$name\"", q{}, wxOK|wxCANCEL, Wx::GetMousePosition);
  if ($ted->ShowModal == wxID_CANCEL) {
    $datapage->{statusbar}->SetStatusText("Data renaming cancelled.");
    return;
  };
  my $newname = $ted->GetValue;
  $datapage->{data}->name($newname);
  $datapage->{name}->SetLabel($newname);

  my $plotlist = $Demeter::UI::Artemis::frames{Plot}->{plotlist};
  foreach my $i (0 .. $plotlist->GetCount-1) {
    if ($datapage->{data}->group eq $plotlist->GetClientData($i)->group) {
      my $checked = $plotlist->IsChecked($i);
      $plotlist->SetString($i, "Data: ".$newname);
      $plotlist->Check($i, $checked);
    };
  };

  $Demeter::UI::Artemis::frames{main}->{$dnum}->SetLabel("Show $newname");
};

sub set_degens {
  my ($self, $how) = @_;
  foreach my $n (0 .. $self->{pathlist}->GetPageCount-1) {
    my $page = $self->{pathlist}->GetPage($n);
    my $pathobject = $self->{pathlist}->{LIST}->GetClientData($n)->{path};
    my $value = ($how eq $DATA_DEGEN_N) ? $pathobject->degen : 1;
    $page->{pp_n} -> SetValue($value);
    $pathobject->n($value);
  };
};

## how = 0 : each path this feff
## how = 1 : each path this data
## how = 2 : each path each data   (not yet)
## how = 3 : marked paths          (not yet)
sub add_parameters {
  my ($self, $param, $me, $how) = @_;
  my $displayed_path = $self->{pathlist}->GetCurrentPage;
  my $displayed_feff = $displayed_path->{path}->parent->group;
  my $which = q{};
  if ($how < 2) {
    foreach my $n (0 .. $self->{pathlist}->GetPageCount-1) {
      my $pagefeff = $self->{pathlist}->GetPage($n)->{path}->parent->group;
      next if (($how == 0) and ($pagefeff ne $displayed_feff));
      $self->{pathlist}->GetPage($n)->{"pp_$param"}->SetValue($me);
    };
    $which = ($how == 0) ? "every path in this Feff calculation" : "every path in this data set";
  } elsif ($how == 2) {
    foreach my $fr (keys %Demeter::UI::Artemis::frames) {
      next if ($fr !~ m{data});
      my $datapage = $Demeter::UI::Artemis::frames{$fr};
      foreach my $n (0 .. $datapage->{pathlist}->GetPageCount-1) {
	$datapage->{pathlist}->GetPage($n)->{"pp_$param"}->SetValue($me);
      };
      $which = "every path in every data set";
    };
  } else {
    foreach my $n (0 .. $self->{pathlist}->GetPageCount-1) {
      next if (not $self->{pathlist}->IsChecked($n));
      $self->{pathlist}->GetPage($n)->{"pp_$param"}->SetValue($me);
    };
    $which = "the marked paths";
  };
  $self->{statusbar}->SetStatusText("Set $param to \"$me\" for $which." );
};

sub export_pp {
  my ($self, $mode) = @_;
  my $how = ($mode == $PATH_EXPORT_FEFF)   ? 0
          : ($mode == $PATH_EXPORT_DATA)   ? 1
          : ($mode == $PATH_EXPORT_EACH)   ? 2
          : ($mode == $PATH_EXPORT_MARKED) ? 3
	  :                                  $mode;
  my $npaths = $self->{pathlist}->GetPageCount-1;
  my $displayed_path = $self->{pathlist}->GetCurrentPage;
  my $displayed_feff = $displayed_path->{path}->parent->group;

  foreach my $i (0 .. $npaths) {
    next if ($self->{pathlist}->GetSelection == $i);
    foreach my $pp (qw(s02 e0 delr sigma2 ei third fourth)) {
      $self->add_parameters($pp, $displayed_path->{"pp_$pp"}->GetValue, $how);
    };
  };
  my $which = ('each path in this Feff calculation',
	       'each path in this data set',
	       'each path in each data set',
	       'the marked paths')[$how];
  $self->{statusbar}->SetStatusText("Exported these path parameters to $which." );
};

sub save_path {
  my ($self, $mode, $filename) = @_;
  my $space = (lc($mode) =~ m{\A[kqr]\z}) ? lc($mode)
            : ($mode == $PATH_SAVE_K)     ? 'k'
            : ($mode == $PATH_SAVE_R)     ? 'r'
            : ($mode == $PATH_SAVE_Q)     ? 'q'
	    :                               'k';
  my $displayed_path = $self->{pathlist}->GetCurrentPage;
  my $path = $displayed_path->{path};
  if (not $filename) {
    my $suggest = $path->name;
    $suggest =~ s{\A\s+}{};
    $suggest =~ s{\s+\z}{};
    $suggest =~ s{\s+}{_}g;
    $suggest = sprintf("%s.%s%s", $suggest, $space, 'sp');
    my $suff = sprintf("%s%s", $space, 'sp');
    my $fd = Wx::FileDialog->new( $self, "Save path", cwd, $suggest,
				  "Demeter fitting project (*.$suff)|*.$suff|All files|*.*",
				  wxFD_SAVE|wxFD_CHANGE_DIR|wxFD_OVERWRITE_PROMPT,
				  wxDefaultPosition);
    if ($fd->ShowModal == wxID_CANCEL) {
      $self->{statusbar}->SetStatusText("Saving path cancelled.");
      return;
    };
    $filename = File::Spec->catfile($fd->GetDirectory, $fd->GetFilename);
  };
  $path->save($space, $filename);
  $self->{statusbar}->SetStatusText("Saved path \"".$path->name."\"to $space space." );
};


sub mark {
  my ($self, $mode) = @_;

  $self->{statusbar}->SetStatusText("No paths have been assigned to this data yet."),
    return if ($self->{pathlist}->GetPage(0) eq $self->{pathlist}->{initial});

  my $how = ($mode !~ m{$NUMBER})   ? $mode
          : ($mode == $MARK_ALL)    ? 'all'
          : ($mode == $MARK_NONE)   ? 'none'
          : ($mode == $MARK_INVERT) ? 'invert'
          : ($mode == $MARK_REGEXP) ? 'regexp'
          : ($mode == $MARK_SS)     ? 'ss'
          : ($mode == $MARK_MS)     ? 'ms'
          : ($mode == $MARK_HIGH)   ? 'high'
          : ($mode == $MARK_MID)    ? 'mid'
          : ($mode == $MARK_LOW)    ? 'low'
          : ($mode == $MARK_RBELOW) ? 'shorter'
          : ($mode == $MARK_RABOVE) ? 'longer'
          : ($mode == $MARK_BEFORE) ? 'before'
          : ($mode == $MARK_AFTER)  ? 'after'
          : ($mode == $MARK_INC)    ? 'included'
          : ($mode == $MARK_EXC)    ? 'excluded'
          :                            $mode;
 SWITCH: {
    (($how eq 'all') or ($how eq 'none')) and do {
      my $onoff = ($how eq 'all') ? 1 : 0;
      foreach my $i (0 .. $self->{pathlist}->GetPageCount-1) {
	$self->{pathlist}->Check($i, $onoff);
      };
      my $word = ($how eq 'all') ? 'Marked' : 'Unmarked';
      $self->{statusbar}->SetStatusText("$word all paths.");
      last SWITCH;
    };
    ($how eq 'invert') and do {
      foreach my $i (0 .. $self->{pathlist}->GetPageCount-1) {
	my $this = $self->{pathlist}->IsChecked($i);
	$self->{pathlist}->Check($i, not $this);
      };
      $self->{statusbar}->SetStatusText("Inverted all marks.");
      last SWITCH;
    };
    ($how eq 'regexp') and do {
      my $regex = q{};
      my $ted = Wx::TextEntryDialog->new( $self, "Mark paths matching this regular expression:", "Enter a regular expression", q{}, wxOK|wxCANCEL, Wx::GetMousePosition);
      if ($ted->ShowModal == wxID_CANCEL) {
	$self->{statusbar}->SetStatusText("Path marking cancelled.");
	return;
      };
      $regex = $ted->GetValue;
      my $re;
      my $is_ok = eval '$re = qr/$regex/';
      if (not $is_ok) {
	$self->{PARENT}->{statusbar}->SetStatusText("Oops!  \"$regex\" is not a valid regular expression");
	return;
      };
      foreach my $i (0 .. $self->{pathlist}->GetPageCount-1) {
	$self->{pathlist}->Check($i, 1) if ($self->{pathlist}->GetPageText($i) =~ m{$re});
      };
      $self->{statusbar}->SetStatusText("Marked all paths matching /$regex/.");
      last SWITCH;
    };

    ($how eq 'ss') and do {
      foreach my $i (0 .. $self->{pathlist}->GetPageCount-1) {
	my $path = $self->{pathlist}->GetPage($i)->{path};
	$self->{pathlist}->Check($i, 1) if ($path->sp->nleg == 2);
      };
      $self->{statusbar}->SetStatusText("Marked all single scattering paths.");
      last SWITCH;
    };
    ($how eq 'ms') and do {
      foreach my $i (0 .. $self->{pathlist}->GetPageCount-1) {
	my $path = $self->{pathlist}->GetPage($i)->{path};
	$self->{pathlist}->Check($i, 1) if ($path->sp->nleg > 2);
      };
      $self->{statusbar}->SetStatusText("Marked all multiple scattering paths.");
      last SWITCH;
    };
    ($how eq 'high') and do {
      foreach my $i (0 .. $self->{pathlist}->GetPageCount-1) {
	my $path = $self->{pathlist}->GetPage($i)->{path};
	$self->{pathlist}->Check($i, 1) if ($path->sp->weight==2);
      };
      $self->{statusbar}->SetStatusText("Marked all high importance paths.");
      last SWITCH;
    };
    ($how eq 'mid') and do {
      foreach my $i (0 .. $self->{pathlist}->GetPageCount-1) {
	my $path = $self->{pathlist}->GetPage($i)->{path};
	$self->{pathlist}->Check($i, 1) if ($path->sp->weight==1);
      };
      $self->{statusbar}->SetStatusText("Marked all mid importance paths.");
      last SWITCH;
    };
    ($how eq 'low') and do {
      foreach my $i (0 .. $self->{pathlist}->GetPageCount-1) {
	my $path = $self->{pathlist}->GetPage($i)->{path};
	$self->{pathlist}->Check($i, 1) if ($path->sp->weight==0);
      };
      $self->{statusbar}->SetStatusText("Marked all low importance paths.");
      last SWITCH;
    };
    (($how eq 'longer') or ($how eq 'shorter')) and do {
      my $ted = Wx::TextEntryDialog->new( $self, "Mark paths $how than this path length:", "Enter a path length", q{}, wxOK|wxCANCEL, Wx::GetMousePosition);
      if ($ted->ShowModal == wxID_CANCEL) {
	$self->{statusbar}->SetStatusText("Path marking cancelled.");
	return;
      };
      my $r = $ted->GetValue;
      if ($r !~ m{$NUMBER}) {
	$self->{statusbar}->SetStatusText("Oops!  That wasn't a number.");
	return;
      };
      foreach my $i (0 .. $self->{pathlist}->GetPageCount-1) {
	my $path = $self->{pathlist}->GetPage($i)->{path};
	$self->{pathlist}->Check($i, 1) if (($how eq 'shorter') and ($path->sp->fuzzy < $r));
	$self->{pathlist}->Check($i, 1) if (($how eq 'longer')  and ($path->sp->fuzzy > $r));
      };
      $self->{statusbar}->SetStatusText("Marked all paths $how than $r " . chr(197) . '.');
      last SWITCH;
    };

    ($how eq 'before') and do {
      my $sel = $self->{pathlist}->GetSelection;
      foreach my $i (0 .. $self->{pathlist}->GetPageCount-1) {
	last if ($i > $sel);
	$self->{pathlist}->Check($i, 1);
      };
      $self->{statusbar}->SetStatusText("Marked this path and all paths before this one.");
      last SWITCH;
    };
    ($how eq 'after') and do {
      my $sel = $self->{pathlist}->GetSelection;
      foreach my $i (0 .. $self->{pathlist}->GetPageCount-1) {
	next if ($i <= $sel);
	$self->{pathlist}->Check($i, 1);
      };
      $self->{statusbar}->SetStatusText("Marked all paths after this one.");
      last SWITCH;
    };

    ($how eq 'included') and do {
      foreach my $i (0 .. $self->{pathlist}->GetPageCount-1) {
	my $path = $self->{pathlist}->GetPage($i)->{path};
	$self->{pathlist}->Check($i, 1) if $path->include;
      };
      $self->{statusbar}->SetStatusText("Marked all paths included in the fit.");
      last SWITCH;
    };

    ($how eq 'excluded') and do {
      foreach my $i (0 .. $self->{pathlist}->GetPageCount-1) {
	my $path = $self->{pathlist}->GetPage($i)->{path};
	$self->{pathlist}->Check($i, 1) if not $path->include;
      };
      $self->{statusbar}->SetStatusText("Marked all paths excluded from the fit.");
      last SWITCH;
    };
  };
};

sub include {
  my ($self, $mode) = @_;
  my $how = ($mode !~ m{$NUMBER})      ? $mode
          : ($mode == $INCLUDE_ALL)    ? 'all'
          : ($mode == $EXCLUDE_ALL)    ? 'none'
          : ($mode == $INCLUDE_INVERT) ? 'invert'
          : ($mode == $INCLUDE_MARKED) ? 'marked'
          : ($mode == $EXCLUDE_MARKED) ? 'marked_none'
          : ($mode == $EXCLUDE_AFTER)  ? 'after'
          : ($mode == $INCLUDE_SS)     ? 'ss'
          : ($mode == $INCLUDE_HIGH)   ? 'high'
          : ($mode == $INCLUDE_R)      ? 'r'
          :                              $mode;

  my $npaths = $self->{pathlist}->GetPageCount-1;
 SWITCH: {
    ($how eq 'all') and do {
      foreach my $i (0 .. $npaths) {
	my $pathpage = $self->{pathlist}->{LIST}->GetClientData($i);
	$pathpage->{include}->SetValue(1);
	$pathpage->include_label(0,$i);
      };
      $self->{statusbar}->SetStatusText("Included all paths in the fit.");
      last SWITCH;
    };

    ($how eq 'none') and do {
      foreach my $i (0 .. $npaths) {
	my $pathpage = $self->{pathlist}->{LIST}->GetClientData($i);
	$pathpage->{include}->SetValue(0);
	$pathpage->include_label(0,$i);
      };
      $self->{statusbar}->SetStatusText("Excluded all paths from the fit.");
      last SWITCH;
    };

    ($how eq 'invert') and do {
      foreach my $i (0 .. $npaths) {
	my $pathpage = $self->{pathlist}->{LIST}->GetClientData($i);
	my $onoff = ($pathpage->{include}->IsChecked) ? 0 : 1;
	$pathpage->{include}->SetValue($onoff);
	$pathpage->include_label(0,$i);
      };
      $self->{statusbar}->SetStatusText("Inverted which paths are included in the fit.");
      last SWITCH;
    };

    ($how eq 'marked') and do {
      foreach my $i (0 .. $npaths) {
	my $pathpage = $self->{pathlist}->{LIST}->GetClientData($i);
	next if not $self->{pathlist}->IsChecked($i);
	$pathpage->{include}->SetValue(1);
	$pathpage->include_label(0,$i);
      };
      $self->{statusbar}->SetStatusText("Included marked paths in the fit.");
      last SWITCH;
    };

    ($how eq 'marked_none') and do {
      foreach my $i (0 .. $npaths) {
	my $pathpage = $self->{pathlist}->{LIST}->GetClientData($i);
	next if not $self->{pathlist}->IsChecked($i);
	$pathpage->{include}->SetValue(0);
	$pathpage->include_label(0,$i);
      };
      $self->{statusbar}->SetStatusText("Excluded marked paths from the fit.");
      last SWITCH;
    };

    ($how eq 'after') and do {
      my $sel = $self->{pathlist}->GetSelection;
      foreach my $i (0 .. $npaths) {
	next if ($i <= $sel);
	my $pathpage = $self->{pathlist}->{LIST}->GetClientData($i);
	$pathpage->{include}->SetValue(0);
	$pathpage->include_label(0,$i);
      };
      $self->{statusbar}->SetStatusText("Excluded all paths after the one currently displayed from the fit.");
      last SWITCH;
    };

    ($how eq 'ss') and do {
      foreach my $i (0 .. $npaths) {
	my $pathpage = $self->{pathlist}->{LIST}->GetClientData($i);
	my $path = $pathpage->{path};
	next if not ($path->sp->nleg == 2);
	$pathpage->{include}->SetValue(1);
	$pathpage->include_label(0,$i);
      };
      $self->{statusbar}->SetStatusText("Included all single scattering paths in the fit.");
      last SWITCH;
    };

    ($how eq 'high') and do {
      foreach my $i (0 .. $npaths) {
	my $pathpage = $self->{pathlist}->{LIST}->GetClientData($i);
	my $path = $pathpage->{path};
	next if not ($path->sp->weight == 2);
	$pathpage->{include}->SetValue(1);
	$pathpage->include_label(0,$i);
      };
      $self->{statusbar}->SetStatusText("Included all high importance paths in the fit.");
      last SWITCH;
    };

    ($how eq 'r') and do {
      my $ted = Wx::TextEntryDialog->new( $self, "Include shorter than this path length:", "Enter a path length", q{}, wxOK|wxCANCEL, Wx::GetMousePosition);
      if ($ted->ShowModal == wxID_CANCEL) {
	$self->{statusbar}->SetStatusText("Path inclusion cancelled.");
	return;
      };
      my $r = $ted->GetValue;
      if ($r !~ m{$NUMBER}) {
	$self->{statusbar}->SetStatusText("Oops!  That wasn't a number.");
	return;
      };
      foreach my $i (0 .. $npaths) {
	my $pathpage = $self->{pathlist}->{LIST}->GetClientData($i);
	my $path = $pathpage->{path};
	next if ($path->sp->fuzzy > $r);
	$pathpage->{include}->SetValue(1);
	$pathpage->include_label(0,$i);
      };
      $self->{statusbar}->SetStatusText("Included all paths shorter than $r " . chr(197) . '.');
      last SWITCH;
    };


  };
};

sub discard_data {
  my ($self, $force) = @_;
  my $dataobject = $self->{data};

  if (not $force) {
    my $yesno = Wx::MessageDialog->new($self, "Do you really wish to discard this data set?",
				       "Discard?", wxYES_NO);
    return if ($yesno->ShowModal == wxID_NO);
  };

  ## remove data and its paths & VPaths from the plot list
  my $plotlist = $Demeter::UI::Artemis::frames{Plot}->{plotlist};
  foreach my $i (0 .. $plotlist->GetCount-1) {
    if ($self->{data}->group eq $plotlist->GetClientData($i)->data->group) {
      $plotlist->Delete($i);
    };
  };

  ## get rid of all the paths
  $self->discard('all');

  ## remove the button from the data tool bar
  my $dnum = $self->{dnum};
  (my $id = $dnum) =~ s{data}{};
  $Demeter::UI::Artemis::frames{main}->{$dnum}->Destroy;

  ## remove the frame with the datapage
  $Demeter::UI::Artemis::frames{$dnum}->Hide;
  delete $Demeter::UI::Artemis::frames{$dnum};
  ## that's not quite right!

  ## destroy the data object
  $dataobject->DEMOLISH;
};

sub discard {
  my ($self, $mode) = @_;
  my $how = ($mode !~ m{$NUMBER})        ? $mode
          : ($mode == $DISCARD_THIS)     ? 'this'
          : ($mode == $DISCARD_ALL)      ? 'all'
          : ($mode == $DISCARD_MARKED)   ? 'marked'
          : ($mode == $DISCARD_UNMARKED) ? 'unmarked'
          : ($mode == $DISCARD_EXCLUDED) ? 'excluded'
	  : ($mode == $DISCARD_AFTER)    ? 'after'
	  : ($mode == $DISCARD_MS)       ? 'ms'
          : ($mode == $DISCARD_LOW)      ? 'low'
          : ($mode == $DISCARD_R)        ? 'r'
          :                                $mode;
  my $npaths = $self->{pathlist}->GetPageCount-1;
  my $sel    = $self->{pathlist}->GetSelection;
  my $page   = $self->{pathlist}->GetPage($sel);
  my $text   = q{};
  my @count  = reverse(0 .. $npaths);

 SWITCH: {
    ($how eq 'this') and do {
      my $path = $self->{pathlist}->GetPage->{path};
      $self->{pathlist}->DeletePage($sel);
      $path->DEMOLISH;
      $text = "Discarded the path that was displayed.";
      last SWITCH;
    };

    ($how eq 'all') and do {
      $self->{pathlist}->Clear;
      $text = "Discarded all paths.";
      last SWITCH;
    };

    ($how eq 'marked') and do {
      foreach my $i (@count) {
	if ($self->{pathlist}->IsChecked($i)) {
	  $self->{pathlist}->DeletePage($i);
	  ($sel = 0) if ($sel = $i);
	};
      };
      $text = "Discarded all paths that were marked.";
      last SWITCH;
    };

    ($how eq 'unmarked') and do {
      foreach my $i (@count) {
	if (not $self->{pathlist}->IsChecked($i)) {
	  $self->{pathlist}->DeletePage($i);
	  ($sel = 0) if ($sel = $i);
	};
      };
      $text = "Discarded all unmarked paths.";
      last SWITCH;
    };

    ($how eq 'excluded') and do {
      foreach my $i (@count) {
	if (not $self->{pathlist}->GetPage($i)->{path}->include) {
	  $self->{pathlist}->DeletePage($i);
	  ($sel = 0) if ($sel = $i);
	};
      };
      $text = "Discarded paths which were not included in the fit.";
      last SWITCH;
    };

    ($how eq 'after') and do {
      foreach my $i (@count) {
	$self->{pathlist}->DeletePage($i) if ($i>$sel);
      };
      $text = "Discarded all paths after the one currently displayed.";
      last SWITCH;
    };

    ($how eq 'ms') and do {
      foreach my $i (@count) {
	if (not $self->{pathlist}->GetPage($i)->{path}->sp->nleg == 2) {
	  $self->{pathlist}->DeletePage($i);
	  ($sel = 0) if ($sel = $i);
	};
      };
      $text = "Discarded all multiple scattering paths.";
      last SWITCH;
    };

    ($how eq 'low') and do {
      foreach my $i (@count) {
	if ($self->{pathlist}->GetPage($i)->{path}->sp->weight < 1) {
	  $self->{pathlist}->DeletePage($i);
	  ($sel = 0) if ($sel = $i);
	};
      };
      $text = "Discarded all low importance paths.";
      last SWITCH;
    };

    ($how eq 'r') and do {
      my $ted = Wx::TextEntryDialog->new( $self, "Discard paths longer than this path length:", "Enter a path length", q{}, wxOK|wxCANCEL, Wx::GetMousePosition);
      if ($ted->ShowModal == wxID_CANCEL) {
	$self->{statusbar}->SetStatusText("Path discarding cancelled.");
	return;
      };
      my $r = $ted->GetValue;
      if ($r !~ m{$NUMBER}) {
	$self->{statusbar}->SetStatusText("Oops!  That wasn't a number.");
	return;
      };
      foreach my $i (@count) {
	if ($self->{pathlist}->GetPage($i)->{path}->sp->fuzzy > $r) {
	  $self->{pathlist}->DeletePage($i);
	  ($sel = 0) if ($sel = $i);
	};
      };
      $text = "Discarded all paths longer that $r " . chr(197) . '.';
    };
  };
  $self->{statusbar}->SetStatusText($text);
  $self->{pathlist}->InitialPage if (not $self->{pathlist}->{VIEW});
};

# sub sum {
#   my ($self, $mode) = @_;
#   my $how = ($mode == $SUM_INCLUDED) ? 'included'
#           : ($mode == $SUM_MARKED)   ? 'marked'
#           : ($mode == $SUM_IM)       ? 'included and marked'
#           :                            $mode;
#   print "summing $how\n";
# };

sub transfer {
  my ($self, $event) = @_;
  my $plotlist  = $Demeter::UI::Artemis::frames{Plot}->{plotlist};
  my $name      = $self->{data}->name;
  my $found     = 0;
  my $thisgroup = $self->{data}->group;
  foreach my $i (0 .. $plotlist->GetCount - 1) {
    if ($thisgroup eq $plotlist->GetClientData($i)->group) {
      $found = 1;
      last;
    };
  };
  if ($found) {
    $self->{statusbar} -> SetStatusText("\"$name\" is already in the plotting list.");
    return;
  };
  $plotlist->Append("Data: $name");
  my $i = $plotlist->GetCount - 1;
  $plotlist->SetClientData($i, $self->{data});
  $plotlist->Check($i,1);
  $self->{statusbar} -> SetStatusText("Transfered data set \"$name\" to the plotting list.");
};


sub process_histogram {
  my ($datapage, $histo_dialog) = @_;
  my $pathpage = $datapage->{pathlist}->GetPage($datapage->{pathlist}->GetSelection);
  my $pathname = $pathpage->{path}->name;
  my $sp = $pathpage->{path}->sp;
  my $common = [data=>$datapage->{data}];

  ## -------- from file:
  if ($histo_dialog->{filesel}) {
    my ($file, $rmin, $rmax, $xcol, $ycol, $amp, $scale) = 
      ($histo_dialog->{filepicker} -> GetTextCtrl -> GetValue,
       $histo_dialog->{filermin}   -> GetValue,
       $histo_dialog->{filermax}   -> GetValue,
       $histo_dialog->{filexcol}   -> GetValue,
       $histo_dialog->{fileycol}   -> GetValue,
       $histo_dialog->{fileamp}    -> GetValue,
       $histo_dialog->{filescale}  -> GetValue,
      );
    carp("$file does not exist"), return if (not -e $file);
    carp("$file cannot be read"), return if (not -r $file);
    my ($rx, $ry) = $sp->histogram_from_file($file, $xcol, $ycol, $rmin, $rmax);
    my $paths = $sp -> make_histogram($rx, $ry, $amp, $scale, $common);

    my $id = $datapage->{pathlist}->GetSelection;
    $datapage->{pathlist}->DeletePage($id);
    #$datapage->{pathlist}->SetSelection($id);
    foreach my $p (@$paths) {
      my $histo_name = '[' . $p->parent->name . '] ' . $p->name;
      my $page = Demeter::UI::Artemis::Path->new($datapage->{pathlist}, $p, $datapage);
      $datapage->{pathlist}->AddPage($page, $histo_name, 1, 0);
      #$page->include_label;
    };
    $Demeter::UI::Artemis::frames{Plot}->{VPaths}->add_named_vpath("histogram from $pathname", @$paths);

    my $gdsframe = $Demeter::UI::Artemis::frames{GDS};
    $gdsframe  -> put_param('guess', $amp,   '1');
    $gdsframe  -> put_param('guess', $scale, '0') if $scale;
    $gdsframe  -> clear_highlight;
    my $re = ($scale)  ?  '\A(?:'.$amp.'|'.$scale.')\z'  :  '\A(?:'.$amp.')\z';
    $gdsframe  -> set_highlight($re);
    $gdsframe  -> Show(1);
    $Demeter::UI::Artemis::frames{main} -> {toolbar}->ToggleTool(1,1);
    $gdsframe  -> {toolbar}->ToggleTool(2,1);

  } elsif ($histo_dialog->{filesel}) {
    printf("%s  %s  %s  %s\n",
	   $sp,
	   $histo_dialog->{gammargrid}->GetValue,
	   $histo_dialog->{gammarmin}->GetValue,
	   $histo_dialog->{gammarmax}->GetValue);
  };
};


my @element_list = qw(h he li be b c n o f ne na mg al si p s cl ar k ca
		      sc ti v cr mn fe co ni cu zn ga ge as se br kr rb
		      sr y zr nb mo tc ru rh pd ag cd in sn sb te i xe cs
		      ba la ce pr nd pm sm eu gd tb dy ho er tm yb lu hf
		      ta w re os ir pt au hg tl pb bi po at rn fr ra ac
		      th pa u np pu);
my $element_regexp = $reopt->list2re(@element_list);

sub quickfs {
  my ($datapage) = @_;

  my $dialog = Demeter::UI::Artemis::Data::Quickfs->new($datapage);
  my $result = $dialog -> ShowModal;
  if ($result == wxID_CANCEL) {
    $datapage->{statusbar}->SetStatusText("Cancelled quick first shell model creation.");
    return;
  };

  my $busy = Wx::BusyCursor->new();
  my ($abs, $scat, $distance, $edge) = ($dialog->{abs}->GetValue,
					$dialog->{scat}->GetValue,
					$dialog->{distance}->GetValue,
					$dialog->{edge}->GetStringSelection,);

  if (lc($abs) !~ m{\A$element_regexp\z}) {
    $datapage->{statusbar} -> SetStatusText("Absorber $abs is not a valid element symbol.");
    return;
  };
  if (lc($scat) !~ m{\A$element_regexp\z}) {
    $datapage->{statusbar} -> SetStatusText("Scatterer $scat is not a valid element symbol.");
    return;
  };

  my $firstshell = Demeter::FSPath->new();
  $firstshell -> set(abs       => $abs,
		     scat      => $scat,
		     distance  => $distance,
		     edge      => $edge,
		     data      => $datapage->{data},
		    );
  $firstshell -> workspace(File::Spec->catfile($Demeter::UI::Artemis::frames{main}->{project_folder}, 'feff', $firstshell->parent->group));
  $firstshell -> _update('bft');
  $firstshell -> save_feff_yaml;
  $datapage->{pathlist}->DeletePage(0) if $datapage->{pathlist}->GetPage(0) =~ m{Panel};
  my $page = Demeter::UI::Artemis::Path->new($datapage->{pathlist}, $firstshell, $datapage);
  $datapage->{pathlist}->AddPage($page, "$abs - $scat", 1, 0);
  $page->{pp_n} -> SetValue(1);
  $page->{pp_label} -> SetValue(sprintf("%s-%s path at %s", $firstshell->absorber, $firstshell->scatterer, $firstshell->reff));

  $Demeter::UI::Artemis::frames{GDS}->put_gds($_) foreach (@{$firstshell->gds});

  autosave();

  undef $busy;

};


package Demeter::UI::Artemis::Data::DropTarget;

use Wx qw( :everything);
use base qw(Wx::DropTarget);
use Demeter::UI::Artemis::DND::PathDrag;
use Demeter::UI::Artemis::Path;

use Scalar::Util qw(looks_like_number);
use Regexp::List;
my $opt  = Regexp::List->new;

sub new {
  my $class = shift;
  my $this = $class->SUPER::new;

  my $data = Demeter::UI::Artemis::DND::PathDrag->new();
  $this->SetDataObject( $data );
  $this->{DATA} = $data;
  $this->{PARENT} = $_[0];
  $this->{BOOK}   = $_[1];

  return $this;
};

#sub data { $_[0]->{DATA} }
#sub textctrl { $_[0]->{TEXTCTRL} }

sub OnData {
  my ($this, $x, $y, $def) = @_;
  $this->GetData;		# this line is what transfers the data from the Source to the Target
  my $book  = $this->{BOOK};
  $book->DeletePage(0) if ($book->GetPage(0) =~ m{Panel});
  my $spref = $this->{DATA}->{Data};
  my $is_sspath = ($spref->[0] eq 'SSPath') ? 1 : 0;
  if ($is_sspath) {
    my $feff = $demeter->mo->fetch("Feff", $spref->[1]);
    my $name = $spref->[2];
    my $reff = $spref->[3];
    my $ipot = $spref->[4];
    if (not looks_like_number($reff)) {
      my $text = "Your distance, $reff, is not a number.  This arbitrary single scattering path cannot be created.";
      $this->{PARENT}->{statusbar}->SetStatusText($text);
      Wx::MessageDialog->new($this->{PARENT}, $text, "Error!", wxOK|wxICON_ERROR) -> ShowModal;
      return $def;
    };
    my $sspath = Demeter::SSPath->new(parent => $feff,
				      data   => $this->{PARENT}->{data},
				      reff   => $reff,
				      ipot   => $ipot
				     );
    my $label = $sspath->name;
    my $page = Demeter::UI::Artemis::Path->new($book, $sspath, $this->{PARENT});
    $book->AddPage($page, $label, 1, 0);
    $page->{pp_n}->SetValue(1);
    $sspath->make_name;
    $sspath->set(name=>$name, label=>$name) if ($name);
    $page->include_label;
  } else {			#  this is a normal path
    my @sparray = map { $demeter->mo->fetch("ScatteringPath", $_) } @$spref;
    foreach my $sp ( @sparray ) {
      my $thispath = Demeter::Path->new(
					parent => $sp->feff,
					data   => $this->{PARENT}->{data},
					sp     => $sp,
					degen  => $sp->n,
				       );
      my $label = $thispath->label;
      my $page = Demeter::UI::Artemis::Path->new($book, $thispath, $this->{PARENT});
      $book->AddPage($page, $label, 1, 0);
      $page->include_label;
    };
  };

  return $def;
};


1;


=head1 NAME

Demeter::UI::Artemis::Data - Data group interface for Artemis

=head1 VERSION

This documentation refers to Demeter version 0.3.

=head1 SYNOPSIS

This module provides a window for displaying Demeter's data interface,
which includes the L<Demeter::UI::Wx::CheckListBook> interface to the
paths associated with the data group.

=head1 CONFIGURATION


=head1 DEPENDENCIES

Demeter's dependencies are in the F<Bundle/DemeterBundle.pm> file.

=head1 BUGS AND LIMITATIONS

=over 4

=item *

Many things still missing from the menus

=item *

Replace data group without replacing paths.

=back

Please report problems to Bruce Ravel (bravel AT bnl DOT gov)

Patches are welcome.

=head1 AUTHOR

Bruce Ravel (bravel AT bnl DOT gov)

L<http://cars9.uchicago.edu/~ravel/software/>

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2009 Bruce Ravel (bravel AT bnl DOT gov). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
