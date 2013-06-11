#!/usr/bin/perl

use Demeter qw(:analysis :ui=screen :plotwith=gnuplot);

# my $data = Demeter::Data->new(file        => 'tipb.305',
# 			      energy      => '$1',
# 			      numerator   => '$2',
# 			      denominator => '$3',
# 			      ln          =>  1,
# 			     );
my $prj  = Demeter::Data::Prj->new(file=>'tipb_copies.prj');
my @data = $prj->slurp;
#$_->bkg_fixstep(0) foreach @data;

my $peak = Demeter::PeakFit->new(data=>$data[0], xmin=>-15, xmax=>1, screen => 0, plot_components=>1);
$peak -> backend($ENV{DEMETER_BACKEND});

$peak->set_mode(screen=>0);

my $ls = $peak -> add('atan', center=>4975.73, name=>'arctangent', fixcenter=>1);
$peak -> add('gaussian', center=>4969.55, name=>'Peak1', fixcenter=>1);
$peak -> add('lorentzian', center=>4966.23, name=>'Peak2', fixcenter=>1);

$peak->sequence(@data);


#$peak -> fit(0);

print $peak -> report;
$peak -> plot('e');
$peak -> pause;
#$peak -> save('foo.dat');
