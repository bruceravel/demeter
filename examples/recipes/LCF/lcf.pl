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

use Demeter qw(:ui=screen :plotwith=gnuplot);

my $prj = Demeter::Data::Prj -> new(file=>'../../cyanobacteria.prj');
my $lcf = Demeter::LCF -> new(space=>'nor', unity=>0, inclusive=>1, plot_difference=>1, plot_components=>1);

$prj -> set_mode('screen' => 0);

my $data     = $prj->record(4);
my ($metal, $chloride, $sulfide) = $prj->records(9, 11, 15);

$lcf->data($data);
$lcf->add_many($metal, $chloride, $sulfide);
#$lcf->add($metal);
#$lcf->add($chloride);
#$lcf->add($sulfide);

$lcf->xmin($data->bkg_e0-20);
$lcf->xmax($data->bkg_e0+60);
$lcf->po->set(emin=>-30, emax=>80);

my $n = 10;
$lcf->start_counter("Fitting $n times", $n);
foreach my $i (1 .. $n) {
  $lcf -> fit(1)
    -> plot
      -> save('foo.dat');
  #print $lcf->report;
  $lcf->clean;
  $lcf->count;
};
$lcf->stop_counter;

$lcf->pause;
