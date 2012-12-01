#!/usr/bin/perl

use Demeter q(:data :ui=screen);

#Demeter->set_mode(screen=>1);
my $data = Demeter::Data->new(file	  => '../../data/uhup.003',
			      energy	  => '$1',
			      numerator	  => '$3',
			      denominator => '$4',
			      ln	  => 1
			     );

$data->po->set(e_bkg=>0, e_pre=>0, e_post=>1, e_margin=>1, margin_min=>100, margin_max=>900, margin=>0.2);
#$data->po->set(e_bkg=>0, e_pre=>1, e_post=>0, e_margin=>1, margin_min=>-200, margin_max=>-50, margin=>0.2);
$data -> plot('E');
$data -> prompt("Return to deglitch points outside margins");
$data -> pause;

$data -> deglitch_margins;

$data->po->start_plot;
$data -> plot('E');
$data -> prompt("Return to finish");
$data -> pause;

