#!/usr/bin/perl

=for Copyright
 .
 Copyright (c) 2006-2009 Bruce Ravel (bravel AT bnl DOT gov).
 All rights reserved.
 .
 This file is free software; you can redistribute it and/or
 modify it under the same terms as Perl itself. See  L<perlgpl>.
 .
 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut

use Demeter qw(:ui=screen :plotwith=gnuplot);

## -------- clean up in preparation of the next fit
unlink("hgfit.iff") if (-e "hgfit.iff");
unlink("hgfit.dpj") if (-e "hgfit.dpj");

## I like to have a dummy object around for things like set_mode and
## simpleGDS, although you can use any object for those purposes...
my $demeter = Demeter->new;
$demeter -> set_mode(screen  => 0, ifeffit => 1, file => ">hgfit.iff");
$demeter -> po -> set(kweight => 2, rmax => 6);


## -------- import data and set up the FT and fit parameters
my $prj = Demeter::Data::Prj -> new(file => 'HgDNA_data.prj');
my $data = $prj -> record(2);	# import 2nd record, which contains the Hg/DNA data
$data -> set(name       => 'Hg with DNA',
	     fft_kmin   => 2.0,    fft_kmax  => 8.8,
	     fit_space  => 'r',
	     fit_k1     => 1,      fit_k2    => 1,    fit_k3    => 1,
	     bft_rmin   => 1,      bft_rmax  => 3.1,
	     fit_do_bkg => 0,
	    );

## -------- create all the guess, set, def, and after parameters
my @gds = (
	   $demeter->simpleGDS("set angle1   = 115.9 * pi / 180"),
	   $demeter->simpleGDS("set angle2   = 116.6 * pi / 180"),
	   $demeter->simpleGDS("set b1       = 1.373"),
	   $demeter->simpleGDS("set b2       = 1.384"),
	   $demeter->simpleGDS("set m        = 1.43"), # crude scaling factor for MS paths

	   $demeter->simpleGDS("guess amp    = 1"),
	   $demeter->simpleGDS("guess enot   = 0"),

	   ## geometry for location equidistant from two 2NN atoms in a 6-member ring
	   $demeter->simpleGDS("set anot     = 2.04"),
	   $demeter->simpleGDS("guess deltaa = 0"),
	   $demeter->simpleGDS("def a        = anot + deltaa"),       # net Hg - N distance
	   $demeter->simpleGDS("def angle    = (angle1 + angle2)/2"), # average Hg-N-C angle
	   $demeter->simpleGDS("def b        = (b1+b2)/2"),           # average N-C distance

	   ## some fun trigonometry follows
	   $demeter->simpleGDS("def tanth    = (a + b) * tan(angle/2) / (a - b)"),
	   $demeter->simpleGDS("def theta    = atan(tanth)"),
	   $demeter->simpleGDS("def c        = (a-b) * cos(angle/2) / cos(theta)"),

	   ## the rest of my fitting parameters, all MS paths will be approximated in terms of these
	   $demeter->simpleGDS("guess dro    = 0"),
	   $demeter->simpleGDS("guess ssn    = 0.003"),
	   $demeter->simpleGDS("def   ssc    = m*ssn"),
	   $demeter->simpleGDS("guess sso    = 0.003"),

	   $demeter->simpleGDS("set   szs    = 0.82"),    # s02 determined from fit to HgO data
	   $demeter->simpleGDS("after cn     = amp/szs"), # compute coordination number for log file
	  );


## -------- run the feff calculation
my $feff = Demeter::Feff->new(file=>'15/withHg.inp', workspace=>'15');
$feff -> set(screen=>0, buffer=>q{}, save=>1);
$feff -> co -> set_default("pathfinder", "fs_angle", 25);
$feff -> potph;
$feff -> rmax(4.5);
$feff -> pathfinder;
## $feff -> freeze('15/feff.yaml');
## print $feff -> intrp, $/;


## -------- begin setting up paths
##          note that I am using the `find_path' method here as a
##          demonstration of how to use Demeter's semantic path
##          descriptions.  for instance, in the case of the first
##          path, I want to use "the SS path that is less than 3
##          angstroms and scatters from a nitrogen atom"
my @paths  = ();
my $index  = 0;
my @common = (parent => $feff, data => $data, s02 => "amp", e0 => "enot",);

my $p = $feff->find_path(lt=>3, tag=>['N']);	       ## find the nearest neighbor, N at a short distance
push @paths, Demeter::Path -> new(@common,
				  sp     => $p,
				  delr   => "deltaa",
				  sigma2 => "ssn",
				 );

$p = $feff->find_path(lt=>3, tag=>['C']);	       ## find the second neighbor C atoms in the pyrimidine ring
push @paths, Demeter::Path -> new(@common,
				  sp     => $p,
				  delr   => "c-reff",
				  sigma2 => "ssc",
				 );

$p = $feff->find_path(lt=>3.5, tag=>['O']);	       ## find the third neighbor O atoms dangling from the pyrimidine ring
push @paths, Demeter::Path -> new(@common,
				  sp     => $p,
				  delr   => "dro",
				  sigma2 => "sso",
				 );

$p = $feff->find_path(lt=>4, tag=>['C', 'N']);	       ## find the C-N triangle paths
push @paths, Demeter::Path -> new(@common,
				  sp     => $p,
				  delr   => "(c-2.924)/2 + deltaa/2",
				  sigma2 => "ssc+ssn",
				 );

$p = $feff->find_path(lt=>4, tag=>['N', 'C', 'N']);    ## find the N-C-N dog leg
push @paths, Demeter::Path -> new(@common,
				  sp     => $p,
				  delr   => "deltaa",
				  sigma2 => "ssn",
				 );

$p = $feff->find_path(lt=>4, tag=>['C', 'O']);	       ## find the C-O triangle
push @paths, Demeter::Path -> new(@common,
				  sp     => $p,
				  delr   => "(c-2.924)/2 + dro/2",
				  sigma2 => "ssc+sso",
				 );

$p = $feff->find_path(lt=>4.2, tag=>['N', 'O']);       ## find the N-O triangle
push @paths, Demeter::Path -> new(@common,
				  sp     => $p,
				  delr   => "deltaa/2 + dro/2",
				  sigma2 => "ssn+sso",
				 );

$p = $feff->find_path(lt=>4.2, tag=>['C', 'O', 'C']);  ## find the C-O-C dog leg
push @paths, Demeter::Path -> new(@common,
				  sp     => $p,
				  delr   => "deltaa/2 + dro/2",
				  sigma2 => "ssn+sso",
				 );

$p = $feff->find_path(lt=>4.2, tag=>['C', 'C']);       ## find the C-C triangle
push @paths, Demeter::Path -> new(@common,
				  sp     => $p,
				  delr   => "2*deltaa",
				  sigma2 => "4*ssn",
				 );

## -------- a Fit object is a collection of GDS, Data, and Path objects
my $fit = Demeter::Fit->new(
			    gds   => \@gds,
			    data  => [$data],
			    paths => \@paths,
			   );

## Up to this point in the script, Demeter does not significantly
## reduce the amount of typing you have to do to create a fitting
## model.  Parameters *have* to be defined, data processing parameters
## *have* to be set, paths *have* to be defined.  The benefit of
## Demeter is how easy everything else is after this point.
##
## Running the fit is trivial.  Plotting the data, paths, and fit is
## easy.  Logfiles, output files, project files -- all those things
## are easily created as well.  Another great feature of the fit
## object is that it performs a sequence of sanity check before
## starting the fit, effectively "spell-checking" your fitting model.

## -------- do interesting things with the Fit object
$fit -> fit;
$fit -> logfile("hgfit.log", "Hg at N15 on pyrimidine", q{});
$fit -> freeze(file=>"hgfit.dpj");
$data -> save("fit", "hgfit.fit");

## -------- simple, on-screen interaction with the fit results
$fit -> interview;

$fit -> finish;
