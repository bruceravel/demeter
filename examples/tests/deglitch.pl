#!/usr/bin/perl -I/home/bruce/codes/demeter/lib

=for Explanation
 This example shows how to use Demeter to deglitch data.  Deglitching
 requires that, somehow, the point to be deglitched is known.  Demeter
 does not supply any methods specifically for finding the coordinates
 of a glitchy point -- that is left for the user interface.

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
my @attributes = (energy      => '$1', # column 1 is energy
		  numerator   => '$3', # column 3 is I0
		  denominator => '$4', # column 4 is It
		  ln          => 1,    # these are transmission data
		 );
print "Reading and plotting uhup.003\n";
my $d0 = Demeter::Data -> new(@attributes);
$d0 -> set(file=>"$where/data/uhup.003", name=>'HUP');

my $plot = $d0 -> po;
$plot->set_mode(screen=>0, repscreen=>0);
$plot->set(emin=>-200, emax=>800, e_norm=>1, e_markers=>1, kweight=>2);

$d0 -> plot('e');

print "Delitching points at 17385.686 and 17655.5 eV; replotting data\n";
$d0 -> name("HUP, deglitched");
$d0 -> deglitch(17385.686, 17655.5);
$d0 -> plot('e');

1;
