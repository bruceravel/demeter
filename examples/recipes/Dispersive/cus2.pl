#!/usr/bin/perl

## This example is of some CuS2 samples from ESRF ID24.  The standard
## is Cu foiul measured at ESRF BM29.  This one works out pretty well.
##

use Demeter qw(:ui=screen :plotwith=gnuplot);
use File::Basename;

my $stan = Demeter::Data->new(file=>'ESRF_ID24/cus2/cufoil_rt.txt', bkg_nor2=>1000);
$stan->set_mode(screen=>0);
my $data = Demeter::Data::Pixel->new(file=>'ESRF_ID24/cus2/cu_08', bkg_nor2=>1000);
$stan->po->set(e_norm=>1, emin=>-100, emax=>400, e_markers=>0);

$data->standard($stan);
$data->guess;
$data->pixel;

my $new = $data->apply;
$new -> bkg_nor1(50);
$_->plot('e') foreach ($stan, $new);
$stan->pause;

$stan->po->start_plot;
foreach my $i (1..10) {
  my $file = sprintf("ESRF_ID24/cus2/cus2_%2.2d", $i);
  next if (not -e $file);
  my $cus2 = Demeter::Data::Pixel->new(file=>$file, name=>basename($file));
  $new=$data->apply($cus2);
  $new->set(bkg_pre1 => -50, bkg_pre2 => -10,
	    bkg_nor1 =>  30, bkg_nor2 => 240);
  $new->plot('e');
};
$stan->pause;
