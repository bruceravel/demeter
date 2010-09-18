package Demeter::UI::Athena::Main;

use Wx qw( :everything );
use base 'Wx::Panel';
use Wx::Event qw(EVT_LIST_ITEM_ACTIVATED EVT_LIST_ITEM_SELECTED EVT_BUTTON  EVT_KEY_DOWN);

use Chemistry::Elements qw(get_name);
use File::Basename;
use File::Spec;

use vars qw($label);
$label = "Main window";

sub new {
  my ($class, $parent) = @_;
  my $this = $class->SUPER::new($parent, -1, wxDefaultPosition, wxDefaultSize, wxMAXIMIZE_BOX );

  my $icon = File::Spec->catfile(dirname($INC{"Demeter/UI/Athena.pm"}), 'Athena', , 'icons', "bullseye.png");
  my $bullseye = Wx::Bitmap->new($icon, wxBITMAP_TYPE_PNG);

  $icon = File::Spec->catfile(dirname($INC{"Demeter/UI/Athena.pm"}), 'Athena', , 'icons', "chainlink.png");
  my $chainlink = Wx::Bitmap->new($icon, wxBITMAP_TYPE_PNG);

  my $group_font_size = Wx::SystemSettings::GetFont(wxSYS_DEFAULT_GUI_FONT)->GetPointSize + 1;

  my $box = Wx::BoxSizer->new( wxVERTICAL);

  ## -------- Group -------------------------------------------
  my $groupbox       = Wx::StaticBox->new($this, -1, 'Current group', wxDefaultPosition, wxDefaultSize);
  my $groupboxsizer  = Wx::StaticBoxSizer->new( $groupbox, wxVERTICAL );
  $groupbox         -> SetFont( Wx::Font->new( $group_font_size, wxDEFAULT, wxNORMAL, wxBOLD, 0, "" ) );
  $box              -> Add($groupboxsizer, 0, wxALL, 5);

  my $gbs = Wx::GridBagSizer->new( 5, 5 );

  $this->{file_label} = Wx::StaticText->new($this, -1, "File");
  $this->{file}       = Wx::StaticText->new($this, -1, q{});
  $gbs -> Add($this->{file_label}, Wx::GBPosition->new(0,0));
  $gbs -> Add($this->{file},       Wx::GBPosition->new(0,1), Wx::GBSpan->new(1,5));

  my @elements = map {sprintf "%-2d: %s", $_, get_name($_)} (1 .. 96);
  $this->{bkg_z_label} = Wx::StaticText->new($this, -1, "Element");
  $this->{bkg_z}       = Wx::ComboBox  ->new($this, -1, 'Hydrogen', wxDefaultPosition, [130,-1], \@elements, wxCB_READONLY );
  $gbs -> Add($this->{bkg_z_label}, Wx::GBPosition->new(1,0));
  $gbs -> Add($this->{bkg_z},       Wx::GBPosition->new(1,1));

  $this->{fft_edge_label} = Wx::StaticText->new($this, -1, "Edge");
  $this->{fft_edge}       = Wx::ComboBox  ->new($this, -1, 'K', wxDefaultPosition, [50,-1],
  						[qw(K L1 L2 L3 M1 M2 M3 M4 M5)], wxCB_READONLY);
  $gbs -> Add($this->{fft_edge_label}, Wx::GBPosition->new(1,2));
  $gbs -> Add($this->{fft_edge},       Wx::GBPosition->new(1,3));

  $this->{bkg_eshift_label} = Wx::StaticText->new($this, -1, "Energy shift");
  $this->{bkg_eshift}       = Wx::TextCtrl  ->new($this, -1, q{}, wxDefaultPosition, [40,-1] );
  $gbs -> Add($this->{bkg_eshift_label}, Wx::GBPosition->new(1,4));
  $gbs -> Add($this->{bkg_eshift},       Wx::GBPosition->new(1,5));

  $this->{importance_label} = Wx::StaticText->new($this, -1, "Importance");
  $this->{importance}       = Wx::TextCtrl  ->new($this, -1, q{}, wxDefaultPosition, [25,-1] );
  $gbs -> Add($this->{importance_label}, Wx::GBPosition->new(1,6));
  $gbs -> Add($this->{importance},       Wx::GBPosition->new(1,7));

  $groupboxsizer -> Add($gbs, 0, wxALL, 5);



  ## -------- Background removal ------------------------------
  my $backgroundbox       = Wx::StaticBox->new($this, -1, 'Background removal', wxDefaultPosition, wxDefaultSize);
  my $backgroundboxsizer  = Wx::StaticBoxSizer->new( $backgroundbox, wxVERTICAL );
  $backgroundbox         -> SetFont( Wx::Font->new( $group_font_size, wxDEFAULT, wxNORMAL, wxBOLD, 0, "" ) );
  $box                   -> Add($backgroundboxsizer, 0, wxALL|wxGROW, 5);


  $gbs = Wx::GridBagSizer->new( 5, 5 );

  $this->{bkg_e0_label} = Wx::StaticText->new($this, -1, "E0");
  $this->{bkg_e0}       = Wx::TextCtrl  ->new($this, -1, q{}, wxDefaultPosition, [80,-1]);
  $gbs -> Add($this->{bkg_e0_label}, Wx::GBPosition->new(0,0));
  $gbs -> Add($this->{bkg_e0},       Wx::GBPosition->new(0,1));
  ## pluck button at 0,2
  $this->{bkg_rbkg_label} = Wx::StaticText->new($this, -1, "Rbkg");
  $this->{bkg_rbkg}       = Wx::TextCtrl  ->new($this, -1, q{}, wxDefaultPosition, [80,-1]);
  $gbs -> Add($this->{bkg_rbkg_label}, Wx::GBPosition->new(0,3));
  $gbs -> Add($this->{bkg_rbkg},       Wx::GBPosition->new(0,4));
  $this->{bkg_flatten} = Wx::CheckBox  ->new($this, -1, q{Flatten normalized data});
  $gbs -> Add($this->{bkg_flatten}, ,    Wx::GBPosition->new(0,5));
  $this->{bkg_flatten}->SetValue(1);

  $this->{bkg_kw_label} = Wx::StaticText->new($this, -1, "k-weight");
  $this->{bkg_kw}       = Wx::TextCtrl  ->new($this, -1, q{}, wxDefaultPosition, [80,-1]);
  $gbs -> Add($this->{bkg_kw_label}, Wx::GBPosition->new(1,0));
  $gbs -> Add($this->{bkg_kw},       Wx::GBPosition->new(1,1));
  $this->{bkg_step_label} = Wx::StaticText->new($this, -1, "Edge step");
  $this->{bkg_step}       = Wx::TextCtrl  ->new($this, -1, q{}, wxDefaultPosition, [80,-1]);
  $this->{bkg_fixstep}    = Wx::CheckBox  ->new($this, -1, q{fix step});
  $gbs -> Add($this->{bkg_step_label}, Wx::GBPosition->new(1,3));
  $gbs -> Add($this->{bkg_step},       Wx::GBPosition->new(1,4));
  $gbs -> Add($this->{bkg_fixstep},    Wx::GBPosition->new(1,5));

  $backgroundboxsizer -> Add($gbs, 0, wxALL, 5);

  $gbs = Wx::GridBagSizer->new( 5, 5 );

  $this->{bkg_pre1_label} = Wx::StaticText->new($this, -1, "Pre-edge range");
  $this->{bkg_pre1}       = Wx::TextCtrl  ->new($this, -1, q{}, wxDefaultPosition, [80,-1]);
  $gbs -> Add($this->{bkg_pre1_label}, Wx::GBPosition->new(0,0));
  $gbs -> Add($this->{bkg_pre1},       Wx::GBPosition->new(0,1));
  $this->{bkg_pre2_label} = Wx::StaticText->new($this, -1, "to");
  $this->{bkg_pre2}       = Wx::TextCtrl  ->new($this, -1, q{}, wxDefaultPosition, [80,-1]);
  $gbs -> Add($this->{bkg_pre2_label}, Wx::GBPosition->new(0,3));
  $gbs -> Add($this->{bkg_pre2},       Wx::GBPosition->new(0,4));

  $this->{bkg_pre1_pluck} = Wx::BitmapButton->new($this, -1, $bullseye);
  $gbs -> Add($this->{bkg_pre1_pluck}, Wx::GBPosition->new(0,2));
  $this->{bkg_pre2_pluck} = Wx::BitmapButton->new($this, -1, $bullseye);
  $gbs -> Add($this->{bkg_pre2_pluck}, Wx::GBPosition->new(0,5));


  $this->{bkg_nor1_label} = Wx::StaticText->new($this, -1, "Normalization range");
  $this->{bkg_nor1}       = Wx::TextCtrl  ->new($this, -1, q{}, wxDefaultPosition, [80,-1]);
  $gbs -> Add($this->{bkg_nor1_label}, Wx::GBPosition->new(1,0));
  $gbs -> Add($this->{bkg_nor1},       Wx::GBPosition->new(1,1));
  $this->{bkg_nor2_label} = Wx::StaticText->new($this, -1, "to");
  $this->{bkg_nor2}       = Wx::TextCtrl  ->new($this, -1, q{}, wxDefaultPosition, [80,-1]);
  $gbs -> Add($this->{bkg_nor2_label}, Wx::GBPosition->new(1,3));
  $gbs -> Add($this->{bkg_nor2},       Wx::GBPosition->new(1,4));

  $this->{bkg_nor1_pluck} = Wx::BitmapButton->new($this, -1, $bullseye);
  $gbs -> Add($this->{bkg_nor1_pluck}, Wx::GBPosition->new(1,2));
  $this->{bkg_nor2_pluck} = Wx::BitmapButton->new($this, -1, $bullseye);
  $gbs -> Add($this->{bkg_nor2_pluck}, Wx::GBPosition->new(1,5));


  $this->{bkg_spl1_label} = Wx::StaticText->new($this, -1, "Spline range in k");
  $this->{bkg_spl1}       = Wx::TextCtrl  ->new($this, -1, q{}, wxDefaultPosition, [80,-1]);
  $gbs -> Add($this->{bkg_spl1_label}, Wx::GBPosition->new(2,0));
  $gbs -> Add($this->{bkg_spl1},       Wx::GBPosition->new(2,1));
  ## pluck button at 2,2
  $this->{bkg_spl2_label} = Wx::StaticText->new($this, -1, "to");
  $this->{bkg_spl2}       = Wx::TextCtrl  ->new($this, -1, q{}, wxDefaultPosition, [80,-1]);
  $gbs -> Add($this->{bkg_spl2_label}, Wx::GBPosition->new(2,3));
  $gbs -> Add($this->{bkg_spl2},       Wx::GBPosition->new(2,4));

  $this->{bkg_spl1_pluck} = Wx::BitmapButton->new($this, -1, $bullseye);
  $gbs -> Add($this->{bkg_spl1_pluck}, Wx::GBPosition->new(2,2));
  $this->{bkg_spl2_pluck} = Wx::BitmapButton->new($this, -1, $bullseye);
  $gbs -> Add($this->{bkg_spl2_pluck}, Wx::GBPosition->new(2,5));

  $gbs -> Add(Wx::StaticBitmap->new($this, -1, $chainlink), Wx::GBPosition->new(2,6), Wx::GBSpan->new(2,1));

  $this->{bkg_spl1e_label} = Wx::StaticText->new($this, -1, "Spline range in E");
  $this->{bkg_spl1e}       = Wx::TextCtrl  ->new($this, -1, q{}, wxDefaultPosition, [80,-1]);
  $gbs -> Add($this->{bkg_spl1e_label}, Wx::GBPosition->new(3,0));
  $gbs -> Add($this->{bkg_spl1e},       Wx::GBPosition->new(3,1));
  $this->{bkg_spl2e_label} = Wx::StaticText->new($this, -1, "to");
  $this->{bkg_spl2e}       = Wx::TextCtrl  ->new($this, -1, q{}, wxDefaultPosition, [80,-1]);
  $gbs -> Add($this->{bkg_spl2e_label}, Wx::GBPosition->new(3,3));
  $gbs -> Add($this->{bkg_spl2e},       Wx::GBPosition->new(3,4));

  $this->{bkg_spl1e_pluck} = Wx::BitmapButton->new($this, -1, $bullseye);
  $gbs -> Add($this->{bkg_spl1e_pluck}, Wx::GBPosition->new(3,2));
  $this->{bkg_spl2e_pluck} = Wx::BitmapButton->new($this, -1, $bullseye);
  $gbs -> Add($this->{bkg_spl2e_pluck}, Wx::GBPosition->new(3,5));

  $backgroundboxsizer -> Add($gbs, 0, wxALL, 5);


  my $abox = Wx::BoxSizer->new( wxHORIZONTAL );
  $this->{bkg_algorithm_label} = Wx::StaticText->new($this, -1, "Algorithm");
  $this->{bkg_algorithm}       = Wx::Choice  ->new($this, -1, wxDefaultPosition, wxDefaultSize,
						   ['Autobk', 'CLnorm']);
  $this->{bkg_algorithm} -> SetSelection(0);
  $abox -> Add($this->{bkg_algorithm_label}, 0, wxALL, 5);
  $abox -> Add($this->{bkg_algorithm}, 0, wxRIGHT, 15);

  $this->{bkg_nnorm_label} = Wx::StaticText->new($this, -1, "Normalization order");
  $this->{bkg_nnorm_1} = Wx::RadioButton->new($this, -1, '1', wxDefaultPosition, wxDefaultSize, wxRB_GROUP);
  $this->{bkg_nnorm_2} = Wx::RadioButton->new($this, -1, '2', wxDefaultPosition, wxDefaultSize);
  $this->{bkg_nnorm_3} = Wx::RadioButton->new($this, -1, '3', wxDefaultPosition, wxDefaultSize);
  $abox -> Add($this->{bkg_nnorm_label}, 0, wxTOP|wxRIGHT, 3);
  $abox -> Add($this->{bkg_nnorm_1}, 0, wxRIGHT, 6);
  $abox -> Add($this->{bkg_nnorm_2}, 0, wxRIGHT, 6);
  $abox -> Add($this->{bkg_nnorm_3}, 0, wxRIGHT, 6);
  $this->{bkg_nnorm_3}->SetValue(1);

  $backgroundboxsizer -> Add($abox, 0, wxALL, 5);

  $abox = Wx::BoxSizer->new( wxHORIZONTAL );
  $this->{bkg_stan_label} = Wx::StaticText->new($this, -1, "Standard");
  $this->{bkg_stan}       = Wx::ComboBox  ->new($this, -1, '', wxDefaultPosition, [50,-1],
  						[], wxCB_READONLY);
  $abox -> Add($this->{bkg_stan_label}, 0, wxALL, 5);
  $abox -> Add($this->{bkg_stan}, 0, wxRIGHT, 15);
  $this->{bkg_clamp1_label} = Wx::StaticText->new($this, -1, "Spline clamps:  low");
  $this->{bkg_clamp1}       = Wx::Choice->new($this, -1, wxDefaultPosition, wxDefaultSize,
					      [qw(None Slight Weak Medium Strong Rigid)]);
  $this->{bkg_clamp1} -> SetSelection(0);
  $this->{bkg_clamp2_label} = Wx::StaticText->new($this, -1, "high");
  $this->{bkg_clamp2}       = Wx::Choice->new($this, -1, wxDefaultPosition, wxDefaultSize,
					      [qw(None Slight Weak Medium Strong Rigid)]);
  $this->{bkg_clamp2} -> SetSelection(4);
  $abox -> Add($this->{bkg_clamp1_label}, 0, wxALL, 5);
  $abox -> Add($this->{bkg_clamp1}, 0, wxRIGHT, 15);
  $abox -> Add($this->{bkg_clamp2_label}, 0, wxALL, 5);
  $abox -> Add($this->{bkg_clamp2}, 0, wxRIGHT, 15);

  $backgroundboxsizer -> Add($abox, 0, wxALL, 5);

  ## -------- Forward FT ------------------------------
  my $fftbox       = Wx::StaticBox->new($this, -1, 'Forward Fourier transform', wxDefaultPosition, wxDefaultSize);
  my $fftboxsizer  = Wx::StaticBoxSizer->new( $fftbox, wxHORIZONTAL );
  $fftbox         -> SetFont( Wx::Font->new( $group_font_size, wxDEFAULT, wxNORMAL, wxBOLD, 0, "" ) );
  $box            -> Add($fftboxsizer, 0, wxALL|wxGROW, 5);

  $gbs = Wx::GridBagSizer->new( 5, 5 );

  $this->{fft_kmin_label} = Wx::StaticText->new($this, -1, "k-range");
  $this->{fft_kmin}       = Wx::TextCtrl  ->new($this, -1, q{}, wxDefaultPosition, [80,-1]);
  $gbs -> Add($this->{fft_kmin_label}, Wx::GBPosition->new(0,0));
  $gbs -> Add($this->{fft_kmin},       Wx::GBPosition->new(0,1));
  $this->{fft_kmin_pluck} = Wx::BitmapButton->new($this, -1, $bullseye);
  $gbs -> Add($this->{fft_kmin_pluck}, Wx::GBPosition->new(0,2));

  $this->{fft_kmax_label} = Wx::StaticText->new($this, -1, "to");
  $this->{fft_kmax}       = Wx::TextCtrl  ->new($this, -1, q{}, wxDefaultPosition, [80,-1]);
  $gbs -> Add($this->{fft_kmax_label}, Wx::GBPosition->new(0,3));
  $gbs -> Add($this->{fft_kmax},       Wx::GBPosition->new(0,4));
  $this->{fft_kmax_pluck} = Wx::BitmapButton->new($this, -1, $bullseye);
  $gbs -> Add($this->{fft_kmax_pluck}, Wx::GBPosition->new(0,5));

  $this->{fft_dk_label} = Wx::StaticText->new($this, -1, "dk");
  $this->{fft_dk}       = Wx::TextCtrl  ->new($this, -1, q{}, wxDefaultPosition, [80,-1]);
  $gbs -> Add($this->{fft_dk_label}, Wx::GBPosition->new(0,6));
  $gbs -> Add($this->{fft_dk},       Wx::GBPosition->new(0,7));

  $this->{fft_kwin_label} = Wx::StaticText->new($this, -1, "window");
  $this->{fft_kwin}       = Wx::Choice    ->new($this, -1, wxDefaultPosition, wxDefaultSize,
						[qw(Kaiser-Bessel Hanning Welch Parzen Sine Gaussian)]);
  $this->{fft_kwin}->SetStringSelection(ucfirst($Demeter::UI::Athena::demeter->co->default("fft", "kwindow")));
  $gbs -> Add($this->{fft_kwin_label}, Wx::GBPosition->new(1,0));
  $gbs -> Add($this->{fft_kwin},       Wx::GBPosition->new(1,1), Wx::GBSpan->new(1,3));
  $this->{fit_karb_value_label} = Wx::StaticText->new($this, -1, q{arbitrary k-weight});
  $this->{fit_karb_value}       = Wx::TextCtrl->new($this, -1, q{}, wxDefaultPosition, [80,-1]);
  $gbs -> Add($this->{fit_karb_value_label}, Wx::GBPosition->new(1,4), Wx::GBSpan->new(1,2));
  $gbs -> Add($this->{fit_karb_value},       Wx::GBPosition->new(1,6), Wx::GBSpan->new(1,2));
  $this->{fft_pc} = Wx::CheckBox  ->new($this, -1, q{phase correction});
  $gbs -> Add($this->{fft_pc},         Wx::GBPosition->new(1,8));

  $fftboxsizer -> Add($gbs, 0, wxALL, 5);





  ## -------- Backward FT ------------------------------
  my $bftbox       = Wx::StaticBox->new($this, -1, 'Backward Fourier transform', wxDefaultPosition, wxDefaultSize);
  my $bftboxsizer  = Wx::StaticBoxSizer->new( $bftbox, wxHORIZONTAL );
  $bftbox         -> SetFont( Wx::Font->new( $group_font_size, wxDEFAULT, wxNORMAL, wxBOLD, 0, "" ) );
  $box            -> Add($bftboxsizer, 0, wxALL|wxGROW, 5);


  $gbs = Wx::GridBagSizer->new( 5, 5 );

  $this->{bft_rmin_label} = Wx::StaticText->new($this, -1, "R-range");
  $this->{bft_rmin}       = Wx::TextCtrl  ->new($this, -1, q{}, wxDefaultPosition, [80,-1]);
  $gbs -> Add($this->{bft_rmin_label}, Wx::GBPosition->new(0,0));
  $gbs -> Add($this->{bft_rmin},       Wx::GBPosition->new(0,1));
  $this->{bft_rmin_pluck} = Wx::BitmapButton->new($this, -1, $bullseye);
  $gbs -> Add($this->{bft_rmin_pluck}, Wx::GBPosition->new(0,2));

  $this->{bft_rmax_label} = Wx::StaticText->new($this, -1, "to");
  $this->{bft_rmax}       = Wx::TextCtrl  ->new($this, -1, q{}, wxDefaultPosition, [80,-1]);
  $gbs -> Add($this->{bft_rmax_label}, Wx::GBPosition->new(0,3));
  $gbs -> Add($this->{bft_rmax},       Wx::GBPosition->new(0,4));
  $this->{bft_rmax_pluck} = Wx::BitmapButton->new($this, -1, $bullseye);
  $gbs -> Add($this->{bft_rmax_pluck}, Wx::GBPosition->new(0,5));

  $this->{bft_dr_label} = Wx::StaticText->new($this, -1, "dR");
  $this->{bft_dr}       = Wx::TextCtrl  ->new($this, -1, q{}, wxDefaultPosition, [80,-1]);
  $gbs -> Add($this->{bft_dr_label}, Wx::GBPosition->new(0,6));
  $gbs -> Add($this->{bft_dr},       Wx::GBPosition->new(0,7));

  $this->{bft_rwin_label} = Wx::StaticText->new($this, -1, "window");
  $this->{bft_rwin}       = Wx::Choice    ->new($this, -1, wxDefaultPosition, wxDefaultSize,
						[qw(Kaiser-Bessel Hanning Welch Parzen Sine Gaussian)]);
  $this->{bft_rwin}->SetStringSelection(ucfirst($Demeter::UI::Athena::demeter->co->default("bft", "rwindow")));
  $gbs -> Add($this->{bft_rwin_label}, Wx::GBPosition->new(1,0));
  $gbs -> Add($this->{bft_rwin},       Wx::GBPosition->new(1,1), Wx::GBSpan->new(1,3));

  $bftboxsizer -> Add($gbs, 0, wxALL, 5);


  my $plotbox       = Wx::StaticBox->new($this, -1, 'Plotting parameters', wxDefaultPosition, wxDefaultSize);
  my $plotboxsizer  = Wx::StaticBoxSizer->new( $plotbox, wxHORIZONTAL );
  $plotbox         -> SetFont( Wx::Font->new( $group_font_size, wxDEFAULT, wxNORMAL, wxBOLD, 0, "" ) );
  $box             -> Add($plotboxsizer, 0, wxALL|wxGROW, 5);

  my $pbox = Wx::BoxSizer->new( wxHORIZONTAL );
  $this->{plot_multiplier_label} = Wx::StaticText->new($this, -1, "Plot multiplier");
  $this->{plot_multiplier}       = Wx::TextCtrl  ->new($this, -1, q{}, wxDefaultPosition, [80,-1]);
  $this->{y_offset_label}        = Wx::StaticText->new($this, -1, "y-axis offset");
  $this->{y_offset}              = Wx::TextCtrl  ->new($this, -1, q{}, wxDefaultPosition, [80,-1]);
  $pbox -> Add($this->{plot_multiplier_label}, 0, wxALL, 5);
  $pbox -> Add($this->{plot_multiplier},       0, wxRIGHT, 10);
  $pbox -> Add($this->{y_offset_label},        0, wxALL, 5);
  $pbox -> Add($this->{y_offset},              0, wxRIGHT, 10);

  $plotboxsizer -> Add($pbox, 0, wxALL, 5);

  $this->SetSizerAndFit($box);
  return $this;
};

1;
