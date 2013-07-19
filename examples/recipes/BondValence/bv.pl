#!/usr/bin/perl

use Demeter qw(:ui=screen :p=gnuplot);
use Xray::BondValence qw(bvparams);
use Chemistry::Elements qw(get_name);
use File::Path;

my $el   = $ARGV[0] || 'Fe';
my $val  = $ARGV[1] || '2';
my $scat = $ARGV[2] || 'O';
#print join('|', Xray::BondValence::valences($el)), $/;

## import some iron oxide data from an Athena project file
my $prj = Demeter::Data::Prj->new(file=>'../QuickFirstShell/FeO.prj');
my $data = $prj->record(1);

## simply tell the FSPath object what the absorber/scattering pair is
## and how far apart they are.  the Feff object and a set of four GDS
## objects will be automatically generated.
## also need to specify a place to perform the Feff calculation
my $fspath = Demeter::FSPath->new(
				  abs       => 'Fe',
				  scat      => 'O',
				  distance  => 2.1,
				  workspace => './fs/',
				  data      => $data,
				 );

my $fit = Demeter::Fit->new(data=>[$data], gds=>$fspath->gds, paths=>[$fspath]);
$fit->fit;

$data->po->plot_fit(1);
$data->plot('rmr');
$data->pause;

## clean up the Feff calculation that was just made.
rmtree('./fs/');

print $fspath->R, $/;
print $fspath->s02_value/0.64, $/;
print $fspath->n, $/;

my %hash = bvparams($el, $val, $scat);
printf("%s%s+ with %s:  b=%s  r0=%s\n", $el, $val, get_name($scat), $hash{b}, $hash{r0});

## V_exp  = N * exp( (R_0 - R) /0.37)
my $vexp =  ($fspath->s02_value/0.64) * exp( ($hash{r0} - $fspath->R) / $hash{b} );
print $vexp, $/;
