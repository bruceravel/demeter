package Demeter::UI::Athena::Main;

use Wx qw( :everything );
use base 'Wx::Panel';
use Wx::Event qw(EVT_LIST_ITEM_ACTIVATED EVT_LIST_ITEM_SELECTED EVT_BUTTON  EVT_KEY_DOWN);
use Wx::Perl::TextValidator;

use Chemistry::Elements qw(get_name get_Z get_symbol);
use File::Basename;
use File::Spec;

use vars qw($label $tag);
$label = "Main window";
$tag = 'Main';

my $box_font_size = Wx::SystemSettings::GetFont(wxSYS_DEFAULT_GUI_FONT)->GetPointSize + 1;
my $icon          = File::Spec->catfile(dirname($INC{"Demeter/UI/Athena.pm"}), 'Athena', , 'icons', "bullseye.png");
my $bullseye      = Wx::Bitmap->new($icon, wxBITMAP_TYPE_PNG);
$icon             = File::Spec->catfile(dirname($INC{"Demeter/UI/Athena.pm"}), 'Athena', , 'icons', "chainlink.png");
my $chainlink     = Wx::Bitmap->new($icon, wxBITMAP_TYPE_PNG);

my @group_params;
my @bkg_parameters;
my @fft_parameters;
my @bft_parameters;
my @plot_parameters;

my $tcsize = [60,-1];

sub new {
  my ($class, $parent, $app) = @_;
  my $this = $class->SUPER::new($parent, -1, wxDefaultPosition, wxDefaultSize, wxMAXIMIZE_BOX );

  my $box = Wx::BoxSizer->new( wxVERTICAL);
  $this->{sizer}  = $box;
  $this->{parent} = $parent;

  ## -------- Group
  $this->group($app);
  ## -------- Background removal
  $this->bkg($app);
  ## -------- Forward FT
  $this->fft($app);
  ## -------- Backward FT
  $this->bft($app);
  ## -------- Plotting parameters
  $this->plot($app);

  $this->mode(q{}, 0, 0);

  $this->SetSizerAndFit($box);
  return $this;
};

sub group {
  my ($this, $app) = @_;

  my $groupbox       = Wx::StaticBox->new($this, -1, 'Current group', wxDefaultPosition, wxDefaultSize);
  my $groupboxsizer  = Wx::StaticBoxSizer->new( $groupbox, wxVERTICAL );
  $groupbox         -> SetFont( Wx::Font->new( $box_font_size, wxDEFAULT, wxNORMAL, wxBOLD, 0, "" ) );
  $this->{sizer}    -> Add($groupboxsizer, 0, wxALL, 0);
  $this->{groupbox}  = $groupbox;

  my $gbs = Wx::GridBagSizer->new( 5, 5 );

  $this->{file_label} = Wx::StaticText -> new($this, -1, "File");
  $this->{file}       = Wx::TextCtrl   -> new($this, -1, q{}, wxDefaultPosition, [450,-1], wxTE_READONLY);
  $gbs -> Add($this->{file_label}, Wx::GBPosition->new(0,0));
  $gbs -> Add($this->{file},       Wx::GBPosition->new(0,1), Wx::GBSpan->new(1,7), 1);

  my @elements = map {sprintf "%-2d: %s", $_, get_name($_)} (1 .. 96);
  $this->{bkg_z_label}      = Wx::StaticText -> new($this, -1, "Element");
  $this->{bkg_z}            = Wx::ComboBox   -> new($this, -1, 'Hydrogen', wxDefaultPosition, [130,-1], \@elements, wxCB_READONLY );
  $this->{fft_edge_label}   = Wx::StaticText -> new($this, -1, "Edge");
  $this->{fft_edge}         = Wx::ComboBox   -> new($this, -1, 'K', wxDefaultPosition, [50,-1],
						    [qw(K L1 L2 L3 M1 M2 M3 M4 M5)], wxCB_READONLY);
  $this->{bkg_eshift_label} = Wx::StaticText -> new($this, -1, "Energy shift");
  $this->{bkg_eshift}       = Wx::TextCtrl   -> new($this, -1, q{}, wxDefaultPosition, [40,-1] );
  $this->{importance_label} = Wx::StaticText -> new($this, -1, "Importance");
  $this->{importance}       = Wx::TextCtrl   -> new($this, -1, q{}, wxDefaultPosition, [25,-1] );
  $gbs -> Add($this->{bkg_z_label},      Wx::GBPosition->new(1,0));
  $gbs -> Add($this->{bkg_z},            Wx::GBPosition->new(1,1));
  $gbs -> Add($this->{fft_edge_label},   Wx::GBPosition->new(1,2));
  $gbs -> Add($this->{fft_edge},         Wx::GBPosition->new(1,3));
  $gbs -> Add($this->{bkg_eshift_label}, Wx::GBPosition->new(1,4));
  $gbs -> Add($this->{bkg_eshift},       Wx::GBPosition->new(1,5));
  $gbs -> Add($this->{importance_label}, Wx::GBPosition->new(1,6));
  $gbs -> Add($this->{importance},       Wx::GBPosition->new(1,7));

  push @group_params, qw(file bkg_z fft_edge bkg_eshift importance);

  $this->{$_} -> SetValidator( Wx::Perl::TextValidator->new( qr([-0-9.]) ) )
    foreach (qw(bkg_eshift importance));


  $groupboxsizer -> Add($gbs, 0, wxALL, 5);
  return $this;
};

sub bkg {
  my ($this, $app) = @_;

  my $backgroundbox       = Wx::StaticBox->new($this, -1, 'Background removal', wxDefaultPosition, wxDefaultSize);
  my $backgroundboxsizer  = Wx::StaticBoxSizer->new( $backgroundbox, wxVERTICAL );
  $backgroundbox         -> SetFont( Wx::Font->new( $box_font_size, wxDEFAULT, wxNORMAL, wxBOLD, 0, "" ) );
  $this->{sizer}         -> Add($backgroundboxsizer, 0, wxALL|wxGROW, 0);

  $gbs = Wx::GridBagSizer->new( 5, 5 );

  ## E0, Rbkg, flatten
  $this->{bkg_e0_label}   = Wx::StaticText   -> new($this, -1, "E0");
  $this->{bkg_e0}         = Wx::TextCtrl     -> new($this, -1, q{}, wxDefaultPosition, $tcsize);
  $this->{bkg_e0_pluck}   = Wx::BitmapButton -> new($this, -1, $bullseye);
  $this->{bkg_rbkg_label} = Wx::StaticText   -> new($this, -1, "Rbkg");
  $this->{bkg_rbkg}       = Wx::TextCtrl     -> new($this, -1, q{}, wxDefaultPosition, $tcsize);
  $this->{bkg_flatten}    = Wx::CheckBox     -> new($this, -1, q{Flatten normalized data});
  $gbs -> Add($this->{bkg_e0_label},   Wx::GBPosition->new(0,0));
  $gbs -> Add($this->{bkg_e0},         Wx::GBPosition->new(0,1));
  $gbs -> Add($this->{bkg_e0_pluck},   Wx::GBPosition->new(0,2));
  $gbs -> Add($this->{bkg_rbkg_label}, Wx::GBPosition->new(0,3));
  $gbs -> Add($this->{bkg_rbkg},       Wx::GBPosition->new(0,4));
  $gbs -> Add($this->{bkg_flatten},    Wx::GBPosition->new(0,5), Wx::GBSpan->new(1,4));
  $this->{bkg_flatten}->SetValue(1);
  push @bkg_parameters, qw(bkg_e0 bkg_rbkg bkg_flatten);

  ## kweight, step, fix step
  $this->{bkg_kw_label}   = Wx::StaticText -> new($this, -1, "k-weight");
  $this->{bkg_kw}         = Wx::SpinCtrl   -> new($this, -1, q{}, wxDefaultPosition, $tcsize, wxSP_ARROW_KEYS, 0, 3);
  $gbs -> Add($this->{bkg_kw_label},   Wx::GBPosition->new(1,3));
  $gbs -> Add($this->{bkg_kw},         Wx::GBPosition->new(1,4));
  push @bkg_parameters, qw(bkg_kw bkg_step bkg_fixstep);

  ## algorithm and normalization order
  $this->{bkg_algorithm_label} = Wx::StaticText  -> new($this, -1, "Algorithm");
  $this->{bkg_algorithm}       = Wx::Choice      -> new($this, -1, wxDefaultPosition, wxDefaultSize,
							['Autobk', 'CLnorm']);
  $this->{bkg_nnorm_label}     = Wx::StaticText  -> new($this, -1, "Normalization order");
  $this->{bkg_nnorm_1}         = Wx::RadioButton -> new($this, -1, '1', wxDefaultPosition, wxDefaultSize, wxRB_GROUP);
  $this->{bkg_nnorm_2}         = Wx::RadioButton -> new($this, -1, '2');
  $this->{bkg_nnorm_3}         = Wx::RadioButton -> new($this, -1, '3');
  $gbs -> Add($this->{bkg_algorithm_label}, Wx::GBPosition->new(1,0));
  $gbs -> Add($this->{bkg_algorithm},       Wx::GBPosition->new(1,1), Wx::GBSpan->new(1,2));
  $gbs -> Add($this->{bkg_nnorm_label},     Wx::GBPosition->new(1,5));
  $gbs -> Add($this->{bkg_nnorm_1},         Wx::GBPosition->new(1,6));
  $gbs -> Add($this->{bkg_nnorm_2},         Wx::GBPosition->new(1,7));
  $gbs -> Add($this->{bkg_nnorm_3},         Wx::GBPosition->new(1,8));
  $this->{bkg_algorithm} -> SetSelection(0);
  $this->{bkg_nnorm_3}   -> SetValue(1);
  push @bkg_parameters, qw(bkg_algorithm bkg_nnorm bkg_nnorm_1 bkg_nnorm_2 bkg_nnorm_3);

  $backgroundboxsizer -> Add($gbs, 0, wxALL, 5);

  $gbs = Wx::GridBagSizer->new( 5, 5 );

  ## pre edge line
  $this->{bkg_pre1_label} = Wx::StaticText   -> new($this, -1, "Pre-edge range");
  $this->{bkg_pre1}       = Wx::TextCtrl     -> new($this, -1, q{}, wxDefaultPosition, $tcsize);
  $this->{bkg_pre2_label} = Wx::StaticText   -> new($this, -1, "to");
  $this->{bkg_pre2}       = Wx::TextCtrl     -> new($this, -1, q{}, wxDefaultPosition, $tcsize);
  $this->{bkg_pre1_pluck} = Wx::BitmapButton -> new($this, -1, $bullseye);
  $this->{bkg_pre2_pluck} = Wx::BitmapButton -> new($this, -1, $bullseye);
  $gbs -> Add($this->{bkg_pre1_label}, Wx::GBPosition->new(0,0));
  $gbs -> Add($this->{bkg_pre1},       Wx::GBPosition->new(0,1));
  $gbs -> Add($this->{bkg_pre1_pluck}, Wx::GBPosition->new(0,2));
  $gbs -> Add($this->{bkg_pre2_label}, Wx::GBPosition->new(0,3));
  $gbs -> Add($this->{bkg_pre2},       Wx::GBPosition->new(0,4));
  $gbs -> Add($this->{bkg_pre2_pluck}, Wx::GBPosition->new(0,5));
  push @bkg_parameters, qw(bkg_pre1 bkg_pre2);

  ## noirmalization line
  $this->{bkg_nor1_label} = Wx::StaticText   -> new($this, -1, "Normalization range");
  $this->{bkg_nor1}       = Wx::TextCtrl     -> new($this, -1, q{}, wxDefaultPosition, $tcsize);
  $this->{bkg_nor2_label} = Wx::StaticText   -> new($this, -1, "to");
  $this->{bkg_nor2}       = Wx::TextCtrl     -> new($this, -1, q{}, wxDefaultPosition, $tcsize);
  $this->{bkg_nor1_pluck} = Wx::BitmapButton -> new($this, -1, $bullseye);
  $this->{bkg_nor2_pluck} = Wx::BitmapButton -> new($this, -1, $bullseye);
  $gbs -> Add($this->{bkg_nor1_label}, Wx::GBPosition->new(1,0));
  $gbs -> Add($this->{bkg_nor1},       Wx::GBPosition->new(1,1));
  $gbs -> Add($this->{bkg_nor1_pluck}, Wx::GBPosition->new(1,2));
  $gbs -> Add($this->{bkg_nor2_label}, Wx::GBPosition->new(1,3));
  $gbs -> Add($this->{bkg_nor2},       Wx::GBPosition->new(1,4));
  $gbs -> Add($this->{bkg_nor2_pluck}, Wx::GBPosition->new(1,5));
  push @bkg_parameters, qw(bkg_nor1 bkg_nor2);

  $this->{bkg_step_label} = Wx::StaticText -> new($this, -1, "Edge step");
  $this->{bkg_step}       = Wx::TextCtrl   -> new($this, -1, q{}, wxDefaultPosition, $tcsize);
  $this->{bkg_fixstep}    = Wx::CheckBox   -> new($this, -1, q{fix step});
  $gbs -> Add($this->{bkg_step_label}, Wx::GBPosition->new(0,7));
  $gbs -> Add($this->{bkg_step},       Wx::GBPosition->new(0,8));
  $gbs -> Add($this->{bkg_fixstep},    Wx::GBPosition->new(1,8));


  ## spline range in k
  $this->{bkg_spl1_label} = Wx::StaticText   -> new($this, -1, "Spline range in k");
  $this->{bkg_spl1}       = Wx::TextCtrl     -> new($this, -1, q{}, wxDefaultPosition, $tcsize);
  $this->{bkg_spl2_label} = Wx::StaticText   -> new($this, -1, "to");
  $this->{bkg_spl2}       = Wx::TextCtrl     -> new($this, -1, q{}, wxDefaultPosition, $tcsize);
  $this->{bkg_spl1_pluck} = Wx::BitmapButton -> new($this, -1, $bullseye);
  $this->{bkg_spl2_pluck} = Wx::BitmapButton -> new($this, -1, $bullseye);
  $gbs -> Add($this->{bkg_spl1_label}, Wx::GBPosition->new(2,0));
  $gbs -> Add($this->{bkg_spl1},       Wx::GBPosition->new(2,1));
  $gbs -> Add($this->{bkg_spl1_pluck}, Wx::GBPosition->new(2,2));
  $gbs -> Add($this->{bkg_spl2_label}, Wx::GBPosition->new(2,3));
  $gbs -> Add($this->{bkg_spl2},       Wx::GBPosition->new(2,4));
  $gbs -> Add($this->{bkg_spl2_pluck}, Wx::GBPosition->new(2,5));
  push @bkg_parameters, qw(bkg_spl1 bkg_spl2);

  $this->{chainlink} = Wx::StaticBitmap->new($this, -1, $chainlink);
  $gbs -> Add($this->{chainlink}, Wx::GBPosition->new(2,6), Wx::GBSpan->new(2,1));
  #$app -> mouseover($this->{chainlink}, "The spline ranges in k and E are not independent parameters, but both are displayed as a service to the user.");

  ## spline range in E
  $this->{bkg_spl1e_label} = Wx::StaticText   -> new($this, -1, "Spline range in E");
  $this->{bkg_spl1e}       = Wx::TextCtrl     -> new($this, -1, q{}, wxDefaultPosition, $tcsize);
  $this->{bkg_spl2e_label} = Wx::StaticText   -> new($this, -1, "to");
  $this->{bkg_spl2e}       = Wx::TextCtrl     -> new($this, -1, q{}, wxDefaultPosition, $tcsize);
  $this->{bkg_spl1e_pluck} = Wx::BitmapButton -> new($this, -1, $bullseye);
  $this->{bkg_spl2e_pluck} = Wx::BitmapButton -> new($this, -1, $bullseye);
  $gbs -> Add($this->{bkg_spl1e_label}, Wx::GBPosition->new(3,0));
  $gbs -> Add($this->{bkg_spl1e},       Wx::GBPosition->new(3,1));
  $gbs -> Add($this->{bkg_spl1e_pluck}, Wx::GBPosition->new(3,2));
  $gbs -> Add($this->{bkg_spl2e_label}, Wx::GBPosition->new(3,3));
  $gbs -> Add($this->{bkg_spl2e},       Wx::GBPosition->new(3,4));
  $gbs -> Add($this->{bkg_spl2e_pluck}, Wx::GBPosition->new(3,5));
  push @bkg_parameters, qw(bkg_spl1e bkg_spl2e chainlink);

  $backgroundboxsizer -> Add($gbs, 0, wxALL, 5);

  ## standard and clamps
  my $clamps = [qw(None Slight Weak Medium Strong Rigid)];
  $abox = Wx::BoxSizer->new( wxHORIZONTAL );
  $this->{bkg_stan_label}   = Wx::StaticText -> new($this, -1, "Standard");
  $this->{bkg_stan}         = Wx::ComboBox   -> new($this, -1, '', wxDefaultPosition, [50,-1], [], wxCB_READONLY);
  $this->{bkg_clamp1_label} = Wx::StaticText -> new($this, -1, "Spline clamps:  low");
  $this->{bkg_clamp1}       = Wx::Choice     -> new($this, -1, wxDefaultPosition, wxDefaultSize, $clamps);
  $this->{bkg_clamp2_label} = Wx::StaticText -> new($this, -1, "high");
  $this->{bkg_clamp2}       = Wx::Choice     -> new($this, -1, wxDefaultPosition, wxDefaultSize, $clamps);
  $abox -> Add($this->{bkg_stan_label},   0, wxALL,    5);
  $abox -> Add($this->{bkg_stan},         0, wxRIGHT, 15);
  $abox -> Add($this->{bkg_clamp1_label}, 0, wxALL,    5);
  $abox -> Add($this->{bkg_clamp1},       0, wxRIGHT, 15);
  $abox -> Add($this->{bkg_clamp2_label}, 0, wxALL,    5);
  $abox -> Add($this->{bkg_clamp2},       0, wxRIGHT, 15);
  $this->{bkg_clamp1} -> SetSelection(0);
  $this->{bkg_clamp2} -> SetSelection(0);
  push @bkg_parameters, qw(bkg_stan bkg_clamp1 bkg_clamp2);

  $backgroundboxsizer -> Add($abox, 0, wxTOP|wxBOTTOM, 5);

  $this->{$_} -> SetValidator( Wx::Perl::TextValidator->new( qr([-0-9.]) ) )
    foreach (qw(bkg_pre1 bkg_pre2 bkg_nor1 bkg_nor2 bkg_spl1 bkg_spl2 bkg_spl1e bkg_spl2e
		bkg_e0 bkg_rbkg bkg_kw bkg_stan));

  return $this;
};


sub fft {
  my ($this, $app) = @_;

  my $fftbox       = Wx::StaticBox->new($this, -1, 'Forward Fourier transform', wxDefaultPosition, wxDefaultSize);
  my $fftboxsizer  = Wx::StaticBoxSizer->new( $fftbox, wxHORIZONTAL );
  $fftbox         -> SetFont( Wx::Font->new( $box_font_size, wxDEFAULT, wxNORMAL, wxBOLD, 0, "" ) );
  $this->{sizer}  -> Add($fftboxsizer, 0, wxALL|wxGROW, 0);

  $gbs = Wx::GridBagSizer->new( 5, 5 );

  $this->{fft_kmin_label} = Wx::StaticText   -> new($this, -1, "k-range");
  $this->{fft_kmin}       = Wx::TextCtrl     -> new($this, -1, q{}, wxDefaultPosition, $tcsize);
  $this->{fft_kmin_pluck} = Wx::BitmapButton -> new($this, -1, $bullseye);
  $gbs -> Add($this->{fft_kmin_label}, Wx::GBPosition->new(0,0));
  $gbs -> Add($this->{fft_kmin},       Wx::GBPosition->new(0,1));
  $gbs -> Add($this->{fft_kmin_pluck}, Wx::GBPosition->new(0,2));

  $this->{fft_kmax_label} = Wx::StaticText   -> new($this, -1, "to");
  $this->{fft_kmax}       = Wx::TextCtrl     -> new($this, -1, q{}, wxDefaultPosition, $tcsize);
  $this->{fft_kmax_pluck} = Wx::BitmapButton -> new($this, -1, $bullseye);
  $this->{fft_dk_label}   = Wx::StaticText   -> new($this, -1, "dk");
  $this->{fft_dk}         = Wx::TextCtrl     -> new($this, -1, q{}, wxDefaultPosition, $tcsize);
  $gbs -> Add($this->{fft_kmax_label}, Wx::GBPosition->new(0,3));
  $gbs -> Add($this->{fft_kmax},       Wx::GBPosition->new(0,4));
  $gbs -> Add($this->{fft_kmax_pluck}, Wx::GBPosition->new(0,5));
  $gbs -> Add($this->{fft_dk_label},   Wx::GBPosition->new(0,6));
  $gbs -> Add($this->{fft_dk},         Wx::GBPosition->new(0,7));

  $this->{fft_kwindow_label}    = Wx::StaticText -> new($this, -1, "window");
  $this->{fft_kwindow}          = Wx::Choice     -> new($this, -1, wxDefaultPosition, wxDefaultSize,
							[qw(Kaiser-Bessel Hanning Welch Parzen Sine Gaussian)]);
  $this->{fit_karb_value_label} = Wx::StaticText -> new($this, -1, q{arbitrary k-weight});
  $this->{fit_karb_value}       = Wx::TextCtrl   -> new($this, -1, q{}, wxDefaultPosition, $tcsize);
  $this->{fft_pc}               = Wx::CheckBox   -> new($this, -1, q{phase correction});
  $gbs -> Add($this->{fft_kwindow_label},    Wx::GBPosition->new(1,0));
  $gbs -> Add($this->{fft_kwindow},          Wx::GBPosition->new(1,1), Wx::GBSpan->new(1,3));
  $gbs -> Add($this->{fit_karb_value_label}, Wx::GBPosition->new(1,4), Wx::GBSpan->new(1,2));
  $gbs -> Add($this->{fit_karb_value},       Wx::GBPosition->new(1,6), Wx::GBSpan->new(1,2));
  $gbs -> Add($this->{fft_pc},               Wx::GBPosition->new(1,8));
  $this->{fft_kwindow}->SetStringSelection($this->window_name($Demeter::UI::Athena::demeter->co->default("fft", "kwindow")));
  push @fft_parameters, qw(fft_kmin fft_kmax fft_dk fft_kwindow fit_karb_value fft_pc);

  $fftboxsizer -> Add($gbs, 0, wxALL, 5);

  $this->{$_} -> SetValidator( Wx::Perl::TextValidator->new( qr([0-9.]) ) )
    foreach (qw(fft_kmin fft_kmax fft_dk fit_karb_value));

  return $this;
};

sub bft {
  my ($this, $app) = @_;

  my $bftbox       = Wx::StaticBox->new($this, -1, 'Backward Fourier transform', wxDefaultPosition, wxDefaultSize);
  my $bftboxsizer  = Wx::StaticBoxSizer->new( $bftbox, wxHORIZONTAL );
  $bftbox         -> SetFont( Wx::Font->new( $box_font_size, wxDEFAULT, wxNORMAL, wxBOLD, 0, "" ) );
  $this->{sizer}  -> Add($bftboxsizer, 0, wxALL|wxGROW, 0);

  $gbs = Wx::GridBagSizer->new( 5, 5 );

  $this->{bft_rmin_label} = Wx::StaticText   -> new($this, -1, "R-range");
  $this->{bft_rmin}       = Wx::TextCtrl     -> new($this, -1, q{}, wxDefaultPosition, $tcsize);
  $this->{bft_rmin_pluck} = Wx::BitmapButton -> new($this, -1, $bullseye);
  $this->{bft_rmax_label} = Wx::StaticText   -> new($this, -1, "to");
  $this->{bft_rmax}       = Wx::TextCtrl     -> new($this, -1, q{}, wxDefaultPosition, $tcsize);
  $this->{bft_rmax_pluck} = Wx::BitmapButton -> new($this, -1, $bullseye);
  $this->{bft_dr_label}   = Wx::StaticText -> new($this, -1, "dR");
  $this->{bft_dr}         = Wx::TextCtrl   -> new($this, -1, q{}, wxDefaultPosition, $tcsize);
  $gbs -> Add($this->{bft_rmin_label}, Wx::GBPosition->new(0,0));
  $gbs -> Add($this->{bft_rmin},       Wx::GBPosition->new(0,1));
  $gbs -> Add($this->{bft_rmin_pluck}, Wx::GBPosition->new(0,2));
  $gbs -> Add($this->{bft_rmax_label}, Wx::GBPosition->new(0,3));
  $gbs -> Add($this->{bft_rmax},       Wx::GBPosition->new(0,4));
  $gbs -> Add($this->{bft_rmax_pluck}, Wx::GBPosition->new(0,5));
  $gbs -> Add($this->{bft_dr_label},   Wx::GBPosition->new(0,6));
  $gbs -> Add($this->{bft_dr},         Wx::GBPosition->new(0,7));
  push @bft_parameters, qw(bft_rmin bft_rmax bft_dr bft_rwindow);

  # $this->{bft_rwindow_label} = Wx::StaticText -> new($this, -1, "window");
  # $this->{bft_rwindow}       = Wx::Choice     -> new($this, -1, wxDefaultPosition, wxDefaultSize,
  # 						  [qw(Kaiser-Bessel Hanning Welch Parzen Sine Gaussian)]);
  # $gbs -> Add($this->{bft_rwindow_label}, Wx::GBPosition->new(1,0));
  # $gbs -> Add($this->{bft_rwindow},       Wx::GBPosition->new(1,1), Wx::GBSpan->new(1,3));
  # $this->{bft_rwindow}->SetStringSelection($this->window_name($Demeter::UI::Athena::demeter->co->default("bft", "rwindow")));

  $bftboxsizer -> Add($gbs, 0, wxALL, 5);

  $this->{$_} -> SetValidator( Wx::Perl::TextValidator->new( qr([0-9.]) ) )
    foreach (qw(bft_rmin bft_rmax bft_dr));

  return $this;
};

sub plot {
  my ($this, $app) = @_;

  my $plotbox       = Wx::StaticBox->new($this, -1, 'Plotting parameters', wxDefaultPosition, wxDefaultSize);
  my $plotboxsizer  = Wx::StaticBoxSizer->new( $plotbox, wxHORIZONTAL );
  $plotbox         -> SetFont( Wx::Font->new( $box_font_size, wxDEFAULT, wxNORMAL, wxBOLD, 0, "" ) );
  $this->{sizer}   -> Add($plotboxsizer, 0, wxALL|wxGROW, 0);

  my $pbox = Wx::BoxSizer->new( wxHORIZONTAL );
  $this->{plot_multiplier_label} = Wx::StaticText->new($this, -1, "Plot multiplier");
  $this->{plot_multiplier}       = Wx::TextCtrl  ->new($this, -1, q{}, wxDefaultPosition, $tcsize);
  $this->{y_offset_label}        = Wx::StaticText->new($this, -1, "y-axis offset");
  $this->{y_offset}              = Wx::TextCtrl  ->new($this, -1, q{}, wxDefaultPosition, $tcsize);
  $pbox -> Add($this->{plot_multiplier_label}, 0, wxALL,    5);
  $pbox -> Add($this->{plot_multiplier},       0, wxRIGHT, 10);
  $pbox -> Add($this->{y_offset_label},        0, wxALL,    5);
  $pbox -> Add($this->{y_offset},              0, wxRIGHT, 10);
  push @plot_parameters, qw(plot_multiplier y_offset);

  $this->{$_} -> SetValidator( Wx::Perl::TextValidator->new( qr([-0-9.]) ) )
    foreach (qw(plot_multiplier y_offset));

  $plotboxsizer -> Add($pbox, 0, wxTOP|wxBOTTOM, 5);
  return $this;
};



sub mode {
  my ($this, $group, $enabled, $frozen) = @_;

  foreach my $w (@group_params, @plot_parameters) {
    $this->set_widget_state($w, $enabled);
  };

  ## no data specified, possibly no data imported
  if (not $group) {
    foreach my $w (@bkg_parameters, @fft_parameters, @bft_parameters) {
      $this->set_widget_state($w, $enabled);
    };

  ## XANES data
  } elsif ($group->datatype eq 'xanes') {
    foreach my $w (@bkg_parameters) {
      $this->set_widget_state($w, $enabled);
    };
    foreach my $w (@fft_parameters, @bft_parameters) {
      $this->set_widget_state($w, 0);
    };

  ## chi(k) data
  } elsif ($group->datatype eq 'chi') {
    foreach my $w (@bkg_parameters) {
      $this->set_widget_state($w, 0);
    };
    foreach my $w (@fft_parameters, @bft_parameters) {
      $this->set_widget_state($w, $enabled);
    };
  } else {
    foreach my $w (@bkg_parameters, @fft_parameters, @bft_parameters) {
      $this->set_widget_state($w, $enabled);
    };
  };

  foreach my $w (qw(bkg_algorithm bkg_stan)) {
    $this->set_widget_state($w, 0);
  };
  return $this;
};

sub set_widget_state {
  my ($this, $widget, $bool) = @_;
  $this->{$widget}         ->Enable($bool) if exists ($this->{$widget});
  $this->{$widget.'_label'}->Enable($bool) if exists ($this->{$widget.'_label'});
  $this->{$widget.'_pluck'}->Enable($bool) if exists ($this->{$widget.'_pluck'});
  return $bool;
};

sub push_values {
  my ($this, $data) = @_;
  foreach my $w (@group_params, @plot_parameters, @bkg_parameters, @fft_parameters, @bft_parameters) {
    next if ($w =~ m{(?:label|pluck)\z});
    #print($w.$/), 
    next if not $data->meta->find_attribute_by_name($w);
    $this->{$w}->SetValue($data->$w) if (ref($this->{$w}) =~ m{SpinCtrl});
    $this->{$w}->SetValue($data->$w) if (ref($this->{$w}) =~ m{TextCtrl});
    $this->{$w}->SetValue($data->$w) if (ref($this->{$w}) =~ m{CheckBox});
  };
  $this->{file}->SetValue($data->prjrecord) if ($this->{file}->GetValue eq '@&^^null^^&@');
  $this->{bkg_z}      -> SetValue(sprintf "%-2d: %s", get_Z($data->bkg_z), get_name($data->bkg_z));
  $this->{fft_edge}   -> SetValue(ucfirst($data->fft_edge));
  $this->{bkg_clamp1} -> SetStringSelection($data->number2clamp($data->bkg_clamp1));
  $this->{bkg_clamp2} -> SetStringSelection($data->number2clamp($data->bkg_clamp2));
  $this->{fft_kwindow}-> SetStringSelection($this->window_name($data->fft_kwindow));
  #$this->{bft_rwindow}-> SetStringSelection($this->window_name($data->bft_rwindow));
  my $nnorm = $data->bkg_nnorm;
  $this->{'bkg_nnorm_'.$nnorm}->SetValue(1);
  ## standard
  my $truncated_name = $data->name;
  my $n = length($truncated_name);
  if ($n > 40) {
    $truncated_name = substr($data->name, 0, 17) . '...' . substr($data->name, $n-17);
  };
  $this->{groupbox}->SetLabel('Current group:  '.$truncated_name);
  return $data;
};

## test that values are not being set unnecessarily.  it is faster to
## set a Moose attribute than to process data with Ifeffit!
sub pull_values {
  my ($this, $data) = @_;
  foreach my $w (@group_params, @plot_parameters, @bkg_parameters, @fft_parameters, @bft_parameters) {
    next if ($w =~ m{(?:label|pluck)\z});
    next if not $data->meta->find_attribute_by_name($w);
    next if ($w eq 'file');
    $data->$w($this->{$w}->GetValue) if ((ref($this->{$w}) =~ m{SpinCtrl}) and ($this->{$w}->GetValue != $data->$w));
    $data->$w($this->{$w}->GetValue) if ((ref($this->{$w}) =~ m{TextCtrl}) and ($this->{$w}->GetValue != $data->$w));
    $data->$w($this->{$w}->GetValue) if ((ref($this->{$w}) =~ m{CheckBox}) and ($this->{$w}->GetValue != $data->$w));
  };
  my $string = $this->{bkg_z}->GetValue;
  my @list = split(/:/, $string);
  $data->bkg_z(get_symbol($list[0]));
  $data->fft_edge(lc($this->{fft_edge} -> GetValue));
  $data->bkg_clamp1($data->co->default("clamp", $this->{bkg_clamp1}->GetStringSelection));
  $data->bkg_clamp2($data->co->default("clamp", $this->{bkg_clamp2}->GetStringSelection));
  $data->fft_kwindow(lc($this->{fft_kwindow} -> GetStringSelection));
  $data->bft_rwindow(lc($this->{fft_kwindow} -> GetStringSelection));

  my $nnorm = ($this->{'bkg_nnorm_1'}->GetValue) ? 1
            : ($this->{'bkg_nnorm_2'}->GetValue) ? 2
            : ($this->{'bkg_nnorm_3'}->GetValue) ? 3
	    :                                      3;
  $data->bkg_nnorm($nnorm);
  ## standard
  return $data;
};

sub zero_values {
  my ($this) = @_;
  foreach my $w (@group_params, @plot_parameters, @bkg_parameters, @fft_parameters, @bft_parameters) {
    next if ($w =~ m{(?:label|pluck)\z});
    next if ($w eq 'file');
    $this->{$w}->SetValue(0)   if (ref($this->{$w}) =~ m{SpinCtrl});
    $this->{$w}->SetValue(q{}) if (ref($this->{$w}) =~ m{TextCtrl});
    $this->{$w}->SetValue(0)   if (ref($this->{$w}) =~ m{CheckBox});
  };
  $this->{bkg_z}         -> SetValue(sprintf "%-2d: %s", 1, 'Hydrogen');
  $this->{fft_edge}      -> SetValue('K');
  $this->{file}          -> SetValue(q{});
  $this->{bkg_clamp1}    -> SetSelection(0);
  $this->{bkg_clamp2}    -> SetSelection(0);
  $this->{fft_kwindow}   -> SetSelection(1);
  $this->{'bkg_nnorm_1'} -> SetValue(0);
  $this->{'bkg_nnorm_2'} -> SetValue(0);
  $this->{'bkg_nnorm_3'} -> SetValue(1);
  $this->{groupbox}      -> SetLabel('Current group');
};

sub window_name {
  my ($this, $string) = @_;
  return 'Kaiser-Bessel' if (lc($string) eq 'kaiser-bessel');
  return ucfirst(lc($string));
};


1;
