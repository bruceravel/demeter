#!/usr/bin/perl

use Demeter qw(:plotwith=gnuplot :ui=screen);

my $data = Demeter::Data::Prj->new(file=>'abc.prj')->record(1);
$data -> set_mode(screen=>0);

## -------- import atoms.inp files and write feff.inp for AgBr
my @common = (file=>'AgBr.inp', rpath=>4.1);
my $atoms_br = Demeter::Atoms->new(@common);
mkdir 'Br' if (not -d 'Br');
open FBR, '>Br/agbr_feff.inp';
print FBR $atoms_br -> Write('feff');
close FBR;

## -------- Clone AgBr input file to make AgCl
my $atoms_cl = $atoms_br -> clone(name=>'AgCl');
my $popped = $atoms_cl -> pop_sites;
$popped   =~ s{Br}{Cl}g;
$atoms_cl -> push_sites($popped);
$atoms_cl -> is_populated(0);
mkdir 'Cl' if (not -d 'Cl');
open FCL, '>Cl/agcl_feff.inp';
print FCL $atoms_cl -> Write('feff');
close FCL;


## -------- run feff for each scatterer and grab the first path
my $feff_br = Demeter::Feff->new(file=>'Br/agbr_feff.inp', workspace => 'Br', screen=>0);
$feff_br -> potph -> pathfinder;
my @list = @{ $feff_br -> pathlist };
my $br_sp = $list[0];

my $feff_cl = Demeter::Feff->new(file=>'Cl/agcl_feff.inp', workspace => 'Cl', screen=>0);
$feff_cl -> potph -> pathfinder;
@list = @{ $feff_cl -> pathlist };
my $cl_sp = $list[0];


## -------- deltaR and ss for each scatterer, common s02 and E0, mixing parameter
my @gds = (Demeter::GDS->new(gds=>'guess', name=>'amp',   mathexp=>1),
	   Demeter::GDS->new(gds=>'set',   name=>'x',     mathexp=>0.5),
	   Demeter::GDS->new(gds=>'guess', name=>'enot',  mathexp=>0),

	   Demeter::GDS->new(gds=>'guess', name=>'dr_br', mathexp=>0),
	   Demeter::GDS->new(gds=>'guess', name=>'ss_br', mathexp=>0.003),

	   Demeter::GDS->new(gds=>'guess', name=>'dr_cl', mathexp=>0),
	   Demeter::GDS->new(gds=>'guess', name=>'ss_cl', mathexp=>0.003),
	  );

## -------- paths
my @paths = ();
push @paths, Demeter::Path->new(data   => $data,
				sp     => $br_sp,
				s02    => 'amp * x',
				e0     => 'enot',
				delr   => 'dr_br',
				sigma2 => 'ss_br',
			       );
push @paths, Demeter::Path->new(data   => $data,
				sp     => $cl_sp,
				s02    => 'amp * (1-x)',
				e0     => 'enot',
				delr   => 'dr_cl',
				sigma2 => 'ss_cl',
			       );

my $fit = Demeter::Fit -> new(data=>[$data], paths=>\@paths, gds=>\@gds);
$fit -> fit;
$data -> po -> set(kweight=>2, kmax=>18);
$fit -> interview;

#$data -> po -> start_plot;
#$data -> po -> set(plot_fit => 1, plot_win => 0, r_pl => 'm');
#$_ -> plot('r') foreach ($data, @paths);
#$data -> pause;

$fit -> po -> end_plot;
