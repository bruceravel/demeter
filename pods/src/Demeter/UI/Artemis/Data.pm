package  Demeter::UI::Artemis::Data;

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
use feature 'switch';

use Wx qw( :everything);
use base qw(Wx::Frame);
use Wx::Event qw(EVT_MENU EVT_CLOSE EVT_ICONIZE EVT_TOOL_ENTER EVT_CHECKBOX EVT_CHOICE
		 EVT_BUTTON EVT_ENTER_WINDOW EVT_LEAVE_WINDOW
		 EVT_HYPERLINK EVT_TEXT_ENTER EVT_LEFT_DOWN);
use Wx::DND;
use Wx::Perl::TextValidator;

use Wx::Perl::Carp;

use Demeter::UI::Artemis::Close;
use Demeter::UI::Artemis::Project;
use Demeter::UI::Artemis::Import;
use Demeter::UI::Artemis::Data::AddParameter;
use Demeter::UI::Artemis::Data::Quickfs;
use Demeter::UI::Artemis::DND::PathDrag;
use Demeter::UI::Artemis::ShowText;
use Demeter::UI::Wx::CheckListBook;
use Demeter::UI::Wx::SpecialCharacters qw(:all);

use Cwd;
use File::Basename;
use File::Spec;
use List::MoreUtils qw(firstidx any);
use YAML::Tiny;

my $windows  = [qw(hanning kaiser-bessel welch parzen sine)];
my $demeter  = $Demeter::UI::Artemis::demeter;
my $icon     = File::Spec->catfile(dirname($INC{"Demeter/UI/Artemis.pm"}), 'Athena', , 'icons', "bullseye.png");
my $bullseye = Wx::Bitmap->new($icon, wxBITMAP_TYPE_PNG);


use Demeter::Constants qw($NUMBER);
use Regexp::Assemble;
use Const::Fast;
const my $DATA_RENAME	      => Wx::NewId();
const my $DATA_DIFF	      => Wx::NewId();
const my $DATA_TRANSFER	      => Wx::NewId();
const my $DATA_VPATH	      => Wx::NewId();
const my $DATA_BALANCE	      => Wx::NewId();
const my $DATA_DEGEN_N	      => Wx::NewId();
const my $DATA_DEGEN_1	      => Wx::NewId();
const my $DATA_DISCARD	      => Wx::NewId();
const my $DATA_REPLACE	      => Wx::NewId();
const my $DATA_KMAXSUGEST     => Wx::NewId();
const my $DATA_EPSK	      => Wx::NewId();
const my $DATA_NIDP	      => Wx::NewId();
const my $DATA_SHOW	      => Wx::NewId();
const my $DATA_YAML	      => Wx::NewId();
const my $DATA_EXPORT	      => Wx::NewId();

const my $FIT_SAVE_K	      => Wx::NewId();
const my $FIT_SAVE_K1	      => Wx::NewId();
const my $FIT_SAVE_K2	      => Wx::NewId();
const my $FIT_SAVE_K3	      => Wx::NewId();
const my $FIT_SAVE_RM	      => Wx::NewId();
const my $FIT_SAVE_RR	      => Wx::NewId();
const my $FIT_SAVE_RI	      => Wx::NewId();
const my $FIT_SAVE_QM	      => Wx::NewId();
const my $FIT_SAVE_QR	      => Wx::NewId();
const my $FIT_SAVE_QI	      => Wx::NewId();

const my $PATH_TRANSFER	      => Wx::NewId();
const my $PATH_FSPATH	      => Wx::NewId();
const my $PATH_EMPIRICAL      => Wx::NewId();
const my $PATH_SU	      => Wx::NewId();
const my $PATH_RENAME	      => Wx::NewId();
const my $PATH_SHOW	      => Wx::NewId();
const my $PATH_ADD	      => Wx::NewId();
const my $PATH_CLONE	      => Wx::NewId();
const my $PATH_YAML	      => Wx::NewId();
const my $PATH_TYPE	      => Wx::NewId();
const my $PATH_4PARAM	      => Wx::NewId();

const my $PATH_EXPORT_FEFF    => Wx::NewId();
const my $PATH_EXPORT_DATA    => Wx::NewId();
const my $PATH_EXPORT_EACH    => Wx::NewId();
const my $PATH_EXPORT_MARKED  => Wx::NewId();

const my $DATA_SAVE_K	      => Wx::NewId();
const my $DATA_SAVE_R	      => Wx::NewId();
const my $DATA_SAVE_Q	      => Wx::NewId();

const my $PATH_SAVE_K	      => Wx::NewId();
const my $PATH_SAVE_R	      => Wx::NewId();
const my $PATH_SAVE_Q	      => Wx::NewId();

const my $PATH_EXP_LABEL      => Wx::NewId();
const my $PATH_EXP_N	      => Wx::NewId();
const my $PATH_EXP_S02	      => Wx::NewId();
const my $PATH_EXP_E0	      => Wx::NewId();
const my $PATH_EXP_DELR	      => Wx::NewId();
const my $PATH_EXP_SIGMA2     => Wx::NewId();
const my $PATH_EXP_EI	      => Wx::NewId();
const my $PATH_EXP_THIRD      => Wx::NewId();
const my $PATH_EXP_FOURTH     => Wx::NewId();

const my $MARKED_SAVE_K	      => Wx::NewId();
const my $MARKED_SAVE_K1      => Wx::NewId();
const my $MARKED_SAVE_K2      => Wx::NewId();
const my $MARKED_SAVE_K3      => Wx::NewId();
const my $MARKED_SAVE_RM      => Wx::NewId();
const my $MARKED_SAVE_RR      => Wx::NewId();
const my $MARKED_SAVE_RI      => Wx::NewId();
const my $MARKED_SAVE_QM      => Wx::NewId();
const my $MARKED_SAVE_QR      => Wx::NewId();
const my $MARKED_SAVE_QI      => Wx::NewId();

const my $MARK_ALL	      => Wx::NewId();
const my $MARK_NONE	      => Wx::NewId();
const my $MARK_INVERT	      => Wx::NewId();
const my $MARK_REGEXP	      => Wx::NewId();
const my $MARK_SS	      => Wx::NewId();
const my $MARK_MS	      => Wx::NewId();
const my $MARK_HIGH	      => Wx::NewId();
const my $MARK_MID	      => Wx::NewId();
const my $MARK_LOW	      => Wx::NewId();
const my $MARK_RBELOW	      => Wx::NewId();
const my $MARK_RABOVE	      => Wx::NewId();
const my $MARK_BEFORE	      => Wx::NewId();
const my $MARK_AFTER	      => Wx::NewId();
const my $MARK_INC	      => Wx::NewId();
const my $MARK_EXC	      => Wx::NewId();

const my $ACTION_INCLUDE      => Wx::NewId();
const my $ACTION_EXCLUDE      => Wx::NewId();
const my $ACTION_DISCARD      => Wx::NewId();
const my $ACTION_VPATH	      => Wx::NewId();
const my $ACTION_TRANSFER     => Wx::NewId();
const my $ACTION_AFTER	      => Wx::NewId();
const my $ACTION_NONEAFTER    => Wx::NewId();

const my $INCLUDE_MARKED      => Wx::NewId();
const my $EXCLUDE_MARKED      => Wx::NewId();

const my $DISCARD_THIS	      => Wx::NewId();
const my $DISCARD_MARKED      => Wx::NewId();
const my $DISCARD_UNMARKED    => Wx::NewId();

const my $WINDOW_HANNING      => Wx::NewId();
const my $WINDOW_KB           => Wx::NewId();
const my $WINDOW_WELCH        => Wx::NewId();
const my $WINDOW_PARZEN       => Wx::NewId();
const my $WINDOW_SINE         => Wx::NewId();

const my $DOCUMENT_DATA       => Wx::NewId();
const my $DOCUMENT_PATH       => Wx::NewId();

const my $CLOSE               => Wx::NewId();

sub new {
  my ($class, $parent, $nset) = @_;

  my $this = $class->SUPER::new($parent, -1, "Artemis: Data controls",
				wxDefaultPosition, [810,520],
				wxCAPTION|wxMINIMIZE_BOX|wxCLOSE_BOX|wxSYSTEM_MENU); #|wxRESIZE_BORDER
  $this ->{PARENT} = $parent;
  $this->make_menubar;
  $this->SetMenuBar( $this->{menubar} );
  EVT_MENU($this, -1, sub{OnMenuClick(@_);} );
  EVT_CLOSE($this, \&on_close);
  EVT_ICONIZE($this, \&on_close);
  given (Demeter->co->default('artemis', 'window_function')) {
    when ('hanning') {
      $this->{menubar}->Check($WINDOW_HANNING, 1);
    };
    when ('kaiser-bessel') {
      $this->{menubar}->Check($WINDOW_KB, 1);
    };
    when ('welch') {
      $this->{menubar}->Check($WINDOW_WELCH, 1);
    };
    when ('parzen') {
      $this->{menubar}->Check($WINDOW_PARZEN, 1);
    };
    when ('sine') {
      $this->{menubar}->Check($WINDOW_SINE, 1);
    };
  };

  $this->{statusbar} = $this->CreateStatusBar;
  $this->{statusbar} -> SetStatusText(q{ });
  #$this->{statusbar}->SetForegroundColour(Wx::Colour->new("#00ff00")); ??????
  my $hbox  = Wx::BoxSizer->new( wxHORIZONTAL );
  $this->{mainbox} = $hbox;
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
  $this->{name} = Wx::StaticText->new($leftpane, -1, q{}, wxDefaultPosition, wxDefaultSize );
  $this->{name}->SetFont( Wx::Font->new( 12, wxDEFAULT, wxNORMAL, wxBOLD, 0, "" ) );
  $namebox -> Add($this->{name}, 1, wxLEFT|wxRIGHT|wxTOP, 5);
  $namebox -> Add(Wx::StaticText->new($leftpane, -1, "CV"), 0, wxLEFT|wxRIGHT|wxTOP, 5);
  $this->{cv} = Wx::TextCtrl->new($leftpane, -1, $nset, wxDefaultPosition, [60,-1], wxTE_PROCESS_ENTER);
  $namebox -> Add($this->{cv}, 0, wxLEFT|wxRIGHT|wxTOP, 3);
  EVT_BUTTON($this, $this->{plotgrab}, sub{transfer(@_)});
  EVT_TEXT_ENTER($this, $this->{cv}, sub{1});

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
  $left -> Add($buttonboxsizer, 0, wxGROW|wxLEFT|wxRIGHT, 5);
  $this->{plot_rmr}  = Wx::Button->new($leftpane, -1, "&Rm".$demeter->co->default("plot", "rmx"),  wxDefaultPosition, [70,-1]);
  $this->{plot_rk}   = Wx::Button->new($leftpane, -1, "Rk",    wxDefaultPosition, [70,-1]);
  $this->{plot_k123} = Wx::Button->new($leftpane, -1, "&k123", wxDefaultPosition, [70,-1]);
  $this->{plot_r123} = Wx::Button->new($leftpane, -1, "R&123", wxDefaultPosition, [70,-1]);
  $this->{plot_kq}   = Wx::Button->new($leftpane, -1, "k&q",   wxDefaultPosition, [70,-1]);
  foreach my $b (qw(plot_k123 plot_r123 plot_rmr plot_rk plot_kq)) {
    $buttonboxsizer -> Add($this->{$b}, 1, wxGROW|wxALL, 2);
    $this->{$b} -> SetForegroundColour(Wx::Colour->new("#000000"));
    $this->{$b} -> SetBackgroundColour(Wx::Colour->new($Demeter::UI::Artemis::demeter->co->default("happiness", "average_color")));
    $this->{$b} -> SetFont(Wx::Font->new( 10, wxDEFAULT, wxNORMAL, wxNORMAL, 0, "" ) );
  };
  EVT_BUTTON($this, $this->{plot_rmr},  sub{plot(@_, 'rmr')});
  EVT_BUTTON($this, $this->{plot_rk},   sub{plot(@_, 'rk')});
  EVT_BUTTON($this, $this->{plot_k123}, sub{plot(@_, 'k123')});
  EVT_BUTTON($this, $this->{plot_r123}, sub{plot(@_, 'r123')});
  EVT_BUTTON($this, $this->{plot_kq},   sub{plot(@_, 'kqfit')});

  $this->mouseover("plot_rmr",  "Plot this data set as |$CHI(R)| and Re[$CHI(R)].");
  $this->mouseover("plot_rk",   "Plot this data set as a stack of $CHI(k) with |$CHI(R)| and Re[$CHI(R)].");
  $this->mouseover("plot_k123", "Plot this data set as $CHI(k) with all three k-weights and scaled to the same size.");
  $this->mouseover("plot_r123", "Plot this data set as $CHI(R) with all three k-weights and scaled to the same size.");
  $this->mouseover("plot_kq",   "Plot this data set as both $CHI(k) and Re[$CHI(q)].");


  ## -------- title lines
  my $titlesbox      = Wx::StaticBox->new($leftpane, -1, 'Title lines ', wxDefaultPosition, wxDefaultSize);
  my $titlesboxsizer = Wx::StaticBoxSizer->new( $titlesbox, wxHORIZONTAL );
  $this->{titles}      = Wx::TextCtrl->new($leftpane, -1, q{}, wxDefaultPosition, [300,100],
					   wxTE_READONLY|wxTE_MULTILINE|wxTE_RICH|wxTE_DONTWRAP);
  $titlesboxsizer -> Add($this->{titles}, 1, wxALL|wxGROW, 0);
  $left           -> Add($titlesboxsizer, 2, wxALL|wxGROW, 5);
  $this->mouseover("titles", "These lines will be written to output files.  Use them to describe this data set.");


  ## -------- Fourier transform parameters
  my $ftbox      = Wx::StaticBox->new($leftpane, -1, 'Fourier transform parameters ', wxDefaultPosition, wxDefaultSize);
  my $ftboxsizer = Wx::StaticBoxSizer->new( $ftbox, wxVERTICAL );
  $left         -> Add($ftboxsizer, 0, wxGROW|wxLEFT|wxRIGHT|wxALIGN_CENTER_HORIZONTAL, 5);

  my $gbs = Wx::GridBagSizer->new( 5, 10 );

  my $label     = Wx::StaticText->new($leftpane, -1, "kmin");
  $this->{kmin} = Wx::TextCtrl  ->new($leftpane, -1, $demeter->co->default("fft", "kmin"),
				      wxDefaultPosition, [50,-1], wxTE_PROCESS_ENTER);
  $this->{kmin_pluck} = Wx::BitmapButton -> new($leftpane, -1, $bullseye);
  $gbs     -> Add($label,              Wx::GBPosition->new(0,1));
  $gbs     -> Add($this->{kmin},       Wx::GBPosition->new(0,2));
  $gbs     -> Add($this->{kmin_pluck}, Wx::GBPosition->new(0,3));

  $label        = Wx::StaticText->new($leftpane, -1, "kmax");
  $this->{kmax} = Wx::TextCtrl  ->new($leftpane, -1, $demeter->co->default("fft", "kmax"),
				      wxDefaultPosition, [50,-1], wxTE_PROCESS_ENTER);
  $this->{kmax_pluck} = Wx::BitmapButton -> new($leftpane, -1, $bullseye);
  $gbs     -> Add($label,              Wx::GBPosition->new(0,4));
  $gbs     -> Add($this->{kmax},       Wx::GBPosition->new(0,5));
  $gbs     -> Add($this->{kmax_pluck}, Wx::GBPosition->new(0,6));

  $label      = Wx::StaticText->new($leftpane, -1, "dk");
  $this->{dk} = Wx::TextCtrl  ->new($leftpane, -1, $demeter->co->default("fft", "dk"),
				      wxDefaultPosition, [50,-1], wxTE_PROCESS_ENTER);
  $gbs     -> Add($label,      Wx::GBPosition->new(0,7));
  $gbs     -> Add($this->{dk}, Wx::GBPosition->new(0,8));

  $label        = Wx::StaticText->new($leftpane, -1, "rmin");
  $this->{rmin} = Wx::TextCtrl  ->new($leftpane, -1, $demeter->co->default("bft", "rmin"),
				      wxDefaultPosition, [50,-1], wxTE_PROCESS_ENTER);
  $this->{rmin_pluck} = Wx::BitmapButton -> new($leftpane, -1, $bullseye);
  $gbs -> Add($label,              Wx::GBPosition->new(1,1));
  $gbs -> Add($this->{rmin},       Wx::GBPosition->new(1,2));
  $gbs -> Add($this->{rmin_pluck}, Wx::GBPosition->new(1,3));

  $label        = Wx::StaticText->new($leftpane, -1, "rmax");
  $this->{rmax} = Wx::TextCtrl  ->new($leftpane, -1, $demeter->co->default("bft", "rmax"),
				      wxDefaultPosition, [50,-1], wxTE_PROCESS_ENTER);
  $this->{rmax_pluck} = Wx::BitmapButton -> new($leftpane, -1, $bullseye);
  $gbs -> Add($label,              Wx::GBPosition->new(1,4));
  $gbs -> Add($this->{rmax},       Wx::GBPosition->new(1,5));
  $gbs -> Add($this->{rmax_pluck}, Wx::GBPosition->new(1,6));

  $label      = Wx::StaticText->new($leftpane, -1, "dr");
  $this->{dr} = Wx::TextCtrl  ->new($leftpane, -1, $demeter->co->default("bft", "dr"),
				    wxDefaultPosition, [50,-1], wxTE_PROCESS_ENTER);
  $gbs     -> Add($label,      Wx::GBPosition->new(1,7));
  $gbs     -> Add($this->{dr}, Wx::GBPosition->new(1,8));

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
  $this->mouseover("kmin_pluck", "Pluck a value for kmin from the plot.");
  $this->mouseover("kmax_pluck", "Pluck a value for kmax from the plot.");
  $this->mouseover("rmin_pluck", "Pluck a value for Rmin from the plot.");
  $this->mouseover("rmax_pluck", "Pluck a value for Rmax from the plot.");

  foreach my $x (qw(kmin kmax dk rmin rmax dr)) {
    EVT_TEXT_ENTER($this, $this->{$x},
		   sub{
		     $this->fetch_parameters;
		     my $text = sprintf("The number of independent points in this data set is %.2f", $this->{data}->nidp);
		     $this->status($text);
		   });
    next if ($x =~ m{d[kr]});
    EVT_BUTTON($this, $this->{$x.'_pluck'}, sub{Pluck(@_, $x)});
  };

  $ftboxsizer -> Add($gbs, 0, wxALL, 5);

  if (Demeter->co->default('artemis', 'window_function') eq 'user') {
    my $windowsbox  = Wx::BoxSizer->new( wxHORIZONTAL );
    $ftboxsizer -> Add($windowsbox, 0, wxALIGN_LEFT|wxALL, 0);

    $label     = Wx::StaticText->new($leftpane, -1, "k window");
    $this->{kwindow} = Wx::Choice  ->new($leftpane, -1, , wxDefaultPosition, wxDefaultSize, $windows);
    $windowsbox -> Add($label, 0, wxLEFT|wxRIGHT, 5);
    $windowsbox -> Add($this->{kwindow}, 0, wxLEFT|wxRIGHT, 2);
    $this->{kwindow}->SetSelection(firstidx {$_ eq $demeter->co->default("fft", "kwindow")} @$windows);

    $label     = Wx::StaticText->new($leftpane, -1, "R window");
    $this->{rwindow} = Wx::Choice  ->new($leftpane, -1, , wxDefaultPosition, wxDefaultSize, $windows);
    $windowsbox -> Add($label, 0, wxLEFT|wxRIGHT, 5);
    $windowsbox -> Add($this->{rwindow}, 0, wxLEFT|wxRIGHT, 2);
    $this->{rwindow}->SetSelection(firstidx {$_ eq $demeter->co->default("bft", "rwindow")} @$windows);

    $this->mouseover("kwindow", "The functional form of the window used for the forward Fourier transform.");
    $this->mouseover("rwindow", "The functional form of the window used for the backward Fourier transform.");
  };


  ## -------- k-weights
  my $kwbox      = Wx::StaticBox->new($leftpane, -1, 'Fitting k weights ', wxDefaultPosition, wxDefaultSize);
  my $kwboxsizer = Wx::StaticBoxSizer->new( $kwbox, wxHORIZONTAL );
  $left         -> Add($kwboxsizer, 0, wxALL, 5);

  $this->{k1}   = Wx::CheckBox->new($leftpane, -1, "1",     wxDefaultPosition, wxDefaultSize);
  $this->{k2}   = Wx::CheckBox->new($leftpane, -1, "2",     wxDefaultPosition, wxDefaultSize);
  $this->{k3}   = Wx::CheckBox->new($leftpane, -1, "3",     wxDefaultPosition, wxDefaultSize);
  $this->{karb} = Wx::CheckBox->new($leftpane, -1, "other", wxDefaultPosition, wxDefaultSize);
  $this->{karb_value} = Wx::TextCtrl->new($leftpane, -1, $demeter->co->default('fit', 'karb_value'), wxDefaultPosition, wxDefaultSize, wxTE_PROCESS_ENTER);
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

  EVT_TEXT_ENTER($this, $this->{karb_value}, sub{1});

  my $otherbox      = Wx::StaticBox->new($leftpane, -1, 'Other parameters ', wxDefaultPosition, wxDefaultSize);
  my $otherboxsizer = Wx::StaticBoxSizer->new( $otherbox, wxVERTICAL );
  $left            -> Add($otherboxsizer, 0, wxLEFT|wxRIGHT|wxBOTTOM|wxGROW|wxALIGN_CENTER_HORIZONTAL, 5);


  ## --------- toggles
  my $togglebox  = Wx::BoxSizer->new( wxHORIZONTAL );
  $otherboxsizer -> Add($togglebox, 0, wxALL, 0);
  $this->{include}    = Wx::CheckBox->new($leftpane, -1, "Include in fit", wxDefaultPosition, wxDefaultSize);
  $this->{plot_after} = Wx::CheckBox->new($leftpane, -1, "Plot after fit", wxDefaultPosition, wxDefaultSize);
  $this->{fit_bkg}    = Wx::CheckBox->new($leftpane, -1, "Fit background", wxDefaultPosition, wxDefaultSize);
  $togglebox -> Add($this->{include},    0, wxLEFT|wxRIGHT, 5);
  $togglebox -> Add($this->{plot_after}, 0, wxLEFT|wxRIGHT, 5);
  $togglebox -> Add($this->{fit_bkg},    0, wxLEFT|wxRIGHT, 5);
  $this->{include}    -> SetValue(1);
  $this->{plot_after} -> SetValue(not $nset);

  $this->mouseover("include",    "Click here to include this data in the fit.  Unclick to exclude it.");
  $this->mouseover("plot_after", "Click here to have this data set automatically transfered tothe plotting list after the fit.");
  $this->mouseover("fit_bkg",    "Click here to co-refine a background spline during the fit.");


  ## -------- epsilon and phase correction
  my $extrabox    = Wx::BoxSizer->new( wxHORIZONTAL );
  $otherboxsizer -> Add($extrabox, 0, wxTOP|wxBOTTOM, 2);

  $extrabox -> Add(Wx::StaticText->new($leftpane, -1, "$EPSILON(k)"), 0, wxALL, 5);
  $this->{epsilon} = Wx::TextCtrl->new($leftpane, -1, 0, wxDefaultPosition, [50,-1], wxTE_PROCESS_ENTER);
  $extrabox  -> Add($this->{epsilon}, 0, wxALL, 0);
  $extrabox  -> Add(Wx::StaticText->new($leftpane, -1, q{}), 1, wxALL, 2);
  $this->{pcplot}  = Wx::CheckBox->new($leftpane, -1, "Plot with phase correction", wxDefaultPosition, wxDefaultSize);
  $extrabox  -> Add($this->{pcplot}, 0, wxALL, 3);
  #$this->{pcplot}->Enable(0);
  EVT_CHECKBOX($this, $this->{pcplot}, sub{
		 my ($self, $event) = @_;
		 $self->{data}->fft_pc($self->{pcplot}->GetValue);
		 if ($self->{pcplot}->GetValue) {
		   $self->{data}->fft_pcpath(q{});
		   foreach my $n (0 .. $self->{pathlist}->GetPageCount - 1) {
		     if ($self->{pathlist}->GetPage($n)->{useforpc}->GetValue) {
		       $self->{data}->fft_pcpath($self->{pathlist}->GetPage($n)->{path});
		       last;
		     };
		   };

		   if ($self->{data}->fft_pcpath) {
		     $self->{data}->update_fft(1);
		     foreach my $n (0 .. $self->{pathlist}->GetPageCount - 1) {
		       $self->{pathlist}->GetPage($n)->{path}->update_fft(1);
		     };
		     $self->{data}->fft_pcpath->_update('fft');
		   } else {
		     $self->status("You have not selected a path to use for phase corrected Fourier transforms", "alert");
		     $self->{pcplot}->SetValue(0);
		   };
		 };
	       });

  EVT_TEXT_ENTER($this, $this->{epsilon}, sub{1});
  $this->{epsilon} -> SetValidator( Wx::Perl::TextValidator->new( qr([0-9.]) ) );
  $this->mouseover("epsilon", "A user specified value for the measurement uncertainty.  A value of 0 means to let " . Demeter->backend_name . " determine the uncertainty.");
  $this->mouseover("pcplot",  "Check here to make plots using phase corrected Fourier transforms.  Note that the fit is NOT made using phase corrected transforms.");

  $leftpane -> SetSizerAndFit($left);


  $hbox -> Add(Wx::StaticLine->new($this, -1, wxDefaultPosition, [4, -1], wxLI_VERTICAL), 0, wxGROW|wxALL, 0);


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

  $this->{pathlist}->SetDropTarget( Demeter::UI::Artemis::Data::DropTarget->new( $this, $this->{pathlist} ) );
  my @kids = $this->{pathlist}->GetChildren;
  EVT_LEFT_DOWN($kids[0], sub{OnDrag(@_,$this->{pathlist})});

  $rightpane -> SetSizerAndFit($right);


  my $accelerator = Wx::AcceleratorTable->new(
   					      [wxACCEL_CTRL, 119, wxID_CLOSE],
   					     );
  $this->SetAcceleratorTable( $accelerator );


  #$splitter -> SplitVertically($leftpane, $rightpane, -500);
  #$splitter -> SetSashSize(10);

  $this -> SetSizerAndFit( $hbox );
  return $this;
};

sub mouseover {
  my ($self, $widget, $text) = @_;
  EVT_ENTER_WINDOW($self->{$widget}, sub{$self->{statusbar}->PushStatusText($text); $_[1]->Skip});
  EVT_LEAVE_WINDOW($self->{$widget}, sub{$self->{statusbar}->PopStatusText if ($self->{statusbar}->GetStatusText eq $text); $_[1]->Skip});
};

sub OnDrag {
  my ($checkbox, $event, $list) = @_;
  if ($event->ControlDown) {
    my $which = $checkbox->HitTest($event->GetPosition);
    my $pathpage = $list->GetPage($which);
    my $path = $pathpage->{path};
    $path->_update_from_ScatteringPath;
    my $yaml = $path->serialization;
    my $source = Wx::DropSource->new( $list );
    my $dragdata = Demeter::UI::Artemis::DND::PathDrag->new(\$yaml);
    $source->SetData( $dragdata );
    $source->DoDragDrop(1);
    $event->Skip(0);
  } else {
    $event->Skip(1);
  };
};


sub initial_page_panel {
  my ($self) = @_;
  my $panel = Wx::Panel->new($self, -1, wxDefaultPosition, wxDefaultSize);

  my $vv = Wx::BoxSizer->new( wxVERTICAL );

  my $dndtext = Wx::StaticText    -> new($panel, -1, "Drag paths from a Feff interpretation list and drop them in this space to add paths to this data set", wxDefaultPosition, [280,-1]);
  $dndtext   -> Wrap(200);
  my $atoms   = Wx::HyperlinkCtrl -> new($panel, -1, 'Import crystal data or a Feff calculation', q{}, wxDefaultPosition, wxDefaultSize, wxNO_BORDER );
  my $qfs     = Wx::HyperlinkCtrl -> new($panel, -1, 'Start a quick first shell fit',             q{}, wxDefaultPosition, wxDefaultSize, wxNO_BORDER );
  my $su      = Wx::StaticText    -> new($panel, -1, 'Import a structural unit',                       wxDefaultPosition, wxDefaultSize, wxNO_BORDER );
  my $emp     = Wx::HyperlinkCtrl -> new($panel, -1, 'Import an empirical standard',              q{}, wxDefaultPosition, wxDefaultSize, wxNO_BORDER );
  ##my $feff    = Wx::HyperlinkCtrl -> new($panel, -1, 'Import a Feff calculation',     q{}, wxDefaultPosition, wxDefaultSize, wxNO_BORDER );

  EVT_HYPERLINK($self, $atoms, sub{Import('feff', q{});});
  EVT_HYPERLINK($self, $qfs,   sub{$self->quickfs;});
  EVT_HYPERLINK($self, $emp,   sub{$self->empirical;});
  $_ -> SetFont( Wx::Font->new( 10, wxDEFAULT, wxITALIC, wxNORMAL, 0, "" ) ) foreach ($dndtext, $qfs, $atoms, $su, $emp);
  $su-> Enable(0);
  $_ -> SetVisitedColour($_->GetNormalColour) foreach ($qfs, $atoms, $emp); #, $su, $feff);

  ##my $or = Wx::StaticText -> new($panel, -1, "\tor");

  $vv -> Add($dndtext,                                  0, wxALL, 5 );
  $vv -> Add(Wx::StaticText -> new($panel, -1, "\tor"), 0, wxALL, 10);
  $vv -> Add($atoms,                                    0, wxALL, 5 );
  $vv -> Add(Wx::StaticText -> new($panel, -1, "\tor"), 0, wxALL, 10);
  $vv -> Add($qfs,                                      0, wxALL, 5 );
  $vv -> Add(Wx::StaticText -> new($panel, -1, "\tor"), 0, wxALL, 10);
  $vv -> Add($su,                                       0, wxALL, 5 );
  $vv -> Add(Wx::StaticText -> new($panel, -1, "\tor"), 0, wxALL, 10);
  $vv -> Add($emp,                                      0, wxALL, 5 );
  ##$vv -> Add(Wx::StaticText -> new($panel, -1, "\tor"), 0, wxALL, 10);
  ##$vv -> Add($feff,                                     0, wxALL, 5 );

  $panel -> SetSizerAndFit($vv);
  return $panel;
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
  $self->status("Transfered marked groups to plotting list");
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
  $self->status("Made a VPath from the marked groups");
};

sub Pluck {
  my ($self, $event, $which) = @_;

  my $on_screen = $Demeter::UI::Artemis::frames{Plot}->{last};
  if (not $on_screen) {
    $self->status("You haven't made a plot yet");
    return;
  };
  if ($on_screen eq 'multiplot') {
    $self->status("Cannot pluck a value from a multiplot.");
    return;
  };
  if (($on_screen eq 'r') and ($which !~ m{rmin|rmax})) {
    $self->status("Cannot pluck for $which from an R plot.");
    return;
  };
  if (($on_screen ne 'r') and ($which =~ m{rmin|rmax})) {
    $self->status("Cannot pluck for $which from a $on_screen plot.");
    return;
  };

  my ($ok, $x, $y) = $::app->cursor($self);
  $self->status("Failed to pluck a value for $which"), return if not $ok;
  $on_screen = 'k' if ($on_screen eq 'q');
  my $plucked = sprintf("%.3f", $x);
  $self->{$which}->SetValue($plucked);
  $self->fetch_parameters;
  my $text = sprintf("Plucked %s for %s. The number of independent points in this data set is now %.2f",
		     $plucked, $which, $self->{data}->nidp);
  $self->status($text);
}

sub make_menubar {
  my ($self) = @_;
  $self->{menubar}   = Wx::MenuBar->new;

  my $datasave_menu     = Wx::Menu->new;
  $datasave_menu->Append($DATA_SAVE_K, "k-space", "Save these data to a file with $CHI(k), $CHI(k)*k, $CHI(k)*k$TWO, $CHI(k)*k$THR, and the k-window", wxITEM_NORMAL);
  $datasave_menu->Append($DATA_SAVE_R, "R-space", "Save these data to a file with the real, imaginary, magnitude and phase parts of $CHI(R)",          wxITEM_NORMAL);
  $datasave_menu->Append($DATA_SAVE_Q, "q-space", "Save these data to a file with the real, imaginary, magnitude and phase parts of $CHI(q)",          wxITEM_NORMAL);
  my $fitsave_menu  = Wx::Menu->new;
  $fitsave_menu->Append($FIT_SAVE_K,  "$CHI(k)",       "Save the data and fit as $CHI(k)",       wxITEM_NORMAL);
  $fitsave_menu->Append($FIT_SAVE_K1, "$CHI(k)*k",     "Save the data and fit as $CHI(k)*k",     wxITEM_NORMAL);
  $fitsave_menu->Append($FIT_SAVE_K2, "$CHI(k)*k$TWO", "Save the data and fit as $CHI(k)*k$TWO", wxITEM_NORMAL);
  $fitsave_menu->Append($FIT_SAVE_K3, "$CHI(k)*k$THR", "Save the data and fit as $CHI(k)*k$THR", wxITEM_NORMAL);
  $fitsave_menu->AppendSeparator;
  $fitsave_menu->Append($FIT_SAVE_RM, "|$CHI(R)|",     "Save the data and fit as the magnitude of $CHI(R) using the plotting k-weight",      wxITEM_NORMAL);
  $fitsave_menu->Append($FIT_SAVE_RR, "Re[$CHI(R)]",   "Save the data and fit as the real part of $CHI(R) using the plotting k-weight",      wxITEM_NORMAL);
  $fitsave_menu->Append($FIT_SAVE_RI, "Im[$CHI(R)]",   "Save the data and fit as the imaginary part of $CHI(R) using the plotting k-weight", wxITEM_NORMAL);
  $fitsave_menu->AppendSeparator;
  $fitsave_menu->Append($FIT_SAVE_QM, "|$CHI(q)|",     "Save the data and fit as the magnitude of $CHI(q) using the plotting k-weight",      wxITEM_NORMAL);
  $fitsave_menu->Append($FIT_SAVE_QR, "Re[$CHI(q)]",   "Save the data and fit as the real part of $CHI(q) using the plotting k-weight",      wxITEM_NORMAL);
  $fitsave_menu->Append($FIT_SAVE_QI, "Im[$CHI(q)]",   "Save the data and fit as the imaginary part of $CHI(q) using the plotting k-weight", wxITEM_NORMAL);
  my $markedsave_menu = Wx::Menu->new;
  $markedsave_menu->Append($MARKED_SAVE_K,  "$CHI(k)",       "Save the data and all marked paths as $CHI(k) with all path parameters evaluated",       wxITEM_NORMAL);
  $markedsave_menu->Append($MARKED_SAVE_K1, "$CHI(k)*k",     "Save the data and all marked paths as $CHI(k)*k with all path parameters evaluated",     wxITEM_NORMAL);
  $markedsave_menu->Append($MARKED_SAVE_K2, "$CHI(k)*k$TWO", "Save the data and all marked paths as $CHI(k)*k$TWO with all path parameters evaluated", wxITEM_NORMAL);
  $markedsave_menu->Append($MARKED_SAVE_K3, "$CHI(k)*k$THR", "Save the data and all marked paths as $CHI(k)*k$THR with all path parameters evaluated", wxITEM_NORMAL);
  $markedsave_menu->AppendSeparator;
  $markedsave_menu->Append($MARKED_SAVE_RM, "|$CHI(R)|",     "Save the data and all marked paths as the magnitude of $CHI(R) with all path parameters evaluated", wxITEM_NORMAL);
  $markedsave_menu->Append($MARKED_SAVE_RR, "Re[$CHI(R)]",   "Save the data and all marked paths as the real part of $CHI(R) with all path parameters evaluated", wxITEM_NORMAL);
  $markedsave_menu->Append($MARKED_SAVE_RI, "Im[$CHI(R)]",   "Save the data and all marked paths as the imaginary part of $CHI(R) with all path parameters evaluated", wxITEM_NORMAL);
  $markedsave_menu->AppendSeparator;
  $markedsave_menu->Append($MARKED_SAVE_QM, "|$CHI(q)|",     "Save the data and all marked paths as the magnitude of $CHI(q) with all path parameters evaluated", wxITEM_NORMAL);
  $markedsave_menu->Append($MARKED_SAVE_QR, "Re[$CHI(q)]",   "Save the data and all marked paths as the real part of $CHI(q) with all path parameters evaluated", wxITEM_NORMAL);
  $markedsave_menu->Append($MARKED_SAVE_QI, "Im[$CHI(q)]",   "Save the data and all marked paths as the imaginary part of $CHI(q) with all path parameters evaluated", wxITEM_NORMAL);

  $self->{importmenu}  = Wx::Menu->new;
  $self->{importmenu}->Append($PATH_FSPATH,    "Quick first shell model", "Generate a quick first shell fitting model", wxITEM_NORMAL );
  $self->{importmenu}->Append($PATH_EMPIRICAL, "Import empirical standard", "Import an empirical standard exported from Athen", wxITEM_NORMAL );
  $self->{importmenu}->Append($PATH_SU,        "Import structural unit",  "Import a structural unit", wxITEM_NORMAL );

  $self->{windowmenu}  = Wx::Menu->new;
  $self->{windowmenu}->AppendRadioItem($WINDOW_HANNING, 'Hanning', 'A Hanning window has sills that ramp as cos^2');
  $self->{windowmenu}->AppendRadioItem($WINDOW_KB, 'Kaiser-Bessel', 'A Kaiser-Bessel window is a modified Bessel function over the entire range');
  $self->{windowmenu}->AppendRadioItem($WINDOW_WELCH, 'Welch', 'A Welch window has sills that ramp linearly in k^2');
  $self->{windowmenu}->AppendRadioItem($WINDOW_PARZEN, 'Parzen', 'A Parzen window has sills that ramp linearly in k');
  $self->{windowmenu}->AppendRadioItem($WINDOW_SINE, 'Sine', 'A Sine window is a sin function over the full range');


  ## -------- chi(k) menu
  $self->{datamenu}  = Wx::Menu->new;
  $self->{datamenu}->Append($DATA_RENAME,      "Rename this $CHI(k)",         "Rename this data set",  wxITEM_NORMAL );
  $self->{datamenu}->Append($DATA_REPLACE,     "Replace this $CHI(k)",        "Replace this data set $MDASH that is, apply the current fitting model to a different set of $CHI(k) data.",  wxITEM_NORMAL );
  $self->{datamenu}->Append($DATA_DISCARD,     "Discard this $CHI(k)",        "Discard this data set", wxITEM_NORMAL );
  #$self->{datamenu}->Append($DATA_DIFF,        "Make difference spectrum", "Make a difference spectrum using the marked paths", wxITEM_NORMAL );
  $self->{datamenu}->AppendSeparator;
  $self->{datamenu}->AppendSubMenu($datasave_menu,   "Save data in ...",                "Save a column data file containing only the data.");
  $self->{datamenu}->AppendSubMenu($fitsave_menu,    "Save data and fit as ...",        "Save a column data file containing the data, fit, background, residual, running R-factor, and window.");
  $self->{datamenu}->AppendSubMenu($markedsave_menu, "Save data + marked paths as ...", "Save a column data file containing the data and all marked paths from this data's path list.");
  $self->{datamenu}->AppendSeparator;
  $self->{datamenu}->AppendSubMenu($self->{importmenu}, "Other fitting standards ...", "Import fitting standards from other places");
  $self->{datamenu}->AppendSeparator;
  $self->{datamenu}->Append($DATA_BALANCE,     "Balance interstitial energies", "Adjust E0 for every path so that the interstitial energies for each Feff calculation are balanced",  wxITEM_NORMAL );
  $self->{datamenu}->Append($DATA_DEGEN_N,     "Set all degens to Feff",   "Set degeneracies for all paths in this data set to values from Feff",  wxITEM_NORMAL );
  $self->{datamenu}->Append($DATA_DEGEN_1,     "Set all degens to one",    "Set degeneracies for all paths in this data set to one (1)",  wxITEM_NORMAL );
  $self->{datamenu}->AppendSeparator;
  $self->{datamenu}->AppendSubMenu($self->{windowmenu}, "Set window function");
  $self->{datamenu}->Append($DATA_EXPORT,     "Export parameters to other data sets", "Export these FT and fitting parameters to other data sets.");
  $self->{datamenu}->Append($DATA_KMAXSUGEST, "Set kmax to ".Demeter->backend_name."'s suggestion", "Set kmax to ".Demeter->backend_name."'s suggestion, which is computed based on the staistical noise", wxITEM_NORMAL );
  $self->{datamenu}->Append($DATA_EPSK,       "Show $EPSILON",                    "Show statistical noise for these data", wxITEM_NORMAL );
  $self->{datamenu}->Append($DATA_NIDP,       "Show Nidp",                        "Show the number of independent points in these data", wxITEM_NORMAL );
  $self->{datamenu}->AppendSeparator;
  $self->{datamenu}->Append(wxID_CLOSE, "&Close\tCtrl+w" );


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
  $self->{pathsmenu}->Append($PATH_TRANSFER, "Transfer displayed path",            "Transfer the path currently on display to the plotting list", wxITEM_NORMAL );
  $self->{pathsmenu}->Append($PATH_RENAME, "Rename displayed path",            "Rename the path currently on display", wxITEM_NORMAL );
  $self->{pathsmenu}->Append($PATH_SHOW,   "Show displayed path",              "Evaluate and show the path parameters for the path currently on display", wxITEM_NORMAL );
  $self->{pathsmenu}->AppendSeparator;
  $self->{pathsmenu}->AppendSubMenu($save_menu, "Save displayed path in ...", "Save a column data file containing only the displayed path." );
  $self->{pathsmenu}->Append($PATH_CLONE, "Clone displayed path",         "Make a copy of the currently displayed path", wxITEM_NORMAL );
  $self->{pathsmenu}->AppendSeparator;
  $self->{pathsmenu}->Append($PATH_ADD,    "Add path parameter",          "Add path parameter to many paths", wxITEM_NORMAL );
  $self->{pathsmenu}->AppendSubMenu($export_menu, "Export all path parameters to ...", "Export the path parameters from the displayed path to other paths in this fitting model.");
  $self->{pathsmenu}->Append($PATH_4PARAM, "Quick 4 parameter fit",       "Make a quick-n-dirty, simple 4 parameter fit with guess parameters amp, enot, delr, and ss", wxITEM_NORMAL );
  $self->{pathsmenu}->AppendSeparator;
  $self->{pathsmenu}->Append($DISCARD_THIS, "Discard displayed path",     "Discard the path currently on display", wxITEM_NORMAL );
  #  $self->{pathsmenu}->AppendSeparator;
  #  $self->{pathsmenu}->AppendSubMenu($explain_menu, "Explain path parameter ..." );

  $self->{debugmenu}  = Wx::Menu->new;
  $self->{debugmenu}->Append($DATA_SHOW, "Show ".Demeter->backend_name." group for this Data", "Show the arrays associated with this group in ".Demeter->backend_name,  wxITEM_NORMAL );
  $self->{debugmenu}->Append($PATH_SHOW, "Show displayed path",              "Evaluate and show the path parameters for the currently display path", wxITEM_NORMAL );
  $self->{debugmenu}->AppendSeparator;
  $self->{debugmenu}->Append($DATA_YAML, "Show YAML for this data set",  "Show YAML for this data set",  wxITEM_NORMAL );
  $self->{debugmenu}->Append($PATH_YAML, "Show YAML for displayed path", "Show YAML for displayed path", wxITEM_NORMAL );
  $self->{debugmenu}->Append($PATH_TYPE, "Identify displayed path",      "Show the object type of the displayed path (Path | FSPath | SSPath | MSPath | ThreeBody)", wxITEM_NORMAL );


  ## -------- marks menu
  $self->{markmenu}  = Wx::Menu->new;
  $self->{markmenu}->Append($MARK_ALL,    "Mark all\tCtrl+Shift+a",              "Mark all paths for this $CHI(k)",             wxITEM_NORMAL );
  $self->{markmenu}->Append($MARK_NONE,   "Unmark all\tCtrl+Shift+u",            "Unmark all paths for this $CHI(k)",           wxITEM_NORMAL );
  $self->{markmenu}->Append($MARK_INVERT, "Invert marks\tCtrl+Shift+i",          "Invert all marks for this $CHI(k)",           wxITEM_NORMAL );
  $self->{markmenu}->Append($MARK_REGEXP, "Mark regexp\tCtrl+Shift+r",           "Mark by regular expression for this $CHI(k)", wxITEM_NORMAL );
  $self->{markmenu}->AppendSeparator;
  $self->{markmenu}->Append($MARK_BEFORE, "Mark before current\tCtrl+Shift+b",   "Mark this path and all paths above it in the path list for this $CHI(k)", wxITEM_NORMAL );
  $self->{markmenu}->Append($MARK_AFTER,  "Mark after current\tCtrl+Shift+f",    "Mark all paths after this one in the path list for this $CHI(k)",         wxITEM_NORMAL );
  $self->{markmenu}->AppendSeparator;
  $self->{markmenu}->Append($MARK_INC,    "Mark included\tCtrl+Shift+c",         "Mark all paths included in the fit",   wxITEM_NORMAL );
  $self->{markmenu}->Append($MARK_EXC,    "Mark excluded\tCtrl+Shift+x",         "Mark all paths excluded from the fit", wxITEM_NORMAL );
  $self->{markmenu}->AppendSeparator;
  $self->{markmenu}->Append($MARK_SS,     "Mark SS paths\tCtrl+Shift+s",         "Mark all single scattering paths for this $CHI(k)", wxITEM_NORMAL );
  $self->{markmenu}->Append($MARK_MS,     "Mark MS paths\tCtrl+Shift+m",         "Mark all multiple scattering paths for this $CHI(k)", wxITEM_NORMAL );
  $self->{markmenu}->AppendSeparator;
  $self->{markmenu}->Append($MARK_HIGH,   "Mark high importance\tCtrl+Shift+h",  "Mark all high importance paths for this $CHI(k)", wxITEM_NORMAL );
  $self->{markmenu}->Append($MARK_MID,    "Mark mid importance\tCtrl+Shift+k",   "Mark all mid importance paths for this $CHI(k)", wxITEM_NORMAL );
  $self->{markmenu}->Append($MARK_LOW,    "Mark low importance\tCtrl+Shift+l",   "Mark all low importance paths for this $CHI(k)", wxITEM_NORMAL );
  $self->{markmenu}->AppendSeparator;
  $self->{markmenu}->Append($MARK_RBELOW, "Mark all paths < R\tCtrl+Shift+<",    "Mark all paths shorter than a specified path length for this $CHI(k)", wxITEM_NORMAL );
  $self->{markmenu}->Append($MARK_RABOVE, "Mark all paths > R\tCtrl+Shift+>",    "Mark all paths longer than a specified path length for this $CHI(k)", wxITEM_NORMAL );

   ## -------- actions menu
  $self->{actionsmenu} = Wx::Menu->new;
  $self->{actionsmenu}->Append($ACTION_VPATH,     "Make VPath from marked\tAlt+Shift+v",  "Make a virtual path from all marked paths", wxITEM_NORMAL );
  $self->{actionsmenu}->Append($ACTION_TRANSFER,  "Transfer marked\tAlt+Shift+t",         "Transfer all marked paths to the plotting list",   wxITEM_NORMAL );
  $self->{actionsmenu}->AppendSeparator;
  $self->{actionsmenu}->Append($ACTION_INCLUDE,   "Include marked\tAlt+Shift+c",          "Include all marked paths in the fit",   wxITEM_NORMAL );
  $self->{actionsmenu}->Append($ACTION_EXCLUDE,   "Exclude marked\tAlt+Shift+x",          "Exclude all marked paths from the fit", wxITEM_NORMAL );
  $self->{actionsmenu}->AppendSeparator;
  $self->{actionsmenu}->Append($ACTION_DISCARD,   "Discard marked",          "Discard all marked paths",              wxITEM_NORMAL );
  $self->{actionsmenu}->AppendSeparator;
  $self->{actionsmenu}->Append($ACTION_AFTER,     "Plot marked after fit\tAlt+Shift+p",   "Flag all marked paths for transfer to the plotting list after completion of a fit", wxITEM_NORMAL );
  $self->{actionsmenu}->Append($ACTION_NONEAFTER, "Plot no paths after fit\tAlt+Shift+u", "Unflag all paths for transfer to the plotting list after completion of a fit", wxITEM_NORMAL );


  $self->{helpmenu} = Wx::Menu->new;
  $self->{helpmenu}->Append($DOCUMENT_DATA, "Documentation: Data window", );
  $self->{helpmenu}->Append($DOCUMENT_PATH, "Documentation: Path page", );

  $self->{menubar}->Append( $self->{datamenu},    "&Data" );
  $self->{menubar}->Append( $self->{pathsmenu},   "&Path" );
  $self->{menubar}->Append( $self->{markmenu},    "&Marks" );
  $self->{menubar}->Append( $self->{actionsmenu}, "&Actions" );
  $self->{menubar}->Append( $self->{debugmenu},   "Debu&g" ) if ($demeter->co->default("artemis", "debug_menus"));
  $self->{menubar}->Append( $self->{helpmenu},    "&Help" );

  map { $self->{datamenu}  ->Enable($_,0) } ($DATA_BALANCE, $DATA_EXPORT);
  map { $self->{importmenu}->Enable($_,0) } ($PATH_SU);

  $self->{menubar}->SetHelpString(3,    "Blah blah");
};

sub populate {
  my ($self, $data) = @_;
  $data->frozen(0);
  $self->{data} = $data;
  $self->{name}->SetLabel($data->name);
  $self->{cv}->SetValue($data->cv);
  $self->{datasource}->SetValue($data->prjrecord || $data->file);
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

  #EVT_CHECKBOX($self, $self->{pcplot}, sub{$data->fft_pc($self->{pcplot}->GetValue)});

  if (Demeter->co->default('artemis', 'window_function') eq 'user') {
    EVT_CHOICE($self, $self->{kwindow}, sub{$data->fft_kwindow($self->{kwindow}->GetStringSelection)});
    EVT_CHOICE($self, $self->{rwindow}, sub{$data->bft_rwindow($self->{rwindow}->GetStringSelection)});
  };
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
  if (Demeter->co->default('artemis', 'window_function') eq 'user') {
    $this->{data}->fft_kwindow	    ($this->{kwindow}   ->GetStringSelection);
    $this->{data}->bft_rwindow	    ($this->{rwindow}   ->GetStringSelection);
  };
  $this->{data}->fit_k1		    ($this->{k1}        ->GetValue	    );
  $this->{data}->fit_k2		    ($this->{k2}        ->GetValue	    );
  $this->{data}->fit_k3		    ($this->{k3}        ->GetValue	    );
  $this->{data}->fit_karb	    ($this->{karb}      ->GetValue	    );
  $this->{data}->fit_karb_value	    ($this->{karb_value}->GetValue	    );
  $this->{data}->fit_epsilon	    ($this->{epsilon}   ->GetValue	    );

  $this->{data}->fit_include	    ($this->{include}   ->GetValue          );
  $this->{data}->fit_plot_after_fit ($this->{plot_after}->GetValue          );
  $this->{data}->fit_do_bkg	    ($this->{fit_bkg}   ->GetValue          );
  $this->{data}->fft_pc  	    ($this->{pcplot}    ->GetValue          );
  if ($this->{data}->fft_pc) {
    $this->{data}->fft_pctype("path");
    $this->{data}->fft_pcpath(q{});
    foreach my $n (0 .. $this->{pathlist}->GetPageCount-1) {
      next if (not $this->{pathlist}->GetPage($n)->{useforpc}->GetValue);
      $this->{data}->fft_pcpath($this->{pathlist}->GetPage($n)->{path});
      last;
    };
    ## default to using the first path in the list...
    if (not $this->{data}->fft_pcpath) {
      foreach my $n (0 .. $this->{pathlist}->GetPageCount-1) {
	next if (not $this->{pathlist}->GetPage($n)->{include}->GetValue);
	$this->{data}->fft_pcpath($this->{pathlist}->GetPage($n)->{path});
	$this->{pathlist}->GetPage($n)->{path}->pc(1);
	$this->{pathlist}->GetPage($n)->{useforpc}->SetValue(1);
	last;
      };
    };
  };

  my $cv = $this->{cv}->GetValue;
  # things that are not caught by $NUMBER or the validator
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
  my $pf = $Demeter::UI::Artemis::frames{Plot};
  $pf->fetch_parameters('data');
  my $saveplot = $demeter->co->default(qw(plot plotwith));

  if ($pf->{fileout}->GetValue) {
    ## writing plot to a single file has been selected...
    my $fd = Wx::FileDialog->new( $self, "Save plot to a file", cwd, "plot.dat",
				  "Data (*.dat)|*.dat|All files (*)|*",
				  wxFD_SAVE|wxFD_CHANGE_DIR, #|wxFD_OVERWRITE_PROMPT,
				  wxDefaultPosition);
    if ($fd->ShowModal == wxID_CANCEL) {
      $self->status("Saving plot to a file has been canceled.");
      $pf->{fileout}->SetValue(0);
      return;
    };
    ## set up for SingleFile backend
    my $file = $fd->GetPath;
    $pf->{fileout}->SetValue(0), return if $self->overwrite_prompt($file); # work-around gtk's wxFD_OVERWRITE_PROMPT bug (5 Jan 2011)
    $self->{data}->plot_with('singlefile');
    $self->{data}->po->file($file);
  };

  $self->{data}->standard if ($pf->{fileout}->GetValue);
  $self->{data}->po->space(substr($how, 0 , 1));
  $self->{data}->po->space('q') if ($how eq 'kqfit');
  $self->{data}->po->start_plot;
  $self->{data}->plot($how);
  my $text = ($how eq 'rmr')   ? "as the magnitude and real part of chi(R)"
           : ($how eq 'rk')    ? "as a stacked plot with chi(k) + the magnitude and real part of chi(R)"
           : ($how eq 'r123')  ? "in R with three k-weights"
           : ($how eq 'k123')  ? "in k with three k-weights"
           : ($how eq 'kqfit') ? "in k- and q-space"
	   :                     q{};

  ## restore plotting backend if this was a plot to a file
  if ($pf->{fileout}->GetValue) {
    $self->{data}->po->finish;
    $self->status("Saved plot to file \"" . $demeter->po->file . "\".");
    $self->{data}->plot_with($saveplot);
    $pf->{fileout}->SetValue(0);
  };
  $self->status(sprintf("Plotted \"%s\" %s.",
					    $self->{data}->name, $text));
  $Demeter::UI::Artemis::frames{Plot}->{indicators}->plot($self->{data}) if ($how ne 'rk');
  $Demeter::UI::Artemis::frames{Plot}->{last} = ($how eq 'rmr')   ? 'r'
                                              : ($how eq 'r123')  ? 'r'
                                              : ($how eq 'k123')  ? 'k'
                                              : ($how eq 'kqfit') ? 'k'
					      :                     'multiplot';
  $Demeter::UI::Artemis::frames{Plot}->{lastplot} = $how."|".$self->{dnum};
  $::app->heap_check;
};

sub OnMenuClick {
  my ($datapage, $event)  = @_;
  my $id = $event->GetId;
  #print "1  $id\n";
 SWITCH: {

    ($id == wxID_CLOSE) and do {
      $datapage->Iconize(1);
      last SWITCH;
    };

    ($id == $DATA_RENAME) and do {
      $datapage->Rename;
      last SWITCH;
    };

    ($id == $DATA_REPLACE) and do {
      $datapage->replace;
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
      my $text;
      if ($datapage->{data}->fft_kmax > 5) {
	$text = sprintf("The number of independent points in this data set is now %.2f", $datapage->{data}->nidp);
	$datapage->status($text);
      } else {
	$text = Demeter->backend_name." returned an odd value for recommended k-weight.  You probably should reset it to a more reasonable value.";
	$datapage->status($text, 'error');
      };
      last SWITCH;
    };
    ($id == $DATA_EPSK) and do {
      $datapage->fetch_parameters;
      $datapage->{data}->chi_noise;
      my $text = sprintf("Statistical noise: $EPSILON(k) = %.2e and $EPSILON(R) = %.2e", $datapage->{data}->epsk, $datapage->{data}->epsr);
      $datapage->status($text);
      last SWITCH;
    };
    ($id == $DATA_NIDP) and do {
      $datapage->fetch_parameters;
      my $text = sprintf("The number of independent points in this data set is %.2f", $datapage->{data}->nidp);
      $datapage->status($text);
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
      my $text = "# Path index = " . $pathobject->Index . $/;
      $text .= $pathobject->serialization;
      my $dialog = Demeter::UI::Artemis::ShowText->new($datapage, $text, 'YAML of '.$pathobject->label)
	-> Show;
      last SWITCH;
    };

    ($id == $PATH_TYPE) and do {
      my $type = ref($datapage->{pathlist}->GetPage($datapage->{pathlist}->GetSelection)->{path});
      $type =~ s{Demeter::}{};
      $datapage->status("This path is a $type");
      last SWITCH;
    };

    ($id == $PATH_TRANSFER) and do {
      my $pathpage = $datapage->{pathlist}->GetPage($datapage->{pathlist}->GetSelection);
      $pathpage->transfer;
      last SWITCH;
    };

    ($id == $PATH_4PARAM) and do {
      $datapage -> fourparam;
      last SWITCH;
    };

    ($id == $PATH_FSPATH) and do {
      $datapage -> quickfs;
      last SWITCH;
    };

    ($id == $PATH_EMPIRICAL) and do {
      $datapage -> empirical;
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
	$datapage->status("Path parameter editing canceled.");
	return;
      };
      my ($param, $me, $how) = ($param_dialog->{param}, $param_dialog->{me}->GetValue, $param_dialog->{apply}->GetSelection);
      $datapage->add_parameters($param, $me, $how, 0);
      last SWITCH;
    };

    (($id == $PATH_EXPORT_FEFF) or ($id == $PATH_EXPORT_DATA) or ($id == $PATH_EXPORT_EACH) or ($id == $PATH_EXPORT_MARKED)) and do {
      $datapage->export_pp($id);
      last SWITCH;
    };

    (($id == $FIT_SAVE_K)  or ($id == $FIT_SAVE_K1) or ($id == $FIT_SAVE_K2) or ($id == $FIT_SAVE_K3) or
     ($id == $FIT_SAVE_RM) or ($id == $FIT_SAVE_RR) or ($id == $FIT_SAVE_RI) or
     ($id == $FIT_SAVE_QM) or ($id == $FIT_SAVE_QR) or ($id == $FIT_SAVE_QI)
    ) and do {
      $datapage->save_fit($id);
      last SWITCH;
    };
    (($id == $PATH_SAVE_K) or ($id == $PATH_SAVE_R) or ($id == $PATH_SAVE_Q)) and do {
      $datapage->save_path($id);
      last SWITCH;
    };
    (($id == $DATA_SAVE_K) or ($id == $DATA_SAVE_R) or ($id == $DATA_SAVE_Q)) and do {
      $datapage->save_data($id);
      last SWITCH;
    };
    (($id == $MARKED_SAVE_K)  or ($id == $MARKED_SAVE_K1) or ($id == $MARKED_SAVE_K2) or ($id == $MARKED_SAVE_K3) or
     ($id == $MARKED_SAVE_RM) or ($id == $MARKED_SAVE_RR) or ($id == $MARKED_SAVE_RI) or
     ($id == $MARKED_SAVE_QM) or ($id == $MARKED_SAVE_QR) or ($id == $MARKED_SAVE_QI)
    ) and do {
      $datapage->save_marked_paths($id);
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
    ($id == $ACTION_AFTER) and do {
      $datapage->flag('marked');
      last SWITCH;
    };
    ($id == $ACTION_NONEAFTER) and do {
      $datapage->flag('none');
      last SWITCH;
    };

    ($id == $PATH_CLONE) and do {
      $datapage->clone;
      last SWITCH;
    };

    ($id == $PATH_EXP_LABEL) and do {
      $datapage->status($Demeter::UI::Artemis::Pathexplanation{label});
      last SWITCH;
    };
    ($id == $PATH_EXP_N) and do {
      $datapage->status($Demeter::UI::Artemis::Path::explanation{n});
      last SWITCH;
    };
    ($id == $PATH_EXP_S02) and do {
      $datapage->status($Demeter::UI::Artemis::Path::explanation{s02});
      last SWITCH;
    };
    ($id == $PATH_EXP_E0) and do {
      $datapage->status($Demeter::UI::Artemis::Path::explanation{e0});
      last SWITCH;
    };
    ($id == $PATH_EXP_DELR) and do {
      $datapage->status($Demeter::UI::Artemis::Path::explanation{delr});
      last SWITCH;
    };
    ($id == $PATH_EXP_SIGMA2) and do {
      $datapage->status($Demeter::UI::Artemis::Path::explanation{sigma2});
      last SWITCH;
    };
    ($id == $PATH_EXP_EI) and do {
      $datapage->status($Demeter::UI::Artemis::Path::explanation{ei});
      last SWITCH;
    };
    ($id == $PATH_EXP_THIRD) and do {
      $datapage->status($Demeter::UI::Artemis::Path::explanation{third});
      last SWITCH;
    };
    ($id == $PATH_EXP_FOURTH) and do {
      $datapage->status($Demeter::UI::Artemis::Path::explanation{fourth});
      last SWITCH;
    };

    ($id == $WINDOW_HANNING) and do {
      Demeter->co->set_default('artemis', 'window_function', 'hanning');
      $datapage->status("Using a Hanning window for all Fourier transforms.");
      last SWITCH;
    };
    ($id == $WINDOW_KB) and do {
      Demeter->co->set_default('artemis', 'window_function', 'kaiser-bessel');
      $datapage->status("Using a Kaiser-Bessel window for all Fourier transforms.");
      last SWITCH;
    };
    ($id == $WINDOW_WELCH) and do {
      Demeter->co->set_default('artemis', 'window_function', 'welch');
      $datapage->status("Using a Welch window for all Fourier transforms.");
      last SWITCH;
    };
    ($id == $WINDOW_PARZEN) and do {
      Demeter->co->set_default('artemis', 'window_function', 'parzen');
      $datapage->status("Using a Parzen window for all Fourier transforms.");
      last SWITCH;
    };
    ($id == $WINDOW_SINE) and do {
      Demeter->co->set_default('artemis', 'window_function', 'sine');
      $datapage->status("Using a Sine window for all Fourier transforms.");
      last SWITCH;
    };

    ($id == $DOCUMENT_DATA) and do {
      $::app->document('data');
      last SWITCH;
    };
    ($id == $DOCUMENT_PATH) and do {
      $::app->document('path');
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
  my ($datapage, $newname) = @_;
  my $dnum = $datapage->{dnum};
  (my $id = $dnum) =~ s{data}{};

  my $name = $datapage->{data}->name;
  if (not $newname) {
    my $ted = Wx::TextEntryDialog->new($datapage, "Enter a new name for \"$name\":", "Rename \"$name\"", q{}, wxOK|wxCANCEL, Wx::GetMousePosition);
    if ($ted->ShowModal == wxID_CANCEL) {
      $datapage->status("Data renaming canceled.");
      return;
    };
    $newname = $ted->GetValue;
  };
  $datapage->{data}->name($newname);
  $datapage->{name}->SetLabel($newname);
  $Demeter::UI::Artemis::frames{main}->{$dnum}->SetLabel(join("", "Show ", '"', $newname, '"'));
  $datapage -> SetTitle("Artemis [Data] ".$newname);

  my $plotlist = $Demeter::UI::Artemis::frames{Plot}->{plotlist};
  foreach my $i (0 .. $plotlist->GetCount-1) {
    if ($datapage->{data}->group eq $plotlist->GetIndexedData($i)->group) {
      my $checked = $plotlist->IsChecked($i);
      $plotlist->SetString($i, "Data: ".$newname);
      $plotlist->Check($i, $checked);
    };
  };

  Demeter::UI::Artemis::modified(1);
};

sub replace {
  my ($datapage) = @_;
  my $dnum = $datapage->{dnum};
  my $was = $datapage->{data}->name;
  $datapage->{data}->DEMOLISH;
  my ($file, $prj, $record) = prjrecord();
  if (not $prj) {
    $datapage->{PARENT}->status("Replacing data canceled" );
    return;
  };
  my $data = $prj->record($record);
  my $is = $data->name;
  $datapage->{data} = $data;
  $datapage->{titles}->SetValue(join("\n", @{ $data->titles }));
  $datapage->{name}->SetLabel($data->name);
  $datapage->{datasource}->SetValue($data->prjrecord);
  foreach my $n (0 .. $datapage->{pathlist}->GetPageCount-1) {
    my $page = $datapage->{pathlist}->GetPage($n);
    my $pathobject = $datapage->{pathlist}->{LIST}->GetIndexedData($n)->{path};
    $pathobject->data($data);
  };
  $datapage->fetch_parameters;
  $datapage->Rename($is);
  $Demeter::UI::Artemis::frames{main}->{$dnum}->SetLabel(join("", "Show ", '"', $datapage->{data}->name, '"'));
#  $Demeter::UI::Artemis::frames{main}->{$dnum}->SetLabel($datapage->{data}->name);
  #Demeter::UI::Artemis::modified(1);

  ## fixy up fit description in the case that the autogenerated description is still there
  my $desc = $Demeter::UI::Artemis::frames{main}->{description}->GetValue;
  $desc =~ s{$was}{$is}g;
  $Demeter::UI::Artemis::frames{main}->{description}->SetValue($desc);

  if ($was eq $is) {
    $datapage->{PARENT}->status("Reimported \"$was\"" );
  } else {
    $datapage->{PARENT}->status("Replaced \"$was\" with \"$is\"" );
  };
};

sub set_degens {
  my ($self, $how) = @_;
  foreach my $n (0 .. $self->{pathlist}->GetPageCount-1) {
    my $page = $self->{pathlist}->GetPage($n);
    my $pathobject = $self->{pathlist}->{LIST}->GetIndexedData($n)->{path};
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
  my ($self, $param, $me, $how, $silent) = @_;
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
      my $path = $self->{pathlist}->GetPage($n)->{path};
      $self->{pathlist}->GetPage($n)->{"pp_$param"}->SetValue($me);
    };
    $which = "the marked paths";
  };
  $self->status("Set $param to \"$me\" for $which." ) if not $silent;
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
      $self->add_parameters($pp, $displayed_path->{"pp_$pp"}->GetValue, $how, 1);
    };
  };
  my $which = ('each path in this Feff calculation',
	       'each path in this data set',
	       'each path in each data set',
	       'the marked paths')[$how];
  $self->status("Exported these path parameters to $which." );
};

sub save_fit {
  my ($self, $mode, $filename) = @_;
  my $how = (lc($mode) =~ m{\A(?:k[123]?|r[imr]|q[imr])\z}) ? lc($mode)
          : ($mode == $FIT_SAVE_K)      ? 'k'
          : ($mode == $FIT_SAVE_K1)     ? 'k1'
          : ($mode == $FIT_SAVE_K2)     ? 'k2'
          : ($mode == $FIT_SAVE_K3)     ? 'k3'
          : ($mode == $FIT_SAVE_RM)     ? 'rmag'
          : ($mode == $FIT_SAVE_RR)     ? 'rre'
          : ($mode == $FIT_SAVE_RI)     ? 'rim'
          : ($mode == $FIT_SAVE_QM)     ? 'qmag'
          : ($mode == $FIT_SAVE_QR)     ? 'qre'
          : ($mode == $FIT_SAVE_QI)     ? 'qim'
	  :                               'k';

  my $data = $self->{data};
  if (not $filename) {
    my $suggest = $data->name;
    $suggest =~ s{\A\s+}{};
    $suggest =~ s{\s+\z}{};
    $suggest =~ s{\s+}{_}g;
    $suggest = sprintf("%s.%s", $suggest, $how);
    my $fd = Wx::FileDialog->new( $self, "Save path", cwd, $suggest,
				  "Data and fit (*.$how)|*.$how|All files (*)|*",
				  wxFD_SAVE|wxFD_CHANGE_DIR, #|wxFD_OVERWRITE_PROMPT,
				  wxDefaultPosition);
    if ($fd->ShowModal == wxID_CANCEL) {
      $self->status("Saving data and fit canceled.");
      return;
    };
    $filename = $fd->GetPath;
    return if $self->overwrite_prompt($filename); # work-around gtk's wxFD_OVERWRITE_PROMPT bug (5 Jan 2011)
  };
  $data->save('fit', $filename, $how);
  $self->status("Saved data and fit as $how to $filename." );
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
				  "Demeter fitting project (*.$suff)|*.$suff|All files (*)|*",
				  wxFD_SAVE|wxFD_CHANGE_DIR, #|wxFD_OVERWRITE_PROMPT,
				  wxDefaultPosition);
    if ($fd->ShowModal == wxID_CANCEL) {
      $self->status("Saving path canceled.");
      return;
    };
    $filename = $fd->GetPath;
    return if $self->overwrite_prompt($filename); # work-around gtk's wxFD_OVERWRITE_PROMPT bug (5 Jan 2011)
  };
  $path->save($space, $filename);
  $self->status("Saved path \"".$path->name."\"to $space space as $filename." );
};

sub save_data {
  my ($self, $mode, $filename) = @_;
  my $space = (lc($mode) =~ m{\A[kqr]\z}) ? lc($mode)
            : ($mode == $DATA_SAVE_K)     ? 'k'
            : ($mode == $DATA_SAVE_R)     ? 'r'
            : ($mode == $DATA_SAVE_Q)     ? 'q'
	    :                               'k';
  my $data = $self->{data};
  if (not $filename) {
    my $suggest = $data->name;
    $suggest =~ s{\A\s+}{};
    $suggest =~ s{\s+\z}{};
    $suggest =~ s{\s+}{_}g;
    $suggest = sprintf("%s.%s%s", $suggest, $space, 'sp');
    my $suff = sprintf("%s%s", $space, 'sp');
    my $fd = Wx::FileDialog->new( $self, "Save data in $space-space", cwd, $suggest,
				  "Data file (*.$suff)|*.$suff|All files (*)|*",
				  wxFD_SAVE|wxFD_CHANGE_DIR, #|wxFD_OVERWRITE_PROMPT,
				  wxDefaultPosition);
    if ($fd->ShowModal == wxID_CANCEL) {
      $self->status("Saving data canceled.");
      return;
    };
    $filename = $fd->GetPath;
    return if $self->overwrite_prompt($filename); # work-around gtk's wxFD_OVERWRITE_PROMPT bug (5 Jan 2011)
  };
  $data->save($space, $filename);
  $self->status("Saved data \"".$data->name."\"to $space space as $filename." );
};


## chi chik chik2 chik3
## chir_mag chir_re chir_im chir_phas
## chiq_mag chiq_re chiq_im chiq_pha
sub save_marked_paths {
  my ($self, $mode, $filename) = @_;
  my $how = (lc($mode) =~ m{\A(?:k[123]?|r[imr]|q[imr])\z}) ? lc($mode)
          : ($mode == $MARKED_SAVE_K)      ? 'chik'
          : ($mode == $MARKED_SAVE_K1)     ? 'chik1'
          : ($mode == $MARKED_SAVE_K2)     ? 'chik2'
          : ($mode == $MARKED_SAVE_K3)     ? 'chik3'
          : ($mode == $MARKED_SAVE_RM)     ? 'chir_mag'
          : ($mode == $MARKED_SAVE_RR)     ? 'chir_re'
          : ($mode == $MARKED_SAVE_RI)     ? 'chir_im'
          : ($mode == $MARKED_SAVE_QM)     ? 'chiq_mag'
          : ($mode == $MARKED_SAVE_QR)     ? 'chiq_re'
          : ($mode == $MARKED_SAVE_QI)     ? 'chiq_im'
	  :                                  'chik';

  my $data = $self->{data};
  my @list;
  foreach my $i (0 .. $self->{pathlist}->GetPageCount-1) {
    my $pathpage = $self->{pathlist}->{LIST}->GetIndexedData($i);
    if (($self->{pathlist}->IsChecked($i)) and ($pathpage->{include}->GetValue)) {
      push @list, $pathpage->{path};
    };
  };

  if (not $filename) {
    my $suggest = $data->name;
    $suggest =~ s{\A\s+}{};
    $suggest =~ s{\s+\z}{};
    $suggest =~ s{\s+}{_}g;
    $suggest = sprintf("%s%s.%s", $suggest, '+paths', $how);
    my $fd = Wx::FileDialog->new( $self, "Save data and marked paths", cwd, $suggest,
				  "Data and paths (*.$how)|*.$how|All files (*)|*",
				  wxFD_SAVE|wxFD_CHANGE_DIR, #|wxFD_OVERWRITE_PROMPT,
				  wxDefaultPosition);
    if ($fd->ShowModal == wxID_CANCEL) {
      $self->status("Saving data and fit canceled.");
      return;
    };
    $filename = $fd->GetPath;
    return if $self->overwrite_prompt($filename); # work-around gtk's wxFD_OVERWRITE_PROMPT bug (5 Jan 2011)
  };
  $data->save_many($filename, $how, @list);
  $self->status("Saved data and marked paths as $how to $filename." );
};

sub mark {
  my ($self, $mode) = @_;

  $self->status("No paths have been assigned to this data yet."),
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
      $self->status("$word all paths.");
      last SWITCH;
    };
    ($how eq 'invert') and do {
      foreach my $i (0 .. $self->{pathlist}->GetPageCount-1) {
	my $this = $self->{pathlist}->IsChecked($i);
	$self->{pathlist}->Check($i, not $this);
      };
      $self->status("Inverted all marks.");
      last SWITCH;
    };
    ($how eq 'regexp') and do {
      my $regex = q{};
      my $ted = Wx::TextEntryDialog->new( $self, "Mark paths matching this regular expression:", "Enter a regular expression", q{}, wxOK|wxCANCEL, Wx::GetMousePosition);
      if ($ted->ShowModal == wxID_CANCEL) {
	$self->status("Path marking canceled.");
	return;
      };
      $regex = $ted->GetValue;
      my $re;
      my $is_ok = eval '$re = qr/$regex/';
      if (not $is_ok) {
	$self->{PARENT}->status("Oops!  \"$regex\" is not a valid regular expression");
	return;
      };
      foreach my $i (0 .. $self->{pathlist}->GetPageCount-1) {
	$self->{pathlist}->Check($i, 1) if ($self->{pathlist}->GetPageText($i) =~ m{$re});
      };
      $self->status("Marked all paths matching /$regex/.");
      last SWITCH;
    };

    ($how eq 'ss') and do {
      foreach my $i (0 .. $self->{pathlist}->GetPageCount-1) {
	my $path = $self->{pathlist}->GetPage($i)->{path};
	$self->{pathlist}->Check($i, 1) if ($path->sp->nleg == 2);
      };
      $self->status("Marked all single scattering paths.");
      last SWITCH;
    };
    ($how eq 'ms') and do {
      foreach my $i (0 .. $self->{pathlist}->GetPageCount-1) {
	my $path = $self->{pathlist}->GetPage($i)->{path};
	$self->{pathlist}->Check($i, 1) if ($path->sp->nleg > 2);
      };
      $self->status("Marked all multiple scattering paths.");
      last SWITCH;
    };
    ($how eq 'high') and do {
      foreach my $i (0 .. $self->{pathlist}->GetPageCount-1) {
	my $path = $self->{pathlist}->GetPage($i)->{path};
	$self->{pathlist}->Check($i, 1) if ($path->sp->weight==2);
      };
      $self->status("Marked all high importance paths.");
      last SWITCH;
    };
    ($how eq 'mid') and do {
      foreach my $i (0 .. $self->{pathlist}->GetPageCount-1) {
	my $path = $self->{pathlist}->GetPage($i)->{path};
	$self->{pathlist}->Check($i, 1) if ($path->sp->weight==1);
      };
      $self->status("Marked all mid importance paths.");
      last SWITCH;
    };
    ($how eq 'low') and do {
      foreach my $i (0 .. $self->{pathlist}->GetPageCount-1) {
	my $path = $self->{pathlist}->GetPage($i)->{path};
	$self->{pathlist}->Check($i, 1) if ($path->sp->weight==0);
      };
      $self->status("Marked all low importance paths.");
      last SWITCH;
    };
    (($how eq 'longer') or ($how eq 'shorter')) and do {
      my $ted = Wx::TextEntryDialog->new( $self, "Mark paths $how than this path length:", "Enter a path length", q{}, wxOK|wxCANCEL, Wx::GetMousePosition);
      if ($ted->ShowModal == wxID_CANCEL) {
	$self->status("Path marking canceled.");
	return;
      };
      my $r = $ted->GetValue;
      if ($r !~ m{$NUMBER}) {
	$self->status("Oops!  That wasn't a number.");
	return;
      };
      foreach my $i (0 .. $self->{pathlist}->GetPageCount-1) {
	my $path = $self->{pathlist}->GetPage($i)->{path};
	$self->{pathlist}->Check($i, 1) if (($how eq 'shorter') and ($path->sp->fuzzy < $r));
	$self->{pathlist}->Check($i, 1) if (($how eq 'longer')  and ($path->sp->fuzzy > $r));
      };
      $self->status("Marked all paths $how than $r " . chr(197) . '.');
      last SWITCH;
    };

    ($how eq 'before') and do {
      my $sel = $self->{pathlist}->GetSelection;
      foreach my $i (0 .. $self->{pathlist}->GetPageCount-1) {
	last if ($i > $sel);
	$self->{pathlist}->Check($i, 1);
      };
      $self->status("Marked this path and all paths before this one.");
      last SWITCH;
    };
    ($how eq 'after') and do {
      my $sel = $self->{pathlist}->GetSelection;
      foreach my $i (0 .. $self->{pathlist}->GetPageCount-1) {
	next if ($i <= $sel);
	$self->{pathlist}->Check($i, 1);
      };
      $self->status("Marked all paths after this one.");
      last SWITCH;
    };

    ($how eq 'included') and do {
      foreach my $i (0 .. $self->{pathlist}->GetPageCount-1) {
	my $path = $self->{pathlist}->GetPage($i)->{path};
	$self->{pathlist}->Check($i, 1) if $path->include;
      };
      $self->status("Marked all paths included in the fit.");
      last SWITCH;
    };

    ($how eq 'excluded') and do {
      foreach my $i (0 .. $self->{pathlist}->GetPageCount-1) {
	my $path = $self->{pathlist}->GetPage($i)->{path};
	$self->{pathlist}->Check($i, 1) if not $path->include;
      };
      $self->status("Marked all paths excluded from the fit.");
      last SWITCH;
    };
  };
};

sub include {
  my ($self, $mode) = @_;
  my $how = ($mode !~ m{$NUMBER})      ? $mode
          : ($mode == $INCLUDE_MARKED) ? 'marked'
          : ($mode == $EXCLUDE_MARKED) ? 'marked_none'
          :                              $mode;

  my $npaths = $self->{pathlist}->GetPageCount-1;
 SWITCH: {
    ($how eq 'all') and do {
      foreach my $i (0 .. $npaths) {
	my $pathpage = $self->{pathlist}->{LIST}->GetIndexedData($i);
	$pathpage->{include}->SetValue(1);
	$pathpage->include_label(0,$i);
      };
      $self->status("Included all paths in the fit.");
      last SWITCH;
    };

    ($how eq 'none') and do {
      foreach my $i (0 .. $npaths) {
	my $pathpage = $self->{pathlist}->{LIST}->GetIndexedData($i);
	$pathpage->{include}->SetValue(0);
	$pathpage->include_label(0,$i);
      };
      $self->status("Excluded all paths from the fit.");
      last SWITCH;
    };

    ($how eq 'invert') and do {
      foreach my $i (0 .. $npaths) {
	my $pathpage = $self->{pathlist}->{LIST}->GetIndexedData($i);
	my $onoff = ($pathpage->{include}->IsChecked) ? 0 : 1;
	$pathpage->{include}->SetValue($onoff);
	$pathpage->include_label(0,$i);
      };
      $self->status("Inverted which paths are included in the fit.");
      last SWITCH;
    };

    ($how eq 'marked') and do {
      foreach my $i (0 .. $npaths) {
	my $pathpage = $self->{pathlist}->{LIST}->GetIndexedData($i);
	next if not $self->{pathlist}->IsChecked($i);
	$pathpage->{include}->SetValue(1);
	$pathpage->include_label(0,$i);
      };
      $self->status("Included marked paths in the fit.");
      last SWITCH;
    };

    ($how eq 'marked_none') and do {
      foreach my $i (0 .. $npaths) {
	my $pathpage = $self->{pathlist}->{LIST}->GetIndexedData($i);
	next if not $self->{pathlist}->IsChecked($i);
	$pathpage->{include}->SetValue(0);
	$pathpage->include_label(0,$i);
      };
      $self->status("Excluded marked paths from the fit.");
      last SWITCH;
    };

    ($how eq 'after') and do {
      my $sel = $self->{pathlist}->GetSelection;
      foreach my $i (0 .. $npaths) {
	next if ($i <= $sel);
	my $pathpage = $self->{pathlist}->{LIST}->GetIndexedData($i);
	$pathpage->{include}->SetValue(0);
	$pathpage->include_label(0,$i);
      };
      $self->status("Excluded all paths after the one currently displayed from the fit.");
      last SWITCH;
    };

    ($how eq 'ss') and do {
      foreach my $i (0 .. $npaths) {
	my $pathpage = $self->{pathlist}->{LIST}->GetIndexedData($i);
	my $path = $pathpage->{path};
	next if not ($path->sp->nleg == 2);
	$pathpage->{include}->SetValue(1);
	$pathpage->include_label(0,$i);
      };
      $self->status("Included all single scattering paths in the fit.");
      last SWITCH;
    };

    ($how eq 'high') and do {
      foreach my $i (0 .. $npaths) {
	my $pathpage = $self->{pathlist}->{LIST}->GetIndexedData($i);
	my $path = $pathpage->{path};
	next if not ($path->sp->weight == 2);
	$pathpage->{include}->SetValue(1);
	$pathpage->include_label(0,$i);
      };
      $self->status("Included all high importance paths in the fit.");
      last SWITCH;
    };

    ($how eq 'r') and do {
      my $ted = Wx::TextEntryDialog->new( $self, "Include shorter than this path length:", "Enter a path length", q{}, wxOK|wxCANCEL, Wx::GetMousePosition);
      if ($ted->ShowModal == wxID_CANCEL) {
	$self->status("Path inclusion canceled.");
	return;
      };
      my $r = $ted->GetValue;
      if ($r !~ m{$NUMBER}) {
	$self->status("Oops!  That wasn't a number.");
	return;
      };
      foreach my $i (0 .. $npaths) {
	my $pathpage = $self->{pathlist}->{LIST}->GetIndexedData($i);
	my $path = $pathpage->{path};
	next if ($path->sp->fuzzy > $r);
	$pathpage->{include}->SetValue(1);
	$pathpage->include_label(0,$i);
      };
      $self->status("Included all paths shorter than $r " . chr(197) . '.');
      last SWITCH;
    };


  };
};

sub discard_data {
  my ($self, $force) = @_;
  my $dataobject = $self->{data};

  if (not $force) {
    my $yesno = Demeter::UI::Wx::VerbDialog->new($self, -1,
						 "Do you really wish to discard this data set?",
						 "Discard?",
						 "Discard");
    return if ($yesno->ShowModal == wxID_NO);
  };

  ## remove data and its paths & VPaths from the plot list
  my $plotlist = $Demeter::UI::Artemis::frames{Plot}->{plotlist};
  foreach my $i (reverse (0 .. $plotlist->GetCount-1)) {
    if ($self->{data}->group eq $plotlist->GetIndexedData($i)->data->group) {
      $plotlist->DeleteData($i);
    };
  };

  ## get rid of all the paths
  $self->discard('all');

  my $dnum = $self->{dnum};

  ## destroy the data object
  $dataobject->clear_ifeffit_titles;
  $dataobject->dispense('process', 'erase', {items=>"\@group ".$dataobject->group});
  $dataobject->DEMOLISH;

  ## remove the frame with the datapage
  $Demeter::UI::Artemis::frames{$dnum}->Hide;
  $Demeter::UI::Artemis::frames{$dnum}->Destroy;
  delete $Demeter::UI::Artemis::frames{$dnum};
  ## that's not quite right!

  ## remove the button from the data tool bar
  $Demeter::UI::Artemis::frames{main}->{databox}->Hide($Demeter::UI::Artemis::frames{main}->{$dnum});
  $Demeter::UI::Artemis::frames{main}->{databox}->Detach($Demeter::UI::Artemis::frames{main}->{$dnum});
  $Demeter::UI::Artemis::frames{main}->{databox}->Layout;
  #$Demeter::UI::Artemis::frames{main}->{$dnum}->Destroy; ## this causes a segfaul .. why?
};

sub discard {
  my ($self, $mode) = @_;
  my $how = (ref($mode) =~ m{Feff})      ? 'feff'
          : ($mode !~ m{$NUMBER})        ? $mode
          : ($mode == $DISCARD_THIS)     ? 'this'
          : ($mode == $DISCARD_MARKED)   ? 'marked'
          : ($mode == $DISCARD_UNMARKED) ? 'unmarked'
          :                                $mode;
  my $npaths = $self->{pathlist}->GetPageCount-1;
  my $sel    = $self->{pathlist}->GetSelection;
  my $page   = $self->{pathlist}->GetPage($sel);
  my $text   = q{};
  my @count  = reverse(0 .. $npaths);

 SWITCH: {
    ($how eq 'this') and do {
      my $path = $self->{pathlist}->GetPage($sel)->{path};
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

    ($how eq 'feff') and do {
      foreach my $i (@count) {
	if (exists($self->{pathlist}->GetPage($i)->{path}) and # Path pages may not yet exist ...
	    ($self->{pathlist}->GetPage($i)->{path}->parent eq $mode)) {
	  $self->{pathlist}->DeletePage($i);
	  ($sel = 0) if ($sel = $i);
	};
      };
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
	$self->status("Path discarding canceled.");
	return;
      };
      my $r = $ted->GetValue;
      if ($r !~ m{$NUMBER}) {
	$self->status("Oops!  That wasn't a number.");
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
  $self->status($text);
  $self->{pathlist}->InitialPage if (not $self->{pathlist}->{VIEW});
};

sub flag {
  my ($self, $mode) = @_;
  my $how = ($mode !~ m{$NUMBER})        ? $mode
          : ($mode == $ACTION_AFTER)     ? 'marked'
          : ($mode == $ACTION_NONEAFTER) ? 'none'
          :                                $mode;
  my $npaths = $self->{pathlist}->GetPageCount-1;
  my $text = ($how eq 'marked') ? "Flagged marked paths for transfer to plotting list after a fit."
           :                      "Unflagged all paths for transfer to plotting list.";
  foreach my $i (0 .. $npaths) {
    my $pathpage = $self->{pathlist}->{LIST}->GetIndexedData($i);
    if ($how eq 'marked') {
      if (($self->{pathlist}->IsChecked($i)) and ($pathpage->{include}->GetValue)) {
	$pathpage->{plotafter}->SetValue(1);
      };
    } elsif ($how eq 'none') {
      $pathpage->{plotafter}->SetValue(0);
    };
  };
  $self->status($text);
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
    if ($thisgroup eq $plotlist->GetIndexedData($i)->group) {
      $found = 1;
      last;
    };
  };
  if ($found) {
    $self->status("\"$name\" is already in the plotting list.");
    return;
  };
  $plotlist->AddData("Data: $name", $self->{data});
  my $i = $plotlist->GetCount - 1;
  #$plotlist->SetClientData($i, $self->{data});
  $plotlist->Check($i,1);
  $self->status("Transfered data set \"$name\" to the plotting list.");
};


sub clone {
  my ($datapage) = @_;
  my $pathpage = $datapage->{pathlist}->GetPage($datapage->{pathlist}->GetSelection);
  my $path = $pathpage->{path};
  $path->n($path->n / 2);
  $pathpage->{pp_n}->SetValue($path->n);

  my $cloned = $path->clone(n => $path->n);
  $cloned->name($path->name . " (clone)");

  my $newpage = Demeter::UI::Artemis::Path->new($datapage->{pathlist}, $cloned, $datapage);
  $datapage->{pathlist}->AddPage($newpage, $cloned->name, 1, 0, $datapage->{pathlist}->GetSelection+1);
  $newpage->{pp_n}->SetValue($path->n);
  $newpage->include_label(0,$datapage->{pathlist}->GetSelection);

  $datapage->status("Cloned \"" . $path->name . "\" and set N to half its value for the new and old paths.");
};


my @element_list = qw(h he li be b c n o f ne na mg al si p s cl ar k ca
		      sc ti v cr mn fe co ni cu zn ga ge as se br kr rb
		      sr y zr nb mo tc ru rh pd ag cd in sn sb te i xe cs
		      ba la ce pr nd pm sm eu gd tb dy ho er tm yb lu hf
		      ta w re os ir pt au hg tl pb bi po at rn fr ra ac
		      th pa u np pu am cm bk cf);
my $element_regexp = Regexp::Assemble->new()->add(@element_list)->re;

sub fourparam {
  my ($datapage) = @_;
  my $count = 0;
  foreach my $i (0 .. $datapage->{pathlist}->GetPageCount-1) {
    my $path = $datapage->{pathlist}->GetPage($i)->{path};
    next if not defined($path);
    $path->set(s02=>'amp', e0=>'enot', delr=>'delr', sigma2=>'ss');
    $datapage->{pathlist}->GetPage($i)->{pp_s02}   ->SetValue('amp');
    $datapage->{pathlist}->GetPage($i)->{pp_e0}    ->SetValue('enot');
    $datapage->{pathlist}->GetPage($i)->{pp_delr}  ->SetValue('delr');
    $datapage->{pathlist}->GetPage($i)->{pp_sigma2}->SetValue('ss');
    ++$count;
  };
  if (not $count) {
    $datapage->status("Skipping quick 4-parameter fit -- no paths have been imported yet.");
    return;
  };
  my $gds = Demeter::GDS->new(gds=>'guess', name=>'amp',  mathexp=>1);
  $Demeter::UI::Artemis::frames{GDS}->put_gds($gds);
  $gds    = Demeter::GDS->new(gds=>'guess', name=>'enot', mathexp=>0);
  $Demeter::UI::Artemis::frames{GDS}->put_gds($gds);
  $gds    = Demeter::GDS->new(gds=>'guess', name=>'delr', mathexp=>0);
  $Demeter::UI::Artemis::frames{GDS}->put_gds($gds);
  $gds    = Demeter::GDS->new(gds=>'guess', name=>'ss',   mathexp=>0.003);
  $Demeter::UI::Artemis::frames{GDS}->put_gds($gds);
  $Demeter::UI::Artemis::frames{GDS}->reset_all;
  $datapage->status("Made a quick 4-parameter fit by defining amp, enot, delr, and ss.");
};

sub quickfs {
  my ($datapage) = @_;

  my $dialog = Demeter::UI::Artemis::Data::Quickfs->new($datapage);
  my $result = $dialog -> ShowModal;
  if ($result == wxID_CANCEL) {
    $datapage->status("Canceled quick first shell model creation.");
    return;
  };

  my $busy = Wx::BusyCursor->new();
  my ($abs, $scat, $distance, $edge, $make) = ($dialog->{abs}->GetValue,
					       $dialog->{scat}->GetValue,
					       $dialog->{distance}->GetValue,
					       $dialog->{edge}->GetStringSelection,
					       $dialog->{make}->GetValue,);

  if (lc($abs) !~ m{\A$element_regexp\z}) {
    $datapage->status("Absorber $abs is not a valid element symbol.");
    return;
  };
  if (lc($scat) !~ m{\A$element_regexp\z}) {
    $datapage->status("Scatterer $scat is not a valid element symbol.");
    return;
  };

  my $firstshell = Demeter::FSPath->new();
  $firstshell -> set(make_gds  => $make,
		     edge      => $edge,
		     abs       => $abs,
		     scat      => $scat,
		     distance  => $distance,
		     data      => $datapage->{data},
		    );
  if ($firstshell->error) {
    my $okcancel = Demeter::UI::Wx::VerbDialog->new($datapage, -1,
						    $firstshell->error . "\n\nDo you want to continue?",
						    "warning!",
						    "Continue");
    if ($okcancel->ShowModal != wxID_YES) {
      $datapage->status("Making quick first shell path canceled.");
      $firstshell -> DEMOLISH;
      return;
    };
  };
  $firstshell->make_name;
  my $ws = File::Spec->catfile($Demeter::UI::Artemis::frames{main}->{project_folder}, 'feff', $firstshell->parent->group);
  $firstshell -> workspace($ws);
  $firstshell -> _update('bft');
  $firstshell -> save_feff_yaml;
  $datapage->{pathlist}->DeletePage(0) if $datapage->{pathlist}->GetPage(0) =~ m{Panel};
  my $page = Demeter::UI::Artemis::Path->new($datapage->{pathlist}, $firstshell, $datapage);
  $datapage->{pathlist}->AddPage($page, "$abs($edge)-$scat", 1, 0);
  $page->{pp_n} -> SetValue(1);
  $page->{pp_label} -> SetValue(sprintf("%s-%s path at %s", $firstshell->absorber, $firstshell->scatterer, $firstshell->reff));

  foreach my $p (@{$firstshell->gds}) {
    $Demeter::UI::Artemis::frames{GDS}->put_gds($p);
  };

  autosave();
  if ($firstshell->error) {
    $datapage->status("QFS path made, but ".$firstshell->error, 'alert');
  };

  undef $busy;

};

sub empirical {
  my ($datapage) = @_;
  my $fd = Wx::FileDialog->new( $datapage, "Import an empirical standard", cwd, q{},
				"Empirical standard (*.es)|*.es|All files (*)|*",
				wxFD_OPEN|wxFD_FILE_MUST_EXIST|wxFD_CHANGE_DIR|wxFD_PREVIEW,
				wxDefaultPosition);
  $datapage->status("Empirical standard import canceled."), return if $fd->ShowModal == wxID_CANCEL;
  my $file  = $fd->GetPath;
  my $fpath = Demeter::FPath->new();
  my $is_ok = $fpath -> deserialize($file);
  $datapage->status("\"$file\" isn't an empirical standard file.", 'error'), return if not $is_ok;
  $fpath -> data($datapage->{data});
  $fpath -> _update('fft');
  $datapage->{pathlist}->DeletePage(0) if ($datapage->{pathlist}->GetPage(0) =~ m{Panel});
  my $page = Demeter::UI::Artemis::Path->new($datapage->{pathlist}, $fpath, $datapage);
  $datapage->{pathlist}->AddPage($page, $fpath->name, 1, 0);
  $page->include_label;
  $datapage->status("Imported \"$file\" as an empirical standard.");
};

sub histogram_sentinal_rdf {
  my ($datapage) = @_;
  my $text = q{};
  if ($datapage->{DISTRIBUTION}->computing_rdf) {
    if ($datapage->{DISTRIBUTION}->count_timesteps) { # increment by timestep  (typically, small cluster, many timestep)

      if (not $datapage->{DISTRIBUTION}->timestep_count % 10) {

	## single scattering histogram
	$text = sprintf("Processing step %d of %d timesteps",
			$datapage->{DISTRIBUTION}->timestep_count, $datapage->{DISTRIBUTION}->{nsteps})
	  if ($datapage->{DISTRIBUTION}->type eq 'ss');

	## nearly collinear histogram
	$text = sprintf("Processing step %d of %d timesteps (every %d-th step)",
			$datapage->{DISTRIBUTION}->timestep_count/$datapage->{DISTRIBUTION}->skip,
			($#{$datapage->{DISTRIBUTION}->clusters}+1)/$datapage->{DISTRIBUTION}->skip,
			$datapage->{DISTRIBUTION}->skip )
	  if (($datapage->{DISTRIBUTION}->type eq 'ncl') or ($datapage->{DISTRIBUTION}->type eq 'thru'));

      };
    } else {			# increment by atomic position (typically large cluster, few/no timesteps)
      if (not $datapage->{DISTRIBUTION}->timestep_count % 250) {

	## any histogram
	$text = sprintf("Processing %d of %d positions",
			$datapage->{DISTRIBUTION}->timestep_count, $datapage->{DISTRIBUTION}->npositions);

      };
    };
  } elsif ($datapage->{DISTRIBUTION}->reading_file) {
    $text = "Reading line $. from ".$datapage->{DISTRIBUTION}->file;
  };
  $datapage->status($text, 'wait|nobuffer') if $text;
  $::app->Yield();
};

sub histogram_sentinal_fpath {
  my ($datapage) = @_;
  my $count = $datapage->{DISTRIBUTION}->fpath_count;
  if (not $count % 5) {
    my $text = sprintf("Making FPath: %d of %d bins processed", $count, $datapage->{DISTRIBUTION}->{nbins});
    $datapage->status($text, 'wait|nobuffer');
  };
  $::app->Yield();
};


## the data for these drop targets comes from Demeter::UI::Atoms::SS.
## there is one drag source for each kind of drop-able path-like
## object.  the data consists of an array reference containing the
## attribute values needed to create an SSPath or a Feff::Distribution
## object

package Demeter::UI::Artemis::Data::DropTarget;

use Wx qw( :everything);
use base qw(Wx::DropTarget);
use Demeter::UI::Artemis::DND::PathDrag;
use Demeter::UI::Artemis::Path;
use Demeter::UI::Wx::SpecialCharacters qw(:all);
#use Demeter::Feff::Distributions;
use File::Basename;

use Scalar::Util qw(looks_like_number);

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
  my $first = ($book->GetPage(0) =~ m{Panel});
  $book->DeletePage(0) if $first;
  my $spref = $this->{DATA}->{Data};
  if (ref($spref) eq 'SCALAR') {
    $this->make_path($spref);
  } elsif ($spref->[0] eq 'SSPath') {
    my $feff = $demeter->mo->fetch("Feff", $spref->[1]);
    my $name = $spref->[2];
    my $reff = $spref->[3];
    my $ipot = $spref->[4];
    if (not looks_like_number($reff)) {
      my $text = "Your distance, $reff, is not a number.  This arbitrary single scattering path cannot be created.";
      $this->{PARENT}->status($text);
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

  } elsif ($spref->[0] eq 'HistogramSS') {
    $this->make_HistogramSS($spref);

  } elsif ($spref->[0] eq 'HistogramNCL') {
    $this->make_HistogramNCL($spref);

  } elsif ($spref->[0] eq 'HistogramThru') {
    $this->make_HistogramThru($spref);

  } else {			#  this is a normal path
    my @sparray = map { $demeter->mo->fetch("ScatteringPath", $_) } @$spref;
    foreach my $sp ( @sparray ) {
      my $thispath = Demeter::Path->new(
					parent => $sp->feff,
					data   => $this->{PARENT}->{data},
					sp     => $sp,
					degen  => $sp->n,
					n      => $sp->n,
				       );
      my $label = $thispath->label;
      my $page = Demeter::UI::Artemis::Path->new($book, $thispath, $this->{PARENT});
      $book->AddPage($page, $label, 1, 0);
      $page->include_label;
      $book->Update;
    };
  };

  $::app->heap_check;
  return $def;
};

sub make_path {
  my ($this, $spref) = @_;
  my $rhash = YAML::Tiny::Load($$spref);
  delete $rhash->{group};
  my $pathlike;
  if (exists $rhash->{ipot}) {          # this is an SSPath
    my $feff = Demeter -> mo -> fetch('Feff', $rhash->{parentgroup});
    delete $rhash->{$_} foreach qw(Type weight string pathtype plottable);
    $pathlike = Demeter::SSPath->new(parent=>$feff);
    $pathlike -> set();
    $pathlike -> sp($pathlike);
    #print $pathlike, "  ", $pathlike->sp, $/;
  } elsif (exists $rhash->{nnnntext}) { # this is an FPath
    $pathlike = Demeter::FPath->new();
    $pathlike -> set(%$rhash);
    $pathlike -> sp($pathlike);
    $pathlike -> parentgroup($pathlike->group);
    $pathlike -> parent($pathlike);
    $pathlike -> workspace($pathlike->stash_folder);
  } elsif (exists $rhash->{absorber}) { # this is an FSPath
    my $feff = Demeter -> mo -> fetch('Feff', $rhash->{parentgroup});
    $pathlike = Demeter::FSPath->new(make_gds=>0);
    delete $rhash->{$_} foreach qw(workspace Type weight string pathtype plottable gds make_gds data);
    $pathlike -> set(%$rhash);
    my $where = Cwd::realpath(File::Spec->catfile($rhash->{folder}, '..', '..', 'feff', basename($feff->workspace)));
    $pathlike -> set(workspace=>$where, folder=>$where, parent=>Demeter -> mo -> fetch('Feff', $rhash->{parentgroup}));
    my $sp = Demeter -> mo -> fetch('ScatteringPath', $pathlike->spgroup);
    $pathlike -> sp($sp);
    $pathlike -> feff_done(1);
  } else {
    $pathlike = Demeter::Path->new(%$rhash);
    my $sp = Demeter -> mo -> fetch('ScatteringPath', $pathlike->spgroup);
    $pathlike -> sp($sp);
    #$pathlike -> folder(q{});
    #print $pathlike, "  ", $pathlike->sp, $/;
  };

  $pathlike->data($this->{PARENT}->{data});
  foreach my $att (qw(delr e0 ei s02 sigma2 third fourth dphase)) {
    $pathlike->$att($rhash->{$att});
  };
  my $book  = $this->{BOOK};
  my $page = Demeter::UI::Artemis::Path->new($book, $pathlike, $this->{PARENT});
  my $i = $book->AddPage($page, $pathlike->name, 1, 0);
  $page->include_label(q{});
  $book->Update;

};


sub make_HistogramSS {
  my ($this, $spref) = @_;
  my $book  = $this->{BOOK};

  my $feff = $demeter->mo->fetch("Feff", $spref->[2]);
  my $do_rattle = $spref->[8];
  my $histogram;
  my $read_file = 1;

  if ((not $spref->[9]) or ($feff->mo->fetch("Distributions", $spref->[9])->type ne 'ss')) {
    $histogram = Demeter::Feff::Distributions->new(type=>'ss');
    $histogram -> set(rmin=>$spref->[4], rmax=>$spref->[5], bin=>$spref->[6], feff=>$feff, ipot=>$spref->[7],);
  } else {
    $histogram = $feff->mo->fetch("Distributions", $spref->[9]);
    $read_file = 0 if ($histogram->file eq $spref->[3]);
    $histogram->rmin($spref->[4]) if ($histogram->rmin != $spref->[4]);
    $histogram->rmax($spref->[5]) if ($histogram->rmax != $spref->[5]);
    $histogram->bin ($spref->[6]) if ($histogram->bin  != $spref->[6]);
    $histogram->ipot($spref->[7]) if ($histogram->ipot != $spref->[7]);
  };
  if (lc($spref->[1]) eq 'lammps') {
    $histogram->count_timesteps(0);
    $histogram->zmax($spref->[11]);
  };

  $this->{PARENT}->{DISTRIBUTION} = $histogram;
  ## this pushes this Distribution object back into the Atoms/Feff frame so it can be reused
  $Demeter::UI::Artemis::frames{$spref->[10]}->{SS}->{DISTRIBUTION} = $histogram;

  my $busy = Wx::BusyCursor->new();
  my $start = DateTime->now( time_zone => 'floating' );
  $histogram->backend($spref->[1]);
  $this->{PARENT}->status("Reading MD time sequence file, please be patient...", 'wait');
  $histogram->sentinal(sub{$this->{PARENT}->histogram_sentinal_rdf});
  $histogram->file($spref->[3]) if $read_file;
  if ($#{$histogram->ssrdf} == -1) {
    $this->{PARENT}->status("Your choice of ipot did not yield any scatterers in the R range selected", 'error');
    undef $busy;
    return;
  };
  #$histogram->sentinal(sub{1});
  my $finish = DateTime->now( time_zone => 'floating' );
  my $dur = $finish->subtract_datetime($start);
  my $finishtext = ($histogram->count_timesteps)
    ? sprintf("Making histogram from %d timesteps (%d minutes, %d seconds)", $histogram->nsteps, $dur->minutes, $dur->seconds)
      : sprintf("Making histogram from %d positions (%d minutes, %d seconds)", $histogram->npositions, $dur->minutes, $dur->seconds);
  $this->{PARENT}->status($finishtext);
  undef $busy;


  $busy = Wx::BusyCursor->new();
  $this->{PARENT}->status("Rebinning histogram into $spref->[6] $ARING bins", 'wait');
  $start = DateTime->now( time_zone => 'floating' );
  $histogram->rebin;
  #$histogram->set(sp=>$sp);
  $histogram->sentinal(sub{$this->{PARENT}->histogram_sentinal_fpath});
  my $composite = $histogram->fpath;
  $histogram->sentinal(sub{1});
  $finish = DateTime->now( time_zone => 'floating' );
  $dur = $finish->subtract_datetime($start);
  $finishtext = sprintf("Rebined and made FPath in %d minutes, %d seconds", $dur->minutes, $dur->seconds);
  $this->{PARENT}->status($finishtext);

  $composite->data($this->{PARENT}->{data});
  my $page = Demeter::UI::Artemis::Path->new($book, $composite, $this->{PARENT});
  $book->AddPage($page, $composite->name, 1, 0);
  $book->Update;
  #$composite->po->start_plot;
  #$composite->plot('r');
  $page->transfer;
  if ($do_rattle) {
    $histogram->rattle(1);
    $this->{PARENT}->status("Rebinning histogram into rattle path with $spref->[6] $ARING bins", 'wait');
    $start = DateTime->now( time_zone => 'floating' );
    $histogram->sentinal(sub{$this->{PARENT}->histogram_sentinal_fpath});
    my $rattle = $histogram->fpath;
    $histogram->sentinal(sub{1});
    $finish = DateTime->now( time_zone => 'floating' );
    $dur = $finish->subtract_datetime($start);
    $finishtext = sprintf("Rebined and made FPath in %d minutes, %d seconds", $dur->minutes, $dur->seconds);
    $this->{PARENT}->status($finishtext);
    $rattle -> data($this->{PARENT}->{data});
    $page = Demeter::UI::Artemis::Path->new($book, $rattle, $this->{PARENT});
    $book->AddPage($page, $rattle->name, 1, 0);
    $book->Update;
    $page->transfer;
  };

  $Demeter::UI::Artemis::frames{Plot}->plot(0, 'r');
  #    $histo_dialog->{DISTRIBUTION} = q{};
  $histogram->DEMOLISH;
  Demeter::UI::Artemis::modified(1);
  undef $busy;
};

sub make_HistogramNCL {
  my ($this, $spref) = @_;
  my $book  = $this->{BOOK};

  my $feff = $demeter->mo->fetch("Feff", $spref->[2]);
  my $histogram = Demeter::Feff::Distributions->new(type=>'ncl');
  $histogram -> set(r1=>$spref->[4], r2=>$spref->[5], r3=>$spref->[6], r4=>$spref->[7],
		    rbin => $spref->[8], betabin => $spref->[9],
		    feff => $feff, ipot => $spref->[10], ipot2 => $spref->[11],
		    skip => $spref->[15], update_bins => 1);
  $this->{PARENT}->{DISTRIBUTION} = $histogram;
  if (lc($spref->[1]) eq 'lammps') {
    $histogram->count_timesteps(0);
    $histogram->zmax($spref->[14]);
  };

  my $busy = Wx::BusyCursor->new();
  my $start = DateTime->now( time_zone => 'floating' );
  $histogram->backend($spref->[1]);
  $this->{PARENT}->status("Reading MD time sequence file, please be patient...", 'wait');
  $histogram->sentinal(sub{$this->{PARENT}->histogram_sentinal_rdf});
  $histogram->file($spref->[3]);
  my $finish = DateTime->now( time_zone => 'floating' );
  my $dur = $finish->subtract_datetime($start);
  my $finishtext = sprintf("Making histogram from %d timesteps (%d minutes, %d seconds)",
			   $histogram->nsteps/$histogram->skip, $dur->minutes, $dur->seconds);
  $this->{PARENT}->status($finishtext);
  undef $busy;

  $busy = Wx::BusyCursor->new();
  $this->{PARENT}->status("Rebinning histogram into $spref->[8] $ARING x $spref->[9] degree bins");
  $start = DateTime->now( time_zone => 'floating' );
  $histogram->rebin;
  $histogram->sentinal(sub{$this->{PARENT}->histogram_sentinal_fpath});
  my $composite = $histogram->fpath;
  $finish = DateTime->now( time_zone => 'floating' );
  $dur = $finish->subtract_datetime($start);
  $finishtext = sprintf("Rebined and made FPath in %d minutes, %d seconds for nearly collinear histogram",
			$dur->minutes, $dur->seconds);
  $this->{PARENT}->status($finishtext);

  $composite->data($this->{PARENT}->{data});
  my $page = Demeter::UI::Artemis::Path->new($book, $composite, $this->{PARENT});
  $book->AddPage($page, $composite->name, 1, 0);
  $book->Update;
  #$composite->po->start_plot;
  #$composite->plot('r');
  $page->transfer;
  $Demeter::UI::Artemis::frames{Plot}->plot(0, 'r');
  $histogram->DEMOLISH;
  undef $busy;
};

sub make_HistogramThru {
  my ($this, $spref) = @_;
  my $book  = $this->{BOOK};

  my $feff = $demeter->mo->fetch("Feff", $spref->[2]);
  my $histogram = Demeter::Feff::Distributions->new(type=>'thru');
  $histogram -> set(rmin=>$spref->[4], rmax=>$spref->[5],
		    rbin => $spref->[6], betabin => $spref->[7],
		    feff=>$feff, ipot => $spref->[8], ipot2 => $spref->[9],
		    skip=>$spref->[13], update_bins=>1);
  $this->{PARENT}->{DISTRIBUTION} = $histogram;
  if (lc($spref->[1]) eq 'lammps') {
    $histogram->count_timesteps(0);
    $histogram->zmax($spref->[12]);
  };

  $histogram->sentinal(sub{$this->{PARENT}->histogram_sentinal_rdf});
  my $busy = Wx::BusyCursor->new();
  my $start = DateTime->now( time_zone => 'floating' );
  $histogram->backend($spref->[1]);
  $this->{PARENT}->status("Reading MD time sequence file, please be patient...", 'wait');
  $histogram->file($spref->[3]);
  my $finish = DateTime->now( time_zone => 'floating' );
  my $dur = $finish->subtract_datetime($start);
  my $finishtext = sprintf("Making histogram from %d timesteps (%d minutes, %d seconds)",
			   $histogram->nsteps/$histogram->skip, $dur->minutes, $dur->seconds);
  $this->{PARENT}->status($finishtext);
  # undef $busy;

  # $busy = Wx::BusyCursor->new();
  $this->{PARENT}->status("Rebinning histogram into $spref->[8] $ARING x $spref->[9] degree bins");
  $start = DateTime->now( time_zone => 'floating' );
  $histogram->rebin;
  $histogram->sentinal(sub{$this->{PARENT}->histogram_sentinal_fpath});
  my $composite = $histogram->fpath;
  $finish = DateTime->now( time_zone => 'floating' );
  $dur = $finish->subtract_datetime($start);
  $finishtext = sprintf("Rebined and made FPath in %d minutes, %d seconds for histogram through absorber",
			$dur->minutes, $dur->seconds);
  $this->{PARENT}->status($finishtext);
  $histogram->sentinal(sub{1});

  $composite->data($this->{PARENT}->{data});
  my $page = Demeter::UI::Artemis::Path->new($book, $composite, $this->{PARENT});
  $book->AddPage($page, $composite->name, 1, 0);
  $book->Update;
  #$composite->po->start_plot;
  #$composite->plot('r');
  $page->transfer;
  $Demeter::UI::Artemis::frames{Plot}->plot(0, 'r');
  $histogram->DEMOLISH;
  undef $busy;
};



1;


=head1 NAME

Demeter::UI::Artemis::Data - Data group interface for Artemis

=head1 VERSION

This documentation refers to Demeter version 0.9.17.

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

=back

Please report problems to Bruce Ravel (bravel AT bnl DOT gov)

Patches are welcome.

=head1 AUTHOR

Bruce Ravel (bravel AT bnl DOT gov)


=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2013 Bruce Ravel (bravel AT bnl DOT gov). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
