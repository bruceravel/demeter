package Ifeffit::Demeter::Data::E0;

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
use Class::Std;
use Class::Std::Utils;
use Fatal qw(open close);
use Regexp::Optimizer;
use Regexp::Common;
use Readonly;
Readonly my $NUMBER  => $RE{num}{real};
Readonly my $EPSILON => 1e-3;

use Xray::Absorption;

{

  sub e0 {
    my ($self, $mode) = @_;
    ($mode = "ifeffit") if ($mode !~ m{\A(?:atomic|fraction|zero|$NUMBER)\z});
    my $e0;
  MODE: {
      $e0 = $self->e0_ifeffit,                     last MODE if ($mode eq "ifeffit");
      $e0 = $self->e0_zero_crossing,               last MODE if ($mode eq "zero");
      $e0 = $self->e0_fraction,                    last MODE if ($mode eq "fraction");
      $e0 = $self->e0_atomic,                      last MODE if ($mode eq "atomic");
      $e0 = $mode->get("bkg_e0"), $self->set($e0), last MODE if (ref($mode) eq "Ifeffit::Demeter::Data");
      ($mode =~ m{\A$NUMBER\z}) and do {
	$self->set({bkg_e0=>$mode});
	$e0 = $mode;
	last MODE;
      };
    };
    $self->set({update_bkg=>1});
    return $e0;
  };

  sub e0_ifeffit {
    my ($self) = @_;
    $self->set({bkg_e0=>-9999999});	# force ifeffit to find e0
    $self->normalize;
    my $e0 = $self->get("bkg_e0");
    return $e0;
  };


  sub e0_fraction {
    my ($self) = @_;
    my $efrac = 0;
    my $fraction = $self->get("bkg_e0_fraction");
    $fraction ||= 0.5;
    ($fraction = 0.5) if ($fraction <= 0);
    ($fraction = 1.0) if ($fraction >  1);
    my $esh =  $self->get("bkg_eshift");
    my $prior = 0;
    my $count = 1;
    while (abs($self->get("bkg_e0")-$prior) > $EPSILON) {
      $prior = $self->get("bkg_e0");
      $self->normalize;
      my $fracstep = $fraction * $self->get("bkg_step");
      my @x = map {$_ + $esh} $self->get_array("energy");
      my @y = $self->get_array("pre");
      $efrac = 0;
      foreach my $i (0 .. $#x) {
	next if ($y[$i] < $fracstep);
	my $frac = ($fracstep - $y[$i-1]) / ($y[$i] - $y[$i-1]);
	$efrac = $x[$i-1] + $frac*($x[$i] - $x[$i-1]);
	last;
      };
      $self -> set({bkg_e0=>$efrac});
      ++$count;
      return $efrac if ($count > 5);	# it shouldn't take more than three
                                        # unless something is very wrong with
                                        # these data
    };
    return $efrac;
  };

  sub e0_zero_crossing {
    my ($self) = @_;
    my $shift = $self->get("bkg_eshift");
    my @energy = map {$_ + $shift} $self->get_array("energy");
    my @second = $self->get_array("sec");

    my $e0index = 0;
    foreach my $e (@energy) {
      last if ($e > $self->get("bkg_e0"));
      ++$e0index;
    };
    my ($enear, $ynear) = ($energy[$e0index], $second[$e0index]);
    my ($ratio, $i) = (1, 1);
    my ($above, $below) = (0,0);
    while (1) {			# find points that bracket the zero crossing
      (($above, $below) = (0,0)), last unless (exists($second[$e0index + $i]) and $second[$e0index]);
      $ratio = $second[$e0index + $i] / $second[$e0index]; # this ratio is negative for a point bracketing the zero crossing
      ($above, $below) = ($e0index+$i, $e0index+$i-1);
      last if ($ratio < 0);
      (($above, $below) = (0,0)), last unless exists($second[$e0index - $i]);
      $ratio = $second[$e0index - $i] / $second[$e0index]; # this ratio is negative for a point bracketing the zero crossing
      ($above, $below) = ($e0index-$i+1, $e0index-$i);
      last if ($ratio < 0);
      ++$i;
    };
    carp("Could not find zero crossing."), return if (($above == 0) and ($below == 0));

    ## linearly interpolate between points that bracket the zero crossing
    my $e0 = sprintf("%.3f", $energy[$below] - ($second[$below]/($second[$above]-$second[$below])) * ($energy[$above] - $energy[$below]));
    return $e0;
  };

  sub e0_atomic {
    my ($self) = @_;
    my $e0 = Xray::Absorption->get_energy( $self->get(qw(bkg_z fft_edge)) );
    return $e0;
  };


  sub calibrate {
    my ($self, $ref, $e0) = @_;
    $self -> _update("background");
    $ref ||= $self->get("bkg_e0");
    if (not $e0) {
      my $rx = $self->regexp('element');
      my ($z, $edge) = $self->get(qw(bkg_z fft_edge));
      croak("You must specify the absorber element to calibrate to the tabulated edge energy.")
	if (lc($z) !~ /$rx/);
      $rx = $self->regexp('edge');
      croak("You must specify the absorber edge to calibrate to the tabulated edge energy.")
	if (lc($edge) !~ /$rx/);
      $e0 = Xray::Absorption->get_energy($z, $edge);
    };
    my $delta = $e0 - $ref;
    my $shift = $self->get("bkg_eshift") + $delta;
    $self->set({bkg_e0     => $e0,
	        bkg_eshift => $shift,
		update_bkg => 1});
    return $e0;
  };

  sub align {
    my ($self, @data) = @_;
    my $standard = Ifeffit::Demeter->get_mode('standard');
    $self->standard;

    my $shift = 0;
    $self -> _update("background");
    foreach my $d (@data) {
      next if (ref($d) !~ m{Data});
      $d -> _update("background");
      $d -> dispose( $d-> template("process", "align") );
      $shift = Ifeffit::get_scalar("aa___esh");
      $d -> set({bkg_eshift=>$shift,
		 update_bkg=>1});
    };
    $standard->standard if (ref($standard) =~ m{Data});
    return $shift;
  };


  sub _e0_marker_command {
    my ($self, $requested) = @_;
    my $pf = $self->get_mode('plot');
    my $suffix = ($pf->get("e_norm") and $pf->get("e_der"))         ? "nder" :
                 ($pf->get("e_norm") and $self->get("bkg_flatten")) ? "flat" :
                 ($pf->get("e_norm"))                               ? "norm" :
                 ($pf->get("e_der"))                                ? "der"  :
		                                                      "xmu";
    my $y = $self->yofx($suffix, "", $self->get("bkg_e0"));
    my $command = $self->template("plot", "marker", { x => $self->get("bkg_e0"),
						     'y'=> $y+$self->get("y_offset")});
    return $command;
  };
  sub _preline_marker_command {
    my ($self, $requested) = @_;
    my $pf = $self->get_mode('plot');
    my $suffix = ($pf->get("e_norm") and $self->get("bkg_flatten")) ? "flat" :
                 ($pf->get("e_norm"))                               ? "norm" :
		                                                      "xmu";
    my $x = $self->get("bkg_pre1") + $self->get("bkg_e0");
    my $y = $self->yofx($suffix, "", $x);
    my $command = $self->template("plot", "marker", { x => $x, 'y'=> $y});
    $x    = $self->get("bkg_pre2") + $self->get("bkg_e0");
    $y    = $self->yofx($suffix, "", $x);
    $command   .= $self->template("plot", "marker", { x => $x, 'y'=> $y});
    return $command;
  };
  sub _postline_marker_command {
    my ($self, $requested) = @_;
    my $pf = $self->get_mode('plot');
    my $suffix = ($pf->get("e_norm") and $self->get("bkg_flatten")) ? "flat" :
                 ($pf->get("e_norm"))                               ? "norm" :
		                                                      "xmu";
    my $x = $self->get("bkg_nor1") + $self->get("bkg_e0");
    my $y = $self->yofx($suffix, "", $x);
    my $command = $self->template("plot", "marker", { x => $x, 'y'=> $y});
    $x    = $self->get("bkg_nor2") + $self->get("bkg_e0");
    $y    = $self->yofx($suffix, "", $x);
    $command   .= $self->template("plot", "marker", { x => $x, 'y'=> $y});
    return $command;
  };


};

1;


=head1 NAME

Ifeffit::Demeter::Data::E0 - Calibrate and align XAS mu(E) data

=head1 VERSION

This documentation refers to Ifeffit::Demeter version 0.1.

=head1 DESCRIPTION

This subclass of Ifeffit::Demeter::Data contains methods for calibrating
mu(E) data and adjusting e0.

=head1 METHODS

=over 4

=item C<calibrate>

This calibrates data by setting a chosen energy value to a new value.  This
method simultaneously sets the C<bkg_e0> and C<bkg_eshift> Data attributes.

  $e0 = $data -> calibrate($edge_point, $edge_energy);

Both arguments are optional.  If the C<$edge_point> is 0 or not given, then
the current value of C<bkg_e0> will be used.  If the C<$edge_energy> is not
given, then the tabulated energy for the absorber species and edge will be
used.  If C<$edge_energy> is 0 or not given and the Data object does not have
valid values for the C<bkg_z> and C<fft_edge> attributes, an exception will be
thrown.  The return value is the new value of the edge energy.

=item C<align>

This method align each item in a list of data objects to the Data object on
which the method is called.  That is, align each Data object in the argument
list to the calling object.

  $standard_data -> align(@list_of_data_to_align);

Each argument must be a Data object.  The return value is the energy shift of
the last Data object in the list.

=item C<e0>

This method is used to set the edge energy for mu(E) data either to a
number or a calculated value.

  $e0 = $data -> e0($mode);

The C<$mode> argument can be any of the following.  If C<$mode> is
omitted, it defaults to "ifeffit".

=over 4

=item I<ifeffit>

Use Ifeffit's internal algorithm for finding the edge energy.  This is
very similar to, but not exactly the same as, the first peak of the
first derivative.  Ifeffit actually uses a simple peak-finding
algorithm to distinguish the edge from noise in the pre-edge.  The
result of this is that Ifeffit often chooses an energy that is one or
two data points above what the human eye would recognize as the peak
of the first derivative.

=item I<zero>

Find the zero crossing of the second derivative of mu(E).  Starting
from the current value of the edge energy (or from the value returned
by Ifeffit's algorithm if the edge energy has not yet been set), step
forward and backward until the parity of the second derivative
spectrum switches.  Then linearly interpolate between the values
bracketing the parity change to find the zero value.

=item I<fraction>

Find the point in the edge of the normalized spectrum whose y-value is
a given fraction of the edge step.  By default, this fraction is 0.5,
but that can be set by the C<bkg_e0_fraction> attribute of the Data
object. This point is linearly interporlated from the normalized data.
The data are normalized again and the fractional point is found again
until its energy value changes by less than 0.001 volts, up to a
maximum of five iterations.

=item I<atomic>

Use the tabulated value of the zero-valent atomic binding energy as
the edge energy.

=item I<Data object>

If the C<$mode> is another Data object, set the edge energy of this
Data object to the value of the other one.

=item I<number>

If the C<$mode> is recognizable as a number, set the edge energy to
that value.

=back

=back

=head1 CONFIGURATION

See L<Ifeffit::Demeter::Config> for a description of the configuration
system.

=head1 DEPENDENCIES

Demeter's dependencies are in the F<Bundle/DemeterBundle.pm> file.

=head1 BUGS AND LIMITATIONS

Please report problems to Bruce Ravel (bravel AT bnl DOT gov)

Patches are welcome.

=head1 AUTHOR

Bruce Ravel (bravel AT bnl DOT gov)

L<http://cars9.uchicago.edu/~ravel/software/>

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2008 Bruce Ravel (bravel AT bnl DOT gov). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
