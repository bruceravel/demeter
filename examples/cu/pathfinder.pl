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
use aliased 'Ifeffit::Demeter::Feff';

my $feff = Feff -> new();
$feff->set({workspace=>"pf", screen=>1, buffer=>q{}, save=>1});

$feff -> rdinp("orig.inp") -> potentials();
$feff -> pathfinder; # sets pathlist attribute

my @list_of_paths = $feff->pathlist;
$feff->pathsdat();

### Freezing this cluster+pathlist to a YAML
$feff->freeze("feff.yaml");

### Run the pf2.pl script to do something with this pathlist
