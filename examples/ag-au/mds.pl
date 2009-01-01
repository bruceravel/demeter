#!/usr/bin/perl -I/home/bruce/codes/demeter/lib/
##
##  this Demeter example makes extensive use of the clone method for
##  generating similar, repetitive Data and Path objects
##
##  This uses characteristic values to set the Ag:Au ratios for each
##  sample.  The use of a local guess to determine those ratios is
##  commented out.
##
##  Also, this example makes use of the simpleGDS method, which is a
##  bit of syntactic sugar used to make GDS objects.

=for Copyright
 .
 Copyright (c) 2006-2009 Bruce Ravel (bravel AT bnl DOT gov).
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

use Demeter qw(:ui=screen :plotwith=gnuplot);
$| = 1;

print "Multiple data set fit to several AgAu samples using Demeter $Demeter::VERSION\n";

unlink("ag-au.iff") if (-e "ag-au.iff");

## make a 2 Data objects and set the FT and fit parameters
my $data_100 = Demeter::Data -> new(group => 'ag100');
$data_100 -> set_mode(screen=>0, ifeffit=>1, file=>">ag-au.iff");


$data_100 -> set(file      => "ag.chi",
		 cv        => 1,
		 fft_kmin  => 2,   fft_kmax  => 11,
		 bft_rmax  => 3.2, bft_rmin  => 1.8,
		 fit_k1    => 1,   fit_k2    => 0,    fit_k3    => 1,
		 name      => 'pure silver data',
		);
my $data_80 = $data_100->clone(group => 'ag80',
			       cv    => 0.8,
			       file  => "20-80.chi",
			       name  => '80% silver',
			      );
my $data_60 = $data_100->clone(group => 'ag60',
			       cv    => 0.6,
			       file  => "40-60.chi",
			       name => '60% silver',
			      );
my $data_50 = $data_100->clone(group => 'ag50',
			       cv    => 0.5,
			       file  => "50-50.chi",
			       name => '50% silver',
			      );
my $data_40 = $data_100->clone(group => 'ag40',
			       cv    => 0.4,
			       file  => "60-40.chi",
			       name  => '40% silver',
			      );

## make GDS objects for an isotropic expansion, correlated Debye, mixed first
## shell fit to silver and silver/gold
my @gdsobjects =  ($data_100 -> simpleGDS("guess amp   = 1"),
		   $data_100 -> simpleGDS("guess enot  = 0"),
		   $data_100 -> simpleGDS("guess dr_ag = 0"),
		   $data_100 -> simpleGDS("guess ss_ag = 0.003"),
		   $data_100 -> simpleGDS("guess dr_au = 0"),
		   $data_100 -> simpleGDS("guess ss_au = 0.003"),
		   ## Determine Ag::Au ratios with an lguess
		   ## $data_100 -> simpleGDS("lguess frac = 0.6"),
		  );

my @paths = ();
$paths[0] = Demeter::Path -> new();
$paths[0]->set(data     => $data_100,
	       folder   => 'feff_ag/',
	       file     => "feff0001.dat",
	       name     => "silver",
	       s02      => 'amp',
	       e0       => 'enot',
	       delr     => 'dr_ag',
	       sigma2   => 'ss_ag',
	      );
## correctly map paths to data sets
my %map = (2=>$data_80, 4=>$data_60, 6=>$data_50, 8=>$data_40);
my %percentage = (2=>'80', 4=>'60', 6=>'50', 8=>'40');
foreach my $i (2,4,6,8) {
  my $j = $i-1;
  $paths[$j] = $paths[0]->clone(data  => $map{$i},
				name  => "silver",
				#s02  => "amp*frac",   # lguess
				s02   => "amp*[cv]",   # char. value
			       );
};
foreach my $i (2,4,6,8) {
  my $j = $i-1;
  my $k = $i+1;
  $paths[$i] = $paths[$j]->clone(folder  => 'feff_au/',
				 name	 => "gold",
				 #s02	 => "amp*(1-frac)", # lguess
				 s02	 => "amp*(1-[cv])", # char. value
				 delr	 => "dr_au",
				 sigma2  => "ss_au",
				);
};


## make a Fit object, which is just a collection of GDS, Data, and Path objects
my $fitobject = Demeter::Fit -> new;
$fitobject->set(gds   => \@gdsobjects,
		data  => [$data_100, $data_80, $data_60, $data_50, $data_40],
		paths => \@paths
	       );

## set nice legend parameters for the plot
$fitobject->po->legend(dy=>0.05, x=>0.8);

## do the fit
$fitobject -> fit;

## save the results of the fit
$data_100 -> save("fit", "ag_100.fit");
$data_80  -> save("fit", "ag_80.fit");
$data_60  -> save("fit", "ag_60.fit");
$data_50  -> save("fit", "ag_50.fit");
$data_40  -> save("fit", "ag_40.fit");

## write a log file
my ($header, $footer) = ("Corefinement of several silver/gold data sets\n", q{});
$fitobject -> logfile("ag-au.log", $header, $footer);

$fitobject -> interview;

$fitobject -> finish;
