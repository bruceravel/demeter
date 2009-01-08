#!/usr/bin/perl

=for Explanation
 This shows how to make mu(E) from a column data file containing data
 from a quick scan.  These data are rebinned onto a standard EXAFS
 grid.  The original and rebinned data are overplotted.

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
my @attributes = (file	      => "$where/data/uhup.101",
		  name	      => 'HUP',
		  fft_kmax    => 3, fft_kmin	=> 14,
		  ## how to interpret the file as data
		  energy      => '$1',    # column 1 is energy
		  numerator   => '$2', # column 2 is I0
		  denominator => '$3', # column 3 is It
		  ln	      => 1,	      # these are transmission data
		  bkg_kw      => 3,
		 );

my $d0 = Demeter::Data -> new(@attributes);
my $plot = $d0->po;
$plot->set_mode(screen=>0, repscreen=>0);
$plot->set(emin=>-200, emax=>800, e_norm=>1, e_markers=>1, kweight=>2);


print "reading data and plotting\n";
$d0->plot('k');

print "rebinning data and plotting\n";
my $rebinned = $d0->rebin;
$rebinned->plot('k');

$d0->screen_echo(1);
print "--> original data is ", $d0->group, "\n--> rebinned data is ", $rebinned->group, $/;
$d0->dispose("show " . $d0->group . ".energy " . $rebinned->group . ".energy");
$d0->screen_echo(0);

print "all done!\n";

1;
