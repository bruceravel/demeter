package Demeter::Data::Plot;
use Moose::Role;

use Carp;
use Demeter::Constants qw($NUMBER);
use List::Util qw(max);
use List::MoreUtils qw(uniq zip);

##-----------------------------------------------------------------
## plotting methods

sub plot {
  my ($self, $space) = @_;
  my $pf   = $self->po;
  $space ||= $pf->space;
  ($space  = 'ed') if (lc($space) eq 'de');
  $space   = lc($space);
  $self->po->space(substr($space, 0, 1)) if ($space !~ m{(?:quad|stddev|variance)});;

  if (($self->datatype eq 'detector') and ($space ne 'e')) {
    carp($self->name . " is a detector group, which cannot be plotted in $space\n\n");
    return $self;
  };
  my $which = ($space eq 'e')     ? $self->_update('fft')
            : ($space eq 'ed')    ? $self->_update('fft')
            : ($space eq 'k')     ? $self->_update('fft')
            : ($space eq 'k123')  ? $self->_update('fft')
            : ($space eq 'r123')  ? $self->_update('bft')
            : ($space eq 'r')     ? $self->_update('bft')
            : ($space eq 'rmr')   ? $self->_update('bft')
            : ($space eq 'rk')    ? $self->_update('bft')
	    : ($space eq 'q')     ? $self->_update('all')
	    : ($space eq 'kq')    ? $self->_update('all')
	    : ($space eq 'kqfit') ? $self->_update('all')
            :                       q{};

 SWITCH: {
    ($space eq 'ed') and do {
      $self -> plot_ed;
      $pf   -> increment;
      return $self;
      last SWITCH;
    };
    ($space eq 'k123') and do {
      $self -> plotk123;
      $pf   -> increment;
      return $self;
      last SWITCH;
    };
    ($space =~ m{\Akq}) and do {
      $self -> plot_kqfit;
      $pf   -> increment;
      return $self;
      last SWITCH;
    };
    ($space eq 'r123') and do {
      $self -> plotR123;
      $pf   -> increment;
      return $self;
      last SWITCH;
    };
    ($space eq 'rmr' ) and do {
      $self -> plotRmr;
      $pf   -> increment;
      return $self;
      last SWITCH;
    };
    ($space eq 'rk' ) and do {
      $self -> rkplot;
      $pf   -> increment;
      return $self;
      last SWITCH;
    };
    ($space eq 'quad' ) and do {
      $self -> quadplot;
      return $self;
      last SWITCH;
    };
    ($space eq 'stddev' ) and do {
      $self -> stddevplot;
      return $self;
      last SWITCH;
    };
    ($space eq 'variance' ) and do {
      $self -> varianceplot;
      return $self;
      last SWITCH;
    };
  };

  $self->co->set(plot_part=>q{});
  my $command = $self->_plot_command($space);
  $self->dispose($command, "plotting");
  $self->po->after_plot_hook($self);
  $pf->increment if ($space ne 'e');
  if ((ref($self) =~ m{Data}) and $self->fitting and (not $self->is_fit)) {
    foreach my $p (qw(fit res bkg)) {
      my $pp = "plot_$p";
      next if not $pf->$pp;
      next if (($p eq 'bkg') and (not $self->fit_do_bkg));
      $self->part_plot($p, $space);
      $pf->increment;
    };
    if ($pf->plot_run) {
      $self->running($space);
      $self->plot_run($space);
      $pf->increment;
    };
  };
  if ($pf->plot_win and (not $self->is_fit)) {
    $self->plot_window($space);
    $self->po->after_plot_hook($self, 'win');
    $pf->increment;
  };

  return $self;
};
sub _plot_command {
  my ($self, $space) = @_;
  $space   = lc($space);

  if (not $self->plottable) {
    my $class = ref $self;
    croak("$class objects are not plottable");
  };
  if ((lc($space) eq 'e') and (not ref($self) =~ m{Data})) {
    my $class = ref $self;
    croak("$class objects are not plottable in energy") if not $self->mo->silently_ignore_unplottable;
  };
  my $string = ($space eq 'e')    ? $self->_plotE_command
            #: ($space eq 'k123') ? $self->_plotk123_command
             : ($space eq 'k')    ? $self->_plotk_command
             : ($space eq 'r')    ? $self->_plotR_command
            #: ($space eq 'rmr')  ? $self->_plotRmr_command
            #: ($space eq 'r123') ? $self->_plotR123_command
	     : ($space eq 'q')    ? $self->_plotq_command
	     : ($space eq 'kq')   ? $self->_plotkq_command
             : q{};
  return $string;
};

sub _plotk_command {
  my ($self, $space) = @_;
  if (not $self->plottable) {
    my $class = ref $self;
    croak("$class objects are not plottable");
  };
  if ((ref($self) =~ m{Data}) and ($self->datatype eq 'xanes')) {
    croak("XANES data are not plottable in k") if not $self->mo->silently_ignore_unplottable;
  };

  $space ||= 'k';
  my $pf  = $self->mo->plot;
  my $string = q{};
  my $group = $self->group;
  my $kw = $self->data->get_kweight;

  my ($xlorig, $ylorig) = ($pf->xlabel, $pf->ylabel);
  my $xl = "k (\\A\\u-1\\d)" if ((not defined($xlorig)) or ($xlorig =~ /^\s*$/));
  my $yl = $pf->plot_kylabel;
  (my $title = $self->name||q{}) =~ s{D_E_F_A_U_L_T}{Plot of paths};
  ($pf->showlegend) ? $pf->key($self->name) : $pf->key(q{});
  my $plotspace = ($pf->chie) ? 'E' : $space;
  $pf->title(sprintf("%s in %s space", $title, $plotspace)) if not $pf->title;
  $pf->xlabel($xl);
  $pf->ylabel($yl);
  my $newold = ($pf->New)  ? 'new'  : 'over';
  my $ke     = ($pf->chie) ? 'chie' : 'k';
  my $template = $newold . $ke;
  $string = $self->template("plot", $template);
  ## reinitialize the local plot parameters
  $pf -> reinitialize($xlorig, $ylorig);
  return $string;
};


sub _plotR_command {
  my ($self) = @_;
  if (not $self->plottable) {
    my $class = ref $self;
    croak("$class objects are not plottable");
  };
  if ((ref($self) =~ m{Data}) and ($self->datatype eq 'xanes')) {
    croak("XANES data are not plottable in R") if not $self->mo->silently_ignore_unplottable;
  };
  my $pf  = $self->po;
  my $string = q{};
  my $group = $self->group;
  my %suffix = ('m'=>"chir_mag", e=>"chir_mag", r=>"chir_re", i=>"chir_im", p=>"chir_pha");
  my %title = ('m'=>"Magnitude", e=>"Envelope", r=>"Real part", i=>"Imaginary part", p=>"Phase");
  my $kw = $self->data->get_kweight;
  my $xl = $pf->xlabel;
  $pf->xlabel("R (\\A)") if ((not defined($xl)) or ($xl =~ /^\s*$/));
  $pf->ylabel($pf->plot_rylabel);
  (my $title = $self->name||q{}) =~ s{D_E_F_A_U_L_T}{Plot of paths};
  ($pf->showlegend) ? $pf->key($self->name) : $pf->key(q{});
  $pf->title(sprintf("%s in R space", $title)) if not $pf->title;

  if ((lc($pf->r_pl) eq 'p') and $self->po->dphase) {
    $self->dispense('process', 'dphase');
    $title{p} = sprintf("Derivative of phase * %.4f", $self->fetch_scalar('___dphase_scale'));
    $self->dispense('process', 'erase', {items=>'___dphase_scale'});
  };
  $self->plotkey($title{lc($pf->r_pl)}) if ($self->po->single and (not $self->forcekey));
  $string = ($pf->New)
          ? $self->template("plot", "newr")
          : $self->template("plot", "overr");
  $self->plotkey(q{});
  if (lc($pf->r_pl) eq 'e') {		# envelope
    my $pm = $self->plot_multiplier;
    $self->plot_multiplier(-1*$pm);
    my $this = $self->template("plot", "overr");
    my $datalabel = $self->name;
    $this = $self->po->fix_envelope($this, $datalabel);
    $string .= $this;
    $self->plot_multiplier($pm);
  };

  ## reinitialize the local plot parameters
  $pf -> reinitialize(q{}, q{});
  return $string;
};

sub _plotq_command {
  my ($self) = @_;
  if (not $self->plottable) {
    my $class = ref $self;
    croak("$class objects are not plottable");
  };
  if ((ref($self) =~ m{Data}) and ($self->datatype eq 'xanes')) {
    croak("XANES data are not plottable in q") if not $self->mo->silently_ignore_unplottable;
  };
  my $pf  = $self->mo->plot;
  my $string = q{};
  my $group = $self->group;
  my %title = ('m'=>"Magnitude", e=>"Envelope", r=>"Real part", i=>"Imaginary part", p=>"Phase");
  #$title{p} = "Derivative of phase" if $self->po->dphase;
  my $kw = $self->data->get_kweight;
  my $xl = $pf->xlabel;
  $pf->xlabel("k (\\A\\u-1\\d)") if ($xl =~ m{\A\s*\z});
  $pf->ylabel($pf->plot_qylabel);
  (my $title = $self->name) =~ s{D_E_F_A_U_L_T}{Plot of paths};
  ($pf->showlegend) ? $pf->key($self->name) : $pf->key(q{});
  $pf->title(sprintf("%s in q space", $title)) if not $pf->title;
  $self->plotkey($title{lc($pf->q_pl)}) if $self->po->single;

  $string = ($pf->New)
          ? $self->template("plot", "newq")
          : $self->template("plot", "overq");
  $self->plotkey(q{});
  if (lc($pf->q_pl) eq 'e') {		# envelope
    my $pm = $self->plot_multiplier;
    $self->plot_multiplier(-1*$pm);
    my $this = $self->template("plot", "overq");
    my $datalabel = $self->name;
    $this = $self->po->fix_envelope($this, $datalabel);
    $string .= $this;
    $self->plot_multiplier($pm);
  };

  ## reinitialize the local plot parameters
  $pf -> reinitialize(q{}, q{});
  return $string;
};

sub _plotkq_command {
  my ($self) = @_;
  my $pf  = $self->po;
  if (not $self->plottable) {
    my $class = ref $self;
    croak("$class objects are not plottable");
  };
  if ((ref($self) =~ m{Data}) and ($self->datatype eq 'xanes')) {
    croak("XANES data are not plottable as kq") if not $self->mo->silently_ignore_unplottable;
  };
  my $string = q{};
  my $save = $self->name;
  $self->name($save . " in k space");
  $pf -> title("$save in k and q space");
  $string .= $self->_plotk_command;
  $pf -> increment;
  $self->name($save . " in q space");
  $string .= $self->_plotq_command;
  $self->name($save);
  return $string;
};

sub plotk123 {
  my ($self) = @_;
  if ((ref($self) =~ m{Data}) and ($self->datatype eq 'xanes')) {
    croak("XANES data are not plottable as k123") if not $self->mo->silently_ignore_unplottable;
  };

  my @save = ($self->name, $self->plot_multiplier, $self->y_offset, $self->po->kweight);
  my $string .= $self->template("process", "k123");
  $self->dispose($string);
  my @max = ($self->fetch_scalar("__123_max1"), $self->fetch_scalar("__123_max2"), $self->fetch_scalar("__123_max3"));
  my $winsave = $self->po->plot_win;

  $self->po->kweight(1);
  $self->po->title($self->name . " at kweight = 1, 2, and 3") if not $self->po->title;
  my $scale = sprintf("%.3f", $max[1]/$max[0]);
  $self->set(plot_multiplier => $scale, 'y_offset'=>1.2*$max[1],  name=>"$save[0]: kw=1, scaled by $scale");
  $self->plot('k');

  $self->po->plot_win(0);
  $self->po->kweight(2);
  $self->set(plot_multiplier => 1,   'y_offset'=>0,  name=>"$save[0]: kw=2, unscaled");
  $self->plot('k');

  $self->po->kweight(3);
  $scale = sprintf("%.3f", $max[1]/$max[2]);
  $self->set(plot_multiplier => $scale, 'y_offset'=>-1.2*$max[1],  name=>"$save[0]: kw=3, scaled by $scale");
  $self->plot('k');

  $self->po->kweight(2);
  $self->set(plot_multiplier => 1,   'y_offset'=>1.2*$max[1]);
  $self->plot_window('k') if $self->po->plot_win;

  $self->po->plot_win($winsave);
  $self->po->title(q{});
  $self->name($save[0]);
  $self->plot_multiplier($save[1]);
  $self->y_offset($save[2]);
  $self->po->kweight($save[3]);
  return $self;
};

sub plotR123 {
  my ($self) = @_;
  if ((ref($self) =~ m{Data}) and ($self->datatype eq 'xanes')) {
    croak("XANES data are not plottable as R123") if not $self->mo->silently_ignore_unplottable;
  };

  my @save = ($self->name, $self->plot_multiplier, $self->y_offset, $self->po->kweight);

  my @max;
  my $winsave = $self->po->plot_win;
  $self->po->kweight(1);
  $self->_update('bft');
  my @chir = $self->fetch_array($self->group.".chir_mag");
  push @max, max(@chir);
  $self->po->kweight(2);
  $self->_update('bft');
  @chir = $self->fetch_array($self->group.".chir_mag");
  push @max, max(@chir);
  $self->po->kweight(3);
  $self->_update('bft');
  @chir = $self->fetch_array($self->group.".chir_mag");
  push @max, max(@chir);

  $self->forcekey(1);
  $self->po->kweight(1);
  $self->po->title($self->name . " at kweight = 1, 2, and 3");
  my $scale = sprintf("%.3f", $max[1]/$max[0]);
  $self->set(plot_multiplier => $scale, 'y_offset'=>$max[1],  name=>"$save[0]: kw=1, scaled by $scale");
  $self->plot('r');

  $self->po->plot_win(0);
  $self->po->kweight(2);
  $self->set(plot_multiplier => 1,   'y_offset'=>0,  name=>"$save[0]: kw=2, unscaled");
  $self->plot('r');

  $self->po->kweight(3);
  $scale = sprintf("%.3f", $max[1]/$max[2]);
  $self->set(plot_multiplier => $scale, 'y_offset'=>-$max[1],  name=>"$save[0]: kw=3, scaled by $scale");
  $self->plot('r');

  $self->po->kweight(2);
  $self->_update('bft');
  $self->set(plot_multiplier => 1,   'y_offset'=>$max[1]);
  $self->plot_window('r') if $self->po->plot_win;
  $self->forcekey(0);

  $self->po->plot_win($winsave);
  $self->po->title(q{});
  $self->name($save[0]);
  $self->plot_multiplier($save[1]);
  $self->y_offset($save[2]);
  $self->po->kweight($save[3]);
  return $self;
};

sub plotRmr {
  my ($self) = @_;
  croak(ref $self . " objects are not plottable") if not $self->plottable;
  if ((ref($self) =~ m{Data}) and ($self->datatype eq 'xanes')) {
    croak("XANES data are not plottable as Rmr") if not $self->mo->silently_ignore_unplottable;
  };
  my $string = q{};
  my ($lab, $yoff, $down) = ( $self->name, $self->y_offset, $self->rmr_offset );
  my $winsave = $self->po->plot_win;

  ## plot magnitude part
  my $rpart = $self->po->r_pl;
  $self -> po -> r_pl('m');
  my $color = $self->po->color;
  my $inc   = $self->po->increm;
  $self -> plot('r');
  $self -> po -> New(0);

  ## plot real part
  $self -> po -> plot_win(0);
  $self -> y_offset($yoff+$down);
  $self -> name(q{});
  $self -> po -> r_pl($self->co->default("plot", "rmx"));
  $self -> po -> color($color);
  $self -> po -> increm($inc);
  $self -> plot('r');
  $self -> y_offset($yoff);

  $self->po->plot_win($winsave);
  $self -> name($lab);
  $self -> po -> r_pl($rpart);
  return $self;
};

sub plot_kqfit {
  my ($self) = @_;
  croak(ref $self . " objects are not plottable") if not $self->plottable;
  if ((ref($self) =~ m{Data}) and ($self->datatype eq 'xanes')) {
    croak("XANES data are not plottable as kq") if not $self->mo->silently_ignore_unplottable;
  };
  my ($lab, $yoff) = ( $self->name, $self->y_offset );
  my $winsave = $self->po->plot_win;
  my $qpart = $self->po->q_pl;

  ## figure out the vertical spacing between the traces
  my $string = $self->template("process", "k123");
  $self->dispose($string);
  my @max = ($self->fetch_scalar("__123_max1"), $self->fetch_scalar("__123_max2"), $self->fetch_scalar("__123_max3"));
  my $down = 0;
  if ($self->fitting) {
    my $k = int($self->po->kweight);
    ($k = 3) if ($k > 3);
    ($k = 1) if ($k < 1);
    $down = $max[$k-1];
  };

  $self->po->title($self->name . " in k and q space");

  ## plot magnitude part
  $self -> name('k space');
  $self -> plot('k');

  ## plot real part
  $self -> po -> plot_win(0);
  $self -> po -> q_pl('r');
  $self -> y_offset($yoff-$down);
  $self -> name('real part of q space');
  $self -> plot('q');
  $self -> y_offset($yoff);

  $self->po->plot_win($winsave);
  $self -> name($lab);
  $self -> po -> q_pl($qpart);
  return $self;
};


## this is obviously wrong for data of variable signal size -- those
## numbers were chosen for Iron metal
sub rmr_offset {
  my ($self) = @_;
  $self->_update('bft');
  if ($self->po->plot_rmr_offset) {
    my $kw = $self -> data -> get_kweight;
    return -10**($kw-1) * $self->po->offset if ($kw == 1);
  };
  return -0.6*max($self->get_array("chir_mag"));
};


sub default_k_weight {
  my ($self) = @_;
  my $data = $self->data;
  carp("Not an Demeter::Data object\n\n"), return 1 if (ref($data) !~ /Data/);
  my $kw = 1;			# return 1 is no other selected
 SWITCH: {
    $kw = sprintf("%.3f", $data->fit_karb_value), last SWITCH
      if ($data->karb and ($data->karb_value =~ $NUMBER));
    $kw = 1, last SWITCH if $data->fit_k1;
    $kw = 2, last SWITCH if $data->fit_k2;
    $kw = 3, last SWITCH if $data->fit_k3;
  };
  return $kw;
};

sub plot_window {
  my ($self, $space) = @_;
  $space ||= lc($self->po->space);
  $space = 'k' if ($space =~ m{[kq]});
  $space = 'r' if ($space =~ m{r});
  $self->fft if (lc($space) eq 'k');
  $self->bft if (lc($space) eq 'r');
  $self->dispose($self->_prep_window_command($space));
  #if (Demeter->get_mode('template_plot') eq 'gnuplot') {
  #  $self->get_mode('external_plot_object')->gnuplot_cmd($self->_plot_window_command($space));
  #  $self->get_mode('external_plot_object')->gnuplot_pause(-1);
  #} else {
  $self->dispose($self->_plot_window_command($space), "plotting");
  #};
  ## reinitialize the local plot parameters
  $self->po->reinitialize(q{}, q{});
  return $self;
};
sub _prep_window_command {
  my ($self, $sp) = @_;
  my $space   = lc($sp);
  #my %dsuff   = (k=>'chik', r=>'chir_mag', 'q'=>'chiq_mag');
  #my $suffix  = ($space =~ m{\Ar}) ? 'rwin' : 'win';
  my $string  = "\n" . $self->hashes . " plot window ___\n";
  if ($space =~ m{\Ar}) {
    $string .= $self->template("process", "prep_rwindow");
  } else {
    $string .= $self->template("process", "prep_kwindow");
  };
  return $string;
};

sub _plot_window_command {
  my ($self, $sp) = @_;
  my $space   = lc($sp);
  $self -> co -> set(window_space => $space,
		     window_size  => sprintf("%.5g", $self->fetch_scalar("win___dow")),
		    );
  my $string = $self->template("plot", "window");
  return $string;
};

sub plot_run {
  my ($self, $space) = @_;
  my $save   = $self->po->kweight;
  my $suff = (lc($space) eq 'k') ? 'chi'
           : (lc($space) eq 'r') ? 'chir_mag'
	   :                       'chiq_mag';
  my @fc = $self->floor_ceil($suff);

  $self -> co -> set(run_space => $space,
		     run_scale => $fc[1]*$self->po->window_multiplier);
  $self->po->kweight(0) if ($space eq 'k');
  my $string = $self->template("plot", "run");
  $self->dispose($string, "plotting");
  $self->po->after_plot_hook($self, 'run');
  $self->po->kweight($save);
return $self;
}

sub plot_marker {
  my ($self, $requested, $x) = @_;
  my $command = q{};
  my @list = (ref($x) eq 'ARRAY') ? @$x : ($x);
  foreach my $xx (@list) {
    my $which = ($requested eq 'chie') ? 'chi' : $requested;
    my $xxx = ($requested eq 'chie') ? $self->k2e($xx, 'absolute') : $xx ;
    my $y = $self->yofx($which, "", $xx);
    $y = $y*$xx**$self->data->get_kweight if ($requested eq 'chie');
    $command .= $self->template("plot", "marker", { x => $xxx, 'y'=> $y });
  };
  #if ($self->get_mode("template_plot") eq 'gnuplot') {
  #  $self->get_mode('external_plot_object')->gnuplot_cmd($command);
  #} else {
  $self -> dispose($command, "plotting");
  #};
  return $self;
};

sub stack {
  my ($self, @list) = @_;
  my @plotlist = uniq($self, @list);
  my $step = $self->y_offset;
  my $save = $step;
  foreach my $obj (@plotlist) {
    my $this_y_offset = $obj -> data -> y_offset;
    $obj  -> data  -> y_offset($step);
    $obj  -> plot;
    $step -= $self -> po -> stackjump;
    $obj  -> data  -> y_offset($this_y_offset);
  };
  $self -> y_offset($save);
  return $self;
};


sub running {
  my ($self, $space, $kw) = @_;
  $space ||= $self->po->space;
  $kw ||= $self->data->get_kweight;
  my ($diffsum, $max, $suff) = (0,0,q{});
  my @running = ();
 SWITCH: {
    (lc($space) eq 'k') and do {
      my @x    = $self->get_array('k');
      my @data = $self->get_array('chi');
      my @fit  = $self->get_array('chi', 'fit');
      my ($kmin, $kmax) = $self->get(qw(fft_kmin fft_kmax));
      foreach my $i (0 .. $#x) {
	push(@running, 0),        next if ($x[$i] < $kmin);
	push(@running, $running[$i-1]), next if ($x[$i] > $kmax);
	$diffsum += ($data[$i]*$x[$i]**$kw - $fit[$i]*$x[$i]**$kw)**2;
	push @running, $diffsum;
      };
      $max = max(@running);
      $suff = 'krun';
    };

    (lc($space) eq 'r') and do {
      my @x     = $self->get_array('r');
      my @datar = $self->get_array('chir_re');
      my @fitr  = $self->get_array('chir_re', 'fit');
      my @datai = $self->get_array('chir_im');
      my @fiti  = $self->get_array('chir_im', 'fit');
      my ($rmin, $rmax) = $self->get(qw(bft_rmin bft_rmax));
      foreach my $i (0 .. $#x) {
	push(@running, 0),        next if ($x[$i] < $rmin);
	push(@running, $running[$i-1]), next if ($x[$i] > $rmax);
	$diffsum += ($datar[$i]-$fitr[$i])**2 + ($datai[$i]-$fiti[$i])**2;
	push @running, $diffsum;
      };
      $max = max(@running);
      $suff = 'rrun';
    };

    (lc($space) eq 'q') and do {
      my @x     = $self->get_array('q');
      my @datar = $self->get_array('chiq_re');
      my @fitr  = $self->get_array('chiq_re', 'fit');
      my @datai = $self->get_array('chiq_im');
      my @fiti  = $self->get_array('chiq_im', 'fit');
      my ($kmin, $kmax) = $self->get(qw(fft_kmin fft_kmax));
      foreach my $i (0 .. $#x) {
	push(@running, 0),        next if ($x[$i] < $kmin);
	push(@running, $running[$i-1]), next if ($x[$i] > $kmax);
	$diffsum += ($datar[$i]-$fitr[$i])**2 + ($datai[$i]-$fiti[$i])**2;
	push @running, $diffsum;
      };
      $max = max(@running);
      $suff = 'qrun';
    };
  };

  @running = map {$_ / $max} @running;
  $self->place_array($self->group.".$suff", \@running);
};

sub stddevplot {
  my ($self) = @_;
  if (not $self->is_merge) {
    carp("Sorry, the stddevplot is only for merged data.") if not $self->mo->silently_ignore_unplottable;
    return $self;
  };
  my @e = qw(e_bkg e_pre e_post e_markers e_i0 e_signal);
  my @zeros = map {0} @e;
  my @vals = $self->po->get(@e);
  $self -> po -> set(zip(@e, @zeros));

  $self -> po -> start_plot;
  my $string = q{};
  if ($self->is_merge eq 'e') {
    $self -> po -> e_norm(0);
    $self -> plot('e');
    $string = $self->template("plot", "stddeve");
  } elsif ($self->is_merge eq 'n') {
    $self -> po -> e_norm(1);
    $self -> plot('e');
    $string = $self->template("plot", "stddevn");
  } elsif ($self->is_merge eq 'k') {
    $self -> plot('k');
    $string = $self->template("plot", "stddevk");
  };
  $self -> dispose($string, 'plotting');

  $self -> po -> set(zip(@e, @vals));
  return $self;
};

sub varianceplot {
  my ($self) = @_;
  if (not $self->is_merge) {
    carp("Sorry, the stddevplot is only for merged data.") if not $self->mo->silently_ignore_unplottable;
    return $self;
  };
  my @e = qw(e_bkg e_pre e_post e_markers e_i0 e_signal);
  my @zeros = map {0} @e;
  my @vals = $self->po->get(@e);
  $self -> po -> set(zip(@e, @zeros));

  $self -> co -> set(stddev_max=>max($self->get_array('stddev')));

  $self -> po -> start_plot;
  my $string = q{};
  if ($self->is_merge eq 'k') {
    $self -> co -> set(data_max=>max($self->get_array('chi')));
    $self -> plot('k');
    $string = $self->template("plot", "variancek");
  } else {
    $self -> co -> set(data_max=>max($self->get_array('xmu')));
    $self -> po -> e_norm(1) if ($self->is_merge eq 'n');
    $self -> plot('e');
    $string = $self->template("plot", "variancee");
  };
  $self -> dispose($string, 'plotting');

  $self -> po -> set(zip(@e, @vals));
  return $self;
};


sub quadplot {
  my ($self) = @_;
  if ($self->mo->template_plot ne 'gnuplot') {
    carp(sprintf("Sorry, the quadplot is not possible with the %s backend.", $self->mo->template_plot));
    return $self;
  };
  croak(ref $self . " objects are not plottable") if not $self->plottable;
  if ((ref($self) =~ m{Data}) and ($self->datatype eq 'xanes')) {
    carp("XANES data and non Data objects are not plottable as quadplots") if not $self->mo->silently_ignore_unplottable;
    return $self;
  };

  $self->_update('all');

  my $save = $self->co->default("plot", "showcopyright");
  $self->co->set_default("plot", "showcopyright", 0);
  $self -> po -> start_plot;
#  my $string = $self->template("plot", "quadstart");
#  $self -> dispose($string, 'plotting');

  my @e = qw(e_bkg e_pre e_post e_markers e_i0 e_signal);
  my @zeros = map {0} @e;
  my @vals = $self->po->get(@e);
  $self -> po -> set(zip(@e, @zeros));
  #$self -> po -> e_markers(0);
  #$self -> po -> e_bkg(1);

  my $string = $self->template("plot", "quad");
  $self -> dispose($string, 'plotting');


  # $self -> po -> title('energy');
  # $self -> plot('e');

  # $self -> po -> title('k space');
  # $self -> po -> New(1);
  # $self -> plot('k');

  # $self -> po -> title('R space');
  # $self -> po -> New(1);
  # $self -> plot('r');

  # $self -> po -> title('q space');
  # $self -> po -> space('q');
  # $self -> po -> New(1);
  # $self -> plot;

#  $string = $self->template("plot", "quadend");
#  $self -> dispose($string, 'plotting');

  $self -> po -> set(zip(@e, @vals));
  $self->co->set_default("plot", "showcopyright", $save);
  return $self;
};

sub rkplot {
  my ($self) = @_;
  if ($self->mo->template_plot ne 'gnuplot') {
    carp(sprintf("Sorry, the Rk plot is not possible with the %s backend.", $self->mo->template_plot));
    return $self;
  };
  croak(ref $self . " objects are not plottable") if not $self->plottable;
  if ((ref($self) =~ m{Data}) and ($self->datatype eq 'xanes')) {
    croak("XANES data and non Data objects are not plottable as Rk") if not $self->mo->silently_ignore_unplottable;
  };
  my $rpl = $self->po->r_pl;
  $self->po->r_pl('m');

  $self->_update('all');
  $self->part_fft('fit');

  $self -> po -> start_plot;
  $self -> po -> title($self->name);

  $self->dispose($self->_prep_window_command('R'));
  $self -> co -> set(window_space => 'R',
		     window_size  => sprintf("%.5g", $self->fetch_scalar("win___dow")),
		    );
  my $string = $self->template("plot", "rkr");

  $self->dispose($self->_prep_window_command('k'));
  $self -> co -> set(window_space => 'k',
		     window_size  => sprintf("%.5g", $self->fetch_scalar("win___dow")),
		    );
  $string   .= $self->template("plot", "rkk");
  $self -> dispose($string, 'plotting');

  $self->po->r_pl($rpl);
  return $self;
};


sub suffix {
  my ($self) = @_;
  my $suff = 'xmu';
  my $po = $self->po;
  if (($po->space eq 'e') and $po->e_norm and $po->e_der) {
    $suff = 'nder';
  } elsif (($po->space eq 'e') and $po->e_der) {
    $suff = 'der';
  } elsif (($po->space eq 'e') and $po->e_norm and $po->e_sec) {
    $suff = 'nsec';
  } elsif (($po->space eq 'e') and $po->e_sec) {
    $suff = 'sec';
  } elsif (($po->space eq 'e') and $po->e_norm and $self->bkg_flatten) {
    $suff = 'flat';
  } elsif (($po->space eq 'e') and $po->e_norm) {
    $suff = 'norm';
  } elsif  ($po->space eq 'k') {
    $suff = 'chi';
  } elsif  ($po->space eq 'chi') {
    $suff = 'chi';
  } elsif (($po->space eq 'r') and ($po->r_pl eq 'm')) {
    $suff = 'chir_mag';
  } elsif (($po->space eq 'r') and ($po->r_pl eq 'r')) {
    $suff = 'chir_re';
  } elsif (($po->space eq 'r') and ($po->r_pl eq 'i')) {
    $suff = 'chir_im';
  } elsif (($po->space eq 'r') and ($po->r_pl eq 'p')) {
    $suff = 'chir_pha';
  } elsif (($po->space eq 'q') and ($po->q_pl eq 'm')) {
    $suff = 'chiq_mag';
  } elsif (($po->space eq 'q') and ($po->q_pl eq 'r')) {
    $suff = 'chiq_re';
  } elsif (($po->space eq 'q') and ($po->q_pl eq 'i')) {
    $suff = 'chiq_im';
  } elsif (($po->space eq 'q') and ($po->q_pl eq 'p')) {
    $suff = 'chiq_pha';
  };
  return $suff;
};

1;

=head1 NAME

Demeter::Data::Plot - Data plotting methods for Demeter

=head1 VERSION

This documentation refers to Demeter version 0.9.17.

=head1 METHODS

=over 4

=item C<plot>

This method generates a plot of the data using its attributes and the
attributes of the plot object.  Because Demeter keeps track of what
processing chores need to be done, you can be sure that the object
being plotted will always be brought up-to-date with respect to
background removal and Fourier transforms before plotting.

  $dataobject -> plot;
  $pathobject -> plot;

The value of the C<space> attribute of the Plot object is used to
determine the plotting space, but that can be overridden with the
optional argument.  These do the same thing:

  $dataobject -> po -> space('q');
  $dataobject -> plot;
    ## and
  $dataobject -> plot('q');

This method returns a reference to invoking object, so method calls
can be chained:

  $dataobject -> plot -> plot_window;

The C<space> can be any of the following and is case insensitive:

=over 4

=item E

Make the plot in energy.

=item k

Make the plot of chi(k) in wavenumber.

=item k123

Make the plot of chi(k) in wavenumber with k-weightings of 1, 2, and 3
scaled and offset.

=item r

Make the plot of chi(R) in distance.

=item rmr

Make a stacked plot of the magnitude and real part of chi(R).  This is
a particularly nice plot to make after a fit.

=item Rk

Make a multiplot with chi(k) on the top and an Rmr plot on the bottom.
This type of plot should only be made after a fit is performed as the
template B<will> attempt to plot the fit part of the data.  This plot
type benefits by a taller plot window than Gnuplot's default.

=item r123

Make the plot of chi(R) in distance with k-weightings of 1, 2, and 3
scaled and offset.

=item q

Make the plot of chi(q) (back-transformed chi(k)) in wavenumber.

=item kq

Make the plot of chi(k) along with the real part of chi(q) in
wavenumber.

=back

The C<k123>, C<r123>, C<rmr>, and C<kq> plots are good single data set
plot types, while the other forms are more appropriate for multiple
data set plots.

The C<k123>, C<r123>, C<rmr>, and C<kq> plotting options require using
the syntax for which the argument is passed ot the C<plot> method.
That is, you should specify:

  $data -> plot('k123');

=item C<stack>

Make a stacked plot out of the caller and a supplied list of Data,
Path, VPath, or SSPath objects.

  $data -> po -> stackjump(0.3);
  $data -> stack(@list_of_data_and_paths);

The value of the C<space> attribute of the Plot object is used to
determine the plotting space and, unlike the C<plot> method, that
cannot be overridden in the argument list.

This uses the C<stackjump> attribute of the Plot object for the
spacing between traces and it stacks downward.  To stack upward, set
C<stackjump> to a negative value.

If the caller is also in the argument list, it will only be plotted
once.  That is, these do the same thing:

   $a -> stack($b, $c, $d);
    ## and
   $a -> stack($a, $b, $c, $d);

=item C<plot_window>

Plot the Fourier transform window in k or R space.

  $dataobject->plot_window;
  $pathobject->plot_window;

The value of the C<space> attribute of the Plot object is used to
determine the plotting space, but that can be overridden with the
optional argument.  These do the same thing:

  $dataobject -> po -> space('k');
  $dataobject -> plot_window;
    ## and
  $dataobject -> plot_window('k');

=item C<running>

Compute the running R-factor for the fit.  This is running sum of the
misfit in the sapce being plotted.  It is related to, but not the same
as, the R-factor of the fit as it is computed on the fly for the
current plotting conditions and is scaled to plot nicely in the
current plot.

  $dataobject -> running($space);

The array is then stored in the same backend group as the data itself
but with a suffix of C<krun>, C<rrun>, or C<qrun> depending on when
space is being plotted.

In k-space, the running R-factor is the sum of the squares of the
difference between the k-weighted data and fit.  In R- and q-space, it
is the sum in quadrature of the differneces of the real and imaginary
parts.  The scaling is then chosen so that the plot is zero below the
Fourier transform (k or q) of fitting range (R) and is the same height
as the plotted window function above the FT or fitting range.

=item C<plot_marker>

Mark an arbitrary point in the data.

  $data -> plot_marker($part, $x);

or

  $data -> plot_marker($part, \@x);

The C<$part> is the suffix of the array to be marked, for example
"xmu", "der", or "chi".  The second argument can be a point to mark or
a reference to a list of points.


=item C<default_k_weight>

This returns the value of the default k-weight for a Data or Path
object.  A Data object can have up to four k-weights associated with
it: 1, 2, 3, and an arbitrary value.  This method returns the
arbitrary value (if it is defined) or the lowest of the three
remaining values (if they are defined).  If none of the four are
defined, this returns 1.  For a Path object, the associated Data
object is used to determine the return value.  An exception is thrown
using Carp::carp for other objects and 1 is returned.

    $kw = $data_object -> default_k_weight;

=item C<suffix>

A utility method that returns the suffix of the data array that will
be plotted based on the current settings in the Plot object.  This is
used in templates.

=back

=head1 DEPENDENCIES

Demeter's dependencies are in the F<Bundle/DemeterBundle.pm> file.

L<Moose> is the basis of Demeter.  This module is implemented as a
role and used by the L<Demeter::Data> object.  I feel obloged to admit
that I am using Moose roles in the most trivial fashion here.  This is
mostly an organization tool to keep modules small and methods
organized by common functionality.

=head1 BUGS AND LIMITATIONS

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
