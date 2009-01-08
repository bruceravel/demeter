#!/usr/bin/perl

=for Explanation
  This is a simple example of using Demeter to convolute data by a
  Gaussian or a Lorentzian.  The convolve method does not take a
  negatve value -- that is, it does not deconvolve a spectrum.

=cut

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


use Demeter;
my $where = $ENV{DEMETER_TEST_DIR} || "..";


## set up two data objects
print "Reading and plotting 60K Fe foil data\n";
my $d0 = Demeter::Data -> new();
$d0 -> set(file=>"$where/data/fe.060.xmu", name=>'Fe 60K');


my $plot = $d0->po;
$plot->set_mode(screen=>0, repscreen=>0);
$plot->set(emin=>-50, emax=>100, e_norm=>0, e_markers=>1, e_bkg=>0);

$d0 -> plot('e');

print "Gaussian convolution and replotting data\n";
my $d1 = $d0 -> clone(name=>"2 eV, gaussian");
$d1 -> convolve(width=>2, type=>'gaussian');
$d1 -> plot('e');

print "Lorentzian convolution and replotting data\n";
my $d2 = $d0 -> clone(name=> "2 eV, lorentzian");
$d2 -> convolve(width=>2, type=>'lorentzian');
$d2 -> plot('e');

1;
