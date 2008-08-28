package Ifeffit::Demeter::Atoms::Absorption;

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

use strict;
use warnings;
use Carp;
#use Class::Std;
#use Class::Std::Utils;
use Readonly;
use Xray::Absorption;
use Xray::Fluorescence;
Readonly my $ETOK    => 0.262468292;


{


  sub _absorption {
    my ($self) = @_;
    $self->populate if (not $self->get("is_populated"));
    my $cell = $self->get("cell");
    my $absorber = scalar $cell->central($self->get("core"));

    my $energy   = Xray::Absorption -> get_energy($absorber->get("element"), $self->get("edge"));
    my $contents = $cell -> get("contents");

    my $bravais  = $cell -> get("bravais");
    my $brav     = ($#{$bravais}+4) / 3;
    my $volume   = $cell -> get("volume");
    my ($mass, $xsec, $delta_mu) = (0,0,0);
    my %cache = ();		# memoize and call cross_section less often
    foreach my $position (@{$contents}) {
      my $site    = $position->[0];
      my $element = $site->get("element");
      my $factor  = 1; #$this_occ; # $occ ? $this_occ : 1; # consider site occupancy??
      my $weight  = Xray::Absorption -> get_atomic_weight($element);
      $mass      += $weight*$factor;
      $cache{lc($element)} ||=
	scalar Xray::Absorption -> cross_section($element, $energy+50);
      $xsec += $cache{lc($element)} * $factor;
      if ($absorber->get("element") eq $element) {
	$delta_mu += ($factor/$brav) *
	  ( $cache{lc($element)} -
	    scalar Xray::Absorption -> cross_section($element, $energy-50) );
      };
    };
    $mass     *= 1.66053/$volume; ## atomic mass unit = 1.66053e-24 gram
    $xsec     /= $volume;
    $delta_mu /= $volume;
    $self->set({xsec		=> sprintf("%.3f", 10000/$xsec),
		deltamu		=> sprintf("%.3f", 10000/$delta_mu),
		density		=> sprintf("%.3f", $mass),
		absorption_done	=> 1
	       });
  };
  sub xsec {
    my ($self) = @_;
    $self->_absorption if not $self->get("absorption_done");
    return $self->get("xsec");
  };
  sub deltamu {
    my ($self) = @_;
    $self->_absorption if not $self->get("absorption_done");
    return $self->get("deltamu");
  };
  sub density {
    my ($self) = @_;
    $self->_absorption if not $self->get("absorption_done");
    return $self->get("density");
  };



  sub mcmaster {
    my ($self)   = @_;
    return $self->get("mcmaster") if $self->get("mcmaster_done");
    my $cell     = $self->get("cell");
    my $absorber = scalar $cell->central($self->get("core"));
    my $central  = $absorber->get("element");
    my $edge     = $self->get("edge");
    my $mcmsig   = Xray::Fluorescence->mcmaster($central, $edge);
    $self->set({mcmaster => sprintf("%8.5f", $mcmsig),
		mcmaster_done => 1});
    return $self->get("mcmaster");
  };


  sub i0 {
    my ($self) = @_;
    return $self->get("i0") if $self->get("i0_done");

    my $cell = $self->get("cell");
    my $absorber = scalar $cell->central($self->get("core"));
    my $central  = $absorber->get("element");
    my $edge     = $self->get("edge");

    my %gases = ();
    map {$gases{$_} = $self->get($_) } qw(nitrogen argon krypton);
    my $i0sig   = Xray::Fluorescence->i0($central, $edge, \%gases);
    $self->set({i0 => sprintf("%8.5f", $i0sig),
		i0_done => 1});

    return $self->get("i0");
  };



  sub _self {
    my ($self) = @_;
    my $cell     = $self->get("cell");
    my $absorber = scalar $cell->central($self->get("core"));
    my $central  = $absorber->get("element");
    my $edge     = $self->get("edge");
    my $contents = $cell -> get("contents");
    my %count    = ();
    foreach my $position (@{$contents}) {
      my $site = $position->[0];
      ++$count{$site -> get("element")};
    };
    my @answer = Xray::Fluorescence->self($central, $edge, \%count);

    $self->set({selfamp   => sprintf("%6.3f", $answer[0]),
		selfsig   => sprintf("%8.5f", $answer[1]),
		self_done => 1
	       });
  };
  sub selfamp {
    my ($self) = @_;
    $self->_self if not $self->get("self_done");
    return $self->get("selfamp");
  };
  sub selfsig {
    my ($self) = @_;
    $self->_self if not $self->get("self_done");
    return $self->get("selfsig");
  };
  sub netsig {
    my ($self) = @_;
    $self->_mcmaster_correction if not $self->get("mcmaster_done");
    $self->_i_zero              if not $self->get("i0_done");
    $self->_self                if not $self->get("self_done");
    return sprintf("%8.5f", $self->get("selfsig") + $self->get("i0") + $self->get("mcmaster"));
  };

}
1;

=head1 NAME

Ifeffit::Demeter::Atoms::Absorption - Interaction with absorption tables

=head1 VERSION

This documentation refers to Ifeffit::Demeter version 0.1.

=head1 DESCRIPTION

This subclass of Ifeffit::Demeter::Atoms provides all of the methods
involved in calculations using tables of X-ray absorption coefficients
provided by the L<Xray::Absorption> package and the methods of the
L<Xray::Fluorescence> package.

=head1 METHODS

The only outward-looking methods are convenience function for
accessing Atoms attributes associated with the various calculations
this module provides.  The internal methods used to compute these
attributes will be called as necessary when these convenience
functions are called.  These methods are used in Atoms templates.

=over 4

=item C<xsec>

This returns the sample thickness required for a sample of total
absorption length equal to 1.

  print $atoms->xsec, $/;

=item C<deltamu>

This returns the sample thickness required for a sample with an edge
step equal to 1.

  print $atoms->deltamu, $/;

=item C<density>

This returns the density of the crystal computed from the cell volume
and contents.

  print $atoms->density, $/;

=item C<mcmaster>

This computes and returns the sigma^2 correction due to edge step
normalization.

  print $atoms->mcmaster, $/;

=item C<i0>

This computes and returns the sigma^2 correction due to the energy
response of the I0 detector in a fluorescence experiment.

  print $atoms->i0, $/;

=item C<selfamp>

This computes and returns the self absorption amplitude correction.

  print $atoms->selfamp, $/;

=item C<selfsig>

This computes and returns the self absorption sigma^2 correction.

  print $atoms->selfsig, $/;

=back

=head1 BUGS AND LIMITATIONS

Fourth cumulant corrections are not calculated.

Please report problems to Bruce Ravel (bravel AT anl DOT gov)

Patches are welcome.

=head1 AUTHOR

Bruce Ravel (bravel AT anl DOT gov)

L<http://cars9.uchicago.edu/~ravel/software/>

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2008 Bruce Ravel (bravel AT bnl DOT gov). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
