#!/usr/bin/perl

use Demeter qw(:plotwith=gnuplot :ui=screen);

my $dobject = Demeter::Data -> new(group => 'data0');
$dobject -> set(file        => "../../data/fe.060",
		fft_kmax    => 3,    fft_kmin  => 14,
		bkg_spl2    => 18,
		bkg_nor2    => 1800,
		energy      => '$1',
		numerator   => '$2',
		denominator => '$3',
		ln          => 1,
	       );

$dobject -> po -> kweight(2);
$dobject -> standard;
print "Plot in E, indicator set in k\n";
$dobject -> plot('e');

my $indic  = Demeter::Plot::Indicator->new(space=>'k', x=>5,);
$indic->plot;

$dobject->pause;

print "Plot in k, indicator set in k\n";
$dobject->po->start_plot;
$dobject->plot('k');
$indic->plot;

$dobject->pause;

print "Plot in E, indicator set in E\n";
$indic->space('E');
$indic->x(70);
$dobject->po->start_plot;
$dobject->plot('E');
$indic->plot;

$dobject->pause;

print "Plot in k, indicator set in E\n";
$dobject->po->start_plot;
$dobject->plot('k');
$indic->plot;

$dobject->pause;

print "Plot in R, indicator set in E does not plot\n";
$dobject->po->start_plot;
$dobject->plot('R');
$indic->plot;

$dobject->pause;

print "Plot in q, indicator set in E\n";
$dobject->po->start_plot;
$dobject->plot('q');
$indic->plot;

$dobject->pause;

print "Plot in R, indicator set in R\n";
$indic->space('R');
$indic->x(2.6);
$dobject->po->start_plot;
$dobject->plot('R');
$indic->plot;

$dobject->pause;

