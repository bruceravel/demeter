#!/usr/bin/perl

use Demeter qw(:analysis :ui=screen :plotwith=gnuplot);

my $prj = Demeter::Data::Prj -> new(file=>'../../cyanobacteria.prj');
my $pca = Demeter::PCA->new(space=>'x', emin=>-20, emax=>80);


my @set = $prj->records(1..8);
#my @set = $prj->records(9,11,12,13,15);
$pca ->add(@set);

$pca->set_mode(screen=>0);
$pca->do_pca;

my $target = $prj->record(9);
$pca->tt($target);
$pca->plot_tt($target);

$pca->pause;
