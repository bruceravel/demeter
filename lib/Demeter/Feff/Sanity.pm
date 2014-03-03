package Demeter::Feff::Sanity;

=for Copyright
 .
 Copyright (c) 2006-2014 Bruce Ravel (bravel AT bnl DOT gov).
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

use Moose::Role;

use Carp;
use List::MoreUtils qw(any);
use Demeter::Constants qw($NUMBER);

use Text::Wrap;
$Text::Wrap::columns = 65;


#my $functions = Demeter->regexp('functions');

## verify 1. all ipots are used
##        2. no atoms have undefined ipots
##        3. there is one and only one central atom
##        4. resequence ipots if tests 1 and 2 pass,
##           but ipots are not sequential

##        5. warning about rmax outside cluster
##        6. ipot > 7

sub S_check_ipots {
  my ($self, $r_problems) = @_;
  my ($r_sites, $r_pots) = $self->get(qw(sites potentials));
  my @sites = @$r_sites;
  my @ipot_used    = (0,0,0,0,0,0,0,0); # ipots 0 .. 7
  my @ipot_defined = (0,0,0,0,0,0,0,0);
  foreach my $rs (@sites) {
    my $this_ipot = $rs -> [3];
    if ($this_ipot > 7) {
      $$r_problems{used_ipot_gt_7} = 1;
      push @{$$r_problems{errors}}, "You have defined an atom with potential index greater than 7.";
    } else {
      ++$ipot_used[$this_ipot];
    };
  };
  #my @pots = @$r_pots;
  #foreach my $rp (@pots) {
  foreach my $rp (@{$self->potentials}) {
    my $ipot = $rp->[0];
    if ($ipot > 7) {
      $$r_problems{defined_ipot_gt_7} = 1;
      push @{$$r_problems{errors}}, "You have defined a potential index greater than 7.";
    } else {
      ++$ipot_defined[$ipot];
    };
  };

  if ($ipot_used[0] == 0) {
    $$r_problems{no_absorber} = 1;
    push @{$$r_problems{errors}}, "You have not designated a central atom.  No site in the atoms list is of potential #0."
  };
  if ($ipot_used[0] > 1) {
    $$r_problems{multiple_absorbers} = 1;
    push @{$$r_problems{errors}}, "You have defined more than one central atom by using potential #0 more than once in the atoms list."
  };
  foreach my $i (0 .. $#ipot_used) {
    if ($ipot_used[$i] and not $ipot_defined[$i]) {
      $$r_problems{used_not_defined} = 1;
      push @{$$r_problems{errors}}, "You have used ipot #$i but not defined it as a potential."
    };
    if ($ipot_defined[$i] and not $ipot_used[$i]) {
      $$r_problems{defined_not_used} = 1;
      push @{$$r_problems{errors}}, "You have defined ipot #$i but not used it in the atoms list."
    };
  };

  #use Data::Dumper;
  #print Data::Dumper->Dump([\@ipot_used, \@ipot_defined],
  #		     [qw(*ipot_used *ipot_defined)]);
};

sub S_check_rmax {
  my ($self, $r_problems) = @_;
  return if ($$r_problems{no_absorber} or $$r_problems{multiple_absorbers});
  my ($r_sites, $rmax) = $self->get(qw(sites rmax));
  my @sites = @$r_sites;
  my @center;
  my $rfarthest = 0;
  foreach my $rs (@sites) {
    if ($rs->[3] == 0) {
      @center = ($rs->[0], $rs->[1], $rs->[2]);
      last;
    };
  };
  foreach my $rs (@sites) {
    my @this = @$rs[0..2];
    my $r = $self->distance(@this, @center);
    $rfarthest = $r if ($r > $rfarthest);
  };
  #print join(" ", $rmax,$rfarthest), $/;
  #if ($rmax > $rfarthest) {
  #  $$r_problems{rmax_outside_cluster} = 1;
  #  push @{$$r_problems{warnings}}, "You have specified a value of rmax that is outside the cluster."
  #};
};


sub S_check_cluster_size {
  my ($self, $r_problems) = @_;
  my $nsites = $#{ $self->sites };
  if ($nsites > 500) {
    $$r_problems{cluster_too_big} = 1;
    push @{$$r_problems{errors}}, "Your cluster size if larger than the copiled limit in Feff6L of 500 atoms."
  };
};

1;


=head1 NAME

Demeter::Feff::Sanity - Sanity checks for feff.inp files

=head1 VERSION

This documentation refers to Demeter version 0.9.20.

=head1 SYNOPSIS

    $feff -> Demeter::Feff -> new(file=>"feff.inp");

=head1 DESCRIPTION

This module contains all the sanity checks made on a F<feff.inp> file.
This file forms part of the base of the Demeter::Feff class and serves
no independent function.  That is, using this module directly in a
program does nothing useful -- it is purely a utility module for the
Feff object.

The user should never need to call the methods explicitly since they
are called automatically whenever a F<feff.inp> file is imported.
However they are documented here so that the scope of such checks made
is clearly understood.

=head1 METHODS

The following sanity checks are made on the imported F<feff.inp> file.

=over 4

=item *

Check that all potential indeces are used in the atom list.

=item *

Check that no atoms have undefined potential indeces.

=item *

Check there is one and only one central atom, i.e. an atom with
potential index 0.

=item *

Resequence the potential indeces if other tests pass but the indeces
are not sequential.

=item *

Warn about C<rmax> outside the cluster.

=item *

Warn if a potential index is greater than 7.

=back

=head1 DIAGNOSTICS

I think these are all self-explanatory.

=over 4

=item C<You have defined an atom with potential index greater than 7>

=item C<You have not designated a central atom.  No site in the atoms list is of potential #0.>

=item C<You have defined more than one central atom by using potential #0 more than once in the atoms list.>

=item C<You have used ipot #$i but not defined it as a potential.>

=item C<You have defined ipot #$i but not used it in the atoms list.>

=item C<You have specified a value of rmax that is outside the cluster.>

=back

=head1 CONFIGURATION AND ENVIRONMENT

See L<Demeter::Config> for a description of the configuration system.

=head1 DEPENDENCIES

The dependencies of the Demeter system are in the
F<Build.PL> file.

=head1 BUGS AND LIMITATIONS

There are no known bugs in this module.

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
