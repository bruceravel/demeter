package Demeter::PeakFit::Ifeffit;

use Moose::Role;
use Demeter::StrTypes qw( IfeffitLineshape );

has 'sigil'       => (is => 'ro', isa => 'Str',  default => q{});
has 'function_hash' => (is => 'ro', isa => 'HashRef',
			default => sub{
			  {
			    linear	     => 2,
			    gauss	     => 3,
			    loren	     => 3,
			    pvoight	     => 4,
			    atan	     => 3,
			    erfc	     => 3,
			  }});

sub DEMOLISH {
  my ($self) = @_;
};

sub initialize {
  my ($self) = @_;
  return $self;
};


sub normalize_function {
  my ($self, $function) = @_;
  foreach my $f (@Demeter::StrTypes::ifeffitlineshape_list) {
    return $f if (lc($function) eq lc($f));
  };
  return 0;
};

sub valid {
  my ($self, $function) = @_;
  return is_IfeffitLineshape($function);
};

sub cleanup {
  my ($self, $ref) = @_;
  my $string = q{};
  foreach my $g (@$ref) {
    $string .= 'erase @' . $g . "\n";
  };
  $self->pf_dispose($string);
  return $self;
};

sub prep_data {
  my ($self) = @_;
  $self->update($self->data);
  $self->dispose($self->template('analysis', 'peak_prep'));
  return $self;
};


sub guess_set {
  my ($self, $ls, $n) = @_;
  my $att = 'fix'.$n;
  return ($ls->$att) ? 'set  ' : 'guess';
};

sub define {
  my ($self, $ls) = @_;
  my $template = "peak_".$ls->function;
  $self->dispose($self->template('analysis', $template));
  return $self;
};

sub fit_command {
  my ($self) = @_;

  return $self;
};



sub pf_dispose {
  my ($self, $string) = @_;
  $self->dispose($string);
  return $self;
};



1;


=head1 NAME

Demeter::PeakFit::LineShape - A lineshape object for peak fitting in Demeter

=head1 VERSION

This documentation refers to Demeter version 0.5.

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 METHODS


=head1 LINESHAPES

These are Fityk's built in lineshapes.  Note that the format of this
document section is parsed by the reporting methods of this object.

=over 4

=item linear(slope,yint)

 yint + slope * x

=item gauss(height, center, sigma)

 height*exp(-1*((x-center)/(2*sigma))^2) / (sigma*sqrt(2*pi)

=item Lorentzian(height, center, sigma)

 (height*sigma/(2*pi)) / ((x-center)^2 * (sigma/2)^2)

=item pvoigt(height, center, hwhm, eta)

 eta*loren + (1-eta)*gauss

=item atan(step=1, e0=0, width=0)

  step*[atan((x-E0)/width)/pi + 0.5]

=item erf(step=0.5, e0=0, width=0)

  step*(erf((x-e0)/width) + 1)


=back

=head1 CONFIGURATION AND ENVIRONMENT

See L<Demeter::Config> for a description of the configuration system.

=head1 DEPENDENCIES

Demeter's dependencies are in the F<Bundle/DemeterBundle.pm> file.

=head1 BUGS AND LIMITATIONS

=over 4

=item *

???

=back

Please report problems to Bruce Ravel (bravel AT bnl DOT gov)

Patches are welcome.

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

