#!/usr/bin/perl

## This example is of some CuS2 samples from ESRF ID24.  The standard
## is Cu foil measured at ESRF BM29.  This one works out pretty well.
##

use Demeter qw(:ui=screen :plotwith=gnuplot);
use File::Basename;

Demeter->set_mode(screen=>0);
my $stan = Demeter::Data->new(file=>'ESRF_ID24/cus2/cufoil_rt.txt', bkg_nor2=>1000,
			      energy=>'$1', numerator=>'$2', denominator=>1, ln=>0, is_kev=>1);
my $data = Demeter::Data::Pixel->new(file=>'ESRF_ID24/cus2/cu_08', bkg_nor2=>1000,
				     energy=>'$1', numerator=>'$2', denominator=>1, ln=>0);
$stan->po->set(e_norm=>1, emin=>-100, emax=>400, e_markers=>0, e_bkg=>0);

$data->standard($stan);
$data->guess;
printf "initial: offset = %.5f, linear = %.5f, quadratic = %.5g\n",
  $data->offset, $data->linear, $data->quadratic;
$data->pixel;
printf "fitted:  offset = %.5f, linear = %.5f, quadratic = %.5g\n",
  $data->offset, $data->linear, $data->quadratic;
print Ifeffit::get_scalar('pixel___xmin'), $/;
print Ifeffit::get_scalar('pixel___xmax'), $/;

my $new = $data->apply;
$new -> bkg_nor1(50);
#$new->po->e_der(1);
$_->plot('e') foreach ($stan, $new);
$stan->pause;

exit;
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
