#!/usr/bin/perl

use strict;
use warnings;

my %all;
open(my $D, 'data/bvparm2006.cif');
my $flag = 0;
while (<$D>) {
  next if m{\A\#};
  next if m{\A;};
  next if m{\A\s*\z};
  if (m{_valence_param_details}) {
    $flag = 1;
    next;
  };
  next if not $flag;
  my @list = split(" ", $_);
  my $comment = join(" ", @list[7..$#list]);
  $comment =~ s{\A\'|\'\z}{}g;
  my $key = sprintf("%s:%s:%s:%s", @list[0..3]);
  $all{$key} ||= [];
  my $val = {r0=>$list[5], b=>$list[5], reference=>$list[6], comment=>$comment};
  push @{ $all{$key} }, $val;
};
close $D;

use Data::Dump qw(pp);
pp %all;
