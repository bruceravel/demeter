package Demeter::PeakFit::Fityk;

use Moose::Role;
use Demeter::StrTypes qw( FitykFunction );

use Scalar::Util qw(looks_like_number);
use String::Random qw(random_string);
use fityk;

use vars qw($FITYK $RESPONSE);
$FITYK = fityk::Fityk->new;
my $fityk_initialized = 0;

has 'feedback'      => (is => 'rw', isa => 'Str',  default => q{});
has 'my_file'       => (is => 'ro', isa => 'Str',  default => 'Demeter/PeakFit/Fityk.pm');
has 'sigil'         => (is => 'ro', isa => 'Str',  default => '%');
has 'init_data'     => (is => 'ro', isa => 'Str',  default => '@0.F=0');
has 'defwidth'      => (is => 'ro', isa => 'Num',  default => 0);
has 'function_hash' => (is => 'ro', isa => 'HashRef',
			default => sub{
			  {
			    Constant	     => 1,
			    Linear	     => 2,
			    Quadratic	     => 3,
	      		    Cubic	     => 4,
	      		    Polynomial4      => 5,
	      		    Polynomial5      => 6,
	      		    Polynomial6      => 7,
	      		    Gaussian	     => 3,
	      		    SplitGaussian    => 4,
	      		    Lorentzian       => 3,
	      		    Pearson7	     => 4,
	      		    SplitPearson7    => 6,
	      		    PseudoVoigt      => 4,
	      		    Voigt	     => 4,
	      		    VoigtA	     => 4,
	      		    EMG	             => 4,
	      		    DoniachSunjic    => 4,
	      		    PielaszekCube    => 4,
	      		    LogNormal	     => 4,
	      		    Spline	     => 1,
	      		    Polyline	     => 1,
	      		    ExpDecay	     => 2,
	      		    GaussianA	     => 3,
	      		    LogNormalA       => 4,
	      		    LorentzianA      => 3,
	      		    Pearson7A	     => 4,
	      		    PseudoVoigtA     => 4,
	      		    SplitLorentzian  => 4,
			    SplitPseudoVoigt => 6,
	      		    SplitVoigt       => 6,

	      		    Atan             => 3,
	      		    Erf              => 3,
			  }
			}
		       );


sub DEMOLISH {
  my ($self) = @_;
  $self->close_file;
  unlink $self->feedback;
  $self->cleantemp;
};

sub pf_dispose {
  my ($self, $string) = @_;
  local $| = 1;

  if ($self->screen) {
    my ($start, $end) = ($self->mo->ui eq 'screen') ? $self->_ansify(q{}, 'peakfit') : (q{}, q{});
    print $start, $string, $end, $/;
  };

  if ($self->engine) {
    $self->process($string);
    if ($self->screen) {
      local $| = 1;
      $self->close_file;
      my $response = $self->slurp($self->feedback);
      if ($response !~ m{\A\s+\z}) {
	my ($start, $end) = ($self->mo->ui eq 'screen') ? $self->_ansify(q{}, 'comment') : (q{}, q{});
	my $start_tag = '# --> ';
	foreach my $line (split(/\n/, $response)) {
	  print $start, $start_tag, $line, $end, $/;
	  $start_tag = '      ';
	};
      };
      $self->refresh_file;
    };
  };

  if ($self->buffer) {
    if (ref($self->buffer eq 'SCALAR')) {
      my $contents = ${$self->buffer};
      $contents .= $string . $/;
      $self->buffer(\$contents);
    } elsif (ref($self->buffer eq 'ARRAY')) {
      my @contents = @{$self->buffer};
      push @contents, $string;
      $self->buffer(\@contents);
    };
  };

  return $self;
};

sub fit_command {
  my ($self) = @_;
  return 'fit in @0';
};

sub prep_data {
  my ($self) = @_;
  my $file = File::Spec->catfile($self->stash_folder, 'data_'.random_string('cccccccc'));
  $self->data->points(file    => $file,
		      space   => 'E',
		      suffix  => $self->yaxis,
		      shift   => $self->data->eshift,
		      scale   => $self->data->plot_multiplier,
		      yoffset => $self->data->y_offset
		     );
  $self->pf_dispose($self->read_command($file));
  $self->add_tempfile($file);
  $self->pf_dispose($self->range_command($self->xmin, $self->xmax));
  $self->pf_dispose($self->init_data);
  return $self;
};


sub read_command {
  my ($self, $file) = @_;
  return '@0 < ' . $file;
};
sub range_command {
  my ($self, $emin, $emax) = @_;
  return "A = a and ($emin < x and x < $emax)";
};
sub set_model {
  my ($self, $model) = @_;
  return '@0.F=' . $model;
};
sub cleanup {
  my ($self, $ref) = @_;
  my $string = join(', ', @$ref);
  $self->pf_dispose('delete ' . $string);
  return $self;
};

sub initialize {
  my ($self) = @_;
  my $file = File::Spec->catfile($self->stash_folder, 'fityk_'.random_string('cccccccc'));
  $self->feedback($file);
  open $RESPONSE, '>', $file;
  $FITYK->redir_messages($RESPONSE);
  if (not $fityk_initialized) {
    $self->pf_dispose('define Atan(step=1, e0=0, width=1) = step*(atan((x-e0)/width)/pi + 0.5)');
    $self->pf_dispose('define Erf(step=0.5, e0=0, width=1) = step*(erf((x-e0)/width) + 1)');
    $fityk_initialized = 1;
  };
  return $self;
};

sub normalize_function {
  my ($self, $function) = @_;
  foreach my $f (@Demeter::StrTypes::fitykfunction_list) {
    return $f if (lc($function) eq lc($f));
  };
  return 0;
};


sub fetch_data_x {
  my ($self) = @_;
  my $size = $FITYK->get_data(0)->size;
  my @array = ();
  foreach my $i (0 .. $size-1) {
    push @array, $FITYK->get_data(0)->get($i)->swig_x_get;
  };
  return @array;
};

sub fetch_model_y {
  my ($self, $ref) = @_;	# $ref is a reference to the x-axis array
  return @{ $FITYK->get_model_vector($ref, 0) };
};

sub engine_object {
  my ($self) = @_;
  return $FITYK;
};

sub close_file {
  my ($self) = @_;
  close $RESPONSE;
  return $self;
};

sub refresh_file {
  my ($self) = @_;
  open $RESPONSE, '>', $self->feedback;
  $FITYK->redir_messages($RESPONSE); # redirect fityk messages to the new file handle
  return $self;
};


sub fetch_statistics {
  my ($self) = @_;
  ## convert the error text into a list of lists
  my $text = $FITYK->get_info('errors');
  #print $text;
  my @results = ();
  foreach my $line (split("\n", $text)) {
    next if ($line =~ m{\AStandard});
    my @fields = split(/\s+[=+-]+\s+/, $line);
    push @results, \@fields;
  };
  foreach my $ls (@{$self->lineshapes}) {
    my $count = 0;
    foreach (1..$ls->np) {
      my $att = 'fix'.$count;
      if (not $ls->$att) {
	my $r = shift @results;
	$att = 'a'.$count;
	$r->[1] = 0 if not looks_like_number($r->[1]);
	$ls->$att($r->[1]);
	$att = 'e'.$count;
	$r->[2] = -1 if not looks_like_number($r->[2]);
	$ls->$att($r->[2]);
      };
      ++$count;
    };
    my $text = $FITYK->get_info('%'.$ls->group, 1);
    foreach my $line (split(/\n/, $text)) {
      next if $line !~ m{\AArea};
      my $area = (split(/:\s+/, $line))[1];
      $ls->area($area);
      last;
    };

  };
};


sub valid {
  my ($self, $function) = @_;
  return is_FitykFunction($function);
};

sub process {
  my ($self, $string) = @_;
  $FITYK->execute($string);
  return $self;
};

sub fityk_report {
  my ($self, $ls) = @_;
  my $string = $self->engine_object->get_info('%'.$ls->group, 1);
  $string .= $/;
  return $string;
};


## define a lineshape
sub define {
  my ($self, $ls) = @_;
  my $string = sprintf("%%%s = guess %s [%.2f:%.2f]", $ls->group, $ls->function, $self->xmin, $self->xmax);
  my @args = ();
  my @names = $ls->parameter_names;
  foreach my $i (0 .. $ls->np-1) {
    my $att = 'a'.$i;
    push(@args, sprintf(" %s=%s%.5f", $names[$i], $ls->isfixed($i), $ls->$att)) if $ls->$att;
  };
  $string .= join(", ", @args);
  $string .= ' in @0';
  $self->pf_dispose($string);
  return $self;
};

sub put_arrays {
  my ($self, $ls, $rx) = @_;
  ## this bit needs abstractin'
  $self->pf_dispose($self->init_data);
  $self->pf_dispose($self->set_model('%'.$ls->group));
  my $model_y = $self->engine_object->get_model_vector($rx, 0);
  Ifeffit::put_array($ls->group.".".$self->xaxis, $rx);
  Ifeffit::put_array($ls->group.".".$self->yaxis, $model_y);
  return $model_y;
};

sub resid {
  my ($self) = @_;
  $self -> dispose(sprintf("set %s.resid = %s.%s - %s.%s", $self->group, $self->data->group, $self->yaxis, $self->group, $self->yaxis));
  return $self;
};

sub post_fit {
  my ($self, $rall) = @_;
  $self->pf_dispose($self->init_data);
  $self->pf_dispose($self->set_model(join(' + ', @$rall)));
  return $self;
};

1;


=head1 NAME

Demeter::PeakFit::LineShape - A lineshape object for peak fitting in Demeter

=head1 VERSION

This documentation refers to Demeter version 0.9.9.

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 METHODS


=head1 LINESHAPES

These are Fityk's built in lineshapes.  Note that the format of this
document section is parsed by the reporting methods of this object.

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

Copyright (c) 2006-2012 Bruce Ravel (bravel AT bnl DOT gov). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut

