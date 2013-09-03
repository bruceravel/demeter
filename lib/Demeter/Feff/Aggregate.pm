package Demeter::Feff::Aggregate;

=for Copyright
 .
 Copyright (c) 2006-2013 Bruce Ravel (bravel AT bnl DOT gov).
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

use autodie qw(open close);

use Moose;
extends 'Demeter::Feff';

use Chemistry::Elements qw(get_symbol);
use Heap::Fibonacci;
use List::Util qw(sum);
use Math::Round qw(round);

has '+source'   => (default => 'aggregate');

has 'parts' => (
		traits    => ['Array'],
		is        => 'rw',
		isa       => 'ArrayRef',
		default   => sub { [] },
		handles   => {
			      'push_parts'  => 'push',
			      'pop_parts'   => 'pop',
			      'clear_parts' => 'clear',
			     },
	       );


sub setup {
  my ($self, $atoms, $abs) = @_;
  $atoms->populate if (not $atoms->is_populated);
  my %frac = $self->fractions($atoms, $abs);
  #Demeter->Dump(\%frac);
  my @sites;
  foreach my $site (keys(%frac)) {
    my $this = Demeter::Atoms->new(file=>$atoms->file);
    $this->set(rmax=>$atoms->rmax, rpath=>$atoms->rpath);
    $this -> core($site);
    $this->build_cluster;
    push @sites, $this;
  };

  foreach my $s (@sites) {
    my $this = Demeter::Feff->new(atoms=>$s);
    $this->site_fraction($frac{$s->core});
    $self->push_parts($this);
  };
};


sub fractions {
  my ($self, $atoms, $abs_element) = @_;
  my %frac;
  my $abs = get_symbol($abs_element);
  foreach my $s (@{$atoms->cell->contents}) {
    next if $s->[0]->element ne $abs;
    ++$frac{$s->[0]->tag};
  };
  my $sum = sum values(%frac);
  $frac{$_} /= $sum foreach keys(%frac);
  return %frac;
};


override 'potph' => sub {
  my ($self) = @_;
  foreach my $p (@{$self->parts}) {
    $p->potph;
  };
  $self->miscdat($self->parts->[0]->miscdat);
  $self->rmax($self->parts->[0]->rmax);
  return $self;
};

override 'pathfinder' => sub {
  my ($self) = @_;

  my $screen = ((not $self->parts->[0]->screen) and ($self->parts->[0]->mo->ui eq 'screen'));
  my $bigheap = Heap::Fibonacci->new;
  my $isite = 1;
  my $bigcount = 0;
  my $sitecount = 0;
  $self -> eta_suppress(Demeter->co->default("pathfinder", "eta_suppress"));
  foreach my $f (@{$self->parts}) {
    $f -> report("\n" . '=' x 60 . "\n=== Site $isite\n\n");
    $f -> start_spinner("Demeter's pathfinder is running") if $screen;
    $f -> eta_suppress(Demeter->co->default("pathfinder", "eta_suppress"));
    $f -> report("=== Preloading distances\n");
    $f -> _preload_distances;
    $f -> report("=== Cluster contains " . $f->nsites . " atoms\n");
    $sitecount += $f->nsites;
    my $this_tree = $f->_populate_tree;
    my $this_heap = $f->_traverse_tree($this_tree);
    undef $this_tree;
    while (my $elem = $this_heap->extract_top) {
      #$elem->feff($self);
      $bigheap->add($elem);
      $bigcount += 1;
    };
    undef $this_heap;
    ++$isite;
    $f->stop_spinner if $screen;
  };

  $self -> nsites(round($sitecount / ($#{$self->parts}+1)));
  $self -> report("\n=== All sites contribute $bigcount paths\n");
  my @list_of_paths = $self->_collapse_heap($bigheap);
  foreach my $sp (@list_of_paths) {
    $sp->pathfinding(0);
    $sp->mo->push_ScatteringPath($sp);
  };
  $self->set(pathlist=>\@list_of_paths, npaths=>$#list_of_paths+1);
  return $self;
};

override 'fetch_zcwifs' => sub {
  my ($self) = @_;
  my @z = ();
  foreach my $i (0 .. $#{$self->pathlist}) {
    $z[$i] = 0;
  };
  return @z;
};

__PACKAGE__->meta->make_immutable;
1;

=head1 NAME

Demeter::Feff::Aggregate - Perform the pathfinder fuzzily over inequivalent sites

=head1 VERSION

This documentation refers to Demeter version 0.9.18.

=head1 SYNOPSIS

   my $atoms = Demeter::Atoms->new(file=>'BaFe12O19.inp');
   my $bigfeff = Demeter::Feff::Aggregate->new;
   $bigfeff->setup($atoms, 'Fe');
   $bigfeff->run;

The C<run> method calls overridden C<potph> and C<pathfinder> methods
which iterate over all inequivalent sites in the unit cell.  The
degeneracies of the paths are weighted by the number of each site in
the fully populated unit cell.

See the file F<examples/recipes/FuzzyOverSites/pfo.pl> in the Demeter
distribution for an example.

=head1 DESCRIPTION

This organizes a sequence of partial Feff calculations, one for each
inequivalent site in the unit cell containing the absorber species.
The C<potph> method is run on each Feff object.  Then, for each, Feff
object the first few steps of the C<pathfinder> method are run.  For
each Feff, the tree of scattering geometries is constructed and the
heap of paths is filled.

Each heap is then unloaded onto a master heap.  This master heap is
collapsed in the nomral manner so that fuzzy degeneracies are found
over all the inequivalent sites in the aggregate.

Care is taken to compute the degeneracies and fuzzy half lengths
considering the fractional representation of each site in the unit
cell.  As a result, degeneracies are unlikely to be integer valued.

This object extends the normal Feff object.  At the end, therefore,
the C<pathlist> attribute is filled with fuzzily degenerate path list
computed in the aggregate over all sites.  In that sense, the
Aggregate object can be used just like a normal Feff object when it
comes time to build a fitting model or do something else with the Feff
claculation.

Each individual Feff calculation is retained and used when it comes
time to compute the actual paths.  A few attributes of the Aggregate
object may be a bit surprising.  The C<miscdat> attribute is filled
with that value from the Feff object from first site in the list of
inequivalent sites.  The C<nsites> attribute is filled with average of
the nsites of the constituent Feff objects, rounded to the nearest
integer.

Many parameters are common to all the Feff objects, included C<rmax>,
C<fuzz>, and C<betafuzz>.

Note that this runs Feff and Demeter's pathfinder once for each
inequivalent site.  It, therefore, takes exactly N times longer to run
than a normal Feff calculation.  Set C<rmax> sensibly!

=head1 ATTRIBUTES

=over 4

=items C<parts>

This is a reference to an array containing the Feff objects from each
inequivalent site.

=back

=head1 METHODS

=over 4

=item C<setup>

Load up the Feff::Aggregate object with its consitutent Feff objects.

   my $atoms = Demeter::Atoms->new(file=>'BaFe12O19.inp');
   my $bigfeff = Demeter::Feff::Aggregate->new;
   $bigfeff->setup($atoms, 'Fe');

The arguments are an atoms object containing the crystal data and the
symbol of the absorbing element.  The Aggregate object will then
contain one Feff object for each inequivalent site in the unit cell.

=item C<fractions>

This populates a unit cell and counts how many of each inequivalent
site is present.  It then sets the C<site_fraction> attribute of each
Feff object in the Aggregate so that path degeneracies and fuzzy
halflengths are corectly calculated.

=back

=head1 CONFIGURATION AND ENVIRONMENT

See L<Demeter> for a description of the configuration system.

=head1 DEPENDENCIES

The dependencies of the Demeter system are in the
F<Bundle/DemeterBundle.pm> file.

=head1 BUGS AND LIMITATIONS

=over 4

=item * Serialization and persistence

=back

Please report problems to Bruce Ravel (bravel AT bnl DOT gov)

Patches are welcome.

=head1 AUTHOR

Bruce Ravel (bravel AT bnl DOT gov)

L<http://bruceravel.github.com/demeter/>


=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2013 Bruce Ravel (bravel AT bnl DOT gov). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
