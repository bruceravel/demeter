package Demeter::LCF;

=for Copyright
 .resid
 Copyright (c) 2006-2010 Bruce Ravel (bravel AT bnl DOT gov).
 All rights reserved.
 .transmission
 This file is free software; you can redistribute it and/or
 modify it under the same terms as Perl itself. See The Perl
 Artistic License.
 .-$self->data->bkg_e0
 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut

use Carp;

use Moose;
extends 'Demeter';
with 'Demeter::Data::Arrays';

use MooseX::Aliases;
use Moose::Util::TypeConstraints;
use Demeter::StrTypes qw( Empty );

if ($Demeter::mode->ui eq 'screen') {
  with 'Demeter::UI::Screen::Pause';
  with 'Demeter::UI::Screen::Spinner';
};

has '+plottable'  => (default => 1);
has '+data'       => (isa => Empty.'|Demeter::Data');
has '+name'       => (default => 'LCF',);

has 'xmin'  => (is => 'rw', isa => 'Num',    default => 0);
has 'xmax'  => (is => 'rw', isa => 'Num',    default => 0);
has 'space' => (is => 'rw', isa => 'Str',    default => q{norm},  # deriv chi
		trigger => sub{my ($self, $new) = @_;
			       $self->suffix(q{norm}), $self->space_description('normalized mu(E)') if ((lc($new) =~ m{\Anor}) and $self->data and (not $self->data->bkg_flatten));
			       $self->suffix(q{flat}), $self->space_description('flatteneed mu(E)') if ((lc($new) =~ m{\Anor}) and $self->data and ($self->data->bkg_flatten));
			       $self->suffix(q{nder}), $self->space_description('derivative mu(E)') if  (lc($new) =~ m{\An?der});
			       $self->suffix(q{chi}),  $self->space_description('chi(k)')           if  (lc($new) =~ m{\Achi});
			      });
has 'suffix' => (is => 'rw', isa => 'Str',    default => q{flat});
has 'space_description' => (is => 'rw', isa => 'Str',    default => q{flattened mu(E)});
has 'noise'  => (is => 'rw', isa => 'Num',    default => 0);

has 'max_standards' => (is => 'rw', isa => 'Int', default => 4);

has 'linear'    => (is => 'rw', isa => 'Bool',    default => 0);
has 'inclusive' => (is => 'rw', isa => 'Bool',    default => 0);
has 'unity'     => (is => 'rw', isa => 'Bool',    default => 1);
has 'one_e0'    => (is => 'rw', isa => 'Bool',    default => 0);

has 'plot_components' => (is => 'rw', isa => 'Bool',    default => 0);
has 'plot_difference' => (is => 'rw', isa => 'Bool',    default => 0);
has 'plot_indicators' => (is => 'rw', isa => 'Bool',    default => 1);

has 'nstan'     => (is => 'rw', isa => 'Int', default => 0);
has 'npoints'   => (is => 'rw', isa => 'Int', default => 0);
has 'nvarys'    => (is => 'rw', isa => 'Int', default => 0);
has 'ntitles'   => (is => 'rw', isa => 'Int', default => 0);
has 'standards' => (
		    metaclass => 'Collection::Array',
		    is        => 'rw',
		    isa       => 'ArrayRef[Demeter::Data]',
		    default   => sub { [] },
		    provides  => {
				  'push'    => 'push_standards',
				  'pop'     => 'pop_standards',
				  'shift'   => 'shift_standards',
				  'unshift' => 'unshift_standards',
				  'clear'   => 'clear_standards',
				 },
		   );
has 'options' => (
		  metaclass => 'Collection::Hash',
		  is        => 'rw',
		  isa       => 'HashRef[ArrayRef]',
		  default   => sub { +{} },
		  provides  => {
				set   => 'set_option',
				get   => 'get_option',
				keys  => 'get_option_list'
			       }
		 );
has 'rfactor' => (is => 'rw', isa => 'Num', default => 0);
has 'chisqr'  => (is => 'rw', isa => 'Num', default => 0);
has 'chinu'   => (is => 'rw', isa => 'Num', default => 0);
has 'scaleby' => (is => 'rw', isa => 'Num', default => 0);


sub BUILD {
  my ($self, @params) = @_;
  $self->mo->push_LCF($self);
};

## float_e0  require
sub add {
  my ($self, $stan, @params) = @_;
  my %hash = @params;
  $hash{float_e0} ||= 0;
  $hash{required} ||= 0;
  $hash{e0}       ||= 0;
  my @previous = @{ $self->standards };
  $self->push_standards($stan);

  my $n = $#{ $self->standards } + 1;
  $self->nstan($n);
  $hash{weight}   ||= sprintf("%.3f", 1/$n);

  my $key = $stan->group;
  $self->set_option($key, [$hash{float_e0}, $hash{required}, $hash{weight}, 0, $hash{e0}, 0]); ## other 2 are dweight and de0

  foreach my $prev (@previous) {
    $self->weight($prev, (1-$hash{weight})/($n-1));
  };
  return $self;
};

sub add_many {
  my ($self, @standards) = @_;
  $self->add($_) foreach (@standards);
  return $self;
};

sub float_e0 {
  my ($self, $stan, $onoff) = @_;
  $onoff ||= 0;
  my $rlist = $self->get_option($stan->group);
  my @params = @$rlist;
  $params[0] = $onoff;
  return $self;
};

sub required {
  my ($self, $stan, $onoff) = @_;
  $onoff ||= 0;
  my $rlist = $self->get_option($stan->group);
  my @params = @$rlist;
  $params[1] = $onoff;
  $self->set_option(\@params);
  return $self;
};

sub weight {
  my ($self, $stan, $value, $error) = @_;
  my $rlist = $self->get_option($stan->group);
  my @params = @$rlist;
  return ($params[2], $params[3]) if (not defined($value));
  $params[2] = $value;
  $params[3] = $error || 0;
  $self->set_option($stan->group, \@params);
  return ($params[2], $params[3]);
};

sub e0 {
  my ($self, $stan, $value, $error) = @_;
  my $rlist = $self->get_option($stan->group);
  my @params = @$rlist;
  return ($params[4], $params[5]) if (not defined($value));
  $params[4] = $value;
  $params[5] = $error || 0;
  $self->set_option($stan->group, \@params);
  return ($params[4], $params[5]);
};

sub standards_list {
  my ($self) = @_;
  return map {$_->group} (@{$self->standards});
};

sub _sanity {
  my ($self) = @_;
  if (ref($self->data) !~ m{Data}) {
    croak("** LCF: You have not set the data for your LCF fit");
  };
  if ($#{$self->standards} < 1) {
    croak("** LCF: You have not set 2 or more standards for your LCF fit");
  };
  if ($self->xmin > $self->xmax) {
    my ($xn, $xx) = $self->get(qw(xmin xmax));
    $self->set(xmin=>$xx, xmax=>$xn);
    carp("** LCF: xmin and xmax were out of order");
  };
  return $self;
};

sub fit {
  my ($self) = @_;
  $self->_sanity;

  $self->start_spinner("Demeter is performing an LCF fit") if ($self->mo->ui eq 'screen');
  #my ($how) = ($self->suffix eq 'chi') ? 'fft' : 'background';
  $self->data->_update('fft');
  $_ -> _update('fft') foreach (@{ $self->standards });

  ## prepare the data for LCF fitting
  my $n1 = $self->data->iofx('energy', $self->xmin);
  my $n2 = $self->data->iofx('energy', $self->xmax);
  $self -> dispose($self->template("analysis", "lcf_prep", {n1=>$n1, n2=>$n2}));

  ## interpolate all the standards onto the grid of the data
  $self->mo->standard($self);
  my @all = @{ $self->standards };
  foreach my $stan (@all[0..$#all-1]) {
    $stan -> dispose($stan->template("analysis", "lcf_prep_standard"));
  };
  if ($self->unity) {
    $all[-1] -> dispose($all[-1]->template("analysis", "lcf_prep_last"));
  } else {
    $all[-1] -> dispose($all[-1]->template("analysis", "lcf_prep_standard"));
  };

  ## create the array to minimize and perform the fit
  $self -> dispose($self->template("analysis", "lcf_fit"));

  my $sumsqr = 0;
  foreach my $st (@all) {
    my ($w, $dw) = $self->weight($st, Ifeffit::get_scalar("aa_".$st->group), Ifeffit::get_scalar("delta_a_".$st->group));
    $sumsqr += $dw**2;
  };
  if ($self->unity) {		# propagate uncertainty for last amplitude
    my ($w, $dw) = $self->weight($all[-1]);
    $self->weight($all[-1], $w, sqrt($sumsqr));
  };
  $self->_statistics;

  $self->stop_spinner if ($self->mo->ui eq 'screen');
  return $self;
};

sub _statistics {
  my ($self) = @_;
  my @x     = $self->get_array('x');
  my @func  = $self->get_array('func');
  my @resid = $self->get_array('resid');
  my ($avg, $count, $rfact, $sumsqr) = (0,0,0,0);
  foreach my $i (0 .. $#x) {
    next if ($x[$i] < $self->xmin);
    next if ($x[$i] > $self->xmax);
    ++$count;
    $avg += $func[$i];
  };
  $avg /= $count;
  foreach my $i (0 .. $#x) {
    next if ($x[$i] < $self->xmin);
    next if ($x[$i] > $self->xmax);
    $rfact  += $resid[$i]**2;
    if ($self->space eq 'nor') {
      $sumsqr += ($func[$i]-$avg)**2;
    } else {
      $sumsqr += $func[$i]**2;
    };
  };
  $self->npoints($count);
  if ($self->space eq 'nor') {
    $self->rfactor(sprintf("%.7f", $count*$rfact/$sumsqr));
  } else {
    $self->rfactor(sprintf("%.7f", $rfact/$sumsqr));
  };
  $self->chisqr(sprintf("%.5f", Ifeffit::get_scalar('chi_square')));
  $self->chinu(sprintf("%.7f", Ifeffit::get_scalar('chi_reduced')));
  $self->nvarys(Ifeffit::get_scalar('n_varys'));

  my $sum = 0;
  foreach my $stan (@{ $self->standards }) {
    my ($w, $dw) = $self->weight($stan);
    $sum += $w;
  };
  $self->scaleby(sprintf("%.3f",$sum));
  return $self;
};

sub report {
  my ($self) = @_;
  my $text = $self->template("analysis", "lcf_report");
  return $text;
};

sub plot {
  my ($self) = @_;
  $self->po->start_plot;
  $self->po->set(e_norm=>1, e_markers=>0, e_der=>0);
  $self->po->e_der(1) if ($self->space =~ m{\An?der});
  $self->data->plot('E');
  $self->dispose($self->template("plot", "overlcf"), 'plotting');
  $self->po->increment;
  if ($self->plot_difference) {
    $self->dispose($self->template("plot", "overlcf", {suffix=>'resid'}), 'plotting');
    $self->po->increment;
  };
  if ($self->plot_components) {
    foreach my $stan (@{ $self->standards }) {
      my ($w, $dw) = $self->weight($stan);
      $self->dispose($self->template("plot", "overlcf", {suffix=>$stan->group}), 'plotting');
      $self->po->increment;
    };
  };
  if ($self->plot_indicators) {
    my @indic = (Demeter::Plot::Indicator->new(space=>'E', x=>$self->xmin-$self->data->bkg_e0),
		 Demeter::Plot::Indicator->new(space=>'E', x=>$self->xmax-$self->data->bkg_e0));
    $self->data->standard;
    $_->plot('E') foreach (@indic);
  };

  return $self;
};

sub save {
  my ($self, $fname) = @_;
  my $text = $self->template('analysis', 'lcf_header');
  my @titles = split(/\n/, $text);
  $self->ntitles($#titles + 1);
  $text .= $self->template('analysis', 'lcf_save', {filename=>$fname});
  $self->dispose($text);
  return $self;
};

sub clean {
  my ($self) = @_;
  $self->dispose($self->template('analysis', 'lcf_clean'));
  return $self;
};


__PACKAGE__->meta->make_immutable;
1;


=head1 NAME

Demeter::LCF - Linear combination fitting

=head1 VERSION

This documentation refers to Demeter version 0.4.

=head1 SYNOPSIS

   #!/usr/bin/perl
   use Demeter;

   my $prj  = Demeter::Data::Prj -> new(file=>'examples/cyanobacteria.prj');
   my $lcf  = Demeter::LCF -> new;

   my $data = $prj->record(4);
   my ($metal, $chloride, $sulfide) = $prj->records(9, 11, 15);

   $lcf -> data($data);
   $lcf -> add($metal);
   $lcf -> add($chloride);
   $lcf -> add($sulfide);

   $lcf -> xmin($data->bkg_e0-20);
   $lcf -> xmax($data->bkg_e0+60);
   $lcf -> po -> set(emin=>-30, emax=>80);
   $lcf -> fit;
   $lcf -> plot;
   $lcf -> save('lcf_fit_result.dat');

=head1 DESCRIPTION

LCF ...

=head1 ATTRIBUTES

=head2 Parameters of the fit

=over 4

=item C<xmin>

The lower bound of the fit.  For a fit to the normalized or derivative
mu(E), this is an absolute energy value and B<not> relative to the
edge energy.

=item C<xmax>

The upper bound of the fit.  For a fit to the normalized or derivative
mu(E), this is an absolute energy value and B<not> relative to the
edge energy.

=item C<space>

The fitting space.  This can be one of C<nor>, C<der>, or C<chi>.

=item C<max_standards>

The maximum numer of standards to use in each fit of a combinatorial
sequence.

=item C<linear>

A boolean.  When true, add a linear term to the fit.

=item C<inclusive>

A boolean.  When true, all weights are forced to be between 0 and 1
inclusive.

=item C<unity>

A boolean.  When true, the weights are forced to sum to 1.

=item C<one_e0>

A boolean.  When true, one over-all e0 parameter is used in the fit
rather than one for each standard.

=item C<plot_components>

A boolean.  When true, the scaled components of the fit will be
included in a plot.

=item C<plot_difference>

A boolean.  When true, the residual of the fit will be included in a
plot.

=item C<plot_indicators>

A boolean.  When true, plot indicators will mark the boundaries of the
fit in a plot.

=back

=head2 Standards

=over 4

=item C<standards>

=back

=head2 Statistics

Once the fit finishes, each of the following attributes is filled with
a value appropriate to recently completed fit.

=over 4

=item C<nstan>

The number of standars used in the fit.

=item C<npoints>

The number of data points included in the fit.

=item C<nvarys>

The number of variable parameters used in the fit.

=item C<rfactor>

An R-factor for the fit.  For fits to chi(k) or the derivative
spectrum, this is an Ifeffit-normal R-factor:

   sum( [data_i - fit_i]^2 ]
  --------------------------
      sum ( data_i^2 )

For a fit to normalized mu(E), that formulation for an R-factor always
results in a really tiny number.  Demeter thus scales the R-factor to
make it somewhat closer to 10^-2.

    npoints * sum( [data_i - fit_i]^2 ]
  ---------------------------------------
        sum ( [data_i - <data>]^2 )

where <data> is the geometric mean of the data in the fitting range.


=item C<chisqr>

This is Ifeffit's chi-square for the fit.

=item C<chinu>

This is Ifeffit's reduced chi-square for the fit.

=back

=head1 METHODS

=over 4

=item C<add>

=item C<add_many>

=item C<float_e0>

=item C<required>

=item C<weight>

=item C<e0>

=item C<standards_list>

=item C<fit>

=item C<save>

=item C<report>

=item C<plot>

=item C<clean>

=back

=head1 SERIALIZATION AND DESERIALIZATION

Good question ...

=head1 CONFIGURATION AND ENVIRONMENT

See L<Demeter::Config> for a description of the configuration system.

=head1 DEPENDENCIES

Demeter's dependencies are in the F<Bundle/DemeterBundle.pm> file.

=head1 BUGS AND LIMITATIONS

=over 4

=item *

combinatorial fitting + combinatorial report

=item *

chi(k) completely undone

=item *

better sanity method

=item *

make a normal Data group

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


