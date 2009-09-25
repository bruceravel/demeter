#!/usr/bin/perl

use Demeter qw(:plotwith=gnuplot :ui=screen);
my $demeter = Demeter->new;
$demeter -> set_mode(screen=>1);

## -------- These commented out lines were used to generate a feff.inp
##          file from crystal data and then to calculate potentials with
##          Feff and to run Demeter's pathfinder
# my $feff = Demeter::Feff -> new(file => "pbaq.inp");
# $feff->set(workspace=>"./pbaq", screen=>0,);
# $feff->make_workspace;
# $feff -> potph;         # use Feff to compute potnetials
# $feff -> pathfinder;    # use Demeter's pathfinder
# my @list_of_paths = @{ $feff->pathlist };
# my $firstshell = $list_of_paths[0];


my $data  = Demeter::Data::Prj->new(file=>'pbaq.prj') -> record(1);
$data -> set(bft_rmin=>1.2, bft_rmax=>2.5);
$data -> po -> kweight(2);
#$data -> plot('k');
#$data -> pause;


my $fspath = Demeter::FSPath->new(abs       => 'Pb',
				  scat      => 'O',
				  edge      => 'L3',
				  distance  => 2.5,
				  data      => $data,
				  workspace => "./pbaq",
				 );
$fspath -> unset_parameters;

#$fspath -> plot('r');
#print $fspath->reff, "  ", $fspath->fuzzy, $/;
#$data->pause;

#exit;

my ($rx, $ry, $rz) = $fspath -> sp -> histogram_gamma(1.8, 3.0, 0.03);
my $common = [e0 => 'enot', data=>$data];

my ($paths, $gamma_gds) = $fspath -> sp -> make_gamma_histogram($rx, $ry, $rz, $common);
my $vpath = Demeter::VPath->new(name=>'gamma histogram');
$vpath->include(@$paths);

## -------- Some parameters
my $e0 = Demeter::GDS->new(gds=>'guess', name=>'enot',   mathexp=>0);

## -------- Do the fit
my $fit = Demeter::Fit->new(gds=>[$e0, @$gamma_gds], data=>[$data], paths=>$paths);
$fit->fit;

$fit->interview;
$data->po->end_plot;



