#!/usr/bin/perl -w
######################################################################
##  This program is copyright (c) 1999, 2011 Bruce Ravel
##  L<http://bruceravel.github.io/home>
##  http://bruceravel.github.io/demeter/
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
## This program generates the edge and line energy data from flat text
## files for use with the Absorption::CL module.  The edge energy data
## was converted from the Fortran source into flat text and resides in
## the file cl/cl.dat.  The line energy data comes from McMaster, so
## only contains Kalpha, Kbeta, Lalpha, and Lbeta without
## distinguishing the sub-lines.  The data is stored as a Storable
## binary database.  The data is stored in "network" order so it can
## be accessed over a network and across disparate platforms.
##
## No data regarding cross section or anomalous scattering is stored
## in the database file.  Insetad it is generated from the fortran
## using CLdata.pm.
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

my $cvs_info = '$Id: cl2st.PL,v 1.3 2001/09/20 17:44:22 bruce Exp $ ';
my $version = (split(' ', $cvs_info))[2] || "pre_release";

$| = 1;

my %cl = ();
$cl{'version'} = $version;

print "CL data conversion tool $version for Absorption 0.10$/";

my $thisdir = &identify_self;
##my $cldir = File::Spec -> catfile($thisdir, "cl");

print "  Parsing lines ... ";
my $infile =  File::Spec -> catfile($thisdir, "cl_lines");
open CL, $infile or die $!;
while (<CL>) {
  next if /^\s*\#/;
  next if /^\s*$/;
  chomp;
  my @line = split;
  my $el = lc( get_symbol($line[0]) );
  $cl{$el}{"energy_kalpha"} = $line[1];
  $cl{$el}{"energy_kbeta"}  = $line[2];
  $cl{$el}{"energy_lalpha"} = $line[3];
  $cl{$el}{"energy_lbeta"}  = $line[4];
};
close CL;

print "energies ...";
$infile =  File::Spec -> catfile($thisdir, "cl.data");
open CL, $infile or die $!;
my ($l, $el);
while (<CL>) {
  next if /^\s*\#/;
  next if /^\s*\#/;
  chomp;
  my @line = split;
  if (/^\s*[a-z]/i) {		# element line
    $el = lc( get_symbol($line[0]) );
    $l = 0;
  } else {			# or one of 5 energy lines
    ++$l;
    if ($l == 1) {
      $cl{$el}{"energy_k"} = $line[0];
      $line[1] and $cl{$el}{"energy_l1"} = $line[1];
      $line[2] and $cl{$el}{"energy_l2"} = $line[2];
      $line[3] and $cl{$el}{"energy_l3"} = $line[3];
    } elsif ($l == 2) {
      $line[0] and $cl{$el}{"energy_m1"} = $line[0];
      $line[1] and $cl{$el}{"energy_m2"} = $line[1];
      $line[2] and $cl{$el}{"energy_m3"} = $line[2];
      $line[3] and $cl{$el}{"energy_m4"} = $line[3];
      $line[4] and $cl{$el}{"energy_m5"} = $line[4];
    } elsif ($l == 3) {
      $line[0] and $cl{$el}{"energy_n1"} = $line[0];
      $line[1] and $cl{$el}{"energy_n2"} = $line[1];
      $line[2] and $cl{$el}{"energy_n3"} = $line[2];
      $line[3] and $cl{$el}{"energy_n4"} = $line[3];
      $line[4] and $cl{$el}{"energy_n5"} = $line[4];
      $line[5] and $cl{$el}{"energy_n6"} = $line[5];
      $line[6] and $cl{$el}{"energy_n7"} = $line[6];
    } elsif ($l == 4) {
      $line[0] and $cl{$el}{"energy_o1"} = $line[0];
      $line[1] and $cl{$el}{"energy_o2"} = $line[1];
      $line[2] and $cl{$el}{"energy_o3"} = $line[2];
      $line[3] and $cl{$el}{"energy_o4"} = $line[3];
      $line[4] and $cl{$el}{"energy_o5"} = $line[4];
    } elsif ($l == 5) {
      $line[0] and $cl{$el}{"energy_p1"} = $line[0];
      $line[1] and $cl{$el}{"energy_p2"} = $line[1];
      $line[2] and $cl{$el}{"energy_p3"} = $line[2];
    };
  };
};
close CL;


print "$/  Getting energy list keys ... ";
my @energy_list = ();
foreach my $key (keys %cl) {
  next if ($key eq "version");
  next if ($key eq "nu");
  foreach my $s ("k" , "l1", "l2", "l3", "m1", "m2", "m3", "m4", "m5",
		 "n1", "n2", "n3", "n4", "n5", "n6", "n7",
		 "o1", "o2", "o3", "o4", "o5", "o6", "o7",
		 "p1", "p2", "p3") {
    exists $cl{$key}->{"energy_".$s} and
      push @energy_list, $key . "_" . $s ;
  };
};

print "sorting energy list ... ";
@energy_list =
  sort {
    $cl{shift @{[split(/_/,$a)]}}{"energy_". pop @{[split(/_/,$a)]}}
       <=>
    $cl{shift @{[split(/_/,$b)]}}{"energy_". pop @{[split(/_/,$b)]}}
  } @energy_list;


print "and making energy hash$/";
#my %energy_hash = ();
while (@energy_list) {
  my $this = shift(@energy_list);
  if (@energy_list) {
    my $that = $energy_list[0];
    my ($elem, $edge) = split(/_/, $that);
    my $energy = $cl{$elem}{"energy_".$edge};
    $cl{energy_list}{$this} = [$elem, $edge, $energy];
  } else {			# taking care with last element
    $cl{energy_list}{$this} = [];
  };
};

my $outfile = File::Spec -> catfile($thisdir, '..', 'Absorption', "cl.db");
if (-e $outfile) {
  print "  Removing stale database, $outfile.$/";
  unlink $outfile or die "could not remove old database $!";
};
print "  Saving new database, $outfile.$/";

## my %foo = %{$cl{u}};
## print Data::Dumper->Dump([\%foo],   [qw(*element)]);
nstore(\%cl, $outfile) or die "can't store hash: $!\n";



sub identify_self {
  my @caller = caller;
  use File::Basename qw(dirname);
  return dirname($caller[1]);
};
