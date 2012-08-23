#!/usr/bin/perl

use Demeter qw(:fit :ui=screen);

## run feff on FeS2
print Demeter->now, $/;
my $feff = Demeter::Feff->new(file=>'feff.inp', workspace=>'feff', screen=>0);
$feff -> make_workspace;
$feff -> rmax(4.6);
$feff -> run;

Demeter->set_mode(screen=>0);
#Demeter->mo->check_heap(1);

my @tests = (qw(area1 area2 area3 height1 height2 height3));

print Demeter->now, $/;
## evaluate the raw rankings
print "Raw values\n          " . join("     ", @tests) . "\n";;
my $i=1;
foreach my $sp (@{ $feff->pathlist }) {
  $sp->rank;
  printf " %4.4d  %8.4f   %8.4f   %8.4f  %8.4f   %8.4f   %8.4f\n",
    $i++, map {$sp->get_rank($_)} @tests;
};

## normalize the rankings
$feff->pathlist->[0]->normalize(@{ $feff->pathlist });

## print out the normalized rankings
print "\nNormalized values\n          " . join("     ", @tests) . "\n";
$i=1;
foreach my $sp (@{ $feff->pathlist }) {
  printf " %4.4d  %8.2f   %8.2f   %8.2f  %8.2f   %8.2f   %8.2f\n",
    $i++, map {$sp->get_rank($_.'_n')} @tests;
};
print Demeter->now, $/;

#feff->pause;
