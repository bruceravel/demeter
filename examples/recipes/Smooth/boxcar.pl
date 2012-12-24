#!/usr/bin/perl

#use PDL;
use Demeter qw(:ui=screen :plotwith=gnuplot);

my $width = $ARGV[0] || 11;

my $data = Demeter::Data->new(file=>'examples/data/auo_noisy.xmu',
			      energy => '$1',
			      numerator => '$2',
			      denominator => 1,
			      ln => 0,
			     );

Demeter->po->set(emin=>-50, emax=>150, e_mu=>1, e_bkg=>0, e_norm=>0);
$data->plot('E');

#my @x = $data->get_array('energy');
#my @y = $data->get_array('xmu');

#my $pdl = PDL->new(\@y);
#my $sm = $pdl->conv1d(ones($width)/$width);
#my @z = $sm->list;

#my $smoothed = $data->put(\@x, \@z, datatype=>'xmu');
my $smoothed=$data->boxcar($width);

$smoothed->plot('E');

$data->pause;
