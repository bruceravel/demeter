#!/usr/bin/perl

use warnings;
use strict;
use XML::Simple;
use Data::Dumper;
use File::Basename;

my $requiredby;
my %seen;
opendir(my $dh, ".");
my @xmllist = grep { m{xml\z} } sort {$a cmp $b} readdir($dh);
closedir $dh;

my @biglist = ();
foreach my $xml (@xmllist) {
  my @sublist = ();
  #print $xml, $/;
  ++$seen{basename($xml, '.xml')};
  my $ref = XMLin("$xml");
  my $rlist = $ref->{dependency};
  ##print Data::Dumper->Dump([\@list], [qw(*list)]);
  foreach my $item (@$rlist) {
    if ($item->{depth} eq 0) {
      $requiredby = $item->{module};
      next;
    };
    next if ($item->{textresult} eq 'Core module');
    next if $seen{$item->{module}}++;
    push @sublist, [$item->{module}, $item->{depth}, $requiredby];
  };
  @sublist = sort {$b->[1] <=> $a->[1]} @sublist;
  push @biglist, @sublist;
};

foreach my $item (@biglist) {
  printf "%-30s  %d (%s)\n", @$item;
};
