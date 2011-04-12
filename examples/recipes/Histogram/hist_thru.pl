#!/usr/bin/perl

use Demeter qw(:ui=screen :plotwith=gnuplot);
use Demeter::Feff::Distributions;
use DateTime;

my $prj = Demeter::Data::Prj->new(file=>"PtData.prj");
my $data = $prj->record(1);
$data->bft_rmin(1.6);
$data->fft_kmin(3);
$data->fft_kmax(16);
$data->po->rmax(8);
$data->po->kweight(2);


      my $start = DateTime->now( time_zone => 'floating' );

my $histogram = Demeter::Feff::Distributions->new( type=>'thru');
$histogram->set(rmin=>1.5, rmax=>3.5, skip=>20,);
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
my $leg3 = Demeter::Path->new(data=>$data, feff=>$feff, sp=>$feff->pathlist->[9],  n=>1);
my $leg4 = Demeter::Path->new(data=>$data, feff=>$feff, sp=>$feff->pathlist->[11], n=>1);
my $vpath = Demeter::VPath->new(data=>$data, name=>"metal 3-body");
$vpath->include($leg3, $leg4);

my $composite = $histogram->fpath;
$composite->data($data);
$composite->name("distorted 3-body");
$data->plot('r');
$vpath->plot('r');
$composite->plot('r');
print $composite->pdtext, $/;
$histogram->pause;
