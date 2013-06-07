#!/usr/bin/perl

## This script demonstrates the use of the LogRatio object.  The data
## used here are iron foil at 60 and 300 K.  Iron foil is certainly an
## awkward material for this analysis given that the first peak in the
## data consists of two scattering shells.  But these data are handy...


use Demeter qw(:ui=screen :plotwith=gnuplot);
Demeter->set_mode(screen=>0);


my @common = (energy=>'$1', numerator=>'$2', denominator=>1, ln=>0);
my $standard = Demeter::Data->new(file=>'../../data/fe.060.xmu', name => 'Fe 60K',  @common);
my $data     = Demeter::Data->new(file=>'../../data/fe.300.xmu', name => 'Fe 300K', @common);

my $lrpd = Demeter::LogRatio->new(standard=>$standard, data=>$data);
$lrpd->fit;
print $lrpd->report;
$lrpd->plot_odd;
$lrpd->data->pause;
$lrpd->plot_even;
$lrpd->data->pause;
$lrpd->save("foo");
