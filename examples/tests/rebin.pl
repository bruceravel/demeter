#!/usr/bin/perl -I/home/bruce/codes/demeter/lib

=for Explanation
 This shows how to make mu(E) from a column data file containing data
 from a quick scan.  These data are rebinned onto a standard EXAFS
 grid.  The original and rebinned data are overplotted.

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
$plot->set({emin=>-200, emax=>800, e_norm=>1, e_markers=>1, kweight=>2});
my $where = $ENV{DEMETER_TEST_DIR} || "..";

my $d0 = Ifeffit::Demeter::Data -> new({group => 'data0'});
$d0 -> set({file	=> "$where/data/uhup.101",
	    label	=> 'HUP',
	    fft_kmax	=> 3, fft_kmin	=> 14,
	    ## how to interpret the file as data
	    energy	=> '$1', # column 1 is energy
	    numerator	=> '$2', # column 2 is I0
	    denominator	=> '$3', # column 3 is It
	    ln		=> 1,	 # these are transmission data
	   });
#$d0 -> set({file	=> "$where/data/uhup.101"});

### reading data and plotting
$d0->plot('k');

### rebinning data and plotting
my $rebinned = $d0->rebin({group=>"data0rb"});
$rebinned->plot('k');

$d0->screen_echo(1);
$d0->dispose("show $d0.energy $rebinned.energy");
$d0->screen_echo(0);

### all done!

1;
