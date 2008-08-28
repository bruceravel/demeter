#!/usr/bin/perl -I/home/bruce/codes/demeter/lib

=for Explanation
 This is a simple example of using Demeter to import data, then serialize
 and deserialize it.

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
$plot->set({emin=>-200, emax=>1200, e_norm=>1, e_markers=>1});
my $where = $ENV{DEMETER_TEST_DIR} || "..";

### Reading, plotting fe.060
my $d0 = Ifeffit::Demeter::Data -> new({group => 'data0'});
$d0 -> set({file        => "$where/data/fe.060",
	    label       => '60K',
	    bkg_pre1    => -30,   bkg_pre2    => -150,
	    bkg_nor1    => 150,   bkg_nor2    => 1757.5,
	    bkg_spl1    => 0.5,   bkg_spl2    => 22,
	    fft_kmax    => 3,     fft_kmin    => 14,

	    energy	=> '$1', # column 1 is energy
	    numerator	=> '$2', # column 2 is I0
	    denominator	=> '$3', # column 3 is It
	    ln		=> 1,	 # these are transmission data
	   });
$d0->plot('k');
my $fname = "$d0.yaml";
### ... and serialize it to a yaml
$d0->freeze($fname);	# or freeze or Dump

### Deserializing from $fname and plotting it as a different object
my $d1 = Ifeffit::Demeter::Data->thaw($fname); # or thaw or Load
$d1->set({label=>"60K, deserialized", 'y_offset'=>-0.5});
### ... and plot it
$d1->plot("k");

1;
