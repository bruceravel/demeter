#!/usr/bin/perl

use Demeter qw(:analysis :ui=screen :plotwith=gnuplot);

# my $data = Demeter::Data->new(file        => 'tipb.305',
# 			      energy      => '$1',
# 			      numerator   => '$2',
# 			      denominator => '$3',
# 			      ln          =>  1,
# 			     );
my $prj  = Demeter::Data::Prj->new(file=>'tipb.prj');
my $data = $prj->record(3);

$data->bkg_fixstep(0);

my $peak = Demeter::PeakFit->new(data=>$data, xmin=>-15, xmax=>1, screen => 0, plot_components=>1);
$peak -> backend($ENV{DEMETER_BACKEND}||'ifeffit');

$data->set_mode(screen=>0);

my $ls = $peak -> add('atan', center=>4975.73, name=>'arctangent', fixcenter=>1);
$peak -> add('gaussian', center=>4969.55, name=>'Peak1', fixcenter=>1);
$peak -> add('pvoigt', center=>4966.23, name=>'Peak2', fixcenter=>1);
#$ls->fix1(0);

$peak -> fit(0);

print $peak -> report;
$peak -> plot('e');
$peak -> pause;
$peak -> save('foo.dat');
