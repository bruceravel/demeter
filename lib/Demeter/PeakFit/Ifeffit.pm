package Demeter::PeakFit::Ifeffit;

use Moose::Role;
use Demeter::StrTypes qw( IfeffitLineshape );

has 'defwidth'    => (is => 'ro', isa => 'Num',  default => 1);
has 'my_file'     => (is => 'ro', isa => 'Str',  default => 'Demeter/PeakFit/Ifeffit.pm');
has 'sigil'       => (is => 'ro', isa => 'Str',  default => q{});
has 'function_hash' => (is => 'ro', isa => 'HashRef',
			default => sub{
			  {
			    linear	     => 2,
			    gaussian	     => 3,
			    lorentzian	     => 3,
			    pseudovoight     => 4,
			    atan	     => 3,
			    erf  	     => 3,
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
    $string .= 'erase @group ' . $g . "\n";
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


sub guess_set {
  my ($self, $ls, $n) = @_;
  my $att = 'fix'.$n;
  return ($ls->$att) ? 'set  ' : 'guess';
};

sub define {
  my ($self, $ls) = @_;
  my $template = "peak_".$ls->function;
  $self->dispense('analysis', $template, {L=>\$ls});
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
  $self->dispense('analysis', 'peak_put', {L=>\$ls});
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
  foreach my $ls (@{$self->lineshapes}) {
    foreach my $n (0 .. $ls->np-1) {
      my $att = 'a'.$n;
      my $scalar = $ls->group.'_'.$n;
      $ls->$att(sprintf("%.5f", $self->fetch_scalar($scalar)));
      $att = 'e'.$n;
      $scalar = 'delta_'.$scalar;
      $ls->$att(sprintf("%.5f", $self->fetch_scalar($scalar)));
    };
    $ls->area($ls->a0);
  };
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

This documentation refers to Demeter version 0.9.17.

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 METHODS


=head1 LINESHAPES

These are Fityk's built in lineshapes.  Note that the format of this
document section is parsed by the reporting methods of this object.

=over 4

=item linear(yint, slope)

 yint + slope * x

=item gaussian(height, center, sigma)

 height*exp(-1*((x-center)/(2*sigma))^2) / (sigma*sqrt(2*pi)

=item lorentzian(height, center, sigma)

 (height*sigma/(2*pi)) / ((x-center)^2 * (sigma/2)^2)

=item pseudovoigt(height, center, hwhm, eta)

 eta*loren + (1-eta)*gauss

=item atan(step, e0, width)

  step*[atan((x-E0)/width)/pi + 0.5]

=item erf(step, e0, width)

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

L<http://bruceravel.github.com/demeter/>


=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2013 Bruce Ravel (bravel AT bnl DOT gov). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut

