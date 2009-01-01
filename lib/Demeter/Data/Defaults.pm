package Demeter::Data::Defaults;

=for Copyright
 .
 Copyright (c) 2006-2009 Bruce Ravel (bravel AT bnl DOT gov).
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

use Regexp::Optimizer;
use Regexp::Common;
use Readonly;
Readonly my $NUMBER  => $RE{num}{real};
Readonly my $EPSILON => 1e-3;

use Xray::Absorption;


sub resolve_defaults {
  my ($self) = @_;
  if ($self->datatype eq 'xmu') {
    my @x = $self->get_array("energy");
    #my @y = $self->get_array("xmu");
    $self->resolve_pre(\@x);
    $self->resolve_nor(\@x);
    $self->resolve_spl(\@x);
    $self->resolve_krange_xmu(\@x);
    $self->resolve_e0_fraction;
    $self->resolve_clamps;
  } else {
    my @x = $self->get_array("k");
    #my @y = $self->get_array("chi");
    $self->resolve_krange_chi(\@x);
  };
};

sub resolve_e0_fraction {
  my ($self) = @_;
  my $fraction = $self->bkg_e0_fraction;
  ($fraction = 1)   if ($fraction  > 1);
  ($fraction = 0.5) if ($fraction <= 0);
  $self->bkg_e0_fraction($fraction);
};

sub resolve_clamps {
  my ($self) = @_;
  my ($clamp1, $clamp2) = ($self->bkg_clamp1, $self->bkg_clamp2);
  $clamp1 = $self->config->default("clamp", $clamp1) if $self->is_Clamp($clamp1);
  $clamp2 = $self->config->default("clamp", $clamp2) if $self->is_Clamp($clamp2);
  $self->bkg_clamp1($clamp1);
  $self->bkg_clamp2($clamp2);
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

  $self->bkg_pre1(sprintf("%.3f",$pre1));
  $self->bkg_pre2(sprintf("%.3f",$pre2));
};

sub resolve_nor {
  my ($self, $rx) = @_;
  my ($last, $e0, $bkg_nor1, $bkg_nor2) = 
    ($$rx[-1], $self->bkg_e0, $self->bkg_nor1, $self->bkg_nor2);
  $last -= $e0;

  ## does this appear to be XANES data?
  my $cutoff = $self->co->default("xanes", "cutoff");
  if ($cutoff and ($last < $cutoff)) {
    ##carp "these are xanes data!\n";
    ($bkg_nor1, $bkg_nor2) = ($self->co->default("xanes", "nor1"),
			      $self->co->default("xanes", "nor2"));
  };

  ($bkg_nor1 *= 1000) if (abs($bkg_nor1) < 1);
  my $nor1 = ($bkg_nor1  <= 0) ? $last + $bkg_nor1 : $bkg_nor1;

  ($bkg_nor2 *= 1000) if (abs($bkg_nor2) < 5);
  my $nor2 = ($bkg_nor2  <= 0) ? $last + $bkg_nor2 : $bkg_nor2;

  ($nor1, $nor2) = sort {$a <=> $b} ($nor1, $nor2);

  $self->bkg_nor1(sprintf("%.3f",$nor1));
  $self->bkg_nor2(sprintf("%.3f",$nor2));
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

  $self->bkg_spl1(sprintf("%.3f",$spl1));
  $self->bkg_spl2(sprintf("%.3f",$spl2));
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

  $self->fft_kmin(sprintf("%.3f",$kmin));
  $self->fft_kmax(sprintf("%.3f",$kmax));
};

sub resolve_krange_chi {
  my ($self, $rx) = @_;
  my @chi = @$rx;
  my ($last, $fft_kmin, $fft_kmax) = ($chi[-1]||0, $self->fft_kmin, $self->fft_kmax);

  my $kmin = ($fft_kmin  < 0) ? $last + $fft_kmin : $fft_kmin;
  my $kmax = ($fft_kmax  < 0) ? $last + $fft_kmax
           : ($fft_kmax == 0) ? $last
           :                    $fft_kmax;

  ($kmin, $kmax) = sort {$a <=> $b} ($kmin, $kmax);
  ($kmax = $last) if ($kmax > $last);

  $self->fft_kmin(sprintf("%.3f",$kmin));
  $self->fft_kmax(sprintf("%.3f",$kmax));
};

1;


=head1 NAME

Demeter::Data::Defaults - Resolve default parameter values

=head1 VERSION

This documentation refers to Demeter version 0.3.

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

Demeter's dependencies are in the F<Bundle/DemeterBundle.pm> file.

=head1 BUGS AND LIMITATIONS

Please report problems to Bruce Ravel (bravel AT bnl DOT gov)

Patches are welcome.

=head1 AUTHOR

Bruce Ravel (bravel AT bnl DOT gov)

L<http://cars9.uchicago.edu/~ravel/software/>

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2009 Bruce Ravel (bravel AT bnl DOT gov). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
