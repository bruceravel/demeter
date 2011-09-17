package Demeter::PeakFit;

=for Copyright
 .
 Copyright (c) 2006-2011 Bruce Ravel (bravel AT bnl DOT gov).
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
use autodie qw(open close);

use Moose;
extends 'Demeter';
with 'Demeter::Data::Arrays';

use MooseX::Aliases;
use Moose::Util qw(apply_all_roles);
use Moose::Util::TypeConstraints;
use Demeter::StrTypes qw( Empty );

use File::Spec;
use List::Util qw(min max);
use List::MoreUtils qw(any none);
use String::Random qw(random_string);

if ($Demeter::mode->ui eq 'screen') {
  with 'Demeter::UI::Screen::Pause';
  with 'Demeter::UI::Screen::Progress';
};

has '+plottable'   => (default => 1);
has '+data'        => (isa => Empty.'|Demeter::Data|Demeter::XES');
has '+name'        => (default => 'PeakFit' );
has 'engine'       => (is => 'rw', isa => 'Bool',   default => 1);
has 'screen'       => (is => 'rw', isa => 'Bool',   default => 0);
has 'buffer'       => (is => 'rw', isa => 'ArrayRef | ScalarRef');

has 'xaxis'        => (is => 'rw', isa => 'Str',    default => q{energy});
has 'yaxis'        => (is => 'rw', isa => 'Str',    default => q{flat});
has 'sigma'        => (is => 'rw', isa => 'Str',    default => q{});

has 'xmin'         => (is => 'rw', isa => 'Num',    default => 0);
has 'xmax'         => (is => 'rw', isa => 'Num',    default => 0);

has 'lineshapes'   => (
		       metaclass => 'Collection::Array',
		       is        => 'rw',
		       isa       => 'ArrayRef[Demeter::PeakFit::LineShape]',
		       default   => sub { [] },
		       provides  => {
				     'push'    => 'push_lineshapes',
				     'pop'     => 'pop_lineshapes',
				     'shift'   => 'shift_lineshapes',
				     'unshift' => 'unshift_lineshapes',
				     'clear'   => 'clear_lineshapes',
				    },
		      );
has 'linegroups'   => (
		       metaclass => 'Collection::Array',
		       is        => 'rw',
		       isa       => 'ArrayRef[Str]',
		       default   => sub { [] },
		       provides  => {
				     'push'    => 'push_linegroups',
				     'pop'     => 'pop_linegroups',
				     'shift'   => 'shift_linegroups',
				     'unshift' => 'unshift_linegroups',
				     'clear'   => 'clear_linegroups',
				    },
		      );

has 'tempfiles' => (
		    metaclass => 'Collection::Array',
		    is        => 'rw',
		    isa       => 'ArrayRef[Str]',
		    default   => sub { [] },
		    provides  => {
				  'push'  => 'add_tempfile',
				  'pop'   => 'remove_tempfile',
				  'clear' => 'clear_tempfiles',
				 }
		   );

enum 'PeakFitBackends' => ['ifeffit', 'fityk'];
coerce 'PeakFitBackends',
  from 'Str',
  via { lc($_) };
has backend => (is => 'rw', isa => 'PeakFitBackends', coerce => 1, alias => 'md',
		trigger => sub{my ($self, $new) = @_;
			       if ($new eq 'ifeffit') {
				 eval {apply_all_roles($self, 'Demeter::PeakFit::Ifeffit')};
				 print $@;
				 $@ and die("PeakFit backend Demeter::PeakFit::Ifeffit could not be loaded");
				 $self->initialize;
			       } elsif ($new eq 'fityk') {
				 eval {apply_all_roles($self, 'Demeter::PeakFit::Fityk')};
				 $@ and die("PeakFit backend Demeter::PeakFit::Fityk does not exist");
				 $self->initialize;
			       } else {
				 eval {apply_all_roles($self, 'Demeter::PeakFit'.$new)};
				 $@ and die("PeakFit backend Demeter::PeakFit::$new does not exist");
				 $self->initialize;
			       };
			     });

sub BUILD {
  my ($self, @params) = @_;
  $self->mo->push_PeakFit($self);
  return $self;
};


sub cleantemp {
  my ($self) = @_;
  foreach my $f (@{ $self->tempfiles }) {
    unlink $f;
  };
  $self -> clear_tempfiles;
  return $self;
};

sub add {
  my ($self, $function, @args) = @_;
  $function = $self->normalize_function($function);
  croak("$function is not a valid lineshape") if not $self->valid($function);

  my %args = @args;
  $args{a0} = $args{height} || $args{m} || 0;
  $args{a1} = $args{center} || $args{b} || 0;
  $args{a2} = $args{hwhm}   || $args{sigma} || $args{width} || 0;
  $args{a3} = $args{eta}    || 0;
  $args{name} ||= 'Lineshape';
  ## set defaults of things

  my $this = Demeter::PeakFit::LineShape->new(function=>$function,
					      a0 => $args{a0}, a1 => $args{a1}, a2 => $args{a2}, a3 => $args{a3},
					      name => $args{name},
					      parent => $self,
					     );

  my $start = 0;
  foreach my $in_model (@{$self->lineshapes}) {
    $start += $in_model->np;
  };
  $this->start($start);		# what is this?

  $self->push_lineshapes($this);
  return $this;
};


sub fit {
  my ($self) = @_;
  $self->start_spinner("Demeter is performing a peak fit") if ($self->mo->ui eq 'screen');

  ## this does the right stuff for XES/Data
  my ($emin, $emax) = $self->data->prep_peakfit($self->xmin, $self->xmax);
  $self->xmin($emin);
  $self->xmax($emax);

  $self->cleantemp;

  ## import data into Fityk
  #$FITYK->load_data(0, \@x, \@y, \@s, $self->name);
  if (@{$self->linegroups}) {    # clean up from previous fit
    $self->cleanup(@{$self->linegroups});
    $self->clear_linegroups;
  };
  $self->prep_data;

  ## define each lineshape
  my @all = ();
  foreach my $ls (@{$self->lineshapes}) {
    $ls->set(xmin=>$emin, xmax=>$emax);
    $self->define($ls);
    push @all, $self->sigil.$ls->group;
  };
  $self -> linegroups(\@all);

  $self->pf_dispose($self->fit_command);
  my @data_x = $self->fetch_data_x;
  my @model_y = $self->fetch_model_y(\@data_x);
  Ifeffit::put_array($self->group.".energy", \@data_x);
  Ifeffit::put_array($self->group.".".$self->yaxis, \@model_y);
  $self -> dispose(sprintf("set %s.res = %s.%s - %s.%s", $self->group, $self->data->group, $self->yaxis, $self->group, $self->yaxis));

  ## gather arrays for each lineshape
  foreach my $ls (@{$self->lineshapes}) {
    $ls->put_arrays(\@data_x);
  };
  $self->pf_dispose($self->init_data);
  $self->pf_dispose($self->set_model(join(' + ', @all)));

  $self->fetch_statistics;

  $self->stop_spinner if ($self->mo->ui eq 'screen');
  return $self;
};



sub plot {
  my ($self) = @_;
  $self->dispose($self->template('plot', 'overpeak'), 'plotting');
  $self->po->increment;
  if ($self->po->plot_res) {
    ## prep the residual plot
    my $save = $self->yaxis;
    my $yoff = $self->data->y_offset;
    $self->yaxis('res');
    $self->data->plotkey('residual');
    my @y = $self->data->get_array($save);
    $self->data->y_offset($self->data->y_offset - 0.1*max(@y));

    $self->dispose($self->template('plot', 'overpeak'), 'plotting');

    ## restore values and increment the plot
    $self->yaxis($save);
    $self->data->plotkey(q{});
    $self->data->y_offset($yoff);
    $self->po->increment;
  };
  return $self;
};


sub report {
  my ($self) = @_;
  my $string = q{};
  foreach my $ls (@{$self->lineshapes}) {
    $string .= $ls->report;
  };
  return $string;
};

__PACKAGE__->meta->make_immutable;
1;


=head1 NAME

Demeter::PeakFit - A peak fitting object for Demeter

=head1 VERSION

This documentation refers to Demeter version 0.5.

=head1 SYNOPSIS

Here is a simple fit of three peak shapes to normalized XES data.

  #!/usr/bin/perl
  use Demeter qw(:ui=screen :plotwith=gnuplot);

  my $xes = Demeter::XES->new(file=>'../XES/7725.11',
                              energy => 2, emission => 3,
                              e1 => 7610, e2 => 7624, e3 => 7664, e4 => 7690,
                             );
  my $peak = Demeter::PeakFit->new(screen => 0, yaxis=> 'norm', name=>'fit');
  $peak -> data($xes);

  $peak -> add('gaussian',   center=>7649.5, name=>'peak 1');
  $peak -> add('gaussian',   center=>7647.7, name=>'peak 2');
  $peak -> add('lorentzian', center=>7636.8, name=>'peak 3');

  $peak -> fit;
  print $peak -> report;
  $_  -> plot('norm') foreach ($xes, $peak, @{$peak->lineshapes});
  $peak -> pause;

=head1 DESCRIPTION

This object is a sort of container for holding Data (either XANES data
in a normal Data object or XES data in an XES object) along with some
number of lineshapes.  It organizes the parameterization of the
lineshapes and shuffles all of this off to the fitting engine for
fitting, all wihtout having to master whatever quirky syntax it might
have.

=head1 FITTING ENGINES

This module provides an abstract framework for enabling peak fitting
in Demeter.  This abstraction allows (well ... in principle) the use
of various backends for performing the actual fit.  Currently the only
one available is Fityk (http://www.unipress.waw.pl/fityk/), which is
implemented as L<Demeter::PeakFit::Fityk>.  I plan to implement an
Ifeffit backend in te future.

Any suggestions?

=head1 ATTRIBUTES

=over 4

=item C<screen> (boolean) [0]

This is a flag telling Demeter to echo instructions to the screen.

=item C<engine> (boolean) [1]

This is a flag telling Demeter to echo instructions to the fitting engine
process.

=item C<buffer>

Dispose commands to a string or array when given a reference to a
string or array.  This allows you to accumulate instructions in a
string or an array an save them for future use, e.g. writing a script
or displaying a text widget in a GUI.

=item C<xaxis> (string) [energy]

The string denoting the array containing the ordinate axis of the
data.  For most XANES and XES data, this is C<energy>.

=item C<yaxis> (string) [flat]

The string denoting the array containing the abscisa axis of the data.
For most XANES, this is typically either C<flat> or C<norm>.  For XES
data, this might be C<raw>, C<sub>, or C<norm>.  Note that the default
will trigger an error if you try to fit XES data without changing its
value appropriately.

=item C<sigma> (string) []

The string denoting the array containing the varience of the data.

=item C<xmin> (float)

The lower bound of the fit range.  For XANES data, this will be
interpreted relative to the edge, while for XES data it is
intepretated as an absolute energy.

=item C<xmax> (float)

The upper bound of the fit range.  For XANES data, this will be
interpreted relative to the edge, while for XES data it is
intepretated as an absolute energy.

=item C<lineshapes>

This contains a reference to the array of LineShape objects included
in the fit.  This array can be manipulated with the standard Moose-y
sort of automatically generated methods:

  push_lineshapes
  pop_lineshapes
  shift_lineshapes
  unshift_lineshapes
  clear_lineshapes

=back

=head1 METHODS

=over 4

=item C<add>

Use this to add new lineshapes to the fitting model.

  $ls = $peak -> add("Gaussian", center => 4967, name => "First peak")

This returns a F<Demeter::PeakFit::LineShape> object.  This is the
standard way of creating such an object as this properly associates
the LineShape object with the current peak fitting effort.  It should
never be necessary (or desirable) to create a LineShape by hand.

=item C<fit>

Perform the fit after adding one or more LineShapes.

  $peak -> fit;

After the fit finishes, the statistics of the fit will be accumulated
from the fitting engine and stored in this and all the LineShape
objects.

=item C<engine_objectt>

This returns the object for interacting with the fitting engine (if
there is one).  This is used extensively by
F<Demeter::PeakFit::LineShape>.

=item C<plot>

Use this to plot the result of the fit.  Note that this only plots the
full model and (optionally) the residual.  To plot the individual
function, use the C<plot> method of the the LineShape object.

This plots the data along with the fitting model and each function:

  $xanes_data -> po -> e_norm(1);
  $_ -> plot('E') foreach ($xanes_data, $peak, @{$peak->lineshapes});

Note that the C('E') argument and the setting of C<e_norm> are ignored
by the PeakFit and LineShape objects, but they are required to plot a
fit to XANES data as the fit is made to the normalized data.  In fact,
the fit is made to the flattened data if the Data's C<bkg_flatten>
attribute is true.

For a fit to raw XES data, you might make the plot like so:

  $_ -> plot('raw') foreach ($xanes_data, $peak, @{$peak->lineshapes});

Specifically, you want to plot the data in the manner indicated by the
C<yaxis> attribute of the PeakFit object, which indicates the form of
the data used in the fit.

When the PeakFit object is plotted, the residual from the fit will
also be plotted if the C<plot_res> attribute of the Plot object is
true.

=item C<pf_dispose>

This is the choke point for sending instructions to the fitting
engine, much like the normal C<dispose> method handles text intended
for Ifeffit or Gnuplot.  See the descriptions of the C<engine> and
C<screen> attributes.

=item C<report>

This returns a tring summarizing the results of a fit.

  print $peak->report;

=back

=head1 CONFIGURATION AND ENVIRONMENT

See L<Demeter::Config> for a description of the configuration system.

=head1 DEPENDENCIES

Demeter's dependencies are in the F<Bundle/DemeterBundle.pm> file.

=head1 BUGS AND LIMITATIONS

=over 4

=item *

How to capture errors without bailing?

=item *

more testing with xanes data

=item *

better interface for fixing parameters

=item *

need to test more functions

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
