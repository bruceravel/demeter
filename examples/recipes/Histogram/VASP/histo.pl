#!/usr/bin/perl

use Demeter qw(:ui=screen :plotwith=gnuplot);
use Demeter::Feff::Distributions;

use DateTime;


my $prj = Demeter::Data::Prj->new(file=>"TiK.prj");
my $data = $prj->record(1);
$data->bft_rmin(1.6);
$data->fft_kmin(3);
$data->fft_kmax(11);
$data->po->rmax(8);
$data->po->kweight(1);
$data->po->space('k');


my $atoms = Demeter::Atoms->new(file=>'LaTiO3.inp');
my $feff = Demeter::Feff->new(workspace=>"feff/", screen=>0, atoms=>$atoms);
$feff->run;
$feff->freeze('feff/feff.yaml');

      my $start = DateTime->now( time_zone => 'floating' );

my $histogram = Demeter::Feff::Distributions->new( rmin=>1.5, rmax=>3.5, type=>'ss', feff=>$feff);
$histogram->backend('VASP');
$histogram->file('OUTCAR');

      my $lap = DateTime->now( time_zone => 'floating' );
      my $dur = $lap->subtract_datetime($start);
      printf("%d minutes, %d seconds\n", $dur->minutes, $dur->seconds);
print join("|", @{$histogram->atoms}), $/;
print join("|", @{$histogram->numbers}), $/;

exit;
#################################################
## plot the histogram
$histogram->rebin;
$histogram->plot;
$histogram->pause;
