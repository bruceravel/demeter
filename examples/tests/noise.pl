#!/usr/bin/perl -I/home/bruce/codes/demeter/lib

=for Explanation
 This is a simple example of using Demeter to add artificial noise to
 data.

=cut

=for Copyright
 .
 Copyright (c) 2006-2008 Bruce Ravel (bravel AT anl DOT gov).
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
$plot->set({emin=>-50, emax=>100, e_bkg=>0, e_norm=>0, e_markers=>1});
my $where = $ENV{DEMETER_TEST_DIR} || "..";


## set up two data objects
my %common_attributes = ();
### Reading and plotting 60K Fe foil data
my $d0 = Ifeffit::Demeter::Data -> new();
$d0 -> set(\%common_attributes);
$d0 -> set({file => "$where/data/fe.060.xmu", label => 'Fe 60K', 'y_offset' => 2});
$d0 -> plot('e');

### 2% noise and replotting data
my $d1 = $d0 -> clone;
$d1 -> set({label => "2% noise", 'y_offset' => 1});
$d1 -> noise({noise=>0.02, which=>'xmu'});
$d1 -> plot('e');

### 10% noise and replotting data
my $d2 = $d0 -> clone;
$d2 -> set({label => "10% noise", y_offset => 0});
$d2 -> noise({noise=>0.1, which=>'xmu'});
$d2 -> plot('e');

1;
