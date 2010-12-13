#!/usr/bin/perl

use Demeter qw(:ui=screen :plotwith=gnuplot);
use Demeter::ScatteringPath::Histogram::DL_POLY;

my $dlp = Demeter::ScatteringPath::Histogram::DL_POLY->new( rmax=>3.5, file=>'HISTORY',);
$dlp->rebin;
$dlp->plot;
$dlp->pause;

# $dlp->bin(0.02);
# $dlp->rebin;
# $dlp->plot;
# $dlp->pause;

my $atoms = Demeter::Atoms->new();
$atoms -> set(a=>3.92);
$atoms -> space('f m 3 m');
$atoms -> push_sites( join("|", 'Pt',  0.0, 0.0, 0.0,   'Pt'  ) );
$atoms -> core('Pt');
$atoms -> set(rpath=>5.2, rmax => 8);
my $feff = Demeter::Feff->new(workspace=>"feff/", screen=>0, atoms=>$atoms);
$feff->run;
$dlp->sp($feff->pathlist->[0]);

my $composite = $dlp->fpath;
$composite->plot('r');
$composite->pause;
$composite->freeze('pthisto.yaml');
