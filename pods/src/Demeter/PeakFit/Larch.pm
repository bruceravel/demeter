package Demeter::PeakFit::Larch;

use Moose::Role;
use Demeter::StrTypes qw( LarchLineshape );
use Scalar::Util qw(looks_like_number);

has 'defwidth'    => (is => 'ro', isa => 'LaxNum', default => 1);
has 'my_file'     => (is => 'ro', isa => 'Str',    default => 'Demeter/PeakFit/Larch.pm');
has 'sigil'       => (is => 'ro', isa => 'Str',    default => q{});
has 'function_hash' => (is => 'ro', isa => 'HashRef',
			default => sub{
			  {
			    linear       => 2,
			    gaussian     => 3,
			    lorentzian   => 3,
			    pvoigt       => 4,
			    pseudo_voigt => 4,
			    atan         => 3,
			    erf          => 3,
			    voigt        => 4,
			    pearson7     => 4,
			    breit_wigner => 4,
			    logistic     => 2,
			    lognormal    => 2,
			    students_t   => 2,
			  }});
has 'correlations' => (
		       traits    => ['Hash'],
		       is        => 'rw',
		       isa       => 'HashRef[HashRef]',
		       default   => sub { {} },
		       handles   => {
				     'exists_in_correlations' => 'exists',
				     'keys_in_correlations'   => 'keys',
				     'get_correlations'       => 'get',
				     'set_correlations'       => 'set',
				    }
		      );
has 'mappings' => (
		   traits    => ['Hash'],
		   is        => 'rw',
		   isa       => 'HashRef',
		   default   => sub { {} },
		   handles   => {
				 'exists_in_mappings' => 'exists',
				 'keys_in_mappings'   => 'keys',
				 'get_mappings'       => 'get',
				 'set_mappings'       => 'set',
				}
		  );

sub DEMOLISH {
  my ($self) = @_;
};

sub initialize {
  my ($self) = @_;
  return $self;
};


sub normalize_function {
  my ($self, $function) = @_;
  foreach my $f (@Demeter::StrTypes::larchlineshape_list) {
    return $f if (lc($function) eq lc($f));
  };
  return 0;
};

sub valid {
  my ($self, $function) = @_;
  return is_LarchLineshape($function);
};

sub cleanup {
  my ($self, $ref) = @_;
  my $string = q{};
  foreach my $g (@$ref) {
    $string .= "del ".$self->group.".$g\n";
  };
  $self->pf_dispose($string);
  return $self;
};

sub prep_data {
  my ($self) = @_;
  $self->data->_update("background");
  my $e1 = $self->xmin;
  my $i1 = $self->data->iofx('energy', $e1);
  my $e2 = $self->xmax;
  my $i2 = $self->data->iofx('energy', $e2);
  $self->dispense('analysis', 'peak_prep', {i1=>$i1, i2=>$i2});
  return $self;
};


sub isvary {
  my ($self, $ls, $n) = @_;
  my $att = 'fix'.$n;
  return ($ls->$att) ? 'False' : 'True';
};

sub define {
  my ($self, $ls) = @_;
  $self->dispense('analysis', 'peak_param', {L=>\$ls});
  #my $template = "peak_".$ls->function;
  #$self->dispense('analysis', $template, {L=>\$ls});
  return $self;
};

sub fit_command {
  my ($self, $nofit) = @_;
  $nofit ||= 0;
  return $self->template('analysis', 'peak_fit', {nofit=>$nofit});
};

sub fetch_data_x {
  my ($self) = @_;
  return ();
};

sub fetch_model_y {
  my ($self) = @_;
  return $self->fetch_array($self->group.".func");
};

sub put_arrays {
  my ($self, $ls, $rx) = @_;
  1;
  #$self->dispense('analysis', 'peak_put', {L=>\$ls});
};

sub resid {
  my ($self) = @_;
  return $self;
};

sub post_fit {
  my ($self, $rall) = @_;
  return $self;
};

sub fetch_statistics {
  my ($self) = @_;

  $self->rfactor(sprintf("%.7f", $self->fetch_scalar('dempeak.rfactor')));
  $self->chisqr(sprintf("%.5f", $self->fetch_scalar('dempeak.chi_square')));
  $self->chinu(sprintf("%.7f", $self->fetch_scalar('dempeak.chi_reduced')));
  #$self->nvarys($self->fetch_scalar('demlcf.nvarys'));
  #$self->npoints($self->nvarys+$self->fetch_scalar('demlcf.nfree'));


  my @which = qw(height centroid width 4th);
  foreach my $ls (@{$self->lineshapes}) {
    foreach my $n (0 .. $ls->np-1) {
      my $att = 'a'.$n;
      my $scalar = sprintf("dempeak.%s_%d", $ls->group, $n);
      $ls->$att(sprintf("%.5f", $self->fetch_scalar($scalar)));
      $att = 'e'.$n;

      my %correls = $self->fetch_array($scalar.'.correl');
      my $this = sprintf("%s_%d", $ls->group, $n);
      $self->set_correlations($this, \%correls);
      $self->set_mappings($this, sprintf("%s %s", $ls->name, $which[$n]));

      $scalar = $scalar.'.stderr';
      my $value = $self->fetch_scalar($scalar);
      $value = 0 if not looks_like_number($value);
      $ls->$att(sprintf("%.5f", $value));
    };
    $ls->area($ls->a0);
  };
  #Demeter->Dump($self->correlations);
  #Demeter->Dump($self->mappings);
};

sub pf_dispose {
  my ($self, $string) = @_;
  $self->dispose($string);
  return $self;
};



1;


=head1 NAME

Demeter::PeakFit::Larch - Larch backend to Demeter's peak fitting tool

=head1 VERSION

This documentation refers to Demeter version 0.9.21.

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 METHODS


=head1 LINESHAPES

These are Larch's available lineshapes.  Note that the format of this
document section is parsed by the reporting methods of this object.

=over 4

=item linear(yint, slope)

 yint + slope * x

=item gaussian(height, center, sigma)

 height*exp(-1*((x-center)/(2*sigma))^2) / (sigma*sqrt(2*pi)

=item lorentzian(height, center, sigma)

 (height*sigma/(2*pi)) / ((x-center)^2 * (sigma/2)^2)

=item voigt(height, center, hwhm, gamma)

 convolution of Lorentzian and Gaussian functions

=item pvoigt(height, center, hwhm, frac)

 eta*loren + (1-eta)*gauss

=item atan(step, e0, width)

 step*[atan((x-E0)/width)/pi + 0.5]

=item erf(step, e0, width)

 step*(erf((x-e0)/width) + 1)

=item pearson7(height, center, sigma, exponent)

 Pearson7 lineshape

=item breit_wigner(height, center, sigma, q)

 height*(q*sigma/2 + x - center)**2 / ( (sigma/2)**2 + (x - center)**2 )

=item logistic(height, center, sigma)

 height*(1 - 1 / (1 + exp((x-center)/sigma)))

=item lognormal(height, center, sigma)

 (height/x) * exp(-(ln(x) - center)/ (2* sigma**2))

=item students_t(height, center, sigma)

 height*gamma((sigma+1)/2) * (1 + (x-center)**2/sigma)^(-(sigma+1)/2) / (sqrt(sigma*pi)gamma(sigma/2))

=back

=head1 CONFIGURATION AND ENVIRONMENT

See L<Demeter::Config> for a description of the configuration system.

=head1 DEPENDENCIES

Demeter's dependencies are in the F<Build.PL> file.

=head1 BUGS AND LIMITATIONS

=over 4

=item *

???

=back

Please report problems to the Ifeffit Mailing List
(L<http://cars9.uchicago.edu/mailman/listinfo/ifeffit/>)

Patches are welcome.

=head1 AUTHOR

Bruce Ravel, L<http://bruceravel.github.io/home>

L<http://bruceravel.github.io/demeter/>


=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2015 Bruce Ravel (L<http://bruceravel.github.io/home>). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut

