package Demeter::PeakFit::LineShape;

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

use Carp;
use Pod::POM;

use Demeter::StrTypes qw( Empty FitykFunction );

use Moose;
extends 'Demeter';
with 'Demeter::Data::Arrays';
use MooseX::Aliases;

has '+plottable' => (default => 1);
has '+data'    => (isa => Empty.'|Demeter::Data|Demeter::XES');
has '+name'    => (default => 'Lineshape' );
has 'parent'   => (is => 'rw', isa => Empty.'|Demeter::PeakFit', default => q{},
		   trigger => sub{ my ($self, $new) = @_; $self->data($new->data)});
has 'function' => (is => 'rw', isa => FitykFunction, default => q{},
		   trigger => sub{ my ($self, $new) = @_;
				   $self->np($self->nparams);
				   $self->peaked(0) if (lc($new) =~ m{linear|atan|erf|const|cubic|quadratic|polynomial|spline|polyline|expdecay});
				 });
has 'peaked'   => (is => 'rw', isa => 'Bool', default => 1, alias => 'is_peak');
has 'np'       => (is => 'rw', isa => 'Int',  default => 0);
has 'start'    => (is => 'rw', isa => 'Int',  default => 0);

has 'xaxis'    => (is => 'rw', isa => 'Str',  default => q{energy});
has 'yaxis'    => (is => 'rw', isa => 'Str',  default => q{func});
has 'xmin'     => (is => 'rw', isa => 'Num',  default => 0);
has 'xmax'     => (is => 'rw', isa => 'Num',  default => 0);

has 'a0'       => (is => 'rw', isa => 'Num',  default => 0, alias => 'height');
has 'a1'       => (is => 'rw', isa => 'Num',  default => 0, alias => 'center');
has 'a2'       => (is => 'rw', isa => 'Num',  default => 0, alias => 'hwhm');
has 'a3'       => (is => 'rw', isa => 'Num',  default => 0);
has 'a4'       => (is => 'rw', isa => 'Num',  default => 0);
has 'a5'       => (is => 'rw', isa => 'Num',  default => 0);
has 'a6'       => (is => 'rw', isa => 'Num',  default => 0);
has 'a7'       => (is => 'rw', isa => 'Num',  default => 0);

has 'e0'       => (is => 'rw', isa => 'Num',  default => 0, alias => 'eheight');
has 'e1'       => (is => 'rw', isa => 'Num',  default => 0, alias => 'ecenter');
has 'e2'       => (is => 'rw', isa => 'Num',  default => 0, alias => 'ehwhm');
has 'e3'       => (is => 'rw', isa => 'Num',  default => 0);
has 'e4'       => (is => 'rw', isa => 'Num',  default => 0);
has 'e5'       => (is => 'rw', isa => 'Num',  default => 0);
has 'e6'       => (is => 'rw', isa => 'Num',  default => 0);
has 'e7'       => (is => 'rw', isa => 'Num',  default => 0);

has 'fix0'     => (is => 'rw', isa => 'Bool', default => 0, alias => 'fixheight');
has 'fix1'     => (is => 'rw', isa => 'Bool', default => 0, alias => 'fixcenter');
has 'fix2'     => (is => 'rw', isa => 'Bool', default => 0, alias => 'fixhwhm');
has 'fix3'     => (is => 'rw', isa => 'Bool', default => 0);
has 'fix4'     => (is => 'rw', isa => 'Bool', default => 0);
has 'fix5'     => (is => 'rw', isa => 'Bool', default => 0);
has 'fix6'     => (is => 'rw', isa => 'Bool', default => 0);
has 'fix7'     => (is => 'rw', isa => 'Bool', default => 0);

has 'area'     => (is => 'rw', isa => 'Num',  default => 0);

sub nparams {
  my ($self, $function) = @_;
  $function ||= $self->function;
  return 0 if ($function =~ m{\A\s*\z});
  my %hash = (
	      Constant	       => 1,
	      Linear	       => 2,
	      Quadratic	       => 3,
	      Cubic	       => 4,
	      Polynomial4      => 5,
	      Polynomial5      => 6,
	      Polynomial6      => 7,
	      Gaussian	       => 3,
	      SplitGaussian    => 4,
	      Lorentzian       => 3,
	      Pearson7	       => 4,
	      SplitPearson7    => 6,
	      PseudoVoigt      => 4,
	      Voigt	       => 4,
	      VoigtA	       => 4,
	      EMG	       => 4,
	      DoniachSunjic    => 4,
	      PielaszekCube    => 4,
	      LogNormal	       => 4,
	      Spline	       => 1,
	      Polyline	       => 1,
	      ExpDecay	       => 2,
	      GaussianA	       => 3,
	      LogNormalA       => 4,
	      LorentzianA      => 3,
	      Pearson7A	       => 4,
	      PseudoVoigtA     => 4,
	      SplitLorentzian  => 4,
	      SplitPseudoVoigt => 6,
	      SplitVoigt       => 6,

	      Atan             => 3,
	      Erf              => 3,
	    );
  return $hash{$function};
};


sub define {
  my ($self) = @_;
  my $string = sprintf("%%%s = guess %s [%.2f:%.2f]", $self->group, $self->function, $self->xmin, $self->xmax);
  #my $string = sprintf("%%%s = guess %s", $self->group, $self->function);
  my @args = ();
  push(@args, sprintf(" height=%s%.5f", $self->isfixed(0), $self->a0)) if $self->a0;
  push(@args, sprintf(" center=%s%.5f", $self->isfixed(1), $self->a1)) if $self->a1;
  push(@args, sprintf(" hwhm=%s%.5f",   $self->isfixed(2), $self->a2)) if $self->a2;
  $string .= join(", ", @args);
  $string .= ' in @0';
  return $string;
};

sub put_arrays {
  my ($self, $rx) = @_;
  $self->parent->dispose_to_fityk('@0.F=0');
  $self->parent->dispose_to_fityk('@0.F=%' . $self->group);
  my @model_y = @{ $self->parent->fityk_object->get_model_vector($rx, 0) };
  Ifeffit::put_array($self->group.".energy", $rx);
  Ifeffit::put_array($self->group.".".$self->yaxis, \@model_y);
  return $self;
};

sub plot {
  my ($self) = @_;
  $self->dispose($self->template('plot', 'overpeak'), 'plotting');
  $self->po->increment;
  return $self;
};

sub isfixed {
  my ($self,$which) = @_;
  my $att = 'fix'.$which;
  return q{} if $self->$att;
  return q{~};
};

sub parameter_names {
  my ($self, $function) = @_;
  $function ||= $self->function;
  return ('intercept', 'slope')  if lc($function) eq 'linear';
  return ('step', 'e0', 'width') if lc($function) =~ m{atan|erf};

  my $parser = Pod::POM->new();
  my $pom = $parser->parse($INC{'Demeter/PeakFit/LineShape.pm'});

  my $sections = $pom->head1();
  my $functions_section;
  foreach my $s (@$sections) {
    next unless ($s->title() eq 'LINESHAPES FROM FITYK');
    $functions_section = $s;
    last;
  };

  my $titleline = q{};
  foreach my $item ($functions_section->over->[0]->item) { # ick! Pod::POM is confusing!
    $titleline = $item->title;
    last if ($titleline =~ m{\b$function\b});
  };
  chop $titleline;
  my $params = substr($titleline, length($function)+1);
  my @names = map {$_ =~ m{(\w+)\s*=\s*(?:.+)} ? $1 : $_} split(/,\s+/, $params);
  return @names;
};

sub report {
  my ($self) = @_;
  my @names = $self->parameter_names;
  my $string = sprintf("%s (%s) :", $self->name, $self->function);
  my $count = 0;
  foreach my $n (@names) {
    my $a = 'a'.$count;
    my $e = 'e'.$count;
    if ($n eq 'center') {
      $string .= sprintf(" %s = %.2f(%.2f),", $n, $self->$a, $self->$e);
    } else {
      $string .= sprintf(" %s = %.3g(%.3g),", $n, $self->$a, $self->$e);
    };
    ++$count;
  };
  chop $string;
  $string .= sprintf(", area = %.2f", $self->area) if $self->peaked;
  $string .= $/;
  return $string;
};

sub fityk_report {
  my ($self) = @_;
  my $string = $self->parent->fityk_object->get_info('%'.$self->group, 1);
  $string .= $/;
  return $string;
};

sub describe {
  my ($self, $function, $description_only) = @_;
  $function ||= $self->function;
  my $parser = Pod::POM->new();
  my $pom = $parser->parse($INC{'Demeter/PeakFit/LineShape.pm'});
  my $text;

  my $sections = $pom->head1();
  my $functions_section;
  foreach my $s (@$sections) {
    next unless ($s->title() eq 'LINESHAPES FROM FITYK');
    $functions_section = $s;
    last;
  };
  foreach my $item ($functions_section->over->[0]->item) { # ick! Pod::POM is confusing!
    my $this = $item->title;
    if ($this =~ m{\b$function\b}) {
      my $content = $item->content();
      $content =~ s{\n}{ }g;
      $content =~ s{\A\s+}{};
      $content =~ s{\s+\z}{};
      $text = $content;
    };
  };
  undef $parser;
  undef $pom;
  return $text if $description_only;
  $text = sprintf("The functional form of %s is %s%s%s\n", $function, q{}, $text, q{});
  return $text;
};

__PACKAGE__->meta->make_immutable;
1;

=head1 NAME

Demeter::PeakFit::LineShape - A lineshape object for peak fitting in Demeter

=head1 VERSION

This documentation refers to Demeter version 0.4.

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 ATTRIBUTES

=over 4

=item C<name>

The string used in a plot lagend.

=item C<parent>

The PeakFit function to which this LineShape belongs.

=item C<function>

The form of the function, like Linear or Gaussian.  See below for the
complete list of possibilities.

=item C<peaked>

A flag that is true if the function associated with this object is a
peak-like function.

Linear, Atan, Erf, Const, Cubic, Quadratic, Spline, PolyLine,
ExpDecay, and the Polynomial functions are the ones for which this is
set to 0.  All others are set to 1.

=item C<np>

The number of parameters used by the specified functional form.

=item C<xaxis>

This is usually set to "energy" and is used by the plotting templates.

=item C<yaxis>

This is usually set to "func" and is used by the plotting templates.

=item C<xmin>

This is set to the lower bound fitting range when the C<fit> method of
the PeakFit object is called.

=item C<xmax>

This is set to the lower bound fitting range when the C<fit> method of
the PeakFit object is called.

=item C<a0> through C<a7>

The guessed (before the fit) and best-fit (after) values of the
parameters of the function.  Note that C<height> is an alias for
C<a0>, C<center> for C<a1>, and C<hwhm> for C<a2> -- all of which is
convenient for peak-like function.  Not all of these are used for any
given function.  For instance, a Voigt only uses C<a0> through C<a3>.

=item C<e0> through C<e7>

The uncertainties (0 before the fit) of the parameters of the
function.  Note that C<eheight> is an alias for C<e0>, C<ecenter> for
C<e1>, and C<ehwhm> for C<e2> -- all of which is convenient for
peak-like function.

=item C<fix0> through C<fix7>

Flags indicating whether to fix the associated value in a fit.  Note
that C<fixheight> is an alias for C<fix0>, C<fixcenter> for C<fix1>,
and C<fixhwhm> for C<fix2> -- all of which is convenient for peak-like
function.

=item C<area>

After the fit, this is filled with Fityk's measure of the peak area
for a Peak-like function.

=back

=head1 LINESHAPES FROM FITYK

These are Fityk's built in lineshapes.  Note that the format of this
document section is parsed by thereporting methods of this object.  It
may not be as pretty as can be, but plese don't "fix" it.

=over 4

=item Constant(a=avgy)

 a

=item Linear(a0=intercept,a1=slope)

 a0 + a1 * x

=item Quadratic(a0=avgy, a1=0, a2=0)

 a0 + a1*x + a2*x^2

=item Cubic(a0=avgy, a1=0, a2=0, a3=0)

 a0 + a1*x + a2*x^2 + a3*x^3

=item Polynomial4(a0=avgy, a1=0, a2=0, a3=0, a4=0)

 a0 + a1*x + a2*x^2 + a3*x^3 + a4*x^4

=item Polynomial5(a0=avgy, a1=0, a2=0, a3=0, a4=0, a5=0)

 a0 + a1*x + a2*x^2 + a3*x^3 + a4*x^4 + a5*x^5

=item Polynomial6(a0=avgy, a1=0, a2=0, a3=0, a4=0, a5=0, a6=0)

 a0 + a1*x + a2*x^2 + a3*x^3 + a4*x^4 + a5*x^5 + a6*x^6

=item Gaussian(height, center, hwhm)

 height*exp(-ln(2)*((x-center)/hwhm)^2)

=item SplitGaussian(height, center, hwhm1=fwhm*0.5, hwhm2=fwhm*0.5)

 if x < center then Gaussian(height, center, hwhm1)else Gaussian(height, center, hwhm2)

=item Lorentzian(height, center, hwhm)

 height/(1+((x-center)/hwhm)^2)

=item Pearson7(height, center, hwhm, shape=2) 

 height/(1+((x-center)/hwhm)^2*(2^(1/shape)-1))^shape

=item SplitPearson7(height, center, hwhm1=fwhm*0.5, hwhm2=fwhm*0.5, shape1=2, shape2=2)

 if x < center then Pearson7(height, center, hwhm1, shape1) else Pearson7(height, center, hwhm2, shape2)

=item PseudoVoigt(height, center, hwhm, shape=0.5)

 height*((1-shape)*exp(-ln(2)*((x-center)/hwhm)^2)+shape/(1+((x-center)/hwhm)^2))

=item Voigt(height, center, gwidth=fwhm*0.4, shape=0.1)

 convolution of Gaussian and Lorentzian #

=item VoigtA(area, center, gwidth=fwhm*0.4, shape=0.1)

 convolution of Gaussian and Lorentzian #

=item EMG(a=height, b=center, c=fwhm*0.4, d=fwhm*0.04)

 a*c*(2*pi)^0.5/(2*d) * exp((b-x)/d + c^2/(2*d^2)) * (abs(d)/d - erf((b-x)/(2^0.5*c) + c/(2^0.5*d)))

=item DoniachSunjic(h=height, a=0.1, F=1, E=center)

 h * cos(pi*a/2 + (1-a)*atan((x-E)/F)) / (F^2+(x-E)^2)^((1-a)/2)

=item PielaszekCube(a=height*0.016, center, r=300, s=150)

 ...#

=item LogNormal(height, center, width=fwhm, asym = 0.1)

 height*exp(-ln(2)*(ln(2.0*asym*(x-center)/width+1)/asym)^2)

=item Spline()

 cubic spline #

=item Polyline()

 linear interpolation #

=item ExpDecay(a=0, t=1)

 a*exp(-x/t)

=item GaussianA(area, center, hwhm)

 Gaussian(area/hwhm/sqrt(pi/ln(2)), center, hwhm)

=item LogNormalA(area, center, width=fwhm, asym=0.1)

 LogNormal(sqrt(ln(2)/pi)*(2*area/width)*exp(-asym^2/4/ln(2)), center, width, asym)

=item LorentzianA(area, center, hwhm)

 Lorentzian(area/hwhm/pi, center, hwhm)

=item Pearson7A(area, center, hwhm, shape)

 Pearson7(area/(hwhm*exp(lgamma(shape-0.5)-lgamma(shape))*sqrt(pi/(2^(1/shape)-1))), center, hwhm, shape)

=item PseudoVoigtA(area, center, hwhm, shape)

 GaussianA(area*(1-shape), center, hwhm) + LorentzianA(area*shape, center, hwhm)

=item SplitLorentzian(height, center, hwhm1, hwhm2)

 x < center ? Lorentzian(height, center, hwhm1) : Lorentzian(height, center, hwhm2)

=item SplitPseudoVoigt(height, center, hwhm1, hwhm2, shape1, shape2)

 x < center ? PseudoVoigt(height, center, hwhm1, shape1) : PseudoVoigt(height, center, hwhm2, shape2)

=item SplitVoigt(height, center, hwhm1, hwhm2, shape1, shape2)

 x < center ? Voigt(height, center, hwhm1, shape1) : Voigt(height, center, hwhm2, shape2)

=back

=head1 LINESHAPES DEFINE BY DEMETER

These are lineshapes defined by Demeter

=over 4

=item Atan(step=1, e0=0, width=0)

  step*[atan((x-E0)/width)/pi + 0.5]

=item Erf(step=0.5, e0=0, width=0)

  step*(erf((x-e0)/width) + 1)

=back

=head1 CONFIGURATION AND ENVIRONMENT

See L<Demeter::Config> for a description of the configuration system.

=head1 DEPENDENCIES

Demeter's dependencies are in the F<Bundle/DemeterBundle.pm> file.

=head1 BUGS AND LIMITATIONS

=over 4

=item *

Need better aliasing of parameter names for add and reporting.

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



