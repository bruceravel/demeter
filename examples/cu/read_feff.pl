#!/usr/bin/perl -I/home/bruce/codes/demeter/lib

=for Copyright
 .
 Copyright (c) 2006-2008 Bruce Ravel (bravel AT bnl DOT gov).
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
use Demeter;

my $feff = Demeter::Feff -> new();
$feff->set({workspace=>"temp", screen=>1, buffer=>q{}, save=>1});
$feff -> rdinp("orig.inp") -> potph();
#print $feff->get("misc.dat");
