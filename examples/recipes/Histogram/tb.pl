#!/usr/bin/perl

use strict;
use warnings;
use Demeter qw(:ui=screen :plotwith=gnuplot);

# my $atoms = Demeter::Atoms->new(file=>'Pt.inp');
# my $feff  = Demeter::Feff->new(atoms=>$atoms, workspace=>'./feff');
# $feff->run;
# $feff->freeze('feff/feff.yaml');

my $feff = Demeter::Feff->new(workspace=>'./feff');
$feff->thaw('feff/feff.yaml');
$feff->screen(0);

my $tb = Demeter::ThreeBody->new(parent=>$feff, name=>'Pt 3 body', s02=>2);
$tb->set(r1=>2.639222692, r2=>2.639222692, beta=>0.694400000, ipot1=>1, ipot2=>1);

print $tb->pathsdat;
$tb->po->r_pl('m');
my $sp = 'r';
$tb->plot($sp);
$tb->vpath->plot($sp);
$tb->pause;
