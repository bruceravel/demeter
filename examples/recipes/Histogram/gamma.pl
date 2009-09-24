#!/usr/bin/perl

use Demeter qw(:plotwith=gnuplot :ui=screen);
my $demeter = Demeter->new;
$demeter -> set_mode(screen=>0);

## -------- These commented out lines were used to generate a feff.inp
##          file from crystal data and then to calculate potentials with
##          Feff and to run Demeter's pathfinder

my $feff = Demeter::Feff -> new(file => "pbaq.inp");
$feff->set(workspace=>"./pbaq", screen=>0,);
$feff->make_workspace;

$feff -> potph;         # use Feff to compute potnetials
$feff -> pathfinder;    # use Demeter's pathfinder

my @list_of_paths = @{ $feff->pathlist };

my $data  = Demeter::Data::Prj->new(file=>'pbaq.prj') -> record(1);
$data -> set(bft_rmin=>1.2, bft_rmax=>2.8);
$data -> po -> kweight(2);
#$data -> plot('k');
#$data -> pause;

my $firstshell = $list_of_paths[0];

my ($rx, $ry, $rz) = $firstshell->histogram_gamma(1.8, 3.0, 0.1);
my $common = [e0 => 'enot', data=>$data];

my ($paths, $gamma_gds) = $firstshell -> make_gamma_histogram($rx, $ry, $rz, $common);
my $vpath = Demeter::VPath->new(name=>'gamma histogram');
$vpath->include(@$paths);

## -------- Some parameters
my @gds = (
	   Demeter::GDS->new(gds=>'guess', name=>'enot',   mathexp=>0),
	  );

## -------- Do the fit
my $fit = Demeter::Fit->new(gds=>[@gds, @$gamma_gds], data=>[$data], paths=>$paths);
$fit->fit;

$fit->interview;
$data->po->end_plot;



