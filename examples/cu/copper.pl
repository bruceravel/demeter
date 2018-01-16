#!/usr/bin/perl

=for Copyright
 .
 Copyright (c) 2006-2018 Bruce Ravel (http://bruceravel.github.io/home).
 All rights reserved.
 .
 This file is free software; you can redistribute it and/or
 modify it under the same terms as Perl itself. See The Perl
 Artistic License.
 .
 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut


use Demeter qw(:fit :ui=screen);
print "Sample fit to copper data using Demeter ", $Demeter::VERSION, $/;
unlink "cufit.iff" if (-e "cufit.iff");

print "make a Data object and set the FT and fit parameters\n";
my $data = Demeter::Data -> new();

$data->set_mode(screen  => 0, backend => 1, file => ">cufit.iff", );
$data -> plot_with('gnuplot');    ## similar to the plotwith pragma

$data ->set(file       => "cu10k.chi",
	    fft_kmin   => 3,	       fft_kmax   => 14,
	    fit_k1     => 1,	       fit_k2     => 0,     fit_k3     => 1,
	    bft_rmin   => 1.6,         bft_rmax   => 4.3,
	    fit_do_bkg => 0,
	    fit_space  => 'R',
	    name       => 'My copper data',
	   );


print "make GDS objects for an isotropic expansion, correlated Debye model fit to copper\n";
my @gds =  (Demeter::GDS -> new(gds => 'guess', name => 'alpha', mathexp => 0),
	    Demeter::GDS -> new(gds => 'guess', name => 'amp',   mathexp => 1),
	    Demeter::GDS -> new(gds => 'guess', name => 'enot',  mathexp => 0),
	    Demeter::GDS -> new(gds => 'guess', name => 'theta', mathexp => 500),
	    Demeter::GDS -> new(gds => 'set',   name => 'temp',  mathexp => 300),
	    Demeter::GDS -> new(gds => 'set',   name => 'sigmm', mathexp => 0.00052),
	   );

my $atoms = Demeter::Atoms->new(file=>'atoms.inp');
my $feff = Demeter::Feff -> new(atoms=>$atoms);
$feff   -> set(workspace=>"temp", screen=>0);
$feff   -> run;
my @sp   = @{$feff->pathlist};

#print $feff->intrp;

print "make Path objects for the first 5 paths in copper (3 shell fit)\n";
my @paths = ();
foreach my $i (0 .. 5) {
  my $j = $i+1;
  $paths[$i] = Demeter::Path -> new();
  $paths[$i]->set(data     => $data,
		  sp       => $sp[$i],
		  s02      => 'amp',
		  e0       => 'enot',
		  delr     => 'Alpha*reff',
		  sigma2   => 'debye(temp, Theta) + sigmm',
		 );
};

print "make a Fit object, which is just a collection of GDS, Data, and Path objects\n";
my $fit = Demeter::Fit -> new(name  => 'simple fcc model',
			      gds   => \@gds,
			      data  => [$data],
			      paths => \@paths
			     );

print "do the fit (or the sum of paths)\n";
$fit -> fit;

$data->po->set(plot_data => 1,
	       plot_fit  => 1,
	       plot_bkg  => 0,
	       plot_res  => 0,
	       plot_win  => 1,
	       plot_run  => 1,
	       kweight   => 2,
	       r_pl      => 'r',
	       'q_pl'    => 'r',
	      );
$data->plot('r');
$data->pause;

print "save the log file\n";
my ($header, $footer) = ("Fit to copper data", q{});
$fit -> logfile("copper.log", $header, $footer);
