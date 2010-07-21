#!/usr/bin/perl

use Demeter qw(:ui=screen :plotwith=gnuplot);
use autodie qw(open close);

## -------- import the standard data as measured by a conventional XAS experiment
my $stan = Demeter::Data->new(file=>'PhotonFactory/Pd_foil_ref.txt');
$stan -> set(bkg_pre1=>-200, bkg_pre2=>-100);
$stan -> convolve(width=>1, type=>'gaussian');
$stan -> po -> e_norm(1);
$stan -> plot('e');
$stan -> pause;
$stan -> po -> start_plot;

## -------- slurp in the CSV file containing the standard data as measured by DXAS
my (@pixel, @xmu);
open(my $ST, '<', 'PhotonFactory/Pd_foil.CSV');
my $toss = <$ST>;		# first line is not data
while (<$ST>) {
  chomp;
  my ($pixel, $xmu) = split(/,/, $_);
  push @pixel, $pixel;
  push @xmu,   $xmu;
};
close $ST;
@xmu = reverse @xmu;		# PF DXAS data has high energy at pixel #1

## -------- make a Pixel object from the DXAS standard
my $data = Demeter::Data::Pixel->put(\@pixel, \@xmu);
$data -> set(bkg_pre1=>-410, bkg_pre2=>-120, bkg_nor1=>150, bkg_nor2=>600);
$data -> plot('e');
$data -> pause;
$data -> po -> start_plot;

## -------- assign the normal XAS data as the standard, make an
##          initial guess for the calibration parameters, then do the
##          fit
$data -> standard($stan);
$data -> guess;
print "INITIAL: ", $data->report;
$data -> pixel;
print "FITTED:  ", $data->report;

## -------- make a Data object from the calibrated data and plot it
##          with the normal XAS data
my $new = $data -> apply;
$new -> e0($data);
$new -> set(bkg_pre1=>-200, bkg_pre2=>-100);
$_ -> plot('e') foreach ($stan, $new);
$stan -> pause;

## -------- slurp in the CSV file containing the time-dependent DXAS data
##
##          note that the file is read line-by-line.  that is, an
##          array of pixel values is imported at each line and the
##          file representes an array of these arrays.  this 2D array
##          needs to be transposed into arrays of data at each time
##          point.  the "push @{$dxas[$i]}, $data[$i];" line does this.
open(my $DXAS, '<', 'PhotonFactory/PdZnO02_mt.CSV');
my $times = <$DXAS>;		# first line is times
chomp $times;
my @times = split(/\s*,\s*/, $times);
@pixel = ();
my @dxas = ();
$dxas[$_] = [] foreach (0..$#times);
while (<$DXAS>) {
  chomp;
  next if m{\A\s*\z};
  my @data = split(/\s*,\s*/, $_);
  push @pixel, $data[0];
  foreach my $i (1..$#data) {
    push @{$dxas[$i]}, $data[$i];
  };
};


## -------- apply the calibration parameters to several time points.
$data -> po -> e_norm(0);
$data -> po -> e_markers(0);
$data -> po -> start_plot;
foreach my $j (1..15, 20, 60, 100) {
  my @this = reverse @{$dxas[$j]};		# PF DXAS data has high energy at pixel #1
  my $pzo = Demeter::Data::Pixel->put(\@pixel, \@this, name=>"time = " . $times[$j]);
  my $pzo_cal = $data -> apply($pzo);
  $pzo_cal -> plot('e');
};
$data->pause;
