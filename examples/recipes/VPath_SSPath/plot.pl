#!/usr/bin/perl

use Demeter qw(:plotwith=gnuplot :ui=screen);

my $fit = Demeter::Fit->new;
$fit -> thaw(file=>"uace.dpj");

my $data = $fit->data->[0];
my @vpaths = @{ $fit->vpaths };

my $how = $ARGV[0] || 'm';

$data->po->set(kweight=>2, r_pl=>$how);
$data->po->stackjump(0.2);
$data->stack(@vpaths);
$data->pause;
