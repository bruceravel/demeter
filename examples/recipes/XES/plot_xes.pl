#!/usr/bin/perl

use Demeter qw(:ui=screen :plotwith=gnuplot);

my $xes = Demeter::XES->new(file=>'7725.11',
			    energy => 2, emission => 3,
			    e1 => 7610, e2 => 7624, e3 => 7664, e4 => 7690,
			   );

$xes->po->e_bkg(1);
$xes -> plot('raw');
printf("peak position = %.3f   element = %s   line = %s\n",
       $xes->peak, $xes->z, $xes->line);
$xes->pause;

$xes->po->start_plot;
$xes -> plot('sub');
$xes->pause;

$xes->po->start_plot;
$xes -> plot('norm');
$xes->pause;

$xes->freeze('foo.yaml');

my $xes2 = Demeter::XES->new;
$xes2 -> thaw('foo.yaml');
$xes2 -> plot('norm');
$xes->pause;
