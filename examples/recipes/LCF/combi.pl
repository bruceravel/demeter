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

use Demeter  qw(:ui=screen :plotwith=gnuplot);

my $prj = Demeter::Data::Prj -> new(file=>'../../cyanobacteria.prj');
my $lcf = Demeter::LCF -> new(space=>'nor', unity=>1, inclusive=>0,
			      plot_difference=>1, plot_components=>0);

$prj -> set_mode('screen' => 0);

my $data     = $prj->record(4);
my @standards = $prj->records(10, 12..17);

$lcf->data($data);
my $metal = $prj->record(9);
$lcf->add($metal, required=>1);
$lcf->add($prj->record(11), required=>1);
$lcf->add_many(@standards);
$lcf->xmin($data->bkg_e0-20);
$lcf->xmax($data->bkg_e0+60);
$lcf->po->set(emin=>-30, emax=>80);

#print scalar($lcf->combi_size), $/;

$lcf->combi;
print "Best fit:\n";
print $lcf->report;
$lcf->plot_fit;
$lcf->combi_report('combinatorial.xls');
$lcf->pause;
