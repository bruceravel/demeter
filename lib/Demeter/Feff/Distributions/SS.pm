package Demeter::Feff::Distributions::SS;
use Moose::Role;

use Demeter::NumTypes qw( NonNeg );

## SS histogram attributes
has 'rmin'        => (is	    => 'rw',
		      isa	    => 'Num',
		      default	    => 0.0,
		      trigger	    => sub{ my($self, $new) = @_; $self->update_bins(1) if $new},
		      documentation => "The lower bound of the SS histogram to be extracted from the cluster");
has 'rmax'        => (is	    => 'rw',
		      isa	    => 'Num',
		      default	    => 5.6,
		      trigger	    => sub{ my($self, $new) = @_; $self->update_bins(1) if $new},
		      documentation => "The upper bound of the SS histogram to be extracted from the cluster");
has 'bin'         => (is            => 'rw',
		      isa           => 'Num',
		      default       => 0.005,);
has 'ssrdf'       => (is	    => 'rw',
		      isa	    => 'ArrayRef',
		      default	    => sub{[]},
		      documentation => "unbinned distribution extracted from the cluster");
has 'positions'   => (is            => 'rw',
		      isa           => 'ArrayRef',
		      default       => sub{[]},
		      documentation => "array of bin positions of the extracted histogram");
has 'npairs'      => (is            => 'rw',
		      isa           => NonNeg,
		      default       => 0);

sub _bin {
  my ($self) = @_;
  my (@x, @y);
  die("No history file has been read, thus no distribution functions have been computed\n") if ($#{$self->ssrdf} == -1);
  my $bin_start = sqrt($self->ssrdf->[0]);
  my ($population, $average) = (0,0);
  $self->start_spinner(sprintf("Rebinning RDF into %.4f A bins", $self->bin)) if ($self->mo->ui eq 'screen');
  foreach my $pair (@{$self->ssrdf}) {
    my $rr = sqrt($pair);
    if (($rr - $bin_start) > $self->bin) {
      $average = $average/$population;
      push @x, sprintf("%.5f", $average);
      push @y, $population*2;
      #print join(" ", sprintf("%.5f", $average), $population*2), $/;
      $bin_start += $self->bin;
      $average = $rr;
      $population = 1;
    } else {
      $average += $rr;
      ++$population;
    };
  };
  push @x, sprintf("%.5f", $average);
  push @y, $population*2;
  $self->positions(\@x);
  $self->populations(\@y);
  $self->update_bins(0);
  $self->stop_spinner if ($self->mo->ui eq 'screen');
  return $self;
};


sub rdf {
  my ($self) = @_;
  my @rdf = ();
  my $count = 0;
  my $rminsqr = $self->rmin*$self->rmin;
  my $rmaxsqr = $self->rmax*$self->rmax;
  $self->start_counter("Making RDF from each timestep", $#{$self->clusters}+1) if ($self->mo->ui eq 'screen');
  my ($x0, $x1, $x2) = (0,0,0);
  my @this;
  foreach my $step (@{$self->clusters}) {
    @this = @$step;
    $self->count if ($self->mo->ui eq 'screen');
    $self->timestep_count(++$count);
    $self->call_sentinal;
    foreach my $i (0 .. $#this) {
      ($x0, $x1, $x2) = @{$this[$i]};
      foreach my $j ($i+1 .. $#this) { # remember that all pairs are doubly degenerate
	my $rsqr = ($x0 - $this[$j]->[0])**2
	         + ($x1 - $this[$j]->[1])**2
	         + ($x2 - $this[$j]->[2])**2; # this loop has been optimized for speed, hence the weird syntax
	push @rdf, $rsqr if (($rsqr > $rminsqr) and ($rsqr < $rmaxsqr));
	#if (($i==1) and ($j==2)) {
	#  print join("|", @{$this[$i]}, @{$this[$j]}, $rsqr), $/;
	#};
      };
    };
  };
  if ($self->mo->ui eq 'screen') {
    $self->stop_counter;
    $self->start_spinner("Sorting RDF");
  };
  @rdf = sort { $a <=> $b } @rdf;
  $self->stop_spinner if ($self->mo->ui eq 'screen');
  $self->ssrdf(\@rdf);
  $self->npairs(($#rdf+1)/$self->nsteps);
  return $self;
};


sub chi {
  my ($self) = @_;

  my $paths = $self -> feff -> make_histogram($self->positions, $self->populations, $self->ipot, q{}, q{});
  $self->nbins($#{$paths}+1);
  $self->start_spinner("Making FPath from histogram") if ($self->mo->ui eq 'screen');


  my $index = $self->mo->pathindex;
  my $first = $paths->[0];
  #$first->update_path(1);
  my $save = $first->group;
  $first->Index(255);
  $first->group("h_i_s_t_o");
  $first->_update('fft');
  $first->dispose($first->template('process', 'histogram_first'));
  $first->group($save);
  my $rbar  = $first->population * $first->R;
  my $rave  = $first->population / $first->R;
  my $rnorm = $first->population / ($first->R**2);
  my $sum   = $first->population;
  my @pop   = ($first->population);
  my @r     = ($first->R);
  foreach my $i (1 .. $#{ $paths }) {
    #$paths->[$i]->update_path(1);
    $self->call_sentinal;
    my $save = $paths->[$i]->group; # add up the SSPaths without requiring an Ifeffit group for each one
    $paths->[$i]->Index(255);
    $paths->[$i]->group("h_i_s_t_o");
    $paths->[$i]->_update('fft');
    $paths->[$i]->dispose($paths->[$i]->template('process', 'histogram_add'));
    $paths->[$i]->group($save);
    $paths->[$i]->dispose($paths->[$i]->template('process', 'histogram_clean', {index=>255}));
    $rbar  += $paths->[$i]->population * $paths->[$i]->R;
    $rave  += $paths->[$i]->population / $paths->[$i]->R;
    $rnorm += $paths->[$i]->population / ($paths->[$i]->R**2);
    $sum   += $paths->[$i]->population;
    push @pop, $paths->[$i]->population;
    push @r,   $paths->[$i]->R;
  }
  $rbar   /= $sum;
  $rave   /= $rnorm;
  my @dev;
  #my $rdiff = 0;
  foreach my $rr (@r) {
    push @dev, $rr-$rave;
    #$rdiff += abs($rr-$rave) / $rr**2;
  };
  #$rdiff /= $rnorm;
  my ($sigsqr, $third, $fourth) = (0,0,0);
  foreach my $i (0 .. $#r) {
    $sigsqr += $pop[$i] * $dev[$i]**2 / $r[$i]**2;
    $third  += $pop[$i] * $dev[$i]**3 / $r[$i]**2;
    $fourth += $pop[$i] * $dev[$i]**4 / $r[$i]**2;
  };
  $sigsqr /= $rnorm;
  $third  /= $rnorm;
  $fourth /= $rnorm;
  $fourth -= 3*$sigsqr**2;

  $self->mo->pathindex($index);
  my @k    = Ifeffit::get_array('h___isto.k');
  my @chi  = Ifeffit::get_array('h___isto.chi');
  my $data = Demeter::Data  -> put(\@k, \@chi, datatype=>'chi', name=>'sum of histogram',
				   fft_kmin=>0, fft_kmax=>20, bft_rmin=>0, bft_rmax=>31);
  my $path = Demeter::FPath -> new(absorber  => $self->feff->abs_species,
				   scatterer => $self->feff->potentials->[$first->ipot]->[2],
				   reff      => $rave,
				   source    => $data,
				   n         => 1,
				   degen     => 1,
				   c1        => $rave,
				   c2        => $sigsqr,
				   c3        => $third,
				   c4        => $fourth,
				   #@$common
				  );
  my $name = sprintf("Histo SS %s-%s (%.5f)", $path->absorber, $path->scatterer, $rave);
  $path->name($name);
  $self->stop_spinner if ($self->mo->ui eq 'screen');
  return $path;
};

sub describe {
  my ($self, $composite) = @_;
  my $text = sprintf("\n\ntaken from %d samples between %.3f and %.3f A\nbinned into %.4f A bins",
		     $self->get(qw{npairs rmin rmax bin}));
  $text .= "\n\nThe structural contributions to the first four cumulants are \n";
  $text .= sprintf "       first  = %9.6f\n",   $composite->c1;
  $text .= sprintf "       sigsqr = %9.6f\n",   $composite->c2;
  $text .= sprintf "       third  = %9.6f\n",   $composite->c3;
  $text .= sprintf "       fourth = %9.6f",     $composite->c4;
  $composite->pdtext($text);
};


sub plot {
  my ($self) = @_;
  Ifeffit::put_array(join(".", $self->group, 'x'), $self->positions);
  Ifeffit::put_array(join(".", $self->group, 'y'), $self->populations);
  $self->po->start_plot;
  $self->dispose($self->template('plot', 'histo'), 'plotting');
  return $self;
};


1;
