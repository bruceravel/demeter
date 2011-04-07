#!/usr/bin/perl

use Demeter qw(:ui=screen :plotwith=gnuplot);
use Demeter::Feff::DL_POLY;

use DateTime;

my $prj = Demeter::Data::Prj->new(file=>"/home/bruce/PtData.prj");
unlink 'histo.iff' if (-e 'histo.iff');
$prj->set_mode(screen=>0, file=>'>histo.iff');
my $data = $prj->record(1);
$data->bft_rmin(1.6);
$data->fft_kmin(2);
$data->fft_kmax(12);
$data->po->rmax(8);

      my $start = DateTime->now( time_zone => 'floating' );
my $dlp = Demeter::Feff::DL_POLY->new( rmin=>1.5, rmax=>3.5, type=>'ss', file=>'HISTORY',);
#my $dlp = Demeter::ScatteringPath::Histogram::DL_POLY->new( r1=>1.5, r2=>3.5, r3=>5.2, r4=>5.7, type=>'ncl', skip=>20, file=>'HISTORY',);
      my $lap = DateTime->now( time_zone => 'floating' );
      my $dur = $lap->subtract_datetime($start);
      printf("%d minutes, %d seconds\n", $dur->minutes, $dur->seconds);

# open(my $twod, '>', 'twod');
# foreach my $p (@{$dlp->nearcl}) {
#   printf $twod "  %.9f  %.9f  %.9f  %.9f  %.15f\n", @$p;
# };
# close $twod;
#print $#{$dlp->nearcl}+1, $/;

#exit;

#print $dlp->npairs, $/;

$dlp->rebin;
$dlp->plot;
$dlp->pause;
#print $dlp->nconfig, $/;
#exit;

# open(my $bin2d, '>', 'bin2d');
# foreach my $p (@{$dlp->populations}) {
#   printf $bin2d "  %.9f  %.9f  %.9f  %.9f  %d\n", @$p;
# };
# close $bin2d;


# $dlp->bin(0.02);
# $dlp->rebin;
# $dlp->plot;
# $dlp->pause;

my $atoms = Demeter::Atoms->new();
$atoms -> a(3.92);
$atoms -> space('f m 3 m');
$atoms -> push_sites( join("|", 'Pt',  0.0, 0.0, 0.0,   'Pt'  ) );
$atoms -> core('Pt');
$atoms -> set(rpath=>6, rmax=>9, rmax => 8);
my $feff = Demeter::Feff->new(workspace=>"feff/", screen=>0, atoms=>$atoms);
$feff->run;
$feff->freeze('feff/feff.yaml');
#$dlp->sp($feff->pathlist->[0]);
$dlp->feff($feff);

my $composite = $dlp->fpath;
$composite->plot('k');
$dlp->pause;
exit;



my $pds = Demeter::Path->new(name   => 'DS',
			     parent => $feff,
			     data   => $data,
			     sp	    => $feff->pathlist->[10],
			     s02    => 1/12);
my $pts = Demeter::Path->new(name   => 'TS',
			     parent => $feff,
			     data   => $data,
			     sp	    => $feff->pathlist->[12],
			     s02    => 1/12);
my $vpath = Demeter::VPath->new(name=>'vpath from metal');
$vpath->include($pds, $pts);

foreach my $pl ($composite, $vpath) {$pl->plot('k')};
#print $pds->geometry, $/;
#print $pts->geometry, $/;
$composite->pause;

$composite->po->start_plot;
$composite->po->r_pl('m');
foreach my $pl ($composite, $vpath) {$pl->plot('r')};
$composite->pause;

$composite->po->start_plot;
$composite->po->r_pl('r');
foreach my $pl ($composite, $vpath) {$pl->plot('r')};
$composite->pause;

exit;

my @gds = (Demeter::GDS->new(gds=>'guess', name=>'amp',  mathexp=>1),
	   Demeter::GDS->new(gds=>'guess', name=>'enot', mathexp=>0),
	   Demeter::GDS->new(gds=>'guess', name=>'ss',   mathexp=>0.001),
	   Demeter::GDS->new(gds=>'set',   name=>'delr', mathexp=>0),
	  );

$composite->set(data   => $data,
		s02    => 'amp',
		e0     => 'enot',
		delr   => 'delr',
		sigma2 => 'ss',
	       );
my $fit = Demeter::Fit->new(gds=>\@gds,
			    data=>[$data],
			    paths=>[$composite],
			   );
$fit->fit;
$fit->logfile('dlpoly.log');
$data->po->start_plot;
$data->po->set(plot_fit=>1);
$data->plot('r');
$data->pause;

