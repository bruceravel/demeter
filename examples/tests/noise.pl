#!/usr/bin/perl

=for Explanation
 This is a simple example of using Demeter to add artificial noise to
 data.

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
my $d0 = Demeter::Data -> new(file => "$where/data/fe.060.xmu",
			      name => 'Fe 60K',
			       energy=>'$1', numerator=>'$2', denominator=>1, ln=>0,
			      'y_offset' => 2);


my $plot = $d0->po;
$plot->set_mode(screen=>0, repscreen=>0);
$plot->set(emin=>-50, emax=>100, e_bkg=>0, e_norm=>0, e_markers=>1);

$d0 -> plot('e');

print "2% noise and replotting data\n";
my $d1 = $d0 -> clone(name => "2% noise", 'y_offset' => 1);
$d1 -> noise(noise=>0.02, which=>'xmu');
$d1 -> plot('e');

print "10% noise and replotting data\n";
my $d2 = $d0 -> clone(name => "10% noise", y_offset => 0);
$d2 -> noise(noise=>0.1, which=>'xmu');
$d2 -> plot('e');

$_->DEMOLISH foreach ($d0, $d1, $d2);

1;
