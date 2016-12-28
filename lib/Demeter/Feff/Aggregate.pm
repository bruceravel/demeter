package Demeter::Feff::Aggregate;

=for Copyright
 .
 Copyright (c) 2006-2016 Bruce Ravel (http://bruceravel.github.io/home).
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
use Demeter::Return;

use Chemistry::Elements qw(get_symbol get_Z);
use Cwd qw(cwd);
use Heap::Fibonacci;
use File::Copy;
use File::Spec;
use List::Util qw(sum);
use List::MoreUtils qw(firstidx);
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
has 'master' => (is => 'rw', isa => 'Int',  default => -1);

sub setup {
  my ($self, $atoms, $abs) = @_;
  $atoms->populate if (not $atoms->is_populated);
  my %frac = $self->fractions($atoms, $abs);
  #Demeter->Dump(\%frac);
  my @sites;
  my @ipots;
  foreach my $site (keys(%frac)) {
    my $this = Demeter::Atoms->new;
    if ($atoms->file) {
      $this->file($atoms->file);
    } elsif ($atoms->cif) {
      $this->cif($atoms->cif);
      $this->record($atoms->record);
    };
    $this->set(rmax=>$atoms->rmax, rpath=>$atoms->rpath);
    $this->core($site);
    $this->build_cluster;
    push @sites, $this;

    my %seen = ();
    my @these;
    $this->set_ipots;
    foreach my $s (sort {$a->ipot <=> $b->ipot} @{ $this->cell->sites }) {
      next if not $s->ipot;
      next if $seen{$s->ipot};
      push @these, [$s->ipot, get_Z($s->element), $s->element];
      $seen{$s->ipot} = 1;
    };
    push @ipots, \@these;
  };
  my $ret = $self->ipot_compare($atoms, @ipots);
  return $ret if not $ret->is_ok;

  foreach my $s (@sites) {
    my $this = Demeter::Feff->new(atoms=>$s);
    $this->site_fraction($frac{$s->core});
    $self->push_parts($this);
  };

  return Demeter::Return->new;
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

sub ipot_compare {
  my ($self, $atoms, @ipots) = @_;
  my $ret = Demeter::Return->new();
  my $first = shift(@ipots);
  my $ok = 1;
  foreach my $i (@ipots) {
    my $this = ($#{$first} == $#{$i});
    $ok = ($ok and $this);
    if (not $ok) {
      $ret->message(sprintf("The sites do not have the same number of ipots.  Try a bigger cluster by setting Rmax to %.3f", $atoms->rmax+1));
      $ret->status(0);
      return $ret;
    };
  };

  my $text = q{};
  foreach my $i (@ipots) {
    foreach my $ip (0 .. $#{$first}) {
      my $this = ($first->[$ip]->[1] == $i->[$ip]->[1]);
      $ok = ($ok and $this);
      if (not $ok) {
	$text .= sprintf("ipot %d for site 1 is %s and for site 2 is %s\n",
			 $ip, set_symbol($first->[$ip]->[1]), set_symbol($i->[$ip]->[1]));
      };
    };
  };
  if (not $ok) {
    $ret->message($text);
    $ret->status(0);
    return $ret;
  };
  return $ret;
};


after 'run' => sub {
  my ($self) = @_;
  $self->make_workspace;
  my $feff_to_use = $self->parts->[$self->master];
  ## point all the ScatteringPath objects at Feff::Aggregate
  foreach my $sp (@{$self->pathlist}) {
    $sp->feff($self);
    $sp->folder($self->workspace);
  };
  ## copy over various things from master Feff object
  $self->absorber($feff_to_use->absorber);
  $self->abs_index($feff_to_use->abs_index);
  copy($feff_to_use->atoms->file,
       File::Spec->catfile($self->workspace, 'atoms.inp'));
  copy(File::Spec->catfile($feff_to_use->workspace, 'feff.inp'),
       File::Spec->catfile($self->workspace, $self->group.'.inp'));
  copy(File::Spec->catfile($feff_to_use->workspace, 'phase.bin'),
       $self->workspace);
  ## serialize
  my $yaml = File::Spec->catfile($self->workspace, $self->group.".yaml");
  $self->freeze($yaml);
  ## clean up
  $_->clean_workspace foreach (@{$self->parts});
  $_->DEMOLISH foreach (@{$self->parts});
  $self->clear_parts;
};

override 'potph' => sub {
  my ($self) = @_;
  my @rmt;
  my $i = 0;
  foreach my $p (@{$self->parts}) {
    $p->unshift_titles("TITLE Aggregate Feff calculation, Site ". ++$i);
    $p->execution_wrapper($self->execution_wrapper);
    $p->screen($self->screen);
    $p->potph;
    push @rmt, $self->fetch_rmt($p);
  };
  @rmt = sort {$a <=> $b} @rmt;
  my $median = $rmt[int($#rmt/2)];
  $self->master(firstidx {$_ == $median} @rmt);

  my $mfeff = $self->parts->[$self->master];
  foreach my $att (qw(sites titles potentials absorber miscdat rmax edge rmultiplier)) {
    $self->$att($mfeff->$att);
  };
  return $self;
};

sub fetch_rmt {
  my ($self, $feff) = @_;
  my $rmt = 0;
  open(my $MD, '<', File::Spec->catfile($feff->workspace, 'misc.dat'));
  while (<$MD>) {
    next if ($_ !~ m{\A\s+Abs\s+Z=});
    my @line = split(" ", $_);
    $rmt = $line[3];
  };
  close $MD;
  return $rmt;
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
    $f -> fuzz($self->fuzz);
    $f -> betafuzz($self->betafuzz);
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
      $elem->ipot([$elem->fetch_ipots]);
      $elem->feff($self);
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
  #Demeter->FDump("/home/bruce/foo", \@list_of_paths);
  $self->set(pathlist=>\@list_of_paths, npaths=>$#list_of_paths+1);
  return $self;
};


sub make_path {
  my ($self, $sp) = @_;
  my $path;
  if ($sp->nleg == 2) {
    $path = Demeter::SSPath -> new(parent => $sp->feff,
				   reff   => $sp->fuzzy,
				   ipot   => $sp->ipot->[1],
				   degen  => $sp->n,
				   n      => $sp->n,
				  );
    $path->make_name;
    $path->bvabs($sp->feff->abs_species);
    $path->bvscat(get_symbol($sp->feff->potentials->[$sp->ipot->[1]]->[1]));
    ## don't forget to set data attribute!
  } else {
    warn("Not yet doing MS paths from aggregate Feff calculation");
    return 0;
  };
  return $path;
};


sub path_geom {
  my ($self, $sp) = @_;
  my @central = $self->central;
  my @ipots = @{ $self->potentials };
  my $tag   = $ipots[$sp->ipot->[1]]->[2];

  my $pd = q{};

  $pd .= sprintf("  %4d    %d  %6.3f  index, nleg, degeneracy, r= %.4f\n",
		 0, $sp->nleg, $sp->n, $sp->fuzzy );
  $pd .= "      x           y           z     ipot  label";
  $pd .= "\n";
  $pd .= sprintf(" %11.6f %11.6f %11.6f   %d '%-6s'\n", $central[0], $central[1], $central[2]+$sp->fuzzy, $sp->ipot->[1], $tag);
  $pd .= sprintf(" %11.6f %11.6f %11.6f   %d '%-6s'\n", $self->central, 0, 'abs');
  return $pd;

};


__PACKAGE__->meta->make_immutable;
1;

=head1 NAME

Demeter::Feff::Aggregate - Perform the pathfinder fuzzily over inequivalent sites

=head1 VERSION

This documentation refers to Demeter version 0.9.26.

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

Many parameters are made common to all the Feff objects, included
C<rmax>, C<fuzz>, and C<betafuzz>.

Note that this runs Feff and Demeter's pathfinder once for each
inequivalent site.  It, therefore, takes exactly N times longer to run
than a normal Feff calculation.  Set C<rmax> sensibly!

=head1 ATTRIBUTES

=over 4

=item C<parts>

This is a reference to an array containing the Feff objects from each
inequivalent site.

=back

=head1 METHODS

=over 4

=item C<setup>

Load up the Feff::Aggregate object with its consitutent Feff objects.

   my $atoms = Demeter::Atoms->new(file=>'BaFe12O19.inp');
   my $bigfeff = Demeter::Feff::Aggregate->new;
   my $ret = $bigfeff->setup($atoms, 'Fe');

The arguments are an atoms object containing the crystal data and the
symbol of the absorbing element.  The Aggregate object will then
contain one Feff object for each inequivalent site in the unit cell.

The clusters computed for each site will be examined to verify that
they contain the same number of unique potentials which are listed in
the ipot list in the same order.

This method returns a L<Demeter::Return> object.  This will be loaded
with a C<message> containin any problem discovered in the analysis of
the ipot lists from the constituent atoms calculations.

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
F<Build.PL> file.

=head1 BUGS AND LIMITATIONS

Please report problems to the Ifeffit Mailing List
(L<http://cars9.uchicago.edu/mailman/listinfo/ifeffit/>)

Patches are welcome.

=head1 AUTHOR

Bruce Ravel, L<http://bruceravel.github.io/home>

L<http://bruceravel.github.io/demeter/>


=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2016 Bruce Ravel (L<http://bruceravel.github.io/home>). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
