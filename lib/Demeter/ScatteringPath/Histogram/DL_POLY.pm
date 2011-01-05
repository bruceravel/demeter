package Demeter::ScatteringPath::Histogram::DL_POLY;

=for Copyright
 .
 Copyright (c) 2006-2011 Bruce Ravel (bravel AT bnl DOT gov).
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

use Moose;
use MooseX::Aliases;
#use MooseX::StrictConstructor;
extends 'Demeter';
use Demeter::StrTypes qw( Empty );
use Demeter::NumTypes qw( Natural PosInt NonNeg );

use POSIX qw(acos);
use Readonly;
Readonly my $PI => 4*atan2(1,1);

with 'Demeter::Data::Arrays';
with 'Demeter::UI::Screen::Pause' if ($Demeter::mode->ui eq 'screen');
if ($Demeter::mode->ui eq 'screen') {
  with 'Demeter::UI::Screen::Pause';
  with 'Demeter::UI::Screen::Progress';
};

use List::Util qw{sum};

has '+plottable'      => (default => 1);

has 'nsteps'    => (is => 'rw', isa => NonNeg, default => 0);
has 'update_bins' => (is => 'rw', isa => 'Bool', default => 1);
has 'rmin'      => (is => 'rw', isa => 'Num', default => 0.0,
		    trigger => sub{ my($self, $new) = @_; $self->update_bins(1) if $new});
has 'rmax'      => (is => 'rw', isa => 'Num', default => 5.6,
		    trigger => sub{ my($self, $new) = @_; $self->update_bins(1) if $new});
has 'bin'       => (is => 'rw', isa => 'Num', default => 0.005,);

has 'r1'        => (is => 'rw', isa => 'Num', default => 0.0,);
has 'r2'        => (is => 'rw', isa => 'Num', default => 3.5,);
has 'r3'        => (is => 'rw', isa => 'Num', default => 5.2,);
has 'r4'        => (is => 'rw', isa => 'Num', default => 5.6,);
has 'beta'      => (is => 'rw', isa => 'Num', default => 20,);

has 'ss'        => (is => 'rw', isa => 'Bool', default => 0, trigger=>sub{my($self, $new) = @_; $self->ncl(0) if $new});
has 'ncl'       => (is => 'rw', isa => 'Bool', default => 0, trigger=>sub{my($self, $new) = @_; $self->ss(0)  if $new});

has 'file'      => (is => 'rw', isa => 'Str', default => q{},
		    trigger => sub{ my($self, $new) = @_;
				    if ($new and (-e $new)) {
				      $self->_cluster;
				      $self->rdf if $self->ss;
				      $self->nearly_collinear if $self->ncl;
				    };
				  });
has 'timestep_count' => (is => 'rw', isa => 'Int',  default => 0);

has 'clusters'    => (is => 'rw', isa => 'ArrayRef', default => sub{[]});
has 'ssrdf'       => (is => 'rw', isa => 'ArrayRef', default => sub{[]});
has 'nearcl'      => (is => 'rw', isa => 'ArrayRef', default => sub{[]});
has 'positions'   => (is => 'rw', isa => 'ArrayRef', default => sub{[]});
has 'populations' => (is => 'rw', isa => 'ArrayRef', default => sub{[]});

has 'sp'          => (is => 'rw', isa => Empty.'|Demeter::ScatteringPath', default => q{},);

## need a pgplot plotting template

sub rebin {
  my($self, $new) = @_;
  $self->_bin if $self->update_bins;
  return $self;
};

sub _number_of_steps {
  my ($self) = @_;
  open(my $H, '<', $self->file);
  my $count = 0;
  while (<$H>) {
    ++$count if m{\Atimestep};
  }
  #print $steps, $/;
  close $H;
  $self->nsteps($count);
  return $self;
};

sub _cluster {
  my ($self) = @_;
  $self->_number_of_steps;
  open(my $H, '<', $self->file);
  my @cluster = ();
  my @all = ();
  while (<$H>) {
    if (m{\Atimestep}) {
      push @all, \@cluster;
      @cluster = ();
      next;
    };
    next if not m{\APt}; # skip the three lines trailing the timestamp
    my $position = <$H>;
    my @vec = split(" ", $position);
    push @cluster, \@vec;
    <$H>;
    <$H>;
    #my $velocity = <$H>;
    #my $force    = <$H>;
    #chomp $position;
  };
  $self->clusters(\@all);
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
  foreach my $step (@{$self->clusters}) {
    my @this = @$step;
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
  return $self;
};

sub nearly_collinear {
  my ($self) = @_;
  my $count = 0;
  my $r1sqr = $self->r1**2;
  my $r2sqr = $self->r2**2;
  my $r3sqr = $self->r3**2;
  my $r4sqr = $self->r4**2;

  $self->start_counter("Making RDF from each timestep", ($#{$self->clusters}+1)/50) if ($self->mo->ui eq 'screen');
  my ($x0, $x1, $x2) = (0,0,0);
  my ($a0, $a1, $a2) = (0,0,0);
  my @three = ();
  my $costh;
  my $cosbetamax = cos($PI*$self->beta/180);
  foreach my $step (@{$self->clusters}) {
    #my $step = $self->clusters->[400];
    my @rdf1 = ();
    my @rdf4 = ();

    my @this = @$step;
    $self->timestep_count(++$count);
    next if $count % 50;
    $self->count if ($self->mo->ui eq 'screen');
    #$self->call_sentinal;
    foreach my $i (0 .. $#this) {
      ($x0, $x1, $x2) = @{$this[$i]};
      foreach my $j (0 .. $#this) {
	my $rsqr = ($x0 - $this[$j]->[0])**2
	         + ($x1 - $this[$j]->[1])**2
	         + ($x2 - $this[$j]->[2])**2; # this loop has been optimized for speed, hence the weird syntax
	push @rdf1, [sqrt($rsqr), $i, $j] if (($rsqr > $r1sqr) and ($rsqr < $r2sqr));
	push @rdf4, [sqrt($rsqr), $i, $j] if (($rsqr > $r3sqr) and ($rsqr < $r4sqr));
      };
    };

    #use Data::Dumper;
    #print Data::Dumper->Dump([\@rdf1, \@rdf4], [qw/*rdf1 *rdf4/]), $/;
    #printf("number of 1st neighbors = %d, number of 4th neighbors = %d\n", $#rdf1, $#rdf4);

    foreach my $fth (@rdf4) {
      my $n4 = $fth->[1];
      foreach my $fst (@rdf1) {
	next if ($n4 ne $fst->[1]);
	($a0, $a1, $a2) = ($this[ $fth->[1] ]->[0], $this[ $fth->[1] ]->[1], $this[ $fth->[1] ]->[2]);
	$costh =
 	  (($this[ $fst->[2] ]->[0] - $a0) * ($this[ $fth->[2] ]->[0] - $a0) +
	   ($this[ $fst->[2] ]->[1] - $a1) * ($this[ $fth->[2] ]->[1] - $a1) +
	   ($this[ $fst->[2] ]->[2] - $a2) * ($this[ $fth->[2] ]->[2] - $a2))  / ($fth->[0] * $fst->[0]);

	#my $costh = ($vec1[0]*$vec4[0] + $vec1[1]*$vec4[1] + $vec1[2]*$vec4[2]) / ($fth->[0] * $fst->[0]);
	#print $costh, "  ", $cosbetamax, $/;
	next if ($costh < $cosbetamax);
	push @three, [$fst->[0], $fth->[0], $costh];
	#printf("%d  %d  %d %.5f  %.5f  %.5f  %.5f\n",
	#     $fst->[1], $fst->[2], $fth->[2], $fst->[0], $fth->[0], $costh, 180*acos($costh)/$PI);
      };
    };
  };
  $self->stop_counter if ($self->mo->ui eq 'screen');
  $self->nearcl(\@three);
};

sub _bin {
  my ($self) = @_;
  my (@x, @y);
  my $bin_start = sqrt($self->ssrdf->[0]);
  my ($population, $average) = (0,0);
  $self->start_counter("Making RDF from each timestep", $#{$self->clusters}+1) if ($self->mo->ui eq 'screen');
  foreach my $pair (@{$self->ssrdf}) {
    my $rr = sqrt($pair);
    if (($rr - $bin_start) > $self->bin) {
      $average = $average/$population;
      push @x, sprintf("%.5f", $average);
      push @y, $population*2;
      #print join(" ", sprintf("%.5f", $average), $population*2), $/;
      $bin_start = $rr;
      $average = $rr;
      $population = 1;
    } else {
      $average += $rr;
      ++$population;
    };
  };
  $self->positions(\@x);
  $self->populations(\@y);
  $self->update_bins(0);
  $self->stop_spinner if ($self->mo->ui eq 'screen');
  return $self;
};

sub plot {
  my ($self) = @_;
  Ifeffit::put_array(join(".", $self->group, 'x'), $self->positions);
  Ifeffit::put_array(join(".", $self->group, 'y'), $self->populations);
  $self->po->start_plot;
  $self->dispose($self->template('plot', 'histo'), 'plotting');
  return $self;
};

sub histogram {
  my ($self) = @_;
  return if not $self->sp;
  my $histo = $self -> sp -> make_histogram($self->positions, $self->populations, q{}, q{});
  return $histo;
};

sub fpath {
  my ($self) = @_;
  my $histo = $self->histogram;
  my $composite = $self -> sp -> chi_from_histogram($histo);
  return $composite;
};

__PACKAGE__->meta->make_immutable;
1;

=head1 NAME

Demeter::ScatteringPath::Histogram::DL_POLY - Support for DL_POLY HISTORY file

=head1 VERSION

This documentation refers to Demeter version 0.4.

=head1 SYNOPSIS

=head1 DESCRIPTION

This provides support for importing data from the DL_POLY HISTORY
file, which is a format for providing the trajectory of a cluster
during a molecular dynamics simulation.  The DL_POLY website is
L<http://www.cse.scitech.ac.uk/ccg/software/DL_POLY/> and a
description of the HISTORY format is in section 5.2.1 of the User
Guide, a link to which can be found at the DL_POLY website.

The main purpose of this module is to extract the coordinates for a
given timestep from the history file and use those coordinates to
construct a histogram representation of that cluster for use in a fit
to EXAFS data using Demeter.

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

=back

=head1 METHODS

=over 4

=item C<fpath>

Return a L<Demeter::FPath> object representing the sum of the bins of
the histogram extracted from the cluster.

=item C<histogram>

Return a reference to an array of L<Demeter::SSPath> objects
representing the bins of the histogram extracted from the cluster.

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

An XES object and be frozen to and thawed from a YAML file in the same
manner as a Data object.  The attributes and data arrays are read to
and from YAMLs with a single object perl YAML.

=head1 BUGS AND LIMITATIONS

=over 4

=item *

This currently only works for a monoatomic cluster.

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

Copyright (c) 2006-2011 Bruce Ravel (bravel AT bnl DOT gov). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
