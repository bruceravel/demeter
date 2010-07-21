#!/usr/bin/perl

## This example is of some GeTe samples from ESRF ID24.  The standard
## is an SbGeTe sample measured at ESRF BM29.  The sequence of data
## that need to be converted are, frankly, horrid -- seriously
## contaminated with Bragg peaks.
##
## This turns out to be a very tricky one -- the fitted result is very
## sensitive to the initial guess.  Using the guess method does not
## work so well.  Instead I use Giuliana's suggested parameters as the
## initial guess.

use Demeter qw(:ui=screen :plotwith=gnuplot);
use File::Basename;

my $stan = Demeter::Data->new(file=>'ESRF_ID24/gete/Ge4SbTe5_ref', bkg_nor2=>1000, bkg_kw=>3);
$stan->set_mode(screen=>0);
my $data = Demeter::Data::Pixel->new(file=>'ESRF_ID24/gete/reference5', bkg_nor2=>900, bkg_kw=>3,
				     quadratic=>8e-5);
$stan->po->set(e_norm=>1, emin=>-100, emax=>1200, e_post=>0, e_der=>0, e_smooth=>3);
$data->Truncate('after', 1200);

# $stan->plot('e');
# $stan->pause;
# $data->po->start_plot;
# $data->plot('e');
# exit;

$data->standard($stan);
#$data->guess;
$data->set(offset=>11013.8, linear=>0.5858, quadratic=>4.1e-5);
printf "initial: offset = %.5f, linear = %.5f, quadratic = %.5g\n",
  $data->offset, $data->linear, $data->quadratic;
$data->pixel;
printf "fitted:  offset = %.5f, linear = %.5f, quadratic = %.5g\n",
  $data->offset, $data->linear, $data->quadratic;

my $new = $data->apply;
$new -> set(bkg_nor1=>50, bkg_nor2=>400, bkg_spl2e=>400);
$_->plot('e') foreach ($stan, $new);
$stan->pause;
$stan->po->start_plot;
$_->plot('k') foreach ($stan, $new);
$stan->pause;

$stan->po->start_plot;
$stan->po->set(e_norm=>0);
foreach my $i (1..99) {
  my $file = sprintf("ESRF_ID24/gete/gete1_%2.2d", $i);
  next if (not -e $file);
  my $gete = Demeter::Data::Pixel->new(file=>$file, name=>basename($file));
  $new=$data->apply($gete);
  $new->set(bkg_pre1 => -50, bkg_pre2 => -15,
	    bkg_nor1 =>  150, bkg_nor2 => 280);
  $new->plot('e');
};
$stan->pause;
