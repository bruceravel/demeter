#!/usr/bin/perl

use Demeter qw(:fit :ui=screen :p=gnuplot);

my $prj = Demeter::Data::Prj->new(file=>'cu.prj');
my ($stan, $data) = $prj->slurp;

my @gds = (Demeter::GDS->new(name=>'amp',  gds=>'guess', mathexp=>'1'),
	   Demeter::GDS->new(name=>'enot', gds=>'set',   mathexp=>'0'),
	   Demeter::GDS->new(name=>'delr', gds=>'guess', mathexp=>'0'),
	   Demeter::GDS->new(name=>'ss',   gds=>'guess', mathexp=>'0.001'));

my $fpath = Demeter::FPath->new(source    => $stan,
				data      => $data,
				name      => "Cu filtered path",
				absorber  => 'Cu',
				scatterer => 'Cu',
				reff      => 2.5562,
				n         => 1,
				s02       => 1, #'amp',
				e0        => 0, #'enot',
				delr      => 0, #'delr',
				sigma2    => 0, #'ss',
			       );

my $sp = 'r';
$stan->plot($sp);
$data->plot($sp);
$fpath->plot($sp);
$stan->pause;




# my $fit = Demeter::Fit->new(gds   => \@gds,
# 			    data  => [$data],
# 			    paths => [$fpath]);
# $fit->fit;
# $data->po->set(plot_data => 1,
#                plot_fit  => 1,
#                plot_bkg  => 0,
#                plot_res  => 0,
#                plot_win  => 1,
#                plot_run  => 0,
#                kweight   => 2,
#                r_pl      => 'm',
#                'q_pl'    => 'r',
#               );
# $data->plot('r');
# print $fit->gds_report;
# $data->pause;
