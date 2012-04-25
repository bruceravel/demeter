package Demeter::Feff::DistributionsP::NCL;
use Moose::Role;
use MooseX::Aliases;

use POSIX qw(acos);
use Demeter::Constants qw($PI);
use Demeter::NumTypes qw( Ipot );

use Chemistry::Elements qw (get_Z get_name get_symbol);
use String::Random qw(random_string);

use PDL::Lite;
use PDL::NiceSlice;

## nearly collinear DS and TS historgram attributes
has 'skip'      => (is => 'rw', isa => 'Int', default => 50,);
has 'nconfig'   => (is => 'rw', isa => 'Int', default => 0, documentation => "the number of 3-body configurations found at each time step");
has 'r1'        => (is => 'rw', isa => 'Num', default => 0.0,
		    trigger	    => sub{ my($self, $new) = @_; $self->update_rdf(1) if $new},);
has 'r2'        => (is => 'rw', isa => 'Num', default => 3.5,
		    trigger	    => sub{ my($self, $new) = @_; $self->update_rdf(1) if $new},);
has 'r3'        => (is => 'rw', isa => 'Num', default => 5.2,
		    trigger	    => sub{ my($self, $new) = @_; $self->update_rdf(1) if $new},);
has 'r4'        => (is => 'rw', isa => 'Num', default => 5.7,
		    trigger	    => sub{ my($self, $new) = @_; $self->update_rdf(1) if $new},);
has 'beta'      => (is => 'rw', isa => 'Num', default => 20,
		    trigger	    => sub{ my($self, $new) = @_; $self->update_rdf(1) if $new},);
has 'rbin'      => (is            => 'rw',
		    isa           => 'Num',
		    default       => 0.02,
		    trigger	  => sub{ my($self, $new) = @_; $self->update_bins(1) if $new},);
has 'betabin'   => (is            => 'rw',
		    isa           => 'Num',
		    default       => 0.5,
		    trigger	  => sub{ my($self, $new) = @_; $self->update_bins(1) if $new},);

has 'ipot'      => (is => 'rw', isa => Ipot, default => 1,
		    traits  => ['MooseX::Aliases::Meta::Trait::Attribute'],
		    alias   => 'ipot1',
		    trigger => sub{ my($self, $new) = @_; $self->update_rdf(1) if $new});
has 'ipot2'     => (is => 'rw', isa => Ipot, default => 1,
		    trigger => sub{ my($self, $new) = @_; $self->update_rdf(1) if $new}, );

has 'nearcl'    => (is => 'rw', isa => 'ArrayRef', default => sub{[]});

has 'huge_cluster' => (is => 'rw', isa => 'Bool', default => 0);

sub _bin {
  my ($self) = @_;

  $self->start_spinner(sprintf("Rebinning three-body configurations into %.3f A x %.2f deg bins", $self->rbin, $self->betabin)) if ($self->mo->ui eq 'screen');

  my $ncl = PDL->new($self->nearcl)->((0),:,:);

  my $halflengths = $ncl->((0),:);
  my $betavalues  = $ncl->((4),:);


  my $minlength = $halflengths->min;
  my $nbinx = 1 + ($halflengths->max - $minlength) / $self->rbin;
  my $nbiny = 1 + $self->beta / $self->betabin;

#  print join("|", $halflengths->min, $halflengths->max, $nbinx, $nbiny), $/;


  my $hist = PDL::Primitive::histogram2d($halflengths, $betavalues,
					 $self->rbin,    $minlength, $nbinx,
					 $self->betabin, 0,          $nbiny);

  my ($nr, $nb) = $hist->dims;

#  print $/, $hist, $/;
  print $/, join("|", $nr, $nb), $/;
  exit;

#  my $halflengths = $self->nearcl->


#  $self->populations(\@binned_plane);
#  $self->nbins($#binned_plane+1);
  $self->update_bins(0);
  $self->stop_spinner if ($self->mo->ui eq 'screen');
  #   local $|=1;
  # printf "number of pixels: unbinned = %d    binned = %d\n", $#plane+1, $#binned_plane+1;
  # printf "stripe pass = %d   pixel pass = %d    last pass = %d\n", $aa, $bb, $cc;
  # printf "binned = %d  unbinned = %d\n", $total, $#{$self->nearcl}+1;
  return $self;

};


sub rdf {
  my ($self) = @_;
  my $count = 0;
  my $r1sqr = $self->r1**2;
  my $r2sqr = $self->r2**2;
  my $r3sqr = $self->r3**2;
  my $r4sqr = $self->r4**2;
  my $abs_species  = get_Z($self->feff->abs_species);
  my $scat1_species = get_Z($self->feff->potentials->[$self->ipot1]->[2]);
  my $scat2_species = get_Z($self->feff->potentials->[$self->ipot2]->[2]);
  my @three = ();

  ## trim the cluster to a slab within ZMAX from the interface (presumed to be at z=0)
  my $select = $self->clusterspdl->(2,:)->flat->abs->lt($self->zmax, 0)->which;
  my $zslab = $self->clusterspdl->(:, $select);
  my ($nd, $np) = $zslab->dims;


  if ($self->mo->ui eq 'screen') {
    $self->progress('%30b %c of %m timesteps <Time elapsed: %8t>') if (not $self->huge_cluster);
    $self->progress('%30b %c of %m positions <Time elapsed: %8t>') if $self->huge_cluster;
  };

  $self->start_counter(sprintf("Making radial/angle distribution from every %d-th timestep", $self->skip),
		       ($#{$self->clusters}+1)/$self->skip) if (($self->mo->ui eq 'screen') and (not $self->huge_cluster));

  my ($i, $n1, $n4, $ind, $centerpdl, $b_select, $scat, $b, $c, $rdf1, $rdf4, $ind1, $d);

  my ($inrange1, $inrange4, $veca1, $vec14);
  my $indeces = PDL::Basic::sequence($np);
  my ($ct, $st, $cp, $sp, $ctp, $stp, $cpp, $spp, $cppp, $sppp, $beta, $leg2, $halfpath);

  $self->start_counter("Digging nearly collinear paths from 1st and 4th shells", $np)
    if (($self->mo->ui eq 'screen') and ($self->huge_cluster));
  foreach $i (0 .. $np-1) {
    if (not $self->count_timesteps) { # progress over positions
      $self->count if ($self->mo->ui eq 'screen');
      $self->timestep_count(++$count);
      $self->call_sentinal;
    };
    next if ($abs_species != $zslab->at(3,$i));


    $centerpdl = $zslab->(:,$i);
    $b_select  = $zslab->(3,:)->flat->eq($scat1_species, 0)->which;
    $scat      = $zslab->(:,$b_select);
    $ind       = $indeces->($b_select);
    $b	       = $scat->minus($centerpdl,0)->(0:2)->power(2,0)->sumover;

    ## find the indeces in $scat of the first and fourth shell scatterers relative to this absorber
    $inrange1  = $b->gt($r1sqr, 0)->and2($b->lt($r2sqr, 0), 0)->which;
    $inrange4  = $b->gt($r3sqr, 0)->and2($b->lt($r4sqr, 0), 0)->which;
    ## the gt/and2/lt idiom finds those in the first or fourth shell range


    foreach $n1 ($inrange1->list) {
      $veca1 = $scat->(:,$n1) -> minus($centerpdl, 0) -> (0:2);
      #print join(", ", $n1, $veca1->list), $/;
      foreach $n4 ($inrange4->list) {
	$vec14 = $scat->(:,$n4) -> minus($scat->(:,$n1), 0) -> (0:2);
	#print "    ", join(", ", $n4, $vec14->list), $/;

	## compute the Eulerian beta angle (following Feff)
	($ct, $st, $cp, $sp)     = $self->_trig( $vec14->list );
	($ctp, $stp, $cpp, $spp) = $self->_trig( $veca1->list );

	$cppp = $cp*$cpp + $sp*$spp;
	$sppp = $spp*$cp - $cpp*$sp;

	$beta = $ct*$ctp + $st*$stp*$cppp;
	if ($beta < -1) {
	  $beta = 180;
	} elsif ($beta >  1) {
	  $beta = 0;
	} else {
	  $beta = 180 * acos($beta)  / $PI;
	};
	#print "        beta = ", $beta, "  ", $self->beta, $/;
	next if ($beta > $self->beta);

	$leg2 = $vec14->power(2,0)->sumover->sqrt->sclr;
	$halfpath = $leg2 + $b->($n1)->sqrt->sclr; # + $fourth->[0]) / 2;
	push @three, [$halfpath, $b->($n1), $leg2, $b->($n4), $beta];
	#print join("|", $halfpath, $b->($n1)->sclr, $leg2, $b->($n4)->sclr, $beta), $/;
      };
    };
  };


  print $/, $#three, $/;


  $self->stop_counter if ($self->mo->ui eq 'screen');
  $self->nconfig( $#three+1 );
  $self->nearcl(\@three);
  $self->update_rdf(0);
  return $self;
};





sub chi {
  my ($self, $paths, $common) = @_;
  $self->start_counter("Making FPath from radial/angle distribution", $#{$self->populations}+1) if ($self->mo->ui eq 'screen');
  #$self->start_spinner("Making FPath from path length/angle distribution") if ($self->mo->ui eq 'screen');

  my $randstr = random_string('ccccccccc').'.sp';
  my @paths = ();
  foreach my $c (@{$self->populations}) {
    push @paths, Demeter::ThreeBody->new(r1    => $c->[2],      r2    => $c->[3],
					 ipot1 => $self->ipot1, ipot2 => $self->ipot2,
					 beta  => $c->[1],      s02   => $c->[4]/$self->nconfig,
					 parent=> $self->feff,
					 update_path => 1,
					 through => 0,
					 randstring => $randstr,
					 @$common);
  };

  my $index = $self->mo->pathindex;

  my $first = $paths[0];
  $first->_update('fft');
  my $save = $first->group;

  $self->count if ($self->mo->ui eq 'screen');
  $first->dspath->Index(255);
  $first->dspath->group("h_i_s_t_o"); # add up the SSPaths without requiring an Ifeffit group for each one
  $first->dspath->path(1);
  $first->dspath->dispose($first->dspath->template('process', 'histogram_first'));
  $first->dspath->group($save);
  $first->dspath->dispose($first->dspath->template('process', 'histogram_clean', {index=>255}));
  my $nnnn = File::Spec->catfile($first->folder, $first->dsstring);
  unlink $nnnn if (-e $nnnn);

  $first->tspath->Index(255);
  $first->tspath->group("h_i_s_t_o");
  $first->tspath->path(1);
  $first->tspath->dispose($first->tspath->template('process', 'histogram_add'));
  $first->tspath->group($save);
  $first->tspath->dispose($first->tspath->template('process', 'histogram_clean', {index=>255}));
  $nnnn = File::Spec->catfile($first->folder, $first->tsstring);
  unlink $nnnn if (-e $nnnn);

  my $ravg = $first->s02 * ($first->r1+$first->r2);
  my $n    = $first->s02;
  foreach my $i (1 .. $#paths) {
    $self->call_sentinal;
    $paths[$i]->_update('fft');
    my $save = $paths[$i]->group;

    $self->count if ($self->mo->ui eq 'screen');
    $paths[$i]->dspath->Index(255);
    $paths[$i]->dspath->group("h_i_s_t_o");
    $paths[$i]->dspath->path(1);
    $paths[$i]->dispose($paths[$i]->dspath->template('process', 'histogram_add'));
    $paths[$i]->dspath->group($save);
    $paths[$i]->dispose($paths[$i]->dspath->template('process', 'histogram_clean', {index=>255}));
    $nnnn = File::Spec->catfile($paths[$i]->dspath->folder, $paths[$i]->dsstring);
    unlink $nnnn if (-e $nnnn);

    $paths[$i]->tspath->Index(255);
    $paths[$i]->tspath->group("h_i_s_t_o");
    $paths[$i]->tspath->path(1);
    $paths[$i]->dispose($paths[$i]->tspath->template('process', 'histogram_add'));
    $paths[$i]->tspath->group($save);
    $paths[$i]->dispose($paths[$i]->tspath->template('process', 'histogram_clean', {index=>255}));
    $nnnn = File::Spec->catfile($paths[$i]->tspath->folder, $paths[$i]->tsstring);
    unlink $nnnn if (-e $nnnn);

    $ravg += $paths[$i]->s02 * ($paths[$i]->r1+$paths[$i]->r2);
    $n += $paths[$i]->s02;
  }
  $self->mo->pathindex($index);
  my @k    = Ifeffit::get_array('h___isto.k');
  my @chi  = Ifeffit::get_array('h___isto.chi');
  my $data = Demeter::Data  -> put(\@k, \@chi, datatype=>'chi', name=>'sum of histogram',
				   fft_kmin=>0, fft_kmax=>20, bft_rmin=>0, bft_rmax=>31);
  my $path = Demeter::FPath -> new(absorber  => $self->feff->abs_species,
				   scatterer => $self->feff->potentials->[$paths[0]->ipot2]->[2],
				   reff      => $ravg,
				   source    => $data,
				   n         => 1,
				   degen     => 1,
				   @$common
				  );
  my $name = sprintf("Histo NCL Abs-%s-%s (%.3f)",
		     $self->feff->potentials->[$self->ipot1]->[2],
		     $self->feff->potentials->[$self->ipot2]->[2],
		     $path->reff);
  $path->name($name);
  $path->randstring($randstr);
  $self->stop_counter if ($self->mo->ui eq 'screen');
  return $path;
}



sub describe {
  my ($self, $composite) = @_;
  my $text = sprintf("\n\nnealry collinear three body configurations with the near atom between %.3f and %.3f A\nthe distant atom between %.3f and %.3f A\nbinned into %.4f A x %.4f deg bins",
		     $self->get(qw{r1 r2 r3 r4 rbin betabin}));
  $composite->pdtext($text);
};

sub plot {
  my ($self) = @_;
  $self->po->start_plot;
  my $twod = $self->po->tempfile;
  open(my $f1, '>', $twod);
  foreach my $p (@{$self->nearcl}) {
    printf $f1 "  %.9f  %.9f  %.9f  %.9f  %.15f\n", @$p;
  };
  close $f1;
  my $bin2d = $self->po->tempfile;
  open(my $f2, '>', $bin2d);
  foreach my $p (@{$self->populations}) {
    printf $f2 "  %.9f  %.9f  %.9f  %.9f  %d\n", @$p;
  };
  close $f2;
  if ($self->po->output) {
    $self->dispose($self->template('plot', 'output'), 'plotting');
  };
  my $text = $self->template('plot', 'histo2d', {twod=>$twod, bin2d=>$bin2d, type=>'nearly collinear'});
  $self->dispose($text, 'plotting');
  return $self;
};


sub info {
  my ($self) = @_;
  my $text = sprintf "Made histogram from %s file '%s'\n\n", uc($self->backend), $self->file;
  $text   .= sprintf "Number of time steps:     %d\n",   $self->nsteps;
  $text   .= sprintf "Absorber:                 %s\n",   get_name($self->feff->abs_species);
  $text   .= sprintf "Scatterer #1:             %s\n",   get_name($self->feff->potentials->[$self->ipot1]->[2]);
  $text   .= sprintf "Scatterer #2:             %s\n",   get_name($self->feff->potentials->[$self->ipot2]->[2]);
  $text   .= sprintf "Number of configurations: %d\n",   $self->nconfig;
  $text   .= sprintf "Used periodic boundaries: %s\n",   $self->yesno($self->periodic and $self->use_periodicity);
  $text   .= sprintf "Radial bin size:          %.4f\n", $self->rbin;
  $text   .= sprintf "Angular bin size:         %.4f\n", $self->betabin;
  $text   .= sprintf "Number of bins:           %d\n",   $#{$self->populations}+1;
  return $text;
};

1;
