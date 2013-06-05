#!/usr/bin/perl

## This script reproduces (in a somewhat simplified form) the LCF fit shown in
##    Mechanisms of Gold Bioaccumulation by Filamentous Cyanobacteria from Gold(III)−Chloride Complex
##    Maggy F. Lengke, Bruce Ravel, Michael E. Fleet, Gregory Wanger, Robert A. Gordon, and Gordon Southam
##    Environ. Sci. Technol., 2006, 40 (20), pp 6304–6309
##    doi:10.1021/es061040r
##
## This has long been one of the teaching examples I have used to
## demonstrate LCF in Athena, so it was a natural place to start in
## Demeter.
##
## The data are contained in an Athena project file that is one of the
## standard examples in the Demeter distro.

use Demeter qw(:ui=screen); # :plotwith=gnuplot);

my $prj = Demeter::Data::Prj -> new(file=>'../../cyanobacteria.prj');
my $lcf = Demeter::LCF -> new(space=>'nor', unity=>1, inclusive=>0, one_e0=>0,
			      plot_difference=>0, plot_components=>0, noise=>0);
$prj -> co -> set_default('lcf', 'plot_during', 1);
#$prj -> set_mode(template_process=>"larch", template_analysis=>"larch");

my @data = $prj->record(1..8);
my ($metal, $chloride, $sulfide) = $prj->records(9, 11, 15);

$lcf->data($data[0]);
$lcf->add_many($metal, $chloride, $sulfide);
#$lcf->add($metal);
#$lcf->add($chloride);
#$lcf->add($sulfide);

if ($lcf->space eq 'chi') {
  $lcf->xmin(3);
  $lcf->xmax(12);
  $lcf->po->kmax(14);
} else {
  $lcf->xmin($data[0]->bkg_e0-20);
  $lcf->xmax($data[0]->bkg_e0+60);
  $lcf->po->set(emin=>-30, emax=>80);
};

$lcf -> sequence(@data);

$lcf -> plot_fit;
#print $lcf->report;
#$lcf->sequence_report('seq.xls');
print $lcf->sequence_columns;
#print $lcf->serialization;
$lcf -> set_mode('screen' => 0);
$lcf->sequence_plot;

$lcf->pause;
