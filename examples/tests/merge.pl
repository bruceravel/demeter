#!/usr/bin/perl -I/home/bruce/codes/demeter/lib

=for Explanation
 This is a simple example of using Demeter to calibrate and align multiple
 data sets: 3 scans of iron foil at 60 K.

=cut

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

use warnings;
use strict;

use Demeter;
my $where = $ENV{DEMETER_TEST_DIR} || "..";


## set up two data objects
my @attributes = (energy      => '$1', # column 1 is energy
		  numerator   => '$2', # column 2 is I0
		  denominator => '$3', # column 3 is It
		  ln          => 1,    # these are transmission data
		  bkg_pre1    => -30,  bkg_pre2    => -150,
		  bkg_nor1    => 150,  bkg_nor2    => 1757.5,
		  bkg_spl1    => 0.5,  bkg_spl2    => 22,
		  fft_kmax    => 3,    fft_kmin    => 14,
		 );
my $d0 = Demeter::Data -> new(group => 'scan1', @attributes);
$d0 -> set(file=>"$where/data/fe.060", name=>'scan 1');

my $d1 = Demeter::Data -> new(group => 'scan2', @attributes);
$d1 -> set(file=>"$where/data/fe.061", name=>'scan 2');

my $d2 = Demeter::Data -> new(group => 'scan3', @attributes);
$d2 -> set(file=>"$where/data/fe.062", name=>'scan 3');

my $plot = $d0->po;
$plot->set_mode(screen=>0, repscreen=>0);
$plot->set(emin=>-30, emax=>70, e_norm=>1, e_markers=>1);

print "calibrating standard\n";
$d0->calibrate;

print "aligning and setting E0 values\n";
$d0->align($d1, $d2);
$d1->e0($d0->bkg_e0);
$d2->e0($d0->bkg_e0);
my $merge = $d0->merge("N", $d1, $d2);

print "plotting data + merge\n";
foreach ($d0, $d1, $d2, $merge) {
  $_->plot('e');
};

1;
