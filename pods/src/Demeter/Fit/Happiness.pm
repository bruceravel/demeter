package Demeter::Fit::Happiness;

=for Copyright
 .
 Copyright (c) 2006-2012 Bruce Ravel (bravel AT bnl DOT gov).
 All rights reserved.
 .my 
 This file is free software; you can redistribute it and/or
 modify it under the same terms as Perl itself. See The Perl
 Artistic License.
 .
 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut

use autodie qw(open close);

use Moose::Role;

use Carp;

sub get_happiness {
  my ($self)  = @_;
  my $cheer   = 100;
  my $summary = q{};

  ## R-factor
  my ($c, $s) = $self->_penalize_rfactor;
  $cheer     -= $c;
  $summary   .= $s;

  ## path parameter values
  ($c, $s)    = $self->_penalize_pathparams;
  $cheer     -= $c;
  $summary   .= $s;

  ## restraints
  ($c, $s)    = $self->_penalize_restraints;
  $cheer     -= $c;
  $summary   .= $s;

  ## Nidp
  ($c, $s)    = $self->_penalize_nidp;
  $cheer     -= $c;
  $summary   .= $s;

  ## correlations
  ($c, $s)    = $self->_penalize_correlations;
  $cheer     -= $c;
  $summary   .= $s;

  $cheer = 0 if ($cheer < 0);
  return wantarray ? ($cheer, $summary) : $cheer;
};

sub color {
  my ($self, $cheer) = @_;
  $cheer ||= $self->happiness;

  my @bad  = $self->_slice_rgb( $self->co->default("happiness", "bad_color"    ) );
  my @ok   = $self->_slice_rgb( $self->co->default("happiness", "average_color") );
  my @good = $self->_slice_rgb( $self->co->default("happiness", "good_color"   ) );
  my (@bottom, @top, $fraction);

  my $min = $self->co->default("happiness", "minimum");
  my $scaled = ($cheer < $min) ? 0 : ($cheer-$min) / (100-$min);
  my $center = $self->co->default("happiness", "shoulder");
  if ($scaled < $center) {
    $fraction = $scaled / $center;
    @bottom   = @bad;
    @top      = @ok;
  } else {
    $fraction = ($scaled-$center) / $center;
    @bottom   = @ok;
    @top      = @good;
  };

  my @answer = map { $bottom[$_] * (1-$fraction) + $top[$_] * $fraction } (0 .. 2);
  return sprintf("#%X%X%X", @answer);
};

sub _slice_rgb {
  my ($self, $string) = @_;
  ## what if color is an rgb.txt named color?
  ## use Color::Rgb and provide an rgb.txt file, perhaps in share/
  $string =~ s{^\#}{};
  my $r = substr($string, 0, 2);
  my $g = substr($string, 2, 2);
  my $b = substr($string, 4, 2);
  return (eval "0x$r", eval "0x$g", eval "0x$b");
};

sub _penalize_rfactor {
  my ($self) = @_;
  my @data   = @{ $self->data };
  my $space = 1;
  foreach my $d (@data) {
    $space = 0.1 if ($d->fit_space eq 'k');
  };
  my ($low, $high, $scale) = (
			      $self->co->default("happiness", "rfactor_low"),
			      $self->co->default("happiness", "rfactor_high"),
			      $self->co->default("happiness", "rfactor_scale")
			     );
  my $maximum = $scale * ($high - $low);

  my $rfactor = $self->r_factor || 0;
  return (0, q{}) if ($rfactor < $low);
  my $penalty = ($rfactor-$low) * $scale * $space; # reduce penalty by 1/10 for fit in k-space
  $penalty = ($rfactor > $high) ? $maximum : $penalty;
  my $summary = sprintf("An R-factor of %.5f gives a penalty of %.5f.\n",
			$rfactor, $penalty);
  return ($penalty, $summary);
};

sub _penalize_pathparams {
  my ($self) = @_;
  my $scale  = $self->co->default("happiness", "pathparams_scale");

  my @paths   = @{ $self->paths };
  my @params  = qw(e0 s02 delr sigma2); # third fourth dphase
  my $count   = 0;
  my $summary = q{};
  foreach my $p (@paths) {
    next if not $p->include;
    foreach my $pa (@params) {
      my ($isok, $explanation) = $p->is_resonable($pa);
      if (not $isok) {
	$summary .= "Penalty of $scale : " . $explanation . "\n";
	++$count;
      };
    };
  };
  $count *= $scale;
  return ($count, $summary);
};

sub _penalize_restraints {
  my ($self) = @_;
  my $scale  = $self->co->default("happiness", "restraints_scale");

  my @gds = @{ $self->gds };
  my $chisqr  = $self->chi_square;
  my $count   = 0;
  my $summary = q{};
  foreach my $g (@gds) {
    next if ($g->gds ne "restrain");
    my $this = $g->bestfit;
    #my $addon = ($chisqr) ? $this/$chisqr : 0;
    my $addon = ($chisqr) ? $this : 0;
    $count += $addon;
    next if ($this == 0);
    #print join("|", $scale,$this,$chisqr), $/;
    $summary .= sprintf("The restraint \"%s\" evaluated to %.3f for a penalty of %.3f.\n",
			$g->name, $g->bestfit, $scale*$this);
			#$g->name, $g->bestfit, $scale*$this/$chisqr);
  };
  my $total = $scale * $count;
  return ($total, $summary);
};

sub _penalize_nidp {
  my ($self) = @_;
  my ($cutoff, $scale) = (
			  $self->co->default("happiness", "nidp_cutoff"),
			  $self->co->default("happiness", "nidp_scale"),
			 );
  return (0, q{}) if ($cutoff >= 1);
  my $nidp  = $self->n_idp;
  my $nvar  = $self->n_varys;
  my $diff  = $nidp-$nvar;
  my $limit = (1 - $cutoff)*$nidp;
  return (0, q{}) if ($diff > $limit);
  my $penalty = ($limit-$diff) / $limit;
  $penalty *= $scale;
  my $summary = sprintf("Used %d of %.3f independent points for a penalty of %.3f\n",
			$nvar, $nidp, $penalty);
  return ($penalty, $summary);
};

sub _penalize_correlations {
  my ($self) = @_;
  my ($cutoff, $scale) = (
			  $self->co->default("happiness", "correl_cutoff"),
			  $self->co->default("happiness", "correl_scale"),
			 );
  my %all = $self->all_correl;
  my @order = sort {abs($all{$b}) <=> abs($all{$a})} (keys %all);
  my $count  = 0;
  foreach my $k (@order) {
    last if (abs($all{$k}) < $cutoff);
    ++$count;
  };
  my $penalty = $count * $scale;
  my $s = ($count > 1) ? q{s} : q{};
  my $summary = ($count)
    ? sprintf("%d correlation%s above %.3f for a penalty of %.3f\n", $count, $s, $cutoff, $penalty)
    : q{};
  return ($penalty, $summary);
};

1;


=head1 NAME

Demeter::Fit::Happiness - Semantic evaluation of an EXAFS fit

=head1 VERSION

This documentation refers to Demeter version 0.9.10.

=head1 SYNOPSIS

After a fit finishes, Demeter evaluates a semantic (i.e.
non-statistical) parameter for the fit based on the R-factor, path
parameter values, restraints, and other aspects of the fit.  This
parameter is a tunable, I<ad hoc> measure of how happy the fit will
make the person running the fit.

=head1 DESCRIPTION

Ifeffit, and therefor Demeter, offers a number of parameters after the
completion of the fit.  These include the chi-square, the reduced
chi-square, an R-factor, error bars, uncertainties, and restraint
evaluations.  These various parameters serve different purposes.  The
chi-square is the actual fitting metric, i.e. the quantity which is
minimized in the fit.  The reduced chi-square is the fitting metric
normalized by the degrees of freedom (i.e. the difference in the
number of independent points and the number of guess parameters used)
and is a true statistical parameter.  The reduced chi-square can be
used to compare two different fitting models against a data set.  The
R-factor is merely a percentage misfit, a numerical measure of how
well the fit over-plots the data.  Taken together the reduced
chi-square and the R-factor go a long way towards helping you evaluate
your fit.

Unfortunately, the EXAFS fitting problem is not a well-defined
Gaussian fitting problem.  That's a shame, given that Ifeffit applies
the concepts of Gaussian statistics.  In principle, one can do much
better than a simple application of Gaussian statistics.  Several
workers, notably Krappe and Rossner, have applied Bayesian concepts to
the EXAFS problem.  In practice Demeter uses Ifeffit because Ifeffit
offers so many useful tools for arbitrary model building.
Consequently, Demeter and its users need to find a way to live with
the shortcomings of the Gaussian approach to the EXAFS problem.

A blind reliance on the reduced chi-square and the R-factor is not a
good idea.  Because the EXAFS problem is so ill-posed in the Gaussian
sense, reduced chi-square is almost never close to 1 -- even tough
that is the definition of a good a fit in Gaussian statistics.
Consequently, reduced chi-square can only be used to compare fits.  It
may not be used to evaluate the quality of a single fit.

The R-factor is even more problematic.  It merely tells you whether
the fit closely over-plots the data.  It does nothing to evaluate
whether the results of the fit make any kind of physical sense.  Those
sorts of value judgments are the responsibility of the EXAFS
practitioner.  She must consider whether the best fit values are
physically sensible, whether the error bars and correlations are
acceptible, and whether the path parameters evaluate to sensible
values.  These value judgments, along the reduced chi-square and the
R-factor, go into the assessment of the fit.

Fortunately, we know a lot about what an EXAFS fit should do.  For
instance,

=over 4

=item *

It should have a small R-factor (although a fit performed in k
space will always have a large R-factor).

=item *

The number of variables should be considerably less than the number of
independent points.

=item *

The S02 and sigma2 path parameters should not be negative.

=item *

The e0, deltaR and sigma2 path parameters should not be too big.

=item *

Fitting parameters should not be too highly correlated.

=back

This module introduces an entirely semantic (i.e. non-statistical, I<ad
hoc>, and non-publishable) parameter which attempts to quantify all of
the above.  This parameter is called the I<happiness>.  This name is
chosen , in part, because it can serve as an indication of how happy
the fit should make you and, in part, because it is a silly idea that
should not be taken too seriously.  (I feel obliged to point out that
happiness in the abstract is not silly, merely the notion that your
EXAFS software can quantify happiness!)

The output is a number between 0 and 100.  A happiness of 100 is the
happiest possible fit.  A happiness of 0 should make you very sad
indeed.  The happiness number is reported in the log file.  A good use
of the happiness would be to provide a visual cue in a graphical
interface.  For example, a region of the screen could glow green when
the happiness is above 90 and red when it is below 60, with values in
between producing colors that run the spectrum between red and green.
That is the sense in which happiness is a semantic parameter.  It does
not provide you with a number that you can quote in the scientific
literature, but it provides a way for software to suggest how pleased
you are liable to be once the fit completes.  Even better, it provides
a clue that something may have gone awry in a bad fit.  In particular,
it evaluates more of the fit than just the percentage misfit.  A fit
with a small R-factor and unreasonable path parameter values should be
an unhappy fit.

The idea for a semantic parameter of this sort came from a radio piece
(I think it was Eight Forty-Eight on Chicago Public Radio) I heard on
a device called L<The Ambient
Orb|http://www.ambientdevices.com/cat/orb/orborder.html>.  The idea of
this device is that it snarfs stock data from the internet and glows
green when the market is up and red when the market is down.  This
provides a semantic, ambient indication of the state of one's stock
portfolio.  The part that interested me when I first heard about this
is that users of the orb tend to be less anxious about their stock
portfolios.  Rather than needing to continuously check etrade.com, one
can glance a splash of color out of the corner of the eye.  I like the
thought of having a visual indicator of how well a fit is working out
while in the middle of a lengthy analysis session.

The current version of the happiness parameter works like this:

=over 4

=item I<initial value>

The happiness starts at 100%, i.e. fully happy.  Each of the
parameters used to evaluate the happiness can only subtract from the
happiness.  Each parameter is checked in turn for its diminution of
the happiness.

=item I<R-factor>

An R-factor below 0.02 is a happy R-factor.  An R-factor between 0.02
and 0.06 diminishes the happiness by this formula:

     (R - 0.02) * 1000

Thus an R-factor of 0.03 reduces the happiness by 10.  An R-factor in
excess of 0.06 incurs the full hit of 40 to the happiness.

The R-factor of a fit in k-space will almost always be large due the
effect of higher frequencies on the evaluation of the R-factor.  Thus
the scaling factor for the R-factor penalty is made 1/10 as big.

=item I<parameter values>

Perform the sanity checks in L<Demeter::Path::Sanity>.
Penalize the happiness by 2 for each path parameter that fails a
sanity check.

=item I<restraints>

The restraints are added as fractional contributions to the evaluated
chi-square and multiplied by a scaling factor.

     (restraint / chi-square) * scale

Thus a restraint that involves a guess parameter wandering farther
away from its nominal value diminishes the happiness more.  This works
well with the C<penalty> function.  When the guess parameter is within
its boundaries, the restraint will not diminish happiness.

=item I<nidp>

Diminish happiness if the number of variables used is too large
compared to the number of independent points.  The full penalty is
applied when all independent points are used.  No penalty is applied
if less than 2/3 of the independent points are used.

=item I<correlations>

Diminish happiness for each correlation above a certain value.  No
penalty is applied if no correlations are too high.

=back

=head1 METHODS

=over 4

=item C<happiness>

This method evaluates the happiness for a fit.

In list context, the return values are the net numerical value of the
happiness and a text string summarizing each of the penalties against
the happiness.

   ($happpiness_value, $happiness_summary) = $fitobject -> happiness;

In scalar context, just the numerical value is returned.

   $happpiness_value = $fitobject -> happiness;

=item C<color>

This method returns a color representation of the happiness as a
hexadecimal triplet.

   print $fit->color;
    ==prints==>
     #E2E995

This is intended as a visual representation of the happiness and could
be used to color a GUI element as an ambient cue as to the quality of
the fit.  It takes four parameters.  Three are colors representing the
best fit, the worst fit, and an average fit.  The last parameter is
the happiness value that represents the worst fit.  For instance:

   good fit           #C5E49A   a greenish color
   average fit        #FFEE90   a yellowish color
   bad fit            #FD7E6F   a reddish color
   minimum happiness  60

For happiness values between 60 and 80, the color is the linear
interpolation between the bad and average colors.  For happiness
values between 80 and 100, the color is the linear interpolation
between the average and good colors.

=back

=head1 CONFIGURATION AND ENVIRONMENT

See L<Demeter::Config> for a description of the configuration
system.

The following parameters are configurable so that the happiness
algorithm can be tuned.  See the happiness group of configuration
parameters.

=over 4

=item I<R-factor>

The boundary values and the scaling factor.  Defaults: 0.02, 0.06,
1000.  The scaling factor is reduced to 1/10 its value for a fit in
k-space.

=item I<parameter values>

The per-failure penalty.  Default: 2.  Each penalty is configurable
using the parameters in the warnings group.

=item I<restraints>

The scaling factor. Default: 10.

=item I<nidp>

The cutoff and the scaling factor. Defaults: 2/3 and 40.

=item I<correlations>

The cutoff and the penalty for each high correlation. Defaults: 0.95
and 3.

=back

=head1 DEPENDENCIES

Demeter's dependencies are in the F<Bundle/DemeterBundle.pm> file.

=head1 BUGS AND LIMITATIONS

Aside from the obvious limitation that happiness is a non-statistical,
I<ad hoc>, non-reportable, and possibly ridiculous parameter, work
needs to be done to tune the various happiness and warnings
parameters.

Other possible penalties:

=over 4

=item *

The stated formula for computing the restraint penalty results in much
too small of a penalty since chi_square is typically much larger than
the restraint evaluation.  I am currently playing with just
multiplying the restraint evaluation by the scaling factor.

=item *

Compare reff of each path to the fitting range.  Penalize paths well
outside the range (which is probably not such a bad thing) or a range
well beyond the longest path (which is certainly a bad thing in that
it indicates an attempt to inflate Nidp).

=item *

Penalize the use of many e0 parameters, determined by comparing how
many different e0 path param values there are among the paths.  The
penalty should apply if the number of e0s is greater than the number
of data sets.

=item *

Penalty parameter type -- like an after parameter but explicitly for
defining new penalties.

=item *

Plugin architecture for user-defined penalties

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
