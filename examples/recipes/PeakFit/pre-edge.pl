#!/usr/bin/perl

use Demeter qw(:ui=screen :plotwith=gnuplot);

my $data = Demeter::Data->new(file        => 'tipb.305',
			      numerator   => '$2',
			      denominator => '$3',
			      energy      => '$1',
			      ln          =>  1,
			     );

my $peak = Demeter::PeakFit->new(xmax=>-3, screen => 1);

$peak -> data($data);

$data -> po -> set(e_norm=>1, emin=>-20, emax=>30);
$data -> plot('e');

$peak -> add('gaussian', center=>4969.8);
$peak -> add('gaussian', center=>4966.1);

$data -> pause;
#exit;

$peak -> fit;
