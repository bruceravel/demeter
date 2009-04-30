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
use Wx::Event qw(EVT_MENU EVT_CLOSE EVT_TOOL_ENTER EVT_CHECKBOX EVT_CHOICE EVT_BUTTON);
use Wx::DND;
use Wx::Perl::TextValidator;

use Demeter::UI::Artemis::Data::AddParameter;

use List::MoreUtils qw(firstidx);

my $windows = [qw(hanning kaiser-bessel welch parzen sine)];
my $demeter = $Demeter::UI::Artemis::demeter;

use Readonly;
Readonly my $ID_DATA_RENAME  => Wx::NewId();
Readonly my $ID_DATA_DIFF    => Wx::NewId();
Readonly my $ID_DATA_DEGEN_N => Wx::NewId();
Readonly my $ID_DATA_DEGEN_1 => Wx::NewId();
Readonly my $ID_DATA_DISCARD => Wx::NewId();
Readonly my $ID_DATA_EPSK    => Wx::NewId();
Readonly my $ID_DATA_NIDP    => Wx::NewId();

Readonly my $PATH_RENAME => Wx::NewId();
Readonly my $PATH_SHOW   => Wx::NewId();
Readonly my $PATH_ADD    => Wx::NewId();
Readonly my $PATH_EXPORT => Wx::NewId();
Readonly my $PATH_CLONE  => Wx::NewId();

Readonly my $PATH_SAVE_K  => Wx::NewId();
Readonly my $PATH_SAVE_R  => Wx::NewId();
Readonly my $PATH_SAVE_Q  => Wx::NewId();

sub new {
  my ($class, $parent, $nset) = @_;

  my $this = $class->SUPER::new($parent, -1, "Artemis: Data controls",
				wxDefaultPosition, [800,520],
				wxCAPTION|wxMINIMIZE_BOX|wxSYSTEM_MENU|wxRESIZE_BORDER);
  $this->{menubar}   = Wx::MenuBar->new;

  my $degen_menu    = Wx::Menu->new;
  $degen_menu->Append( $ID_DATA_DEGEN_N, "Feff's values", "Set degeneracies for all paths in this data set to values from Feff",  wxITEM_NORMAL );
  $degen_menu->Append( $ID_DATA_DEGEN_1, "one", "Set degeneracies for all paths in this data set to one (1)",  wxITEM_NORMAL );

  $this->{datamenu}  = Wx::Menu->new;
  $this->{datamenu}->Append( $ID_DATA_RENAME,   "Rename this data set",     "Rename this data set",  wxITEM_NORMAL );
  $this->{datamenu}->Append( $ID_DATA_DIFF,     "Make difference spectrum", "Make a difference spectrum using the selected paths", wxITEM_NORMAL );
  $this->{datamenu}->AppendSubMenu($degen_menu, "Set all degeneracies to");
  $this->{datamenu}->AppendSeparator;
  $this->{datamenu}->Append( $ID_DATA_DISCARD, "Discard this data set",    "Discard this data set", wxITEM_NORMAL );
  $this->{datamenu}->AppendSeparator;
  $this->{datamenu}->Append( $ID_DATA_EPSK,    "Show epsilon_k",           "Show statistical noise for these data", wxITEM_NORMAL );
  $this->{datamenu}->Append( $ID_DATA_NIDP,    "Show Nidp",                "Show the number if independent points in these data", wxITEM_NORMAL );


  my $include_menu  = Wx::Menu->new;
  my $discard_menu  = Wx::Menu->new;
  my $save_menu     = Wx::Menu->new;
  $save_menu->Append($PATH_SAVE_K, "χ(k)", "Save the currently displayed path as χ(k)", wxITEM_NORMAL);
  $save_menu->Append($PATH_SAVE_R, "χ(R)", "Save the currently displayed path as χ(R)", wxITEM_NORMAL);
  $save_menu->Append($PATH_SAVE_Q, "χ(q)", "Save the currently displayed path as χ(q)", wxITEM_NORMAL);

  $this->{pathsmenu} = Wx::Menu->new;
  $this->{pathsmenu}->Append( $PATH_RENAME, "Rename path",            "Rename the path currently on display", wxITEM_NORMAL );
  $this->{pathsmenu}->Append( $PATH_SHOW,   "Show path",              "Evaluate and show the path parameters for the currently display path", wxITEM_NORMAL );
  $this->{pathsmenu}->AppendSeparator;
  $this->{pathsmenu}->Append( $PATH_ADD,    "Add path parameter",     "Add path parameter to many paths", wxITEM_NORMAL );
  $this->{pathsmenu}->Append( $PATH_EXPORT, "Export path parameters", "Export path parameters from currently displayed path", wxITEM_NORMAL );
  $this->{pathsmenu}->AppendSeparator;
  $this->{pathsmenu}->AppendSubMenu($include_menu, "Include ...");
  $this->{pathsmenu}->AppendSubMenu($discard_menu, "Discard ...");
  $this->{pathsmenu}->AppendSeparator;
  $this->{pathsmenu}->AppendSubMenu($save_menu, "Save path as ..." );
  $this->{pathsmenu}->Append( $PATH_CLONE, "Clone path", "Make a copy of the currently displayed path", wxITEM_NORMAL );

  $this->{menubar}->Append( $this->{datamenu},  "&Data" );
  $this->{menubar}->Append( $this->{pathsmenu}, "&Paths" );
  $this->SetMenuBar( $this->{menubar} );
  EVT_MENU($this, -1, sub{OnMenuClick(@_)} );

  $this->{statusbar} = $this->CreateStatusBar;
  $this->{statusbar} -> SetStatusText(q{});
  #$this->{statusbar}->SetForegroundColour(Wx::Colour->new("#00ff00")); ??????
  my $hbox  = Wx::BoxSizer->new( wxHORIZONTAL );
  #my $splitter = Wx::SplitterWindow->new($this, -1, wxDefaultPosition, [900,-1], wxSP_3D);
  #$hbox->Add($splitter, 1, wxGROW|wxALL, 1);

  my $leftpane = Wx::Panel->new($this, -1, wxDefaultPosition, wxDefaultSize);
  my $left = Wx::BoxSizer->new( wxVERTICAL );
  $hbox->Add($leftpane, 0, wxGROW|wxALL, 0);

  ## -------- name
  my $namebox  = Wx::BoxSizer->new( wxHORIZONTAL );
  $left    -> Add($namebox, 0, wxGROW|wxTOP|wxBOTTOM, 5);
  $namebox -> Add(Wx::StaticText->new($leftpane, -1, "Name"), 0, wxLEFT|wxRIGHT|wxTOP, 5);
  $this->{name} = Wx::TextCtrl->new($leftpane, -1, q{}, wxDefaultPosition, wxDefaultSize,);
  $namebox -> Add($this->{name}, 1, wxLEFT|wxRIGHT|wxTOP, 5);
  $namebox -> Add(Wx::StaticText->new($leftpane, -1, "CV"), 0, wxLEFT|wxRIGHT|wxTOP, 5);
  $this->{cv} = Wx::TextCtrl->new($leftpane, -1, $nset, wxDefaultPosition, [60,-1],);
  $namebox -> Add($this->{cv}, 0, wxGROW|wxLEFT|wxRIGHT|wxTOP, 5);

  ## -------- file name and record number
  my $filebox  = Wx::BoxSizer->new( wxHORIZONTAL );
  $left    -> Add($filebox, 0, wxGROW|wxALL, 0);
  $filebox -> Add(Wx::StaticText->new($leftpane, -1, "Data source: "), 0, wxALL, 5);
  $this->{datasource} = Wx::TextCtrl->new($leftpane, -1, q{}, wxDefaultPosition, wxDefaultSize, wxTE_READONLY);
  $filebox -> Add($this->{datasource}, 1, wxGROW|wxLEFT|wxRIGHT|wxTOP, 5);
  ##$this->{datasource} -> SetInsertionPointEnd;

  ## -------- single data set plot buttons
  my $buttonbox  = Wx::StaticBox->new($leftpane, -1, 'Plot this data set as ', wxDefaultPosition, [350,-1]);
  my $buttonboxsizer = Wx::StaticBoxSizer->new( $buttonbox, wxHORIZONTAL );
  $left -> Add($buttonboxsizer, 0, wxGROW|wxALL, 5);
  $this->{plot_rmr}  = Wx::Button->new($leftpane, -1, "Rmr",  wxDefaultPosition, [80,-1]);
  $this->{plot_k123} = Wx::Button->new($leftpane, -1, "k123", wxDefaultPosition, [80,-1]);
  $this->{plot_r123} = Wx::Button->new($leftpane, -1, "R123", wxDefaultPosition, [80,-1]);
  $this->{plot_kq}   = Wx::Button->new($leftpane, -1, "kq",   wxDefaultPosition, [80,-1]);
  foreach my $b (qw(plot_k123 plot_r123 plot_rmr plot_kq)) {
    $buttonboxsizer -> Add($this->{$b}, 1, wxGROW|wxALL, 2);
    $this->{$b} -> SetForegroundColour(Wx::Colour->new("#000000"));
    $this->{$b} -> SetBackgroundColour(Wx::Colour->new($Demeter::UI::Artemis::demeter->co->default("happiness", "average_color")));
    $this->{$b} -> SetFont(Wx::Font->new( 10, wxDEFAULT, wxNORMAL, wxNORMAL, 0, "" ) );
  };
  EVT_BUTTON($this, $this->{plot_rmr},  sub{$this->fetch_parameters;
					    $this->{data}->po->start_plot;
					    $this->{data}->plot('rmr');
					    $parent->{statusbar}->SetStatusText("Plotted \"" . $this->{data}->name . "\" as the magnitude and real part of chi(R).");
					  });
  EVT_BUTTON($this, $this->{plot_k123}, sub{$this->fetch_parameters;
					    $this->{data}->po->start_plot;
					    $this->{data}->plot('k123');
					    $parent->{statusbar}->SetStatusText("Plotted \"" . $this->{data}->name . "\" in k with three k-weights.");
					  });
  EVT_BUTTON($this, $this->{plot_r123}, sub{$this->fetch_parameters;
					    $this->{data}->po->start_plot;
					    $this->{data}->plot('r123');
					    $parent->{statusbar}->SetStatusText("Plotted \"" . $this->{data}->name . "\" in R with three k-weights.");
					  });
  EVT_BUTTON($this, $this->{plot_kq},   sub{$this->fetch_parameters;
					    $this->{data}->po->start_plot;
					    $this->{data}->plot('kqfit');
					    #$this->{data}->plot_window('k') if $this->{data}->po->plot_win;
					    $parent->{statusbar}->SetStatusText("Plotted \"" . $this->{data}->name . "\" in k- and q-space.");
					  });

  ## -------- title lines
  my $titlesbox      = Wx::StaticBox->new($leftpane, -1, 'Title lines ', wxDefaultPosition, wxDefaultSize);
  my $titlesboxsizer = Wx::StaticBoxSizer->new( $titlesbox, wxHORIZONTAL );
  $this->{titles}      = Wx::TextCtrl->new($leftpane, -1, q{}, wxDefaultPosition, [350,-1],
					   wxVSCROLL|wxHSCROLL|wxTE_MULTILINE|wxTE_READONLY|wxNO_BORDER);
  $titlesboxsizer -> Add($this->{titles}, 0, wxALL|wxALIGN_CENTER_HORIZONTAL, 0);
  $left           -> Add($titlesboxsizer, 0, wxALL|wxALIGN_CENTER_HORIZONTAL, 5);


  ## --------- toggles
  my $togglebox  = Wx::BoxSizer->new( wxHORIZONTAL );
  $left    -> Add($togglebox, 0, wxALIGN_CENTER_HORIZONTAL|wxALL, 0);
  $this->{include}    = Wx::CheckBox->new($leftpane, -1, "Include in fit", wxDefaultPosition, wxDefaultSize);
  $this->{plot_after} = Wx::CheckBox->new($leftpane, -1, "Plot after fit", wxDefaultPosition, wxDefaultSize);
  $this->{fit_bkg}    = Wx::CheckBox->new($leftpane, -1, "Fit background", wxDefaultPosition, wxDefaultSize);
  $togglebox -> Add($this->{include},    1, wxALL, 5);
  $togglebox -> Add($this->{plot_after}, 1, wxALL, 5);
  $togglebox -> Add($this->{fit_bkg},    1, wxALL, 5);
  $this->{include}    -> SetValue(1);
  $this->{plot_after} -> SetValue(1);

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

  $this->{kmin} -> SetValidator( Wx::Perl::TextValidator->new( qr([0-9.]) ) );
  $this->{kmax} -> SetValidator( Wx::Perl::TextValidator->new( qr([0-9.]) ) );
  $this->{dk}   -> SetValidator( Wx::Perl::TextValidator->new( qr([0-9.]) ) );
  $this->{rmin} -> SetValidator( Wx::Perl::TextValidator->new( qr([0-9.]) ) );
  $this->{rmax} -> SetValidator( Wx::Perl::TextValidator->new( qr([0-9.]) ) );
  $this->{dr}   -> SetValidator( Wx::Perl::TextValidator->new( qr([0-9.]) ) );

  $ftboxsizer -> Add($gbs, 0, wxALL, 5);

  my $windowsbox  = Wx::BoxSizer->new( wxHORIZONTAL );
  $ftboxsizer -> Add($windowsbox, 0, wxALIGN_LEFT|wxALL, 0);

  $label     = Wx::StaticText->new($leftpane, -1, "FT window");
  $this->{kwindow} = Wx::Choice  ->new($leftpane, -1, , wxDefaultPosition, wxDefaultSize, $windows);
  $windowsbox -> Add($label, 0, wxALL, 5);
  $windowsbox -> Add($this->{kwindow}, 0, wxALL, 2);
  $this->{kwindow}->SetSelection(firstidx {$_ eq $demeter->co->default("fft", "kwindow")} @$windows);

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
  $kwboxsizer -> Add($this->{k1}, 1, wxALL, 5);
  $kwboxsizer -> Add($this->{k2}, 1, wxALL, 5);
  $kwboxsizer -> Add($this->{k3}, 1, wxALL, 5);
  $kwboxsizer -> Add($this->{karb}, 0, wxALL, 5);
  $kwboxsizer -> Add($this->{karb_value}, 0, wxALL, 5);
  $this->{k1}   -> SetValue($demeter->co->default('fit', 'k1'));
  $this->{k2}   -> SetValue($demeter->co->default('fit', 'k2'));
  $this->{k3}   -> SetValue($demeter->co->default('fit', 'k3'));
  $this->{karb} -> SetValue($demeter->co->default('fit', 'karb'));
  $this->{karb_value} -> SetValidator( Wx::Perl::TextValidator->new( qr([0-9.]) ) );

  ## -------- epsilon and phase correction
  my $extrabox  = Wx::BoxSizer->new( wxHORIZONTAL );
  $left        -> Add($extrabox, 0, wxALL|wxGROW|wxALIGN_CENTER_HORIZONTAL, 0);

  $extrabox -> Add(Wx::StaticText->new($leftpane, -1, "ε(k)"), 0, wxALL, 5);
  $this->{epsilon} = Wx::TextCtrl->new($leftpane, -1, 0, wxDefaultPosition, [50,-1]);
  $extrabox  -> Add($this->{epsilon}, 0, wxALL, 2);
  $extrabox  -> Add(Wx::StaticText->new($leftpane, -1, q{}), 1, wxALL, 5);
  $this->{pcplot}  = Wx::CheckBox->new($leftpane, -1, "Plot with phase correction", wxDefaultPosition, wxDefaultSize);
  $extrabox  -> Add($this->{pcplot}, 0, wxALL, 5);

  $this->{epsilon} -> SetValidator( Wx::Perl::TextValidator->new( qr([0-9.]) ) );

  $leftpane -> SetSizer($left);


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

  $this->{pathlist} = Wx::Listbook->new( $rightpane, -1, wxDefaultPosition, wxDefaultSize, wxBK_LEFT );
  $right -> Add($this->{pathlist}, 1, wxGROW|wxALL, 5);
  $this->{pathlist}->AssignImageList( $imagelist );
  #$this->{pathlist}->SetPageSize(Wx::Size->new(300,400));
  #$this->{pathlist}->SetPadding(Wx::Size->new(2,2));
  #$this->{pathlist}->SetIndent(0);

  my $page = Wx::Panel->new($this->{pathlist}, -1, wxDefaultPosition, [-1,-1]);
  my $hh = Wx::BoxSizer->new( wxHORIZONTAL );
  $page -> SetSizer($hh);

  $hh -> Add(Wx::StaticText -> new($page, -1, "Drag paths from the Feff interpretation\nlist and drop them in this space\nto add paths to this data set.", wxDefaultPosition, [390,-1]),
	     0, wxALL, 5);
  $this->{pathlist}->AddPage($page, "Path list", 1, 0);


  $this->{pathlist}->SetDropTarget( Demeter::UI::Artemis::Data::DropTarget->new( $this, $this->{pathlist} ) );

  $rightpane -> SetSizerAndFit($right);


  #$splitter -> SplitVertically($leftpane, $rightpane, -500);
  #$splitter -> SetSashSize(10);

  $this -> SetSizer( $hbox );
  return $this;
};

sub populate {
  my ($self, $data) = @_;
  $self->{data} = $data;
  $self->{name}->SetValue($data->name);
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
  $this->{data}->name($this->{name}->GetValue);

  my $titles = $this->{titles}->GetValue;
  my @list   = split(/\n/, $titles);
  $this->{data}->titles(\@list);

  $this->{data}->fft_kmin      ($this->{kmin}      ->GetValue		);
  $this->{data}->fft_kmax      ($this->{kmax}      ->GetValue		);
  $this->{data}->fft_dk        ($this->{dk}        ->GetValue		);
  $this->{data}->bft_rmin      ($this->{rmin}      ->GetValue		);
  $this->{data}->bft_rmax      ($this->{rmax}      ->GetValue		);
  $this->{data}->bft_dr        ($this->{dr}        ->GetValue		);
  $this->{data}->fft_kwindow   ($this->{kwindow}   ->GetStringSelection	);
  $this->{data}->bft_rwindow   ($this->{kwindow}   ->GetStringSelection	);
  $this->{data}->fit_k1        ($this->{k1}        ->GetValue		);
  $this->{data}->fit_k2        ($this->{k2}        ->GetValue		);
  $this->{data}->fit_k3        ($this->{k3}        ->GetValue		);
  $this->{data}->fit_karb      ($this->{karb}      ->GetValue		);
  $this->{data}->fit_karb_value($this->{karb_value}->GetValue		);
  $this->{data}->fit_epsilon   ($this->{epsilon}   ->GetValue		);

  $this->{data}->fit_include       ($this->{include}    ->GetValue      );
  $this->{data}->fit_plot_after_fit($this->{plot_after} ->GetValue      );
  $this->{data}->fit_do_bkg        ($this->{fit_bkg}    ->GetValue      );
  $this->{data}->fit_do_pcpath     ($this->{pcplot}     ->GetValue      );


  ## toggles, kweights, epsilon, pcpath
};


sub OnMenuClick {
  my ($datapage, $event)  = @_;
  my $id = $event->GetId;
 SWITCH: {
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
  };
};

## how = 0 : each path this feff
## how = 1 : each path this data
## how = 2 : each path each data   (not yet)
## how = 3 : selected paths        (not yet)
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
    $which = "every path in every data set";
  } else {
    $which = "the selected paths";
  };
  $self->{statusbar}->SetStatusText("Set $param to \"$me\" for $which." );
};


package Demeter::UI::Artemis::Data::DropTarget;

use Wx qw( :everything);
use base qw(Wx::DropTarget);
use Demeter::UI::Artemis::DND::PathDrag;
use Demeter::UI::Artemis::Path;

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
  $book->DeletePage(0) if $book->GetPage(0) =~ m{Panel};
  my $spref = $this->{DATA}->{Data};
  my @sparray = map { $demeter->mo->fetch("ScatteringPath", $_) } @$spref;
  foreach my $sp ( @sparray ) {
    my $thispath = Demeter::Path->new(
				      parent => $sp->feff,
				      data   => $this->{PARENT}->{data},
				      sp     => $sp,
				      degen  => $sp->n,
				     );
    my $label = $thispath->name;

    my $page = Demeter::UI::Artemis::Path->new($book, $thispath, $this->{PARENT});

    $book->AddPage($page, $label, 1, 0);
  };

  return $def;
};


1;
