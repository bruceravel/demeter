#!/usr/bin/perl

use Demeter qw(:ui=screen :plotwith=gnuplot);

my $data = Demeter::Data->new(file        => 'tipb.305',
			      energy      => '$1',
			      numerator   => '$2',
			      denominator => '$3',
			      ln          =>  1,
			     );

my $peak = Demeter::PeakFit->new(xmin=>-15, xmax=>5, screen => 0);

$peak -> data($data);

$data->set_mode(screen=>0);

my $ls = $peak -> add('atan', center=>4976.5, name=>'arctangent');
$peak -> add('gaussian', center=>4969.5, name=>'Peak1');
$peak -> add('lorentzian', center=>4966, name=>'Peak2');
$ls->fix1(0);

$peak -> fit;
print $peak -> report;

$data -> po -> set(e_norm=>1, emin=>-20, emax=>30, plot_res=>0);
$_  -> plot('e') foreach ($data, $peak, @{$peak->lineshapes});
#$peak -> pause;
