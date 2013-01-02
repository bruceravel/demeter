#!/usr/bin/perl

use Demeter qw(:ui=screen plotwith:gnuplot :analysis);

my $prj = Demeter::Data::Prj->new(file=>'../../cyanobacteria.prj');
my $stan = $prj->record(4);
my @data = $prj->records(9, 11, 15);
my $lcf = Demeter::LCF->new(space=>'xmu', unity=>0, inclusive=>0, one_e0=>0,
			    plot_difference=>0, plot_components=>0, noise=>0);

$lcf->data($stan);
$lcf->add($data[$_], weight=>0.33) foreach (0..2);
$lcf->weight($data[0], 3);
#$lcf->set_mode(screen=>1);
$lcf->prep_arrays;
#$lcf->set_mode(screen=>0);

my $x = $lcf->ref_array('x');
my $y = $lcf->ref_array('lcf');
my $sum = $data[0]->put($x, $y, datatype=>'xmu', name=>'sum');
$sum->e0($data[0]);
$sum->resolve_defaults;


$data[0]->plot_multiplier(3);
Demeter->po->set(e_norm=>0, e_bkg=>0, emin=>-70, emax=>130);
$_ -> plot('E') foreach (@data, $sum);
$sum->pause;
$lcf->clean;
