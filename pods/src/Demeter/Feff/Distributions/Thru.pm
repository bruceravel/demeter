package Demeter::Feff::Distributions::Thru;
use Moose::Role;
use MooseX::Aliases;

use POSIX qw(acos);
use Demeter::Constants qw($PI);
use Demeter::NumTypes qw( Ipot );

use Chemistry::Elements qw (get_Z get_name get_symbol);
use String::Random qw(random_string);

has 'skip'    => (is => 'rw', isa => 'Int', default => 50,
		  trigger       => sub{ my($self, $new) = @_; $self->update_rdf(1) if $new},);
has 'nconfig' => (is => 'rw', isa => 'Int', default => 0, documentation => "the number of 3-body configurations found at each time step");
has 'rmin'    => (is	        => 'rw',
		  isa	        => 'Num',
		  default       => 0.0,
		  traits => ['MooseX::Aliases::Meta::Trait::Attribute'],
		  alias         => 'r1',
		  trigger       => sub{ my($self, $new) = @_; $self->update_rdf(1) if $new},
		  documentation => "The lower bound of the through-absorber histogram to be extracted from the cluster");
has 'rmax'    => (is 	        => 'rw',
		  isa 	        => 'Num',
		  default       => 5.6,
		  traits => ['MooseX::Aliases::Meta::Trait::Attribute'],
		  alias         => 'r2',
		  trigger       => sub{ my($self, $new) = @_; $self->update_rdf(1) if $new},
		  documentation => "The upper bound of the through-absorber histogram to be extracted from the cluster");

has 'beta'    => (is => 'rw', isa => 'Num', default => 20,
		  trigger       => sub{ my($self, $new) = @_; $self->update_rdf(1) if $new},);
has 'ipot'    => (is => 'rw', isa => Ipot, default => 1,
		  traits => ['MooseX::Aliases::Meta::Trait::Attribute'],
		  alias => 'ipot1',
		  trigger       => sub{ my($self, $new) = @_; $self->update_rdf(1) if $new});
has 'ipot2'   => (is => 'rw', isa => Ipot, default => 1,
		  trigger       => sub{ my($self, $new) = @_; $self->update_rdf(1) if $new},);
has 'nearcl'  => (is => 'rw', isa => 'ArrayRef', default => sub{[]});

has 'rbin'    => (is            => 'rw',
		  isa           => 'Num',
		  default       => 0.02,
		  trigger	=> sub{ my($self, $new) = @_; $self->update_bins(1) if $new},);
has 'betabin' => (is            => 'rw',
		  isa           => 'Num',
		  default       => 0.5,
		  trigger	=> sub{ my($self, $new) = @_; $self->update_bins(1) if $new},);

has 'huge_cluster' => (is => 'rw', isa => 'Bool', default => 0);

sub _bin {
  my ($self) = @_;

  $self->start_spinner(sprintf("Rebinning three-body configurations into %.3f A x %.2f deg bins", $self->rbin, $self->betabin)) if ($self->mo->ui eq 'screen');

  ## slice the configurations in R
  my @slices = ();
  my @this   = ();
  my $r_start = $self->nearcl->[0]->[0];
  my $aa = 0;
  foreach my $tb (@{$self->nearcl}) {
    my $rr = $tb->[0];
    if (($rr - $r_start) > $self->rbin) {
      push @slices, [@this];
      $r_start += $self->rbin;
      $#this=-1;
      push @this, $tb;
    } else {
      push @this, $tb;
    };
    ++$aa;
  };
  push @slices, [@this];
  #print ">>>>>>>>", $#slices+1, $/;

  ## pixelate each slice in angle
  my @plane = ();
  my @pixel = ();
  my $bb = 0;
  foreach my $sl (@slices) {
    my @slice = sort {$a->[4] <=> $b->[4]} @$sl; # sort by angle within this slice in R
    my $beta_start = 0;
    @pixel = ();
    foreach my $tb (@slice) {
      my $beta = $tb->[4];
      if (($beta - $beta_start) > $self->betabin) {
	push @plane, [@pixel];
	$beta_start += $self->betabin;
	@pixel = ();
	push @pixel, $tb;
      } else {
	push @pixel, $tb;
      };
      ++$bb;
    };
    push @plane, [@pixel];
  };
  ##print ">>>>>>>>", $#plane+1, $/;

  ## compute the population and average distance and angle of each pixel
  my @binned_plane = ();
  my ($r, $b, $l1, $l2, $count, $total) = (0, 0, 0, 0, 0, 0);
  my $cc = 0;
  foreach my $pix (@plane) {
    next if ($#{$pix} == -1);
    ($r, $b, $l1, $l2, $count) = (0, 0, 0, 0, 0);
    foreach my $tb (@{$pix}) {
      $r  += $tb->[0];
      $l1 += $tb->[1];
      $l2 += $tb->[3];
      $b  += $tb->[4];
      ++$count;
      ++$total;
    };
    $cc += $count;
    push @binned_plane, [$r/$count, $b/$count, $l1/$count, $l2/$count, $count];
  #  print join("|", $r/$count, $b/$count, $l1/$count, $l2/$count, $count), $/;
  };
  $self->populations(\@binned_plane);
  $self->nbins($#binned_plane+1);
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
  my $r1sqr = $self->rmin**2;
  my $r2sqr = $self->rmax**2;
  my $abs_species  = get_Z($self->feff->abs_species);
  my $scat1_species = get_Z($self->feff->potentials->[$self->ipot1]->[2]);
  my $scat2_species = get_Z($self->feff->potentials->[$self->ipot2]->[2]);

  $self->progress('%30b %c of %m timesteps <Time elapsed: %8t>') if (not $self->huge_cluster);
  $self->progress('%30b %c of %m positions <Time elapsed: %8t>') if $self->huge_cluster;

  $self->start_counter(sprintf("Making radial/angle distribution from every %d-th timestep", $self->skip),
		       ($#{$self->clusters}+1)/$self->skip) if (($self->mo->ui eq 'screen') and (not $self->huge_cluster));
  my ($x0, $x1, $x2, $ip) = (0,0,0,-1);
  my ($ax, $ay, $az) = (0,0,0);
  my ($bx, $by, $bz) = (0,0,0);
  my ($cx, $cy, $cz) = (0,0,0);
  my @rdf   = ();

  my @three = ();
  my @this  = ();
  my $costh;
  my $i2;
  my $halfpath;
  my ($ct, $st, $cp, $sp, $ctp, $stp, $cpp, $spp, $cppp, $sppp, $beta, $leg2);
  my $testx = 15;
  #my $cosbetamax = cos($PI*$self->beta/180);
  foreach my $step (@{$self->clusters}) {
    @rdf = ();

    $self->start_counter("Digging out 1st shell", $#{$step}+1) if (($self->mo->ui eq 'screen') and ($self->huge_cluster));

    @this = @$step;
    $self->timestep_count(++$count) if (not $self->huge_cluster);
    next if (($#{$self->clusters} > $self->skip) and ($count % $self->skip)); # only process every Nth timestep
    if (not $self->huge_cluster) {
      $self->count if ($self->mo->ui eq 'screen');
      $self->call_sentinal;
    };

    ## find the members of the specified coordination shell
    foreach my $i (0 .. $#this) {
      if ($self->huge_cluster) {
	$self->count if ($self->mo->ui eq 'screen');
	$self->call_sentinal;
      };
      ($x0, $x1, $x2, $ip) = @{$this[$i]};
      next if ($abs_species != $ip);
      next if (abs($x2) > $self->zmax); # assumes slab w/ interface at z=0
      #next if (abs($this[$i]->[0]) > $testx); # testing ...
      #next if (abs($this[$i]->[1]) > $testx); #
      foreach my $j (0 .. $#this) {
	next if ($i == $j);
	next if not (($scat1_species == $this[$j]->[3]) or ($scat2_species == $this[$j]->[3]));
	next if (abs($this[$j]->[2]) > $self->zmax); # assumes slab w/ interface at z=0
	#next if (abs($this[$j]->[0]) > $testx); # testing ...
	#next if (abs($this[$j]->[1]) > $testx); #
	my $rsqr = ($x0 - $this[$j]->[0])**2
	         + ($x1 - $this[$j]->[1])**2
	         + ($x2 - $this[$j]->[2])**2; # this loop has been optimized for speed, hence the weird syntax
	push @rdf, [sqrt($rsqr), $i, $j] if (($rsqr > $r1sqr) and ($rsqr < $r2sqr));
      };
    };
    if (($self->mo->ui eq 'screen') and ($self->huge_cluster)) {
      $self->stop_counter;
      $self->progress('%30b %c of %m 1st shell pairs <Time elapsed: %8t>') if $self->huge_cluster;
      $self->start_counter("Finding nearly colinear pairs", $#rdf+1) if ($self->mo->ui eq 'screen');
    };

    ## find those 1st/1st pairs that share an absorber and have a small angle between them
    foreach my $second (@rdf) {
      $self->count if ($self->mo->ui eq 'screen');
      $i2 = $second->[1];
      next if ($this[$second->[2]]->[3] != $scat2_species); # this is not the ipot2 species
      foreach my $first (@rdf) {
	next if ($this[$first->[2]]->[3] != $scat1_species); # this is not the ipot1 species
	next if ($i2 != $first->[1]);          # these don't share absorber
	next if ($second->[2] == $first->[2]); # this is a rattle, not a through

	($ax, $ay, $az) = ($this[ $i2          ]->[0], $this[ $i2          ]->[1], $this[ $i2          ]->[2]);
	#($bx, $by, $bz) = ($this[ $first->[2]  ]->[0], $this[ $first->[2]  ]->[1], $this[ $first->[2]  ]->[2]);
	#($cx, $cy, $cz) = ($this[ $second->[2] ]->[0], $this[ $second->[2] ]->[1], $this[ $second->[2] ]->[2]);

	#my @vector = ( $cx-$ax, $cy-$ay, $cz-$az);
	($ct, $st, $cp, $sp)     = $self->_trig( $this[ $second->[2] ]->[0]-$ax, $this[ $second->[2] ]->[1]-$ay, $this[ $second->[2] ]->[2]-$az );
	#@vector    = ( $ax-$bx, $ay-$by, $az-$bz);
	($ctp, $stp, $cpp, $spp) = $self->_trig( $ax-$this[ $first->[2]  ]->[0], $ay-$this[ $first->[2]  ]->[1], $az-$this[ $first->[2]  ]->[2] );

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
	next if ($beta > $self->beta);

	#$leg2 = sqrt( ($bx - $this[ $second->[2] ]->[0])**2 +
	#	      ($by - $this[ $second->[2] ]->[1])**2 +
	#	      ($bz - $this[ $second->[2] ]->[2])**2 );
	$halfpath = $second->[0] + $first->[0]; # half path of 4-legged path
	push @three, [$halfpath, $first->[0], 0, $second->[0], $beta];
      };
    };
  };
  if ($self->mo->ui eq 'screen') {
    $self->stop_counter;
    $self->start_spinner("Sorting path length/angle distribution by path length");
  };
  @three = sort { $a->[0] <=> $b->[0] } @three;
  $self->stop_spinner if ($self->mo->ui eq 'screen');
  $self->nconfig( $#three+1 );
  #$self->nconfig( int( ($#three+1) / (($#{$self->clusters}+1) / $self->skip) + 0.5 ) );
  # local $|=1;
  # print "||||||| ", $self->nconfig, $/;
  $self->nearcl(\@three);
  $self->update_rdf(0);
};

sub chi {
  my ($self, $paths, $common) = @_;
  $self->start_counter("Making FPath from radial/angle distribution", $#{$self->populations}+1) if ($self->mo->ui eq 'screen');
  #$self->start_spinner("Making FPath from path length/angle distribution") if ($self->mo->ui eq 'screen');

  my @paths = ();
  my $randstr = random_string('ccccccccc').'.sp';
  foreach my $c (@{$self->populations}) {
    push @paths, Demeter::ThreeBody->new(r1    => $c->[2],      r2    => $c->[3],
					 ipot1 => $self->ipot1, ipot2 => $self->ipot2,
					 beta  => $c->[1],      s02   => $c->[4]/$self->nconfig,
					 parent=> $self->feff,
					 update_path => 1,
					 through => 1,
					 randstring => $randstr,
					 @$common);
  };

  my $index = $self->mo->pathindex;

  my $first = $paths[0];
  $first->_update('fft');
  my $save = $first->group;

  $self->count if ($self->mo->ui eq 'screen');
  $first->dspath->Index(255);
  $first->dspath->group("h_i_s_t_o"); # add up the SSPaths without requiring a group for each one
  $first->dspath->path(1);
  $first->dspath->dispense('process', 'histogram_first');
  $first->dspath->group($save);
  $first->dspath->dispense('process', 'histogram_clean', {index=>255});
  my $nnnn = File::Spec->catfile($first->folder, $first->dsstring);
  unlink $nnnn if (-e $nnnn);

  $first->tspath->Index(255);
  $first->tspath->group("h_i_s_t_o");
  $first->tspath->path(1);
  $first->tspath->dispense('process', 'histogram_add');
  $first->tspath->group($save);
  $first->tspath->dispense('process', 'histogram_clean', {index=>255});
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
  my @k    = $self->fetch_array('h___isto.k');
  my @chi  = $self->fetch_array('h___isto.chi');
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
  my $name = sprintf("Histo Through %s-Abs-%s (%.3f)",
		     $self->feff->potentials->[$self->ipot1]->[2],
		     $self->feff->potentials->[$self->ipot2]->[2],
		     $path->reff);
  $path->name($name);
  $path->randstring($randstr);
  $self->stop_counter if ($self->mo->ui eq 'screen');
  return $path;
};

sub describe {
  my ($self, $composite) = @_;
  my $text = sprintf("\n\nthree body configurations through the absorber with both atoms between %.3f and %.3f A\nbinned into %.4f A x %.4f deg bins",
		     $self->get(qw{rmin rmax rbin betabin}));
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
    $self->chart('plot', 'output');
  };
  $self->chart('plot', 'histo2d', {twod=>$twod, bin2d=>$bin2d, type=>'nearly collinear'});
  return $self;
};

sub info {
  my ($self) = @_;
  my $text = sprintf "Made histogram from %s file '%s'\n\n", uc($self->backend), $self->file;
  $text   .= sprintf "Number of time steps:     %d\n",   $self->nsteps;
  $text   .= sprintf "Absorber:                 %s\n",   get_name($self->feff->abs_species);
  $text   .= sprintf "Scatterer #1:             %s\n",   get_name($self->feff->potentials->[$self->ipot1]->[2]);
  $text   .= sprintf "Scatterer #1:             %s\n",   get_name($self->feff->potentials->[$self->ipot2]->[2]);
  $text   .= sprintf "Number of configurations: %d\n",   $self->nconfig;
  $text   .= sprintf "Used periodic boundaries: %s\n",   $self->yesno($self->periodic and $self->use_periodicity);
  $text   .= sprintf "Radial bin size:          %.4f\n", $self->rbin;
  $text   .= sprintf "Angular bin size:         %.4f\n", $self->betabin;
  $text   .= sprintf "Number of bins:           %d\n",   $#{$self->populations}+1;
  return $text;
};

1;

=head1 NAME

Demeter::Feff::Distributions::Thru - Histograms for MS paths through the absorber

=head1 VERSION

This documentation refers to Demeter version 0.9.14.

=head1 SYNOPSIS

=head1 DESCRIPTION

This provides methods for generating two-dimensional histograms in
path length and forward scattering angle for nearly collinear
arrangements of three atoms, like so:

   Scatterer --- Absorber --- Scatterer

Given radial ranges for the near neighbor scatterer and its ipot,
compute a two-dimensional histogram in half-path-length and scattering
angle through the absorber.

=head1 ATTRIBUTES

=over 4

=item C<file> (string)

The path to and name of the HISTORY file.  Setting this will trigger
reading of the file and construction of a histogram using the values
of the other attributes.

=item C<nsteps> (integer)

When the HISTORY file is first read, it will be parsed to obtain the
number of time steps contained in the file.  This number will be
stored in this attribute.

=item C<rmin> and C<rmax> (numbers)

The lower and upper bounds of the radial distribution function to
extract from the cluster.

=item C<rbin> (number)

The width of the histogram bin to be extracted from the RDF.

=item C<betabin> (number)

The forward scattering angular range through the absorber of the
histogram bin to be extracted from the RDF.

=item C<sp> (number)

This is set to the L<Demeter::ScatteringPath> object used to construct
the bins of the histogram.  A good choice would be the similar path
from a Feff calculation on the bulk, crystalline analog to your
cluster.

=back

=head1 METHODS

=over 4

=item C<fpath>

Return a L<Demeter::FPath> object representing the sum of the bins of
the histogram extracted from the cluster.

=item C<plot>

Make a plot of the the RDF.

=back

=head1 CONFIGURATION

See L<Demeter::Config> for a description of the configuration system.
Many attributes of a Data object can be configured via the
configuration system.  See, among others, the C<bkg>, C<fft>, C<bft>,
and C<fit> configuration groups.

=head1 DEPENDENCIES

Demeter's dependencies are in the F<Bundle/DemeterBundle.pm> file.

=head1 SERIALIZATION AND DESERIALIZATION


=head1 BUGS AND LIMITATIONS

=over 4

=item *

This currently only works for a monoatomic cluster.  See rdf in SS.pm
for species checks

=item *

Feff interaction is a bit unclear

=item *

Triangles and nearly colinear paths

=back

Please report problems to Bruce Ravel (bravel AT bnl DOT gov)

Patches are welcome.

=head1 AUTHOR

Bruce Ravel (bravel AT bnl DOT gov)

L<http://cars9.uchicago.edu/~ravel/software/>


=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2013 Bruce Ravel (bravel AT bnl DOT gov). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut

