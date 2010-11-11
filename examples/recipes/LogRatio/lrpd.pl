#!/usr/bin/perl

## This script demonstrates the use of the LogRatio object.  The data
## used here are iron foil at 60 and 300 K.  Iron foil is certainly an
## awkward material for this analysis given that the first peak in the
## data consists of two scattering shells.  But these data are handy...


use Demeter qw(:ui=screen :plotwith=gnuplot);

my $standard = Demeter::Data->new(file=>'../../data/fe.060.xmu', name => 'Fe 60K');
my $data     = Demeter::Data->new(file=>'../../data/fe.300.xmu', name => 'Fe 60K');

$standard ->set_mode(screen=>1);

my $lrpd = Demeter::LogRatio->new(standard=>$standard, data=>$data);
$lrpd->fit;
print $lrpd->report;
$lrpd->plot_odd;
$lrpd->data->pause;
$lrpd->save("foo");
