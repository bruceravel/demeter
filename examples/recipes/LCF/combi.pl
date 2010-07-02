#!/usr/bin/perl

use Demeter  qw(:ui=screen :plotwith=gnuplot);

my $prj = Demeter::Data::Prj -> new(file=>'../../cyanobacteria.prj');
my $lcf = Demeter::LCF -> new(space=>'nor', unity=>0, inclusive=>1, plot_difference=>0, plot_components=>0);

$prj -> set_mode('screen' => 0);

my $data     = $prj->record(4);
my @standards = $prj->records(10, 12..17);

$lcf->data($data);
$lcf->add($prj->record(9), required=>1);
$lcf->add($prj->record(11), required=>1);
$lcf->add_many(@standards);
$lcf->xmin($data->bkg_e0-20);
$lcf->xmax($data->bkg_e0+60);
$lcf->po->set(emin=>-30, emax=>80);

$lcf->combi;
$lcf->pause;
