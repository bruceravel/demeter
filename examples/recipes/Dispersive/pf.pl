#!/usr/bin/perl

## This example demonstrates how to use the Demeter::Data::Pixel
## object to convert Photon Factory DXAS data into a plot or a set of
## Athena project files.
##
## The thing that distinguishes this from the ESRF examples is that
## the data are contained in a big comma-separated value file.  The
## whole chunk from lines 70-85 slurps the data into perl data
## structures, which are then doled out to Demeter::Data::Pixel
## objects at line 95 (or 122).

use Demeter qw(:ui=screen :plotwith=gnuplot);
use Demeter::Data::Pixel;
use autodie qw(open close);
use Compress::Zlib;

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
my $line   = q{};
my $csv_fh = gzopen('PhotonFactory/PdZnO02_mt.CSV.gz', "rb") or die "could not open PhotonFactory/PdZnO02_mt.CSV.gz as a zipped CSV file\n";
$csv_fh->gzreadline($line);		# first line contains times
my @times = split(/\s*,\s*/, $line);
@pixel = ();
my @dxas = ();
$dxas[$_] = [] foreach (0..$#times);
while ($csv_fh->gzreadline($line) > 0) {
  #chomp $line;
  next if ($line =~ m{\A\s*\z});
  my @data = split(/\s*,\s*/, $line);
  push @pixel, $data[0];
  foreach my $i (1..$#data) {
    push @{$dxas[$i]}, $data[$i];
  };
};


## -------- apply the calibration parameters to several time points and make a pretty picture
$data -> po -> set(e_norm=>1, e_markers=>0, emin=>-50, emax=>100);
$data -> co -> set_default("gnuplot", "keylocation", "bottom right");
$data -> po -> start_plot;
$data -> po -> title('time sequence');
foreach my $j (1..15, 20, 60, 100) {
  my @this = reverse @{$dxas[$j]};		# PF DXAS data has high energy at pixel #1
  my $pzo = Demeter::Data::Pixel->put(\@pixel, \@this, name=>"time = " . $times[$j]);
  my $pzo_cal = $data -> apply($pzo);
  $pzo_cal -> set(bkg_pre1=>-410, bkg_pre2=>-120, bkg_nor1=>150, bkg_nor2=>600);
  $pzo_cal -> plot('e');
  # undef $pzo;
};
$data->pause;

exit;

## -------- apply the calibration parameters to each time point and
##          write out Athena project files containing 30 data groups
##          each
$data->start_counter("Converting DXAS from each time point", $#dxas+1);
my $athena = sprintf("athena_%d.prj", 1);
my $maxgroups = 30;
my @list = ();
foreach my $j (1..$#dxas) {

  if ($j % $maxgroups == 0) {
    $list[0]->write_athena($athena, @list);
    $athena = sprintf("athena_%d.prj", $j/$maxgroups+1);
    @list = ();
  };

  my @this = reverse @{$dxas[$j]};		# PF DXAS data has high energy at pixel #1
  my $pzo = Demeter::Data::Pixel->put(\@pixel, \@this, name=>"time = " . $times[$j]||'?');
  my $pzo_cal = $data -> apply($pzo);
  $pzo_cal -> set(bkg_pre1=>-410, bkg_pre2=>-120, bkg_nor1=>150, bkg_nor2=>600);
  push @list, $pzo_cal;
  $data->count;
};
$list[0]->write_athena($athena, @list);
$data->stop_counter;
