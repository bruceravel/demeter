package Demeter::UI::Atoms::SS;

use strict;
use warnings;

use Wx qw( :everything );
use Wx::DND;
use base 'Wx::Panel';

use Wx::Event qw(EVT_CHOICE EVT_KEY_DOWN EVT_MENU EVT_TOOL_ENTER EVT_BUTTON
		 EVT_ENTER_WINDOW EVT_LEAVE_WINDOW EVT_RADIOBOX
		 EVT_LEFT_DOWN EVT_LIST_BEGIN_DRAG EVT_TEXT_ENTER);
use Wx::Perl::TextValidator;

use List::MoreUtils qw(uniq);
use YAML::Tiny;

my @PosSize = (wxDefaultPosition, [40,-1]);

sub new {
  my ($class, $page, $parent) = @_;
  my $self = $class->SUPER::new($page, -1, wxDefaultPosition, wxDefaultSize, wxMAXIMIZE_BOX );
  $self->{parent}    = $parent;
  $self->{statusbar} = $parent->{statusbar};
  my $vbox = Wx::BoxSizer->new( wxVERTICAL );


  my $cb = Wx::Choicebook->new( $self, -1, wxDefaultPosition, wxDefaultSize, wxBK_TOP );
  $self->{book} = $cb;
  #my $size = Wx::SystemSettings::GetFont(wxSYS_DEFAULT_GUI_FONT)->GetPointSize + 2;
  #($cb->GetChildren)[0]->SetFont( Wx::Font->new($size, wxDEFAULT, wxNORMAL, wxNORMAL, 0, "" ) );
  $vbox->Add($cb, 1, wxALL, 5);

  $self->{histoyaml} = {};

  $self->{ss} = $self->_ss($parent);
  $cb  -> AddPage($self->{ss}, "Make a Single Scattering path of arbitrary length", 1);

  $self->{histo_ss} = $self->_histo($parent);
  $cb  -> AddPage($self->{histo_ss}, "Make histograms from a molecular dynamics history", 0);

  $self -> SetSizerAndFit( $vbox );
  return $self;
};


sub _ss {
  my ($self, $parent) = @_;
  my $page = Wx::Panel->new($self->{book}, -1, wxDefaultPosition, wxDefaultSize);
  my $vbox = Wx::BoxSizer->new( wxVERTICAL );
  $page->SetSizerAndFit($vbox);


  my $hbox = Wx::BoxSizer->new( wxHORIZONTAL );
  $hbox -> Add( Wx::StaticText->new($page, -1, "Name: "), 0, wxALL, 7);
  $self->{ss_name} = Wx::TextCtrl->new($page, -1, q{}, wxDefaultPosition, wxDefaultSize, wxTE_PROCESS_ENTER);
  $hbox -> Add( $self->{ss_name}, 1, wxGROW|wxALL, 5);
  $vbox -> Add( $hbox, 0, wxGROW|wxLEFT|wxRIGHT, 20 );

  $hbox = Wx::BoxSizer->new( wxHORIZONTAL );
  $hbox -> Add( Wx::StaticText->new($page, -1, "Distance: "), 0, wxALL, 7);
  $self->{ss_reff} = Wx::TextCtrl->new($page, -1, q{3.0}, wxDefaultPosition, wxDefaultSize, wxTE_PROCESS_ENTER);
  $hbox -> Add( $self->{ss_reff}, 0, wxALL, 5);
  $vbox -> Add( $hbox, 0, wxGROW|wxLEFT|wxRIGHT, 20 );

  $self->{ss_ipot} = Wx::RadioBox->new($page, -1, ' ipot of scatterer ', wxDefaultPosition, wxDefaultSize,
				       [q{     },q{     },q{     },q{     },q{     },q{     },q{     }], 7, wxRA_SPECIFY_COLS);
  $self->{ss_ipot}->Enable($_,0) foreach (0..6);
  EVT_RADIOBOX($self, $self->{ss_ipot}, sub{set_name(@_,'spath')});

  $vbox -> Add( $self->{ss_ipot}, 0, wxLEFT|wxRIGHT, 25 );

  $hbox = Wx::BoxSizer->new( wxHORIZONTAL );
  $vbox -> Add( $hbox, 0, wxGROW|wxALL, 20 );
  $self->{ss_drag} = Demeter::UI::Atoms::SS::SSDragSource->new($page, -1, wxDefaultPosition, wxDefaultSize, $parent);
  $hbox  -> Add( $self->{ss_drag}, 0, wxALL, 20);
  $self->{ss_drag}->SetCursor(Wx::Cursor->new(wxCURSOR_HAND));
  $self->{ss_drag}->SetFont( Wx::Font->new( 10, wxDEFAULT, wxNORMAL, wxNORMAL, 1, "" ) );
  $self->{ss_drag}->Enable(0);




#  $self->{toolbar} = Wx::ToolBar->new($self, -1, wxDefaultPosition, wxDefaultSize, wxTB_HORIZONTAL|wxTB_3DBUTTONS|wxTB_TEXT);
#  EVT_MENU( $self->{toolbar}, -1, sub{my ($toolbar, $event) = @_; OnToolClick($toolbar, $event, $self)} );
#  $self->{toolbar} -> AddTool(2, "Plot SS path",  $self->icon("plot"), wxNullBitmap, wxITEM_NORMAL, q{}, $Demeter::UI::Atoms::Paths::hints{plot});
#  $self->{toolbar} -> AddSeparator;
#  $self->{toolbar} -> AddRadioTool(4, 'chi(k)',     $self->icon("chik"),    wxNullBitmap, q{}, $Demeter::UI::Atoms::Paths::hints{chik});
#  $self->{toolbar} -> AddRadioTool(5, '|chi(R)|',   $self->icon("chirmag"), wxNullBitmap, q{}, $Demeter::UI::Atoms::Paths::hints{chir_mag});
#  $self->{toolbar} -> AddRadioTool(6, 'Re[chi(R)]', $self->icon("chirre"),  wxNullBitmap, q{}, $Demeter::UI::Atoms::Paths::hints{chir_re});
#  $self->{toolbar} -> AddRadioTool(7, 'Im[chi(R)]', $self->icon("chirim"),  wxNullBitmap, q{}, $Demeter::UI::Atoms::Paths::hints{chir_im});
#  $self->{toolbar} -> ToggleTool(5, 1);

#  EVT_TOOL_ENTER( $self, $self->{toolbar}, sub{my ($toolbar, $event) = @_; &OnToolEnter($toolbar, $event, 'toolbar')} );
#  $self->{toolbar} -> Realize;
#  $vbox -> Add($self->{toolbar}, 0, wxALL, 20);
  return $page;
};


sub _histo {
  my ($self, $parent) = @_;
  my $page = Wx::Panel->new($self->{book}, -1, wxDefaultPosition, wxDefaultSize);

  my $vbox = Wx::BoxSizer->new( wxVERTICAL );

  $self->{histo_file} = Wx::FilePickerCtrl->new( $page, -1, "", "Choose a HISTORY File", "HISTORY files|HISTORY|All files|*",
						    wxDefaultPosition, wxDefaultSize,
						    wxFLP_DEFAULT_STYLE|wxFLP_USE_TEXTCTRL|wxFLP_CHANGE_DIR|wxFLP_FILE_MUST_EXIST );
  $vbox -> Add($self->{histo_file}, 0, wxGROW|wxALL, 10);


  my $scrl = Wx::ScrolledWindow->new($page, -1, wxDefaultPosition, wxDefaultSize, wxVSCROLL);
  my $svbox = Wx::BoxSizer->new( wxVERTICAL );
  $scrl -> SetSizer($svbox);
  $scrl -> SetScrollbars(0, 20, 0, 50);


  ################################################################################
  ######## single scattering
  my $ssbox       = Wx::StaticBox->new($scrl, -1, 'Make a single scattering histogram', wxDefaultPosition, wxDefaultSize);
  my $ssboxsizer  = Wx::StaticBoxSizer->new( $ssbox, wxVERTICAL );
  $svbox         -> Add($ssboxsizer, 0, wxALL|wxGROW, 5);

  my $hbox = Wx::BoxSizer->new( wxHORIZONTAL );
  $ssboxsizer -> Add($hbox, 0, wxGROW|wxLEFT|wxRIGHT, 10);
  $self -> {histo_ss_rminlab} = Wx::StaticText -> new($scrl, -1, "Rmin");
  $self -> {histo_ss_rmin}    = Wx::TextCtrl   -> new($scrl, -1, 1.0, @PosSize, wxTE_PROCESS_ENTER);
  $hbox -> Add($self->{histo_ss_rminlab},   0, wxALL|wxALIGN_CENTRE_VERTICAL, 5);
  $hbox -> Add($self->{histo_ss_rmin},      0, wxALL|wxALIGN_CENTRE_VERTICAL, 5);

  $self -> {histo_ss_rmaxlab} = Wx::StaticText -> new($scrl, -1, "Rmax");
  $self -> {histo_ss_rmax}    = Wx::TextCtrl   -> new($scrl, -1, 3.5, @PosSize, wxTE_PROCESS_ENTER);
  $hbox -> Add($self->{histo_ss_rmaxlab},   0, wxALL|wxALIGN_CENTRE_VERTICAL, 5);
  $hbox -> Add($self->{histo_ss_rmax},      0, wxALL|wxALIGN_CENTRE_VERTICAL, 5);

  $self -> {histo_ss_binlab} = Wx::StaticText -> new($scrl, -1, "Bin size");
  $self -> {histo_ss_bin}    = Wx::TextCtrl   -> new($scrl, -1, 0.005, @PosSize, wxTE_PROCESS_ENTER);
  $hbox -> Add($self->{histo_ss_binlab},    0, wxALL|wxALIGN_CENTRE_VERTICAL, 5);
  $hbox -> Add($self->{histo_ss_bin},       0, wxALL|wxALIGN_CENTRE_VERTICAL, 5);

  $self -> {histo_ss_histoplot} = Wx::Button -> new($scrl, -1, "Plot RDF");
  $hbox -> Add($self->{histo_ss_histoplot}, 1, wxALL|wxALIGN_CENTRE_VERTICAL, 5);
  EVT_BUTTON($self, $self->{histo_ss_histoplot}, sub{ histoplot(@_) });


  $self->{histo_ss_ipot} = Wx::RadioBox->new($scrl, -1, ' ipot of scatterer ', wxDefaultPosition, wxDefaultSize,
				       [q{     },q{     },q{     },q{     },q{     },q{     },q{     }], 7, wxRA_SPECIFY_COLS);
  $self->{histo_ss_ipot}->Enable($_,0) foreach (0..6);
  EVT_RADIOBOX($self, $self->{histo_ss_ipot}, sub{set_name(@_,'histo_ss')});

  $ssboxsizer -> Add( $self->{histo_ss_ipot}, 0, wxLEFT|wxRIGHT, 10 );

  $self->{histo_ss_rattle} = Wx::CheckBox->new($scrl, -1, "Also create triple scattering path from this histogram");
  $ssboxsizer -> Add( $self->{histo_ss_rattle}, 0, wxTOP|wxLEFT|wxRIGHT, 10 );

  $hbox = Wx::BoxSizer->new( wxHORIZONTAL );
  $ssboxsizer -> Add( $hbox, 0, wxGROW|wxALL, 10 );
  $self->{histo_ss_drag} = Demeter::UI::Atoms::SS::HistoSSDragSource->new($scrl, -1, wxDefaultPosition, wxDefaultSize, $parent);
  $hbox  -> Add( $self->{histo_ss_drag}, 0, wxALL, 0);
  $self->{histo_ss_drag}->SetCursor(Wx::Cursor->new(wxCURSOR_HAND));
  $self->{histo_ss_drag}->SetFont( Wx::Font->new( 10, wxDEFAULT, wxNORMAL, wxNORMAL, 1, "" ) );
  $self->{histo_ss_drag}->Enable(0);


  ################################################################################
  ######## nearly collinear
  my $nclbox       = Wx::StaticBox->new($scrl, -1, 'Make a nearly collinear three-body histogram', wxDefaultPosition, wxDefaultSize);
  my $nclboxsizer  = Wx::StaticBoxSizer->new( $nclbox, wxVERTICAL );
  $svbox           -> Add($nclboxsizer, 0, wxALL|wxGROW, 5);


  $hbox = Wx::BoxSizer->new( wxHORIZONTAL );
  $nclboxsizer -> Add($hbox, 0, wxGROW|wxLEFT|wxRIGHT, 10);
  $self -> {histo_ncl_rbinlab}    = Wx::StaticText -> new($scrl, -1, "Radial bin size");
  $self -> {histo_ncl_rbin}       = Wx::TextCtrl   -> new($scrl, -1, 1.0, @PosSize, wxTE_PROCESS_ENTER);
  $self -> {histo_ncl_betabinlab} = Wx::StaticText -> new($scrl, -1, "Angular bin size");
  $self -> {histo_ncl_betabin}    = Wx::TextCtrl   -> new($scrl, -1, 1.0, @PosSize, wxTE_PROCESS_ENTER);
  $hbox -> Add($self->{histo_ncl_rbinlab},    0, wxALL|wxALIGN_CENTRE_VERTICAL, 5);
  $hbox -> Add($self->{histo_ncl_rbin},       0, wxALL|wxALIGN_CENTRE_VERTICAL, 5);
  $hbox -> Add($self->{histo_ncl_betabinlab}, 0, wxALL|wxALIGN_CENTRE_VERTICAL, 5);
  $hbox -> Add($self->{histo_ncl_betabin},    0, wxALL|wxALIGN_CENTRE_VERTICAL, 5);

  $self -> {histo_ncl_plot} = Wx::Button -> new($scrl, -1, "Scatter plot");
  $hbox -> Add($self->{histo_ncl_plot},    1, wxALL|wxALIGN_CENTRE_VERTICAL, 5);
  EVT_BUTTON($self, $self->{histo_ncl_plot}, sub{ scatterplot(@_) });

  $hbox = Wx::BoxSizer->new( wxHORIZONTAL );
  $nclboxsizer -> Add($hbox, 0, wxGROW|wxLEFT|wxRIGHT, 10);
  $self->{histo_ncl_ipot1} = Wx::RadioBox->new($scrl, -1, ' ipot of near neighbor scatterer ', wxDefaultPosition, wxDefaultSize,
					     [q{     },q{     },q{     },q{     },q{     },q{     },q{     }], 7, wxRA_SPECIFY_COLS);
  $self->{histo_ncl_ipot1}->Enable($_,0) foreach (0..6);
  EVT_RADIOBOX($self, $self->{histo_ncl_ipot1}, sub{set_name(@_,'histo_ncl1')});
  $hbox -> Add( $self->{histo_ncl_ipot1}, 0, wxALL|wxALIGN_CENTRE_VERTICAL, 5 );

  $self -> {histo_ncl_r1}    = Wx::TextCtrl   -> new($scrl, -1, 1.0, @PosSize, wxTE_PROCESS_ENTER);
  $self -> {histo_ncl_r2}    = Wx::TextCtrl   -> new($scrl, -1, 1.0, @PosSize, wxTE_PROCESS_ENTER);
  $hbox -> Add(Wx::StaticText -> new($scrl, -1, "R1:"), 0, wxALL|wxALIGN_CENTRE_VERTICAL, 5);
  $hbox -> Add($self->{histo_ncl_r1},                   0, wxALL|wxALIGN_CENTRE_VERTICAL, 5);
  $hbox -> Add(Wx::StaticText -> new($scrl, -1, "R2:"), 0, wxALL|wxALIGN_CENTRE_VERTICAL, 5);
  $hbox -> Add($self->{histo_ncl_r2},                   0, wxALL|wxALIGN_CENTRE_VERTICAL, 5);

  $hbox = Wx::BoxSizer->new( wxHORIZONTAL );
  $nclboxsizer -> Add($hbox, 0, wxGROW|wxLEFT|wxRIGHT, 10);
  $self->{histo_ncl_ipot2} = Wx::RadioBox->new($scrl, -1, ' ipot of distant scatterer ', wxDefaultPosition, wxDefaultSize,
					     [q{     },q{     },q{     },q{     },q{     },q{     },q{     }], 7, wxRA_SPECIFY_COLS);
  $self->{histo_ncl_ipot2}->Enable($_,0) foreach (0..6);
  EVT_RADIOBOX($self, $self->{histo_ncl_ipot2}, sub{set_name(@_,'histo_ncl2')});
  $hbox -> Add( $self->{histo_ncl_ipot2}, 0, wxALL|wxALIGN_CENTRE_VERTICAL, 5 );

  $self -> {histo_ncl_r3}    = Wx::TextCtrl   -> new($scrl, -1, 1.0, @PosSize, wxTE_PROCESS_ENTER);
  $self -> {histo_ncl_r4}    = Wx::TextCtrl   -> new($scrl, -1, 1.0, @PosSize, wxTE_PROCESS_ENTER);
  $hbox -> Add(Wx::StaticText -> new($scrl, -1, "R3:"), 0, wxALL|wxALIGN_CENTRE_VERTICAL, 5);
  $hbox -> Add($self->{histo_ncl_r3},                   0, wxALL|wxALIGN_CENTRE|wxALIGN_CENTRE_VERTICAL, 5);
  $hbox -> Add(Wx::StaticText -> new($scrl, -1, "R4:"), 0, wxALL|wxALIGN_CENTRE_VERTICAL, 5);
  $hbox -> Add($self->{histo_ncl_r4},                   0, wxALL|wxALIGN_CENTRE|wxALIGN_CENTRE_VERTICAL, 5);

  $hbox = Wx::BoxSizer->new( wxHORIZONTAL );
  $nclboxsizer -> Add( $hbox, 0, wxGROW|wxALL, 10 );
  $self->{histo_ncl_drag} = Demeter::UI::Atoms::SS::HistoNCLDragSource->new($scrl, -1, wxDefaultPosition, wxDefaultSize, $parent);
  $hbox  -> Add( $self->{histo_ncl_drag}, 0, wxALL, 0);
  $self->{histo_ncl_drag}->SetCursor(Wx::Cursor->new(wxCURSOR_HAND));
  $self->{histo_ncl_drag}->SetFont( Wx::Font->new( 10, wxDEFAULT, wxNORMAL, wxNORMAL, 1, "" ) );
  $self->{histo_ncl_drag}->Enable(0);

  ################################################################################
  ######## through absorber
  my $thrubox       = Wx::StaticBox->new($scrl, -1, 'Make a three-body histogram through the absorber', wxDefaultPosition, wxDefaultSize);
  my $thruboxsizer  = Wx::StaticBoxSizer->new( $thrubox, wxVERTICAL );
  $svbox           -> Add($thruboxsizer, 0, wxALL|wxGROW, 5);

  $hbox = Wx::BoxSizer->new( wxHORIZONTAL );
  $thruboxsizer -> Add($hbox, 0, wxGROW|wxLEFT|wxRIGHT, 10);
  $self -> {histo_thru_rbinlab}    = Wx::StaticText -> new($scrl, -1, "Radial bin size");
  $self -> {histo_thru_rbin}       = Wx::TextCtrl   -> new($scrl, -1, 1.0, @PosSize, wxTE_PROCESS_ENTER);
  $self -> {histo_thru_betabinlab} = Wx::StaticText -> new($scrl, -1, "Angular bin size");
  $self -> {histo_thru_betabin}    = Wx::TextCtrl   -> new($scrl, -1, 1.0, @PosSize, wxTE_PROCESS_ENTER);
  $hbox -> Add($self->{histo_thru_rbinlab},    0, wxALL|wxALIGN_CENTRE_VERTICAL, 5);
  $hbox -> Add($self->{histo_thru_rbin},       0, wxALL|wxALIGN_CENTRE_VERTICAL, 5);
  $hbox -> Add($self->{histo_thru_betabinlab}, 0, wxALL|wxALIGN_CENTRE_VERTICAL, 5);
  $hbox -> Add($self->{histo_thru_betabin},    0, wxALL|wxALIGN_CENTRE_VERTICAL, 5);

  $self -> {histo_thru_plot} = Wx::Button -> new($scrl, -1, "Scatter plot");
  $hbox -> Add($self->{histo_thru_plot},    1, wxALL|wxALIGN_CENTRE_VERTICAL, 5);
  EVT_BUTTON($self, $self->{histo_thru_plot}, sub{ scatterplot(@_) });

  $hbox = Wx::BoxSizer->new( wxHORIZONTAL );
  $thruboxsizer -> Add($hbox, 0, wxGROW|wxLEFT|wxRIGHT, 10);
  $self -> {histo_thru_rmin} = Wx::TextCtrl   -> new($scrl, -1, 1.0, @PosSize, wxTE_PROCESS_ENTER);
  $self -> {histo_thru_rmax} = Wx::TextCtrl   -> new($scrl, -1, 1.0, @PosSize, wxTE_PROCESS_ENTER);
  $hbox -> Add(Wx::StaticText -> new($scrl, -1, "Rmin:"), 0, wxALL|wxALIGN_CENTRE_VERTICAL, 5);
  $hbox -> Add($self->{histo_thru_rmin},                  0, wxALL|wxALIGN_CENTRE_VERTICAL, 5);
  $hbox -> Add(Wx::StaticText -> new($scrl, -1, "Rmax:"), 0, wxALL|wxALIGN_CENTRE_VERTICAL, 5);
  $hbox -> Add($self->{histo_thru_rmax},                  0, wxALL|wxALIGN_CENTRE_VERTICAL, 5);

  $hbox = Wx::BoxSizer->new( wxHORIZONTAL );
  $thruboxsizer -> Add($hbox, 0, wxGROW|wxLEFT|wxRIGHT, 10);
  $self->{histo_thru_ipot1} = Wx::RadioBox->new($scrl, -1, ' ipot of first scatterer in range ', wxDefaultPosition, wxDefaultSize,
					     [q{     },q{     },q{     },q{     },q{     },q{     },q{     }], 7, wxRA_SPECIFY_COLS);
  $self->{histo_thru_ipot1}->Enable($_,0) foreach (0..6);
  EVT_RADIOBOX($self, $self->{histo_thru_ipot1}, sub{set_name(@_,'histo_thru1')});
  $hbox -> Add( $self->{histo_thru_ipot1}, 0, wxALL|wxALIGN_CENTRE_VERTICAL, 5 );

  $hbox = Wx::BoxSizer->new( wxHORIZONTAL );
  $thruboxsizer -> Add($hbox, 0, wxGROW|wxLEFT|wxRIGHT, 10);
  $self->{histo_thru_ipot2} = Wx::RadioBox->new($scrl, -1, ' ipot of second scatterer in range ', wxDefaultPosition, wxDefaultSize,
					     [q{     },q{     },q{     },q{     },q{     },q{     },q{     }], 7, wxRA_SPECIFY_COLS);
  $self->{histo_thru_ipot2}->Enable($_,0) foreach (0..6);
  EVT_RADIOBOX($self, $self->{histo_thru_ipot2}, sub{set_name(@_,'histo_thru2')});
  $hbox -> Add( $self->{histo_thru_ipot2}, 0, wxALL|wxALIGN_CENTRE_VERTICAL, 5 );

  $hbox = Wx::BoxSizer->new( wxHORIZONTAL );
  $thruboxsizer -> Add( $hbox, 0, wxGROW|wxALL, 10 );
  $self->{histo_thru_drag} = Demeter::UI::Atoms::SS::HistoThruDragSource->new($scrl, -1, wxDefaultPosition, wxDefaultSize, $parent);
  $hbox  -> Add( $self->{histo_thru_drag}, 0, wxALL, 0);
  $self->{histo_thru_drag}->SetCursor(Wx::Cursor->new(wxCURSOR_HAND));
  $self->{histo_thru_drag}->SetFont( Wx::Font->new( 10, wxDEFAULT, wxNORMAL, wxNORMAL, 1, "" ) );
  $self->{histo_thru_drag}->Enable(0);


  ################################################################################
  ######## set validators and draw values from persistance file

  $self->{$_} -> SetValidator( Wx::Perl::TextValidator->new( qr([0-9.]) ) )
    foreach (qw(histo_ss_rmin histo_ss_rmax histo_ss_bin
		histo_ncl_r1 histo_ncl_r2 histo_ncl_r3 histo_ncl_r4
		histo_ncl_rbin histo_ncl_betabin
		histo_thru_rmin histo_thru_rmax histo_thru_rbin histo_thru_betabin
	      ));

  my $persist = File::Spec->catfile(Demeter->dot_folder, 'demeter.histograms');
  if (-e $persist) {
    my $yaml = YAML::Tiny::LoadFile($persist);
    $self->{histoyaml} = $yaml;
    $self->{histo_file}    -> SetPath ($yaml->{file});
    $self->{histo_ss_rmin} -> SetValue($yaml->{rmin}  || 1.5);
    $self->{histo_ss_rmax} -> SetValue($yaml->{rmax}  || 3.5);
    $self->{histo_ss_bin}  -> SetValue($yaml->{bin}   || 0.5);
    my $i1 = (exists $yaml->{ipot1}) ? $yaml->{ipot1}-1 : 0;
    $self->{histo_ss_ipot} -> SetSelection($i1);

    $self->{histo_ncl_r1}     -> SetValue($yaml->{r1} || 1);
    $self->{histo_ncl_r2}     -> SetValue($yaml->{r2} || 3);
    $self->{histo_ncl_r3}     -> SetValue($yaml->{r3} || 4);
    $self->{histo_ncl_r4}     -> SetValue($yaml->{r4} || 5);
    $self->{histo_ncl_rbin}   -> SetValue($yaml->{rbin} || 0.02);
    $self->{histo_ncl_betabin}-> SetValue($yaml->{betabin} || 0.5);
    my $i2 = (exists $yaml->{ipot2}) ? $yaml->{ipot2}-1 : 0;
    $self->{histo_ncl_ipot1}  -> SetSelection($i1);
    $self->{histo_ncl_ipot2}  -> SetSelection($i2);

    $self->{histo_thru_rmin}   -> SetValue($yaml->{rmin}    || 1.5);
    $self->{histo_thru_rmax}   -> SetValue($yaml->{rmax}    || 3.5);
    $self->{histo_thru_rbin}   -> SetValue($yaml->{rbin}    || 0.02);
    $self->{histo_thru_betabin}-> SetValue($yaml->{betabin} || 0.5);
    $self->{histo_thru_ipot1}  -> SetSelection($i1);
    $self->{histo_thru_ipot2}  -> SetSelection($i2);

  };

  $vbox -> Add($scrl, 1, wxGROW|wxALL, 2);
  $page -> SetSizerAndFit($vbox);
  return $page;
};

sub histoplot {
  my ($this, $event) = @_;
  my $file = $this->{histo_file}->GetTextCtrl->GetValue;
  my $rmin = $this->{histo_ss_rmin}->GetValue;
  my $rmax = $this->{histo_ss_rmax}->GetValue;
  my $bin  = $this->{histo_ss_bin}->GetValue;
  $this->{histoyaml}->{file} = $file;
  $this->{histoyaml}->{rmin} = $rmin;
  $this->{histoyaml}->{rmax} = $rmax;
  $this->{histoyaml}->{bin}  = $bin;

  if ((not $file) or (not -e $file) or (not -r $file)) {
    $this->{parent}->status("You did not specify a file or your file cannot be read.");
    return;
  };

  my $dlp = Demeter::Feff::Distributions->new(rmin=>$rmin, rmax=>$rmax, bin=>$bin, type=>'ss',
					      feff=>$this->{parent}->{Feff}->{feffobject});
  my $persist = File::Spec->catfile($dlp->dot_folder, 'demeter.histograms');
  YAML::Tiny::DumpFile($persist, $this->{histoyaml});


  $this->{DISTRIBUTION} = $dlp;
  $dlp->sentinal(sub{$this->dlpoly_sentinal});

  my $busy = Wx::BusyCursor->new();
  my $start = DateTime->now( time_zone => 'floating' );
  $dlp->backend('DL_POLY');
  $dlp->file($file);
  $dlp->rebin;
  my $finish = DateTime->now( time_zone => 'floating' );
  my $dur = $finish->subtract_datetime($start);
  my $finishtext = sprintf("Plotting histogram from %d timesteps (%d minutes, %d seconds)", $dlp->nsteps, $dur->minutes, $dur->seconds);
  $this->{statusbar}->SetStatusText($finishtext);
  $dlp->plot;
  undef $busy;
};

sub scatterplot {
  my ($this, $event) = @_;
  my $file = $this->{histo_file}->GetTextCtrl->GetValue;
  my $r1   = $this->{histo_ncl_r1}->GetValue;
  my $r2   = $this->{histo_ncl_r2}->GetValue;
  my $r3   = $this->{histo_ncl_r3}->GetValue;
  my $r4   = $this->{histo_ncl_r4}->GetValue;
  my $rbin = $this->{histo_ncl_rbin}->GetValue;
  my $betabin = $this->{histo_ncl_betabin}->GetValue;
  $this->{histoyaml}->{file} = $file;
  $this->{histoyaml}->{r1}   = $r1;
  $this->{histoyaml}->{r2}   = $r2;
  $this->{histoyaml}->{r3}   = $r3;
  $this->{histoyaml}->{r4}   = $r4;
  $this->{histoyaml}->{rbin} = $rbin;
  $this->{histoyaml}->{betabin} = $betabin;

  if ((not $file) or (not -e $file) or (not -r $file)) {
    $this->{parent}->status("You did not specify a file or your file cannot be read.");
    return;
  };

  my $histo = Demeter::Feff::Distributions->new(type=>'ncl');
  $histo->set(r1=>$r1, r2=>$r2, r3=>$r3, r4=>$r4, rbin=>$rbin, betabin=>$betabin,
	      feff=>$this->{parent}->{Feff}->{feffobject});

  my $persist = File::Spec->catfile($histo->dot_folder, 'demeter.histograms');
  YAML::Tiny::DumpFile($persist, $this->{histoyaml});

  $this->{DISTRIBUTION} = $histo;
  $histo->sentinal(sub{$this->dlpoly_sentinal});

  my $busy = Wx::BusyCursor->new();
  my $start = DateTime->now( time_zone => 'floating' );
  $histo->backend('DL_POLY');
  $histo->file($file);
  $histo->rebin;
  my $finish = DateTime->now( time_zone => 'floating' );
  my $dur = $finish->subtract_datetime($start);
  my $finishtext = sprintf("Plotting histogram from %d timesteps (%d minutes, %d seconds)", $histo->nsteps, $dur->minutes, $dur->seconds);
  $this->{statusbar}->SetStatusText($finishtext);
  $histo->plot;
  undef $busy;
};

sub dlpoly_sentinal {
  my ($this) = @_;
  if (not $this->{DISTRIBUTION}->timestep_count % 10) {
    my $text = $this->{DISTRIBUTION}->timestep_count . " of " . $this->{DISTRIBUTION}->{nsteps} . " timesteps";
    #print $text, $/;
    $this->{statusbar}->SetStatusText($text);
    #$this->{parent}->status($text, 'wait|nobuffer') if not $this->{DISTRIBUTION}->timestep_count % 10;
    $::app->Yield();
  };
};


sub icon {
  my ($self, $which) = @_;
  my $icon = File::Spec->catfile($Demeter::UI::Atoms::atoms_base, 'Atoms', 'icons', "$which.png");
  return wxNullBitmap if (not -e $icon);
  return Wx::Bitmap->new($icon, wxBITMAP_TYPE_ANY)
};

sub set_name {
  my ($self, $event, $which) = @_;

  if ($which eq 'spath') {
    ## need to make a regular expression out of all elements in the potentials list ...
    my @pots = @{ $self->{parent}->{Feff}->{feffobject}->potentials };
    shift @pots;
    my @all_elems = uniq( map { $_ -> [2] } @pots );
    my $re = join("|", @all_elems);

    ## ... so I can reset the name if it has been left to its default.
    if ($self->{ss_name}->GetValue =~ m{\A\s*$re\s+SS\z}) {
      my $label = $self->{ss_ipot}->GetStringSelection;
      my $elem  = (split(/: /, $label))[1];
      $self->{ss_name}->SetValue($elem.' SS');
    };
  };
};

sub OnToolEnter {
  my ($self, $event, $which) = @_;
  if ( $event->GetSelection > -1 ) {
    $self->{statusbar}->SetStatusText($self->{$which}->GetToolLongHelp($event->GetSelection));
  } else {
    $self->{statusbar}->SetStatusText(q{});
  };
};

sub OnToolClick {
  my ($toolbar, $event, $self) = @_;
  ##                 Vv------order of toolbar on the screen-----vV
  my @callbacks = qw(plot noop set_plot set_plot set_plot set_plot);
  my $closure = $callbacks[$toolbar->GetToolPos($event->GetId)];
  $self->$closure($event->GetId);
};

sub noop {
  return 1;
};

sub set_plot {
  my ($self, $id) = @_;
  ## set plotting space
  my $space = ($id == 5) ? 'k' : 'r';
  $self->{parent}->{Feff}->{feffobject}->po->space($space);
  # set part of R space plot
  my %pl = (5 => q{}, 6 => 'm', 7 => 'r', 8 => 'i');
  $self->{parent}->{Feff}->{feffobject}->po->r_pl($pl{$id}) if $pl{$id};
  # sensible status bar message
  my %as = (5 => 'chi(k)', 6 => 'the magnitude of chi(R)', 7 => 'the real part of chi(R)', 8 => 'the imaginary part of chi(R)');
  $self->{statusbar}->SetStatusText("Plotting as $as{$id}");
  return $self;
};

sub plot {
  my ($self) = @_;
  my $save = $Demeter::UI::Atoms::demeter->po->title;

  ## make SSPath

  ## make plot

  ## destroy SSPath (since it will be created when dnd-ed

  $Demeter::UI::Atoms::demeter->po->title($save);
};



package Demeter::UI::Atoms::SS::SSDragSource;

use Demeter;

use Wx qw( :everything );
use base qw(Wx::Window);
use Wx::Event qw(EVT_LEFT_DOWN EVT_PAINT);

sub new {
  my $class = shift;
  my $this = $class->SUPER::new( @_[0..2], [300,30] );
  my $parent = $_[4];

  EVT_PAINT( $this, \&OnPaint );
  EVT_LEFT_DOWN( $this, sub{OnDrag(@_, $parent)} );

  return $this;
};

sub OnPaint {
  my( $this, $event ) = @_;
  my $dc = Wx::PaintDC->new( $this );

  $dc->DrawText( "Drag single scattering path from here ", 2, 2 );
};

sub OnDrag {
  my( $this, $event, $parent ) = @_;

  my $dragdata = ['SSPath',  	                         # id
		  $parent->{Feff}->{feffobject}->group,  # feff object group
		  $parent->{SS}->{ss_name}->GetValue,       # name
		  $parent->{SS}->{ss_reff}->GetValue,       # reff
		  $parent->{SS}->{ss_ipot}->GetSelection+1, # ipot
		 ];
  my $data = Demeter::UI::Artemis::DND::PathDrag->new($dragdata);
  my $source = Wx::DropSource->new( $this );
  $source->SetData( $data );
  $source->DoDragDrop(1);
};


package Demeter::UI::Atoms::SS::HistoSSDragSource;

use Demeter;

use Wx qw( :everything );
use base qw(Wx::Window);
use Wx::Event qw(EVT_LEFT_DOWN EVT_PAINT);

use Scalar::Util qw(looks_like_number);

sub new {
  my $class = shift;
  my $this = $class->SUPER::new( @_[0..2], [300,30] );
  my $parent = $_[4];

  EVT_PAINT( $this, \&OnPaint );
  EVT_LEFT_DOWN( $this, sub{OnDrag(@_, $parent)} );

  return $this;
};

sub OnPaint {
  my( $this, $event ) = @_;
  my $dc = Wx::PaintDC->new( $this );

  $dc->DrawText( "Drag SS path from here ", 2, 2 );
};

sub OnDrag {
  my( $this, $event, $parent ) = @_;

  my $file = $parent->{SS}->{histo_file}->GetTextCtrl->GetValue;
  if (not -e $file) {
    $parent->{statusbar}->SetStatusText("Histogram canceled: The file $file does not exist");
    return;
  };
  if (not -r $file) {
    $parent->{statusbar}->SetStatusText("Histogram canceled: The file $file cannot be read");
    return;
  };

  foreach my $s (qw(rmin rmax bin)) {
    if (not looks_like_number($parent->{SS}->{"histo_ss_".$s}->GetValue)) {
      $parent->{statusbar}->SetStatusText("Histogram canceled: $s is not a number.");
      return;
    };
  };

  if ($parent->{SS}->{histo_ss_rmin}->GetValue >= $parent->{SS}->{histo_ss_rmax}->GetValue) {
    $parent->{statusbar}->SetStatusText("Histogram canceled: Rmin >= Rmax for the single scattering histogram.");
    return;
  };
  if ($parent->{SS}->{histo_ss_bin}->GetValue <= 0) {
    $parent->{statusbar}->SetStatusText("Histogram canceled: R bin size must be positive.");
    return;
  };

  my $dragdata = ['HistogramSS',					  # 0 id
		  'DL_POLY',				                  # 1 backend
		  $parent->{Feff}->{feffobject}->group,			  # 2 feff object group
		  $parent->{SS}->{histo_file}->GetTextCtrl->GetValue,     # 3 HISTORY file
		  $parent->{SS}->{histo_ss_rmin}->GetValue,		  # 4 rmin
		  $parent->{SS}->{histo_ss_rmax}->GetValue,		  # 5 rmax
		  $parent->{SS}->{histo_ss_bin} ->GetValue,		  # 6 bin size
		  $parent->{SS}->{histo_ss_ipot}->GetSelection+1,	  # 7 ipot
		  $parent->{SS}->{histo_ss_rattle}->GetValue,		  # 8 do rattle path
		 ];

  ## handle persistence file
  $parent->{SS}->{histoyaml}->{file}  = $dragdata->[3];
  $parent->{SS}->{histoyaml}->{rmin}  = $dragdata->[4];
  $parent->{SS}->{histoyaml}->{rmax}  = $dragdata->[5];
  $parent->{SS}->{histoyaml}->{bin}   = $dragdata->[6];
  $parent->{SS}->{histoyaml}->{ipot1} = $dragdata->[7];
  my $persist = File::Spec->catfile(Demeter->dot_folder, 'demeter.histograms');
  YAML::Tiny::DumpFile($persist, $parent->{SS}->{histoyaml});

  my $data = Demeter::UI::Artemis::DND::PathDrag->new($dragdata);
  my $source = Wx::DropSource->new( $this );
  $source->SetData( $data );
  $source->DoDragDrop(1);
};


package Demeter::UI::Atoms::SS::HistoNCLDragSource;

use Demeter;

use Wx qw( :everything );
use base qw(Wx::Window);
use Wx::Event qw(EVT_LEFT_DOWN EVT_PAINT);

use Scalar::Util qw(looks_like_number);

sub new {
  my $class = shift;
  my $this = $class->SUPER::new( @_[0..2], [300,30] );
  my $parent = $_[4];

  EVT_PAINT( $this, \&OnPaint );
  EVT_LEFT_DOWN( $this, sub{OnDrag(@_, $parent)} );

  return $this;
};

sub OnPaint {
  my( $this, $event ) = @_;
  my $dc = Wx::PaintDC->new( $this );

  $dc->DrawText( "Drag nearly collinear path from here ", 2, 2 );
};

sub OnDrag {
  my( $this, $event, $parent ) = @_;

  my $file = $parent->{SS}->{histo_file}->GetTextCtrl->GetValue;
  if (not -e $file) {
    $parent->{statusbar}->SetStatusText("Histogram canceled: The file $file does not exist");
    return;
  };
  if (not -r $file) {
    $parent->{statusbar}->SetStatusText("Histogram canceled: The file $file cannot be read");
    return;
  };

  foreach my $s (qw(r1 r2 r3 r4 rbin betabin)) {
    if (not looks_like_number($parent->{SS}->{"histo_ncl_".$s}->GetValue)) {
      $parent->{statusbar}->SetStatusText("Histogram canceled: $s is not a number.");
      return;
    };
  };

  if ($parent->{SS}->{histo_ncl_r1}->GetValue >= $parent->{SS}->{histo_ncl_r2}->GetValue) {
    $parent->{statusbar}->SetStatusText("Histogram canceled: R1 >= R2 for the near atom.");
    return;
  };
  if ($parent->{SS}->{histo_ncl_r3}->GetValue >= $parent->{SS}->{histo_ncl_r4}->GetValue) {
    $parent->{statusbar}->SetStatusText("Histogram canceled: R3 >= R4 for the far atom.");
    return;
  };
  if ($parent->{SS}->{histo_ncl_rbin}->GetValue <= 0) {
    $parent->{statusbar}->SetStatusText("Histogram canceled: R bin size must be positive.");
    return;
  };
  if ($parent->{SS}->{histo_ncl_betabin}->GetValue <= 0) {
    $parent->{statusbar}->SetStatusText("Histogram canceled: Beta bin size must be positive.");
    return;
  };

  my $dragdata = ['HistogramNCL',						# 0  id
		  'DL_POLY',							# 1 backend
		  $parent->{Feff}->{feffobject}      -> group,			# 2  feff object group
		  $parent->{SS}->{histo_file}        -> GetTextCtrl->GetValue,	# 3  HISTORY file
		  $parent->{SS}->{histo_ncl_r1}      -> GetValue,		# 4  r ranges
		  $parent->{SS}->{histo_ncl_r2}      -> GetValue,		# 5
		  $parent->{SS}->{histo_ncl_r3}      -> GetValue,		# 6
		  $parent->{SS}->{histo_ncl_r4}      -> GetValue,		# 7
		  $parent->{SS}->{histo_ncl_rbin}    -> GetValue,		# 8  bin size
		  $parent->{SS}->{histo_ncl_betabin} -> GetValue,		# 9  bin size
		  $parent->{SS}->{histo_ncl_ipot1}   -> GetSelection+1,		# 10 ipot
		  $parent->{SS}->{histo_ncl_ipot2}   -> GetSelection+1,		# 11 ipot
		 ];

  ## handle persistence file
  $parent->{SS}->{histoyaml}->{file}    = $dragdata->[3];
  $parent->{SS}->{histoyaml}->{r1}	= $dragdata->[4];
  $parent->{SS}->{histoyaml}->{r2}	= $dragdata->[5];
  $parent->{SS}->{histoyaml}->{r3}	= $dragdata->[6];
  $parent->{SS}->{histoyaml}->{r4}	= $dragdata->[7];
  $parent->{SS}->{histoyaml}->{rbin}    = $dragdata->[8];
  $parent->{SS}->{histoyaml}->{betabin} = $dragdata->[9];
  $parent->{SS}->{histoyaml}->{ipot1}   = $dragdata->[10];
  $parent->{SS}->{histoyaml}->{ipot2}   = $dragdata->[11];
  my $persist = File::Spec->catfile(Demeter->dot_folder, 'demeter.histograms');
  YAML::Tiny::DumpFile($persist, $parent->{SS}->{histoyaml});

  my $data = Demeter::UI::Artemis::DND::PathDrag->new($dragdata);
  my $source = Wx::DropSource->new( $this );
  $source->SetData( $data );
  $source->DoDragDrop(1);
};




package Demeter::UI::Atoms::SS::HistoThruDragSource;

use Demeter;

use Wx qw( :everything );
use base qw(Wx::Window);
use Wx::Event qw(EVT_LEFT_DOWN EVT_PAINT);

use Scalar::Util qw(looks_like_number);

sub new {
  my $class = shift;
  my $this = $class->SUPER::new( @_[0..2], [300,30] );
  my $parent = $_[4];

  EVT_PAINT( $this, \&OnPaint );
  EVT_LEFT_DOWN( $this, sub{OnDrag(@_, $parent)} );

  return $this;
};

sub OnPaint {
  my( $this, $event ) = @_;
  my $dc = Wx::PaintDC->new( $this );

  $dc->DrawText( "Drag nearly collinear path through absorber from here ", 2, 2 );
};

sub OnDrag {
  my( $this, $event, $parent ) = @_;

  my $file = $parent->{SS}->{histo_file}->GetTextCtrl->GetValue;
  if (not -e $file) {
    $parent->{statusbar}->SetStatusText("Histogram canceled: The file $file does not exist");
    return;
  };
  if (not -r $file) {
    $parent->{statusbar}->SetStatusText("Histogram canceled: The file $file cannot be read");
    return;
  };

  foreach my $s (qw(rmin rmax rbin betabin)) {
    if (not looks_like_number($parent->{SS}->{"histo_thru_".$s}->GetValue)) {
      $parent->{statusbar}->SetStatusText("Histogram canceled: $s is not a number.");
      return;
    };
  };

  if ($parent->{SS}->{histo_thru_rmin}->GetValue >= $parent->{SS}->{histo_thru_rmax}->GetValue) {
    $parent->{statusbar}->SetStatusText("Histogram canceled: R1 >= R2 for the near atom.");
    return;
  };
  if ($parent->{SS}->{histo_thru_rbin}->GetValue <= 0) {
    $parent->{statusbar}->SetStatusText("Histogram canceled: R bin size must be positive.");
    return;
  };
  if ($parent->{SS}->{histo_thru_betabin}->GetValue <= 0) {
    $parent->{statusbar}->SetStatusText("Histogram canceled: Beta bin size must be positive.");
    return;
  };

  my $dragdata = ['HistogramThru',						# 0  id
		  'DL_POLY',							# 1  backend
		  $parent->{Feff}->{feffobject}       -> group,			# 2  feff object group
		  $parent->{SS}->{histo_file}         -> GetTextCtrl->GetValue,	# 3  HISTORY file
		  $parent->{SS}->{histo_thru_rmin}    -> GetValue,		# 4  r ranges
		  $parent->{SS}->{histo_thru_rmax}    -> GetValue,		# 5
		  $parent->{SS}->{histo_thru_rbin}    -> GetValue,		# 6  bin size
		  $parent->{SS}->{histo_thru_betabin} -> GetValue,		# 7  bin size
		  $parent->{SS}->{histo_thru_ipot1}   -> GetSelection+1,	# 8  ipot
		  $parent->{SS}->{histo_thru_ipot2}   -> GetSelection+1,	# 9  ipot
		 ];

  ## handle persistence file
  $parent->{SS}->{histoyaml}->{file}    = $dragdata->[3];
  $parent->{SS}->{histoyaml}->{rmin}	= $dragdata->[4];
  $parent->{SS}->{histoyaml}->{rmax}	= $dragdata->[5];
  $parent->{SS}->{histoyaml}->{rbin}    = $dragdata->[6];
  $parent->{SS}->{histoyaml}->{betabin} = $dragdata->[7];
  $parent->{SS}->{histoyaml}->{ipot1}   = $dragdata->[8];
  $parent->{SS}->{histoyaml}->{ipot2}   = $dragdata->[9];
  my $persist = File::Spec->catfile(Demeter->dot_folder, 'demeter.histograms');
  YAML::Tiny::DumpFile($persist, $parent->{SS}->{histoyaml});

  my $data = Demeter::UI::Artemis::DND::PathDrag->new($dragdata);
  my $source = Wx::DropSource->new( $this );
  $source->SetData( $data );
  $source->DoDragDrop(1);
};



1;

=head1 NAME

Demeter::UI::Atoms::SS - Create SSPath objects in Atoms

=head1 VERSION

This documentation refers to Demeter version 0.4.

=head1 DESCRIPTION

This class is used to populate the SS tab in the Wx version of Atoms
as a component of Artemis.

=head1 AUTHOR

Bruce Ravel (bravel AT bnl DOT gov)

L<http://cars9.uchicago.edu/~ravel/software/>

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2011 Bruce Ravel (bravel AT bnl DOT gov). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
