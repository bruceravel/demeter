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

use Demeter qw(:ui=screen);
use Demeter::Feff::External;

use Package::Alias
  DD   => 'Demeter::Data',
  GDS  => 'Demeter::GDS',
  DFE  => 'Demeter::Feff::External',
  Path => 'Demeter::Path',
  Fit  => 'Demeter::Fit';

print "Sample fit to copper data using Demeter ", $Demeter::VERSION, $/;
unlink "cufit.iff" if (-e "cufit.iff");

print "make a Data object and set the FT and fit parameters\n";
my $data = DD -> new();

$data->set_mode(screen  => 0, backend => 1, file => ">cufit.iff", );
$data -> plot_with('gnuplot');    ## similar to the plotwith pragma

$data ->set(file       => "cu10k.chi",
	    fft_kmin   => 3,	       fft_kmax   => 14,
	    fit_k1     => 1,	       fit_k3     => 1,
	    bft_rmin   => 1.6,         bft_rmax   => 4.3,
	    fit_do_bkg => 0,
	    name       => 'My copper data',
	   );



print "make GDS objects for an isotropic expansion, correlated Debye model fit to copper\n";
my @gds =  (GDS -> new(gds => 'guess', name => 'alPha', mathexp => 0),
	    GDS -> new(gds => 'guess', name => 'amp',   mathexp => 1),
	    GDS -> new(gds => 'guess', name => 'Enot',  mathexp => 0),
	    GDS -> new(gds => 'guess', name => 'theta', mathexp => 500),
	    #GDS -> new(gds => 'guess', name => 'fred',  mathexp => 500),
	    GDS -> new(gds => 'set',   name => 'temP',  mathexp => 300),
	    GDS -> new(gds => 'set',   name => 'sigmm', mathexp => 0.00052),
	   );

print "import the Feff calculation that is already on disk\n";
my $feff = DFE -> new();
$feff   -> set(workspace=>"temp", screen=>0);
$feff   -> file('./orig.inp');
my @sp   = @{$feff->pathlist};

print "make Path objects for the first 5 paths in copper (3 shell fit)\n";
my @paths = ();
foreach my $i (0 .. 4) {
  my $j = $i+1;
  $paths[$i] = Path -> new();
  $paths[$i]->set(data     => $data,
		  sp       => $sp[$i],
		  s02      => 'amp',
		  e0       => 'enot',
		  delr     => 'Alpha*reff',
		  sigma2   => 'debye(temp, Theta) + sigmm',
		 );
};

print "make a Fit object, which is just a collection of GDS, Data, and Path objects\n";
my $fit = Fit -> new(gds   => \@gds,
		    data  => [$data],
		    paths => \@paths
		   );

print "do the fit (or the sum of paths)\n";
$fit -> fit;

$fit -> interview;
