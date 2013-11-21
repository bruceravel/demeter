#!/usr/bin/perl

use warnings;
use strict;
use List::MoreUtils qw(any uniq);

my $top = $ENV{HOME} . "/git/demeter/";
my $which = $ARGV[0] || "analysis";
my $where = "lib/Demeter/templates/$which/";

my $id = $top.$where."ifeffit/";
my $ld = $top.$where."larch/";

opendir(my $I, $id);
my @it = sort {$a cmp $b} grep {!m{\A\.}} readdir $I;
closedir $I;

opendir(my $L, $ld);
my @lt = sort {$a cmp $b} grep {!m{\A\.}} readdir $L;
closedir $L;

my @list = sort {$a cmp $b} uniq(@it, @lt);

printf "# %-30s   %-30s\n", qw(Ifeffit Larch);
print "# ---------------------------------------------------------\n";
my ($i, $l);
foreach my $t (@list) {
  $i = (any {$_ eq $t} @it) ? $t : q{};
  $l = (any {$_ eq $t} @lt) ? $t : q{};
  printf "  %-30s   %-30s\n", $i, $l;
};

