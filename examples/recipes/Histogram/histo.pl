#!/usr/bin/perl

use Demeter qw(:plotwith=gnuplot :ui=screen);
my $demeter = Demeter->new;

## -------- These commented out lines were used to generate a feff.inp
##          file from crystal data and then to calculate potentials with
##          Feff and to run Demeter's pathfinder

# my $atoms = Demeter::Atoms->new(file => "Au.inp");
# open my $F, ">Au_feff.inp";
# print $F $atoms->Write("feff6");
# close $F;

# my $feff = Demeter::Feff -> new(file => "Au_feff.inp");
# $feff->set(workspace=>"./", screen=>0,);

# $feff -> potph;         # use Feff to compute potnetials
# $feff -> pathfinder;    # use Demeter's pathfinder
# $feff->freeze("Au_feff.yaml");

## -------- Import the results of the Feff calculation

my $feff = Demeter::Feff->new(yaml=>'Au_feff.yaml');
my @list_of_paths = @{ $feff->pathlist };


## -------- Import the first scattering path object and use it
##          to populate a histogram defined by an external file.
##          Also define a VPath containing the entire first
##          shell of the histogram.
my $firstshell = $list_of_paths[0];

my ($rx, $ry) = $firstshell->histogram_from_file('RDFDAT 20K', 1, 2, 2.6, 3.0);
my @common = (sigma2 => 'sigsqr', e0 => 'enot',); # data=>$data);

my @paths = $firstshell -> make_histogram($rx, $ry, \@common);
my $vpath = Demeter::VPath->new(name=>'histo');
$vpath->include(@paths);


## -------- Import some data

my $prj  = Demeter::Data::Prj->new(file=>'Aunano.prj');
my $data = $prj -> record(1);
$data -> set(fft_kmin=>3,   fft_kmax=>15,
	     bft_rmin=>1.8, bft_rmax=>3,
	     fit_k1=>1,     fit_k2=>1,    fit_k3=>1,
	    );

## -------- Some parameters
my @gds = (
	   Data::GDS->new(gds=>'guess', name=>'amp',    mathexp=>1);
	   Data::GDS->new(gds=>'guess', name=>'enot',   mathexp=>0);
	   Data::GDS->new(gds=>'set',   name=>'alpha',  mathexp=>0);
	   Data::GDS->new(gds=>'set',   name=>'sigsqr', mathexp=>0);
	  );

## -------- Do the fit
my $fit = Demeter::Fit->new(gds=>\@gds, data=>[$data], paths=>\@paths);
$fit->fit;

$data->plot('rmr');

$data->pause(-1);
$data->po->cleantemp;
