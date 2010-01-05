package Demeter::UI::Hephaestus::Formulas;

=for Copyright
 .
 Copyright (c) 2006-2010 Bruce Ravel (bravel AT bnl DOT gov).
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
use Carp;
use Chemistry::Elements qw(get_name);
use Chemistry::Formula qw(formula_data parse_formula);
use Scalar::Util qw(looks_like_number);
use Xray::Absorption;

use Wx qw( :everything );
use Wx::Event qw(EVT_LISTBOX EVT_BUTTON EVT_KEY_DOWN);
use base 'Wx::Panel';
use Demeter::UI::Wx::PeriodicTableDialog;


my (%formula_of, %density_of);
formula_data(\%formula_of, \%density_of);

sub new {
  my ($class, $page, $echoarea) = @_;
  my $self = $class->SUPER::new($page, -1, wxDefaultPosition, wxDefaultSize, wxMAXIMIZE_BOX );

  my $hbox = Wx::BoxSizer->new( wxHORIZONTAL );

  my @choices = keys(%formula_of);

  $self->{energyvalue} = $Demeter::UI::Hephaestus::demeter->co->default(qw(hephaestus formula_energy));
  $self->{type}        = 'Density';
  $self->{units}       = 'energy';
  $self->{echo}        = $echoarea;

  ## -------- list of materials
  $self->{materialsbox} = Wx::StaticBox->new($self, -1, 'Materials', wxDefaultPosition, wxDefaultSize);
  $self->{materialsboxsizer} = Wx::StaticBoxSizer->new( $self->{materialsbox}, wxVERTICAL );
  $self->{materials} = Wx::ListBox->new($self, -1, wxDefaultPosition, wxDefaultSize,
					\@choices, wxLB_SINGLE|wxLB_ALWAYS_SB|wxLB_SORT);
  $self->{materialsboxsizer} -> Add($self->{materials}, 1, wxEXPAND|wxALL, 0);
  $hbox -> Add($self->{materialsboxsizer}, 1, wxEXPAND|wxALL, 5);
  EVT_LISTBOX( $self, $self->{materials}, sub{insert_formula_density(@_, $self)} );


  my $vbox = Wx::BoxSizer->new( wxVERTICAL );
  $hbox -> Add($vbox, 2, wxEXPAND|wxALL, 5);

  my $width = 85;

  my $tsz = Wx::GridBagSizer->new( 3, 3 );
  $vbox -> Add($tsz, 0, wxEXPAND|wxALL, 5);

  ## -------- Formula
  my $label = Wx::StaticText->new($self, -1, 'Formula', wxDefaultPosition, [$width,-1]);
  $tsz -> Add($label, Wx::GBPosition->new(0,0));
  $self->{formula} = Wx::TextCtrl->new($self, -1, q{}, wxDefaultPosition, [$width*3, -1]);
  $tsz -> Add($self->{formula}, Wx::GBPosition->new(0,1));
  $self->{element} = Wx::Button->new($self, -1, 'Element', wxDefaultPosition, wxDefaultSize);
  $tsz -> Add($self->{element}, Wx::GBPosition->new(0,2));
  EVT_KEY_DOWN( $self->{formula}, sub{on_key_down(@_, $self)} );
  EVT_BUTTON($self, $self->{element}, sub{use_element(@_, $self)} );

  ## -------- Density
  $self->{dm} = Wx::Choice->new( $self, -1, [-1, -1], [$width, -1], ['Density', 'Molarity'], );
  $tsz -> Add($self->{dm}, Wx::GBPosition->new(1,0));
  $self->{density} = Wx::TextCtrl->new($self, -1, q{}, wxDefaultPosition, [$width*3, -1]);
  $tsz -> Add($self->{density}, Wx::GBPosition->new(1,1));
  $self->{densityunits} = Wx::StaticText->new($self, -1, 'g/cm^3', wxDefaultPosition, wxDefaultSize);
  $tsz -> Add($self->{densityunits}, Wx::GBPosition->new(1,2));
  EVT_KEY_DOWN( $self->{density}, sub{on_key_down(@_, $self)} );
  $self->{dm}->SetSelection(0);

  ## -------- Energy
  $label = Wx::StaticText->new($self, -1, 'Energy', wxDefaultPosition, [$width,-1]);
  $tsz -> Add($label, Wx::GBPosition->new(2,0));
  $self->{energy} = Wx::TextCtrl->new($self, -1, q{}, wxDefaultPosition, [$width*3, -1]);
  $tsz -> Add($self->{energy}, Wx::GBPosition->new(2,1));
  $self->{energy} -> SetValue($self->{energyvalue});
  EVT_KEY_DOWN( $self->{energy}, sub{on_key_down(@_, $self)} );
  my $numval = Wx::Perl::TextValidator -> new('\d', \($self->{data}));
  $self->{energy}->SetValidator($numval);


  ## -------- Compute button
  my $buttonbox = Wx::BoxSizer->new( wxVERTICAL );
  $vbox -> Add($buttonbox, 0, wxEXPAND|wxALL, 0);
  $self->{compute} = Wx::Button->new($self, -1, 'Compute', wxDefaultPosition, [$width*3, -1]);
  $buttonbox -> Add($self->{compute}, 0, wxEXPAND|wxALL, 5);
  EVT_BUTTON( $self, $self->{compute}, sub{get_formula_data(@_, $self)} );


  ## -------- Results text
  $self->{resultsbox} = Wx::StaticBox->new($self, -1, 'Results', wxDefaultPosition, wxDefaultSize);
  $self->{resultsboxsizer} = Wx::StaticBoxSizer->new( $self->{resultsbox}, wxVERTICAL );
  $self->{results} = Wx::TextCtrl->new($self, -1, q{}, wxDefaultPosition, wxDefaultSize,
				       wxVSCROLL|wxTE_MULTILINE|wxTE_READONLY|wxNO_BORDER);
  $self->{resultsboxsizer} -> Add($self->{results}, 1, wxEXPAND|wxALL, 2);
  $vbox -> Add($self->{resultsboxsizer}, 1, wxEXPAND|wxALL, 5);
  $self->{results}->SetFont( Wx::Font->new( 10, wxTELETYPE, wxNORMAL, wxNORMAL, 0, "" ) );

  $self->SetSizerAndFit($hbox);

  return $self;
};

sub insert_formula_density {
  my ($self, $event, $parent) = @_;
  my $this = $event->GetString;
  #print join("|", $this, $formula_of{$this}, $density_of{$this}),$/;
  $parent->{formula} -> SetValue($formula_of{$this});
  $parent->{density} -> SetValue($density_of{$this});
};

sub on_key_down {
  my ($self, $event, $parent) = @_;
  if ($event->GetKeyCode == 13) {
    #print join("|", $self, $event, $parent), $/;
    get_formula_data($self, $event, $parent);
  } else {
    $event->Skip;
  };
};

sub get_formula_data {
  my ($self, $event, $parent) = @_;
  my $answer = "\n";
  my @edges = ();
  my %count;
  $self->{echo}->SetStatusText('You have not provided a formula.'), return if not $parent->{formula}->GetValue;
  my $ok = parse_formula($parent->{formula}->GetValue, \%count);
  $parent->{echo}->SetStatusText(sprintf("This calculation uses the %s data resource and %s cross sections.",
				$Demeter::UI::Hephaestus::demeter->co->default('hephaestus', 'resource'),
				$Demeter::UI::Hephaestus::demeter->co->default('hephaestus', 'xsec')
			       ));

  my $resource = Xray::Absorption->current_resource;
  my $which = $Demeter::UI::Hephaestus::demeter->co->default('hephaestus', 'xsec');
  if (($resource eq "mcmaster") or ($resource eq "elam")) {
    ($which = "total")      if ($which eq "full");
  } elsif ($resource eq "chantler") {
    ($which = "total")      if ($which eq "full");
    ($which = "scattering") if ($which =~ /coherent/);
  };

  ## worry about energy and wavelength
  my $energy  = $parent->{energy}->GetValue;
  my $units   = 'eV';
  my $density = $parent->{density}->GetValue;
  my $type    = ('Density', 'Molarity')[$parent->{dm}->GetCurrentSelection];

  if ($type eq 'Molarity') {
    ## 1 mole is 6.0221415 x 10^23 particles
    ## 1 amu = 1.6605389 x 10^-24 gm
    ## mole*amu = 1 gram/amu  wow!
    $density = 0;
    foreach my $k (keys(%count)) {
      $density += Xray::Absorption -> get_atomic_weight($k) * $count{$k};
    };
    ## number_of_amus * molarity(moles/liter) * 1 gram/amu = density of solute
    $density *= $parent->{density};
    # molarity is moles/liter, density is g/cm^3, 1000 is the conversion
    # btwn liters and cm^3
    $density /= 1000;
  };

  if ((not $energy) or (not looks_like_number($energy)) or ($energy < 0)) {
    $answer .= "\n(Energy too low or not provided. Absorption calculation canceled.)";
    $parent->{echo}->SetStatusText("Energy too low or not provided. Absorption calculation canceled.");
  } elsif ($ok) {
    my ($weight, $xsec, $dens) = (0,0,$density);
    $dens = ($density and looks_like_number($density) and ($density > 0)) ? $density : 0;
    $answer .= "  element   number   barns/atom     cm^2/gm\n";
    $answer .= " --------- ----------------------------------\n";
    my ($barns_per_formula_unit, $amu_per_formula_unit) = (0,0);  # 1.6607143
    foreach my $k (sort (keys(%count))) {
      $weight  += Xray::Absorption -> get_atomic_weight($k) * $count{$k};
      my $scale = Xray::Absorption -> get_conversion($k);
      my $this = Xray::Absorption -> cross_section($k, $energy, $which);
      $barns_per_formula_unit += $this * $count{$k};
      $amu_per_formula_unit += Xray::Absorption -> get_atomic_weight($k) * $count{$k};
      if ($count{$k} > 0.001) {
	$answer  .= sprintf("    %-2s %11.3f %11.3f  %11.3f\n",
			    $k, $count{$k}, $this, $this/$scale);
      } else {
	$answer  .= sprintf("    %-2s      %g      %g      %g\n",
			    $k, $count{$k}, $this, $this/$scale);
      };
      ## notice if any of this atoms edges are within 100 eV of the given energy
      foreach my $edge (qw(k l1 l2 l3)) {
	my $enot = Xray::Absorption -> get_energy($k, $edge);
	push @edges, [$k, $edge] if (abs($enot - $parent->{energy}->GetValue) < 100);
      };
    };
    ## 1 amu = 1.6605389 x 10^-24 gm
    $xsec = $barns_per_formula_unit / $amu_per_formula_unit / 1.6605389;
    $answer .= sprintf("\nThis weighs %.3f amu.\n", $weight);
    if ($xsec == 0) {
      $answer .= "\n(Energy too low or not provided.  Absorption calculation skipped.)";
    } else {
      my $xx = $xsec;
      $xsec *= $dens;
      if ($xsec > 0) {
	if (10000/$xsec > 1500) {
	  $answer .=
	    sprintf("\nAbsorption length = %.3f cm at %d %s",
		    1/$xsec, $parent->{energy}->GetValue, $units);
	  $answer .= ($type eq 'Molarity') ? " for a ".$parent->{density}->GetValue." molar sample.\n" : ".\n";
	  $answer .=
	    sprintf("\nA sample of 1 absorption length with area of 1 square cm requires %.3f milligrams of sample at %.2f %s\n",
	  	    1000*$density/$xsec, $parent->{energy}->GetValue, $units) if ($type eq 'Density');
	} elsif (10000/$xsec > 500) {
	  $answer .=
	    sprintf("\nAbsorption length = %.3f cm at %d %s",
		    1/$xsec, $parent->{energy}->GetValue, $units);
	  $answer .= ($type eq 'Molarity') ? " for a ".$parent->{density}->GetValue." molar sample.\n" : ".\n";
	  $answer .=
	    sprintf("\nA sample of 1 absorption length with area of 1 square cm requires %.3f miligrams of sample at %.2f %s.\n",
	  	    1000*$density/$xsec, $parent->{energy}->GetValue, $units) if ($type eq 'Density');
	} else {
	  $answer .=
	    sprintf("\nAbsorption length = %.1f micron at %d %s",
		    10000/$xsec, $parent->{energy}->GetValue, $units);
	  $answer .= ($type eq 'Molarity') ? " for a ".$parent->{density}->GetValue." molar sample.\n" : ".\n";
	  $answer .=
	    sprintf("\nA sample of 1 absorption length with area of 1 square cm requires %.3f miligrams of sample at %.2f %s.\n",
		    1000*$density/$xsec, $parent->{energy}->GetValue, $units) if ($type eq 'Density');
	}
      } else {
	if (not $density) {
	  $answer .=
	    "\n(The absorption length calculation requires a value for density.)";
	  $self->{echo}->SetStatusText("The absorption length calculation requires a value for density.");
	} elsif (not looks_like_number($density)) {
	  $answer .=
	    "\n(The value for density is not a number.)";
	  $self->{echo}->SetStatusText("The value for density is not a number.");
	};
	$answer .=
	  sprintf("\n\nA sample of 1 absorption length with area of 1 square cm requires %.3f miligrams of sample at %.2f %s.\n",
		  1000/$xx, $parent->{energy}->GetValue, $units);
      };
    };
    ## compute unit edge step lengths for all the relevant edges in this material
    foreach my $e (@edges) {
      my $enot = Xray::Absorption -> get_energy(@$e);
      my @abovebelow = ();
      foreach my $step (-50, +50) {
	my ($bpfu, $apfu) = (0, 0);
	my $energy = $enot + $step;
	foreach my $k (keys(%count)) {
	  my $this = Xray::Absorption -> cross_section($k, $energy, $which);
	  $bpfu   += $this * $count{$k};
	  $apfu   += Xray::Absorption -> get_atomic_weight($k) * $count{$k};
	};
	## 1 amu = 1.6605389 x 10^-24 gm
	push @abovebelow, $bpfu / $apfu / 1.6605389;
      };
      my $xabove = $abovebelow[1] * $density;
      my $xbelow = $abovebelow[0] * $density;
      my $step   = 10000 / ($xabove - $xbelow);
      $answer .= sprintf "\nUnit edge step length at %s %s edge (%.1f eV) is %.1f microns\n",
	ucfirst($e->[0]), uc($e->[1]), $enot, $step;
    };

    if ($type eq 'Molarity') {
      $answer .= "\nRemember that a molarity calculation only considers the absorption of the solute. The solvent also absorbs.\n";
    };
#     my $resource = Xray::Absorption->current_resource;
#     my $which = $Demeter::UI::Hephaestus::demeter->co->default('hephaestus', 'xsec');
#     if (($resource eq "mcmaster") or ($resource eq "elam")) {
#       ($which = "total")      if ($which eq "full");
#     } elsif (lc($data{resource}) eq "chantler") {
#       ($which = "total")      if ($which eq "full");
#       ($which = "scattering") if ($which =~ /coherent/);
#     };
    ($resource = $1) if ($resource =~ m{(\w+)\.pm});
    $answer .= sprintf("\nThe %s database and the %s cross-sections were used in the calculation.",
		       $resource, $which);
  } else {
    $answer .= "\nInput error:\n\t".$count{error};
  };
  $parent->{results} -> SetValue($answer);

};

sub use_element {
  my ($self, $event, $parent) = @_;
  $parent->{popup}  = Demeter::UI::Wx::PeriodicTableDialog->new($self, -1, "Choose an element", sub{$self->put_element($_[0])});
  $parent->{popup} -> ShowModal;
};

sub put_element {
  my ($self, $el) = @_;
  $self->{popup}->Destroy;
  $self->{formula}->SetValue($el);
  $self->{density}->SetValue(Xray::Absorption->get_density($el));
  $self->{echo}->SetStatusText(sprintf("You selected %s from the pop-up periodic table.",get_name($el)));
};


1;


=head1 NAME

Demeter::UI::Hephaestus::Formulas - Hephaestus' formulas utility

=head1 VERSION

This documentation refers to Demeter version 0.4.

=head1 SYNOPSIS

The contents of Hephaestus' formulas utility can be added to any Wx
application.

  my $page = Demeter::UI::Hephaestus::Formulas->new($parent,$statusbar);
  $sizer -> Add($page, 1, wxGROW|wxEXPAND|wxALL, 0);

The arguments to the constructor method are a reference to the parent
in which this is placed and a reference to a mechanism for displaying
progress and warning messages.  C<$statusbar> is the StatusBar of the
parent window.

C<$page> contains most of what is displayed in the main part of the
Hephaestus frame.  Only the label at the top is not included in
C<$page>.

=head1 DESCRIPTION

This utility presents a short list of known materials and allows you
to either select one or to enter the chemical formula of some other
material.  There is also a button to open a periodic table pop-up for
selecting an element and its natural density.  From the specified
density and measurement energy, the absorption of that material will
be calculated using tables of x-ray absorption coefficients.  This is
useful for planning sample preparation and for predicting the response
of your sample and other parts of the experiment when exposed ot the
x-ray beam.

=head1 CONFIGURATION


=head1 DEPENDENCIES

Demeter's dependencies are in the F<Bundle/DemeterBundle.pm> file.

=head1 BUGS AND LIMITATIONS

=over 4

=item *

Add and delete user materials using an ini file.

=back

Please report problems to Bruce Ravel (bravel AT bnl DOT gov)

Patches are welcome.

=head1 AUTHOR

Bruce Ravel (bravel AT bnl DOT gov)

L<http://cars9.uchicago.edu/~ravel/software/>

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2010 Bruce Ravel (bravel AT bnl DOT gov). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
