#!/usr/bin/perl -I/home/bruce/codes/demeter/lib

=for Explanation
  This script uses Demeter to calibrate and align two data sets: iron
  foil at 60 and 300 K.

=cut

=for Copyright
 .
 Copyright (c) 2006-2007 Bruce Ravel (bravel AT anl DOT gov).
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

use warnings;
use strict;
use Smart::Comments;

use Ifeffit::Demeter;
my $plot = Ifeffit::Demeter->get_mode("plot");
$plot->set_mode({screen=>0, repscreen=>0});
$plot->set({emin=>-30, emax=>70, e_norm=>1, e_markers=>1});
my $where = $ENV{DEMETER_TEST_DIR} || "..";

## set up two data objects
my %common_attributes = (bkg_pre1   => -30,    bkg_pre2   => -150,
			 bkg_nor1   => 150,    bkg_nor2   => 1757.5,
			 bkg_spl1   => 0.5,    bkg_spl2   => 22,
			 fft_kmax   => 3,      fft_kmin   => 14,
			);

my $d0 = Ifeffit::Demeter::Data -> new({group => 'data0'});
$d0 -> set(\%common_attributes);
$d0 -> set({file => "$where/data/fe.060.xmu", label => '60K',});
my $d1 = Ifeffit::Demeter::Data -> new({group => 'data1'});
$d1 -> set(\%common_attributes);
$d1 -> set({file => "$where/data/fe.300.xmu", label => '300K',});

### plotting unaligned data
foreach ($d0, $d1) {
  $_->plot('E');
};

### sleeping 3 seconds
sleep 3;

### calibrating standard
$d0->calibrate;

### aligning
$d0->align($d1);
$d1->e0($d0);

### plotting aligned data
$plot->start_plot;
foreach ($d0, $d1) {
  $_->plot('E');
};

1;
