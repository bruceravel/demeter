#!/usr/bin/perl -w
######################################################################
##  This program is copyright (c) 1999, 2011 Bruce Ravel
##  <ravel@phys.washington.edu>
##  http://feff.phys.washington.edu/~ravel/software/atoms/
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
## This program generates the Chantler data from a flat text files for
## use with the Absorption::Chantler module.  The flat text data files
## were converted from the html found at
##    http://physics.nist.gov/PhysRefData/FFast/html/form.html
## using the command `lynx -dump -width=120'.  The data is stored as a
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

my $cvs_info = '$Id: chantler2st.PL,v 1.2 1999/06/25 23:45:16 bruce Exp $ ';
my $version = (split(' ', $cvs_info))[2] || "pre_release";

$| = 1;

my %chantler = ();
$chantler{'version'} = $version;

print "Chantler data conversion tool $version for Absorption 0.10$/";

my $thisdir = &identify_self;
my $chantlerdir = File::Spec -> catfile($thisdir, "chantler");

print "  Parsing lines ... ";
my $infile =  File::Spec -> catfile($chantlerdir, "lines.elem");
open CHANTLER, $infile or die $!;
while (<CHANTLER>) {
  next if /^\s*\#/;
  chomp;
  my @line = split;
  my $el = lc( get_symbol($line[0]) );
  $chantler{$el}{"energy_kalpha"} = $line[1];
  $chantler{$el}{"energy_kbeta"}  = $line[2];
  $chantler{$el}{"energy_lalpha"} = $line[3];
  $chantler{$el}{"energy_lbeta"}  = $line[4];
};
close CHANTLER;

print "$/  Parsing element";
foreach my $z (1 .. 92) {
  ($z % 5) or print " $z";
  my $el = lc( get_symbol($z) );
  my $frel = 0;
  my $infile = sprintf "%2.2d.dat.elem", $z;
  $infile =  File::Spec -> catfile($chantlerdir, $infile);
  open CHANTLER, $infile or die $!;
  $_ = <CHANTLER>;			# pop off first line;
  $chantler{$el}{"energy"}=[];
  $chantler{$el}{"f1"}=[];
  $chantler{$el}{"f2"}=[];
  while (<CHANTLER>) {
    next if /^\s*$/;
    chomp;
    ##next if ($line[1] < -9998);	# drop points for which f' is not tabulated


    if (/^\s*(K|([LMNOP]\s+[IV]+)) /i) { ## line with edge energies
      my @line = split;
      while (@line) {
	my $token = shift @line;
	if ($token =~ /k/i) {
	  $chantler{$el}{"energy_k"} = 1000 * shift @line;
	} else {
	  $token = lc($token);
	  my $number = lc(shift @line);
	  my %r2a = ("i"=>"1",  "ii"=>"2", "iii"=>"3", "iv"=>"4", "v"=>"5",
		     "vi"=>"6", "vii"=>"7", "vi*"=>"6");
	  $number = $r2a{$number};
	  $chantler{$el}{"energy_".$token.$number} = 1000 * shift @line;
	};
      };
    } elsif (($el =~ /he?/) and (/^\s+1 edge/)) {	# H and He are special
      my @line = split;
      $chantler{$el}{"energy_k"} = 1000 * $line[7];
    } elsif (/^\s*Relativistic/i) {
      my @line = split;
      $frel = $line[6];
      chop $frel;
    } elsif (/^[^ \t]/) {	# line with data
      my @line = split;
      push @{$chantler{$el}{"energy"}},  1000 * $line[0];
      ##if (($line[1]+$frel) <= 0) {
      if ($line[1] <= 0) {
	push @{$chantler{$el}{"f1"}},	 log(0.000001);
      } else {
	##push @{$chantler{$el}{"f1"}},	 log($line[1]+$frel);
	push @{$chantler{$el}{"f1"}},	 log($line[1]);
      };
      if ($line[2] <= 0) {
	push @{$chantler{$el}{"f2"}},	 log(0.000001);
      } else {
	push @{$chantler{$el}{"f2"}},	 log($line[2]);
      }
      if ($line[4] <= 0) {
	push @{$chantler{$el}{"scatt"}}, log(0.000001);
      } else {
	push @{$chantler{$el}{"scatt"}}, log($line[4]);
      }
    };
  };
  close CHANTLER;
};
print $/;


print "  Getting energy list keys ... ";
my @energy_list = ();
foreach my $key (keys %chantler) {
  next if ($key eq "version");
  next if ($key eq "nu");
  foreach my $s ("k" , "l1", "l2", "l3", "m1", "m2", "m3", "m4", "m5",
		 "n1", "n2", "n3", "n4", "n5", "n6", "n7",
		 "o1", "o2", "o3", "o4", "o5", "o6", "o7",
		 "p1", "p2", "p3") {
    exists $chantler{$key}->{"energy_".$s} and
      push @energy_list, $key . "_" . $s ;
  };
};

print "sorting energy list ... ";
@energy_list =
  sort {
    $chantler{shift @{[split(/_/,$a)]}}{"energy_". pop @{[split(/_/,$a)]}}
       <=>
    $chantler{shift @{[split(/_/,$b)]}}{"energy_". pop @{[split(/_/,$b)]}}
  } @energy_list;


print "and making energy hash$/";
#my %energy_hash = ();
while (@energy_list) {
  my $this = shift(@energy_list);
  if (@energy_list) {
    my $that = $energy_list[0];
    my ($elem, $edge) = split(/_/, $that);
    my $energy = $chantler{$elem}{"energy_".$edge};
    $chantler{energy_list}{$this} = [$elem, $edge, $energy];
  } else {			# taking care with last element
    $chantler{energy_list}{$this} = [];
  };
};



my $outfile = File::Spec -> catfile($thisdir, '..', 'Absorption', "chantler.db");
if (-e $outfile) {
  print "  Removing stale database, $outfile.$/";
  unlink $outfile or die "could not remove old database $!";
};
print "  Saving new database, $outfile.$/";

## my %foo = %{$chantler{ho}};
## print Data::Dumper->Dump([\%foo],   [qw(*element)]);
nstore(\%chantler, $outfile) or die "can't store hash: $!\n";



sub identify_self {
  my @caller = caller;
  use File::Basename qw(dirname);
  return dirname($caller[1]);
};
