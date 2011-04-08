#!/usr/bin/perl

use Demeter qw(:ui=screen :plotwith=gnuplot);
use Demeter::Feff::Distributions;

use DateTime;


      my $start = DateTime->now( time_zone => 'floating' );

my $histogram = Demeter::Feff::Distributions->new( rmin=>1.5, rmax=>3.5, type=>'ss');
$histogram->backend('DL_POLY');
$histogram->file('HISTORY');

      my $lap = DateTime->now( time_zone => 'floating' );
      my $dur = $lap->subtract_datetime($start);
      printf("%d minutes, %d seconds\n", $dur->minutes, $dur->seconds);


$histogram->rebin;
$histogram->plot;
$histogram->pause;


my $atoms = Demeter::Atoms->new();
$atoms -> a(3.92);
$atoms -> space('f m 3 m');
$atoms -> push_sites( join("|", 'Pt',  0.0, 0.0, 0.0,   'Pt'  ) );
$atoms -> core('Pt');
$atoms -> set(rpath=>6, rmax=>9, rmax => 8);
my $feff = Demeter::Feff->new(workspace=>"feff/", screen=>0, atoms=>$atoms);
$feff->run;
$feff->freeze('feff/feff.yaml');
#$histogram->sp($feff->pathlist->[0]);
$histogram->feff($feff);

my $composite = $histogram->fpath;
$composite->plot('k');
print $composite->pdtext, $/;
$histogram->pause;
