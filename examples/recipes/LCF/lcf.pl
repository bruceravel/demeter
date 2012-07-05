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

use Demeter qw(:analysis :ui=screen :plotwith=gnuplot);

my $prj = Demeter::Data::Prj -> new(file=>'../../cyanobacteria.prj');
my $lcf = Demeter::LCF -> new(space=>'nor', unity=>1, inclusive=>0, one_e0=>0,
			      plot_difference=>1, plot_components=>1, noise=>0);

$prj -> set_mode('screen' => 0);

my $data = $prj->record(3);
my ($metal, $chloride, $sulfide) = $prj->records(9, 11, 15);

$lcf->data($data);
$lcf->add_many($metal, $chloride, $sulfide);
#$lcf->add($metal);
#$lcf->add($chloride);
#$lcf->add($sulfide);

if ($lcf->space eq 'chi') {
  $lcf->xmin(3);
  $lcf->xmax(12);
  $lcf->po->kmax(14);
} else {
  $lcf->xmin($data->bkg_e0-20);
  $lcf->xmax($data->bkg_e0+60);
  $lcf->po->set(emin=>-30, emax=>80);
};

$lcf -> fit
  -> plot_fit
  -> save('foo.dat');
print $lcf->report;
#$lcf->clean;

$lcf->pause;

## test plot method
# $lcf->po->start_plot;
# $lcf->po->set(e_norm=>0, e_der=>1);
# $_->plot('e') foreach ($data, $metal, $chloride, $sulfide, $lcf);

# $lcf->pause;
