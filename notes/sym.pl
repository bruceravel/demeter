#!/usr/bin/perl

use Demeter qw(:plotwith=gnuplot);


my $data = Demeter::Data->new(file	  => 'fe.060',
			      ln	  =>  1,
			      energy	  => '$1',
			      numerator   => '$2',
			      denominator => '$3',
			     );

my $start = $ARGV[0] || 105;
$data->co->set_default('gnuplot', 'markersymbol', $start);
$data->po->just_mu;
$data->po->e_marker(1);

while (1) {
  $data->po->start_plot;
  print "symbol = $start > ";
  $data->plot('e');
  ++$start;
  $data->co->set_default('gnuplot', 'markersymbol', $start);
  my $response = <STDIN>;
  exit if ($response =~ m{\Aq});
};
