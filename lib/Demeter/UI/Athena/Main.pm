package Demeter::UI::Athena::Main;

use Wx qw( :everything );
use base 'Wx::Panel';
use Wx::Event qw(EVT_LIST_ITEM_ACTIVATED EVT_LIST_ITEM_SELECTED EVT_BUTTON EVT_KEY_DOWN
		 EVT_TEXT EVT_CHOICE EVT_COMBOBOX EVT_CHECKBOX EVT_RADIOBUTTON
		 EVT_RIGHT_DOWN EVT_MENU);
use Wx::Perl::TextValidator;

use Chemistry::Elements qw(get_name get_Z get_symbol);
use File::Basename;
use File::Spec;
use List::MoreUtils qw(none any);
use Scalar::Util qw(looks_like_number);
use Readonly;

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
  $this->{app} = $app;

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
  $this->{sizer}    -> Add($groupboxsizer, 0, wxBOTTOM|wxGROW, 5);
  $this->{groupbox}  = $groupbox;

  EVT_RIGHT_DOWN($groupbox, sub{ContextMenu(@_, $app, 'group')});
  EVT_MENU($groupbox, -1, sub{ $this->DoContextMenu(@_, $app, 'group') });

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
  foreach my $x (qw(bkg_eshift importance)) {
    EVT_TEXT($this, $this->{$x}, sub{OnParameter(@_, $app, $x)});
    EVT_RIGHT_DOWN($this->{$x.'_label'}, sub{ContextMenu(@_, $app, $x)});
    EVT_MENU($this->{$x.'_label'}, -1, sub{ $this->DoContextMenu(@_, $app, $x)    });
  };
  EVT_COMBOBOX($this, $this->{bkg_z},    sub{OnAbsorber(@_, $app)});
  EVT_COMBOBOX($this, $this->{fft_edge}, sub{OnEdge(@_, $app)});
  foreach my $x (qw(bkg_z fft_edge)) {
    EVT_RIGHT_DOWN($this->{$x.'_label'}, sub{ContextMenu(@_, $app, $x)});
    EVT_MENU($this->{$x.'_label'}, -1, sub{ $this->DoContextMenu(@_, $app, $x)    });
  };

  $this->{$_} -> SetValidator( Wx::Perl::TextValidator->new( qr([-0-9.]) ) )
    foreach (qw(bkg_eshift importance));

  $groupboxsizer -> Add($gbs, 0, wxALL, 5);
  return $this;
};


sub bkg {
  my ($this, $app) = @_;

  my $backgroundbox       = Wx::StaticBox->new($this, -1, 'Background removal parameters', wxDefaultPosition, wxDefaultSize);
  my $backgroundboxsizer  = Wx::StaticBoxSizer->new( $backgroundbox, wxVERTICAL );
  $backgroundbox         -> SetFont( Wx::Font->new( $box_font_size, wxDEFAULT, wxNORMAL, wxBOLD, 0, "" ) );
  $this->{sizer}         -> Add($backgroundboxsizer, 0, wxBOTOM|wxGROW, 5);
  $this->{backgroundbox}  = $backgroundbox;

  EVT_RIGHT_DOWN($backgroundbox, sub{ContextMenu(@_, $app, 'bkg')});
  EVT_MENU($backgroundbox, -1, sub{ $this->DoContextMenu(@_, $app, 'bkg') });

  $gbs = Wx::GridBagSizer->new( 5, 5 );

  ## E0, Rbkg, flatten
  $this->{bkg_e0_label}   = Wx::StaticText   -> new($this, -1, "E0");
  $this->{bkg_e0}         = Wx::TextCtrl     -> new($this, -1, q{}, wxDefaultPosition, $tcsize);
  $this->{bkg_e0_pluck}   = Wx::BitmapButton -> new($this, -1, $bullseye);
  $this->{bkg_rbkg_label} = Wx::StaticText   -> new($this, -1, "Rbkg");
  $this->{bkg_rbkg}       = Wx::TextCtrl     -> new($this, -1, q{}, wxDefaultPosition, $tcsize);
  $this->{bkg_rbkg_pluck} = Wx::BitmapButton -> new($this, -1, $bullseye);
  $this->{bkg_flatten}    = Wx::CheckBox     -> new($this, -1, q{Flatten normalized data});
  $gbs -> Add($this->{bkg_e0_label},   Wx::GBPosition->new(0,0));
  $gbs -> Add($this->{bkg_e0},         Wx::GBPosition->new(0,1));
  $gbs -> Add($this->{bkg_e0_pluck},   Wx::GBPosition->new(0,2));
  $gbs -> Add($this->{bkg_rbkg_label}, Wx::GBPosition->new(0,3));
  $gbs -> Add($this->{bkg_rbkg},       Wx::GBPosition->new(0,4));
  $gbs -> Add($this->{bkg_rbkg_pluck}, Wx::GBPosition->new(0,5));
  $gbs -> Add($this->{bkg_flatten},    Wx::GBPosition->new(0,6), Wx::GBSpan->new(1,3));
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
  $gbs -> Add($this->{bkg_nnorm_label},     Wx::GBPosition->new(1,5), Wx::GBSpan->new(1,2));
  $gbs -> Add($this->{bkg_nnorm_1},         Wx::GBPosition->new(1,7));
  $gbs -> Add($this->{bkg_nnorm_2},         Wx::GBPosition->new(1,8));
  $gbs -> Add($this->{bkg_nnorm_3},         Wx::GBPosition->new(1,9));
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
  EVT_TEXT($this, $this->{bkg_spl1}, sub{OnSpl(@_, $app, 'bkg_spl1')});
  EVT_TEXT($this, $this->{bkg_spl2}, sub{OnSpl(@_, $app, 'bkg_spl2')});

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
  EVT_TEXT($this, $this->{bkg_spl1e}, sub{OnSpl(@_, $app, 'bkg_spl1e')});
  EVT_TEXT($this, $this->{bkg_spl2e}, sub{OnSpl(@_, $app, 'bkg_spl2e')});

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
  foreach my $x (qw(bkg_e0 bkg_rbkg bkg_kw bkg_pre1 bkg_pre2 bkg_nor1 bkg_nor2 bkg_step)) {
    EVT_TEXT($this, $this->{$x}, sub{OnParameter(@_, $app, $x)});
    next if (any {$x eq $_} qw(bkg_pre2 bkg_nor2 bkg_spl2 bkg_spl2e));
    EVT_RIGHT_DOWN($this->{$x.'_label'}, sub{ContextMenu(@_, $app, $x)});
    EVT_MENU($this->{$x.'_label'}, -1, sub{ $this->DoContextMenu(@_, $app, $x) });
  };
  foreach my $x (qw(bkg_spl1 bkg_spl1e)) {
    EVT_RIGHT_DOWN($this->{$x.'_label'}, sub{ContextMenu(@_, $app, $x)});
    EVT_MENU($this->{$x.'_label'}, -1, sub{ $this->DoContextMenu(@_, $app, $x) });
  };
  foreach my $x (qw(bkg_clamp1 bkg_clamp2 bkg_algorithm)) {
    EVT_CHOICE($this, $this->{$x}, sub{OnParameter(@_, $app, $x)});
    EVT_RIGHT_DOWN($this->{$x.'_label'}, sub{ContextMenu(@_, $app, $x)});
    EVT_MENU($this->{$x.'_label'}, -1, sub{ $this->DoContextMenu(@_, $app, $x) });
  };
  foreach my $x (qw(bkg_e0 bkg_rbkg bkg_pre1 bkg_pre2 bkg_nor1 bkg_nor2 bkg_spl1 bkg_spl2 bkg_spl1e bkg_spl2e)) {
    EVT_BUTTON($this, $this->{$x.'_pluck'}, sub{Pluck(@_, $app, $x)})
  };
  foreach my $x (qw(bkg_flatten bkg_fixstep)) {
    EVT_CHECKBOX($this, $this->{$x}, sub{OnParameter(@_, $app, $x)});
    #EVT_RIGHT_DOWN($this->{$x.'_label'}, sub{ContextMenu(@_, $app, $x)});
    #EVT_MENU($this->{$x.'_label'}, -1, sub{ $this->DoContextMenu(@_, $app, $x) });
  };
  foreach my $x (qw(bkg_nnorm_1 bkg_nnorm_2 bkg_nnorm_3)) {
    EVT_RADIOBUTTON($this, $this->{$x}, sub{OnParameter(@_, $app, $x)});
  };
  EVT_RIGHT_DOWN($this->{bkg_nnorm_label}, sub{ContextMenu(@_, $app, 'bkg_nnorm')});
  EVT_MENU($this->{bkg_nnorm_label}, -1, sub{ $this->DoContextMenu(@_, $app, 'bkg_nnorm') });


  return $this;
};


sub fft {
  my ($this, $app) = @_;

  my $fftbox       = Wx::StaticBox->new($this, -1, 'Forward Fourier transform parameters', wxDefaultPosition, wxDefaultSize);
  my $fftboxsizer  = Wx::StaticBoxSizer->new( $fftbox, wxHORIZONTAL );
  $fftbox         -> SetFont( Wx::Font->new( $box_font_size, wxDEFAULT, wxNORMAL, wxBOLD, 0, "" ) );
  $this->{sizer}  -> Add($fftboxsizer, 0, wxBOTTOM|wxGROW, 5);
  $this->{fftbox}  = $fftbox;

  EVT_RIGHT_DOWN($fftbox, sub{ContextMenu(@_, $app, 'fft')});
  EVT_MENU($fftbox, -1, sub{ $this->DoContextMenu(@_, $app, 'fft') });

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
  foreach my $x (qw(fft_kmin fft_kmax fft_dk fit_karb_value)) {
    EVT_TEXT($this, $this->{$x}, sub{OnParameter(@_, $app, $x)});
    next if ($x eq 'fft_kmax');
    EVT_RIGHT_DOWN($this->{$x.'_label'}, sub{ContextMenu(@_, $app, $x)});
    EVT_MENU($this->{$x.'_label'}, -1, sub{ $this->DoContextMenu(@_, $app, $x) });
  };
  EVT_CHOICE($this, $this->{fft_kwindow}, sub{OnParameter(@_, $app, 'fft_kwindow')});
  EVT_RIGHT_DOWN($this->{fft_kwindow_label}, sub{ContextMenu(@_, $app, 'fft_kwindow')});
  EVT_MENU($this->{fft_kwindow_label}, -1, sub{ $this->DoContextMenu(@_, $app, 'fft_kwindow') });
  foreach my $x (qw(fft_kmin fft_kmax)) {
    EVT_BUTTON($this, $this->{$x.'_pluck'}, sub{Pluck(@_, $app, $x)});
  };
  EVT_CHECKBOX($this, $this->{fft_pc}, sub{OnParameter(@_, $app, 'fft_pc')});

  return $this;
};

sub bft {
  my ($this, $app) = @_;

  my $bftbox       = Wx::StaticBox->new($this, -1, 'Backward Fourier transform parameters', wxDefaultPosition, wxDefaultSize);
  my $bftboxsizer  = Wx::StaticBoxSizer->new( $bftbox, wxHORIZONTAL );
  $bftbox         -> SetFont( Wx::Font->new( $box_font_size, wxDEFAULT, wxNORMAL, wxBOLD, 0, "" ) );
  $this->{sizer}  -> Add($bftboxsizer, 0, wxBOTTOM|wxGROW, 0);
  $this->{bftbox}  = $bftbox;

  EVT_RIGHT_DOWN($bftbox, sub{ContextMenu(@_, $app, 'bft')});
  EVT_MENU($bftbox, -1, sub{ $this->DoContextMenu(@_, $app, 'bft') });

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
  foreach my $x (qw(bft_rmin bft_rmax bft_dr)) {
    EVT_TEXT($this, $this->{$x}, sub{OnParameter(@_, $app, $x)});
    next if ($x eq 'bft_rmax');
    EVT_RIGHT_DOWN($this->{$x.'_label'}, sub{ContextMenu(@_, $app, $x)});
    EVT_MENU($this->{$x.'_label'}, -1, sub{ $this->DoContextMenu(@_, $app, $x) });
  };
  foreach my $x (qw(bft_rmin bft_rmax)) {
    EVT_BUTTON($this, $this->{$x.'_pluck'}, sub{Pluck(@_, $app, $x)});
  };
  EVT_CHECKBOX($this, $this->{bkg_flatten}, sub{OnParameter(@_, $app, 'bkg_flatten')});

  return $this;
};

sub plot {
  my ($this, $app) = @_;

  my $plotbox       = Wx::StaticBox->new($this, -1, 'Plotting parameters', wxDefaultPosition, wxDefaultSize);
  my $plotboxsizer  = Wx::StaticBoxSizer->new( $plotbox, wxHORIZONTAL );
  $plotbox         -> SetFont( Wx::Font->new( $box_font_size, wxDEFAULT, wxNORMAL, wxBOLD, 0, "" ) );
  $this->{sizer}   -> Add($plotboxsizer, 0, wxALL|wxGROW, 0);
  $this->{plotbox}  = $plotbox;

  EVT_RIGHT_DOWN($plotbox, sub{ContextMenu(@_, $app, 'plot')});
  EVT_MENU($plotbox, -1, sub{ $this->DoContextMenu(@_, $app, 'plot') });

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
  foreach my $x (qw(plot_multiplier y_offset)) {
    EVT_TEXT($this, $this->{$x}, sub{OnParameter(@_, $app, $x)});
    EVT_RIGHT_DOWN($this->{$x.'_label'}, sub{ContextMenu(@_, $app, $x)});
    EVT_MENU($this->{$x.'_label'}, -1, sub{ $this->DoContextMenu(@_, $app, $x) });
  };

  $plotboxsizer -> Add($pbox, 0, wxTOP|wxBOTTOM, 5);
  return $this;
};



sub mode {
  my ($this, $group, $enabled, $frozen) = @_;

  foreach my $w (@group_params, @plot_parameters, 'groupbox', 'plotbox') {
    $this->set_widget_state($w, $enabled);
  };

  ## no data specified, possibly no data imported
  if (not $group) {
    foreach my $w (@bkg_parameters, @fft_parameters, @bft_parameters, qw(backgroundbox fftbox bftbox)) {
      $this->set_widget_state($w, $enabled);
    };

  ## XANES data
  } elsif ($group->datatype eq 'xanes') {
    foreach my $w (@bkg_parameters, 'backgroundbox') {
      if ($w =~ m{spl|chain|bkg_(rbkg|kw)}) {
	$this->set_widget_state($w, 0);
      } else {
	$this->set_widget_state($w, $enabled);
      };
    };
    foreach my $w (@fft_parameters, @bft_parameters, qw(fftbox bftbox)) {
      $this->set_widget_state($w, 0);
    };

  ## chi(k) data
  } elsif ($group->datatype eq 'chi') {
    foreach my $w (@bkg_parameters, 'backgroundbox') {
      $this->set_widget_state($w, 0);
    };
    foreach my $w (@fft_parameters, @bft_parameters, qw(fftbox bftbox)) {
      $this->set_widget_state($w, $enabled);
    };
  } else {
    foreach my $w (@bkg_parameters, @fft_parameters, @bft_parameters, qw(backgroundbox fftbox bftbox)) {
      $this->set_widget_state($w, $enabled);
    };
  };

  foreach my $w (qw(bkg_algorithm bkg_stan fft_pc bkg_fixstep)) {
    $this->set_widget_state($w, 0);
  };

  my $is_merge = ($group) ? $group->is_merge : 0;
  $this->{app}->set_mergedplot($is_merge);

  if ($group and ($group->reference)) {
    $this->{bkg_eshift}-> SetBackgroundColour( Wx::Colour->new($group->co->default("athena", "tied")) );
  } else {
    $this->{bkg_eshift}-> SetBackgroundColour( wxNullColour );
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
    next if ($w =~ m{(?:label|pluck|file)\z});
    #print($w.$/), 
    next if not $data->meta->find_attribute_by_name($w);
    $this->{$w}->SetValue($data->$w) if (ref($this->{$w}) =~ m{SpinCtrl});
    $this->{$w}->SetValue($data->$w) if (ref($this->{$w}) =~ m{TextCtrl});
    $this->{$w}->SetValue($data->$w) if (ref($this->{$w}) =~ m{CheckBox});
  };
  $this->{file}->SetValue($data->source);
  $this->{file}->SetValue($data->prjrecord)  if ($this->{file}->GetValue eq '@&^^null^^&@');
  $this->{file}->SetValue($data->provenance) if ($data->is_merge);
  $this->{bkg_z}      -> SetValue(sprintf "%-2d: %s", get_Z($data->bkg_z), get_name($data->bkg_z));
  $this->{fft_edge}   -> SetValue(ucfirst($data->fft_edge));
  $this->{bkg_clamp1} -> SetStringSelection($data->number2clamp($data->bkg_clamp1));
  $this->{bkg_clamp2} -> SetStringSelection($data->number2clamp($data->bkg_clamp2));
  $this->{fft_kwindow}-> SetStringSelection($this->window_name($data->fft_kwindow));
  #$this->{bft_rwindow}-> SetStringSelection($this->window_name($data->bft_rwindow));
  my $nnorm = $data->bkg_nnorm;
  $this->{'bkg_nnorm_'.$nnorm}->SetValue(1);
  ## standard
  if ($data->reference) {
    $this->{bkg_eshift}-> SetBackgroundColour( Wx::Colour->new($data->co->default("athena", "tied")) );
  } else {
    $this->{bkg_eshift}-> SetBackgroundColour( wxNullColour );
  };
  my $truncated_name = $data->name;
  my $n = length($truncated_name);
  if ($n > 40) {
    $truncated_name = substr($data->name, 0, 17) . '...' . substr($data->name, $n-17);
  };
  $this->{groupbox}->SetLabel('Current group:  '.$truncated_name);
  return $data;
};

sub pull_values {
  1;
};
## test that values are not being set unnecessarily.  it is faster to
## set a Moose attribute than to process data with Ifeffit!
# sub pull_values {
#   my ($this, $data) = @_;
#   foreach my $w (@group_params, @plot_parameters, @bkg_parameters, @fft_parameters, @bft_parameters) {
#     next if ($w =~ m{(?:label|pluck)\z});
#     next if not $data->meta->find_attribute_by_name($w);
#     next if ($w eq 'file');
#     $data->$w($this->{$w}->GetValue) if ((ref($this->{$w}) =~ m{SpinCtrl}) and ($this->{$w}->GetValue != $data->$w));
#     $data->$w($this->{$w}->GetValue) if ((ref($this->{$w}) =~ m{TextCtrl}) and ($this->{$w}->GetValue != $data->$w));
#     $data->$w($this->{$w}->GetValue) if ((ref($this->{$w}) =~ m{CheckBox}) and ($this->{$w}->GetValue != $data->$w));
#   };
#   my $string = $this->{bkg_z}->GetValue;
#   my @list = split(/:/, $string);
#   $data->bkg_z(get_symbol($list[0]));
#   $data->fft_edge(lc($this->{fft_edge} -> GetValue));
#   $data->bkg_clamp1($data->co->default("clamp", $this->{bkg_clamp1}->GetStringSelection));
#   $data->bkg_clamp2($data->co->default("clamp", $this->{bkg_clamp2}->GetStringSelection));
#   $data->fft_kwindow(lc($this->{fft_kwindow} -> GetStringSelection));
#   $data->bft_rwindow(lc($this->{fft_kwindow} -> GetStringSelection));
#
#   my $nnorm = ($this->{'bkg_nnorm_1'}->GetValue) ? 1
#             : ($this->{'bkg_nnorm_2'}->GetValue) ? 2
#             : ($this->{'bkg_nnorm_3'}->GetValue) ? 3
# 	    :                                      3;
#   $data->bkg_nnorm($nnorm);
#   ## standard
#   return $data;
# };

sub zero_values {
  my ($this, $app) = @_;
  foreach my $w (@group_params, @plot_parameters, @bkg_parameters, @fft_parameters, @bft_parameters) {
    next if ($w =~ m{(?:label|pluck)\z});
    next if ($w eq 'file');
    next if ($w eq 'bkg_rbkg');
    $this->{$w}->SetValue(0)   if (ref($this->{$w}) =~ m{SpinCtrl});
    $this->{$w}->SetValue($Demeter::UI::Athena::demeter->dd->$w) if (ref($this->{$w}) =~ m{TextCtrl});
    $this->{$w}->SetValue(0)   if (ref($this->{$w}) =~ m{CheckBox});
  };
  $this->{bkg_z}         -> SetValue(sprintf "%-2d: %s", 1, 'Hydrogen');
  #$this->{bkg_rbkg}      -> SetValue(1);
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

sub OnParameter {
  my ($main, $event, $app, $which) = @_;
  return if $app->{selecting_data_group};
  my $data = $app->current_data;
  return if not $data;
  my $widget = $app->{main}->{Main}->{$which};
  ## TextCtrl SpinCtrl ComboBox CheckBox RadioButton all have GetValue
  my $value = (ref($widget) =~ m{Choice}) ? $data->co->default("clamp", $widget->GetStringSelection)
            : ($which eq 'bkg_z')         ? interpret_bkg_z($widget->GetValue)
            : ($which =~ m{nnorm})        ? interpret_nnorm($app)
	    :                               $widget->GetValue;
  $value = 0 if not looks_like_number($value);
  $data->$which($value) if not ($which =~ m{nnorm});
  $app->modified(1);
};

sub OnAbsorber {
  my ($main, $event, $app) = @_;
  my $abs = interpret_bkg_z($app->{main}->{Main}->{bkg_z}->GetValue);
  $app->current_data->bkg_z(get_symbol($abs));
};
sub OnEdge {
  my ($main, $event, $app) = @_;
  my $edge = $app->{main}->{Main}->{fft_edge}->GetValue;
  $app->current_data->fft_edge($edge);
};

sub interpret_bkg_z {
  my ($string) = @_;
  my @list = split(/\s*:\s*/, $string);
  my $z = get_symbol($list[1]);
  return $z;
};
sub interpret_nnorm {
  my ($app) = @_;
  my $nnorm = ($app->{main}->{Main}->{bkg_nnorm_1}->GetValue) ? 1
            : ($app->{main}->{Main}->{bkg_nnorm_2}->GetValue) ? 2
            : ($app->{main}->{Main}->{bkg_nnorm_3}->GetValue) ? 3
	    :                                                   3;
  $app->current_data->bkg_nnorm($nnorm);
  return $nnorm;
};

sub OnSpl {
  my ($main, $event, $app, $which) = @_;
  my $value = $event->GetString || 0;
  ## this slight of hand keeps this from regressing infinately as the
  ## connected k- and E-spline parameters are modified.  basically,
  ## this prevents the scond round of recurssion, thus stopping things
  if ($app->{constraining_spline_parameters}) {
    $app->{constraining_spline_parameters}=0;
    return;
  };
  $app->{constraining_spline_parameters}=1;
  return if not looks_like_number($value);
  my $data = $app->current_data;
  return if not defined $data;
  my ($other, $computed) = (q{}, 0);
  if ($which eq 'bkg_spl1') {
    ($other, $computed) = ('bkg_spl1e', $data->k2e($value));
  } elsif ($which eq 'bkg_spl2') {
    ($other, $computed) = ('bkg_spl2e', $data->k2e($value));
  } elsif ($which eq 'bkg_spl1e') {
    ($other, $computed) = ('bkg_spl1',  $data->e2k($value));
  } elsif ($which eq 'bkg_spl2e') {
    ($other, $computed) = ('bkg_spl2',  $data->e2k($value));
  };
  $app->{main}->{Main}->{$other}->SetValue($computed);
  ## this avoids triggering the modified flag when just clicking on
  ## the groups list
  return if $app->{selecting_data_group};
  $data->$which($value);
  $data->$other($computed);
  $app->modified(1);
};

sub Pluck {
  my ($frame, $event, $app, $which) = @_;

  my $on_screen = lc($app->{lastplot}->[0]);
  if ($on_screen eq 'quad') {
    $app->{main}->status("Cannot pluck from a quad plot.");
    return;
  };
  if (($on_screen eq 'r') and ($which !~ m{rmin|rmax|rbkg})) {
    $app->{main}->status("Cannot pluck for $which from an R plot.");
    return;
  };
  if (($on_screen ne 'r') and ($which =~ m{bft|rbkg})) {
    my $type = ($on_screen eq 'e') ? 'n energy' : " $on_screen";
    $app->{main}->status("Cannot pluck for $which from a$type plot.");
    return;
  };

  my ($ok, $x, $y) = $app->cursor;
  return if not $ok;
  my $plucked = -999;

  $on_screen = 'k' if ($on_screen eq 'q');
  my $data = $app->current_data;
  if ($on_screen eq 'r') {
    $plucked = $x;
  } elsif (($on_screen eq 'e') and ($which eq "bkg_e0")) {
    $plucked = $x;
  } elsif (($on_screen eq 'k') and ($which eq "bkg_e0")) {
    $plucked = $data->k2e($x, 'absolute');
  } elsif (($on_screen eq 'e') and ($which =~ m{fft})) {
    $plucked = $data->e2k($x, 'absolute');
  } elsif (($on_screen eq 'k') and ($which =~ m{fft})) {
    $plucked = $x;
  } elsif (($on_screen eq 'e') and ($which =~ m{bkg})) {
    $plucked = $x - $data->bkg_e0;
  } elsif (($on_screen eq 'k') and ($which =~ m{bkg})) {
    $plucked = $data->k2e($x, 'relative');
  };
  $plucked = sprintf("%.3f", $plucked);
  $app->{main}->{Main}->{$which}->SetValue($plucked);

  $app->{main}->status("Plucked $plucked for $which");
  undef $busy;
};

Readonly my $SET_ALL	        => Wx::NewId();
Readonly my $SET_MARKED	        => Wx::NewId();
Readonly my $KMAX_RECOMMENDED   => Wx::NewId();
Readonly my $IDENTIFY_REFERENCE => Wx::NewId();
Readonly my $EXPLAIN_ESHIFT     => Wx::NewId();
Readonly my $ALL_TO_1           => Wx::NewId();
Readonly my $MARKED_TO_1        => Wx::NewId();


sub ContextMenu {
  my ($label, $event, $app, $which) = @_;
  my $menu  = Wx::Menu->new(q{});
  return if ($app->{main}->{list}->GetCount < 1);

  my ($this) = (any {$which eq $_} qw(group bkg fft bft plot)) ? 'these values' : 'this value';
  my $text = $label->GetLabel;
  return if not $label->IsEnabled;
  ($text = "Low spline clamp")  if ($text =~ m{low\z});
  ($text = "High spline clamp") if ($text eq 'high');
  ($text = "group parameters")  if ($text =~ m{group});
  $menu->Append($SET_ALL,    "Set all groups to $this of $text");
  $menu->Append($SET_MARKED, "Set marked groups to $this of $text");
  if ($text eq 'k-range') {
    $menu->AppendSeparator;
    $menu->Append($KMAX_RECOMMENDED, "Set kmax to Ifeffit's suggestion");
  } elsif ($which eq 'importance') {
    $menu->AppendSeparator;
    $menu->Append($ALL_TO_1,    "Set importance to 1 for all groups");
    $menu->Append($MARKED_TO_1, "Set importance to 1 for marked groups");
  } elsif ($which eq 'bkg_eshift') {
    $menu->AppendSeparator;
    $menu->Append($IDENTIFY_REFERENCE, "Identify this groups reference channel");
    $menu->Append($EXPLAIN_ESHIFT,     "Explain energy shift");
  } elsif ($which eq 'bkg_e0') {
    $menu->AppendSeparator;
  };

  ## set to session default
  ## set as session default
  ## set to standard
  ## bkg_e0: various set e0 options, tie e and k values to e0
  ## bkg_eshift: identify reference, explain eshift
  ## importance: all to 1, marked to 1

  my $here = ($event =~ m{Mouse}) ? $event->GetPosition : Wx::Point->new(10,10);
  $label -> PopupMenu($menu, $here);
};

sub DoContextMenu {
  #print join("|", @_), $/;
  my ($main, $label, $event, $app, $which) = @_;
  my $id = $event->GetId;
  my $data = $app->current_data;
  my @list = ($which);
  push(@list, 'fft_kmax')  if ($which eq 'fft_kmin');
  push(@list, 'bft_rmax')  if ($which eq 'bft_rmin');
  push(@list, 'bkg_pre2')  if ($which eq 'bkg_pre1');
  push(@list, 'bkg_nor2')  if ($which eq 'bkg_nor1');
  push(@list, 'bkg_spl2')  if ($which eq 'bkg_spl1');
  push(@list, 'bkg_spl2e') if ($which eq 'bkg_spl1e');
 SWITCH: {
    ($id == $SET_ALL) and do {
      $main->constrain($app, \@list, 'all');
      last SWITCH;
    };
    ($id == $SET_MARKED) and do {
      $main->constrain($app, \@list, 'marked');
      last SWITCH;
    };
    ($id == $KMAX_RECOMMENDED) and do {
      $data->_update('bft');
      $data->fft_kmax($data->recommended_kmax);
      $app->{main}->{Main}->{fft_kmax}->SetValue($data->fft_kmax);
      last SWITCH;
    };
  };
};


Readonly my @all_group => (qw(bkg_z fft_edge bkg_eshift importance));
Readonly my @all_bkg   => (qw(bkg_e0 bkg_rbkg bkg_flatten bkg_kw
			      bkg_fixstep bkg_nnorm bkg_pre1 bkg_pre2
			      bkg_nor1 bkg_nor2 bkg_spl1 bkg_spl2
			      bkg_spl1e bkg_spl2e bkg_stan bkg_clamp1
			      bkg_clamp2)); # bkg_algorithm bkg_step
Readonly my @all_fft    => (qw(fft_kmin fft_kmax fft_dk fft_kwindow fit_karb_value fft_pc));
Readonly my @all_bft    => (qw(bft_rmin bft_rmax bft_dr bft_rwindow));
Readonly my @all_plot   => (qw(plot_multiplier y_offset));

sub constrain {
  my ($main, $app, $which, $how) = @_;
  my $data = $app->current_data;
  my @params = ($which->[0] eq 'all')  ? (@all_group, @all_bkg, @all_fft, @all_bft, @all_plot)
             : ($which->[0] eq 'file') ?  @all_group
             : ($which->[0] eq 'bkg')  ?  @all_bkg
             : ($which->[0] eq 'fft')  ?  @all_fft
             : ($which->[0] eq 'bft')  ?  @all_bft
             : ($which->[0] eq 'plot') ?  @all_plot
	     :                            @$which;
  foreach my $i (0 .. $app->{main}->{list}->GetCount-1) {
    next if (($how eq 'marked') and (not $app->{main}->{list}->IsChecked($i)));
    my $this = $app->{main}->{list}->GetClientData($i);
    next if ($data eq $this);
    next if $this->frozen;
    foreach my $p (@params) {
      #print join("|", '>>>', $data->name, $this->name, $p, $this->$p), $/;
      $this->$p($data->$p);
      #print join("|", '<<<', $data->name, $this->name, $p, $this->$p), $/;
    };
  };
  $app->modified(1);
  $app->{main}->status("Set parameters for $how groups");
};

1;
