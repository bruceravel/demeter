######################################################################
package Demeter::UI::Hephaestus::Ion::EnergyChamberBox;
use strict;
use warnings;
use Carp;

use Wx qw( :everything );
use base 'Wx::Panel';
use Wx::Event qw(EVT_RADIOBOX EVT_BUTTON);
use Wx::Perl::TextValidator;

sub new {
  my ($class, $parent) = @_;
  my $self = $class->SUPER::new($parent, -1, wxDefaultPosition, wxDefaultSize, wxMAXIMIZE_BOX );

  ## -------- vertical box containing photon energy and chamber radiobuttons
  my $energy_chamber_box = Wx::BoxSizer->new( wxVERTICAL );
  my $energysizer = Wx::BoxSizer->new( wxHORIZONTAL );
  my $label = Wx::StaticText->new($self, -1, 'Photon energy', wxDefaultPosition, wxDefaultSize);
  $energysizer -> Add($label, 0, wxALL, 2);
  $parent->{energybox} = Wx::TextCtrl -> new($self, -1, $parent->{energy});
  $parent->{energybox}->SetValidator(numval());
  $energysizer -> Add($parent->{energybox}, 0, wxALL, 2);
  $energy_chamber_box -> Add($energysizer, 0, wxALL, 2);

  $parent->{compute} = Wx::Button->new($self, -1, 'Compute', wxDefaultPosition, wxDefaultSize);
  $energy_chamber_box -> Add($parent->{compute}, 0, wxEXPAND|wxALL, 10);

  $parent->{length} = '15cm';
  $parent->{lengths} = Wx::RadioBox->new( $self, -1, 'Chamber length', wxDefaultPosition, wxDefaultSize,
					  \@Demeter::UI::Hephaestus::Ion::lengths,
					  1, wxRA_SPECIFY_COLS);
  my $i = 0;
  my $setlength = $Demeter::UI::Hephaestus::demeter->co->default(qw(hephaestus ion_length));
  foreach my $l (@Demeter::UI::Hephaestus::Ion::lengths) {
    $parent->{lengths}->SetSelection($i), last if ($l =~ m{$setlength});
    ++$i;
  };
  $energy_chamber_box -> Add($parent->{lengths}, 0, wxEXPAND|wxALL, 10);

  my $lengthsizer = Wx::BoxSizer->new( wxHORIZONTAL );
  $label = Wx::StaticText->new($self, -1, 'Custom length', wxDefaultPosition, wxDefaultSize);
  $lengthsizer -> Add($label, 0, wxLEFT|wxRIGHT, 2);
  $parent->{userlength} = $Demeter::UI::Hephaestus::demeter->co->default('hephaestus', 'ion_custom');
  $parent->{userlengthbox} = Wx::TextCtrl -> new($self, -1, $parent->{userlength}, wxDefaultPosition, [40,-1]);
  $parent->{userlengthbox}->SetValidator(numval());
  $lengthsizer -> Add($parent->{userlengthbox}, 0, wxLEFT|wxRIGHT|wxEXPAND, 2);
  $label = Wx::StaticText->new($self, -1, 'cm', wxDefaultPosition, wxDefaultSize);
  $lengthsizer -> Add($label, 0, wxLEFT|wxRIGHT, 2);
  $energy_chamber_box -> Add($lengthsizer, 0, wxALL, 10);

  $self->SetSizerAndFit($energy_chamber_box);
  return $self;
};


sub numval {
  return Wx::Perl::TextValidator -> new('\d');
};

######################################################################
package Demeter::UI::Hephaestus::Ion::Primary;
use strict;
use warnings;
use Carp;

use Wx qw( :everything );
use base 'Wx::Panel';
use Wx::Event qw(EVT_RADIOBOX EVT_BUTTON);

sub new {
  my ($class, $parent) = @_;
  my $self = $class->SUPER::new($parent, -1, wxDefaultPosition, wxDefaultSize, wxMAXIMIZE_BOX );

  my $primary_box = Wx::BoxSizer->new( wxVERTICAL );
  my $hbox  = Wx::BoxSizer->new( wxHORIZONTAL );
  $primary_box->Add($hbox, 0, wxALL|wxEXPAND, 5);
  my $label = Wx::StaticText->new($self, -1, 'Primary gas');
  $hbox->Add($label, 0, wxALL, 5);

  $parent->{primarygas} = Wx::Choice->new( $self, -1,
					   [-1, -1], [50, -1], 
					   \@Demeter::UI::Hephaestus::Ion::gases,
					 );
  my $i = 0;
  my $setgas = $Demeter::UI::Hephaestus::demeter->co->default(qw(hephaestus ion_gas1));
  foreach my $g (@Demeter::UI::Hephaestus::Ion::gases) {
    $parent->{primarygas}->SetSelection($i), last if ($g eq $setgas);
    ++$i;
  };
  $hbox->Add($parent->{primarygas}, 0, wxALL, 0);


  $parent->{primary} = Wx::Slider->new($self, -1, 100, 0, 100, [-1,-1], [-1,-1],
				     wxSL_VERTICAL|wxSL_AUTOTICKS|wxSL_LABELS|wxSL_RIGHT|wxSL_INVERSE);
  $primary_box->Add($parent->{primary}, 1, wxALL|wxEXPAND, 5);

  $self->SetSizerAndFit($primary_box);
  return $self;
};


######################################################################
package Demeter::UI::Hephaestus::Ion::Secondary;
use strict;
use warnings;
use Carp;

use Wx qw( :everything );
use base 'Wx::Panel';
use Wx::Event qw(EVT_RADIOBOX EVT_BUTTON);

sub new {
  my ($class, $parent) = @_;
  my $self = $class->SUPER::new($parent, -1, wxDefaultPosition, wxDefaultSize, wxMAXIMIZE_BOX );

  my $secondary_box = Wx::BoxSizer->new( wxVERTICAL );

  my $hbox  = Wx::BoxSizer->new( wxHORIZONTAL );
  $secondary_box->Add($hbox, 0, wxALL|wxEXPAND, 5);
  my $label = Wx::StaticText->new($self, -1, 'Secondary gas');
  $hbox->Add($label, 0, wxALL, 5);

  $parent->{secondarygas} = Wx::Choice->new( $self, -1,
					   [-1, -1], [50, -1],
					   \@Demeter::UI::Hephaestus::Ion::gases,
					 );
  $parent->{secondarygas}->SetSelection(0);
  $hbox->Add($parent->{secondarygas}, 0, wxALL, 0);


  $parent->{secondary} = Wx::Slider->new($self, -1, 0, 0, 100, [-1,-1], [-1,-1],
				     wxSL_VERTICAL|wxSL_AUTOTICKS|wxSL_LABELS|wxSL_RIGHT|wxSL_INVERSE);
  $secondary_box->Add($parent->{secondary}, 1, wxALL|wxEXPAND, 5);

  $self->SetSizerAndFit($secondary_box);
  return $self;
};


######################################################################
package Demeter::UI::Hephaestus::Ion::Pressure;
use strict;
use warnings;
use Carp;

use Wx qw( :everything );
use base 'Wx::Panel';
use Wx::Event qw(EVT_RADIOBOX EVT_BUTTON);

sub new {
  my ($class, $parent) = @_;
  my $self = $class->SUPER::new($parent, -1, wxDefaultPosition, wxDefaultSize, wxMAXIMIZE_BOX );
  my $pressure_box = Wx::BoxSizer->new( wxVERTICAL );
  my %max  = (torr => 2300, mbar => 3066, atm => 3);
  my %line = (torr => 1, mbar => 1, atm => 0.01);

  my $units = $Demeter::UI::Hephaestus::demeter->co->default("hephaestus", "ion_pressureunits");
  $parent->{pressureunits} = Wx::StaticText->new($self, -1, "Pressure ($units) ");
  $pressure_box->Add($parent->{pressureunits}, 0, wxALL, 5);
  $parent->{pressure} = Wx::Slider->new($self, -1,
					$Demeter::UI::Hephaestus::demeter->co->default(qw(hephaestus ion_pressure)),
					0, $max{$units},
					[-1,-1], [-1,-1],
					wxSL_VERTICAL|wxSL_AUTOTICKS|wxSL_LABELS|wxSL_RIGHT|wxSL_INVERSE);
  $pressure_box->Add($parent->{pressure}, 1, wxALIGN_CENTER_HORIZONTAL|wxALL, 5);

  $self->SetSizerAndFit($pressure_box);
  return $self;
};


######################################################################
package Demeter::UI::Hephaestus::Ion;
use strict;
use warnings;
use Carp;
use Chemistry::Elements qw(get_Z get_name get_symbol);
use Xray::Absorption;

use Wx qw( :everything );
use Wx::Perl::TextValidator;
use base 'Wx::Panel';
use Wx::Event qw(EVT_RADIOBOX EVT_BUTTON EVT_CHOICE EVT_KEY_DOWN
		 EVT_SPINCTRL EVT_SPIN EVT_SPIN_DOWN EVT_SPIN_UP
		 EVT_SCROLL
	       );

use vars qw(@lengths @gases %density);
@lengths = ('3.3 cm Lytle detector', '6.6 cm Lytle detector',
	    '10 cm', '15 cm', '30 cm', '45 cm', '60 cm',
	    'Use the custom length');
@gases = (qw(He N2 Ne Ar Kr Xe));
%density  = (N  => 0.00125,
	     Ar => 0.001784,
	     He => 0.00009,
	     Ne => 0.000905,
	     Kr => 0.00374,
	     Xe => 0.00588,
	    );

sub new {
  my ($class, $page, $echoarea) = @_;
  my $self = $class->SUPER::new($page, -1, wxDefaultPosition, wxDefaultSize, wxMAXIMIZE_BOX );
  my $outerbox = Wx::BoxSizer->new( wxVERTICAL );
  $self->SetSizer($outerbox);

  my $demeter = $Demeter::UI::Hephaestus::demeter;
  $self->{energy} = $demeter->co->default(qw(hephaestus ion_energy));
  $self->{echo} = $echoarea;

  ## -------- horizontal box containing energy, chambers, sliders
  my $topbox = Wx::BoxSizer->new( wxHORIZONTAL );

  my $energy_chamber = Demeter::UI::Hephaestus::Ion::EnergyChamberBox -> new($self);
  $topbox -> Add($energy_chamber, 1, wxALL|wxEXPAND|wxGROW, 5);

  my $primary = Demeter::UI::Hephaestus::Ion::Primary -> new($self);
  $topbox -> Add($primary, 0, wxALL|wxGROW, 5);
  my $secondary = Demeter::UI::Hephaestus::Ion::Secondary -> new($self);
  $topbox -> Add($secondary, 0, wxALL|wxGROW, 5);
  my $pressure = Demeter::UI::Hephaestus::Ion::Pressure -> new($self);
  $topbox -> Add($pressure, 0, wxALL|wxGROW, 5);

  EVT_SCROLL($self->{primary},      sub{twiddle_sliders(@_, $self, 'primary')});
  EVT_SCROLL($self->{secondary},    sub{twiddle_sliders(@_, $self, 'secondary')});
  EVT_SCROLL($self->{pressure},     sub{get_ion_data($self); $self->{pressure}->Refresh(1);});
  EVT_CHOICE($self, $self->{primarygas},   sub{get_ion_data($self)});
  EVT_CHOICE($self, $self->{secondarygas}, sub{get_ion_data($self)});
  EVT_RADIOBOX($self, $self->{lengths}, sub{get_ion_data($self)});
  EVT_KEY_DOWN($self->{energybox}, sub{energy_key_down(@_, $self)} );

  $outerbox -> Add($topbox);

  $outerbox -> Add( 20, 10, 0, wxGROW );

  ## -------- horizontal box for percentage absorbed
  my $midbox = Wx::BoxSizer->new( wxHORIZONTAL );
  my $label = Wx::StaticText->new($self, -1, 'Percentage absorbed');
  $midbox -> Add($label, 0, wxALL, 5);
  $self->{percentage} = Wx::StaticText->new($self, -1, 0, wxDefaultPosition, wxDefaultSize);
  $self->{percentage} -> SetFont( Wx::Font->new( 10, wxDEFAULT, wxNORMAL, wxBOLD, 0, "" ) );
  $midbox -> Add($self->{percentage}, 0, wxALL, 5);
  $midbox -> Add( 30, 10, 0, wxGROW );
  $self->{reset} = Wx::Button->new($self, -1, 'Reset', wxDefaultPosition, wxDefaultSize);
  $midbox -> Add($self->{reset}, 0, wxALL, 0);
  EVT_BUTTON($self, $self->{reset}, sub{ion_reset($self)});
  EVT_BUTTON($self, $self->{compute}, sub{get_ion_data($self)});

  $outerbox -> Add($midbox, 0, wxALIGN_CENTER_HORIZONTAL|wxALL);

  $outerbox -> Add( 20, 10, 0, wxGROW );

  ## -------- horizontal box for flux calculator
  $self->{fluxbox} = Wx::StaticBox->new($self, -1, 'Photon Flux', wxDefaultPosition, wxDefaultSize);
  my $botbox = Wx::StaticBoxSizer->new( $self->{fluxbox}, wxHORIZONTAL );
  $label = Wx::StaticText->new($self, -1, 'Amplifier gain');
  $botbox -> Add($label, 0, wxLEFT|wxRIGHT, 5);
  $self->{amp} = Wx::SpinCtrl->new($self, -1, 8, wxDefaultPosition, [50,-1]);
  $self->{amp} -> SetRange(0,12);
  $self->{amp} -> SetValue($Demeter::UI::Hephaestus::demeter->co->default(qw(hephaestus ion_gain)));
  $botbox -> Add($self->{amp}, 0, wxLEFT|wxRIGHT, 5);
  $label = Wx::StaticText->new($self, -1, 'with');
  $botbox -> Add($label, 0, wxLEFT|wxRIGHT, 5);
  $self->{volts} = Wx::TextCtrl->new($self, -1, 0, wxDefaultPosition, [40,-1]);
  $self->{volts}->SetValidator(numval());
  $botbox -> Add($self->{volts}, 0, wxLEFT|wxRIGHT, 5);
  $label = Wx::StaticText->new($self, -1, 'volts gives');
  $botbox -> Add($label, 0, wxLEFT|wxRIGHT, 5);
  $self->{fluxcalc} = Wx::StaticText->new($self, -1, 0, wxDefaultPosition, [100,-1], wxSUNKEN_BORDER|wxALIGN_RIGHT);
  $self->{fluxcalc} -> SetFont( Wx::Font->new( 10, wxDEFAULT, wxNORMAL, wxBOLD, 0, "" ) );
  $botbox -> Add($self->{fluxcalc}, 0, wxLEFT|wxRIGHT, 5);
  $label = Wx::StaticText->new($self, -1, 'photons / second');
  $botbox -> Add($label, 0, wxLEFT|wxRIGHT, 5);

  EVT_SPINCTRL($self, $self->{amp}, sub{flux_calc($self)} );
  EVT_KEY_DOWN($self->{amp}, sub{energy_key_down(@_, $self)} );
  EVT_KEY_DOWN($self->{volts}, sub{energy_key_down(@_, $self)} );

  $outerbox -> Add($botbox, 0, wxALIGN_CENTER_HORIZONTAL|wxALL, 5);

  $self -> SetSizerAndFit( $outerbox );
  #EVT_LIST_ITEM_SELECTED($self->{edges}, $self->{edges}, sub{select_edge(@_, $self)});

  get_ion_data($self);

  return $self;
};

sub twiddle_sliders {
  my ($self, $event, $parent, $me) = @_;
  my $thisval = $self->GetValue;
  my $it = ($me eq 'primary') ? 'secondary' : 'primary';
  $parent->{$it}->SetValue(100-$thisval);
  get_ion_data($parent);
};

sub get_ion_data {
  my ($self) = @_;

  $self->{userlength} = $self->{userlengthbox}->GetValue;
  if (($self->{lengths}->GetSelection == 7) and (not $self->{userlength})) {
    $self->{echo}->echo('You have not specified a custom ion chamber length.');
    $self->{percentage}->SetLabel('0 %');
    return;
  };
  $self->{echo}->echo(q{});

  my @gas = ($gases[$self->{primarygas}  ->GetCurrentSelection],
	     $gases[$self->{secondarygas}->GetCurrentSelection]);

  my @fractions = ($self->{primary}  ->GetValue/100,
		   $self->{secondary}->GetValue/100);

  my $energy = $self->{energybox}->GetValue;

  my ($barns_per_component, $amu_per_component, $dens) = (0,0, 0);
  foreach my $i (0,1) {
    my $thisgas = $gas[$i];
    ($thisgas = 'N') if ($thisgas eq 'N2');
    my $one_minus_g = 1; #Xray::Absorption->get_one_minus_g($thisgas, $energy);
    $dens +=  $fractions[$i] * $density{$thisgas};
    my $this = (Xray::Absorption -> cross_section($thisgas, $energy, 'photo') +
		Xray::Absorption -> cross_section($thisgas, $energy, 'incoherent'))
      * $one_minus_g;
    my $mass_factor = ($thisgas eq 'N') ? 2 : 1;
    $barns_per_component += $this * $fractions[$i] * $mass_factor;
    $amu_per_component   += Xray::Absorption -> get_atomic_weight($thisgas) * $fractions[$i] * $mass_factor;
  };

  ## this is in cm ...
  $self->{xsec} = $dens * $barns_per_component / $amu_per_component / 1.6607143;
  $self->{thislength} = ($lengths[$self->{lengths}->GetSelection] =~ m{(\d+(?:\.\d)?)}) ? $1 : $self->{userlength};
  my $len = $self->{thislength};
  #print 1/$xsec, "  $len\n";
  my %conv  = (torr => 760, mbar => 1013.25, atm => 1);
  my $atm = $self->{pressure}->GetValue / $conv{$Demeter::UI::Hephaestus::demeter->co->default('hephaestus', 'ion_pressureunits')};
  $atm ||= 0.001;
  $self->{xsec} *= $atm;
  $self->{percentage}->SetLabel(sprintf("%.2f %%", 100*(1-exp(-1*$self->{xsec}*$self->{thislength}))));

  flux_calc($self);
  $self->{echo}->echo(sprintf("This calculation uses the %s data resource and %s cross sections.",
			      $Demeter::UI::Hephaestus::demeter->co->default('hephaestus', 'resource'),
			      'total'));

};

sub ion_reset {
  my ($self) = @_;
  $self->{energybox}->SetValue(9000);
  $self->{lengths}->SetSelection(3);
  $self->{primary}->SetValue(100);
  $self->{secondary}->SetValue(0);
  my %conv  = (torr => 760, mbar => 1013.25, atm => 1);
  $self->{pressure}->SetValue($conv{$Demeter::UI::Hephaestus::demeter->co->default('hephaestus', 'ion_pressureunits')});
  $self->{primarygas}->SetSelection(0);
  $self->{secondarygas}->SetSelection(0);
  $self->{amp} -> SetValue(8);
  $self->{volts} -> SetValue(0);
  get_ion_data($self);
  $self->{echo}->echo('Reset all controls to their default values.');
};

sub energy_key_down {
  my ($self, $event, $parent) = @_;
  if ($event->GetKeyCode == 13) {
    get_ion_data($parent);
  } else {
    $event->Skip;
  };
};


sub flux_calc {
  my ($self) = @_;
  if ($self->{volts}->GetValue > 0) {
    my $flux = (30/16) * (10**(20-$self->{amp}->GetValue)) * $self->{volts}->GetValue / $self->{energybox}->GetValue;
    $self->{fluxcalc} -> SetLabel(0), return unless ($self->{xsec});
    $flux /= (1-exp(-1*$self->{xsec}*$self->{thislength})); # account for fraction absorbed
    $self->{fluxcalc} -> SetLabel(sprintf("%.3e", $flux));
  } else {
    $self->{fluxcalc} -> SetLabel(0);
  };
};

sub numval {
  return Wx::Perl::TextValidator -> new('\d');
};

1;

=head1 NAME

Demeter::UI::Hephaestus::Ion - Hephaestus' ion chamber utility

=head1 VERSION

This documentation refers to Demeter version 0.2.

=head1 SYNOPSIS

The contents of Hephaestus' ion chamber utility can be added to any Wx
application.

  my $page = Demeter::UI::Hephaestus::Ion->new($parent,$echoarea);
  $sizer -> Add($page, 1, wxGROW|wxEXPAND|wxALL, 0);

The arguments to the constructor method are a reference to the parent
in which this is placed and a reference to a mechanism for displaying
progress and warning messages.  The C<$echoarea> object must provide a
method called C<echo>.

C<$page> contains most of what is displayed in the main part of the
Hephaestus frame.  Only the label at the top is not included in
C<$page>.

=head1 DESCRIPTION

This utility allows the user to predict the response of ion chambers
given selected fill gases, ion chmaber length, and an incident photon
energy.  Two gases can be mixed and the pressure can be adjusted in
the calculation.  Photon flux can be calculated given an amplifier
gain and voltage.

=head1 CONFIGURATION


=head1 DEPENDENCIES

Demeter's dependencies are in the F<Bundle/DemeterBundle.pm> file.

=head1 BUGS AND LIMITATIONS

=over 4

=item *

Allow the user to perform the caluclation using different parts of the
total cross-section.

=item *

Compute flux from SRS amplifiers.

=back

Please report problems to Bruce Ravel (bravel AT bnl DOT gov)

Patches are welcome.

=head1 AUTHOR

Bruce Ravel (bravel AT bnl DOT gov)

L<http://cars9.uchicago.edu/~ravel/software/>

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2008 Bruce Ravel (bravel AT bnl DOT gov). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
