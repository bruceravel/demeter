package Demeter::PeakFit;

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
use autodie qw(open close);

use Moose;
extends 'Demeter';
with 'Demeter::Data::Arrays';

use MooseX::Aliases;
use Moose::Util::TypeConstraints;
use Demeter::StrTypes qw( Empty FitykFunction );

use Fityk;

use List::Util qw(min);
use List::MoreUtils qw(any none);

if ($Demeter::mode->ui eq 'screen') {
  with 'Demeter::UI::Screen::Pause';
  with 'Demeter::UI::Screen::Progress';
};

my $FITYK = Fityk::Fityk->new;
$FITYK->execute('define Atan(step=1, e0=0, width=1) = step*(atan((x-e0)/width)/pi + 0.5)');
$FITYK->execute('define Erf(step=0.5, e0=0, width=1) = step*(erf((x-e0)/width) + 1)');

has '+plottable'   => (default => 1);
has '+data'        => (isa => Empty.'|Demeter::Data|Demeter::XES');
has '+name'        => (default => 'PeakFit' );
has 'screen'       => (is => 'rw', isa => 'Bool',   default => 0);
has 'fityk'        => (is => 'rw', isa => 'Bool',   default => 1);

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

sub add {
  my ($self, $function, @args) = @_;
  $function = $self->normalize_function($function);
  croak("$function is not a valid Fityk lineshape") if not is_FitykFunction($function);

  my %args = @args;
  $args{a0} = $args{height} || 0;
  $args{a1} = $args{center} || 0;
  $args{a2} = $args{hwhm}   || 0;
  $args{name} ||= 'Lineshape';
  ## set defaults of things

  my $this = Demeter::PeakFit::LineShape->new(function=>$function,
					      a0 => $args{a0}, a1 => $args{a1}, a2 => $args{a2},
					      name => $args{name},
					      parent => $self,
					     );

  my $start = 0;
  foreach my $in_model (@{$self->lineshapes}) {
    $start += $in_model->np;
  };
  $this->start($start);

  $self->push_lineshapes($this);
};

sub normalize_function {
  my ($self, $function) = @_;
  foreach my $f (@Demeter::StrTypes::fitykfunction_list) {
    return $f if (lc($function) eq lc($f));
  };
  return 0;
};

sub fit {
  my ($self) = @_;
  $self->start_spinner("Demeter is performing a peak fit") if ($self->mo->ui eq 'screen');

  ## this does the right stuff for XES/Data
  my ($emin, $emax) = $self->data->prep_peakfit($self->xmin, $self->xmax);
  $self->xmin($emin);
  $self->xmax($emax);

  ## import data into Fityk
  #$FITYK->load_data(0, \@x, \@y, \@s, $self->name);
  if (@{$self->linegroups}) {    # clean up from previous fit
    my $string = 'delete ' . join(', ', @{$self->linegroups});
    $self->dispose_to_fityk($string);
  };
  my $file = $self->po->tempfile;
  $self->data->points(file    => $file,
		      space   => 'E',
		      suffix  => $self->yaxis,
		      shift   => $self->data->eshift,
		      scale   => $self->data->plot_multiplier,
		      yoffset => $self->data->y_offset
		     );
  $self->dispose_to_fityk('@0 < '.$file);
  $self->dispose_to_fityk("A = ($emin < x and x < $emax)");
  $self->dispose_to_fityk('@0.F=0');

  #print $FITYK->get_data(0)->size, $/;
  ## define each lineshape
  my @all = ();
  foreach my $ls (@{$self->lineshapes}) {
    $ls->set(xmin=>$emin, xmax=>$emax);
    $self->dispose_to_fityk($ls->define);
    #print $FITYK->get_info('%'.$ls->group, 1), $/;
    push @all, '%'.$ls->group;
  };
  $self -> linegroups(\@all);

  $self->dispose_to_fityk('fit in @0');
  my @data_x = $self->fetch_data_x;
  my @model_y = @{ $FITYK->get_model_vector(\@data_x, 0) };
  Ifeffit::put_array($self->group.".energy", \@data_x);
  Ifeffit::put_array($self->group.".".$self->yaxis, \@model_y);

  ## gather arrays for each lineshape
  foreach my $ls (@{$self->lineshapes}) {
    $ls->put_arrays(\@data_x);
  };
  $self->dispose_to_fityk('@0.F=0');
  $self->dispose_to_fityk('@0.F=' . join(' + ', @all));

  $self->fetch_statistics;

  $self->stop_spinner if ($self->mo->ui eq 'screen');
  return $self;
};

sub fetch_statistics {
  my ($self) = @_;
  ## convert the error text into a list of lists
  my $text = $FITYK->get_info('errors');
  my @results = ();
  foreach my $line (split("\n", $text)) {
    next if ($line =~ m{\AStandard});
    my @fields = split(/\s+[=+-]+\s+/, $line);
    push @results, \@fields;
  };
  foreach my $ls (@{$self->lineshapes}) {
    my $count = 0;
    foreach (1..$ls->np) {
      my $r = shift @results;
      my $att = 'a'.$count;
      $ls->$att($r->[1]);
      $att = 'e'.$count;
      $ls->$att($r->[2]);
      ++$count;
    };
  };
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

sub fityk_object {
  my ($self) = @_;
  return $FITYK;
};

sub plot {
  my ($self) = @_;
  $self->dispose($self->template('plot', 'overpeak'), 'plotting');
  $self->po->increment;
  return $self;
};

sub dispose_to_fityk {
  my ($self, $string) = @_;
  local $| = 1;
  if ($self->screen) {
    my ($start, $end) = ($self->mo->ui eq 'screen') ? $self->_ansify(q{}, 'fityk') : (q{}, q{});
    print $start, $string, $end, $/;
  };
  $FITYK->execute($string) if $self->fityk;
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

1;
