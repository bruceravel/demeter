#!/usr/bin/perl

=for Explanation
 This is a simple example of using Demeter to smooth noisy data using
 Ifeffit's three-point smoothing algorithm.  The smoothing method
 takes an integer argument to indicate how many times the smoothing
 should be repeated.

=cut

=for Copyright
 .
 Copyright (c) 2006-2015 Bruce Ravel (http://bruceravel.github.io/home).
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


print "Reading and plotting auo_noisy.xmu\n";
my $d0 = Demeter::Data -> new();
$d0 -> set(file=>"$where/data/auo_noisy.xmu", name=>'AuO, noisy');

my $plot = $d0->po;
$plot->set_mode(screen=>0, repscreen=>0);
$plot->set(emin=>-50, emax=>200, e_norm=>0, e_markers=>1, e_bkg=>0);

$d0 -> plot('e');

print "Smoothing once and replotting data\n";
my $d1 = $d0 -> Clone(name=>"AuO, smoothed 1 time");
$d1 -> smooth(1);
$d1 -> plot('e');

print "Smoothing 7 times and replotting data\n";
my $d2 = $d0 -> Clone(name=>"AuO, smoothed 7 times");
$d2 -> smooth(7);
$d2 -> plot('e');

1;
