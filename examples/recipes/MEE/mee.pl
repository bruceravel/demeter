#!/usr/bin/perl

use Demeter qw(:ui=screen :p=gnuplot);

Demeter->set_mode(screen=>0);
my $prj = Demeter::Data::Prj->new(file=>'La-LIIIedge_multiexcitation.prj');
my $data = $prj->record(2);
$data->fft_kmax(9);

Demeter->po->set(e_mu=>1, e_norm=>1, e_bkg=>0, e_pre=>0, e_post=>0, kweight=>2);
$data -> plot('e');

##       white line -  MEE feature
my $shift = 5612.22 - 5491.18;
my $amp = 0.014; # play around with these two
my $width = 0.5;

my $new = $data->mee(shift=>$shift, amp=>$amp, width=>$width);
$new ->plot('e');
$data->pause;

Demeter->po->start_plot;
$data -> plot('k');
$new  -> plot('k');
$data->pause;


Demeter->po->start_plot;
$data -> plot('r');
$new  -> plot('r');
$data->pause;
