#!/usr/bin/perl

use strict;
use warnings;
use JSON qw(encode_json);

my @biglist = ();

open(my $F, '<', '/home/bruce/ShannonRadii.txt');
while (<$F>) {
  chop; chop;			# win eol
  next if not $_ =~ m{\A\d};
  my @list = split(/\t/, );
  my ($el, $chg) = split(/[-+]/, $list[1]);
  my $i = $list[0]-1;
  ($biglist[$i]->{element} = $el) =~ s/\s//g;
  if ($list[2] > 0) {
    $biglist[$i]->{ionization} = '+'.$list[2];
  } else {
    $biglist[$i]->{ionization} = $list[2];
  }
  $biglist[$i]->{coordination}  = $list[3];
  $biglist[$i]->{configuration} = $list[4];
  $biglist[$i]->{spin} = $list[5];
  $biglist[$i]->{crystalradius} = $list[6];
  $biglist[$i]->{ionicradius} = $list[7];
  $biglist[$i]->{notes} = $list[8];
  $biglist[$i]->{zoverr} = $list[9];
};
close $F;

my $snarf = encode_json(\@biglist);

open(my $J, '>', 'ionic_radii.json');
print $J $snarf;

