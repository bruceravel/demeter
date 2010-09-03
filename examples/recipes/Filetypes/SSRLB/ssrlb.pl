#!/usr/bin/perl
use Demeter qw(:ui=screen :plotwith=gnuplot);

## Test the SSRLB plugin on files from versions 2.0 and 1.1 of the SSRL XAS Data Collector

print "== Version 2.0 of the SSRL XAS Data Collector:\n";
my $ssrl   = Demeter::Plugins::SSRLB->new(file=>'IN_540_001.003');
($ssrl->is) ? print "recognized as SSRLB\n" : print "NOT recognized as SSRLB\n";
$ssrl->fix;


my $data = Demeter::Data->new(file        =>  $ssrl->fixed,
			      energy      => '$1',
			      numerator   => '$9+$10+$11+$12+$13+$14+$15+$16+$17+$18+$19+$20',
			      denominator => '$4',
			      ln          =>  0,
			     );
$data -> set_mode(screen=>0);
$data -> po -> set(emin=>-200, emax=>600, e_norm=>0);
$data -> plot('e');
print $data->bkg_z, " ", uc $data->fft_edge, $/;
$data -> pause;
unlink $ssrl->fix;

$data -> po -> start_plot;
print "== Version 1.1 of the SSRL XAS Data Collector:\n";
$ssrl   = Demeter::Plugins::SSRLB->new(file=>'../../../../t/filetypes/ssrlb.dat');
($ssrl->is) ? print "recognized as SSRLB\n" : print "NOT recognized as SSRLB\n";
$ssrl->fix;

$data = Demeter::Data->new(file=>$ssrl->fixed, $ssrl->suggest('transmission'), );
$data -> set_mode(screen=>0);
$data -> po -> set(emin=>-200, emax=>600, e_norm=>0);
$data -> plot('e');
print $data->bkg_z, " ", uc $data->fft_edge, $/;
$data -> pause;
unlink $ssrl->fix;
