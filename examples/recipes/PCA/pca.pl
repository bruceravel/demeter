#!/usr/bin/perl

use Demeter qw(:analysis :ui=screen :plotwith=gnuplot);

my $prj = Demeter::Data::Prj -> new(file=>'../../cyanobacteria.prj');
my $pca = Demeter::PCA->new(space=>'x', emin=>-30, emax=>70);


my @set = $prj->records(1..8);
$pca ->add(@set);

$pca->interpolate;
$pca->make_pdl;
$pca->do_pca;
$pca->set_mode(screen=>0);
$pca->plot_components(0..7);
$pca->pause;
$pca->plot_scree(0);
$pca->pause;
$pca->plot_variance;
$pca->pause;

#$pca->po->set(emin=>-50, emax=>100, e_norm=>1, e_bkg=>0);
#foreach my $s (@set) {
#  $s->plot('E');
#};
#$pca->pause;
