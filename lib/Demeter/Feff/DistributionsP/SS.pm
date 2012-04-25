package Demeter::Feff::DistributionsP::SS;
use Moose::Role;
use MooseX::Aliases;

use Demeter::NumTypes qw( NonNeg Ipot );

use Chemistry::Elements qw (get_Z get_name get_symbol);
use List::MoreUtils qw(pairwise);
use String::Random qw(random_string);

use PDL::Lite;
use PDL::NiceSlice;

## SS histogram attributes
has 'rmin'        => (is	    => 'rw',
		      isa	    => 'Num',
		      default	    => 0.0,
		      trigger	    => sub{ my($self, $new) = @_; $self->update_rdf(1) if $new},
		      documentation => "The lower bound of the SS histogram to be extracted from the cluster");
has 'rmax'        => (is	    => 'rw',
		      isa	    => 'Num',
		      default	    => 5.6,
		      trigger	    => sub{ my($self, $new) = @_; $self->update_rdf(1) if $new},
		      documentation => "The upper bound of the SS histogram to be extracted from the cluster");
has 'ipot'        => (is => 'rw', isa => Ipot, default => 1,
		      traits => ['MooseX::Aliases::Meta::Trait::Attribute'],
		      alias => 'ipot1',
		      trigger => sub{my ($self, $new) = @_; $self->update_rdf(1)   if $new});
has 'bin'         => (is            => 'rw',
		      isa           => 'Num',
		      default       => 0.005,
		      trigger => sub{my ($self, $new) = @_; $self->update_bins(1)   if $new},);
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
has 'rattle'      => (is            => 'rw',
		      isa           => 'Bool',
		      default       => 0,
		      trigger       => sub{my ($self, $new) = @_; $self->update_fpath(1)   if $new});






sub _bin {
  my ($self) = @_;
  my (@x, @y);
  die("No MD output file has been read, thus no distribution functions have been computed\n") if ($#{$self->ssrdf} == -1);

  $self->start_spinner(sprintf("Rebinning RDF into %.4f A bins", $self->bin)) if ($self->mo->ui eq 'screen');
  my $rdf = PDL->new($self->ssrdf);
  ## $self->rmin, $self->rmax, $self->bin
  my $numbins = 1 + ($self->rmax - $self->rmin) / $self->bin;
  my ($grid, $hist) = $rdf->hist($self->rmin, $self->rmax, $self->bin);

  $self->positions([$grid->list]);
  $self->populations([$hist->list]);
  $self->update_bins(0);
  $self->stop_spinner if ($self->mo->ui eq 'screen');
  return $self;
};




sub rdf {
  my ($self) = @_;
  $self->computing_rdf(1);
  my @rdf = ();
  my $count = 0;
  my $rmin    = $self->rmin;
  my $rmax    = $self->rmax;
  my $rminsqr = $self->rmin*$self->rmin;
  my $rmaxsqr = $self->rmax*$self->rmax;
  if (($Demeter::mode->ui eq 'screen') and ($self->count_timesteps)) {
    $self->progress('%30b %c of %m timesteps <Time elapsed: %8t>');
    $self->start_counter("Making RDF from each timestep", $#{$self->clusters}+1);
  };

  ## trim the cluster to a slab within ZMAX from the interface (presumed to be at z=0)
  my $select = $self->clusterspdl->(2,:)->flat->abs->lt($self->zmax, 0)->which;
  my $zslab = $self->clusterspdl->(:, $select);
  my ($nd, $np) = $zslab->dims;

  if (($Demeter::mode->ui eq 'screen') and (not $self->count_timesteps)) {
    $self->progress('%30b %c of %m positions <Time elapsed: %8t>');
    $self->start_counter("Making RDF from large cluster", $np);
  };
  my $abs_species  = get_Z($self->feff->abs_species);
  my $scat_species = get_Z($self->feff->potentials->[$self->ipot]->[2]);
  #my (@vec0, @vec1, @vec2);
  #if ($self->periodic) {	# pre-derefencing these vectors speeds up the loop where
  #  @vec0 = @{$self->lattice->[0]}; # the periodic boundary conditions are applied by a
  #  @vec1 = @{$self->lattice->[1]}; # substantial amount
  #  @vec2 = @{$self->lattice->[2]};
  #};

  ## predeclaring these variables svaes about 6% on execution time of the loop
  my ($i, $xx, $yy, $centerpdl, $b_select, $scat, $b, $c, $d);


#  foreach my $step (@{$self->clusters}) {

#    @this = @$step;
#    if ($self->count_timesteps) { # progress over timesteps
#      $self->count if ($self->mo->ui eq 'screen');
#      $self->timestep_count(++$count);
#      $self->call_sentinal;
#    };



    foreach $i (0 .. $np-1) {
      if (not $self->count_timesteps) { # progress over positions
	$self->count if ($self->mo->ui eq 'screen');
	$self->timestep_count(++$count);
	$self->call_sentinal;
      };
      next if ($abs_species != $zslab->at(3,$i));


      $centerpdl = $zslab->(:,$i);
      $b_select = $zslab->(3,:)->flat->eq($scat_species, 0)->which;

      $scat = $zslab->(:,$b_select);


      $b = $scat->minus($centerpdl,0)->(0:2)->power(2,0)->sumover;
      $c = $b->where($b>$rminsqr);
      $d = $c->where($c<$rmaxsqr);
      push @rdf, $d->sqrt->list;
  };


  $self->stop_counter if ($self->mo->ui eq 'screen');
  $self->ssrdf(\@rdf);
  $self->npairs(($#rdf+1)/$self->nsteps);
  $self->name(sprintf("%s-%s SS histogram", get_symbol($self->feff->abs_species), get_symbol($self->feff->potentials->[$self->ipot]->[2])));

  $self->computing_rdf(0);
  $self->update_rdf(0);
  return $self;
};


sub chi {
  my ($self) = @_;

  ##                              ($self, $rx,              $ry,                $ipot,       $s02, $scale, $common) = @_;
  my $paths = $self->feff->make_histogram($self->positions, $self->populations, $self->ipot, q{}, q{}, [rattle=>$self->rattle]);
  $self->nbins($#{$paths}+1);
  my $kind = ($self->rattle) ? "rattle" : "SS";
  $self->start_spinner("Making FPath from $kind histogram") if ($self->mo->ui eq 'screen');

  my $randstr = random_string('ccccccccc').'.sp';
  my $index = $self->mo->pathindex;
  my $first = $paths->[0];
  #$first->update_path(1);
  my $save = $first->group;
  $first->Index(255);
  $first->group("h_i_s_t_o");
  $first->randstring($randstr);
  $first->_update('fft');
  $first->dispose($first->template('process', 'histogram_first'));
  $first->group($save);
  $first->dispose($first->template('process', 'histogram_clean', {index=>255}));
  my $nnnn = File::Spec->catfile($first->folder, $first->randstring);
  unlink $nnnn if (-e $nnnn);
  my $rbar  = $first->population * $first->R;
  my $rave  = $first->population / $first->R;
  my $rnorm = $first->population / ($first->R**2);
  my $sum   = $first->population;
  my @pop   = ($first->population);
  my @r     = ($first->R);
  $self->fpath_count(0);
  foreach my $i (1 .. $#{ $paths }) {
    #$paths->[$i]->update_path(1);
    $self->fpath_count($i);
    $self->call_sentinal;
    my $save = $paths->[$i]->group; # add up the SSPaths without requiring an Ifeffit group for each one
    $paths->[$i]->Index(255);
    $paths->[$i]->group("h_i_s_t_o");
    $paths->[$i]->randstring($randstr);
    $paths->[$i]->_update('fft');
    $paths->[$i]->dispose($paths->[$i]->template('process', 'histogram_add'));
    $paths->[$i]->group($save);
    $paths->[$i]->dispose($paths->[$i]->template('process', 'histogram_clean', {index=>255}));
    $nnnn = File::Spec->catfile($paths->[$i]->folder, $paths->[$i]->randstring);
    unlink $nnnn if (-e $nnnn);
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
  $path->randstring($randstr);
  my $name = sprintf("Histo %s %s-%s (%.5f)", $kind, $path->absorber, $path->scatterer, $rave);
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
  if ($self->po->output) {
    $self->dispose($self->template('plot', 'output'), 'plotting');
  };
  $self->dispose($self->template('plot', 'histo'), 'plotting');
  return $self;
};

sub info {
  my ($self) = @_;
  my $text = sprintf "Made histogram from %s file '%s'\n\n", uc($self->backend), $self->file;
  $text   .= sprintf "Number of time steps:     %d\n",   $self->nsteps;
  $text   .= sprintf "Absorber:                 %s\n",   get_name($self->feff->abs_species);
  $text   .= sprintf "Scatterer:                %s\n",   get_name($self->feff->potentials->[$self->ipot]->[2]);
  $text   .= sprintf "Pairs in RDF:             %d\n",   $#{$self->ssrdf}+1;
  $text   .= sprintf "Pairs per timestep:       %d\n",   $self->npairs;
  $text   .= sprintf "Used periodic boundaries: %s\n",   $self->yesno($self->periodic and $self->use_periodicity);
  $text   .= sprintf "Bin size:                 %.4f\n", $self->bin;
  $text   .= sprintf "Number of bins:           %d\n",   $#{$self->positions}+1;
  return $text;
};



1;

