package Demeter::LCF;

=for Copyright
 .
 Copyright (c) 2006-2016 Bruce Ravel (http://bruceravel.github.io/home).
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
#use Demeter::Carp;
use autodie qw(open close);

use Moose;
extends 'Demeter';
with 'Demeter::Data::Arrays';

use MooseX::Aliases;
use Moose::Util::TypeConstraints;
use Demeter::Constants qw($PI);
use Demeter::StrTypes qw( Empty );

use List::Util qw(min);
use List::MoreUtils qw(any none uniq pairwise);
use Math::Combinatorics;
use Scalar::Util qw(looks_like_number);
use Spreadsheet::WriteExcel;

if ($Demeter::mode->ui eq 'screen') {
  with 'Demeter::UI::Screen::Pause';
  with 'Demeter::UI::Screen::Progress';
};

has '+plottable'  => (default => 1);
has '+data'       => (isa => Empty.'|Demeter::Data');
has '+name'       => (default => 'LCF' );

has 'xmin'  => (is => 'rw', isa => 'LaxNum',    default => 0);
has 'xmax'  => (is => 'rw', isa => 'LaxNum',    default => 0);
has 'space' => (is => 'rw', isa => 'Str',    default => q{norm},  # deriv chi
		trigger => sub{my ($self, $new) = @_;
			       $self->suffix(q{norm}), $self->space_description('normalized mu(E)') if ((lc($new) =~ m{\Anor}) and $self->data and (not $self->data->bkg_flatten));
			       $self->suffix(q{flat}), $self->space_description('flattened mu(E)')  if ((lc($new) =~ m{\Anor}) and $self->data and ($self->data->bkg_flatten));
			       $self->suffix(q{nder}), $self->space_description('derivative mu(E)') if  (lc($new) =~ m{\An?der});
			       $self->suffix(q{chi}),  $self->space_description('chi(k)')           if  (lc($new) =~ m{\Achi});
			       $self->suffix(q{xmu}),  $self->space_description('raw mu(E)')        if  (lc($new) =~ m{\Axmu});
			      });
has 'space_description' => (is => 'rw', isa => 'Str',    default => q{flattened mu(E)});
has 'suffix'    => (is => 'rw', isa => 'Str',     default => q{flat});
has 'noise'     => (is => 'rw', isa => 'LaxNum',  default => 0);
has 'kweight'   => (is => 'rw', isa => 'LaxNum',  default => 0);
has 'slope'     => (is => 'rw', isa => 'LaxNum',  default => 0);
has 'offset'    => (is => 'rw', isa => 'LaxNum',  default => 0);
has 'delslope'  => (is => 'rw', isa => 'LaxNum',  default => 0);
has 'deloffset' => (is => 'rw', isa => 'LaxNum',  default => 0);

has 'max_standards' => (is => 'rw', isa => 'Int', default => sub{ shift->co->default("lcf", "max_standards")  || 4});

has 'linear'     => (is => 'rw', isa => 'Bool', default => 0);
has 'inclusive'  => (is => 'rw', isa => 'Bool', default => sub{ shift->co->default("lcf", "inclusive")  || 0});
has 'unity'      => (is => 'rw', isa => 'Bool', default => sub{ shift->co->default("lcf", "unity")      || 1});
has 'one_e0'     => (is => 'rw', isa => 'Bool', default => 0);
has 'has_stddev' => (is => 'rw', isa => 'Bool', default => 0);

has 'plot_components' => (is => 'rw', isa => 'Bool', default => sub{ shift->co->default("lcf", "components")  || 0});
has 'plot_difference' => (is => 'rw', isa => 'Bool', default => sub{ shift->co->default("lcf", "difference")  || 0});
has 'plot_indicators' => (is => 'rw', isa => 'Bool', default => sub{ shift->co->default("lcf", "indicators")  || 1});

has 'nstan'     => (is => 'rw', isa => 'Int',    default => 0);
has 'npoints'   => (is => 'rw', isa => 'Int',    default => 0);
has 'ninfo'     => (is => 'rw', isa => 'LaxNum', default => 0);
has 'epsilon'   => (is => 'rw', isa => 'LaxNum', default => 0);
has 'nvarys'    => (is => 'rw', isa => 'Int',    default => 0);
has 'ntitles'   => (is => 'rw', isa => 'Int',    default => 0);
has 'standards' => (
		    traits    => ['Array'],
		    is        => 'rw',
		    isa       => 'ArrayRef[Demeter::Data]',
		    default   => sub { [] },
		    handles   => {
				  'push_standards'    => 'push',
				  'pop_standards'     => 'pop',
				  'shift_standards'   => 'shift',
				  'unshift_standards' => 'unshift',
				  'clear_standards'   => 'clear',
				 },
		   );
has 'doing_combi' => (is => 'rw', isa => 'Bool', default => 0);
has 'combi_count' => (is => 'rw', isa => 'Int',  default => 0);
has 'combi_results'=> (
		       traits    => ['Array'],
		       is        => 'rw',
		       isa       => 'ArrayRef',
		       default   => sub { [] },
		       handles   => {
				     'push_combi_results'    => 'push',
				     'pop_combi_results'     => 'pop',
				     'shift_combi_results'   => 'shift',
				     'unshift_combi_results' => 'unshift',
				     'clear_combi_results'   => 'clear',
				    },
		      );

has 'doing_seq' => (is => 'rw', isa => 'Bool', default => 0);
has 'include_caller' => (is => 'rw', isa => 'Bool', default => 1);
has 'seq_count' => (is => 'rw', isa => 'Int',  default => 0);
has 'seq_results'=> (
		     traits    => ['Array'],
		     is        => 'rw',
		     isa       => 'ArrayRef',
		     default   => sub { [] },
		     handles   => {
				   'push_seq_results'    => 'push',
				   'pop_seq_results'     => 'pop',
				   'shift_seq_results'   => 'shift',
				   'unshift_seq_results' => 'unshift',
				   'clear_seq_results'   => 'clear',
				  },
		    );

has 'options' => (
		  traits    => ['Hash'],
		  is        => 'rw',
		  isa       => 'HashRef[ArrayRef]',
		  default   => sub { +{} },
		  handles   => {
				'set_option'      => 'set',
				'get_option'      => 'get',
				'get_option_list' => 'keys',
				'clear_option'    => 'clear',
				'option_exists'   => 'exists',
			       },
		 );
has 'rfactor' => (is => 'rw', isa => 'LaxNum', default => 0);
has 'chisqr'  => (is => 'rw', isa => 'LaxNum', default => 0);
has 'chinu'   => (is => 'rw', isa => 'LaxNum', default => 0);
has 'scaleby' => (is => 'rw', isa => 'LaxNum', default => 0);

has 'standardsgroups' => (
			  traits    => ['Array'],
			  is        => 'rw',
			  isa       => 'ArrayRef[Str]',
			  default   => sub { [] },
			  handles   => {
					'push_standardsgroups'    => 'push',
					'pop_standardsgroups'     => 'pop',
					'shift_standardsgroups'   => 'shift',
					'unshift_standardsgroups' => 'unshift',
					'clear_standardsgroups'   => 'clear',
				       },
			 );

sub BUILD {
  my ($self, @params) = @_;
  $self->mo->push_LCF($self);
};

override all => sub {
  my ($self) = @_;
  my %all = $self->SUPER::all;
  delete $all{$_} foreach (qw(standards));
  return %all;
};

## float_e0  require
sub add {
  my ($self, $stan, @params) = @_;
  my %hash = @params;
  $hash{float_e0} ||= 0;
  $hash{required} ||= 0;
  $hash{dweight}  ||= 0;
  $hash{e0}       ||= 0;
  $hash{de0}      ||= 0;
  my $weight_provided = exists($hash{weight});
  my @previous = @{ $self->standards };
  $self->push_standards($stan);

  my $n = $#{ $self->standards } + 1;
  $self->nstan($n);
  if (not defined($hash{weight})) {
    $hash{weight} = sprintf("%.3f", 1/$n);
  };

  my $key = $stan->group;
  $self->set_option($key, [$hash{float_e0}, $hash{required}, $hash{weight}, $hash{dweight}, $hash{e0}, $hash{de0}]); ## other 2 are dweight and de0

  return $self if $weight_provided;
  foreach my $prev (@previous) {
    $self->weight($prev, 1/$n);
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
  return $self if not $rlist;
  my @params = @$rlist;
  $params[0] = $onoff;
  $self->set_option($stan->group, \@params);
  return $self;
};

sub required {
  my ($self, $stan, $onoff) = @_;
  $onoff ||= 0;
  my $rlist = $self->get_option($stan->group);
  return $self if not $rlist;
  my @params = @$rlist;
  $params[1] = $onoff;
  $self->set_option($stan->group, \@params);
  return $self;
};

## take reference or group (reference not working....)
sub is_e0_floated {
  my ($self, $stan) = @_;
  ($stan = $stan->group) if (ref($stan) =~ m{Data});
  my $rlist = $self->get_option($stan);
  return ((not $rlist)) ? 0 : $rlist->[0];
};
sub is_required {
  my ($self, $stan) = @_;
  ($stan = $stan->group) if (ref($stan) =~ m{Data});
  my $rlist = $self->get_option($stan);
  return ((not $rlist)) ? 0 : $rlist->[1];
};

sub weight {
  my ($self, $stan, $value, $error) = @_;
  ($stan = $stan->group) if (ref($stan) =~ m{Data});
  my $rlist = $self->get_option($stan);
  #if (not $rlist) { return wantarray ? (0,0) : 0 }; # this happens when perusing combinatoric fits
  my @params = @$rlist;
  if (not defined($value)) {
    return wantarray ? ($params[2], $params[3]) : $params[2];
  };
  $params[2] = $value;
  $params[3] = $error || 0;
  $params[3] = 0 if not looks_like_number($params[3]); # uncertainty will be "null" in larch if not varied
  $self->set_option($stan, \@params);
  return wantarray ? ($params[2], $params[3]) : $params[2];
};

sub e0 {
  my ($self, $stan, $value, $error) = @_;
  ($stan = $stan->group) if (ref($stan) =~ m{Data});
  my $rlist = $self->get_option($stan);
  #if (not $rlist) { return wantarray ? (0,0) : 0 };
  my @params = @$rlist;
  if (not defined($value)) {
    return wantarray ? ($params[4], $params[5]) : $params[4];
  };
  $params[4] = $value;
  $params[5] = $error || 0;
  $params[5] = 0 if not looks_like_number($params[5]); # uncertainty will be "null" in larch if not varied
  $self->set_option($stan, \@params);
  return wantarray ? ($params[4], $params[5]) : $params[4];
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
  if ($self->xmin == $self->xmax) {
    croak("** LCF: zero data range: xmin = xmax = " . $self->xmin);
  };
  if ($self->xmin > $self->xmax) {
    my ($xn, $xx) = $self->get(qw(xmin xmax));
    $self->set(xmin=>$xx, xmax=>$xn);
    carp("** LCF: xmin and xmax were out of order");
  };
  return $self;
};

sub prep_arrays {
  my ($self, $how) = @_;
  my $ud = ($self->suffix eq 'chi') ? 'bft' : 'fft';

  ## prepare the data for LCF fitting
  my $n1 = $self->data->iofx('energy', $self->xmin);
  my $n2 = $self->data->iofx('energy', $self->xmax);
  $self->data -> _update($ud);
  my $which = ($self->space =~ m{\Achi}) ? "lcf_prep_k" : "lcf_prep";
  $self -> dispense("analysis", $which);

  ## interpolate all the standards onto the grid of the data
  my @all = @{ $self->standards };
  $_ -> _update($ud) foreach (@all);
  $self->mo->standard($self);
  foreach my $stan (@all[0..$#all-1]) {
    $which = ($self->space =~ m{\Achi}) ? "lcf_prep_standard_k" : "lcf_prep_standard";
    $stan -> dispense("analysis", $which);
  };
  if ($self->nstan eq 1) {
    $which = ($self->space =~ m{\Achi}) ? "lcf_prep_standard_k" : "lcf_prep_standard";
    $all[$#all] -> dispense("analysis", $which);
  } elsif ($self->unity) {
    $which = ($self->space =~ m{\Achi}) ? "lcf_prep_last_k" : "lcf_prep_last";
    $all[$#all] -> dispense("analysis", $which);
  } else {
    $which = ($self->space =~ m{\Achi}) ? "lcf_prep_standard_k" : "lcf_prep_standard";
    $all[$#all] -> dispense("analysis", $which);
  };
  $self -> dispense("analysis", 'lcf_prep_lcf', {how=>$how});
  $self->mo->standard(q{});
  return $self;
};

sub compute_ninfo {
  my ($self) = @_;
  my $ni = 0;
  ## for fit to chi(k), use the standard EXAFS definition with delta_k
  ## set to the fitting range and deltaR set arbitrarily to 3
  if ($self->space eq 'chi') {
    my $dk = $self->xmax - $self->xmin;
    my $dr = 3; ## let's assume 1 to 4
    $ni = 2*$dk*$dr/$PI + 1;
  ## for XANES (norm or deriv) divide the data range by the core-hole lifetime
  } else {
    $ni =($self->xmax - $self->xmin) / Xray::Absorption->get_gamma($self->data->bkg_z, $self->data->fft_edge);
  };
  $self->ninfo(sprintf("%.3f",$ni));
  return $ni;
};

sub fit {
  my ($self, $quiet) = @_;
  $self->_sanity;
  $self->compute_ninfo if not $self->ninfo;
  $self->has_stddev( ($self->space !~ m{\Achi}) and $self->get_array('stddev') );

  $self->start_spinner("Demeter is performing an LCF fit") if (($self->mo->ui eq 'screen') and (not $quiet));
  my @all = @{ $self->standards };

  $self->prep_arrays('def');
  ## create the array to minimize and perform the fit
  $self -> dispense("analysis", "lcf_fit");

  if (Demeter->is_ifeffit) {
    my $sumsqr = 0;
    foreach my $st (@all) {
      my ($w, $dw) = $self->weight($st, $self->fetch_scalar("aa_".$st->group), $self->fetch_scalar("delta_a_".$st->group));
      $sumsqr += $dw**2;
      if ($self->one_e0) {
	$self->e0($st, $self->fetch_scalar("e_".$st->group), $self->fetch_scalar("delta_e_".$self->group));
      } else {
	$self->e0($st, $self->fetch_scalar("e_".$st->group), $self->fetch_scalar("delta_e_".$st->group));
      };
    };
    if ($self->unity) {		# propagate uncertainty for last amplitude
      my ($w, $dw) = $self->weight($all[$#all]);
      $self->weight($all[$#all], $w, sqrt($sumsqr));
    };
  } elsif (Demeter->mo->template_analysis eq 'larch') {
    foreach my $st (@all) {
      $self->weight($st, $self->fetch_scalar("demlcf.".$st->group."_a"),
		         $self->fetch_scalar("demlcf.".$st->group."_a.stderr"));
      if ($self->one_e0) {
	$self->e0($st, $self->fetch_scalar("demlcf.".$self->group),
		       $self->fetch_scalar("demlcf.".$self->group.".stderr"));
      } else {
	$self->e0($st, $self->fetch_scalar("demlcf.".$st->group.'_e'),
 		       $self->fetch_scalar("demlcf.".$st->group.'_e.stderr'));
      };
    };
    $self->slope    ($self->fetch_scalar("demlcf._slope"));
    my $del = $self->fetch_scalar("demlcf._slope.stderr");
    $del = 0 if not looks_like_number($del);
    $self->delslope ($del);
    $self->offset   ($self->fetch_scalar("demlcf._offset"));
    $del = $self->fetch_scalar("demlcf._offset.stderr");
    $del = 0 if not looks_like_number($del);
    $self->deloffset($del);
  };
  $self->_statistics;

  $self->stop_spinner if (($self->mo->ui eq 'screen') and (not $quiet));
  #$self->ifeffit_heap;
  return $self;
};

sub _statistics {
  my ($self) = @_;
  my ($avg, $count, $rfact, $sumsqr) = (0,0,0,0);

  if (Demeter->is_ifeffit) {
    my @x     = $self->get_array('x');
    my @func  = $self->get_array('func');
    my @resid = $self->get_array('resid');
    foreach my $i (0 .. $#x) {
      next if ($x[$i] < $self->xmin);
      next if ($x[$i] > $self->xmax);
      ++$count;
      $avg += $func[$i];
    };
    $avg /= $count if $count != 0;
    foreach my $i (0 .. $#x) {
      next if ($x[$i] < $self->xmin);
      next if ($x[$i] > $self->xmax);
      $rfact  += $resid[$i]**2;
      if ($self->space =~ m{\Anor}) {
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
    $self->chisqr(sprintf("%.5f", $self->fetch_scalar('chi_square')));
    $self->chinu(sprintf("%.7f", $self->fetch_scalar('chi_reduced')));
    $self->nvarys($self->fetch_scalar('n_varys'));
  } elsif (Demeter->is_larch) {
    $self->rfactor(sprintf("%.7f", $self->fetch_scalar('demlcf.rfactor')));
    $self->chisqr(sprintf("%.5f", $self->fetch_scalar('demlcf.chi_square')));
    $self->chinu(sprintf("%.7f", $self->fetch_scalar('demlcf.chi_reduced')));
    $self->nvarys(int($self->fetch_scalar('demlcf.nvarys')));
    my @x     = $self->get_array('x');
    foreach my $i (0 .. $#x) {
      next if ($x[$i] < $self->xmin);
      next if ($x[$i] > $self->xmax);
      ++$count;
    };
    $self->npoints($count);
  };

  my $sum = 0;
  foreach my $stan (@{ $self->standards }) {
    my ($w, $dw) = $self->weight($stan);
    $sum += $w;
  };
  $self->scaleby(sprintf("%.3f",$sum));
  $self->kweight($self->po->kweight) if ($self->space =~ m{\Achi});
  return $self;
};

sub report {
  my ($self) = @_;
  my $text = $self->template("analysis", "lcf_report");
  return $text;
};

sub plot_fit {
  my ($self) = @_;
  $self->prep_arrays('set');
  $self->po->start_plot;
  my $step = 0;
  if ($self->space =~ m{\Achi}) {
    #$self->data->plot('k');
    $self->chart("plot", "newlcf", {suffix=>'func', yoffset=>$self->data->y_offset});
    $self->po->increment;
    my ($floor, $ceil) = $self->data->floor_ceil('chi');
    $step = min(abs($floor), abs($ceil));
  } else {
    $self->po->set(e_norm=>1, e_markers=>0, e_der=>0);
    $self->po->e_der(1) if ($self->space =~ m{\An?der});
    #self->data->plot('E');
    $self->chart("plot", "newlcf", {suffix=>'func', yoffset=>$self->data->y_offset});
    $self->po->increment;
    if ($self->space =~ m{\An?der}) {
      my ($floor, $ceil) = $self->data->floor_ceil('nder');
      $step = min(abs($floor), abs($ceil));
    };
  };
  $self->chart("plot", "overlcf", {suffix=>'lcf', yoffset=>$self->data->y_offset});
  $self->po->increment;
  if ($self->plot_difference) {
    $self->chart("plot", "overlcf", {suffix=>'resid', yoffset=>$self->data->y_offset});
    $self->po->increment;
  };
  if ($self->plot_components) {
    my $save_yoff = $self->data->y_offset;
    foreach my $stan (@{ $self->standards }) {
      if ($self->space =~ m{\A(?:chi|der)}) {
	my $yoff = $self->data->y_offset;
	$self->data->y_offset($yoff - $step);
	#print join(" ", $step, $self->data->y_offset), $/;
      };
      $self->chart("plot", "overlcf", {suffix=>$stan->group, yoffset=>$self->data->y_offset});
      $self->po->increment;
    };
    $self->data->y_offset($save_yoff);
  };
  if ($self->plot_indicators) {
    my @indic;
    $self->data->standard;
    if ($self->space =~ m{\Achi}) {
      @indic = (Demeter::Plot::Indicator->new(space=>'k', x=>$self->xmin),
		Demeter::Plot::Indicator->new(space=>'k', x=>$self->xmax));
      $_->plot('k') foreach (@indic);
    } else {
      @indic = (Demeter::Plot::Indicator->new(space=>'E', x=>$self->xmin-$self->data->bkg_e0),
		Demeter::Plot::Indicator->new(space=>'E', x=>$self->xmax-$self->data->bkg_e0));
      $_->plot('E') foreach (@indic);
    };
  };

  return $self;
};

sub plot {
  my ($self) = @_;
  my $do_plot = 0;
  ## only make a plot if the LCF meets all the conditions of the current plot
  ($do_plot = 1) if (($self->po->space eq 'k') and ($self->space =~ m{\Achi}));

  ($do_plot = 1) if (($self->po->space eq 'e') and ($self->space =~ m{\Anor}) and
		     $self->po->e_norm and (not $self->po->e_der));

  ($do_plot = 1) if (($self->po->space eq 'e') and ($self->space =~ m{\An?der}) and
		     $self->po->e_norm and $self->po->e_der);

  if ($do_plot) {
    ## if space is chi and plot ir R, do FFTs and plot those...
    $self->chart("plot", "overlcf", {suffix=>'lcf', yoffset=>$self->data->y_offset});
  };
  if (($self->po->space eq 'r') and ($self->space =~ m{\Achi})) {
    my $suff = ($self->po->r_pl eq 'm') ? 'chir_mag'
             : ($self->po->r_pl eq 'r') ? 'chir_re'
             : ($self->po->r_pl eq 'i') ? 'chir_im'
             : ($self->po->r_pl eq 'p') ? 'chir_pha'
	     :                            'chir_mag';
    $self->chart("plot", "overlcf", {suffix=>$suff, yoffset=>$self->data->y_offset});
  };

  return $self;
};


sub fft {
  my ($self) = @_;
  $self->data->_update("fft");
  $self->prep_arrays('set');

  my $group = $self->group;
  my $dobject = $self->data->group;
  my $string = $self->data->_fft_command;
  $string =~ s{\b$dobject\b}{$group}g; # replace group names
  $string =~ s{\.k\b}{.x};             # replace abscissa suffix
  $string =~ s{\.chi\b}{.lcf};         # replace ordinate suffix
  $string =~ s{\bkweight=\d\b}{kweight=0}; # replace kweighting

  #print $string;
  $self->dispose($string);
  return $string;
};


sub save {
  my ($self, $fname) = @_;

  my $text = $self->template('analysis', 'lcf_report');

  my $save_columns = {};
  my $hash = {1=>'energy eV', 2=>'data', 3=>'fit', 4=>'residual'};
  $hash->{1} = 'wavelength inverse Angstrom' if $self->space eq 'chi';
  my $i=4;
  foreach my $st (sort {$b cmp $a} @{ $self->standards }) {
    ++$i;
    (my $name = $st->name) =~ s{\s+}{_}g;
    $hash->{$i} = $name;
  };
  if ($self->data->xdi) {
    #$text = $self->template('analysis', 'lcf_report');
    $save_columns  = $self->data->xdi->metadata->{Column};
    $self->data->xdi_set_columns($hash);
  };

  $self->data->xdi_output_header('data', $text, $hash);
  $self->dispose($self->template('analysis', 'lcf_save', {filename=>$fname}));
  $self->data->xdi_set_columns($save_columns) if ($self->data->xdi);

  return $self;
};

sub clear {
  my ($self) = @_;
  $self->clear_standards;
  $self->clear_option;
  return $self;
};

sub clean {
  my ($self) = @_;
  $self->ninfo(0);
  $self->dispense('analysis', 'lcf_clean');
  return $self;
};

sub combi_size {
  my ($self) = @_;
  my @biglist = ();
  my @all_required = grep {$self->is_required($_)} $self->standards_list;
  foreach my $n (2 .. $self->max_standards) {
    my $combinat = Math::Combinatorics->new(count => $n,
					    data => [$self->standards_list],
					   );
    while (my @combo = $combinat->next_combination) {
      my $requirements_present = 1;
      foreach my $req (@all_required) {
	$requirements_present &&= any {$_ eq $req} @combo;
      };
      next if not $requirements_present;
      #my $stringified = join(",", @combo);
      push @biglist, \@combo;
    };
  };
  return wantarray ? @biglist : $#biglist+1;
};

sub combi {
  my ($self, @params) = @_;
  #my %options = @params;
  #$options{plot} ||= $self->co->default('lcf', 'combi_plot_during');

  my @biglist = $self->combi_size;
  my $nfits = $#biglist+1;
  $self->doing_combi(1);
  $self->start_counter("Performing combinatoric LCF fitting", $nfits) if ($self->mo->ui eq 'screen');
  my @results = ();
  my $count = 1;
  foreach my $this (@biglist) {
    $self->combi_count($count);
    $self->clear_standards;
    my @list = map {$self->mo->fetch('Data', $_)} @$this;
    foreach my $st (@list) {	# take care not to change contents of options attribute
      $self->push_standards($st);
      $self->weight($st, 1/($#list+1));
    };
    $self->count if ($self->mo->ui eq 'screen');
    $self->call_sentinal;
    $self->fit(1);
    $self->plot_fit if $self->co->default('lcf', 'plot_during');
    #$self->clean;

    my %fit = (
	       Rfactor => $self->rfactor,
	       Chinu   => $self->chinu,
	       Chisqr  => $self->chisqr,
	       Nvarys  => $self->nvarys,
	       Scaleby => $self->scaleby,
	      );
    foreach my $st (@list) {	# use of capitalized keys above avoid key collision
      $fit{$st->group} = [$self->weight($st), $self->e0($st)];
    };
    push @results, \%fit;
    ++$count;
  };
  $self->stop_counter if ($self->mo->ui eq 'screen');
  $self->doing_combi(0);
  @results = sort {$a->{Rfactor} <=> $b->{Rfactor}} @results;
  $self->combi_results(\@results);

  ## restore best fit
  $self->restore($results[0]);
  #print "yes!\n" if $self->is_required('hqlr');
  return $self;
};

sub restore {
  my ($self, $rhash) = @_;
  my @stats = qw(rfactor chinu chisqr nvarys scaleby);
  foreach my $p (@stats) {
    $self->$p($rhash->{ucfirst($p)});
  };
  my $stats_regex = join('|', map {ucfirst $_} @stats);
  $self->mo->standard($self);
  $self->clear_standards;
  foreach my $k (keys %$rhash) {
    next if ($k =~ m{\A(?:$stats_regex)});
    next if ($k eq 'Data');
    my $rlist = $rhash->{$k};
    my $this_data = $self->mo->fetch('Data', $k);
    my ($w, $dw, $e0, $de0) = @$rlist;
    $self->add($this_data, weight=>$w, dweight=>$dw, e0=>$e0, de0=>$de0);
    #$self->push_standards($this_data), weight=>$w, dweight=>$dw, e0=>$e0, de0=>$de0);
    #$self->weight($this_data->group, $w, $dw);
    #$self->e0($this_data->group, $e0, $de0);
    if (Demeter->mo->template_analysis eq 'larch') {
      if ($self->space =~ m{\Achi}) {
	$self->dispose($this_data->template('analysis', 'lcf_prep_standard_k'));
      } else {
	$self->dispose($this_data->template('analysis', 'lcf_prep_standard'));
      };
    } else {
      $self->dispose($this_data->template('analysis', 'lcf_sum_standard'));
    };
  };
  if (Demeter->mo->template_analysis eq 'larch') {
    $self->dispense('analysis', 'lcf_prep_lcf');
  } else {
    $self->dispense('analysis', 'lcf_sum');
  };
  $self->mo->standard(q{});
  return $self;
};


sub combi_report {
  my ($self, $fname) = @_;
  if ($self->co->default("lcf", "output") eq 'excel') {
    $self->report_excel($fname, 'combi');
  } else {
    $self->report_csv($fname, 'combi');
  };
};


sub report_excel {
  my ($self, $fname, $which) = @_;
  my @stats = qw(rfactor chinu chisqr nvarys scaleby);
  my @stand = sort {$b cmp $a} keys %{ $self->options };
  my @names = map {$self->mo->fetch('Data', $_)->name} @stand;
  #@names = map { $_ =~ s{,}{ }g; $_ } @names;

  my $workbook;
  {
    ## The evals in Spreadsheet::WriteExcel::Workbook::_get_checksum_method
    ## will set the eval error variable ($@) if any of Digest::XXX
    ## (XXX = MD4 | PERL::MD4 | MD5) are not installed on the machine.
    ## This is not a problem -- crypto is not needed in the exported
    ## Excel file.  However, setting $@ will post a warning given that
    ## $SIG{__DIE__} is defined to use Wx::Perl::Carp.  So I need to
    ## locally undefine $SIG{__DIE__} to avoid having a completely
    ## pointless error message posted to the screen when the S::WE
    ## object is instantiated
    local $SIG{__DIE__} = undef;
    $workbook = Spreadsheet::WriteExcel->new($fname);
  };
  my $worksheet = $workbook->add_worksheet();

  my $head = $workbook->add_format();
  $head -> set_bold;
  $head -> set_bg_color('grey');
  $head -> set_align('left');
  my $group = $workbook->add_format();
  $group -> set_bold;
  $group -> set_bg_color('grey');
  $group -> set_align('left');

  my $col = 0;
  if ($which eq 'seq') {
    $worksheet->write(1, $col, 'Data', $head);
    ++$col;
  };
  foreach my $s (@stats) {
    $worksheet->write(1, $col, $s, $head);
    ++$col;
  };
  foreach my $n (@names) {
    $worksheet->merge_range(0,  $col, 0, $col+3, $n, $group);
    $worksheet->write(1, $col,   'weight', $head);
    $worksheet->write(1, $col+1, 'error',  $head);
    $worksheet->write(1, $col+2, 'e0',     $head);
    $worksheet->write(1, $col+3, 'error',  $head);
    $col+=4;
  };

  my $row = 2;
  $col = 0;
  my $att = $which.'_results';
  foreach my $res (@{ $self->$att }) {
    if ($which eq 'seq') {
      $worksheet->write($row, $col, $self->mo->fetch('Data', $res->{Data})->name);
      ++$col;
    };
    foreach my $s (@stats) {
      $worksheet->write($row, $col, $res->{ucfirst($s)});
      ++$col;
    };
    foreach my $st (@stand) {
      if (exists $res->{$st}) {
	foreach my $c (@{ $res->{$st} }) {
	  $worksheet->write($row, $col, $c);
	  ++$col;
	};
      } else {
	$worksheet->write($row, $col, q{}) foreach (1..4);
	$col+=4;
      }
    };
    ++$row;
    $col=0;
  };
  $workbook->close;
};

sub report_csv {
  my ($self, $fname, $which) = @_;
  my @stats = qw(rfactor chinu chisqr nvarys scaleby);
  my @stand = sort {$b cmp $a} keys %{ $self->options };
  my @names = map {$self->mo->fetch('Data', $_)->name} @stand;
  @names = map { $_ =~ s{,}{ }g; $_ } @names;
  open(my $FH, '>', $fname);
  print $FH join(',', @stats), ',';
  print $FH join(',,,,', @names), ",,,,\n";
  my $att = $which.'_results';
  foreach my $res (@{ $self->$att }) {
    print $FH ($res->{ucfirst($_)},',') foreach @stats;
    foreach my $st (@stand) {
      if (exists $res->{$st}) {
	print $FH join(',', @{ $res->{$st} } ), ',';
      } else {
	print $FH ',,,,';
      }
    };
    print $FH $/;
  };
  close $FH;
};


sub sequence {
  my ($self, @groups) = @_;
  my $first = $self->data;
  my @data = ($self->include_caller) ? uniq($first, @groups) : uniq(@groups);
  my $nfits = $#data+1;

  $self->doing_seq(1);
  $self->start_counter("Performing a sequence of LCF fitting", $nfits) if ($self->mo->ui eq 'screen');
  my @results = ();
  my $count = 1;
  my @standards = @{$self->standards};
  foreach my $d (@data) {
    $self->clean;
    $self->seq_count($count);
    $self->count if ($self->mo->ui eq 'screen');
    $self->call_sentinal;
    $self->data($d);
    $self->clear_standards;
    foreach my $st (@standards) {
      $self->push_standards($st);
      $self->weight($st, 1/($#standards+1));
      $self->e0($st, 0);
    };
    $self->fit(1);
    $self->plot_fit if $self->co->default('lcf', 'plot_during');
    my %fit = (
	       Rfactor => $self->rfactor,
	       Chinu   => $self->chinu,
	       Chisqr  => $self->chisqr,
	       Nvarys  => $self->nvarys,
	       Scaleby => $self->scaleby,
	       Data    => $d->group,
	      );
    foreach my $st (@standards) { # use of capitalized keys above avoid key collision
      $fit{$st->group} = [$self->weight($st), $self->e0($st)];
    };
    push @results, \%fit;
    ++$count;
  };
  $self->stop_counter if ($self->mo->ui eq 'screen');
  $self->clean;
  $self->data($first);
  my $which = ($self->space =~ m{\Achi}) ? "lcf_prep_k" : "lcf_prep";
  $self->dispense("analysis", $which);
  $self->set(doing_seq=>0, seq_results=>\@results);
  $self->restore($results[0]);
  $self->plot_fit if $self->co->default('lcf', 'plot_during');
  return $self;
};


sub sequence_report {
  my ($self, $fname) = @_;
  if ($self->co->default("lcf", "output") eq 'excel') {
    $self->report_excel($fname, 'seq');
  } else {
    $self->report_csv($fname, 'seq');
  };
  return $self;
};

sub sequence_plot {
  my ($self) = @_;
  $self->po->start_plot;
  my $tempfile = $self->po->tempfile;
  open my $T, '>'.$tempfile;
  print $T $self->sequence_columns;
  close $T;

  my $first = $self->seq_results->[0];
  my @all = keys(%$first);
  my @stan = grep {$_ !~ m{\A[A-Z]}} @all;
  my $st1 = shift @stan;
  $self->chart('plot', 'newlcf_seq', {file=>$tempfile, col=>2, title=>$self->mo->fetch('Data', $st1)->name});
  my $col = 4;
  foreach my $st (@stan) {
    $self->po->increment;
    $self->chart('plot', 'overlcf_seq', {file=>$tempfile, col=>$col, title=>$self->mo->fetch('Data', $st)->name});
    $col += 2;
  };
  return $self;
};

sub sequence_columns {
  my ($self) = @_;
  my $first = $self->seq_results->[0];
  my @all = keys(%$first);
  my @stan = grep {$_ !~ m{\A[A-Z]}} @all;
  my $nstan = $#all - 5;
  my $format = ' %d' . '   %.3f' x (2*$nstan) . "\n";
  my $text = "# Linear combination results\n";
  my $count = 1;
  foreach my $res (@{ $self->seq_results }) {
    $text   .= "# $count: ". $self->mo->fetch('Data', $res->{Data})->name . "\n";
    ++$count;
  };
  $text   .= "# --------------------------\n";
  $text   .= "# N   " . join("   ", map {$_ =~ s{\s}{_}g; "$_   error_$_"} map {$self->mo->fetch('Data', $_)->name} @stan) . "\n";
  $count = 1;
  foreach my $res (@{ $self->seq_results }) {
    my @weights;
    foreach my $st (@stan) {
      push @weights, $res->{$st}->[0], $res->{$st}->[1];
    };
    $text .= sprintf($format, $count++, @weights);
  };
  return $text;
};

sub sequence_xtics {
  my ($self) = @_;
  my $text = 'set xtics (';
  my $i = 1;
  foreach my $res (@{ $self->seq_results }) {
    $text .= '"' . $self->mo->fetch('Data', $res->{Data})->name . "\" $i, ";
    ++$i;
  };
  chop $text;
  chop $text;
  $text .= ")\n";
  return $text;
};

sub make_group {
  my ($self) = @_;
  my $suff = ($self->space =~ m{\Achi}) ? "k" : "energy";
  my @x = $self->get_array('x');
  my @y = $self->get_array('lcf');
  if ($self->space =~ m{\Achi}) {
    local $SIG{__WARN__} = undef;
    @y = pairwise {$a**(-1*$self->kweight)*($b||0)} @x, @y;
  };
  my $name = "LCF " . $self->data->name;
  my $which = ($self->space =~ m{\Achi}) ? "chi" : "xmu";
  my $data = $self->data->put(\@x, \@y, datatype=>$which, is_nor=>1, name=>$name, file=>"LCF fit to ".$self->data->name);
  my %attributes = $self->data->all;
  foreach my $k (keys %attributes) {
    delete $attributes{$k} if ($k !~ m{\A(?:bkg|bft|fft|fit)_});
  };
  delete $attributes{bkg_eshift};
  #foreach my $a (qw(datatype name is_nor bkg_step bkg_eshift data datagroup)) {
  #  delete $attributes{$a};
  #};
  $data->set(%attributes);
  return $data;
};

__PACKAGE__->meta->make_immutable;
1;


=head1 NAME

Demeter::LCF - Linear combination fitting

=head1 VERSION

This documentation refers to Demeter version 0.9.25.

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
   $lcf -> plot_fit;
   $lcf -> save('lcf_fit_result.dat');

=head1 DESCRIPTION

Linear combination fitting (LCF) is an analysis method for
interpreting XANES or EXAFS data using standards.  The assumption is
that the data from an unknown sample can be understood as a linear
superposition of the data from two or more known, well-understood
standards.  The LCF analysis, therefore, tells us what fraction of the
unknown sample is explained by one of the known standards.

For example, imagine mixing together quantities of iron oxide and iron
sulfide such that there are equal numbers of iron atoms surrounded by
oxygen and by sulfur.  You would then expect to be able to describe
the data from the mixure by adding together equal parts of the data
from the two pure materials.

This object provides a framework for performing this sort of analysis.
In the example shown above, data and standards are imported from an
Athena project file.  The data are fit as a linear combination of
three standards.  The result of the fit is the fraction of each
standard present in the data as well as uncertainties in those
fractions.

This object also provides methods for "combinatorial fitting".  In
this approach an ensemble of standards are compared to the data in all
possible combinations (with certain constraints).  The results are
sorted by increasing R-factor of the fit.  The first result, then, is
the combination of standards giving the closest fit to the data.

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
When fitting in C<chi>, e0 cannot be varied.

=item C<max_standards>

The maximum number of standards to use in each fit of a combinatorial
sequence.

=item C<include_caller>

A boolean.  Use in sequence fitting to determine whether the data
currently associated with the LCF object is inlcuded in the fit
sequence.  The default is true.  This is a convenience introduced for
the sake of the LCF tool in Athena.

=item C<linear>

A boolean.  When true, add a linear term to the fit.  (Not implemented
yet.)

=item C<inclusive>

A boolean.  When true, all weights are forced to be between 0 and 1
inclusive.

=item C<unity>

A boolean.  When true, the weights are forced to sum to 1.

=item C<one_e0>

A boolean.  When true, one over-all e0 parameter is used in the fit
rather than one for each standard.  In practice, the standards are
shifted by the same floated e0 value.  That is, one parameter is
floated and an e0 for each standard is def-ed to that value.

=item C<noise>

If non-zero, add artifical noise to the data.  The value is used as
the sigma of the normally distributed artifical noise.  You may need
to play around to find an appropriate value for your data.  Note that
for a fit in chi(k), the noise is added to the un-k-weighted chi(k)
data.

=item C<kweight>

The kweighting used in a fit using chi(k) data.

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

This attribute contains the list of standards added to this LCF problem.
The accessor returns a list reference:

  $ref_to_standards = $lcf->standards;

It is strongly recommended that you do not assign standards directly
to this.  Instead use the C<add> or C<add_many> methods.  Those
methods take care of some other chores required to keep the LCF
organized.

=back

A number of methods are provided by Moose for interacting with the
list stored in this attribute:

=over 4

=item C<push_standards>

Push a value to the list.

=item C<pop_standards>

Pop a value from the list.

=item C<shift_standards>

Shift a value from the list.

=item C<unshift_standards>

Unshift a value to the list.

=item C<clear_standards>

Assign an empty list.

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
spectrum, this is a normal R-factor in Ifeffit or Larch:

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

This is the chi-square for the fit.

=item C<chinu>

This is the reduced chi-square for the fit.

=back

=head1 METHODS

=over 4

=item C<add>

Add a Data object to the LCF object for use one of the fitting
standards.  In it's simplest form, the sole argument is a Data objectL

  $lcf -> add($data_object);

You can also set certain parameters of the standard by supplying an
optional anonymous hash:

  $lcf -> add($data_object, required => 0,
                            float_e0 => 0,
                            weight   => 1/3,
                            e0       => 1/3,);

The C<required> parameter flags this standard as one that is required
to be in a combinatorial fit.  C<float_e0> is true when you wish to
float an energy shift for this standard.  The other two are used to
specify the weight and e0.

There are methods (described) below for setting each of these
parameters.

=item C<add_many>

This method provides a way of setting a group of Data objects as
standard in one shot.  It is equivalent to repeated calls to the
C<add> method without the anonymous hash.

  $lcf -> add_many(@data);

=item C<float_e0>

This method is used to turn a floating e0 value on or off for a given
standard.

  $lcf->float_e0($standard, $onoff);

The first argument is the standard in question, the second is a
boolean toggling the floating e0 on or off.

These are the same:

  $lcf->add($data);
  $lcf->float_e0($data, 1);

and

  $lcf->add($add, float_e0=>1);

=item C<required>

This method is used to require a given standard in a combinatorial
fit.

  $lcf->required($standard, $onoff);

The first argument is the standard in question, the second is a
boolean toggling the requirement on or off.

These are the same:

  $lcf->add($data);
  $lcf->required($data, 1);

and

  $lcf->add($add, required=>1);

=item C<weight>

This method is both a setter and getter of the weight for a given
standard.  As a getter:

  my ($weight, $dweight) = $lcf->weight($standard);

The weight and the uncertainty in the weight are returned as an array.

The weight can be set to an explicit value:

  my ($weight, $dweight) = $lcf->weight($standard, $value);

Again weight and the uncertainty in the weight are returned as an
array.  The uncertainty is zeroed when the weight is explicitly set.

In scalar context, this just returns the weight.

=item C<e0>

This method is both a setter and getter of the e0 shift for a given
standard.  As a getter:

  my ($e0, $e0) = $lcf->e0($standard);

The e0 and the uncertainty in the e0 are returned as an array.

The e0 can be set to an explicit value:

  my ($e0, $de0) = $lcf->e0($standard, $value);

Again e0 and the uncertainty in the e0 are returned as an array.  The
uncertainty is zeroed when the e0 is explicitly set.

In scalar context, this just returns the e0.

=item C<fit>

Perform the fit.

  $lcf->fit;

This will perform some sanity checks, including verifying that the
data has been set and that at least two standards have been defined.
It will also make sure C<xmin> and C<xmax> are in the correct order.

An optional boolean argument turns the spinner off when in screen UI
mode.  This allows use of a counter for combinatorial fits.

  $lcf->fit(1);  # true value means to turn spinner off

=item C<report>

This returns a summary of the fitting results.

  print $lcf->report;

=item C<save>

This method saves the results of a fit to a column data file
containing columns for the x-axis (energy or wavenumber), the data,
the fit, and each of the weighted components.

  $lcf -> save("file.dat");

=item C<plot_fit>

This method will generate a plot showing the data and the fit.

  $lcf -> plot_fit;

The C<plot_difference>, C<plot_components>, and C<plot_indicators>
attributes determine whether the residual, the weighted components,
and indicators marking the fitting range are included in the plot.

By default, the chi(k) and derivative components are stacked
automatically.

=item C<plot>

This is the generic plotting method for use when overplotting a large
number of objects.  In this example, the data, the standards, and the
result of the LCF fit are plotted together with the standards plotted
normally rather than as the weighted components of the fit.

   $lcf->po->start_plot;
   $lcf->po->set(e_norm=>1, e_der=>1, emin=>-30, emax=>70);
   $_->plot('e') foreach ($data, @standards, $lcf);

This method does nothing (i.e. it does not attempt to plot the LCF fit
at all) if the plot conditions do not match the fitting space of the
fit.  E.g., an LCF fit to normalized data will only be plotted if the
fit is in energy and the C<e_norm> Plot attribute is true.

=item C<clean>

This method clears all scalars and arrays out of the memory of the
data processing backend (Ifeffit/Larch).

  $lcf->clean;

=back

Note that there is not a C<remove> method to do the opposite of
C<add>.  This seems to me unnecessarily difficult to use.  I suggest
explicitly clearing the standards list and then C<add>ing a new set of
standards.  This is how the combinatorial fitting loop works.

  $lcf->add(@data);
   ... do stuff, then
  $lcf->clear_standards;
  $lcf->add(@new_data);

Explain these:

				  'push'    => 'push_standards',
				  'pop'     => 'pop_standards',
				  'shift'   => 'shift_standards',
				  'unshift' => 'unshift_standards',
				  'clear'   => 'clear_standards',

=head1 COMBINATORIAL FITTING

These attributes and methods are specifically related to combinatorial
fitting.  A combinatorial fit is one in which all possible
combinations (within certain constraints) are compared to the data.

=head2 Attributes for combinatorial fitting

=over 4

=item C<max_standards>

The maximum number of standards to use in each fit of a combinatorial
sequence.  Note that the size of the combinatorial problem grows
geometrically in the value of this parameter and in the number of
possible standards.

If, for example, this is set to 4, then in a combinatorial fit, all
possible combinations of 2, 3, or 4 standards will be fit to the data.

Note that the size of the combinatorial problem gets very large as
this number grows.

=item C<combi_results>

This is an array of hashes, sorted by rfactor, containing all the
results of fitting sequence.

Each hash in the array looks like this:

  {
   Rfactor => Num,
   Chinu   => Num,
   Chisqr  => Num,
   Nvarys  => Num,
   Scaleby => Num,
   aaaaa   => [weight, dweight, e0, de0],
   bbbbb   => [weight, dweight, e0, de0],
   ....
  }

A key like "aaaaa" is the group attribute of a Data object used in the
fit.  From this, the final state of each fit can be recovered using
the C<restore> method.

=back

=head2 Methods of combinatorial fitting

=over 4

=item C<combi>

Perform a combinatorial sequence of fits, that is, perform all fits
using all combinations of standards up to the number in
C<max_standards>.  If C<max_standards> is 4, then all combinations of
2, 3, or 4 of all the standards added to the object will considered.

  $lcf->combi;

At the end of the fit, the C<combi_results> attribute is filled with
an array of hashes containing the sorted results of the fit.  The
first item in the array contains th results from the fit with the
lowest R-factor (that is, the combinationof standards that most
closely describes the data).

One or more standards can be flagged as being required in a fit.  That
is, each fit will include the flagged standards.  This will
significantly reduce the size of the combinatorial problem.  See the
discussion of the C<add>, C<required>, and C<is_required> methods
above.

At the end of the combinatorial sequence of fits, the fit with the
lowest R-factor will be restored.  Calling C<plot_fit>, C<report>, or
C<save> will act on that fit.  To examine other fits from the
sequence, the C<restore> must be called using one of the results from
the C<combi_results> attribute.

=item C<combi_report>

Write an Excel or CSV (comma separated value) file that can be
imported into a spreadsheet with the results of the combinatorial fit.

  $lcf->combi_report("results.xls");

The argument is the name of the output file (which you probably want
to give a ".csv" or ".xls" extension so your spreadsheet will know to
import it as such.  The choice of file type is controlled by the value
of the C<lcf -E<gt>; output> configuration parameter.

Note that care is taken to strip any commas from the names of the
standards before writing the CSV file.  Also note that this does not
make the most elegant spreadsheet, but it is certainly functional and
it certainly allows you to examine all of your results.

=back

=head1 SEQUENCE FITTING

These attributes and methods are specifically related to combinatorial
fitting.  A combinatorial fit is one in which all possible
combinations (within certain constraints) are compared to the data.

=head2 Attributes for combinatorial fitting

=over 4

=item C<seq_results>

This is an array of hashes, sorted by rfactor, containing all the
results of fitting sequence.

Each hash in the array looks like this:

  {
   Rfactor => Num,
   Chinu   => Num,
   Chisqr  => Num,
   Nvarys  => Num,
   Scaleby => Num,
   aaaaa   => [weight, dweight, e0, de0],
   bbbbb   => [weight, dweight, e0, de0],
   ....
  }

A key like "aaaaa" is the group attribute of a Data object used in the
fit.  From this, the final state of each fit can be recovered using
the C<restore> method.

=back

=head2 Methods of sequence fitting

=over 4

=item C<sequence>

Perform a sequence of fits to a group data.

  $lcf->sequence(@data);

The data in C<$lcf> is appended to the beginning of C<@data> unless
the C<include_caller> attribute is false. Care is taken to remove
repeats from C<@data>.

At the end of the fit, the C<seq_results> attribute is filled with an
array of hashes containing the results of each fit.  This array is in
the same order as C<@data>.

At the end of the sequence of fits, the fit to the data originally in
C<$lcf> will be restored.  Calling C<plot_fit>, C<report>, or C<save>
will act on that fit.  To examine other fits from the sequence, the
C<restore> must be called using one of the results from the
C<seq_results> attribute.

=item C<sequence_report>

Write an Excel or CSV (comma separated value) file that can be
imported into a spreadsheet with the results of the combinatorial fit.

  $lcf->sequence_report("results.csv");

The argument is the name of the output file (which you probably want
to give a ".csv" or ".xls" extension so your spreadsheet will know to
import it as such.  The choice of file type is controlled by the value
of the C<lcf -E<gt>; output> configuration parameter.

Note that care is taken to strip any commas from the names of the
standards before writing the CSV file.  Also note that this does not
make the most elegant spreadsheet, but it is certainly functional and
it certainly allows you to examine all of your results.

=item C<sequence_plot>

Make a plot of the component weights as a function of data set.

=back

=head1 SERIALIZATION AND DESERIALIZATION

Good question ...

=head1 CONFIGURATION AND ENVIRONMENT

See L<Demeter::Config> for a description of the configuration system.
See the C<lcf> configuration group for the relevant parameters.

=head1 DEPENDENCIES

Demeter's dependencies are in the F<Build.PL> file.

=head1 BUGS AND LIMITATIONS

=over 4

=item *

noise

=item *

Serialization and deserialization

=item *

linear term

=item *

better sanity method that provides usable feedback for a GUI

=item *

singlefile plot

=item *

further processing of LCF result (i.e. bkg removal, FTs).  This seems
better than converting the fit into a normal Data object

=back

Please report problems to the Ifeffit Mailing List
(L<http://cars9.uchicago.edu/mailman/listinfo/ifeffit/>)

Patches are welcome.

=head1 AUTHOR

Bruce Ravel, L<http://bruceravel.github.io/home>

L<http://bruceravel.github.io/demeter/>


=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2016 Bruce Ravel (L<http://bruceravel.github.io/home>). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut


