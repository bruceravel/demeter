#!/usr/bin/perl

use Demeter qw(:ui=screen :plotwith=gnuplot);

my $xes = Demeter::XES->new(file=>'../XES/7725.11',
			    energy => 2, emission => 3,
			    e1 => 7610, e2 => 7624, e3 => 7664, e4 => 7690,
			   );

my $peak = Demeter::PeakFit->new(screen => 1, yaxis=> 'raw',);

$peak -> data($xes);

$peak -> add('linear', name=>'baseline');
$peak -> add('gaussian', center=>7649.5, name=>'peak 1');
$peak -> add('gaussian', center=>7647.7, name=>'peak 2');
my $ls = $peak -> add('lorentzian', center=>7636.8, name=>'peak 3');
$ls -> fix1(0);

$peak -> fit;
print $peak -> report;

$peak->po->plot_res(1);
$_  -> plot('raw') foreach ($xes, $peak, @{$peak->lineshapes});
$peak -> pause;
