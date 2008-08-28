#!/usr/bin/perl -I/home/bruce/codes/demeter/lib

=for Copyright
 .
 Copyright (c) 2006-2007 Bruce Ravel (bravel AT bnl DOT gov).
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
use Term::ANSIColor qw(:constants);
use aliased 'Ifeffit::Demeter::Feff';

Ifeffit::Demeter->set_mode({screen => 0,});

### Deserializing feff.yaml;
my $feff = Feff -> thaw("feff.yaml");
$feff->set({workspace=>"pf", screen=>0, buffer=>q{}});
$feff->po->legend({key_dy => 0.05, # set nice legend parameters for the plot
		   key_x  => 0.6});

#$feff->pathsdat(1,2,6,9); # the first four SS paths
my @list_of_paths = $feff->pathlist;

### miscdat: $feff->get('misc.dat')

### Here are the 6 scattering geometries that contribute to path #2:
my $sp = $list_of_paths[1];
my $j=1000;
foreach my $s ($sp->all_strings) {
  print $sp -> pathsdat({index=>++$j, string=>$s, angles=>1});
};

#print $/, $feff->intrp('latex');
print $/, $feff->intrp({comment	=> BOLD.RED,
			close	=> RESET,
			1	=> YELLOW,
			2	=> BOLD.GREEN
		       });


### Plotting the first 6 paths
my @pobjects = ();
foreach my $i (0 .. 7) {
  my $j = $i+1;
  Ifeffit::Demeter::Path -> new()
      -> set({sp    => $list_of_paths[$i],
	      #label => "Path $j",
	      index => $j,
	     })
	-> plot('r')
	  -> rm;
};


$feff->pathsdat();

### All done!



