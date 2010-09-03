#!/usr/bin/perl

use Demeter qw(:ui=screen :plotwith=gnuplot);

my $data = Demeter::Data->new(file        => 'tipb.305',
			      energy      => '$1',
			      numerator   => '$2',
			      denominator => '$3',
			      ln          =>  1,
			     );

my $peak = Demeter::PeakFit->new(xmin=>-20, xmax=>3, screen => 1);

$peak -> data($data);

$data->set_mode(screen=>0);

$peak -> add('atan', center=>4976, name=>'arctangent');
$peak -> add('gaussian', center=>4966.2, name=>'Peak2');
$peak -> add('gaussian', center=>4969.4, name=>'Peak1');

$peak -> fit;
print $peak -> report;

$data -> po -> set(e_norm=>1, emin=>-20, emax=>30);
$_  -> plot('e') foreach ($data, $peak, @{$peak->lineshapes});
$peak -> pause;
