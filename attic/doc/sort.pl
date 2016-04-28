#!/usr/perl/bin

## first do ack '\\label' > foo
## that will show you how many instances of \label{} you have
## and which labels are multiply defined
## then go through and sort them out by hand

use strict;
use warnings;

my @list;
open(my $F, '<', 'foo');
while (<$F>) {
  chomp;
  my ($file, $line, $labelspec) = split(/:\s*/, $_);
  my $label = $1 if $labelspec =~ m{\\label\{(.*)\}};
  $label ||= 'NULL';
  push @list, [$label, $file, $line];
};
close $F;


my %count;
@list = sort {$a->[0] cmp $b->[0]} @list;
foreach my $l (@list) {
  #printf("%-20s : %s, %d\n", @$l);
  ++$count{$l->[0]};
};

foreach my $c (keys %count) {
  print $c, "  ", $count{$c}, $/ if $count{$c} > 1;
};
