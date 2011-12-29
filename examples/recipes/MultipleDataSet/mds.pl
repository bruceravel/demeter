#!/usr/bin/perl
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
 Copyright (c) 2006-2012 Bruce Ravel (bravel AT bnl DOT gov).
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

### -------- import five sets of Ag and Ag/Au data from an Athena project file
my $prj = Demeter::Data::Prj->new(file => 'AgAu_merged.prj');
$prj -> set_mode(screen=>0, ifeffit=>1);
my @common = (fft_kmin  => 2,   fft_kmax  => 11,
	      bft_rmax  => 3.2, bft_rmin  => 1.8,
	      fit_k1    => 1,   fit_k2    => 0,    fit_k3    => 1,);
my $data_100 = $prj->record(1);
$data_100 -> set(@common, cv => 1, name => 'pure silver');

my $data_80 = $prj->record(3);
$data_80 -> set(@common, cv => 0.8, name => '80% silver');

my $data_60 = $prj->record(5);
$data_60 -> set(@common, cv => 0.6, name => '60% silver');

my $data_50 = $prj->record(6);
$data_50 -> set(@common, cv => 0.5, name => '50% silver');

my $data_40 = $prj->record(7);
$data_40 -> set(@common, cv => 0.4, name => '40% silver');

## -------- make GDS objects for an isotropic expansion, correlated
##          Debye, mixed first shell fit to silver and silver/gold
my @gdsobjects =  ($data_100 -> simpleGDS("guess amp   = 1"),
		   $data_100 -> simpleGDS("guess enot  = 0"),
		   $data_100 -> simpleGDS("guess dr_ag = 0"),
		   $data_100 -> simpleGDS("guess ss_ag = 0.003"),
		   $data_100 -> simpleGDS("guess dr_au = 0"),
		   $data_100 -> simpleGDS("guess ss_au = 0.003"),
		   ## Determine Ag::Au ratios with an lguess
		   ## $data_100 -> simpleGDS("lguess frac = 0.6"),
		  );

## -------- import Ag crystal data and generate a feff.inp file
my $atoms = Demeter::Atoms->new(file => "Ag.inp");
open(my $FEFF, '>feff.inp');
print $FEFF $atoms->Write("feff6");
close $FEFF;

## -------- run Feff on pure silver
my $agfeff = Demeter::Feff -> new(file => "feff.inp");
$agfeff -> set(workspace=>"feff/", screen=>0,);
$agfeff -> make_workspace;
$agfeff -> run;
$agfeff -> freeze("feff/feff.yaml");

## -------- make a path object from the 1st shell of pure silver, use
##          this for the pure silver data
my @paths = ();
$paths[0] = Demeter::Path -> new();
$paths[0]->set(data     => $data_100,
	       parent   => $agfeff,
	       sp       => $agfeff->pathlist->[0],
	       name     => "silver",
	       n        => 12,
	       s02      => 'amp',
	       e0       => 'enot',
	       delr     => 'dr_ag',
	       sigma2   => 'ss_ag',
	      );

## -------- clone the Ag Feff calculation, add Au to the potentials
##          list, make an Au scatterer out of the first site after the
##          absorber
my $aufeff = $agfeff->clone;
$aufeff -> set(workspace=>"feffau/", screen=>0,);
$aufeff -> make_workspace;
$aufeff -> push_potentials([2, 79, 'Au']); ## add Au to the end of the potentials list
my @sites = @{ $aufeff->sites }; ## make the first atom after the
my @neighbor   = @{ $sites[1] }; ## absorber in the sites list an Au
@neighbor[3,4] = (2,'Au');       ## (this could be easier...)
$sites[1]      = \@neighbor;
$aufeff -> sites(\@sites);
$aufeff -> run;			## and continue
$aufeff -> freeze("feffau/feff.yaml");

## -------- clone the Path object several times, taking care to
##          correctly map paths to data sets
my %map = (2=>$data_80, 4=>$data_60, 6=>$data_50, 8=>$data_40);
my %percentage = (2=>'80', 4=>'60', 6=>'50', 8=>'40');
foreach my $i (2,4,6,8) {	# clone silver paths
  my $j = $i-1;
  $paths[$j] = $paths[0]->clone(data  => $map{$i},
				#s02  => "amp*frac",   # lguess
				s02   => "amp*[cv]",   # char. value
			       );
};
foreach my $i (2,4,6,8) {	# clone gold paths
  my $j = $i-1;
  $paths[$i] = $paths[$j]->clone(parent  => $aufeff,
				 sp      => $aufeff->find_path(tag=>['Au']),
				 name	 => "gold",
				 #s02	 => "amp*(1-frac)", # lguess
				 n       => 12,
				 s02	 => "amp*(1-[cv])", # char. value
				 delr	 => "dr_au",
				 sigma2  => "ss_au",
				);
};


## -------- make a Fit object, which is just a collection of GDS, Data, and Path objects
my $fitobject = Demeter::Fit -> new;
$fitobject->set(gds   => \@gdsobjects,
		data  => [$data_100, $data_80, $data_60, $data_50, $data_40],
		paths => \@paths
	       );

## do the fit
$fitobject -> fit;

## save the results of the fit
# $data_100 -> save("fit", "ag_100.fit");
# $data_80  -> save("fit", "ag_80.fit");
# $data_60  -> save("fit", "ag_60.fit");
# $data_50  -> save("fit", "ag_50.fit");
# $data_40  -> save("fit", "ag_40.fit");

## write a log file
my ($header, $footer) = ("Corefinement of several silver/gold data sets\n", q{});
$fitobject -> logfile("ag-au.log", $header, $footer);

$fitobject -> freeze(file=>'mds.dpj');
$fitobject -> interview;
