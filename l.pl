#!/usr/bin/perl

use Demeter qw(:p=gnuplot :ui=screen :d=1);

Demeter->set_mode(template_process => 'larch', screen=>0);

#my $prj = Demeter::Data::Prj->new(file=>'/home/bruce/git/demeter/examples/cyanobacteria.prj');
#my $data = $prj->record(9);

# my $data = Demeter::Data->new(file	  => 'examples/data/fe.060',
# 			      ln	  =>  1,
# 			      energy	  => '$1',
# 			      numerator   => '$2',
# 			      denominator => '$3',
# 			);

Demeter->po->set(e_bkg=>1, e_pre=>0, e_post=>0, e_norm=>0, emin=>-150, emax=>800, kweight=>2);

# my $dat2 = Demeter::Data->new(file	  => 'examples/data/fe.061',
# 			      ln	  =>  1,
# 			      energy	  => '$1',
# 			      numerator   => '$2',
# 			      denominator => '$3',
# 			);
# my $dat3 = Demeter::Data->new(file        => 'examples/data/fe.062',
# 			      ln	  =>  1,
# 			      energy	  => '$1',
# 			      numerator   => '$2',
# 			      denominator => '$3',
# 			);

# $data->calibrate;
# $data->align($dat2, $dat3);
# my $merge = $data->merge('e', $dat2, $dat3);

# $_->plot('e') foreach ($data, $dat2, $dat3, $merge);

my $data = Demeter::Data->new(datatype => 'chi', file => 'examples/nonuniform.chi', fft_kmin=>3);


#$data->plot('e');
#$data->pause;
$data->po->start_plot;
$data->plot('k');
$data->pause;
$data->po->start_plot;
$data->plot('r');
$data->pause;
