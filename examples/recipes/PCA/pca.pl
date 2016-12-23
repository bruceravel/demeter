#!/usr/bin/perl

use Demeter qw(:data :ui=screen :plotwith=gnuplot);
use Demeter::PCA;
Demeter->set_mode(screen=>0);

my $prj = Demeter::Data::Prj -> new(file=>'../../cyanobacteria.prj');
my $pca = Demeter::PCA->new(space=>'x', emin=>-20, emax=>80);


my @set = $prj->records(1..8);
#my @set = $prj->records(9,11,12,13,15);
$pca ->add(@set);
my $target = $prj->record(9);


$pca->set_mode(screen=>0);
$pca->do_pca;

#print $pca->serialization;
#exit;

# my ($iv, $ic) = $pca->loadings->pca_sorti();
# print $iv, $/;
# print $ic, $/;

#my @idv = (0..7);
#foreach my $i (list $iv) {
#  print $idv[$i] . "\t" . $pca->loadings->($_,$ic)->flat . "\n";
#};
#exit;

$ARGV[0] ||= 0;

my $data_index = $ARGV[0];
$pca->ncompused(2);
#$pca->save_reconstruction("foo", $data_index);
$pca->tt($target,3);
#print $pca->tt_report($target,4);
$pca->plot_tt($target);
$pca->pause;
exit;

my $save = $pca->prompt;
my $n = 0;
while ($n !~ m{q}) {
  $pca->prompt("[s|c|r|l] or number of components? ");
  $n = $pca->pause;
  exit if $n =~ m{q};
  if ($n =~ m{s}) {
    $pca->plot_stack;
  } elsif ($n =~ m{c}) {
    $pca->plot_components;
  } elsif ($n =~ m{r}) {
    $pca->plot_scree(0);
  } elsif ($n =~ m{l}) {
    $pca->plot_scree(1);
  } else {
    $n ||= 1;
    $pca->reconstruct($n/1);
    $pca->plot_reconstruction($data_index);
  };
};

