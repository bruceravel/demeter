#!/usr/bin/perl

use Demeter qw(:ui=screen :plotwith=gnuplot);

my $data = Demeter::Data->new(file        => 'fe73ga27.010',
			      energy      => '$1',
			      numerator   => '$3',
			      denominator => '$2',
			      ln          =>  0
			      );

$data->set_mode(screen=>1);
#my ($sadata, $text) = $data->sa_atoms("Fe72.74Ga27.26");
my ($sadata, $text) = $data->sa_booth("Fe72.74Ga27.26");

$data->plot('k');
$sadata->plot('k');
print $text;
$data->pause;
