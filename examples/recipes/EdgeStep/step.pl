#!/usr/bin/perl

use Demeter qw(:data :ui=screen);
use Statistics::Descriptive;
my $stat = Statistics::Descriptive::Full->new();

my $med  = Demeter::Plugins::X23A2MED->new(file=>'cu_kmdg1.020');
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

$|=1;
$data->_update('background');
$stat -> add_data($data->bkg_step);
printf "%.3f: %.5f\n", $data -> bkg_nor1, $data->bkg_step;

my $start = $data->bkg_nor1;
my $emin = 0.5 * $data->bkg_nor1;
#my $emax = 1.5 * $data->bkg_nor1;
#my $span = $emax - $emin;
my $nstep = 5;
my $step = $emin / $nstep;
my $init = $data->bkg_nor1;

foreach my $i (1 .. $nstep) {
  $data -> bkg_nor1( $init - $i*$step );
  $data -> _update('background');
  $stat -> add_data($data->bkg_step);
  printf "%.3f: %.5f\n", $data -> bkg_nor1, $data->bkg_step;

  $data -> bkg_nor1( $init + $i*$step );
  $data -> _update('background');
  $stat -> add_data($data->bkg_step);
  printf "%.3f: %.5f\n", $data -> bkg_nor1, $data->bkg_step;
};
$data->bkg_nor1($start);
$data->_update('background');
printf "edge step is %.5f +/- %.5f\n", $data->bkg_step, $stat -> standard_deviation;
