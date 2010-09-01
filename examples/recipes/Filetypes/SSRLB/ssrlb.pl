#!/usr/bin/perl
use Demeter qw(:ui=screen :plotwith=gnuplot);

## Test the SSRLB plugin on a file from version 2.0 of the SSRL XAS Data Collector

my $obj   = Demeter::Plugins::SSRLB->new(file=>'IN_540_001.003');
($obj->is) ? print "recognized as SSRLB\n" : print "NOT recognized as SSRLB\n";
$obj->fix;

my $data = Demeter::Data->new(file=>$obj->fixed,
			      numerator => '$9+$10+$11+$12+$13+$14+$15+$16+$17+$18+$19+$20',
			      denominator => '$4',
			      ln => 0,
			      energy => '$1',
			      #bkg_flatten => 0,
			     );
$data -> set_mode(screen=>0);
$data -> po -> set(emin=>-200, emax=>600, e_norm=>0);
$data -> plot('e');
print $data->bkg_z, " ", uc $data->fft_edge, $/;
$data -> pause;
unlink $obj->fix;
