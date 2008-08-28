#!/usr/bin/perl -I/home/bruce/codes/demeter/lib

=for Explanation
 This is a simple example of using Demeter to calibrate and align multiple
 data sets: 3 scans of iron foil at 60 K.

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
my %common_attributes = (energy      => '$1', # column 1 is energy
			 numerator   => '$2', # column 2 is I0
			 denominator => '$3', # column 3 is It
			 ln          => 1,    # these are transmission data
			 bkg_pre1    => -30,  bkg_pre2    => -150,
			 bkg_nor1    => 150,  bkg_nor2    => 1757.5,
			 bkg_spl1    => 0.5,  bkg_spl2    => 22,
			 fft_kmax    => 3,    fft_kmin    => 14,
			);
my $d0 = Ifeffit::Demeter::Data -> new({group => 'scan1'});
$d0 -> set(\%common_attributes);
$d0 -> set({file => "$where/data/fe.060", label => 'scan 1',});
my $d1 = Ifeffit::Demeter::Data -> new({group => 'scan2'});
$d1 -> set(\%common_attributes);
$d1 -> set({file => "$where/data/fe.061", label => 'scan 2',});
my $d2 = Ifeffit::Demeter::Data -> new({group => 'scan3'});
$d2 -> set(\%common_attributes);
$d2 -> set({file => "$where/data/fe.062", label => 'scan 3',});

### calibrating standard
$d0->calibrate;

### aligning and setting E0 values
$d0->align($d1, $d2);
$d1->e0($d0->get("bkg_e0"));
$d2->e0($d0->get("bkg_e0"));
my $merge = $d0->merge("N", $d1, $d2);

### plotting data + merge
foreach ($d0, $d1, $d2, $merge) {
  $_->plot('e');
};

1;
