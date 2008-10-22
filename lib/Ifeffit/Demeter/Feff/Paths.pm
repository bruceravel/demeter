package Ifeffit::Demeter::Feff::Paths;

=for Copyright
 .
 Copyright (c) 2006-2008 Bruce Ravel (bravel AT bnl DOT gov).
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

use Moose::Role;

use Carp;
use List::MoreUtils qw(all none pairwise);


## Reff greater than
## Reff less than
## tag(s) matches
## tag(s) equals
## element is (are)
## ipot is (are)
## nlegs
sub find_path {
  my ($self, @params) = @_;
  ## coerce arguments into a hash
  my %params = @params;

  ($params{tag}      = $params{tags})      if (exists($params{tags})      and not exists($params{tag}));
  ($params{tagmatch} = $params{tagsmatch}) if (exists($params{tagsmatch}) and not exists($params{tagmatch}));
  ($params{ipot}     = $params{ipots})     if (exists($params{ipots})     and not exists($params{ipot}));
  ($params{element}  = $params{elements})  if (exists($params{elements})  and not exists($params{element}));

  $params{gt}       ||= 0;
  $params{lt}       ||= 0;
  $params{tagmatch} ||= 0;
  $params{tag}      ||= 0;
  $params{element}  ||= 0;
  $params{ipot}     ||= 0;
  $params{nlegs}    ||= 0;

  ## scalar valued tests need to be made into an array ref
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

  $params{list} = $params{tag} || $params{tagmatch} || $params{ipot} || $params{element};


  my @list_of_paths = @{ $self->pathlist };
  return $list_of_paths[0] if none {$params{$_}} (keys %params);

  my @list_of_sites = @{ $self->sites };
  my @ipots = @{ $self->potentials };

 PATHS: foreach my $p (@list_of_paths) {

    my $is_the_one = 1;


    $is_the_one &&= ($p->nleg != $params{nlegs}) if $params{nlegs};
    $is_the_one &&= ($p->fuzzy > $params{gt})    if $params{gt};
    $is_the_one &&= ($p->fuzzy < $params{lt})    if $params{lt};

    next if not $is_the_one;

    if (not $params{list}) {
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

      $ok_so_far &&= all {$_} ( pairwise {$a eq $b}     @{ $hash{elements} }, @{ $params{element} } )
	if $params{element};

      return $p if $ok_so_far;
    };
  };
};


1;
