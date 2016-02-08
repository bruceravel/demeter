package Demeter::Data::Defaults;

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

use Moose::Role;

use Carp;

#use Demeter::Constants qw($NUMBER $EPSILON3);

use Xray::Absorption;


sub resolve_defaults {
  my ($self) = @_;
  if ($self->datatype =~ m{(?:xmu|xanes)}) {
    my @x = $self->get_array("energy");
    #my @y = $self->get_array("xmu");

    my ($pre1, $pre2) = $self->resolve_pre(\@x);
    if ($pre2 >= -35) {
      if (($self->bkg_e0 > 12000) and ($self->bkg_e0 < 20000)) {
	$pre2 -= 15;
      } elsif (($self->bkg_e0 > 20000) and ($self->bkg_e0 < 30000)) {
	$pre2 -= 30;
      } elsif ($self->bkg_e0 > 30000) {
	$pre2 -= 45;
      };
    };
    $pre1 = $x[0]-$self->bkg_e0 if ($self->bkg_e0 + $pre1 < $x[0]);
    $pre2 = $pre1+10 if ($self->bkg_e0 + $pre2 < $x[0]);
    $pre2 = $pre1/2  if ($pre2 > 0);
    $self->bkg_pre1(sprintf("%.3f",$pre1));
    $self->bkg_pre2(sprintf("%.3f",$pre2));

    my ($nor1, $nor2) = $self->resolve_nor(\@x);
    $self->bkg_nor1(sprintf("%.3f",$nor1));
    $self->bkg_nor2(sprintf("%.3f",$nor2));

    my ($spl1, $spl2) = $self->resolve_spl(\@x);
    $self->bkg_spl1(sprintf("%.3f",$spl1));
    $self->bkg_spl2(sprintf("%.3f",$spl2));

    my ($kmin, $kmax) = $self->resolve_krange_xmu(\@x);
    $self->fft_kmin(sprintf("%.3f",$kmin));
    $self->fft_kmax(sprintf("%.3f",$kmax));

    my $fraction = $self->resolve_e0_fraction;
    $self->bkg_e0_fraction($fraction);

    my ($clamp1, $clamp2) = $self->resolve_clamps;
    $self->bkg_clamp1($clamp1);
    $self->bkg_clamp2($clamp2);
  } elsif ($self->datatype eq 'chi') {
    my @x = $self->get_array("k");
    #my @y = $self->get_array("chi");
    my ($kmin, $kmax) = $self->resolve_krange_chi(\@x);
    $self->fft_kmin(sprintf("%.3f",$kmin));
    $self->fft_kmax(sprintf("%.3f",$kmax));
  };
  $self->update_norm(1);
};

## edge   Z   e0   (CheckBoxen: flatten and pc)
sub to_default {
  my ($self, $param) = @_;
  #print $param, $/;
 SWITCH: {
    ($param eq 'bkg_pre1') and do {
      $self->bkg_pre1($self->co->default("bkg", "pre1"));
      $self->bkg_pre2($self->co->default("bkg", "pre2"));
      my @x = $self->get_array("energy");
      my ($pre1, $pre2) = $self->resolve_pre(\@x);
      $self->bkg_pre1(sprintf("%.3f",$pre1));
      $self->bkg_pre2(sprintf("%.3f",$pre2));
      last SWITCH;
    };
    ($param eq 'bkg_nor1') and do {
      $self->bkg_nor1($self->co->default("bkg", "nor1"));
      $self->bkg_nor2($self->co->default("bkg", "nor2"));
      my @x = $self->get_array("energy");
      my ($nor1, $nor2) = $self->resolve_nor(\@x);
      $self->bkg_nor1(sprintf("%.3f",$nor1));
      $self->bkg_nor2(sprintf("%.3f",$nor2));
      last SWITCH;
    };
    ($param =~ m{bkg_spl1e?}) and do {
      $self->bkg_spl1($self->co->default("bkg", "spl1"));
      $self->bkg_spl2($self->co->default("bkg", "spl2"));
      my @x = $self->get_array("energy");
      my ($spl1, $spl2) = $self->resolve_spl(\@x);
      $self->bkg_spl1(sprintf("%.3f",$spl1));
      $self->bkg_spl2(sprintf("%.3f",$spl2));
      last SWITCH;
    };
    ($param eq 'bkg_eshift') and do {
      $self->bkg_eshift(0);
      last SWITCH;
    };
    ($param eq 'importance') and do {
      $self->importance(1);
      last SWITCH;
    };
    ($param eq 'bkg_rbkg') and do {
      $self->bkg_rbkg($self->co->default('bkg', 'rbkg'));
      last SWITCH;
    };
    ($param eq 'bkg_kw') and do {
      $self->bkg_kw($self->co->default('bkg', 'kw'));
      last SWITCH;
    };
    ($param eq 'bkg_nnorm') and do {
      ($self->datatype eq 'xanes') ? $self->bkg_nnorm($self->co->default('xanes', 'nnorm'))
	: $self->bkg_nnorm($self->co->default('bkg', 'nnorm'));
      last SWITCH;
    };
    ($param eq 'bkg_clamp1') and do {
      $self->bkg_clamp1($self->co->default("bkg", "clamp1"));
      my ($clamp1, $clamp2) = $self->resolve_clamps;
      $self->bkg_clamp1($clamp1);
      last SWITCH;
    };
    ($param eq 'bkg_clamp2') and do {
      $self->bkg_clamp2($self->co->default("bkg", "clamp2"));
      my ($clamp1, $clamp2) = $self->resolve_clamps;
      $self->bkg_clamp2($clamp2);
      last SWITCH;
    };
    ($param eq 'bkg_stan') and do {
      last SWITCH;
      $self->bkg_stan(q{});
    };

    ($param eq 'fft_kmin') and do {
      $self->fft_kmin($self->co->default("fft", "kmin"));
      $self->fft_kmax($self->co->default("fft", "kmax"));
      my @x = ($self->datatype eq 'chi') ? $self->get_array("k") : $self->get_array("energy");
      my ($kmin, $kmax) = ($self->datatype eq 'chi') ? $self->resolve_krange_chi(\@x) : $self->resolve_krange_xmu(\@x);
      $self->fft_kmin(sprintf("%.3f",$kmin));
      $self->fft_kmax(sprintf("%.3f",$kmax));
      last SWITCH;
    };
    ($param eq 'fft_dk') and do {
      $self->fft_dk($self->co->default('fft', 'dk'));
      last SWITCH;
    };
    ($param eq 'fft_kwindow') and do {
      $self->fft_kwindow($self->co->default('fft', 'kwindow'));
      $self->bft_rwindow($self->co->default('fft', 'kwindow'));
      last SWITCH;
    };
    ($param eq 'fit_karb_value') and do {
      $self->fit_karb_value(0.5);
      last SWITCH;
    };

    ($param eq 'bft_rmin') and do {
      $self->bft_rmin($self->co->default('bft', 'rmin'));
      $self->bft_rmax($self->co->default('bft', 'rmax'));
      last SWITCH;
    };
    ($param eq 'bft_dr') and do {
      $self->bft_dr($self->co->default('bft', 'dr'));
      last SWITCH;
    };

    ($param eq 'plot_multiplier') and do {
      $self->plot_multiplier(1);
      last SWITCH;
    };
    ($param eq 'y_offset') and do {
      $self->y_offset(0);
      last SWITCH;
    };
  };
  return $self;
};

sub resolve_e0_fraction {
  my ($self) = @_;
  my $fraction = $self->bkg_e0_fraction;
  ($fraction = 1)   if ($fraction  > 1);
  ($fraction = 0.5) if ($fraction <= 0);
  return $fraction;
};

sub resolve_clamps {
  my ($self) = @_;
  my ($clamp1, $clamp2) = ($self->bkg_clamp1, $self->bkg_clamp2);
  $clamp1 = $self->config->default("clamp", $clamp1) if $self->is_Clamp($clamp1);
  $clamp2 = $self->config->default("clamp", $clamp2) if $self->is_Clamp($clamp2);
  return ($clamp1, $clamp2);
};

sub resolve_pre {
  my ($self, $rx) = @_;
  my ($first, $second, $e0, $bkg_pre1, $bkg_pre2) =
    ($$rx[0], $$rx[1], $self->bkg_e0, $self->bkg_pre1, $self->bkg_pre2);
  $first  -= $e0;
  $second -= $e0;

  ($bkg_pre1 *= 1000) if (abs($bkg_pre1) < 1);
  my $pre1 = ($bkg_pre1  > 0) ? $first + $bkg_pre1
           : ($bkg_pre1 == 0) ? $second
	   : $bkg_pre1;

  ($bkg_pre2 *= 1000) if (abs($bkg_pre2) < 1);
  my $pre2 = ($bkg_pre2  > 0) ? $first + $bkg_pre2 : $bkg_pre2;

  ($pre1, $pre2) = sort {$a <=> $b} ($pre1, $pre2);
  return ($pre1, $pre2);
};

sub resolve_nor {
  my ($self, $rx) = @_;
  my ($last, $e0, $bkg_nor1, $bkg_nor2) = 
    ($$rx[-1], $self->bkg_e0, $self->bkg_nor1, $self->bkg_nor2);
  $last -= $e0;

  ## does this appear to be XANES data?
  my $cutoff = $self->co->default("xanes", "cutoff");
  if (($cutoff and ($last < $cutoff)) or ($self->datatype eq 'xanes')){
    ##carp "these are xanes data!\n\n";
    $bkg_nor1 = $self->co->default("xanes", "nor1") if ($bkg_nor1 == $self->co->default("bkg", "nor1"));
    $bkg_nor2 = $self->co->default("xanes", "nor2") if ($bkg_nor2 == $self->co->default("bkg", "nor2"));
    $self->datatype('xanes');
  };

  ($bkg_nor1 *= 1000) if (abs($bkg_nor1) < 1);
  my $nor1 = ($bkg_nor1  <= 0) ? $last + $bkg_nor1 : $bkg_nor1;

  ($bkg_nor2 *= 1000) if (abs($bkg_nor2) < 5);
  my $nor2 = ($bkg_nor2  <= 0) ? $last + $bkg_nor2 : $bkg_nor2;

  ($nor1, $nor2) = sort {$a <=> $b} ($nor1, $nor2);
  return ($nor1, $nor2);
};

## should I worry about energy values, say value>30 means it is energy?
sub resolve_spl {
  my ($self, $rx) = @_;
  my ($last, $e0, $bkg_spl1, $bkg_spl2) = 
    ($$rx[-1], $self->bkg_e0, $self->bkg_spl1, $self->bkg_spl2);
  my $lastk = $self->e2k($last, "absolute");
  $last -= $e0;
  $last = $self->e2k($last);

  my $spl1 = ($bkg_spl1  < 0) ? $last + $bkg_spl1 : $bkg_spl1;
  my $spl2 = ($bkg_spl2  < 0) ? $last + $bkg_spl2
           : ($bkg_spl2 == 0) ? $lastk
           :                    $bkg_spl2;

  ($spl1, $spl2) = sort {$a <=> $b} ($spl1, $spl2);
  ($spl2 = $lastk) if ($spl2 > $lastk);
  return ($spl1, $spl2);
};

sub resolve_krange_xmu {
  my ($self, $rx) = @_;
  my ($last, $e0, $fft_kmin, $fft_kmax) = ($$rx[-1], $self->bkg_e0, $self->fft_kmin, $self->fft_kmax);
  my $lastk = $self->e2k($last, "absolute");
  $last -= $e0;
  $last = $self->e2k($last);

  my $kmin = ($fft_kmin  < 0) ? $last + $fft_kmin : $fft_kmin;
  my $kmax = ($fft_kmax  < 0) ? $last + $fft_kmax
           : ($fft_kmax == 0) ? $lastk
           :                    $fft_kmax;

  ($kmin, $kmax) = sort {$a <=> $b} ($kmin, $kmax);
  ($kmax = $lastk) if ($kmax > $lastk);
  return ($kmin, $kmax);
};

sub resolve_krange_chi {
  my ($self, $rx) = @_;
  my @chi = @$rx;
  my ($last, $fft_kmin, $fft_kmax) = ($chi[$#chi]||0, $self->fft_kmin, $self->fft_kmax);

  my $kmin = ($fft_kmin  < 0) ? $last + $fft_kmin : $fft_kmin;
  my $kmax = ($fft_kmax  < 0) ? $last + $fft_kmax
           : ($fft_kmax == 0) ? $last
           :                    $fft_kmax;

  ($kmin, $kmax) = sort {$a <=> $b} ($kmin, $kmax);
  ($kmax = $last) if ($kmax > $last);
  return ($kmin, $kmax);
};

1;


=head1 NAME

Demeter::Data::Defaults - Resolve default parameter values

=head1 VERSION

This documentation refers to Demeter version 0.9.24.

=head1 DESCRIPTION

This role of Demeter::Data contains methods resolving default
parameter values from the contents of the data.  These rarely need to
be called in a program, but they need to be documented so that values
in configuration files can be understood.

=head1 METHODS

=over 4

=item C<resolve_defaults>

This method dispatches to the other methods of tyhis module depending
on whether the data are mu(E) or chi(k).

=item C<resolve_e0_fraction>

This method sanitizes the C<bkg_e0_fraction> parameter.  Values
greater than 1 are set to 1.  Values of 0 or less are set to 0.5.

=item C<resolve_clamps>

This method converts the words "none", "slight", "weak", "medium",
"strong", or "rigid" to their numeric values.  See the clamp
configuration group for tuning the translation between string and
numeric clamp values.

=item C<resolve_pre>

This method resolves the default values for C<bkg_pre1> and
C<bkg_pre2> to values appropriate to the data.  If the pre1 value is
set to 0, C<bkg_pre1> is set to evaluate the second data point.  If
either the pre1 or pre2 values is positive, it is set to evaluate that
far above the first data point.  Numbers less than 1 are interpreted
as keV.  C<bkg_pre1> and C<bkg_pre2> are sorted such that C<bkg_pre1>
is less than C<bkg_pre2>.  See the bkg configuration group for tuning
these defaults.

=item C<resolve_nor>

This method resolves the default values for C<bkg_nor1> and
C<bkg_nor2> to values appropriate to the data.  If the nor2 value is
set to 0, C<bkg_nor2> is set to evaluate the last data point.  If
either the nor1 or nor2 values is negative, it is set to evaluate that
far below the last data point.  Numbers less than 5 are interpreted
as keV.  C<bkg_nor1> and C<bkg_nor2> are sorted such that C<bkg_nor1>
is less than C<bkg_nor2>.  See the bkg configuration group for tuning
these defaults.

=item C<resolve_spl>

This method resolves the default values for C<bkg_spl1> and
C<bkg_spl2> to values appropriate to the data.  If the spl2 value is
set to 0, C<bkg_spl2> is set to evaluate the last data point.  If
either the spl1 or spl2 values is negative, it is set to evaluate that
far below the last data point.  C<bkg_spl1> and C<bkg_spl2> are sorted
such that C<bkg_spl1> is less than C<bkg_spl2>.  See the bkg
configuration group for tuning these defaults.

=item C<resolve_krange_xmu>

This method resolves the default values for C<fft_kmin> and
C<fft_kmax> to values appropriate to the mu(E) data.  If the kmax
value is set to 0, C<fft_kmax> is set to evaluate the last data point.
If either the kmin or kmax values is negative, it is set to evaluate
that far below the last data point.  C<fft_kmin> and C<fft_kmax> are
sorted such that C<fft_kmin> is less than C<fft_kmax>.  See the fft
configuration group for tuning these defaults.

=item C<resolve_krange_chi>

This method resolves the default values for C<fft_kmin> and
C<fft_kmax> to values appropriate to the chi(k) data (that is, data
that are originally imported as chi(k)).  If the kmax value is set to
0, C<fft_kmax> is set to evaluate the last data point.  If either the
kmin or kmax values is negative, it is set to evaluate that far below
the last data point.  C<fft_kmin> and C<fft_kmax> are sorted such that
C<fft_kmin> is less than C<fft_kmax>.  See the fft configuration group
for tuning these defaults.

=back

=head1 CONFIGURATION

See L<Demeter::Config> for a description of the configuration system.

=head1 DEPENDENCIES

Demeter's dependencies are in the F<Build.PL> file.

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
