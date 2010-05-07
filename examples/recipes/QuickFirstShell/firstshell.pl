#!/usr/bin/perl

##
## This recipe shows how to make a very simple, first shell only fit
## to some iron oxide data using the FSPath object.
##
## The advantage of the FSPath object is that you do not have to
## explicitly set up and manage a Feff object and its Feff
## calculation.  Becuase only the first scattering path will ever be
## used, the management of the Feff object is greatly simplified and
## happens entirely behind the scenes.
##
## You also do not need to explicitly define GDS parameters.  A set of
## four GDS parameters will be created with the FSPath object, one for
## each of S02, E0, DeltaR, and sigma^2.  They are given obvious names
## based on the symbols of the absorber and scatterer.
##

use Demeter qw(:ui=screen);
use File::Path;

## import some iron oxide data from an Athena project file
my $prj = Demeter::Data::Prj->new(file=>'FeO.prj');
my $data = $prj->record(1);
$data -> plot_with('gnuplot');

## simply tell the FSPath object what the absorber/scattering pair is
## and how far apart they are.  the Feff object and a set of four GDS
## objects will be automatically generated.
## also need to specify a place to perform the Feff calculation
my $fspath = Demeter::FSPath->new(
				  abs       => 'Fe',
				  scat      => 'O',
				  distance  => 2.1,
				  workspace => './fs/',
				  data      => $data,
				 );

#$fspath -> co -> set_default(qw(fspath coordination 4));

## define, perform, and examine a fit
## the FSPath gds method returns a reference to the list of
## auto-generated guess parameters
my $fit = Demeter::Fit->new(data=>[$data], gds=>$fspath->gds, paths=>[$fspath]);
$fit->fit;
$fit->po->kweight(2);
$fit->interview;

## clean up the Feff calculation that was just made.
rmtree('./fs/');
