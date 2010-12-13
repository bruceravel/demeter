#!/usr/bin/perl

use Demeter qw(:ui=screen :plotwith=gnuplot);
use Demeter::ScatteringPath::Histogram::DL_POLY;

my $dlp = Demeter::ScatteringPath::Histogram::DL_POLY->new( rmax=>5.8, file=>'HISTORY',);
$dlp->rebin;
$dlp->plot;
$dlp->pause;

$dlp->bin(0.02);

$dlp->rebin;
$dlp->plot;
$dlp->pause;
