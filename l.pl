#!/usr/bin/perl

use Demeter qw(:plotwith=gnuplot :ui=screen);

Demeter->set_mode(template_process => 'larch', screen=>1);

my $prj = Demeter::Data::Prj->new(file=>'/home/bruce/git/demeter/examples/cyanobacteria.prj');
my $data = $prj->record(9);

# my $data = Demeter::Data->new(file	  => '/home/bruce/play/fe/fe.060',
# 			      ln	  =>  1,
# 			      energy	  => '$1',
# 			      numerator   => '$2',
# 			      denominator => '$3',
# 			);
# my $dat2 = Demeter::Data->new(file	  => '/home/bruce/play/fe/fe.061',
# 			      ln	  =>  1,
# 			      energy	  => '$1',
# 			      numerator   => '$2',
# 			      denominator => '$3',
# 			);
# my $dat3 = Demeter::Data->new(file        => '/home/bruce/play/fe/fe.062',
# 			      ln	  =>  1,
# 			      energy	  => '$1',
# 			      numerator   => '$2',
# 			      denominator => '$3',
# 			);

# $data->calibrate;
# $data->align($dat2, $dat3);
# my $merge = $data->merge('e', $dat2, $dat3);

# Demeter->po->set(e_bkg=>0, e_pre=>0, e_post=>0, e_norm=>0, emin=>-150, emax=>800);
# $_->plot('e') foreach ($data, $dat2, $dat3, $merge);

$data->plot('e');
$data->pause;
$data->po->start_plot;
$data->plot('k');
$data->pause;
