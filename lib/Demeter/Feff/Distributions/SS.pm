package Demeter::Feff::Distributions::SS;
use Moose::Role;
use MooseX::Aliases;

use Demeter::NumTypes qw( NonNeg Ipot );

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
has 'ipot'        => (is => 'rw', isa => Ipot, default => 1,
		      traits => ['MooseX::Aliases::Meta::Trait::Attribute'],
		      alias => 'ipot1');
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
has 'rattle'      => (is            => 'rw',
		      isa           => 'Bool',
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
  $average = $average/$population;
  push @x, sprintf("%.5f", $average);
  push @y, $population*2;
  # use Data::Dumper;
  # print Data::Dumper->Dump([\@x, \@y], [qw(*x *y)]);
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
	push @rdf, $rsqr if (($rsqr >= $rminsqr) and ($rsqr <= $rmaxsqr));
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

  ##                              ($self, $rx,              $ry,                $ipot,       $s02, $scale, $common) = @_;
  my $paths = $self->feff->make_histogram($self->positions, $self->populations, $self->ipot, q{}, q{}, [rattle=>$self->rattle]);
  $self->nbins($#{$paths}+1);
  my $kind = ($self->rattle) ? "rattle" : "SS";
  $self->start_spinner("Making FPath from $kind histogram") if ($self->mo->ui eq 'screen');


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


=head1 NAME

Demeter::Feff::Distributions::SS - Histograms forsingle scattering paths

=head1 VERSION

This documentation refers to Demeter version 0.4.

=head1 SYNOPSIS

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

An XES object and be frozen to and thawed from a YAML file in the same
manner as a Data object.  The attributes and data arrays are read to
and from YAMLs with a single object perl YAML.

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

Copyright (c) 2006-2011 Bruce Ravel (bravel AT bnl DOT gov). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
