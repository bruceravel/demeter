#!/usr/bin/perl

use Demeter qw(:ui=screen :plotwith=gnuplot);

my $prj = Demeter::Data::Prj->new(file=>'diff.prj');
my $stan = $prj->record(1);

$stan->po->set(emin=>-50, emax=>80, e_norm=>1, e_markers=>0);

my $diff = Demeter::Diff->new(standard=>$stan, plotspectra=>0, invert=>0);
#$diff->set_mode(screen=>1);
$diff->po->start_plot;
foreach my $i (18,21) { #6,9,12,15,18,21) {
  $diff->data($prj->record($i));
  $diff->diff;
  $diff->plot;
  printf "%7.3f\n", $diff->area;
};
$stan->pause;
