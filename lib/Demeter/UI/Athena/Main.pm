package Demeter::UI::Athena::Main;

use strict;
use warnings;

use Wx qw( :everything );
use base 'Wx::Panel';
use Wx::Event qw(EVT_LIST_ITEM_ACTIVATED EVT_LIST_ITEM_SELECTED EVT_BUTTON EVT_KEY_DOWN
		 EVT_TEXT EVT_CHOICE EVT_COMBOBOX EVT_CHECKBOX EVT_RADIOBUTTON
		 EVT_RIGHT_DOWN EVT_MENU EVT_TEXT_ENTER EVT_SPIN
		 EVT_ENTER_WINDOW EVT_LEAVE_WINDOW);
use Wx::Perl::TextValidator;

use Chemistry::Elements qw(get_name get_Z get_symbol);
use File::Basename;
use File::Spec;
use List::Util qw(max);
use List::MoreUtils qw(none any);
use Scalar::Util qw(looks_like_number);
use Demeter::Constants qw($NUMBER $EPSILON2);
use Const::Fast;
use DateTime;
use Statistics::Descriptive;

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

  #my $groupbox       = Wx::StaticBox->new($this, -1, 'Current group', wxDefaultPosition, wxDefaultSize);
  #my $groupboxsizer  = Wx::StaticBoxSizer->new( $groupbox, wxVERTICAL );
  #$groupbox         -> SetFont( Wx::Font->new( $box_font_size, wxDEFAULT, wxNORMAL, wxBOLD, 0, "" ) );
  #$this->{sizer}    -> Add($groupboxsizer, 0, wxBOTTOM|wxGROW, 5);
  #$this->{groupbox}  = $groupbox;

  my $groupboxsizer  = Wx::BoxSizer->new( wxVERTICAL );
  $groupboxsizer -> Add(Wx::StaticLine->new($this, -1, wxDefaultPosition, wxDefaultSize, wxLI_HORIZONTAL), 0, wxGROW|wxBOTTOM, 2);
  $this->{sizer}  -> Add($groupboxsizer, 0, wxTOP|wxBOTTOM|wxGROW, 5);

  my $hbox = Wx::BoxSizer->new( wxHORIZONTAL );
  $groupboxsizer -> Add($hbox, 0, wxGROW|wxBOTTOM, 0);

  $this->{group_group_label} = Wx::StaticText->new($this, -1, 'Current group');
  $this->{group_group_label} -> SetFont( Wx::Font->new( $box_font_size, wxDEFAULT, wxNORMAL, wxBOLD, 0, "" ) );
  $hbox -> Add($this->{group_group_label}, 0, wxBOTTOM|wxALIGN_LEFT, 5);
  $this->{freeze} = Wx::CheckBox -> new($this, -1, q{Freeze});
  $hbox -> Add(1,1,1);
  $hbox -> Add($this->{freeze}, 0, wxBOTTOM, 5);
  EVT_CHECKBOX($this, $this->{freeze}, sub{$app->quench('toggle')});

  EVT_RIGHT_DOWN($this->{group_group_label}, sub{ContextMenu(@_, $app, 'currentgroup')});
  EVT_MENU($this->{group_group_label}, -1, sub{ $this->DoContextMenu(@_, $app, 'currentgroup') });

  my $gbs = Wx::GridBagSizer->new( 5, 5 );

  $this->{file_label} = Wx::StaticText -> new($this, -1, "File");
  $this->{file}       = Wx::TextCtrl   -> new($this, -1, q{}, wxDefaultPosition, [450,-1], wxTE_READONLY);
  $gbs -> Add($this->{file_label}, Wx::GBPosition->new(0,0));
  $gbs -> Add($this->{file},       Wx::GBPosition->new(0,1), Wx::GBSpan->new(1,7), 1);
  EVT_ENTER_WINDOW($this->{file}, sub{my $text = $this->show_source;
				      $::app->{main}->GetStatusBar->PushStatusText($text);
				      $_[1]->Skip});
  EVT_LEAVE_WINDOW($this->{file}, sub{my $text = $this->show_source;
				      $::app->{main}->GetStatusBar->PopStatusText if ($::app->{main}->GetStatusBar->GetStatusText eq $text);
				      $_[1]->Skip});

  my @elements = map {sprintf "%-2d: %s", $_, get_name($_)} (1 .. 96);
  $this->{bkg_z_label}      = Wx::StaticText -> new($this, -1, "Element", wxDefaultPosition, [50,-1]);
  $this->{bkg_z}            = Wx::ComboBox   -> new($this, -1, 'Hydrogen', wxDefaultPosition, [130,-1], \@elements, wxCB_READONLY );
  $this->{fft_edge_label}   = Wx::StaticText -> new($this, -1, "Edge");
  $this->{fft_edge}         = Wx::ComboBox   -> new($this, -1, 'K', wxDefaultPosition, [50,-1],
						    [qw(K L1 L2 L3 M1 M2 M3 M4 M5)], wxCB_READONLY);
  $this->{bkg_eshift_label} = Wx::StaticText -> new($this, -1, "Energy shift");
  $this->{bkg_eshift}       = Wx::TextCtrl   -> new($this, -1, q{}, wxDefaultPosition, [40,-1] );
  $this->{importance_label} = Wx::StaticText -> new($this, -1, "Importance");
  $this->{importance}       = Wx::TextCtrl   -> new($this, -1, q{}, wxDefaultPosition, [40,-1] );
  $gbs -> Add($this->{bkg_z_label},      Wx::GBPosition->new(1,0));
  $gbs -> Add($this->{bkg_z},            Wx::GBPosition->new(1,1));
  $gbs -> Add($this->{fft_edge_label},   Wx::GBPosition->new(1,2));
  $gbs -> Add($this->{fft_edge},         Wx::GBPosition->new(1,3));
  $gbs -> Add($this->{bkg_eshift_label}, Wx::GBPosition->new(1,4));
  $gbs -> Add($this->{bkg_eshift},       Wx::GBPosition->new(1,5));
  $gbs -> Add($this->{importance_label}, Wx::GBPosition->new(1,6));
  $gbs -> Add($this->{importance},       Wx::GBPosition->new(1,7));

  push @group_params, qw(file bkg_z fft_edge bkg_eshift importance freeze);
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

  $groupboxsizer -> Add($gbs, 0, wxLEFT, 5);
  return $this;
};


sub bkg {
  my ($this, $app) = @_;

  #my $backgroundbox       = Wx::StaticBox->new($this, -1, 'Background removal parameters', wxDefaultPosition, wxDefaultSize);
  #my $backgroundboxsizer  = Wx::StaticBoxSizer->new( $backgroundbox, wxVERTICAL );
  #$backgroundbox         -> SetFont( Wx::Font->new( $box_font_size, wxDEFAULT, wxNORMAL, wxBOLD, 0, "" ) );
  #$this->{sizer}         -> Add($backgroundboxsizer, 0, wxBOTTOM|wxGROW, 5);
  #$this->{backgroundbox}  = $backgroundbox;

  my $backgroundboxsizer  = Wx::BoxSizer->new( wxVERTICAL );
  $backgroundboxsizer -> Add(Wx::StaticLine->new($this, -1, wxDefaultPosition, wxDefaultSize, wxLI_HORIZONTAL), 0, wxGROW|wxBOTTOM, 2);
  $this->{sizer}  -> Add($backgroundboxsizer, 0, wxTOP|wxBOTTOM|wxGROW, 5);
  $this->{background_group_label} = Wx::StaticText->new($this, -1, 'Background removal and normalization parameters');
  $this->{background_group_label} -> SetFont( Wx::Font->new( $box_font_size, wxDEFAULT, wxNORMAL, wxBOLD, 0, "" ) );
  $backgroundboxsizer -> Add($this->{background_group_label}, 0, wxBOTTOM|wxALIGN_LEFT, 5);

  EVT_RIGHT_DOWN($this->{background_group_label}, sub{ContextMenu(@_, $app, 'bkg')});
  EVT_MENU($this->{background_group_label}, -1, sub{ $this->DoContextMenu(@_, $app, 'bkg') });

  my $gbs = Wx::GridBagSizer->new( 5, 5 );

  ## E0, Rbkg, flatten
  $this->{bkg_e0_label}   = Wx::StaticText   -> new($this, -1, "E0");
  $this->{bkg_e0}         = Wx::TextCtrl     -> new($this, -1, q{}, wxDefaultPosition, [80,-1], wxTE_PROCESS_ENTER);
  $this->{bkg_e0_pluck}   = Wx::BitmapButton -> new($this, -1, $bullseye);
  $this->{bkg_rbkg_label} = Wx::StaticText   -> new($this, -1, "Rbkg");
  $this->{bkg_rbkg}       = Wx::TextCtrl     -> new($this, -1, q{}, wxDefaultPosition, $tcsize, wxTE_PROCESS_ENTER);
  #$this->{bkg_rbkg_pluck} = Wx::BitmapButton -> new($this, -1, $bullseye);
  $this->{bkg_rbkg_pluck} = Wx::SpinButton -> new($this, -1, wxDefaultPosition, wxDefaultSize, wxSP_HORIZONTAL|wxSP_WRAP);
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
  EVT_SPIN($this, $this->{bkg_rbkg_pluck}, sub{spin_rbkg(@_)});
  $this->{bkg_rbkg_pluck}->SetRange(-1,1);
  $this->{bkg_rbkg_pluck}->SetValue(0);
  $this->{last_spin} = DateTime->now(time_zone => 'floating');  # see comment in spin_rbkg
  $app->mouseover($this->{bkg_rbkg_pluck}, "Increment or deincrement Rbkg and plot immediately.  (You must wait 2 seconds between clicks!)");

  ## kweight, step, fix step
  $this->{bkg_kw_label}   = Wx::StaticText -> new($this, -1, "k-weight");
  $this->{bkg_kw}         = Wx::SpinCtrl   -> new($this, -1, q{}, wxDefaultPosition, $tcsize, wxTE_PROCESS_ENTER|wxSP_ARROW_KEYS, 0, 3);
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

  $backgroundboxsizer -> Add($gbs, 0, wxLEFT, 5);

  $gbs = Wx::GridBagSizer->new( 5, 5 );

  ## pre edge line
  $this->{bkg_pre1_label} = Wx::StaticText   -> new($this, -1, "Pre-edge range");
  $this->{bkg_pre1}       = Wx::TextCtrl     -> new($this, -1, q{}, wxDefaultPosition, $tcsize, wxTE_PROCESS_ENTER);
  $this->{bkg_pre2_label} = Wx::StaticText   -> new($this, -1, "to");
  $this->{bkg_pre2}       = Wx::TextCtrl     -> new($this, -1, q{}, wxDefaultPosition, $tcsize, wxTE_PROCESS_ENTER);
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
  $this->{bkg_nor1}       = Wx::TextCtrl     -> new($this, -1, q{}, wxDefaultPosition, $tcsize, wxTE_PROCESS_ENTER);
  $this->{bkg_nor2_label} = Wx::StaticText   -> new($this, -1, "to");
  $this->{bkg_nor2}       = Wx::TextCtrl     -> new($this, -1, q{}, wxDefaultPosition, $tcsize, wxTE_PROCESS_ENTER);
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
  $this->{bkg_fixstep}    = Wx::CheckBox   -> new($this, -1, q{fix});
  $gbs -> Add($this->{bkg_step_label}, Wx::GBPosition->new(0,7));
  $gbs -> Add($this->{bkg_step},       Wx::GBPosition->new(0,8));
  $gbs -> Add($this->{bkg_fixstep},    Wx::GBPosition->new(0,9));

  my $clampbox       = Wx::StaticBox->new($this, -1, 'Spline clamps', wxDefaultPosition, wxDefaultSize);
  my $clampboxsizer  = Wx::StaticBoxSizer->new( $clampbox, wxVERTICAL );
  $clampbox         -> SetFont( Wx::Font->new( Wx::SystemSettings::GetFont(wxSYS_DEFAULT_GUI_FONT)->GetPointSize, wxDEFAULT, wxNORMAL, wxNORMAL, 0, "" ) );
  $gbs -> Add($clampboxsizer, Wx::GBPosition->new(1,7), Wx::GBSpan->new(3,3));
  my $cgbs = Wx::GridBagSizer->new( 5, 5 );
  $clampboxsizer -> Add($cgbs, 0, wxALL, 5);
  $this->{clampbox}  = $clampbox;

  my $clamps = [qw(None Slight Weak Medium Strong Rigid)];
  #$this->{clamp_label}      = Wx::StaticText -> new($this, -1, "Spline clamps");
  $this->{bkg_clamp1_label} = Wx::StaticText -> new($this, -1, "low");
  $this->{bkg_clamp1}       = Wx::Choice     -> new($this, -1, wxDefaultPosition, wxDefaultSize, $clamps);
  $this->{bkg_clamp2_label} = Wx::StaticText -> new($this, -1, "high");
  $this->{bkg_clamp2}       = Wx::Choice     -> new($this, -1, wxDefaultPosition, wxDefaultSize, $clamps);
  $this->{bkg_clamp1} -> SetSelection(0);
  $this->{bkg_clamp2} -> SetSelection(0);
  #$gbs -> Add($this->{clamp_label}, Wx::GBPosition->new(1,7), Wx::GBSpan->new(1,2));
  $cgbs -> Add($this->{bkg_clamp1_label}, Wx::GBPosition->new(0,0));
  $cgbs -> Add($this->{bkg_clamp1},       Wx::GBPosition->new(0,1));
  $cgbs -> Add($this->{bkg_clamp2_label}, Wx::GBPosition->new(1,0));
  $cgbs -> Add($this->{bkg_clamp2},       Wx::GBPosition->new(1,1));

  ## spline range in k
  $this->{bkg_spl1_label} = Wx::StaticText   -> new($this, -1, "Spline range in k");
  $this->{bkg_spl1}       = Wx::TextCtrl     -> new($this, -1, q{}, wxDefaultPosition, $tcsize, wxTE_PROCESS_ENTER);
  $this->{bkg_spl2_label} = Wx::StaticText   -> new($this, -1, "to");
  $this->{bkg_spl2}       = Wx::TextCtrl     -> new($this, -1, q{}, wxDefaultPosition, $tcsize, wxTE_PROCESS_ENTER);
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

  #$this->{chainlink} = Wx::StaticBitmap->new($this, -1, $chainlink);
  #$gbs -> Add($this->{chainlink}, Wx::GBPosition->new(2,6), Wx::GBSpan->new(2,1));
  #$app -> mouseover($this->{chainlink}, "The spline ranges in k and E are not independent parameters, but both are displayed as a service to the user.");

  ## spline range in E
  $this->{bkg_spl1e_label} = Wx::StaticText   -> new($this, -1, "Spline range in E");
  $this->{bkg_spl1e}       = Wx::TextCtrl     -> new($this, -1, q{}, wxDefaultPosition, $tcsize, wxTE_PROCESS_ENTER);
  $this->{bkg_spl2e_label} = Wx::StaticText   -> new($this, -1, "to");
  $this->{bkg_spl2e}       = Wx::TextCtrl     -> new($this, -1, q{}, wxDefaultPosition, $tcsize, wxTE_PROCESS_ENTER);
  $this->{bkg_spl1e_pluck} = Wx::BitmapButton -> new($this, -1, $bullseye);
  $this->{bkg_spl2e_pluck} = Wx::BitmapButton -> new($this, -1, $bullseye);
  $gbs -> Add($this->{bkg_spl1e_label}, Wx::GBPosition->new(3,0));
  $gbs -> Add($this->{bkg_spl1e},       Wx::GBPosition->new(3,1));
  $gbs -> Add($this->{bkg_spl1e_pluck}, Wx::GBPosition->new(3,2));
  $gbs -> Add($this->{bkg_spl2e_label}, Wx::GBPosition->new(3,3));
  $gbs -> Add($this->{bkg_spl2e},       Wx::GBPosition->new(3,4));
  $gbs -> Add($this->{bkg_spl2e_pluck}, Wx::GBPosition->new(3,5));
  push @bkg_parameters, qw(bkg_spl1e bkg_spl2e); # chainlink);
  EVT_TEXT($this, $this->{bkg_spl1e}, sub{OnSpl(@_, $app, 'bkg_spl1e')});
  EVT_TEXT($this, $this->{bkg_spl2e}, sub{OnSpl(@_, $app, 'bkg_spl2e')});

  $backgroundboxsizer -> Add($gbs, 0, wxLEFT|wxTOP, 5);

  ## standard and clamps
  my $abox = Wx::BoxSizer->new( wxHORIZONTAL );
  $this->{box_with_standard} = $abox;
  $this->{bkg_stan_label}   = Wx::StaticText -> new($this, -1, "Standard");
  #$this->{bkg_stan}         = Wx::ComboBox   -> new($this, -1, '', wxDefaultPosition, [50,-1], [], wxCB_READONLY);
  $this->{bkg_stan}         = Demeter::UI::Athena::GroupList -> new($this, $app, 1);
  $abox -> Add($this->{bkg_stan_label},   0, wxBOTTOM|wxRIGHT,   5);
  $abox -> Add($this->{bkg_stan},         0, wxRIGHT, 10);
  push @bkg_parameters, qw(bkg_stan bkg_clamp1 bkg_clamp2 clamp);
  $app -> mouseover($this->{bkg_stan}, "Perform background removal using the selected data standard.");

  $backgroundboxsizer -> Add($abox, 0, wxLEFT, 5);

  $this->{$_} -> SetValidator( Wx::Perl::TextValidator->new( qr([-0-9.]) ) )
    foreach (qw(bkg_pre1 bkg_pre2 bkg_nor1 bkg_nor2 bkg_spl1 bkg_spl2 bkg_spl1e bkg_spl2e
		bkg_e0 bkg_rbkg bkg_kw));
  foreach my $x (qw(bkg_e0 bkg_rbkg bkg_kw bkg_pre1 bkg_pre2 bkg_nor1 bkg_nor2 bkg_step bkg_stan)) {
    EVT_TEXT($this, $this->{$x}, sub{OnParameter(@_, $app, $x)});
    EVT_TEXT_ENTER($this, $this->{$x}, sub{OnTextEnter(@_, $app, $x)});
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
  #
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

  #my $fftbox       = Wx::StaticBox->new($this, -1, 'Forward Fourier transform parameters', wxDefaultPosition, wxDefaultSize);
  #my $fftboxsizer  = Wx::StaticBoxSizer->new( $fftbox, wxHORIZONTAL );
  #$fftbox         -> SetFont( Wx::Font->new( $box_font_size, wxDEFAULT, wxNORMAL, wxBOLD, 0, "" ) );
  #$this->{sizer}  -> Add($fftboxsizer, 0, wxBOTTOM|wxGROW, 5);
  #$this->{fftbox}  = $fftbox;

  my $fftboxsizer  = Wx::BoxSizer->new( wxVERTICAL );
  $fftboxsizer -> Add(Wx::StaticLine->new($this, -1, wxDefaultPosition, wxDefaultSize, wxLI_HORIZONTAL), 0, wxGROW|wxBOTTOM, 2);
  $this->{sizer}  -> Add($fftboxsizer, 0, wxTOP|wxBOTTOM|wxGROW, 5);
  $this->{fft_group_label} = Wx::StaticText->new($this, -1, 'Forward Fourier transform parameters');
  $this->{fft_group_label} -> SetFont( Wx::Font->new( $box_font_size, wxDEFAULT, wxNORMAL, wxBOLD, 0, "" ) );
  $fftboxsizer -> Add($this->{fft_group_label}, 0, wxBOTTOM|wxALIGN_LEFT, 5);

  EVT_RIGHT_DOWN($this->{fft_group_label}, sub{ContextMenu(@_, $app, 'fft')});
  EVT_MENU($this->{fft_group_label}, -1, sub{ $this->DoContextMenu(@_, $app, 'fft') });

  my $tcsize = [50,-1];
  my $gbs = Wx::GridBagSizer->new( 5, 5 );

  $this->{fft_kmin_label} = Wx::StaticText   -> new($this, -1, "k-range", wxDefaultPosition, [48,-1]);
  $this->{fft_kmin}       = Wx::TextCtrl     -> new($this, -1, q{}, wxDefaultPosition, $tcsize, wxTE_PROCESS_ENTER);
  $this->{fft_kmin_pluck} = Wx::BitmapButton -> new($this, -1, $bullseye);
  $gbs -> Add($this->{fft_kmin_label}, Wx::GBPosition->new(0,0));
  $gbs -> Add($this->{fft_kmin},       Wx::GBPosition->new(0,1));
  $gbs -> Add($this->{fft_kmin_pluck}, Wx::GBPosition->new(0,2));

  $this->{fft_kmax_label} = Wx::StaticText   -> new($this, -1, "to");
  $this->{fft_kmax}       = Wx::TextCtrl     -> new($this, -1, q{}, wxDefaultPosition, $tcsize, wxTE_PROCESS_ENTER);
  $this->{fft_kmax_pluck} = Wx::BitmapButton -> new($this, -1, $bullseye);
  $this->{fft_dk_label}   = Wx::StaticText   -> new($this, -1, "dk", wxDefaultPosition, [18,-1]);
  $this->{fft_dk}         = Wx::TextCtrl     -> new($this, -1, q{}, wxDefaultPosition, $tcsize, wxTE_PROCESS_ENTER);
  $gbs -> Add($this->{fft_kmax_label}, Wx::GBPosition->new(0,3));
  $gbs -> Add($this->{fft_kmax},       Wx::GBPosition->new(0,4));
  $gbs -> Add($this->{fft_kmax_pluck}, Wx::GBPosition->new(0,5));
  $gbs -> Add($this->{fft_dk_label},   Wx::GBPosition->new(0,6));
  $gbs -> Add($this->{fft_dk},         Wx::GBPosition->new(0,7));

  $this->{fft_kwindow_label}    = Wx::StaticText -> new($this, -1, "window");
  $this->{fft_kwindow}          = Wx::Choice     -> new($this, -1, wxDefaultPosition, wxDefaultSize,
							[qw(Kaiser-Bessel Hanning Welch Parzen Sine Gaussian)]);
  $this->{fit_karb_value_label} = Wx::StaticText -> new($this, -1, q{arbitrary k-weight});
  $this->{fit_karb_value}       = Wx::TextCtrl   -> new($this, -1, q{}, wxDefaultPosition, $tcsize, wxTE_PROCESS_ENTER);
  $this->{fft_pc}               = Wx::CheckBox   -> new($this, -1, q{phase correction});
  $gbs -> Add($this->{fft_kwindow_label},    Wx::GBPosition->new(0,8));
  $gbs -> Add($this->{fft_kwindow},          Wx::GBPosition->new(0,9));
  $gbs -> Add($this->{fit_karb_value_label}, Wx::GBPosition->new(1,0), Wx::GBSpan->new(1,2));
  $gbs -> Add($this->{fit_karb_value},       Wx::GBPosition->new(1,2), Wx::GBSpan->new(1,3));
  $gbs -> Add($this->{fft_pc},               Wx::GBPosition->new(1,5), Wx::GBSpan->new(1,4));
  $this->{fft_kwindow}->SetStringSelection($this->window_name($Demeter::UI::Athena::demeter->co->default("fft", "kwindow")));
  push @fft_parameters, qw(fft_kmin fft_kmax fft_dk fft_kwindow fit_karb_value fft_pc);

  $fftboxsizer -> Add($gbs, 0, wxLEFT, 5);

  $this->{$_} -> SetValidator( Wx::Perl::TextValidator->new( qr([0-9.]) ) )
    foreach (qw(fft_kmin fft_kmax fft_dk fit_karb_value));
  foreach my $x (qw(fft_kmin fft_kmax fft_dk fit_karb_value)) {
    EVT_TEXT($this, $this->{$x}, sub{OnParameter(@_, $app, $x)});
    EVT_TEXT_ENTER($this, $this->{$x}, sub{OnTextEnter(@_, $app, $x)});
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

  #my $bftbox       = Wx::StaticBox->new($this, -1, 'Backward Fourier transform parameters', wxDefaultPosition, wxDefaultSize);
  #my $bftboxsizer  = Wx::StaticBoxSizer->new( $bftbox, wxHORIZONTAL );
  #$bftbox         -> SetFont( Wx::Font->new( $box_font_size, wxDEFAULT, wxNORMAL, wxBOLD, 0, "" ) );
  #$this->{sizer}  -> Add($bftboxsizer, 0, wxBOTTOM|wxGROW, 0);
  #$this->{bftbox}  = $bftbox;

  my $bftboxsizer  = Wx::BoxSizer->new( wxVERTICAL );
  $bftboxsizer -> Add(Wx::StaticLine->new($this, -1, wxDefaultPosition, wxDefaultSize, wxLI_HORIZONTAL), 0, wxGROW|wxBOTTOM, 2);
  $this->{sizer}  -> Add($bftboxsizer, 0, wxTOP|wxBOTTOM|wxGROW, 5);
  $this->{bft_group_label} = Wx::StaticText->new($this, -1, 'Backward Fourier transform parameters');
  $this->{bft_group_label} -> SetFont( Wx::Font->new( $box_font_size, wxDEFAULT, wxNORMAL, wxBOLD, 0, "" ) );
  $bftboxsizer -> Add($this->{bft_group_label}, 0, wxBOTTOM|wxALIGN_LEFT, 5);

  EVT_RIGHT_DOWN($this->{bft_group_label}, sub{ContextMenu(@_, $app, 'bft')});
  EVT_MENU($this->{bft_group_label}, -1, sub{ $this->DoContextMenu(@_, $app, 'bft') });

  my $tcsize = [50,-1];
  my $gbs = Wx::GridBagSizer->new( 5, 5 );

  $this->{bft_rmin_label} = Wx::StaticText   -> new($this, -1, "R-range", wxDefaultPosition, [48,-1]);
  $this->{bft_rmin}       = Wx::TextCtrl     -> new($this, -1, q{}, wxDefaultPosition, $tcsize, wxTE_PROCESS_ENTER);
  $this->{bft_rmin_pluck} = Wx::BitmapButton -> new($this, -1, $bullseye);
  $this->{bft_rmax_label} = Wx::StaticText   -> new($this, -1, "to");
  $this->{bft_rmax}       = Wx::TextCtrl     -> new($this, -1, q{}, wxDefaultPosition, $tcsize, wxTE_PROCESS_ENTER);
  $this->{bft_rmax_pluck} = Wx::BitmapButton -> new($this, -1, $bullseye);
  $this->{bft_dr_label}   = Wx::StaticText   -> new($this, -1, "dR", wxDefaultPosition, [18,-1]);
  $this->{bft_dr}         = Wx::TextCtrl     -> new($this, -1, q{}, wxDefaultPosition, $tcsize, wxTE_PROCESS_ENTER);
  $gbs -> Add($this->{bft_rmin_label}, Wx::GBPosition->new(0,0));
  $gbs -> Add($this->{bft_rmin},       Wx::GBPosition->new(0,1));
  $gbs -> Add($this->{bft_rmin_pluck}, Wx::GBPosition->new(0,2));
  $gbs -> Add($this->{bft_rmax_label}, Wx::GBPosition->new(0,3));
  $gbs -> Add($this->{bft_rmax},       Wx::GBPosition->new(0,4));
  $gbs -> Add($this->{bft_rmax_pluck}, Wx::GBPosition->new(0,5));
  $gbs -> Add($this->{bft_dr_label},   Wx::GBPosition->new(0,6));
  $gbs -> Add($this->{bft_dr},         Wx::GBPosition->new(0,7));
  push @bft_parameters, qw(bft_rmin bft_rmax bft_dr bft_rwindow);

  $this->{bft_rwindow_label} = Wx::StaticText -> new($this, -1, "window");
  $this->{bft_rwindow}       = Wx::Choice     -> new($this, -1, wxDefaultPosition, wxDefaultSize,
  						  [qw(Kaiser-Bessel Hanning Welch Parzen Sine Gaussian)]);
  $gbs -> Add($this->{bft_rwindow_label}, Wx::GBPosition->new(0,8));
  $gbs -> Add($this->{bft_rwindow},       Wx::GBPosition->new(0,9), Wx::GBSpan->new(1,3));
  $this->{bft_rwindow}->SetStringSelection($this->window_name($Demeter::UI::Athena::demeter->co->default("bft", "rwindow")));

  $bftboxsizer -> Add($gbs, 0, wxLEFT, 5);

  $this->{$_} -> SetValidator( Wx::Perl::TextValidator->new( qr([0-9.]) ) )
    foreach (qw(bft_rmin bft_rmax bft_dr));
  foreach my $x (qw(bft_rmin bft_rmax bft_dr)) {
    EVT_TEXT($this, $this->{$x}, sub{OnParameter(@_, $app, $x)});
    EVT_TEXT_ENTER($this, $this->{$x}, sub{OnTextEnter(@_, $app, $x)});
    next if ($x eq 'bft_rmax');
    EVT_RIGHT_DOWN($this->{$x.'_label'}, sub{ContextMenu(@_, $app, $x)});
    EVT_MENU($this->{$x.'_label'}, -1, sub{ $this->DoContextMenu(@_, $app, $x) });
  };
  foreach my $x (qw(bft_rmin bft_rmax)) {
    EVT_BUTTON($this, $this->{$x.'_pluck'}, sub{Pluck(@_, $app, $x)});
  };
  EVT_CHOICE($this, $this->{bft_rwindow}, sub{OnParameter(@_, $app, 'bft_rwindow')});
  EVT_RIGHT_DOWN($this->{bft_rwindow_label}, sub{ContextMenu(@_, $app, 'bft_rwindow')});
  EVT_MENU($this->{bft_rwindow_label}, -1, sub{ $this->DoContextMenu(@_, $app, 'bft_rwindow') });

  return $this;
};

sub plot {
  my ($this, $app) = @_;

  #my $plotbox       = Wx::StaticBox->new($this, -1, 'Plotting parameters', wxDefaultPosition, wxDefaultSize);
  #my $plotboxsizer  = Wx::StaticBoxSizer->new( $plotbox, wxHORIZONTAL );
  #$plotbox         -> SetFont( Wx::Font->new( $box_font_size, wxDEFAULT, wxNORMAL, wxBOLD, 0, "" ) );
  #$this->{sizer}   -> Add($plotboxsizer, 0, wxALL|wxGROW, 0);
  #$this->{plotbox}  = $plotbox;

  my $plotboxsizer  = Wx::BoxSizer->new( wxVERTICAL );
  $plotboxsizer -> Add(Wx::StaticLine->new($this, -1, wxDefaultPosition, wxDefaultSize, wxLI_HORIZONTAL), 0, wxGROW|wxBOTTOM, 2);
  $this->{sizer}  -> Add($plotboxsizer, 0, wxTOP|wxBOTTOM|wxGROW, 5);
  $this->{plot_group_label} = Wx::StaticText->new($this, -1, 'Plotting parameters');
  $this->{plot_group_label} -> SetFont( Wx::Font->new( $box_font_size, wxDEFAULT, wxNORMAL, wxBOLD, 0, "" ) );
  $plotboxsizer -> Add($this->{plot_group_label}, 0, wxBOTTOM|wxALIGN_LEFT, 5);

  EVT_RIGHT_DOWN($this->{plot_group_label}, sub{ContextMenu(@_, $app, 'plot')});
  EVT_MENU($this->{plot_group_label}, -1, sub{ $this->DoContextMenu(@_, $app, 'plot') });

  my $pbox = Wx::BoxSizer->new( wxHORIZONTAL );
  $this->{plot_multiplier_label} = Wx::StaticText->new($this, -1, "Plot multiplier");
  $this->{plot_multiplier}       = Wx::TextCtrl  ->new($this, -1, q{}, wxDefaultPosition, $tcsize, wxTE_PROCESS_ENTER);
  $this->{'y_offset_label'}        = Wx::StaticText->new($this, -1, "y-axis offset");
  $this->{'y_offset'}              = Wx::TextCtrl  ->new($this, -1, q{}, wxDefaultPosition, $tcsize, wxTE_PROCESS_ENTER);
  $pbox -> Add($this->{plot_multiplier_label}, 0, wxALL,    5);
  $pbox -> Add($this->{plot_multiplier},       0, wxRIGHT, 10);
  $pbox -> Add($this->{'y_offset_label'},      0, wxALL,    5);
  $pbox -> Add($this->{'y_offset'},            0, wxRIGHT, 10);
  push @plot_parameters, qw(plot_multiplier y_offset);

  $this->{$_} -> SetValidator( Wx::Perl::TextValidator->new( qr([-0-9.]) ) )
    foreach (qw(plot_multiplier y_offset));
  foreach my $x (qw(plot_multiplier y_offset)) {
    EVT_TEXT($this, $this->{$x}, sub{OnParameter(@_, $app, $x)});
    EVT_TEXT_ENTER($this, $this->{$x}, sub{OnTextEnter(@_, $app, $x)});
    EVT_RIGHT_DOWN($this->{$x.'_label'}, sub{ContextMenu(@_, $app, $x)});
    EVT_MENU($this->{$x.'_label'}, -1, sub{ $this->DoContextMenu(@_, $app, $x) });
  };

  $plotboxsizer -> Add($pbox, 0, wxLEFT, 5);
  return $this;
};



sub mode {
  my ($this, $group, $enabled, $frozen) = @_;
  if ($::app and $::app->current_data) {
    $frozen ||= $::app->current_data->quenched;
    ##print join("|", $group->name, $enabled, $frozen, $::app->current_data->name, caller), $/;
  };

  foreach my $w (qw(group_group_label background_group_label fft_group_label
		    bft_group_label plot_group_label)) {
    $this->{$w} -> SetForegroundColour( Wx::Colour->new(wxNullColour) );
  };
  if ($::app) {
    $this->Refresh;
    $this->Update;
  };
  foreach my $w (@bkg_parameters, @fft_parameters, @bft_parameters,
		 @group_params, @plot_parameters, 'group_group_label', 'plot_group_label', 'clampbox') {
    $this->set_widget_state($w, $enabled);
  };

  ## no data specified, possibly no data imported
  if (not $group) {
    foreach my $w (@bkg_parameters, @fft_parameters, @bft_parameters,
		   qw(background_group_label fft_group_label bft_group_label clampbox)) {
      $this->set_widget_state($w, $enabled);
    };
    $this->set_widget_state('freeze', 0);

  } elsif ($frozen) {
    foreach my $w (@group_params, @plot_parameters, @bkg_parameters, @fft_parameters,
		   @bft_parameters) {
      next if ($w =~ m{group_label});
      $this->set_widget_state($w, 0, 1);
    };
    foreach my $w (qw(group_group_label background_group_label fft_group_label
		      bft_group_label plot_group_label)) {
      $this->set_widget_state($w, $enabled);
      $this->{$w} -> SetForegroundColour( Wx::Colour->new($group->co->default("athena", "frozen")) );
    };
    $this->Refresh;
    $this->Update;
    $this->set_widget_state('freeze', 1);

  ## XANES data
  } elsif ($group->datatype eq 'xanes') {
    foreach my $w (@bkg_parameters, 'background_group_label') {
      if ($w =~ m{spl|chain|clampbox|bkg_(rbkg|kw)}) {
	$this->set_widget_state($w, 0);
      } else {
	$this->set_widget_state($w, $enabled);
      };
    };
    foreach my $w (@fft_parameters, @bft_parameters, qw(fft_group_label bft_group_label)) {
      $this->set_widget_state($w, 0);
    };
    $this->set_widget_state('freeze', 1);

  ## chi(k) data
  } elsif ($group->datatype eq 'chi') {
    foreach my $w (@bkg_parameters, 'background_group_label') {
      $this->set_widget_state($w, 0);
    };
    foreach my $w (@fft_parameters, @bft_parameters, qw(fft_group_label bft_group_label)) {
      $this->set_widget_state($w, $enabled);
    };
    $this->set_widget_state('freeze', 1);

  } else {
    foreach my $w (@bkg_parameters, @fft_parameters, @bft_parameters, qw(background_group_label fft_group_label bft_group_label clampbox)) {
      $this->set_widget_state($w, $enabled);
    };
    $this->set_widget_state('freeze', 1);
  };

  foreach my $w (qw(bkg_algorithm)) {
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
  my ($this, $widget, $bool, $not_label) = @_;
  $this->{$widget}         ->Enable($bool) if exists ($this->{$widget});
  $this->{$widget.'_label'}->Enable($bool) if ((exists $this->{$widget.'_label'}) and (not $not_label));
  $this->{$widget.'_pluck'}->Enable($bool) if exists ($this->{$widget.'_pluck'});
  return $bool;
};

sub push_values {
  my ($this, $data) = @_;
  my @save = $data->get(qw(update_columns update_norm update_bkg update_fft update_bft));
  my $is_fixed = $data->bkg_fixstep;
  foreach my $w (@group_params, @plot_parameters, @bkg_parameters, @fft_parameters, @bft_parameters) {
    next if ($w =~ m{(?:label|pluck|file)\z});
    #print($w.$/), 
    next if not $data->meta->find_attribute_by_name($w);
    $this->{$w}->SetValue($data->$w) if (ref($this->{$w}) =~ m{SpinCtrl});
    $this->{$w}->SetValue($data->$w) if (ref($this->{$w}) =~ m{TextCtrl});
    $this->{$w}->SetValue($data->$w) if (ref($this->{$w}) =~ m{CheckBox});
  };
  ($this->{file}->GetValue eq '@&^^null^^&@') ? $this->{file}->SetValue($data->prjrecord)  :
  ($this->{file}->GetValue =~ m{\A\s*\z})     ? $this->{file}->SetValue($data->prjrecord)  :
  ($data->from_athena)                        ? $this->{file}->SetValue($data->prjrecord)  :
  ($data->is_merge)                           ? $this->{file}->SetValue($data->provenance) :
                                                $this->{file}->SetValue($data->source);
  $this->{file}->GetValue =~ m{\A\s*\z} && $this->{file}->SetValue($data->source);
  $this->{bkg_z}      -> SetValue(sprintf "%-2d: %s", get_Z($data->bkg_z), get_name($data->bkg_z));
  $this->{fft_edge}   -> SetValue(ucfirst($data->fft_edge));
  $this->{bkg_clamp1} -> SetStringSelection($data->number2clamp($data->bkg_clamp1));
  $this->{bkg_clamp2} -> SetStringSelection($data->number2clamp($data->bkg_clamp2));
  $this->{fft_kwindow}-> SetStringSelection($this->window_name($data->fft_kwindow));
  $this->{bft_rwindow}-> SetStringSelection($this->window_name($data->bft_rwindow));
  my $nnorm = $data->bkg_nnorm;
  $this->{'bkg_nnorm_'.$nnorm}->SetValue(1);

  ## handle fixed step correctly
  $this->{bkg_fixstep}->SetValue($is_fixed);
  $data->bkg_fixstep($is_fixed);

  ## standard
  $this->{bkg_stan}->fill($::app, 1, 0);
  if ($data->bkg_stan eq 'None') {
    $this->{bkg_stan}->SetStringSelection('None');
  } else {
    my $stan = $data->mo->fetch("Data", $data->bkg_stan);
    if (not $stan) {
      $this->{bkg_stan}->SetStringSelection('None');
    } else {
      $this->{bkg_stan}->SetStringSelection($stan->name);
    };
  };

  if ($data->reference) {
    $this->{bkg_eshift}-> SetBackgroundColour( Wx::Colour->new($data->co->default("athena", "tied")) );
  } else {
    $this->{bkg_eshift}-> SetBackgroundColour( wxNullColour );
  };
  if (($data->bkg_e0 < 150) and ($data->datatype ne 'chi')) {
    $this->{bkg_e0}-> SetBackgroundColour( Wx::Colour->new("#FD7E6F") );
  } else {
    $this->{bkg_e0}-> SetBackgroundColour( wxNullColour );
  };
  if ((get_Z($data->bkg_z) < 5) and ($data->datatype ne 'chi')) {
    $this->{bkg_z_label} -> SetFont( Wx::Font->new( Wx::SystemSettings::GetFont(wxSYS_DEFAULT_GUI_FONT)->GetPointSize, wxDEFAULT, wxNORMAL, wxBOLD, 0, "" ) );
    $this->{bkg_z_label} -> SetForegroundColour( Wx::Colour->new("#FF4C4C") );
  } else {
    $this->{bkg_z_label} -> SetFont( Wx::Font->new( Wx::SystemSettings::GetFont(wxSYS_DEFAULT_GUI_FONT)->GetPointSize, wxDEFAULT, wxNORMAL, wxNORMAL, 0, "" ) );
    $this->{bkg_z_label} -> SetForegroundColour( wxNullColour );
  };
  $this->{bkg_eshift}->Refresh;
  my $truncated_name = $data->name;
  my $n = length($truncated_name);
  if ($n > 40) {
    $truncated_name = substr($data->name, 0, 17) . '...' . substr($data->name, $n-17);
  };
  $this->{group_group_label}->SetLabel('Current group:  '.$truncated_name);

  $data->set(update_columns => $save[0], update_norm => $save[1], update_bkg => $save[2],
	     update_fft     => $save[3], update_bft  => $save[4],);
  $this->{freeze}->SetValue($data->quenched);
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
  $this->{group_group_label} -> SetLabel('Current group');
};

sub window_name {
  my ($this, $string) = @_;
  return 'Kaiser-Bessel' if (lc($string) eq 'kaiser-bessel');
  return ucfirst(lc($string));
};

sub OnParameter {
  my ($main, $event, $app, $which) = @_;
#Demeter->trace;
  return if $app->{selecting_data_group};
  my $data = $app->current_data;
  return if not $data;
  my $widget = $app->{main}->{Main}->{$which};
#  print $widget->GetValue, $/;
  ## TextCtrl SpinCtrl ComboBox CheckBox RadioButton all have GetValue
  my $value = ((ref($widget) =~ m{Choice}) and ($which =~ m{clamp})) ? $data->co->default("clamp", $widget->GetStringSelection)
            : (ref($widget) =~ m{Choice})    ? $widget->GetStringSelection
            : (ref($widget) =~ m{GroupList}) ? $widget->GetSelection # bkg_stan uses Demeter::UI::Athena::GroupList
            : ($which eq 'bkg_z')            ? interpret_bkg_z($widget->GetValue)
            : ($which =~ m{nnorm})           ? interpret_nnorm($app)
	    :                                  $widget->GetValue;
  $value = 0 if ((not looks_like_number($value)) and ($which !~ m{window}));
  if ($which !~ m{nnorm}) {
    $value = 0.001 if (($data->what_isa($which) =~ m{PosNum}) and ($value<=0));
    $value = 0     if (($data->what_isa($which) =~ m{NonNeg}) and ($value<0));
  };
  #print join("|",$which,$value), $/;
  if ($which eq 'bkg_stan') {
    local $| = 1;
    my $stan = $app->{main}->{Main}->{bkg_stan}->GetClientData($value);
    if (not defined($stan)) {
      $data->bkg_stan('None');
    } else {
      $data->bkg_stan($stan->group);
    };

    ##### implementing interaction between step and normalization
    ##### TextCtrl windows as suggested by Scott Calvin by email 13
    ##### June 2011
    # Changing the value in the edge step box should automatically check the
    # "fix" button. Changing values in the pre-edge or normalization boxes
    # should immediately uncheck the "fix" button and recalculate the edge
    # step.
  } elsif (($which eq 'bkg_step') and $data->co->default('athena', 'interactive_fixstep')) {
    $data->bkg_fixstep(1);
    $app->{main}->{Main}->{bkg_fixstep}->SetValue(1);
    $data->$which($value)
  } elsif (($which =~ m{bkg_(?:nor|pre)}) and $data->co->default('athena', 'interactive_fixstep')) {
    $data->bkg_fixstep(0);
    $app->{main}->{Main}->{bkg_fixstep}->SetValue(0);
    $data->$which($value);

  } elsif ($which =~ m{nnorm_(\d)}) { # norm order
    $data->bkg_nnorm($1);

  } elsif ($which !~ m{fixstep}) { # toggle
    $data->$which($value);

  } elsif ($which !~ m{nnorm}) { # everything else...
    $data->$which($value);
  };
  $app->modified(1);
  #$widget->SetFocus;
};

sub OnTextEnter {
  my ($main, $event, $app, $which) = @_;
  $app->plot(q{}, q{}, 'E', 'single') if ($which =~ m{\Abkg});
  $app->plot(q{}, q{}, 'R', 'single') if ($which =~ m{\Afft});
  $app->plot(q{}, q{}, 'q', 'single') if ($which =~ m{\Abft});
  $app->plot(q{}, q{}, @{$app->{lastplot}}) if (($which eq 'plot_multiplier') or ($which eq 'y_offset'));
};

sub OnAbsorber {
  my ($main, $event, $app) = @_;
  my $abs = interpret_bkg_z($app->{main}->{Main}->{bkg_z}->GetValue);
  $app->current_data->bkg_z(get_symbol($abs));
  $app->modified(1);
};
sub OnEdge {
  my ($main, $event, $app) = @_;
  my $edge = $app->{main}->{Main}->{fft_edge}->GetValue;
  $app->current_data->fft_edge($edge);
  $app->modified(1);
};

sub show_source {
  my ($this) = @_;
  return "Data source: " . $::app->current_data->source;
};


sub spin_rbkg {
  my ($main, $event) = @_;
  ## this bit of chicanery is needed because plotting for some reason
  ## causes the spin event to be issues twice.  very confusing!  this
  ## serves the secondary purpose of discouraging repeated clicking of
  ## the spinner.
  my $now = DateTime->now(time_zone => 'floating');
  my $duration = $now->subtract_datetime($main->{last_spin});
  if ($duration->seconds < 2) {
    $main->{last_spin}=$now;
    $main->{bkg_rbkg_pluck} -> SetValue(0);
    return;
  };
  my $cur =  $main->{bkg_rbkg}->GetValue;
  my $pm  = ($event->GetPosition == 1) ? +1 : -1;
  my $new = $cur + Demeter->co->default(qw(athena bkg_spin_step)) * $pm;
  $new = $cur if (($new < 0.5) and ($pm = -1));
  $new = $cur if (($new > 2.5) and ($pm =  1));
  $main->{bkg_rbkg_pluck} -> SetValue(0);
  if ($new != $cur) {
    $main->{bkg_rbkg}    -> SetValue($new);
    $::app->current_data -> bkg_rbkg($new);
    $::app->plot(q{}, q{}, Demeter->co->default(qw(athena bkg_spin_plot)), 'single') if Demeter->co->default(qw(athena bkg_spin_plot));
    $::app->modified(1);
  };
  $main->{last_spin}=$now;
  $event->Veto();
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
  ## this slight of hand keeps this from regressing infinitely as the
  ## connected k- and E-spline parameters are modified.  basically,
  ## this prevents the second round of recursion, thus stopping things
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
    $app->{main}->status("Cannot pluck from a quad plot.", 'alert');
    return;
  };
  if (($on_screen eq 'r') and ($which !~ m{rmin|rmax|rbkg})) {
    $app->{main}->status("Cannot pluck for $which from an R plot.", 'alert');
    return;
  };
  if (($on_screen ne 'r') and ($which =~ m{bft|rbkg})) {
    my $type = ($on_screen eq 'e') ? 'n energy' : " $on_screen";
    $app->{main}->status("Cannot pluck for $which from a$type plot.", 'alert');
    return;
  };

  my ($return, $x, $y) = $app->cursor;
  if (not $return->status) {
    $app->{main}->status($return->message, 'alert');
    return;
  };
  my $plucked = -999;
  my $space = 'E';

  $on_screen = 'k' if ($on_screen eq 'q');
  my $data = $app->current_data;
  if ($on_screen eq 'r') {
    $plucked = $x;
    $space = 'q';
    $space = 'R' if ($which eq 'bkg_rbkg');
  } elsif (($on_screen eq 'e') and ($which eq "bkg_e0")) {
    $plucked = $x;
    $space = 'E';
  } elsif (($on_screen eq 'k') and ($which eq "bkg_e0")) {
    $plucked = $data->k2e($x, 'absolute');
    $space = 'E';
  } elsif (($on_screen eq 'e') and ($which =~ m{fft})) {
    $plucked = $data->e2k($x, 'absolute');
    $space = 'R';
  } elsif (($on_screen eq 'k') and ($which =~ m{fft})) {
    $plucked = $x;
    $space = 'R';
  } elsif (($on_screen eq 'e') and ($which =~ m{bkg})) {
    $plucked = $x - $data->bkg_e0;
    $plucked = $data->e2k($plucked) if ($which =~ m{spl\d\z});
    $space = 'E';
  } elsif (($on_screen eq 'k') and ($which =~ m{bkg})) {
    $plucked = $data->k2e($x, 'relative');
    $plucked = $data->e2k($plucked) if ($which =~ m{spl\d\z});
    $space = 'E';
  };
  if ($plucked eq -999) {
    $app->{main}->status("Could not use plucked value ($plucked)");
    return;
  };
  $plucked = sprintf("%.3f", $plucked);
  $app->{main}->{Main}->{$which}->SetValue($plucked);
  if ($::app->current_data->co->default(qw(athena pluck_plot))) {
    my $busy = Wx::BusyCursor->new();
    $::app->plot(q{}, q{}, $space, 'single');
    undef $busy;
  };
  $app->{main}->status("Plucked $plucked for $which");
};

const my $SET_ALL	     => Wx::NewId();
const my $SET_MARKED	     => Wx::NewId();
const my $TO_DEFAULT	     => Wx::NewId();
const my $KMAX_RECOMMENDED   => Wx::NewId();
const my $IDENTIFY_REFERENCE => Wx::NewId();
const my $UNTIE_REFERENCE    => Wx::NewId();
const my $EXPLAIN_ESHIFT     => Wx::NewId();
const my $ALL_TO_1           => Wx::NewId();
const my $MARKED_TO_1        => Wx::NewId();
const my $IMP_BLA_PIXEL      => Wx::NewId();
const my $SCALE_BLA_PIXEL    => Wx::NewId();
const my $E0_IFEFFIT         => Wx::NewId();
const my $E0_TABULATED       => Wx::NewId();
const my $E0_FRACTION        => Wx::NewId();
const my $E0_ZERO            => Wx::NewId();
const my $E0_PEAK            => Wx::NewId();
const my $STEP_ALL           => Wx::NewId();
const my $STEP_MARKED        => Wx::NewId();
const my $STEP_ERROR         => Wx::NewId();
const my $ESHIFT_ALL         => Wx::NewId();
const my $ESHIFT_MARKED      => Wx::NewId();


sub ContextMenu {
  my ($label, $event, $app, $which) = @_;
  my $menu  = Wx::Menu->new(q{});
  return if ($app->{main}->{list}->GetCount < 1);

  my ($this) = (any {$which eq $_} qw(currentgroup bkg fft bft plot)) ? 'these values' : 'this value';
  my $text = $label->GetLabel;
  return if not $label->IsEnabled;
  ($text = "Low spline clamp")  if ($text =~ m{low\z});
  ($text = "High spline clamp") if ($text eq 'high');
  ($text = "group parameters")  if ($text =~ m{currentgroup});
  $menu->Append($SET_ALL,    "Set all groups to $this of $text");
  $menu->Append($SET_MARKED, "Set marked groups to $this of $text");
  if ($text ne 'Edge step') {
    $menu->AppendSeparator;
    $menu->Append($TO_DEFAULT, "Set $text to its default value");
  };
  if ($text eq 'k-range') {
    $menu->AppendSeparator;
    $menu->Append($KMAX_RECOMMENDED, "Set kmax to ".Demeter->backend_name."'s suggestion");
  } elsif ($which eq 'importance') {
    $menu->AppendSeparator;
    $menu->Append($ALL_TO_1,    "Set Importance to 1 for all groups");
    $menu->Append($MARKED_TO_1, "Set Importance to 1 for marked groups");
    if (any {$_ =~ m{BLA.pixel_ratio}} @{$app->current_data->xdi_extensions}) {
      $menu->AppendSeparator;
      $menu->Append($IMP_BLA_PIXEL, "Set Importance for marked data to BLA pixel ratio");
    };
  } elsif ($which eq 'bkg_eshift') {
    $menu->AppendSeparator;
    $menu->Append($IDENTIFY_REFERENCE, "Identify this groups reference");
    $menu->Append($UNTIE_REFERENCE,    "Untie this group from its reference");
    $menu->Append($EXPLAIN_ESHIFT,     "Explain energy shift");
    $menu->AppendSeparator;
    $menu->Append($ESHIFT_ALL,     "Show energy shifts of all groups");
    $menu->Append($ESHIFT_MARKED,  "Show energy shifts of marked groups");
  } elsif ($which eq 'bkg_e0') {
    $menu->AppendSeparator;
    $menu->Append($E0_IFEFFIT,   "Set E0 to ".Demeter->backend_name."'s default");
    $menu->Append($E0_TABULATED, "Set E0 to the tabulated value");
    $menu->Append($E0_FRACTION,  "Set E0 to a fraction of the edge step");
    $menu->Append($E0_ZERO,      "Set E0 to the zero crossing of the second derivative");
    #$menu->Append($E0_PEAK,      "Set E0 to the peak of the white line");
  } elsif ($which eq 'bkg_step') {
    $menu->AppendSeparator;
    $menu->Append($STEP_ALL,     "Show edge steps of all groups");
    $menu->Append($STEP_MARKED,  "Show edge steps of marked groups");
    $menu->AppendSeparator;
    $menu->Append($STEP_ERROR,   "Approximate uncertainty in edge step");
  } elsif (($which eq 'plot_multiplier') and (any {$_ =~ m{BLA.pixel_ratio}} @{$app->current_data->xdi_extensions})) {
    $menu->AppendSeparator;
    $menu->Append($SCALE_BLA_PIXEL, "Set Plot multiplier for marked data to BLA pixel ratio");
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
    ($id == $TO_DEFAULT) and do {
      $main->to_default($app, \@list, 'marked');
      last SWITCH;
    };

    ## -------- k-range context menu
    ($id == $KMAX_RECOMMENDED) and do {
      $data->_update('bft');
      $data->fft_kmax($data->recommended_kmax);
      $app->{main}->{Main}->{fft_kmax}->SetValue($data->fft_kmax);
      if ($data->fft_kmax < 5) {
	$app->{main}->status(Demeter->backend_name." returned an oddly low value for its recommended k-weight.", 'error');
      };
      $app->modified(1);
      last SWITCH;
    };

    ## -------- bkg_e0 context menu
    (($id == $E0_IFEFFIT) or ($id == $E0_TABULATED) or ($id == $E0_FRACTION) or ($id == $E0_ZERO) or ($id == $E0_PEAK))
      and do {
	my $how = ($id == $E0_IFEFFIT)   ? 'ifeffit'
                : ($id == $E0_TABULATED) ? 'atomic'
                : ($id == $E0_FRACTION)  ? 'fraction'
                : ($id == $E0_ZERO)      ? 'zero'
                : ($id == $E0_PEAK)      ? 'peak'
		:                          'ifeffit';
	$data->e0($how);
	$app->{main}->{Main}->{bkg_e0}->SetValue($data->bkg_e0);
	$app->modified(1);
	last SWITCH;
      };

    ## -------- bkg_eshift context menu
    ($id == $IDENTIFY_REFERENCE) and do {
      $app->{main}->status(sprintf("%s is the reference for %s", $data->reference->name, $data->name));
      last SWITCH;
    };
    ($id == $UNTIE_REFERENCE) and do {
      $data->untie_reference;
      $app->modified(1);
      $app->OnGroupSelect(0,0,0);
      $app->{main}->status(sprintf("Untied reference from %s", $data->name));
      last SWITCH;
    };
    ($id == $EXPLAIN_ESHIFT) and do {
      $app->{main}->status("The value for energy shift is subtracted from the energy axis of these data before any other actions are taken.");
      last SWITCH;
    };

    ## -------- importance context menu
    ($id == $ALL_TO_1) and do {
      $main->importance_to_1($app, 'all');
      last SWITCH;
    };
    ($id == $MARKED_TO_1) and do {
      $main->importance_to_1($app, 'marked');
      last SWITCH;
    };
    ($id == $IMP_BLA_PIXEL) and do {
      foreach my $i (0 .. $app->{main}->{list}->GetCount-1) {
	next if (not $app->{main}->{list}->IsChecked($i));
	foreach my $ext (@{$app->{main}->{list}->GetIndexedData($i)->xdi_extensions}) {
	  if ($ext =~ m{BLA.pixel_ratio:\s+($NUMBER)}) {
	    $app->{main}->{list}->GetIndexedData($i)->importance($1);
	  };
	};
      };
      $app->modified(1);
      $app->OnGroupSelect(0,0,0);
      last SWITCH;
    };
    ($id == $SCALE_BLA_PIXEL) and do {
      foreach my $i (0 .. $app->{main}->{list}->GetCount-1) {
	next if (not $app->{main}->{list}->IsChecked($i));
	foreach my $ext (@{$app->{main}->{list}->GetIndexedData($i)->xdi_extensions}) {
	  if ($ext =~ m{BLA.pixel_ratio:\s+($NUMBER)}) {
	    $app->{main}->{list}->GetIndexedData($i)->plot_multiplier($1);
	  };
	};
      };
      $app->modified(1);
      $app->OnGroupSelect(0,0,0);
      last SWITCH;
    };
    ($id == $STEP_ALL) and do {
      $main->parameter_table($app, 'bkg_step', 'all', 'Edge steps');
      last SWITCH;
    };
    ($id == $STEP_MARKED) and do {
      $main->parameter_table($app, 'bkg_step', 'marked', 'Edge steps');
      last SWITCH;
    };
    ($id == $STEP_ERROR) and do {
      $main->edgestep_error($app);
      last SWITCH;
    };
    ($id == $ESHIFT_ALL) and do {
      $main->parameter_table($app, 'bkg_eshift', 'all', 'E0 shifts');
      last SWITCH;
    };
    ($id == $ESHIFT_MARKED) and do {
      $main->parameter_table($app, 'bkg_eshift', 'marked', 'E0 shifts');
      last SWITCH;
    };
  };
};

sub parameter_table {
  my ($main, $app, $which, $how, $description) = @_;

  my $stat = Statistics::Descriptive::Full->new();

  my $text = "  group                    $description\n" . "=" x 40 . "\n";
  my $max = 0;
  foreach my $i (0 .. $app->{main}->{list}->GetCount-1) {
    next if (($how eq 'marked') and (not $app->{main}->{list}->IsChecked($i)));
    $max = max($max, length($app->{main}->{list}->GetIndexedData($i)->name));
  };
  my $format = ' "%-'.$max.'s"  %.5f'."\n";
  foreach my $i (0 .. $app->{main}->{list}->GetCount-1) {
    next if (($how eq 'marked') and (not $app->{main}->{list}->IsChecked($i)));
    my $d = $app->{main}->{list}->GetIndexedData($i);
    $d -> _update('bkg');
    my $val = $d->$which;
    $text .= sprintf($format, $d->name, $val);
    $stat -> add_data($val) if looks_like_number($val);
  };
  $text .= sprintf("\n\nAverage = %.5f  Standard deviation = %.5f\n", $stat->mean, $stat->standard_deviation)
    if $stat->count > 1;
  my $dialog = Demeter::UI::Artemis::ShowText
    -> new($app->{main}, $text, "$description, $how groups")
      -> Show;
};


sub edgestep_error {
  my ($main, $app) = @_;
  my $data = $app->current_data;
  my $busy = Wx::BusyCursor->new();

  $data->sentinal(sub{$app->{main}->status(sprintf("Sample #%d of %d", $_[0]+1, $_[1]+1), 'wait|nobuffer')});
  my ($mean, $stddev, $report) = $data->edgestep_error(1);

  my $dialog = Demeter::UI::Artemis::ShowText
    -> new($app->{main}, $report, "Edge step error calculation")
      -> Show if Demeter->co->default('edgestep', 'fullreport');

  $data->sentinal(sub{1});
  $app->OnGroupSelect(0,0,0);
  $app->{main}->status(sprintf("%s: edge step = %.5f +/- %.5f", $data->name, $data->bkg_step, $stddev));
  undef $busy;
};

const my @all_group  => (qw(bkg_z fft_edge importance));
const my @all_bkg    => (qw(bkg_e0 bkg_rbkg bkg_flatten bkg_kw
			    bkg_fixstep bkg_nnorm bkg_pre1 bkg_pre2
			    bkg_nor1 bkg_nor2 bkg_spl1 bkg_spl2
			    bkg_spl1e bkg_spl2e bkg_stan bkg_clamp1
			    bkg_clamp2)); # bkg_algorithm bkg_step
const my @all_fft    => (qw(fft_kmin fft_kmax fft_dk fft_kwindow fit_karb_value fft_pc));
const my @all_bft    => (qw(bft_rmin bft_rmax bft_dr bft_rwindow));
const my @all_plot   => (qw(plot_multiplier y_offset));

sub constrain {
  my ($main, $app, $which, $how) = @_;
  if ($app->is_empty) {
    $app->{main}->status("No data!");
    return;
  };
  ($which = ['all']) if ($which eq 'all');
  my $data = $app->current_data;
  my @params = ($which->[0] eq 'all')          ? (@all_group, @all_bkg, @all_fft, @all_bft, @all_plot)
             : ($which->[0] eq 'currentgroup') ?  @all_group
             : ($which->[0] eq 'bkg')          ?  @all_bkg
             : ($which->[0] eq 'fft')          ?  @all_fft
             : ($which->[0] eq 'bft')          ?  @all_bft
             : ($which->[0] eq 'plot')         ?  @all_plot
	     :                                    @$which;
  foreach my $i (0 .. $app->{main}->{list}->GetCount-1) {
    next if (($how eq 'marked') and (not $app->{main}->{list}->IsChecked($i)));
    my $this = $app->{main}->{list}->GetIndexedData($i);
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

my %e0_algorithms = (ifeffit  => "Ifeffit's default",
		     atomic   => "the tabulated values",
		     fraction => "a fraction of the edge step",
		     zero     => "the zero crossing of their second derivatives",
		     dmax     => "the peak of their first derivatives",
		     peak     => "the peak of their white lines",
		    );
sub set_e0 {
  my ($main, $app, $which, $how) = @_;
  if ($app->is_empty) {
    $app->{main}->status("No data!");
    return;
  };
  my $busy = Wx::BusyCursor->new();
  foreach my $i (0 .. $app->{main}->{list}->GetCount-1) {
    next if (($how eq 'marked') and (not $app->{main}->{list}->IsChecked($i)));
    my $this = $app->{main}->{list}->GetIndexedData($i);
    $this->e0($which);
  };
  $app->OnGroupSelect(0,0,0);
  $app->{main}->status(sprintf("Set the e0 values for %s groups to %s", $how, $e0_algorithms{$which}));
  undef $busy;
};

sub to_default {
  my ($main, $app, $which, $how) = @_;
  my $data = $app->current_data;
  my @params = ($which->[0] eq 'all')  ? (@all_group, @all_bkg, @all_fft, @all_bft, @all_plot)
             : ($which->[0] eq 'file') ?  @all_group
             : ($which->[0] eq 'bkg')  ?  @all_bkg
             : ($which->[0] eq 'fft')  ?  @all_fft
             : ($which->[0] eq 'bft')  ?  @all_bft
             : ($which->[0] eq 'plot') ?  @all_plot
	     :                            @$which;
  foreach my $p (@params) {
    $data->to_default($p);
  };
  $app->OnGroupSelect(0,0,0);
};

sub importance_to_1 {
  my ($main, $app, $how) = @_;
  foreach my $i (0 .. $app->{main}->{list}->GetCount-1) {
    next if (($how eq 'marked') and (not $app->{main}->{list}->IsChecked($i)));
    $app->{main}->{list}->GetIndexedData($i)->importance(1);
  };
  $app->modified(1);
  $app->OnGroupSelect(0,0,0);
};

1;


=head1 NAME

Demeter::UI::Athena::Main - Main processing tool for Athena

=head1 VERSION

This documentation refers to Demeter version 0.9.16.

=head1 SYNOPSIS

This module provides the main data processing tool for Athena,
including parameters for normalization and background removal, Fourier
transforms, and group-specific plotting parameters.

=head1 DEPENDENCIES

Demeter's dependencies are in the F<Bundle/DemeterBundle.pm> file.

=head1 BUGS AND LIMITATIONS

Please report problems to Bruce Ravel (bravel AT bnl DOT gov)

Patches are welcome.

=head1 AUTHOR

Bruce Ravel (bravel AT bnl DOT gov)

L<http://bruceravel.github.com/demeter/>

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2013 Bruce Ravel (bravel AT bnl DOT gov). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
