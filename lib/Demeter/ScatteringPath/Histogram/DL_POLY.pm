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

use List::Util qw{sum};

has '+plottable'      => (default => 1);

has 'nsteps'    => (is => 'rw', isa => NonNeg, default => 0);
has 'timestep'  => (is => 'rw', isa => NonNeg, default => 0);
has 'rmin'      => (is => 'rw', isa => 'Num', default => 0.0,
		    trigger => sub{ my($self, $new) = @_; $self->fetch_rdf; $self->fetch_bins;} );
has 'rmax'      => (is => 'rw', isa => 'Num', default => 5.8,
		    trigger => sub{ my($self, $new) = @_; $self->fetch_rdf; $self->fetch_bins;} );
has 'bin'       => (is => 'rw', isa => 'Num', default => 0.005,
		    trigger => sub{ my($self, $new) = @_; $self->fetch_bins;} );

has 'file'      => (is => 'rw', isa => 'Str', default => q{},
		    trigger => sub{ my($self, $new) = @_;
				    if ($new and (-e $new)) {
				      $self->number_of_steps;
				      $self->fetch_cluster;
				      $self->fetch_rdf;
				      $self->fetch_bins;
				    }});

has 'cluster'     => (is => 'rw', isa => 'ArrayRef', default => sub{[]});
has 'rdf'         => (is => 'rw', isa => 'ArrayRef', default => sub{[]});
has 'positions'   => (is => 'rw', isa => 'ArrayRef', default => sub{[]});
has 'populations' => (is => 'rw', isa => 'ArrayRef', default => sub{[]});

has 'feff'        => (is => 'rw', isa => Empty.'|Demeter::Feff', default => q{},);
has 'sp'          => (is => 'rw', isa => Empty.'|Demeter::ScatteringPath', default => q{},);

## need a pgplot plotting template


sub number_of_steps {
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

sub fetch_cluster {
  my ($self) = @_;
  open(my $H, '<', $self->file);
  my $count = 0;
  my $use_this = 0;
  my $target = $self->timestep || $self->nsteps;
  my @cluster = ();
  while (<$H>) {
    if (m{\Atimestep}) {
      ++$count;
      last if $use_this;
      next;
    };
    $use_this=1 if ($count == $target);
    next if not $use_this;
    next if not m{\APt}; # skip the three lines trailing the timestamp
    my $position = <$H>;
    my $velocity = <$H>;
    my $force    = <$H>;
    chomp $position;
    my @vec = split(" ", $position);
    push @cluster, \@vec;
  };
  $self->cluster(\@cluster);
  return $self;
};

sub fetch_rdf {
  my ($self) = @_;
  my @rdf = ();
  my $size = $#{$self->cluster};
  foreach my $i (0 .. $size) {
    foreach my $j ($i+1 .. $size) { # all pairs are doubly degenerate
      my $r = sqrt sum  map { ($self->cluster->[$i]->[$_] - $self->cluster->[$j]->[$_])**2 } (0..2) ; # this may be too cute
      next if ($r < $self->rmin);
      next if ($r > $self->rmax);
      push @rdf, [$i, $j, $r];
    };
  };
  @rdf = sort { $a->[2] <=> $b->[2] } @rdf;
  $self->rdf(\@rdf);
  return $self;
};

sub fetch_bins {
  my ($self) = @_;
  my (@x, @y);
  my $bin_start = $self->rdf->[0]->[2];
  my ($population, $average) = (0,0);
  foreach my $pair (@{$self->rdf}) {
    if (($pair->[2] - $bin_start) > $self->bin) {
      $average = $average/$population;
      push @x, sprintf("%.5f", $average);
      push @y, $population*2;
      #print join(" ", sprintf("%.5f", $average), $population*2), $/;
      $bin_start = $pair->[2];
      $average = $pair->[2];
      $population = 1;
    } else {
      $average += $pair->[2];
      ++$population;
    };
  };
  $self->positions(\@x);
  $self->populations(\@y);
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
  return if not $self->feff;
  $self->feff->run;
  my @list_of_paths = @{ $self->feff->pathlist };
  my $firstshell = $list_of_paths[0];
  my $histo = $firstshell -> make_histogram($self->positions, $self->populations, q{}, q{});
  return $hosto;
};

sub fpath {
  my ($self) = @_;
  my $histo = $self->histogram;
  my $composite = $firstshell -> chi_from_histogram($histo);
  return $composite;
};

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

=item C<timestep> (integer)

The timestep from which to extract a cluster.  If zero, the final
timestep will be used.

=item C<rmin> and C<rmax> (numbers)

The lower and upper bounds of the radial distribution function to
extract from the cluster.  These are set to values that include a
single coordination shell when constructing input for an EXAFS fit.
However, for constructing a plot of the RDF, it may be helpful to set
these to cover a larger range of distances.

=item C<bin> (number)

The width of the histogram bin to be extracted from the RDF.

=item C<feff> (number)

This is set to the ScatteringPath object used to construct the bins of
the histogram.

=back

=head1 METHODS

=over 4

=item C<fpath>

Return an FPath object representing the sum of the bins of the
histogram extracted from the cluster.

=item C<histogram>

Return a reference to an array of SSPath objects representing the bins
of the histogram extracted from the cluster.

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
