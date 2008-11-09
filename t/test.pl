#!/usr/bin/perl -I/home/bruce/codes/demeter/lib

use warnings;
use strict;

use Demeter;
use Xray::Site;
use Xray::Cell;

my $config = Demeter->config;
#$config->set_default("atoms", "precision", "7.3f");

my $atoms = Demeter::Atoms->new();
#$atoms->set({ipot_style=>'tags'});

my $which = "absorption";  # absorption feff6 atoms feff8 spacegroup
print $atoms -> read_inp($ARGV[0]||"ybco.inp") -> Write($which);
