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
use Demeter::Feff::External;

print "Sample fit to copper data using Demeter ", $Demeter::VERSION, $/;
unlink "cufit.iff" if (-e "cufit.iff");

print "make a Data object and set the FT and fit parameters\n";
my $data = Demeter::Data -> new();

$data->set_mode(screen  => 0, backend => 1); #, file => ">cufit.iff", );
$data -> plot_with('gnuplot');    ## similar to the :plotwith pragma

$data ->set(file       => "cu10k.chi",
	    fft_kmin   => 3,	       fft_kmax   => 14,
	    fit_k1     => 1,	       fit_k3     => 1,
	    bft_rmin   => 1.6,         bft_rmax   => 4.3,
	    fit_do_bkg => 0,
	    fit_space  => 'k',
	    name       => 'My copper data',
	   );


print "make GDS objects for an isotropic expansion, correlated Debye model fit to copper\n";
my @gds =  (Demeter::GDS -> new(gds => 'guess', name => 'alPha', mathexp => 0),
	    Demeter::GDS -> new(gds => 'guess', name => 'amp',   mathexp => 1),
	    Demeter::GDS -> new(gds => 'guess', name => 'Enot',  mathexp => 0),
	    Demeter::GDS -> new(gds => 'guess', name => 'theta', mathexp => 500),
	    #Demeter::GDS -> new(gds => 'guess', name => 'fred',  mathexp => 500),
	    Demeter::GDS -> new(gds => 'set',   name => 'temP',  mathexp => 10),
	    Demeter::GDS -> new(gds => 'set',   name => 'sigmm', mathexp => 0.00052),
	   );

print "import the Feff calculation that is already on disk\n";
my $feff = Demeter::Feff::External -> new();
$feff   -> set(workspace=>"temp", screen=>0);
$feff   -> file('./orig.inp');
my @sp   = @{$feff->pathlist};

print "make Path objects for the first 5 paths in copper (3 shell fit)\n";
my @paths = ();
foreach my $i (0 .. 4) {
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

# my $sum = $fit->sum;
# $data->plot('r');
# $sum->plot('r');
# $data->pause;
# exit;

print "do the fit (or the sum of paths)\n";
$fit -> fit;



## this file demonstrates several things that you might want to do
## after a fit.  to try them, comment out the ones you don't want to
## use and comment out the "exit" lines appropriately




##############################################################################################
## ======== post-fit option #1
##          make a plot in R then save a log file and some column data files
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
exit;

print "save the results of the fit\n";
my ($header, $footer) = ("Fit to copper data", q{});
$fit -> logfile("cufit.log", $header, $footer);
$data->save("fit", "cufit.fit");
$paths[0]->save("r", "path0.rsp");
$fit -> freeze(file=>"cufit.dpj");
exit;
##############################################################################################



##############################################################################################
## ======== post-fit option #2
##          run the fit interview for simple interactive plotting and examination of the fit
$fit -> interview;
exit;
##############################################################################################



##############################################################################################
## ======== post-fit option #3
##          make an interesting stacked plot and serialize the fit
print "set nice legend parameters for the plot\n";
$data->po->legend(dy=>0.05, x=>0.8);

print "plot the data + fit + paths\n";
my $space = 'r';
$data->po->set(plot_data => 1,
	       plot_fit  => 1,
	       plot_bkg  => 0,
	       plot_res  => 0,
	       plot_win  => 1,
	       plot_run  => 1,
	       kweight   => 2,
	       r_pl      => 'm',
	       'q_pl'    => 'r',
	      );

my $s = 0;  # stack the plot interestingly...
foreach my $obj ($data, @paths,) {
  $obj -> plot($space);
  $s -= 0.8;
  $data -> set('y_offset'=>$s);
};

print "save the results of the fit\n";
$data->save("fit", "cufit.fit");
$data->save("fit", "rmag.fit", 'rmag');
$data->save("fit", "rre.fit", 'rre');
$data->save("fit", "rim.fit", 'rim');
#$paths[0]->save("r", "path0.r");

print "write log and serialization files\n";
($header, $footer) = ("Fit to copper data", q{});
$fit -> logfile("cufit.log", $header, $footer);
$fit -> freeze(file=>"cufit.dpj");
##############################################################################################
