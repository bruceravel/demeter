#!/usr/bin/perl

use Demeter qw(:fit :ui=screen :plotwith=gnuplot);
#use Demeter qw(:plotwith=gnuplot);
use Demeter::Feff::Distributions;

use DateTime;


my $prj = Demeter::Data::Prj->new(file=>"PtData.prj");
my $data = $prj->record(1);
$data->bft_rmin(1.6);
$data->fft_kmin(3);
$data->fft_kmax(16);
$data->po->rmax(8);
$data->po->kweight(1);
$data->po->space('k');


# my $atoms = Demeter::Atoms->new();
# $atoms -> a(3.92);
# $atoms -> space('f m 3 m');
# $atoms -> push_sites( join("|", 'Pt',  0.0, 0.0, 0.0,   'Pt'  ) );
# $atoms -> core('Pt');
# $atoms -> set(rpath=>6, rmax=>9, rmax => 8);
# my $feff = Demeter::Feff->new(workspace=>"feff/", screen=>0, atoms=>$atoms);
# $feff->run;
# $feff->freeze('feff/feff.yaml');
my $feff = Demeter::Feff->new(workspace=>"feff/", screen=>0);
$feff->yaml('feff/feff.yaml');

my $first    = Demeter::Path->new(data=>$data, feff=>$feff, sp=>$feff->pathlist->[0],  n=>1);
my $eighteen = Demeter::Path->new(data=>$data, feff=>$feff, sp=>$feff->pathlist->[17], n=>1);
#print $first -> intrpline, $/;
#print $eighteen -> intrpline, $/;
#$histogram->pause;


      my $start = DateTime->now( time_zone => 'floating' );

my $histogram = Demeter::Feff::Distributions->new( rmin=>1.5, rmax=>3.5, type=>'ss', feff=>$feff);
$histogram->backend('DL_POLY');
$histogram->file('HISTORY');

      my $lap = DateTime->now( time_zone => 'floating' );
      my $dur = $lap->subtract_datetime($start);
      printf("%d minutes, %d seconds\n", $dur->minutes, $dur->seconds);

#################################################
## plot the histogram
$histogram->rebin;
$histogram->plot;
$histogram->pause;



#################################################
## plot the composite spectrum along with data
my $composite = $histogram->fpath;
$data->po->start_plot;
#$data->plot;

$data->set_mode(screen=>0);
$first->plot;
$composite->plot;
print $composite->pdtext, $/;
$histogram->pause;


#################################################
## plot the composite rattle spectrum along with data
$data->set_mode(screen=>0);
$histogram->rattle(1);
my $rattle = $histogram->fpath;
$data->po->start_plot;
#$data->plot;
$eighteen->plot;
$rattle->plot;
$histogram->pause;
