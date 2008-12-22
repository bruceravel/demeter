#!/usr/bin/perl -I/home/bruce/codes/demeter/lib

=for Explanation
 This plots 60 and 300 K iron foil data in k- and R-space.

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

my @common_to_all_data_sets = (bkg_rbkg    => 1.5,
			       bkg_spl1    => 0,    bkg_spl2    => 18,
			       bkg_nor2    => 1800,
			       bkg_flatten => 1,
			       fft_kmax    => 3,    fft_kmin    => 17,
			      );
my @data = (Demeter::Data -> new(group => 'data0'),
	    Demeter::Data -> new(group => 'data1'),
	   );
foreach (@data) { $_ -> set(@common_to_all_data_sets) };
$data[0] -> set(file => "$where/data/fe.060.xmu", name => 'Fe 60K', 'y_offset' => 1, );
$data[1] -> set(file => "$where/data/fe.300.xmu", name => 'Fe 300K', );

my $plot = $data[0]->po;
$plot->set_mode(screen=>0, repscreen=>0);

## decide how to plot the data
$plot -> set(e_mu    => 1,
	     e_bkg   => 1,
	     e_norm  => 1,
	     e_pre   => 0,
	     e_post  => 0,
	     kweight => 2,
	     r_pl    => 'm',
	     'q_pl'  => 'r',
	    );

print "Plotting in k-space ...\n";
my $space = 'k';
foreach (@data) { $_ -> plot($space) };

print "Sleeping for 3 seconds ...\n";
sleep 3;

print "Plotting in R-space ...\n";
$plot -> start_plot;
$space = 'r';
foreach (@data) { $_ -> plot($space) };
print "All done!\n";

1;
