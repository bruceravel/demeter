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
$data->po->kweight(2);
$data->po->kmax(18);
$data->po->space('k');


my $atoms = Demeter::Atoms->new(file=>'LaTiN3.inp');
my $feff  = Demeter::Feff->new(workspace=>"feff/", screen=>0, atoms=>$atoms);
$feff->run;
$feff->freeze('feff/feff.yaml');
my $first = Demeter::Path->new(data=>$data, feff=>$feff, sp=>$feff->pathlist->[0],  n=>6, sigma2=>0.005);

      my $start = DateTime->now( time_zone => 'floating' );

my $histogram = Demeter::Feff::Distributions->new(rmin=>1.5, rmax=>2.8, type=>'ss', feff=>$feff, bin=>0.01, ipot=>3,
						  name=>"Ti-N histogram in LaTiO2N",
						  use_periodicity=>1);
$histogram->backend('VASP');
$histogram->file('OUTCAR');

      my $lap = DateTime->now( time_zone => 'floating' );
      my $dur = $lap->subtract_datetime($start);
      printf("%d minutes, %d seconds\n", $dur->minutes, $dur->seconds);

#################################################
## plot the histogram
$histogram->rebin;
$histogram->plot;
print $histogram->Dump($histogram->lattice);
print $/, $histogram->info, $/;
$histogram->pause;

#################################################
## plot the composite spectrum along with data
my $composite = $histogram->fpath;
$composite->n(6);
$data->po->start_plot;
#$data->plot;

$data->set_mode(screen=>0);
$data->plot;
$first->plot;
$composite->plot;
print $composite->pdtext, $/;
$histogram->pause;
