#!/usr/bin/perl -w
######################################################################
##  This program is copyright (c) 1999, 2011 Bruce Ravel
##  bravel AT bnl DOT gov
##  http://bruceravel.github.com/demeter/
##
## -------------------------------------------------------------------
##     All rights reserved. This program is free software; you can
##     redistribute it and/or modify it under the same terms as Perl
##     itself.
##
##     This program is distributed in the hope that it will be useful,
##     but WITHOUT ANY WARRANTY; without even the implied warranty of
##     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
##     Artistic License for more details.
## -------------------------------------------------------------------
######################################################################
## Time-stamp: <99/04/20 22:00:15 bruce>
######################################################################
## This program generates the Henke data from a flat text files for
## use with the Absorption::Henke module.  The data is stored as a
## Storable binary database.  The data is stored in "network" order so
## it can be accessed over a network and across disparate platforms.
##
## The data is stored a big hash.  There is a hash entry for each
## element keyed off its lower case symbol.  There is an entry keyed
## off "version" which contains a scalar identifying the database.
## There is an entry called "energy_list" which is used by the
## "next_energy" method.
######################################################################
## Code:

use strict;
use Storable qw/nstore/;
## use Data::Dumper;
use File::Spec;
use Chemistry::Elements qw(get_symbol);

my $cvs_info = '$Id: henke2st.PL,v 1.5 1999/10/24 16:21:36 bruce Exp $ ';
my $version = (split(' ', $cvs_info))[2] || "pre_release";

$| = 1;

my %henke = ();
$henke{'version'} = $version;

print "Henke data conversion tool $version for Absorption 0.10$/";

my $thisdir = &identify_self;
my $henkedir = File::Spec -> catfile($thisdir, "henke");

print "  Parsing energies ... ";
my $infile =  File::Spec -> catfile($henkedir, "energies");
open HENKE, $infile or die $!;
while (<HENKE>) {
  chomp;
  my @line = split;
  my $el = lc( get_symbol($line[1]) );
  foreach my $i (1 .. $line[2]) {
    $_ = <HENKE>;
    my @eline = split;
    my $edge = lc($eline[1]);
    ($edge eq "k1") and $edge = "k";
    $henke{$el}{"energy_".$edge} = $eline[2];
  };
};
close HENKE;

print "lines ... ";
$infile =  File::Spec -> catfile($henkedir, "lines");
open HENKE, $infile or die $!;
while (<HENKE>) {
  next if /^\s*\#/;
  next if /^\s*$/;
  chomp;
  my @line = split;
  my $el = lc( get_symbol($line[0]) );
  $henke{$el}{"energy_kalpha"} = $line[1];
  $henke{$el}{"energy_kbeta"}  = $line[2];
  $henke{$el}{"energy_lalpha"} = $line[3];
  $henke{$el}{"energy_lbeta"}  = $line[4];
};
close HENKE;

print $/, "  Parsing element";
foreach my $z (1 .. 92) {
  ($z % 5) or print " $z";
  my $el = lc( get_symbol($z) );
  my $infile =  File::Spec -> catfile($henkedir, "$el.nff");
  open HENKE, $infile or die $!;
  $_ = <HENKE>;			# pop off first line;
  $henke{$el}{"energy"}=[];
  $henke{$el}{"f1"}=[];
  $henke{$el}{"f2"}=[];
  while (<HENKE>) {
    chomp;
    my @line = split;
    next if ($line[1] < -9998);	# drop points for which f' is not tabulated
    push @{$henke{$el}{"energy"}}, $line[0];
    if ($line[1] < 0) {
      push @{$henke{$el}{"f1"}},   log(0.0001);
    } else {
      push @{$henke{$el}{"f1"}},   log($line[1]);
    };
    push @{$henke{$el}{"f2"}},     log($line[2]);
  };
  close HENKE;
};
print $/;


print "  Getting energy list keys ... ";
my @energy_list = ();
foreach my $key (keys %henke) {
  next if ($key eq "version");
  next if ($key eq "nu");
  foreach my $s ("k" , "l1", "l2", "l3", "m1", "m2", "m3", "m4", "m5",
		 "n1", "n2", "n3", "n4", "n5", "n6", "n7",
		 "o1", "o2", "o3", "o4", "o5", "o6", "o7",
		 "p1", "p2", "p3") {
    exists $henke{$key}->{"energy_".$s} and
      push @energy_list, $key . "_" . $s ;
  };
};

print "sorting energy list ... ";
@energy_list =
  sort {
    $henke{shift @{[split(/_/,$a)]}}{"energy_". pop @{[split(/_/,$a)]}}
       <=>
    $henke{shift @{[split(/_/,$b)]}}{"energy_". pop @{[split(/_/,$b)]}}
  } @energy_list;


print "and making energy hash$/";
#my %energy_hash = ();
while (@energy_list) {
  my $this = shift(@energy_list);
  if (@energy_list) {
    my $that = $energy_list[0];
    my ($elem, $edge) = split(/_/, $that);
    my $energy = $henke{$elem}{"energy_".$edge};
    $henke{energy_list}{$this} = [$elem, $edge, $energy];
  } else {			# taking care with last element
    $henke{energy_list}{$this} = [];
  };
};



my $outfile = File::Spec -> catfile($thisdir, '..', 'Absorption', "henke.db");
if (-e $outfile) {
  print "  Removing stale database, $outfile.$/";
  unlink $outfile or die "could not remove old database $!";
};
print "  Saving new database, $outfile.$/";

## open (OUT, ">".$outfile) or die $!;;
## print OUT Data::Dumper->Dump([\%henke],   [qw(*henke)]);
## close OUT;
nstore(\%henke, $outfile) or die "can't store hash: $!\n";



sub identify_self {
  my @caller = caller;
  use File::Basename qw(dirname);
  return dirname($caller[1]);
};
