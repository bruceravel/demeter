package Demeter::Feff::Paths;

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

use Carp;
use Chemistry::Elements qw(get_Z);
use List::MoreUtils qw(all none pairwise);

use Moose::Role;
use Demeter::NumTypes qw( Ipot PosNum );

sub find_path {
  my ($self, @params) = @_;
  ## coerce arguments into a hash
  my %params = @params;

  ## -------- recognize singular and plural for nlegs
  ($params{nlegs}    = $params{nleg})      if (exists($params{nleg})      and not exists($params{nlegs}));
  ## -------- recognize singular and plural for list-valued criteria
  ($params{tag}      = $params{tags})      if (exists($params{tags})      and not exists($params{tag}));
  ($params{tagmatch} = $params{tagsmatch}) if (exists($params{tagsmatch}) and not exists($params{tagmatch}));
  ($params{ipot}     = $params{ipots})     if (exists($params{ipots})     and not exists($params{ipot}));
  ($params{element}  = $params{elements})  if (exists($params{elements})  and not exists($params{element}));

  ## -------- leave nothing undefined
  $params{sp}       ||= 0;
  $params{gt}       ||= 0;
  $params{lt}       ||= 0;
  $params{tagmatch} ||= 0;
  $params{tag}      ||= 0;
  $params{element}  ||= 0;
  $params{ipot}     ||= 0;
  $params{nlegs}    ||= 0;

  carp("\$feff->find_path : the sp criterion must be a ScatteringPath object\n\n"), return 0 if ($params{sp} and (ref($params{sp}) !~ m{ScatteringPath}));
  carp("\$feff->find_path : the lt criterion must be a positive number\n\n"),       return 0 if ($params{lt} and not is_PosNum($params{lt}));
  carp("\$feff->find_path : the gt criterion must be a positive number\n\n"),       return 0 if ($params{gt} and not is_PosNum($params{gt}));

  ## -------- scalar valued tests need to be made into array refs
  if ($params{tag} and (ref($params{tag}) ne 'ARRAY')) {
    $params{tag} = [ $params{tag} ];
  };
  if ($params{tagmatch} and (ref($params{tagmatch}) ne 'ARRAY')) {
    $params{tagmatch} = [ $params{tagmatch} ];
  };
  if ($params{ipot} and (ref($params{ipot}) ne 'ARRAY')) {
    $params{ipot} = [ $params{ipot} ];
  };
  if ($params{element} and (ref($params{element}) ne 'ARRAY')) {
    $params{element} = [ $params{element} ];
  };

  my $list_defined = $params{tag} || $params{tagmatch} || $params{ipot} || $params{element};

  if ($params{ipot}) {
    my $ipots_ok = 1;
    foreach my $i (@{ $params{ipot} }) {
      $ipots_ok &&= is_Ipot($i);
    };
    carp("\$feff->find_path : each part of the ipot criterion must be an integer between 0 and 7\n\n"), return 0 if not $ipots_ok;
  };
  if ($params{element}) {
    my $elements_ok = 1;
    foreach my $e (@{ $params{element} }) {
      $elements_ok &&= get_Z($e);
    };
    carp("\$feff->find_path : each part of the element criterion must be an element name, symbol, or Z number\n\n"), return 0 if not $elements_ok;
  };

  my @list_of_paths = @{ $self->pathlist };
  return $list_of_paths[0] if none {$params{$_}} (keys %params);

  my @list_of_sites = @{ $self->sites };
  my @ipots = @{ $self->potentials };

 PATHS: foreach my $p (@list_of_paths) {

    my $is_the_one = 1;

    $is_the_one &&= ($p->fuzzy > $params{sp}->fuzzy) if $params{sp};
    $is_the_one &&= ($p->nleg == $params{nlegs})     if $params{nlegs};
    $is_the_one &&= ($p->fuzzy > $params{gt})        if $params{gt};
    $is_the_one &&= ($p->fuzzy < $params{lt})        if $params{lt};

    next if not $is_the_one;

    if (not $list_defined) {
      return $p if $is_the_one;
      next PATHS;
    };

  DEGEN: foreach my $d (@{ $p->degeneracies }) {
      my $ok_so_far = $is_the_one;
      my %hash = $p->details($d);
      # print join(" ", $d, @{ $hash{tags}     }), $/;
      # print join(" ", @{ $hash{ipots}    }), $/;
      # print join(" ", @{ $hash{elements} }), $/;

      ## only consider these tests if this path has the same number of
      ## legs as the path we are looking for
      my @this = @{ $hash{tags} };
      my @test = ($params{tag})      ? @{ $params{tag} }
	       : ($params{tagmatch}) ? @{ $params{tagmatch} }
	       : ($params{ipot})     ? @{ $params{ipot} }
	       : ($params{element})  ? @{ $params{element} }
	       :                       () ;
      next PATHS if ($#this != $#test);

      $ok_so_far &&= all {$_} ( pairwise {$a eq $b}     @{ $hash{tags} },     @{ $params{tag} } )
	if $params{tag};

      $ok_so_far &&= all {$_} ( pairwise {($a =~ m{$b}i) ? 1 : 0} @{ $hash{tags} },     @{ $params{tagmatch} } )
	if $params{tagmatch};

      $ok_so_far &&= all {$_} ( pairwise {$a == $b}     @{ $hash{ipots} },    @{ $params{ipot} } )
	if $params{ipot};

      $ok_so_far &&= all {$_} ( pairwise {lc($a) eq lc($b)}     @{ $hash{elements} }, @{ $params{element} } )
	if $params{element};

      return $p if $ok_so_far;
    };
  };
  return 0;
};

sub find_all_paths {
  my ($self, @params) = @_;
  my @list_of_paths;

  my $path = $self->find_path(@params);
  while ($path) {
    push @list_of_paths, $path;
    my $next = $self->find_path(@params, sp=>$path);
    $path = $next;
  };

  return @list_of_paths;
};

1;

=head1 NAME

Demeter::Feff::Paths - Semantic descriptions of Feff paths

=head1 VERSION

This documentation refers to Demeter version 0.4.

=head1 SYNOPSIS

    $feff -> Demeter::Feff -> new(file=>"feff.inp");
    $feff -> potph;
    $feff -> pathfinder;
    my $scatteringpath = $feff->find_path(lt=>3.5, tag=>'Dy');

=head1 DESCRIPTION

This role for the Feff object provides a mechanism for semantically
describing paths from a Feff calculation.  The example in the synopsis
finds the single scattering path that is less than 3.5 Angstroms long
and scatters from a Dysprosium atom.

This way of interacting with the Feff calculation really shines in a
situation where structural distortions or modifications are introduced
into Feff's input data.  Because Feff orders its paths by increasing
half path length, the path index is not a reliable way of keeping
track of a particular scattering geometry as different structural
modifications are introduced.  Semantic mechanisms of probing the Feff
calculation allow you to keep track of particular geometries
regardless of the fine details of the strcuture provided to Feff.

=head1 METHODS

=over 4

=item C<find_path>

This method searches through a Feff calculation for a path that
matches B<each> of the provided criteria.  The first such path is the
one that returned.  The degeneracies associated with each path are
also searched.  Thus order does not matter for the list-valued
criteria and fuzzily degenerate paths will be found correctly.

This method returns 0 if a path meeting the criteria cannot be found
or if there is an error in specifying the criteria.

The following criteria are available:

=over 4

=item C<lt>

This criterion takes a number and requires that the returned path be
shorter in half path length than that number.

=item C<gt>

This criterion takes a number and requires that the returned path be
longer in half path length than that number.

=item C<nleg>

This criterion takes an integer and requires that the returned path
have this number of scattering legs.  This criterion is redundant when
the list-valued criteria are also used.

=item C<sp>

This criterion takes a ScatteringPath object and requires that the
returned path be longer in half path length than that path.

=item C<tag>

This criterion takes a string or an anonymous array of strings and
requires that the returned path contain the atoms which have this
(these) tags.  The tag is the optional fifth column in a F<feff.inp>
file written by Demeter's Atoms.  This criterion requires that the
tags are lexically equal.  See the C<tagmatch> criterion for matching
tags in the sense of regular expressions.

=item C<tagmatch>

This criterion takes a string or an anonymous array of strings and
requires that the returned path contain the atoms which have tags
matching the arguments of this criterion.  The tag is the optional
fifth column in a F<feff.inp> file written by Demeter's Atoms.  This
criterion requires that the tags match in the sense of regular
expressions.  See the C<tag> criterion for requiring that tags be
lexically equal.

=item C<ipot>

This criterion takes an integer from 0 to 7 or an anonymous array of
such integers and requires that the returned path contain the atoms
which have ipots equal to the arguments of this criterion.

=item C<element>

This criterion takes a string identifying an element (its name, its
one or two letter symbol or its Z number) or an anonymous array of
such strings and requires that the returned path contain the atoms
which have the elements specified.

=back

For several of the criteria, care is taken to recognize singluar and
plural forms.  That is, C<nleg> and C<nlegs> are synonymous as
criteria.

The list-valued criterion are compared in order with the scattering
atoms in a path.  As an example, this

    my $scatteringpath = $feff->find_path(lt=>4, tag=>['Fe1', 'C1']);

would return the first double scattering path that scatters from a
site with the tag C<Fe1> then from a site with the tag C<C1> before
completing the loop and returning to the central atom.

Some more examples:

   my $scatteringpath = $feff->find_path(gt=>4, ipots=>[2]);

In this example, the scattering path will be the first one that is
longer than 4 Angstroms, is a single scattering path, and scatters
from unique potential number 2.

   my $nextscatteringpath = $feff->find_path(sp=>$scatteringpath);

In this example, the path returned will be the next longer single
scattering path than the previous example and which also scatters from
unique potential number 2.

   my $scatteringpath = $feff->find_path(lt=>5.3, element=>["O", "Ti", "O"]);

This will return the shortest triple scattering path shorter than 5.3
Angstroms which scatters from oxygen, then titanium, then oxygen.

   my $scatteringpath = $feff->find_path(tagmatch=>["O[1-3]"]);

This will return the shortest first path (with no other length
restriction) which scatters from a site whose tag matches the given
regular expression -- in this case it will match any of O1, O2, or O3.


=item C<find_all_paths>

This returns a list of paths meeting the same criteria as for the
C<find_path> method.  This is just a wrapper around the C<find_path>
method which sequentially uses the C<sp> criterion to find each
subsequent path meeting the input criteria.

    my @list = $feff->find_all_paths(lt=>6, element=>['Fe', 'C']);

This returns all double scattering paths which scatter from iron and
carbon atoms and are less than 6 Angstroms.  The order of paths in the
list is in order of increasing half path length.

Another example:

   my @list =  $feff->find_all_paths(lt=>6, nleg=>2);

This returns all single scattering paths less than 6 Angstroms.

=back

=head1 CONFIGURATION AND ENVIRONMENT

See L<Demeter::Config> for a description of the configuration
system.

=head1 DEPENDENCIES

The dependencies of the Demeter system are in the
F<Bundle/DemeterBundle.pm> file.

=head1 BUGS AND LIMITATIONS

=over 4

Please report problems to Bruce Ravel (bravel AT bnl DOT gov)

Patches are welcome.

=back

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

