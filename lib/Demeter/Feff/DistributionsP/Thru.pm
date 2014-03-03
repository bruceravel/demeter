package Demeter::Feff::DistributionsP::Thru;
use Moose::Role;
use MooseX::Aliases;

use POSIX qw(acos);
use Demeter::Constants qw($PI);
use Demeter::NumTypes qw( Ipot );

use Chemistry::Elements qw (get_Z get_name get_symbol);

use PDL::Lite;
use PDL::NiceSlice;

#has 'skip'    => (is => 'rw', isa => 'Int', default => 50,
#		  trigger       => sub{ my($self, $new) = @_; $self->update_rdf(1) if $new},);
has 'nconfig' => (is => 'rw', isa => 'Int', default => 0, documentation => "the number of 3-body configurations found at each time step");
has 'rmin'    => (is	        => 'rw',
		  isa	        => 'LaxNum',
		  default       => 0.0,
		  traits => ['MooseX::Aliases::Meta::Trait::Attribute'],
		  alias         => 'r1',
		  trigger       => sub{ my($self, $new) = @_; $self->update_rdf(1) if $new},
		  documentation => "The lower bound of the through-absorber histogram to be extracted from the cluster");
has 'rmax'    => (is 	        => 'rw',
		  isa 	        => 'LaxNum',
		  default       => 5.6,
		  traits => ['MooseX::Aliases::Meta::Trait::Attribute'],
		  alias         => 'r2',
		  trigger       => sub{ my($self, $new) = @_; $self->update_rdf(1) if $new},
		  documentation => "The upper bound of the through-absorber histogram to be extracted from the cluster");

has 'beta'    => (is => 'rw', isa => 'LaxNum', default => 20,
		  trigger       => sub{ my($self, $new) = @_; $self->update_rdf(1) if $new},);
has 'ipot'    => (is => 'rw', isa => Ipot, default => 1,
		  traits => ['MooseX::Aliases::Meta::Trait::Attribute'],
		  alias => 'ipot1',
		  trigger       => sub{ my($self, $new) = @_; $self->update_rdf(1) if $new});
has 'ipot2'   => (is => 'rw', isa => Ipot, default => 1,
		  trigger       => sub{ my($self, $new) = @_; $self->update_rdf(1) if $new},);
has 'nearcl'  => (is => 'rw', isa => 'ArrayRef', default => sub{[]});

has 'rbin'    => (is            => 'rw',
		  isa           => 'LaxNum',
		  default       => 0.02,
		  trigger	=> sub{ my($self, $new) = @_; $self->update_bins(1) if $new},);
has 'betabin' => (is            => 'rw',
		  isa           => 'LaxNum',
		  default       => 0.5,
		  trigger	=> sub{ my($self, $new) = @_; $self->update_bins(1) if $new},);

has 'huge_cluster' => (is => 'rw', isa => 'Bool', default => 0);



sub _bin {
  my ($self) = @_;

  $self->start_spinner(sprintf("Rebinning three-body configurations into %.3f A x %.2f deg bins", $self->rbin, $self->betabin)) if ($self->mo->ui eq 'screen');

  my $ncl = PDL->new($self->nearcl); #->((0),:,:);

  my $halflengths = $ncl->((0),:);
  my $betavalues  = $ncl->((4),:);


  my $minlength = $halflengths->min;
  my $nbinx = 1 + ($halflengths->max - $minlength) / $self->rbin;
  my $nbiny = 1 + $self->beta / $self->betabin;

  my $hist = PDL::Primitive::histogram2d($halflengths, $betavalues,
					 $self->rbin,    $minlength, $nbinx,
					 $self->betabin, 0,          $nbiny);

  my $count = $hist->flat->sumover;
  my ($r, $beta, $l1, $l2) = (0,0,0,0);
  my @binned_plane = ();
  my ($nr, $nb) = $hist->dims;
  #print $/, $hist, $/;
  #print $/, join("|", $nr, $nb), $/;
  foreach my $angle (0 .. $nb-1) { # angle axis
    $beta = 0.5 + $angle*$self->betabin;
    foreach my $halflen (0 .. $nr-1) { # half length axis

      $r = sprintf("%.5f", $minlength + (0.5+$halflen)*$self->rbin);
      next if $hist->at($halflen, $angle) == 0;
      #print join("|", $r, $beta, $l1, $l2, $hist->at($halflen, $angle)), $/;
      push @binned_plane, [$r, $beta, $l1, $l2, $hist->at($halflen, $angle)];
    };
  };


  $self->populations(\@binned_plane);
  $self->nbins($#binned_plane+1);
  $self->update_bins(0);
  $self->stop_spinner if ($self->mo->ui eq 'screen');
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
  $self->computing_rdf(1);
  my @three = ();


  ## 4 (x,y,z,ipot) x positions x timesteps
  ## backends without the time sequence do not have the third dimension
  $self->npositions($self->clusterspdl->getdim(1));
  $self->ntimesteps(1);
  $self->ntimesteps($self->clusterspdl->getdim(2)) if ($self->clusterspdl->ndims != 2);


  ## periodic boundary conditions...?

  ## start timestep counter
  if (($Demeter::mode->ui eq 'screen') and ($self->count_timesteps)) {
    $self->progress('%30b %c of %m timesteps <Time elapsed: %8t>');
    $self->start_counter(sprintf("Making radial/angle distribution from every %d-th timestep", $self->skip),
			 ($#{$self->clusters}+1)/$self->skip);
  };



  my ($i, $n1, $n2, $centerpdl, $b_select, $scat, $b, $c);
  my ($inrange1, $inrange2, $vec1a, $veca2);
  my ($ct, $st, $cp, $sp, $ctp, $stp, $cpp, $spp, $cppp, $sppp, $beta, $leg2, $halfpath);
  my ($clus, $nd, $np);

  foreach my $istep (0 .. $self->ntimesteps-1) {

    if (not $self->count_timesteps) {
      ## trim the cluster to a slab within ZMAX from the interface (presumed to be at z=0)
      ## the assumption here is that a single time step calculation is a huge slab
      ## here we are restricting that slab to withi some amount of an interface
      my $select = $self->clusterspdl->(2,:)->flat->abs->lt($self->zmax, 0)->which;
      $clus = $self->clusterspdl->(:, $select);
      ($nd, $np) = $clus->dims;
      $self->npositions($np);

      if ($self->mo->ui eq 'screen') {
	$self->progress('%30b %c of %m positions <Time elapsed: %8t>');
	$self->start_counter("Digging nearly collinear paths from 1st and 4th shells", $np);
      };

    } else {			# otherwise extract this timestep
      ++$count;
      next if (($#{$self->clusters} > $self->skip) and ($count % $self->skip)); # only process every Nth timestep
      $clus = $self->clusterspdl->(:,:,($istep));
      ($nd, $np) = $clus->dims;
      $self->npositions($np);

      $self->count if ($self->mo->ui eq 'screen');
      $self->timestep_count($count);
      $self->call_sentinal;
    };




    foreach $i (0 .. $np-1) {
      if (not $self->count_timesteps) { # progress over positions
	$self->count if ($self->mo->ui eq 'screen');
	$self->timestep_count(++$count);
	$self->call_sentinal;
      };
      next if ($abs_species != $clus->at(3,$i));


      $centerpdl = $clus->(:,$i);
      $b_select  = $clus->(3,:)->flat->eq($scat1_species, 0) -> or2($clus->(3,:)->flat->eq($scat2_species, 0), 0) ->which;
      $scat      = $clus->(:,$b_select);
      $b	 = $scat->minus($centerpdl,0)->(0:2)->power(2,0)->sumover;

      ## find the indeces in $scat of the first and fourth shell scatterers relative to this absorber
      $inrange1  = $b->gt($r1sqr, 0)->and2($b->lt($r2sqr, 0), 0) ->and2($scat->(3,:)->flat->eq($scat1_species, 0), 0) ->which;
      $inrange2  = $b->gt($r1sqr, 0)->and2($b->lt($r2sqr, 0), 0) ->and2($scat->(3,:)->flat->eq($scat2_species, 0), 0) ->which;
      ## the gt/and2/lt idiom finds those in the first or fourth shell range
      ## the second and2 selects those of the correct atoms type
      ## finally, `which' returns the indeces in $scat that meet all those criteria


      foreach $n1 ($inrange1->list) {
	$vec1a = $centerpdl -> minus($scat->(:,$n1), 0) -> (0:2); # vector from near shell scatterer to absorber
	foreach $n2 ($inrange2->list) {
	  $veca2 = $scat->(:,$n2) -> minus($centerpdl, 0) -> (0:2); # vector from absorber to other scatterer

	  ## compute the Eulerian beta angle between them (following Feff)
	  ($ct, $st, $cp, $sp)     = $self->_trig( $vec1a->list );
	  ($ctp, $stp, $cpp, $spp) = $self->_trig( $veca2->list );

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

	  $leg2 = $veca2->power(2,0)->sumover->sqrt->sclr;
	  $halfpath = $leg2 + $b->($n1)->sqrt->sclr; # + $fourth->[0]) / 2;
	  push @three, [$halfpath, $b->($n1)->sqrt->sclr, 0, $b->($n2)->sqrt->sclr, $beta];
	  #print join("|", $halfpath, $b->($n1)->sqrt->sclr, 0, $b->($n2)->sqrt->sclr, $beta), $/;
	};
      };
    };
  };

  $self->stop_counter if ($self->mo->ui eq 'screen');
  $self->nconfig( $#three+1 );
  $self->nearcl(\@three);
  $self->computing_rdf(0);
  $self->update_rdf(0);
  return $self;
};


sub chi {
  my ($self, $paths, $common) = @_;
  $self->start_counter("Making FPath from radial/angle distribution", $#{$self->populations}+1) if ($self->mo->ui eq 'screen');
  #$self->start_spinner("Making FPath from path length/angle distribution") if ($self->mo->ui eq 'screen');

  my @paths = ();
  my $randstr = Demeter->randomstring(8).'.sp';
  #my $total = 0;
  foreach my $c (@{$self->populations}) {
    ## we are going to assume that this shallow triangle is isosceles,
    ## so compute r1 and r2 from the supplied half path length and
    ## beta (ignoring items 2 and 3 in these lists)
    push @paths, Demeter::ThreeBody->new(r1    => $c->[0]/2,    r2    => $c->[0]/2,
					 ipot1 => $self->ipot1, ipot2 => $self->ipot2,
					 beta  => $c->[1],      s02   => $c->[4]/$self->nconfig,
					 parent=> $self->feff,
					 update_path => 1,
					 through => 1,
					 randstring => $randstr,
					 @$common);
    #$total += $c->[4]/$self->nconfig;
  };
  #print $/, $/, $total, $/, $/;

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
  $self->fpath_count(0);
  foreach my $i (1 .. $#paths) {
    $self->fpath_count($i);
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
				   Type      => 'through-absorber histogram',
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
}

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
  $text   .= sprintf "Scatterer #2:             %s\n",   get_name($self->feff->potentials->[$self->ipot2]->[2]);
  $text   .= sprintf "Number of configurations: %d\n",   $self->nconfig;
  $text   .= sprintf "Used periodic boundaries: %s\n",   $self->yesno($self->periodic and $self->use_periodicity);
  $text   .= sprintf "Radial bin size:          %.4f\n", $self->rbin;
  $text   .= sprintf "Angular bin size:         %.4f\n", $self->betabin;
  $text   .= sprintf "Number of bins:           %d\n",   $#{$self->populations}+1;
  return $text;
};

1;

=head1 NAME

Demeter::Feff::DistributionsP::Thru - Histograms for MS paths through the absorber

=head1 VERSION

This documentation refers to Demeter version 0.9.20.

=head1 SYNOPSIS

Construct a multiple scattering histogram for nearly collinear paths
through the absorber.  This version of this module uses PDL.

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

Demeter's dependencies are in the F<Build.PL> file.

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

Please report problems to the Ifeffit Mailing List
(L<http://cars9.uchicago.edu/mailman/listinfo/ifeffit/>)

Patches are welcome.

=head1 AUTHOR

Bruce Ravel (bravel AT bnl DOT gov)

L<http://bruceravel.github.io/demeter/>


=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2014 Bruce Ravel (bravel AT bnl DOT gov). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut


