#!/usr/bin/perl

use Demeter qw(:data :ui=screen :p=gnuplot);
use Xray::BondValence qw(bvparams bvdescribe);
use Chemistry::Elements qw(get_name);
use File::Path;

my $el   = $ARGV[0] || 'Au';
my $val  = $ARGV[1] || '3';
my $scat = $ARGV[2] || 'Cl';
#print join('|', Xray::BondValence::valences($el)), $/;

## import some iron oxide data from an Athena project file
#my $prj = Demeter::Data::Prj->new(file=>'../QuickFirstShell/FeO.prj');
my $prj = Demeter::Data::Prj->new(file=>'../../cyanobacteria.prj');
my $data = $prj->record(11);
$data->bft_rmin(1.25);

## simply tell the FSPath object what the absorber/scattering pair is
## and how far apart they are.  the Feff object and a set of four GDS
## objects will be automatically generated.
## also need to specify a place to perform the Feff calculation
my $fspath = Demeter::FSPath->new(
				  abs       => 'Au',
				  scat      => 'Cl',
				  edge      => 'l3',
				  distance  => 2.1,
				  workspace => './fs/',
				  data      => $data,
				 );

my $fit = Demeter::Fit->new(data=>[$data], gds=>$fspath->gds, paths=>[$fspath]);
$fit->fit;

$data->po->plot_fit(1);
$data->po->kweight(2);
$data->plot('rmr');
$data->pause;

## clean up the Feff calculation that was just made.
rmtree('./fs/');

print "R=", $fspath->R;
print "\tS02=", $fspath->s02_value;
print "\tN=", $fspath->n, $/;

$fspath->valence_abs(3);
print bvdescribe($fspath);

print $fspath->bv(0.661), $/;

Demeter->pjoin(Xray::BondValence::valences('Au'));
