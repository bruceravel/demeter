package Demeter::Data::Mu;

=for Copyright
 .
 Copyright (c) 2006-2013 Bruce Ravel (bravel AT bnl DOT gov).
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

use autodie qw(open close);

use Moose::Role;
use MooseX::Aliases;

use Carp;
use File::Basename;
use File::Spec;
use List::Util qw(max);
use List::MoreUtils qw(any all zip firstidx);
use Demeter::Constants qw($NUMBER $INTEGER $ETOK $PI $EPSILON3 $EPSILON4);

use Text::Template;
use Text::Wrap;
$Text::Wrap::columns = 65;

use Chemistry::Elements qw(get_symbol);
use Xray::Absorption;

use Demeter::StrTypes qw( Clamp );

  #my $config = Demeter->get_mode("params");
  # my %clamp = ("None"   => 0,
  # 	       "Slight" => 3,
  # 	       "Weak"   => 6,
  # 	       "Medium" => 12,
  # 	       "Strong" => 24,
  # 	       "Rigid"  => 96
  # 	      );

sub clamp {
  my ($self, $clampval) = @_;
  if ($clampval =~ m{$NUMBER}) {
    $clampval = int($clampval);
    ## this is not correct!, need to compare numeric values
    #return $1 if (lc($clampval) =~ m{\A($clamp_regex)\z});
    return $clampval;
  } elsif ( is_Clamp($clampval) ) {
    return $self->co->default("clamp", $clampval);
  } else {
    return 0;
  };
};

## recompute E or k spline boundary when the other is changed
sub spline_range {
  my ($self, $which) = @_;
  $self->tying(1);		# prevent deep recursion
 SWITCH: {
    ($which eq 'spl1') and do {
      $self->bkg_spl1e( $self->k2e($self->bkg_spl1, 'relative') );
      last SWITCH;
    };

    ($which eq 'spl1e') and do {
      $self->bkg_spl1( $self->e2k($self->bkg_spl1e, 'relative') );
      last SWITCH;
    };

    ($which eq 'spl2') and do {
      $self->bkg_spl2e( $self->k2e($self->bkg_spl2, 'relative') );
      last SWITCH;
    };

    ($which eq 'spl2e') and do {
      $self->bkg_spl2( $self->e2k($self->bkg_spl2e, 'relative') );
      last SWITCH;
    };
  };
  $self->set_nknots;
  return $self;
};

## recompute this every time the spline range or Rbkg is changed
sub set_nknots {
  my ($self) = @_;
  $self->nknots( int( 2 * ($self->bkg_spl2 - $self->bkg_spl1) * $self->bkg_rbkg / $PI ) );
  return $self;
};

sub guess_units {
  my ($self) = @_;
  my @energy = $self->get_array('energy');
  return 'eV' if not @energy;
  if (($energy[0] < $energy[1]) and
      ($energy[1] < $energy[2]) and
      ($energy[2] < $energy[3]) and
      ($energy[3] < $energy[4])) {
    if ($energy[0] > 100) {
      return 'eV';
    } else {
      return 'keV';
    };
  } else {
    return 'lambda';
  };
};

sub guess_columns {
  my ($self) = @_;
  my $i0_regexp = $self->co->default("file", 'i0_regex');
  my $tr_regexp = $self->co->default("file", 'transmission_regex');
  my $fl_regexp = $self->co->default("file", 'fluorescence_regex');
  my ($i0, $tr, $fl) = (q{}, q{}, q{});

  $self->_update('data');

  my $count = 1;
  foreach my $c (split(" ", $self->columns)) {
    if ($c =~ m{$i0_regexp}) {
      $i0 = '$'.$count;
      last;
    };
    ++$count;
  };

  $count = 1;
  foreach my $c (split(" ", $self->columns)) {
    if ($c =~ m{$tr_regexp}) {
      $tr = '$'.$count;
      last;
    };
    ++$count;
  };

  if (not $tr) {
    $count = 1;
    foreach my $c (split(" ", $self->columns)) {
      if ($c =~ m{$fl_regexp}) {
	$fl = '$'.$count;
	last;
      };
      ++$count;
    };
  };

  $i0 ||= '1';
  if ($tr) {
    $self->set(ln=>1, numerator=>$i0, denominator=>$tr);
  } else {
    $fl ||= '1';
    $self->set(ln=>0, numerator=>$fl, denominator=>$i0);
  };
};

sub put_data {
  my ($self) = @_;

  ## I think this next bit is supposed to do the right thing for
  ## column data, mu(E) data, or chi(k) data
  if (not $self->is_col) {
    $self->determine_data_type;
    if ($self->datatype eq "chi") {
      ##$self->plot('k');
      $self->fix_chik;
      $self->resolve_defaults;
      $self->update_columns(0);
      return 0;
    } elsif ($self->is_kev) {
      $self->dispense('process', 'kev');
      $self->dispense("process", "deriv");
      return 0;
    } elsif ($self->from_athena) {
      $self->update_columns(0);
      return 0;
    } elsif ($self->is_special) {
      return 0;
    } else {
      $self->update_columns(0);
      $self->update_norm(1);
      $self->initialize_e0;
      return 0;
    };
  };
  $self->read_data("raw") if $self->update_data;

  ## get columns from ifeffit
  my @cols = split(" ", $self->columns);
  unshift @cols, q{};

  my $energy_string = ($self->is_kev) ? '1000*'.$self->energy : $self->energy;
  my ($chi_string, $xmu_string, $i0_string, $signal_string) = (q{}, q{}, q{});
  if ($self->datatype eq 'chi') {
    $chi_string = $self->chi_column;
  } elsif ($self->ln) {
    $xmu_string    = "ln(abs(  ("
	           . $self->numerator
                   . ") / ("
		   . $self->denominator
		   . ") ))";
    $i0_string     = $self->numerator;
    $signal_string = $self->denominator;
  } else {
    $xmu_string    = "(" . $self->numerator . ") / (" . $self->denominator . ")";
    $i0_string     = $self->denominator;
    $signal_string = $self->numerator;
  };
  if ($self->multiplier != 1) {
    $xmu_string    = $self->multiplier . "*" . $xmu_string;
    $signal_string = $self->multiplier . "*" . $signal_string;
  };
  if ($self->inv) {
    $xmu_string    = "-1*" . $xmu_string;
    $signal_string = "-1*" . $signal_string;
  };

  ## resolve column tokens
  my $group = $self->group;
  if ($self->datatype eq 'chi') {
    $chi_string    =~ s{\$(\d+)}{$group.$cols[$1]}g;
    $energy_string =~ s{\$(\d+)}{$group.$cols[$1]}g;
    $self->chi_string($chi_string);
  } else {
    $i0_string     =~ s{\$(\d+)}{$group.$cols[$1]}g;
    $signal_string =~ s{\$(\d+)}{$group.$cols[$1]}g;
    $xmu_string    =~ s{\$(\d+)}{$group.$cols[$1]}g;
    $energy_string =~ s{\$(\d+)}{$group.$cols[$1]}g;

    $self->i0_string($i0_string);
    $self->signal_string($signal_string);
    $self->xmu_string($xmu_string);
  };
  $self->energy_string($energy_string);

  if (($self->display) and ($self->datatype ne 'chi')) {
    $self->dispense("process", "display");
    $self->update_data(1) if ($self->xmu_string =~ m{\(1\)\s*/\s*\(1\)}); ## need to reread data file to
    $self->update_data(1) if ($self->xmu_string =~ m{\.xmu\b}); ## avoid a looping definition of the column
    return;			                                ## labeled "xmu"
  };

  if ($self->datatype eq 'chi') {
    my $command = $self->template("process", "chi_column");
    $self->dispose($command);
    return if $self->display;
    $self->update_columns(0);
    $self->update_data(0);
    $self->resolve_defaults;

  } else {
    if ($self->quickmerge) {
      my $command = $self->template("process", "columns_qm");
      $command   .= $self->template("process", "deriv_qm");
      $self->dispose($command);
    } else {
      my $command = $self->template("process", "columns");
      $command   .= $self->template("process", "deriv");
      $self->dispose($command);
      $self->i0_scale($self->fetch_scalar('__i0_scale'));
      $self->signal_scale($self->fetch_scalar('__signal_scale'));
      $self->update_columns(0);
      $self->update_data(0);
      $self->initialize_e0 if not $self->is_nor; # we take a somewhat different path through these chores for pre-normalized data
    };
  };
  return $self;
};

sub fix_chik {
  my ($self) = @_;
  my @k = $self->get_array('k');
  return $self if ( ($k[0] == 0) and (all { abs($k[$_] - $k[$_-1] - 0.05) < $EPSILON4 } (1 .. $#k)) );
  #my $command = 
  $self->dispense("process", "fix_chik");
  #print $command;
  #$self->dispose($command);
  return $self;
};

sub initialize_e0 {
  my ($self) = @_;
  $self->e0('ifeffit') if not $self->bkg_e0;
  $self->resolve_defaults;
};

sub normalize {
  my ($self) = @_;
  my $group = $self->group;

  if ($self->datatype eq 'detector') {
    carp($self->name . " is a detector group, which cannot be normalized\n\n");
    return $self;
  };
  $self->_update("normalize");

  my $fixed = ($self->bkg_fixstep) ? $self->bkg_step : 0;

  if (not $self->is_nor) {
    ## call pre_edge()
    my $precmd = $self->template("process", "normalize");
    $self->dispose($precmd);

    my $was = $self->bkg_e0;
    my $e0 = $self->fetch_scalar("e0");
    $self->bkg_e0($e0) if (abs($was - $e0) > $EPSILON3); # avoid a tiny numerical "surprise" from Larch
    if (lc($self->bkg_z) eq 'h') {
      my ($elem, $edge) = $self->find_edge($e0);
      $self->bkg_z($elem);
      $self->fft_edge($edge);
    };
    $self->bkg_spl1($self->bkg_spl1); # this odd move sets the spl1e and
    $self->bkg_spl2($self->bkg_spl2); # spl2e attributes correctly for the
				      # new value of e0

    ## incorporate results of pre_edge() into data object
    $self->bkg_nc0(sprintf("%.14f", $self->fetch_scalar("norm_c0")));
    $self->bkg_nc1(sprintf("%.14f", $self->fetch_scalar("norm_c1")));
    $self->bkg_nc2(sprintf("%.14g", $self->fetch_scalar("norm_c2")));
    $self->bkg_nc3(sprintf("%.14g", $self->fetch_scalar("norm_c3"))) if $self->is_larch;

    if ($self->datatype eq 'xmudat') {
      $self->bkg_slope(0);
      $self->bkg_int(0);
      $self->is_nor(1);
    } else {
      $self->bkg_step(1);
      #$self->bkg_fixstep(1);
      $self->bkg_slope(sprintf("%.14f", $self->fetch_scalar("pre_slope")));
      $self->bkg_int(sprintf("%.14f", $self->fetch_scalar("pre_offset")));
    };
    $self->bkg_step(sprintf("%.7f", $fixed || $self->fetch_scalar("edge_step")));
    $self->bkg_fitted_step($self->bkg_step) if not ($self->bkg_fixstep);

    ## group.pre_edge *must* be set here.  does all of this need to be called at this point?
    #my $command = q{};
    #$command .= $self->template("process", "post_autobk");
    if (($self->bkg_fixstep) or ($self->datatype eq 'xanes')) {
      $self->dispense("process", "flatten_fit");
    #} else {
    #  $command .= $self->template("process", "flatten_set");
    };
    #$self->dispose($command);
    $self->bkg_nc0(sprintf("%.14f", $self->fetch_scalar("norm_c0")));
    $self->bkg_nc1(sprintf("%.14f", $self->fetch_scalar("norm_c1")));
    $self->bkg_nc2(sprintf("%.14g", $self->fetch_scalar("norm_c2")));
    $self->bkg_nc3(sprintf("%.14g", $self->fetch_scalar("norm_c3"))) if $self->is_larch;
    $self->dispense("process", "nderiv");
  } else { # we take a somewhat different path through these chores for pre-normalized data
    $self->bkg_step(1);
    $self->bkg_fitted_step(1);
    $self->dispense("process", "is_nor");
  };

  $self->update_norm(0);
  return $self;
};

sub edgestep_error {
  my ($self, $plot) = @_;

  my $stat = Statistics::Descriptive::Full->new();

  my @bubbles = (Demeter->co->default('edgestep', 'pre1'),
		 Demeter->co->default('edgestep', 'pre2'),
		 Demeter->co->default('edgestep', 'nor1'),
		 Demeter->co->default('edgestep', 'nor2'),
		);
  my @save    = $self->get(qw(bkg_pre1 bkg_pre2 bkg_nor1 bkg_nor2));
  push @save, $self->po->showlegend;
  my @params  = qw(bkg_pre1 bkg_pre2 bkg_nor1 bkg_nor2);
  my $size    = Demeter->co->default('edgestep', 'samples');
  my $margin  = Demeter->co->default('edgestep', 'margin');

  $self->_update('background');
  $stat -> add_data($self->bkg_step);
  my $init = $self->bkg_step;

  $self->po->start_plot;
  $self->po->showlegend(0);
  my @plotsave = $self->po->get(qw(e_mu e_bkg e_norm e_markers e_pre e_post
				   e_i0 e_signal e_der e_sec emin emax));
  $self->po->set(e_mu=>1, e_bkg=>0, e_norm=>1, e_markers=>0, e_pre=>0, e_post=>0,
		 e_i0=>0, e_signal=>0, e_der=>0, e_sec=>0,
		 emin=>-100, emax=>250);

  ## crerate a sampling of edge step values from randomized normalization parameters
  foreach my $i (1 .. $size) {
    $self->call_sentinal($i, $size);
    foreach my $j (0 ..3) {
      my $p = $params[$j];
      $self->$p($save[$j] + rand(2*$bubbles[$j]) - $bubbles[$j]);
    };
    $self -> normalize;
    $self -> plot('E') if $plot;
    $stat -> add_data($self->bkg_step);
  };

  my $sd = $stat -> standard_deviation;
  my $text = sprintf("\tedge step with outliers is %.5f +/- %.5f  (%d samples)\n",
		     $stat->mean, $sd, $stat->count);

  my @full = $stat->get_data;
  my ($final, $m, $unchanged, $prev) = (0, $margin, 0, 0);

  ## weed out outliers until the original edge step value and the
  ## average are close enough
  while (abs($init - $final) > $sd/$margin) {
    my @list = ();
    foreach my $es (@full) {
      next if (abs($es-$init) > $m*$sd);
      push @list, $es;
    };
    $stat->clear;
    $stat->add_data(@list);

    $final = $stat->mean;
    $sd = $stat->standard_deviation;
    if ($prev == $final) {
      ++$unchanged;
    } else {
      $unchanged = 0;
    };
    $prev = $final;
    $text .= sprintf("\tedge step without outliers is %.5f +/- %.5f  (%d samples, margin = %.1f, unchanged count = %d)\n",
		     $final, $sd, $stat->count, $m, $unchanged);
    $m -= 0.2;
    last if ($unchanged == 4);	# bail if mean is unchanged -- probably means sample has no outliers
    last if $m < 1.5;
  };

  my $report = sprintf("Full sample size = %d\n", $size+1);
  $report   .= sprintf("Sample size with outliers removed = %d\n", $stat->count);
  $report   .= sprintf("Current edge step value = %.5f\n", $init);
  $report   .= sprintf("Average edge step value = %.5f\n", $final);
  $report   .= sprintf("Approximate uncertainty in edge step = %.5f\n\n", $sd);

  $report   .= "Progress report:\n";
  $report   .= $text;

  ## restore states of Data and Plot objects
  $self->set(bkg_pre1=>$save[0], bkg_pre2=>$save[1], bkg_nor1=>$save[2], bkg_nor2=>$save[3]);
  $self->po->showlegend($save[4]);
  $self->po->set(e_mu     =>$plotsave[0], e_bkg   =>$plotsave[1],  e_norm=>$plotsave[2],
		 e_markers=>$plotsave[3], e_pre   =>$plotsave[4],  e_post=>$plotsave[5],
		 e_i0     =>$plotsave[6], e_signal=>$plotsave[7],  e_der =>$plotsave[8],
		 e_sec    =>$plotsave[9], emin    =>$plotsave[10], emax  =>$plotsave[11]);
  $self -> normalize;

  return ($final, $sd, $report);
};



sub autobk {
  my ($self) = @_;
  my $group = $self->group;
#      print ">>>", $self->datatype, "  ", $self->update_bkg, $/;

  if ($self->datatype eq 'detector') {
    carp($self->name . " is a detector group, which cannot have its background removed\n\n");
    return $self;
  };
  $self->_update("background");
  my $fixed = $self->bkg_fixstep;

  ## make sure that a fitted edge step actually exists...
  $self->bkg_fitted_step($self->bkg_step) if not $self->bkg_fitted_step;

  $self->bkg_kwindow('kaiser')        if ($self->is_larch   and ($self->bkg_kwindow eq 'kaiser-bessel'));
  $self->bkg_kwindow('kaiser-bessel') if ($self->is_ifeffit and ($self->bkg_kwindow eq 'kaiser'       ));
  my $save = $self->bkg_dk;
  if ($self->is_larch and ($self->bkg_kwindow eq 'kaiser')) {
    $self->bkg_dk(0.1) if ($self->bkg_dk < 0.1); # fix numerical error in larch implementation of kaiser window
  }

  my $command = q{};
  if (lc($self->bkg_stan) ne 'none') {
    my $stan = $self->mo->fetch("Data", $self->bkg_stan);
    $command .= $stan->template("process", "autobk") if ($stan->update_bkg  and ($stan->datatype =~ m{xmu}));
  };
  $command .= $self->template("process", "autobk");
  $fixed = $self->bkg_step if $self->bkg_fixstep;

  if ($self->is_nor) {		# we take a somewhat different path through these chores for pre-normalized data
    my $was = $self->bkg_e0;
    my $e0 = $self->fetch_scalar("e0");
    my ($elem, $edge) = $self->find_edge($e0);
    $self->bkg_e0($e0) if (abs($was - $e0) > $EPSILON3); # avoid a tiny numerical "surprise" from Larch
    $self->bkg_z($elem);
    $self->fft_edge($edge);
    $self->bkg_spl1($self->bkg_spl1); # this odd move sets the spl1e and
    $self->bkg_spl2($self->bkg_spl2); # spl2e attributes correctly for the
				      # new value of e0
    $self->bkg_nor2($self->co->default('bkg', 'nor2'));
    $self->resolve_defaults;
  };
  $self->dispose($command);
  ##$self->bkg_step(sprintf("%.7f", $fixed || $self->fetch_scalar("edge_step")));
  $self->bkg_dk($save);

## is it necessary to do post_autobk and flatten templates here?  they
## *were* done in the normalize method...

  ## begin setting up all the generated arrays from the background removal
  $self->update_fft(1);
  $self->bkg_cl(0);
  $command = $self->template("process", "post_autobk");
  if ($self->is_nor) {
    $command .= $self->template("process", "deriv");
    $command .= $self->template("process", "nderiv");
    $command .= $self->template("process", "is_nor");
  };

  #$self->dispose($command);

  if ($self->bkg_fixstep or $self->is_nor or ($self->datatype eq 'xanes')) {
    $command .= $self->template("process", "flatten_fit");
  } else {
    $command .= $self->template("process", "flatten_set");
  };
  #$self->dispose($command);

  ## first and second derivative
  #$command .= $self->template("process", "deriv");
  $command .= $self->template("process", "nderiv") if not $self->is_nor;
  $self->dispose($command);
    $self->bkg_nc0(sprintf("%.14f", $self->fetch_scalar("norm_c0")));
    $self->bkg_nc1(sprintf("%.14f", $self->fetch_scalar("norm_c1")));
    $self->bkg_nc2(sprintf("%.14g", $self->fetch_scalar("norm_c2")));
    $self->bkg_nc3(sprintf("%.14g", $self->fetch_scalar("norm_c3"))) if $self->is_larch;

  ## note the largest value of the k array
  my @k = $self->get_array('k');
  $self->maxk($k[$#k]) if @k;

  $self->update_bkg(0);
  return $self;
};
alias spline => 'autobk';


sub plotE {
  my ($self) = @_;
  $self -> dispose($self->_plotE_command);
};
sub _plotE_command {
  my ($self) = @_;
  if (not ref($self) =~ m{Data}) {
    my $class = ref $self;
    croak("$class objects are not plottable");
  };
  if (($self->datatype ne 'xmu') and ($self->datatype ne 'xanes')) {
    carp("$self cannot be plotted in energy\n\n") if not $self->mo->silently_ignore_unplottable;
    return;
  };

  ## need to handle single or multiple data set plots.  presumably for a
  ## multiple plot you want to increment colors and just plot data.  presumably
  ## for a single, you want to increment internally and plot several traces
  my $incr = $self->po->increm;

  ## walk through the attributes of the plot object to figure out what parts
  ## off the data should be plotted
  my @suffix_list = ();
  my @color_list  = ();
  my @key_list    = ();
  my @save = ($self->bkg_eshift, $self->bkg_e0);
  if ($self->po->e_zero) {
    $self->bkg_eshift($save[0] - $self->bkg_e0);
    $self->bkg_e0(0);
  };
  if ($self->po->e_bkg and not ($self->datatype eq 'xanes')) { # show the background
    my $this = 'bkg';
    ($this = 'nbkg') if ($self->po->e_norm);
    ($this = 'fbkg') if ($self->po->e_norm and $self->bkg_flatten);
    push @suffix_list, $this;
    my $n = $incr+1;
    my $cn = "col$n";
    push @color_list,  $self->po->$cn;
    push @key_list,    "background";
  };
  if ($self->po->e_mu) { # show the data
    my $this = 'xmu';
    if  ($self->po->e_der) {
      $this = ($self->po->e_norm) ? 'nder' : 'der';
    } elsif  ($self->po->e_sec) {
      $this = ($self->po->e_norm) ? 'nsec' : 'sec';
    } elsif ($self->po->e_norm and $self->bkg_flatten) {
      $this = 'flat';
    } elsif ($self->po->e_norm) {
      $this = 'norm';
    };
    if ($self->po->e_smooth) {
      $self -> co -> set(smooth_suffix => $this);
      $self->dispense('process', 'smoothed');
      $this = 'smooth';
    };
    push @suffix_list, $this;
    my $n = $incr % 10;
    my $cn = "col$n";
    push @color_list,  $self->po->$cn;
    push @key_list,    $self->name;
  };
  if ($self->po->e_pre)  { # show the pre_edge
    push @suffix_list, 'pre_edge';
    my $n = ($incr+2) % 10;
    my $cn = "col$n";
    push @color_list,  $self->po->$cn;
    push @key_list,    "pre-edge";
  };
  if ($self->po->e_post) { # show the post_edge
    push @suffix_list, 'post_edge';
    my $n = ($incr+3) % 10;
    my $cn = "col$n";
    push @color_list,  $self->po->$cn;
    push @key_list,    "post-edge";
  };
  if ($self->po->e_margin) { # show the deglitching margins
    my $ok = $self->make_margins;
    if ($ok) {
      push @suffix_list, 'margin1';
      my $n = ($incr+6) % 10;
      my $cn = "col$n";
      push @color_list,  $self->po->$cn;
      push @key_list,    "margin";
      push @suffix_list, 'margin2';
      push @color_list,  $self->po->$cn;
      push @key_list,    "";
    };
  };
  if ($self->po->e_i0) { # show i0
    if ($self->i0_string) {
      push @suffix_list, 'i0';
      my $n = ($incr+4) % 10;
      $n = $incr if ($self->po->is_i0_plot);
      $n = $incr+4 if ($self->po->is_d0s_plot);
      my $cn = "col$n";
      push @color_list,  $self->po->$cn;
      push @key_list,    ($self->po->e_mu) ? $self->po->i0_text : $self->name . ": " . $self->po->i0_text;
    };
  };
  if ($self->po->e_signal) { # show signal
    if ($self->signal_string) {
      push @suffix_list, 'signal';
      my $n = ($incr+5) % 10;
      my $cn = "col$n";
      push @color_list,  $self->po->$cn;
      push @key_list,    ($self->po->e_mu) ? 'signal' : $self->name . ": signal";
    };
  };

  ## convert plot ranges from relative to absolute energies
  my ($emin, $emax) = map {$_ + $self->bkg_e0} ($self->po->emin, $self->po->emax);

  my $string = q{};
  my ($xlorig, $ylorig) = ($self->po->xlabel, $self->po->ylabel);
  my $xl = "E (eV)" if (defined($xlorig) and ($xlorig =~ /^\s*$/));
  my $yl = q{};
  if ($ylorig =~ /^\s*$/) {
    $yl = ($self->po->e_der and $self->po->e_norm)  ? 'deriv normalized x\gm(E)'
        : ($self->po->e_der)                        ? 'deriv x\gm(E)'
        : ($self->po->e_sec and $self->po->e_norm)  ? 'second deriv normalized x\gm(E)'
        : ($self->po->e_sec)                        ? 'second deriv x\gm(E)'
	: ($self->po->e_norm)                       ? 'normalized x\gm(E)'
	:                                             'x\gm(E)';
  };
  ($self->po->showlegend) ? $self->po->key($self->name) : $self->po->key(q{});
  my $title = $self->name||q{Data};
  $self->po->title(sprintf("%s in energy", $title)) if not $self->po->title;
  #$self->po->title(sprintf("%s", $self->name||q{}));
  $self->po->xlabel($xl);
  $self->po->ylabel($yl);

  my ($plot, $cont);
  my $counter = 0;
  foreach my $suff (@suffix_list) {  # loop through list of parts to plot
    $self->po->color(shift(@color_list));
    ($self->po->showlegend) ? $self->po->key(shift(@key_list)) : $self->po->key(q{});
    $self->po->e_part($suff);
    $string .= $self->_plotE_string;
    $self->po->increment;
    $self->po->New(0) if ($self->get_mode("template_plot") eq 'pgplot');;
    ++$counter;
  };
  my $markers = q{};
  if ($self->po->e_markers) {
    my $this = 'xmu';
    if  ($self->po->e_smooth) {
      $this = 'smooth';
    } elsif  ($self->po->e_der) {
      $this = ($self->po->e_norm) ? 'nder' : 'der';
    } elsif  ($self->po->e_sec) {
      $this = ($self->po->e_norm) ? 'nsec' : 'sec';
    } elsif ($self->po->e_norm) {
      $this = 'norm';
    } elsif ($self->po->e_norm and $self->bkg_flatten) {
      $this = 'flat';
    };
#      my $this = 'xmu';
#      ($this = 'norm') if  ($self->po->get('e_norm'));
#      ($this = 'flat') if (($self->po->get('e_norm')) and $self->get('bkg_flatten'));
#      ($this = 'der')  if  ($self->po->get('e_der'));
    $markers .= $self->_e0_marker_command($this);
    $markers .= $self->_preline_marker_command($this)  if $self->po->e_pre;
    $markers .= $self->_postline_marker_command($this) if $self->po->e_post;
  };
  ## reinitialize the local plot parameters
  #$self->po -> reinitialize($xlorig, $ylorig);
  #return ($self->get_mode("template_plot") eq 'gnuplot') ? $markers.$string : $string.$markers;
  if ($self->po->e_zero) {
    $self->bkg_eshift($save[0]);
    $self->bkg_e0($save[1]);
  };
  return $string.$markers.$/;
};

sub _plotE_string {
  my ($self) = @_;
  my $group = $self->group;
  my $string = ($self->po->New)
             ? $self->template("plot", "newe")
             : $self->template("plot", "overe");
  return $string;
};


sub make_margins {
  my ($self) = @_;
  if (($self->po->margin_min < 0) and ($self->po->margin_max > 0)) {
    return 0;
  };
  if (($self->po->margin_min > 0) and ($self->po->margin_max < 0)) {
    return 0;
  };

  if (($self->po->margin_min > 0) and ($self->po->margin_max > 0)) {
    $self->dispense("process", "margin", {suffix=>"post_edge"});
  } else {
    $self->dispense("process", "margin", {suffix=>"pre_edge"});
  };
  return 1;
};

sub plot_ed {
  my ($self) = @_;
  my @deriv = $self->get_array('nder');
  @deriv = map {abs($_)} @deriv;
  my $scale = sprintf("%.3f", $self->co->default('plot', 'ed_scale') / max(@deriv));

  my $scale_save = $self->plot_multiplier;
  my $name = $self->name;
  my @keys = qw(e_mu e_bkg e_norm e_der e_pre e_post e_i0 e_signal e_markers);
  my @save = $self->po->get(@keys);
  $self->po->set(e_mu      => 1,    e_bkg     => 0,
		 e_norm    => 1,    e_der     => 0,
		 e_pre     => 0,    e_post    => 0,
		 e_i0      => 0,    e_signal  => 0,
		 e_markers => 1,
		);
  $self->po->emin($self->co->default('plot', 'ed_min'));
  $self->po->emax($self->co->default('plot', 'ed_max'));


  $self->po->start_plot;
  $self->plot('E');
  $self->po->set(e_der=>1, e_markers => 0);
  $self->plot_multiplier($scale);
  $self->name("Derivative spectrum, scaled by $scale");
  $self->plot('E');

  $self->plot_multiplier($scale_save);
  $self->name($name);
  $self->po->set(zip(@keys, @save));
};


=for LiteratureReference (find_edge) (e0)
  "Gnosis," in Greek, means "knowledge"; it has been conjectured that
  [the Swiss alchemist] Paracelsus invented the word "gnome" because
  these creatures knew, and could reveal to men, the exact location of
  hidden metals.
                                   Jorge Luis Borges
                                   The Book of Imaginary Beings

=cut

sub find_edge {
  my ($self, $e0) = @_;
  ##return ('H', 'K') unless ($absorption_exists);
  my $input = $e0;
  my ($edge, $answer, $this) = ("K", 1, 0);
  my $diff = 100000;
  my $xdi_elem = (exists $self->xdi_scan->{element}) ? $self->xdi_scan->{element} : q{};
  my $xdi_edge = (exists $self->xdi_scan->{edge})    ? $self->xdi_scan->{edge}    : q{};
  return ($xdi_elem, $xdi_edge) if ($xdi_elem and $xdi_edge);
  foreach my $ed (qw(K L1 L2 L3)) {  # M1 M2 M3 M4 M5
  Z: foreach (1..104) {
      last Z unless (Xray::Absorption->in_resource($_));
      my $e = Xray::Absorption -> get_energy($_, $ed);
      next Z unless $e;
      $this = abs($e - $input);
      last Z if (($this > $diff) and ($e > $input));
      if ($this < $diff) {
	$diff = $this;
	$answer = $_;
	$edge = $ed;
	#print "$answer  $edge\n";
      };
    };
  };
  my $elem = get_symbol($answer);
  ##if ($config{general}{rel2tmk}) {
  do {
    ## give special treatment to the case of fe oxide.
    ($elem, $edge) = ("Fe", "K")  if (($elem eq "Nd") and ($edge eq "L1"));
    ## give special treatment to the case of co oxide.
    ($elem, $edge) = ("Co", "K")  if (($elem eq "Sm") and ($edge eq "L1"));
    ## give special treatment to the case of ni oxide.
    ($elem, $edge) = ("Ni", "K")  if (($elem eq "Er") and ($edge eq "L3"));
    ## give special treatment to the case of mn oxide.
    ($elem, $edge) = ("Mn", "K")  if (($elem eq "Ce") and ($edge eq "L1"));
    ## prefer Bi L3 to Ir L1
    ($elem, $edge) = ("Bi", "L3") if (($elem eq "Ir") and ($edge eq "L1"));
    ## prefer Se K to Tl L3
    ($elem, $edge) = ("Se", "K")  if (($elem eq "Tl") and ($edge eq "L3"));
    ## prefer Pt L3 to W L2
    #($elem, $edge) = ("Pt", "L3") if (($elem eq "W") and ($edge eq "L2"));
    ## prefer Se K to Pb L2
    ($elem, $edge) = ("Rb", "K")  if (($elem eq "Pb") and ($edge eq "L2"));
    ## prefer Np L3 to At L1
    #($elem, $edge) = ("Np", "L3")  if (($elem eq "At") and ($edge eq "L1"));
    ## prefer Cr K to Ba L1
    ($elem, $edge) = ("Cr", "K")  if (($elem eq "Ba") and ($edge eq "L1"));
    ## prefer Ni K to Er L3
    #($elem, $edge) = ("Ni", "K")  if (($elem eq "Er") and ($edge eq "L3"));
    ## prefer Pd K to Bk L2
    ($elem, $edge) = ("Pd", "K")  if (($elem eq "Bk") and ($edge eq "L2"));
  };
  return ($elem, $edge);
};

sub _save_xmu_command {
  my ($self, $filename) = @_;
  croak("No filename specified for save_xmu") unless $filename;

  $self->title_glob("dem_data_", "e");
  my $string = $self->template("process", "save_xmu", {filename => $filename,
						       titles   => "dem_data_*"});
  return $string;
};
sub _save_norm_command {
  my ($self, $filename) = @_;
  croak("No filename specified for save_norm") unless $filename;
  $self->title_glob("dem_data_", "n");
  my $string = $self->template("process", "save_norm", {filename => $filename,
							titles   => "dem_data_*"});
  return $string;
};

sub find_white_line {
  my ($self) = @_;
  return -999 if ($self->datatype !~ m{xmu|xanes});
  $self->_update('fft');
  #my $sm = $self->boxcar(11);
  #$sm->_update('fft');
  my @energy = $self->get_array("energy");
  my @mu     = $self->get_array("xmu");
  #my @flat   = $self->get_array("flat");
  my $e0 = $self->bkg_e0;
  my $i = firstidx {$_ > $e0} @energy;
  my $prev = $mu[$i++];
  my ($wl, $iwl, $err) = (0,0,0);
  foreach my $j ($i .. $#mu) {
    if ($mu[$j] < $prev) {
      $wl = $energy[$j-1];
      $iwl = $j-1;
      last;
    };
    $prev = $mu[$j];
  };

  my $margin = Demeter->co->default('whiteline', 'margin');
  my $grid   = Demeter->co->default('whiteline', 'grid');
  my ($en, $ex) = ($energy[$iwl-$margin]+$self->bkg_eshift, $energy[$iwl+$margin]+$self->bkg_eshift);
  $self->dispense('process', 'find_wl', {emin=>$en, emax=>$ex, suffix=>'flat'});
  $wl = $en + $grid*($self->fetch_scalar('__wl')-1);
  return (wantarray) ? ($wl, $err) : $wl;

  # my $margin = 5;
  # print join("|", $wl, $iwl, $energy[$iwl], $mu[$iwl]), $/;
  # my $peak = Demeter::PeakFit->new(data=>$self,
  # 				   xmin=>$energy[$iwl-$margin]+$self->bkg_eshift-$self->bkg_e0,
  # 				   xmax=>$energy[$iwl+$margin]+$self->bkg_eshift-$self->bkg_e0);
  # print join("|", $energy[$iwl-3]+$self->bkg_eshift, $energy[$iwl+3]+$self->bkg_eshift), $/;
  # print join("|", $peak->xmin, $peak->xmax,$flat[$iwl]), $/;
  # $peak -> backend($ENV{DEMETER_BACKEND});
  # my $ls = $peak -> add('gaussian', center=>$energy[$iwl], fix1=>0, height=>$flat[$iwl],
  # 			width=>($energy[$iwl+$margin]-$energy[$iwl+$margin])/2, name=>'wl');
  # $peak -> fit;
  # $peak -> plot;
  # return (wantarray) ? ($ls->a1, $ls->e1) : $ls->a1;
};


1;


=head1 NAME

Demeter::Data::Mu - Methods for processing and plotting mu(E) data

=head1 VERSION

This documentation refers to Demeter version 0.9.18.

=head1 SYNOPSIS

  my $data = Demeter::Data -> new;
  $data -> set(file      => "fe.060.xmu",
	       name      => 'My copper data',
               bkg_rbkg  => 1.4,
               bkg_spl2e => 1800,
	      );
  $data -> plot("k");

=head1 DESCRIPTION

This role of Demeter::Data contains methods for dealing with mu(E)
data.

=head1 METHODS

=head2 Data processing methods

These methods are very rarely called explicitly in a script.  Rather
they get called behind the scenes when plots are made using the
C<plot> method or if some other method is called which requires that
the data first be processed in energy.  They are documented here for
completeness.

=over 4

=item C<normalize>

This method normalizes the data and calculates the flattened,
normalized spectrum.

  $data_object -> normalize;

=item C<edgestep_error>

This method attempts to compute the uncertainty in the edge step.
This is done by generating a sampling of randomly chosen values for
the pre- and post-edge line parameters, computing the edge step for
each one, and computing the standard deviation in edge step values.
Care is taken to remove extreme outliers in edge step -- often caused
either by C<bkg_pre2> being too close to the edge or by C<bkg_nor1>
resulting in an overly large quadratic term in the post-edge line.

  ($mean, $sd, $report) = $data->edgestep_error($do_plot);

The return values are the average and standard deviation of the
sampling of edge step values and a bit of text with some information
abot how the calculation progressed.  When true, the parameter says to
plot the normalized spectrum for each sampling of parameter values.

=item C<autobk>

This method computes the background spline using the Autobk algorithm
and extracts chi(k) from the mu(E) data.

  $data_object -> autobk;

=item C<spline>

This is an alias for C<autobk>.

=item C<plotE>

This method plots the data in energy using information from the Plot
object.

  $data_object -> plotE;

This method is not typically called directly.  Instead it is called as
one of the options of the more generic C<plot> method.

=item C<guess_columns>

This method uses regular expressions in the file configuration group
to attempt to guess which columns are which in an input column data
file.  This is most useful in a GUI where a bad or undesirable guess
can be overridden interactively, but it still might be useful even in
a script.

  $data_object -> guess_columns;

This will set the C<ln>, C<numerator>, and C<denominator> attributes
of the Data object.  It will return attribute values suitable for
transmission in preference to fluorescence.  In the event that no
columns match, C<numerator> or C<denominator> (or possibly both) will
be set to the string C<"1">.

=back

=head2 I/O methods

These are methods used to write out column ASCII data containing data
in energy space.

=over 4

=item C<save_xmu>

This method writes an output mu(E) file containing the background,
pre- and post-edge lines, and first and second derivatives.

  $data_object -> save_xmu($filename);

This method is not typically called directly.  Instead it is called as
one of the options of the more generic C<save> method.

=item C<save_norm>

This method writes an output mu(E) file containing the normalized data
and background, flattened data and background, and the first and second
derivatives of the normalized data.

  $data_object -> save_norm($filename);

This method is not typically called directly.  Instead it is called as
one of the options of the more generic C<save> method.

=back

=head2 Code generating methods

Again, these are rarely needed in user scripts, but are documented for
completeness.

=over 4

=item C<step>

This method generates code for making an array containing a Heaviside
step function centered at the edge energy and placed on the grid of
the energy array associated with the object.  The resulting array
containing the step function will have the suffix C<step>.

    $string = $self->step;

=item C<_plotE_command>

This method generates a string containing the commands required to
plot data in energy.  It is called by the C<plotE> method, which then
disposes of the commands.

=back

=head2 Utility methods

These are handy methods related to energy space data processing that
might be needed in a user script.

=over 4

=item C<find_edge>

This method determines the absorber and edge of mu(E) data by
comparing the edge energy for these data to a table of edge energies
of the elements.

   ($elem, $edge) = $self->find_edge($e0);


=item C<clamp>

This method translates between numeric and descriptive values of
clamping strengths.  See the clamp configuration group for tuning the
translation between string and numeric clamp values.

=back

=head1 CONFIGURATION

See L<Demeter::Config> for a description of the configuration
system.

=head1 DEPENDENCIES

Demeter's dependencies are in the F<Bundle/DemeterBundle.pm> file.

=head1 BUGS AND LIMITATIONS

=over 4

=item *

Cromer-Liberman normalization is not yet implemented.

=item *

Something like the Penner-Hahn mxan would be nice also.

=item *

There is currently no mechanism for importing an array into Ifeffit
and associating an object with it.

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
