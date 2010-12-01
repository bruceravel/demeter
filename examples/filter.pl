#!/usr/bin/perl
use Demeter qw(:ui=screen :plotwith=gnuplot);
my $data = Demeter::Data->new(file=>'examples/data/cu010k.dat', name=>'copper metal', datatype=>'xmu');
$data->set(fft_kmin=>3, fft_kmax=>16, bft_rmin=>1, bft_rmax=>3);
$data->po->kweight(1);
my $fp = Demeter::FPath->new(absorber  => 'cOppEr',
			     scatterer => 'Cu',
			     reff      => 2.55266,
			     data      => $data,
			     n         => 12,
			     delr      => 0.0,
			     s02       => 1.09,
			    );


print $fp->absorber, "  ", $fp->abs_z, "  ", $fp->kmin, $/;

$fp->set_mode(screen=>1);
$fp->po->q_pl('r');
$data->plot('q');
$fp->plot('q');
$fp->pause;
