#!/usr/bin/perl

use Demeter qw(:analysis :ui=screen :plotwith=gnuplot);

my $prj = Demeter::Data::Prj -> new(file=>'../../cyanobacteria.prj');
my $pca = Demeter::PCA->new(space=>'x', emin=>-20, emax=>80);


my @set = $prj->records(1..8);
#my @set = $prj->records(9,11,12,13,15);
$pca ->add(@set);

$pca->interpolate_stack;
$pca->make_pdl;
$pca->do_pca;
print $pca->report;

my $target = $prj->record(9);
$pca->set_mode(screen=>0);
#$pca->tt($target);
#$pca->plot_tt($target);
#$pca->pause;
#exit;

my $data_index = 7;
$pca->set_mode(screen=>0);
my $save = $pca->prompt;
my $n = 0;
while ($n !~ m{q}) {
  $pca->prompt("How many components? ");
  $n = $pca->pause;
  exit if $n =~ m{q};
  $pca->reconstruct($n/1);
  $pca->plot_reconstruction($data_index);
};

$pca->plot_stack;
$pca->pause;
$pca->plot_components(0..7);
$pca->pause;
exit;


#my $save = $pca->prompt;
$pca->prompt("Plot log of scree? [y/n] ");
my $do_log = $pca->pause;
$pca->plot_scree($do_log =~ m{y});
$pca->prompt($save);
$pca->pause;
#$pca->plot_variance;
#$pca->pause;

#$pca->po->set(emin=>-50, emax=>100, e_norm=>1, e_bkg=>0);
#foreach my $s (@set) {
#  $s->plot('E');
#};
#$pca->pause;
