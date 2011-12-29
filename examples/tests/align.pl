#!/usr/bin/perl

=for Explanation
  This script uses Demeter to calibrate and align two data sets: iron
  foil at 60 and 300 K.

=cut

=for Copyright
 .
 Copyright (c) 2006-2012 Bruce Ravel (bravel AT bnl DOT gov).
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

use Demeter;
my $where = $ENV{DEMETER_TEST_DIR} || "..";

## set up two data objects
my @common_attributes = (bkg_pre1   => -31,    bkg_pre2   => -150,
			 bkg_nor1   => 150,    bkg_nor2   => 1757.5,
			 bkg_spl1   => 0.5,    bkg_spl2   => 22,
			 fft_kmax   => 3,      fft_kmin   => 14,
			);

my $d0 = Demeter::Data -> new();
$d0 -> set(@common_attributes);
$d0 -> set(file => "$where/data/fe.060.xmu", name => '60K',);
$d0 -> po -> e_zero(1);

my $d1 = Demeter::Data -> new();
$d1 -> set(@common_attributes);
$d1 -> set(file => "$where/data/fe.300.xmu", name => '300K',);

my $plot = $d0->po;
$plot->set_mode(screen=>0, repscreen=>0);
$plot->set(e_mu      => 1,    e_bkg     => 0,
	   e_norm    => 1,    e_der     => 0,
	   e_pre     => 0,    e_post    => 0,
	   e_i0      => 0,    e_signal  => 0,
	   e_markers => 1,
	   emin      => -30, emax      => 70,
	   space     => 'E',
	  );

print "plotting unaligned data\n";
foreach ($d0, $d1) {
  $_->plot('E');
};

print "sleeping 3 seconds\n";
sleep 3;

print "calibrating standard\n";
$d0->calibrate;

print "aligning\n";
$d0->align($d1);
$d1->e0($d0);

print "plotting aligned data\n";
$plot->start_plot;
foreach ($d0, $d1) {
  $_->plot('E');
};

1;
