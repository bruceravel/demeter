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

  my $select = $hist->which;


  $self->positions([$grid->($select)->list]);
  $self->populations([$hist->($select)->list]);
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

  ## 4 (x,y,z,ipot) x positions x timesteps
  ## backends without the time sequence do not have the third dimension
  $self->npositions($self->clusterspdl->getdim(1));
  $self->ntimesteps(1);
  $self->ntimesteps($self->clusterspdl->getdim(2)) if ($self->clusterspdl->ndims != 2);

  my $abs_species  = get_Z($self->feff->abs_species);
  my $scat_species = get_Z($self->feff->potentials->[$self->ipot]->[2]);


  ### VASP (others?) requires this
  #my (@vec0, @vec1, @vec2);
  #if ($self->periodic) {	# pre-derefencing these vectors speeds up the loop where
  #  @vec0 = @{$self->lattice->[0]}; # the periodic boundary conditions are applied by a
  #  @vec1 = @{$self->lattice->[1]}; # substantial amount
  #  @vec2 = @{$self->lattice->[2]};
  #};

  ## predeclaring these variables saves about 6% on execution time of the loop
  my ($i, $xx, $yy, $centerpdl, $b_select, $scat, $b, $c, $d);
  my ($clus, $nd, $np);

  foreach my $istep (0 .. $self->ntimesteps-1) {

    if (not $self->count_timesteps) {
      ## trim the cluster to a slab within ZMAX from the interface (presumed to be at z=0)
      ## the assumption here is that a single time step calculation is a huge slab
      ## here we are restricting that slab to withi some amount of an interface
      my $select = $self->clusterspdl->(2,:)->flat->abs->lt($self->zmax, 0)->which;
      $clus   = $self->clusterspdl->(:, $select);
      ($nd, $np) = $clus->dims;
      $self->npositions($np);

      if ($Demeter::mode->ui eq 'screen') {
	$self->progress('%30b %c of %m positions <Time elapsed: %8t>');
	$self->start_counter("Making RDF from large cluster", $np);
      };

    } else {			# otherwise extract this timestep
      $clus = $self->clusterspdl->(:,:,($istep));
      ($nd, $np) = $clus->dims;
      $self->npositions($np);

      $self->count if ($self->mo->ui eq 'screen');
      $self->timestep_count(++$count);
      $self->call_sentinal;
    };

    ## now $clus contains a portion of the MD simulation
    foreach $i (0 .. $np-1) {
      if (not $self->count_timesteps) { # progress over positions
	$self->count if ($self->mo->ui eq 'screen');
	$self->timestep_count(++$count);
	$self->call_sentinal;
      };

      ## the current absorber
      next if ($abs_species != $clus->at(3,$i));
      $centerpdl = $clus->(:,$i);

      ## find those members of $clus that represent the scattering species
      $b_select = $clus->(3,:)->flat->eq($scat_species, 0)->which;
      $scat = $clus->(:,$b_select);

      ## distances between absorber and all scatterers within $clus
      $b = $scat->minus($centerpdl,0)->(0:2)->power(2,0)->sumover;
      $c = $b->where($b>$rminsqr);
      $d = $c->where($c<$rmaxsqr);

      ## save those within range
      push @rdf, $d->sqrt->list;
    }; # end of this time step
  }; # end of loop over timesteps

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
  $first->dispense('process', 'histogram_first');
  $first->group($save);
  $first->dispense('process', 'histogram_clean', {index=>255});
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
  my @k    = $self->fetch_array('h___isto.k');
  my @chi  = $self->fetch_array('h___isto.chi');
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
  $self->place_array(join(".", $self->group, 'x'), $self->positions);
  $self->place_array(join(".", $self->group, 'y'), $self->populations);
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


=head1 NAME

Demeter::Feff::DistributionsP::SS - Histograms for single scattering paths

=head1 VERSION

This documentation refers to Demeter version 0.9.10.

=head1 SYNOPSIS

Construct a single scattering histogram.  This version of this module
uses PDL.

=head1 DESCRIPTION

This provides methods for generating histograms in path length for
single scattering paths.  It also provides a way to compute the triple
scattering contribution of the sort:

  Abs ---> Scat. ---> Abs ---> Scat. ---> Abs

This is the path that rattles between the absorber and a neighbor.  In
general, this is only observable for the nearest neighbor.

Given a radial ranges for the scattering shell, this will dig through
a configurational distribution and construct a histogram to describe
the radial istribution function of that scattering atom.  It then
makes a L<Demeter::SSPath> at each histogram bin, then sums them into
a L<Demeter::FPath> to make a single path-like object describing the
single scattering (or rattle) contribution from that histogram.

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
extract from the cluster.  These are set to values that include a
single coordination shell when constructing input for an EXAFS fit.
However, for constructing a plot of the RDF, it may be helpful to set
these to cover a larger range of distances.

=item C<bin> (number)

The width of the histogram bin to be extracted from the RDF.

=item C<sp> (number)

This is set to the L<Demeter::ScatteringPath> object used to construct
the bins of the histogram.  A good choice would be the similar path
from a Feff calculation on the bulk, crystalline analog to your
cluster.

=item C<rattle> (boolean)

If true, the rattle contribution will be computed.  If false, the
single scattering contribution will be computed.

=back

=head1 METHODS

=over 4

=item C<fpath>

Return a L<Demeter::FPath> object representing the sum of the bins of
the histogram extracted from the cluster.

=item C<plot>

Make a plot of the the RDF histogram.

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

This currently only works for a monoatomic cluster.

=back

Please report problems to Bruce Ravel (bravel AT bnl DOT gov)

Patches are welcome.

=head1 AUTHOR

Bruce Ravel (bravel AT bnl DOT gov)

L<http://cars9.uchicago.edu/~ravel/software/>


=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2012 Bruce Ravel (bravel AT bnl DOT gov). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
