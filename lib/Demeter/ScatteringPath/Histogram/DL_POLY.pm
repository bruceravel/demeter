package Demeter::ScatteringPath::Histogram::DL_POLY;

=for Copyright
 .
 Copyright (c) 2006-2010 Bruce Ravel (bravel AT bnl DOT gov).
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

with 'Demeter::Data::Arrays';
with 'Demeter::UI::Screen::Pause' if ($Demeter::mode->ui eq 'screen');
if ($Demeter::mode->ui eq 'screen') {
  with 'Demeter::UI::Screen::Pause';
  with 'Demeter::UI::Screen::Progress';
};

use List::Util qw{sum};

has '+plottable'      => (default => 1);

has 'nsteps'    => (is => 'rw', isa => NonNeg, default => 0);
has 'rmin'      => (is => 'rw', isa => 'Num', default => 0.0,);
has 'rmax'      => (is => 'rw', isa => 'Num', default => 5.8,);
has 'bin'       => (is => 'rw', isa => 'Num', default => 0.005,);

has 'file'      => (is => 'rw', isa => 'Str', default => q{},
		    trigger => sub{ my($self, $new) = @_;
				    if ($new and (-e $new)) {
				      $self->_cluster;
				      $self->rdf;
				    };
				  });
has 'timestep_count' => (is => 'rw', isa => 'Int',  default => 0);

has 'clusters'    => (is => 'rw', isa => 'ArrayRef', default => sub{[]});
has 'ssrdf'       => (is => 'rw', isa => 'ArrayRef', default => sub{[]});
has 'positions'   => (is => 'rw', isa => 'ArrayRef', default => sub{[]});
has 'populations' => (is => 'rw', isa => 'ArrayRef', default => sub{[]});

has 'sp'          => (is => 'rw', isa => Empty.'|Demeter::ScatteringPath', default => q{},);

## need a pgplot plotting template

sub rebin {
  my($self, $new) = @_;
  $self->_bin;
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
  foreach my $step (@{$self->clusters}) {
    $self->count if ($self->mo->ui eq 'screen');
    $self->timestep_count(++$count);
    $self->call_sentinal;
    my $size = $#{$step};
    foreach my $i (0 .. $size) {
      foreach my $j ($i+1 .. $size) { # remember that all pairs are doubly degenerate
	#my $rsqr = sum  map { ($step->[$i]->[$_] - $step->[$j]->[$_])**2 } (0..2) ; # this may be too cute
	my $rsqr = ($step->[$i]->[0] - $step->[$j]->[0])**2
	         + ($step->[$i]->[1] - $step->[$j]->[1])**2
	         + ($step->[$i]->[2] - $step->[$j]->[2])**2;
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

sub _bin {
  my ($self) = @_;
  my (@x, @y);
  my $bin_start = sqrt($self->ssrdf->[0]);
  my ($population, $average) = (0,0);
  $self->start_spinner("Binning RDF") if ($self->mo->ui eq 'screen');
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

Copyright (c) 2006-2010 Bruce Ravel (bravel AT bnl DOT gov). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
