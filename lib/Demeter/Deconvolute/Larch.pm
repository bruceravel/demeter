package Demeter::Deconvolute::Larch;

use Moose::Role;
use Demeter::StrTypes qw( LarchLineshape );
use Scalar::Util qw(looks_like_number);


sub DEMOLISH {
  my ($self) = @_;
};

sub initialize {
  my ($self) = @_;
  return $self;
};

  $self->data->_update("background");

sub prep_data {
  my ($self) = @_;
  my $e1 = $self->xmin;
  my $i1 = $self->data->iofx('energy', $e1);
  my $e2 = $self->xmax;
  my $i2 = $self->data->iofx('energy', $e2);
  $self->dispense('analysis', 'peak_prep', {i1=>$i1, i2=>$i2});
  return $self;
};


sub fit_command {
  my ($self, $nofit) = @_;
  $nofit ||= 0;
  return $self->template('analysis', 'peak_fit', {nofit=>$nofit});
};

sub fetch_model_y {
  my ($self) = @_;
  return $self->fetch_array($self->group.".func");
};

 $self->fetch_scalar('dempeak.rfactor')));




1;


=head1 NAME

Demeter::PeakFit::Larch - Larch backend to Demeter's peak fitting tool

=head1 VERSION

This documentation refers to Demeter version 0.9.26.

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

Copyright (c) 2006-2019 Bruce Ravel (L<http://bruceravel.github.io/home>). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut

