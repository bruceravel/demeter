#!/usr/bin/perl
use Demeter qw(:ui=screen :plotwith=gnuplot);
my $data = Demeter::Data->new(file=>'data/cu010k.dat', name=>'copper metal', datatype=>'xmu');
$data->set(fft_kmin=>3, fft_kmax=>16, bft_rmin=>1, bft_rmax=>3, bft_dr=>0);
$data->po->kweight(2);
my $fp = Demeter::FPath->new(absorber  => 'cOppEr',
			     scatterer => 'Cu',
			     reff      => 2.55266,
			     source    => $data,
			     n         => 1,
			     delr      => 0.0,
			     s02       => 1,
			    );


print $fp->absorber, "  ", $fp->abs_z, "  ", $fp->kmin, $/;

$fp->po->q_pl('r');
$data->po->kweight(2);
$data->plot('q');
$fp->plot('k');
$fp->plot('k');
$fp->pause;

$fp->freeze('fpath.yaml');

$fp->set_mode(screen=>0);
my $fp2 = Demeter::FPath->new;
$fp2->thaw('fpath.yaml');
$fp2->name('thawed');
$data->po->start_plot;
$data->plot('q');
$fp->plot('k');
$fp2->plot('k');
$fp2->pause;
