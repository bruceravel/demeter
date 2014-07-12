#!/usr/bin/perl

use strict;
use warnings;
use Xray::Absorption;
use Term::ANSIColor qw(:constants);
use feature 'switch';

my $el = $ARGV[0];
my $energy = Xray::Absorption->get_energy($el, 'K');

my $hash;
do {
  no warnings;
  $hash = $$Xray::Absorption::Elam::r_elam{energy_list};
};
my @edge_list;
foreach my $key (keys %$hash) {
  next unless exists $$hash{$key}->[2];
  next if ($$hash{$key}->[2] < 100);
  push @edge_list, $$hash{$key};
};
@edge_list = sort {$a->[2] <=> $b->[2]} @edge_list;

print "Edges within 500 volts of 3x the $el K edge:\n";
printf("%s K edge at %.1f, 3x is %.1f\n\n", $el, $energy, 3*$energy);
foreach my $e (@edge_list) {
  my $diff = $e->[2] - 3*$energy;
  next if (abs($diff) > 500);
#  next if ($e->[1] !~ m{k|l3});
  given ($diff) {
    when ($_ < -50) {
      printf("%s%-2.2s %-2.2s -> %.1f (%.1f)%s\n",
	     BOLD.WHITE, ucfirst($e->[0]), ucfirst($e->[1]), $e->[2], $diff, RESET)
    };

    when ($_ < 0) {
      printf("%s%-2.2s %-2.2s -> %.1f (%.1f)%s\n",
	     BOLD.RED, ucfirst($e->[0]), ucfirst($e->[1]), $e->[2], $diff, RESET)
    }

    when ($_ > 50) {
      printf("%s%-2.2s %-2.2s -> %.1f (%.1f)%s\n",
	     q{}, ucfirst($e->[0]), ucfirst($e->[1]), $e->[2], $diff, RESET)
    }

    when ($_ > 0) {
      printf("%s%-2.2s %-2.2s -> %.1f (%.1f)%s\n",
	     BOLD.RED, ucfirst($e->[0]), ucfirst($e->[1]), $e->[2], $diff, RESET)
    }
  };
};
