#!/usr/bin/perl -I/home/bruce/codes/demeter/lib

use warnings;
use strict;
#use Smart::Comments;

use Ifeffit::Demeter;
use Xray::Site;
use Xray::Cell;

my $config = Ifeffit::Demeter->config;
#$config->set_default("atoms", "precision", "7.3f");

my $atoms = Ifeffit::Demeter::Atoms->new();
#$atoms->set({ipot_style=>'tags'});

my $which = "absorption";  # absorption feff6 atoms feff8 spacegroup
print $atoms -> read_inp($ARGV[0]||"ybco.inp") -> Write($which);
