#!/usr/bin/perl

use Demeter qw(:all :ui=screen);

## run feff on FeS2
my $feff = Demeter::Feff->new(file=>'feff.inp', workspace=>'feff', screen=>0);
$feff -> make_workspace;
$feff -> rmax(4.6);
$feff -> run;

## evaluate the raw rankings
print "Raw values\n          area      peak position         height\n";
my $i=1;
foreach my $sp (@{ $feff->pathlist }) {
  $sp->rank;
  printf " %4.4d  %8.2f   %8.2f             %8.2f\n",
    $i++, $sp->importance->{area2}, $sp->importance->{peakpos2}, $sp->importance->{height2};
};

## normalize the rankings
$feff->pathlist->[0]->normalize(@{ $feff->pathlist });

## print out the normalized rankings
print "\nNormalized values\n          area      peak position         height\n";
$i=1;
foreach my $sp (@{ $feff->pathlist }) {
  printf " %4.4d  %8.2f   %8.2f             %8.2f\n",
    $i++, $sp->importance->{area2_n}, $sp->importance->{peakpos2}, $sp->importance->{height2_n};
};

$feff->pause;
