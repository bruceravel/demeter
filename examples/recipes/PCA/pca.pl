#!/usr/bin/perl

use Demeter qw(:analysis :ui=screen :plotwith=gnuplot);

my $prj = Demeter::Data::Prj -> new(file=>'../../cyanobacteria.prj');
my $pca = Demeter::PCA->new(space=>'x', emin=>-20, emax=>80);


my @set = $prj->records(1..8);
#my @set = $prj->records(9,11,12,13,15);
$pca ->add(@set);

$pca->set_mode(screen=>0);
$pca->do_pca;

$ARGV[0] ||= 0;

my $data_index = $ARGV[0];
$pca->set_mode(screen=>0);
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
