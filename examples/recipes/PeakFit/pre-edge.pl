#!/usr/bin/perl

use Demeter qw(:analysis :ui=screen :plotwith=gnuplot);

my $data = Demeter::Data->new(file        => 'tipb.305',
			      energy      => '$1',
			      numerator   => '$2',
			      denominator => '$3',
			      ln          =>  1,
			     );

my $peak = Demeter::PeakFit->new(data=>$data, xmin=>-15, xmax=>5, screen => 0);
$peak -> backend('ifeffit');

$data->set_mode(screen=>0);

my $ls = $peak -> add('atan', center=>4975.73, name=>'arctangent', fixcenter=>1);
$peak -> add('gaussian', center=>4969.55, name=>'Peak1', fixcenter=>1);
$peak -> add('lorentzian', center=>4966.23, name=>'Peak2', fixcenter=>1);
#$ls->fix1(0);

$peak -> fit;

print $peak -> report;
$peak -> plot('e');
$peak -> pause;
