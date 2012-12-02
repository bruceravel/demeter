#!/usr/bin/perl

use Demeter qw(:data :ui=screen);
use Statistics::Descriptive;
my $stat = Statistics::Descriptive::Full->new();

my $med  = Demeter::Plugins::X23A2MED->new(file=>'cudata.dat');
$med->fix;
my $data = Demeter::Data->new(file=>$med->fixed,
			      energy      => '$1',
			      numerator   => '$3+$4+$5+$6',
			      denominator => '$2',
			      ln          =>  0,
			      bkg_pre1    => -100,
			      bkg_pre2    => -30,
			      bkg_nor1    => 150,
			      bkg_nor2    => 541.215,
			      bkg_nnorm   => 3,
			     );
# my $med  = Demeter::Plugins::X23A2MED->new(file=>'brdata.dat');
# $med->fix;
# my $data = Demeter::Data->new(file=>$med->fixed,
# 			      energy      => '$1',
# 			      numerator   => '$3+$4+$5+$6',
# 			      denominator => '$2',
# 			      ln          =>  0,
# 			      bkg_pre1    => -100,
# 			      bkg_pre2    => -45,
# 			      #bkg_nor1    => 50,
# 			      bkg_nor1    => 102.751,
# 			      bkg_nor2    => 202,
# 			      bkg_nnorm   => 3,
# 			     );


my @bubbles = (Demeter->co->default('edgestep', 'pre1'),
	       Demeter->co->default('edgestep', 'pre2'),
	       Demeter->co->default('edgestep', 'nor1'),
	       Demeter->co->default('edgestep', 'nor2'),
	      );
#$bubbles[1] = 40;
my @save    = $data->get(qw(bkg_pre1 bkg_pre2 bkg_nor1 bkg_nor2));
my @params  = qw(bkg_pre1 bkg_pre2 bkg_nor1 bkg_nor2);
my $size    = 20; #Demeter->co->default('edgestep', 'samples');
my $margin  = Demeter->co->default('edgestep', 'margin');

$|=1;
$data->_update('background');
$stat -> add_data($data->bkg_step);
my $init = $data->bkg_step;
printf "initial: %.5f   %.5f\n", $data->bkg_step, $data->bkg_nc2;

$data->po->showlegend(0);
$data->po->set(e_bkg=>0, e_norm=>1, e_markers=>0, emin=>-100, emax=>250);
$data->start_counter("Sampling", $size);
foreach my $i (1 .. $size) {

  $data->count;
  foreach my $j (0 ..3) {
    my $p = $params[$j];
    $data->$p($save[$j] + rand(2*$bubbles[$j]) - $bubbles[$j]);
  };
  $data -> normalize;
  #printf "%.5f\n", $data->bkg_nc2;
  $data->plot('E');
  $stat -> add_data($data->bkg_step);
};
$data->stop_counter;

my $sd = $stat -> standard_deviation;
printf "edge step with outliers is %.5f +/- %.5f  (%d samples)\n", $stat->mean, $sd, $stat->count;

my @full = $stat->get_data;

my $final = 0;
my $m = 3.0;
my $unchanged = 0;
my $prev = 0;
while (abs($init - $final) > $sd/3) {

  my @list = ();
  foreach my $es (@full) {
    next if (abs($es-$init) > $m*$sd);
    push @list, $es;
  };
  $stat->clear;
  $stat->add_data(@list);

  $final = $stat->mean;
  $sd = $stat->standard_deviation;
  if ($prev == $final) {
    ++$unchanged;
  } else {
    $unchanged = 0;
  };
  $prev = $final;
  printf "edge step without outliers is %.5f +/- %.5f  (%d samples, margin = %.1f  %d)\n", $final, $sd, $stat->count, $m, $unchanged;
  $m -= 0.2;
  last if ($unchanged == 4);
  last if $m < 1.5;
}

printf "final edge step evaluation %.5f +/- %.5f\n", $final, $sd; #$stat->mean, $stat -> standard_deviation;
$data->pause;
