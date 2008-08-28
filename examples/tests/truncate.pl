#!/usr/bin/perl -I/home/bruce/codes/demeter/lib

=for Explanation
 This example shows how to truncate points from the beginning or end
 of a spectrum.  One interesting thing demonstrated in this script is
 reinitializing a data group by resetting the file attribute.

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
$plot->set({emin=>-100, emax=>700, e_norm=>0, e_markers=>1});
my $where = $ENV{DEMETER_TEST_DIR} || "..";

## set up a data object
my %common_attributes = (bkg_pre1   => -30,    bkg_pre2   => -150,
			 bkg_nor1   => 150,    bkg_nor2   => 1757.5,
			 bkg_spl1   => 0.5,    bkg_spl2   => 22,
			 fft_kmax   => 3,      fft_kmin   => 14,
			);

my $d0 = Ifeffit::Demeter::Data -> new({group => 'data0'});
$d0 -> set(\%common_attributes);
$d0 -> set({file => "$where/data/fe.060.xmu", label => '60K',});
### plotting original data
$d0 -> plot('E');

### plotting data truncated before 7100
$d0 -> Truncate('before', 7100);
$d0 -> plot('E');

### sleeping for 3 seconds
sleep 3;

$plot->start_plot;

### plotting original data
$d0 -> set({file => "$where/data/fe.060.xmu",}); # resetting file resets all
$d0 -> plot('E');		                 # data processing chores!

### plotting data truncated after 7500
$d0 -> Truncate('after', 7500);
$d0 -> plot('E');

1;
