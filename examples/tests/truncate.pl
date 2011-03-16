#!/usr/bin/perl

=for Explanation
 This example shows how to truncate points from the beginning or end
 of a spectrum.  One interesting thing demonstrated in this script is
 reinitializing a data group by resetting the file attribute.

=cut

=for Copyright
 .
 Copyright (c) 2006-2011 Bruce Ravel (bravel AT bnl DOT gov).
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

## set up a data object
my @attributes = (bkg_pre1   => -30,    bkg_pre2   => -150,
		  bkg_nor1   => 150,    bkg_nor2   => 1757.5,
		  bkg_spl1   => 0.5,    bkg_spl2   => 22,
		  fft_kmax   => 3,      fft_kmin   => 14,
		 );

my $d0 = Demeter::Data -> new(@attributes);
$d0 -> set(file=>"$where/data/fe.060", name=>'60K',
	   ln	       => 1,
	   energy      => q{$1},
	   numerator   => q{$2},
	   denominator => q{$3});

my $plot = $d0->po;
$plot->set_mode(screen=>0, repscreen=>0);
$plot->set(e_mu      => 1,    e_bkg     => 0,
	   e_norm    => 0,    e_der     => 0,
	   e_pre     => 0,    e_post    => 0,
	   e_i0      => 0,    e_signal  => 0,
	   e_markers => 1,
	   emin      => -100, emax      => 700,
	   space     => 'E',
	  );

print "plotting original data\n";
$d0 -> plot('E');

print "plotting data truncated before 7100\n";
$d0 -> Truncate('before', 7100);
$d0 -> plot('E');

print "sleeping for 3 seconds\n";
sleep 3;

$plot->start_plot;

print "plotting original data\n";
$d0 -> file("$where/data/fe.060",
	    ln		=> 1,
	    energy	=> q{$1},
	    numerator	=> q{$2},
	    denominator	=> q{$3}); # resetting file resets all
$d0 -> plot('E');		        # data processing chores!

print "plotting data truncated after 7500\n";
$d0 -> Truncate('after', 7500);
$d0 -> plot('E');

1;
