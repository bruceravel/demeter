#!/usr/bin/perl -w
######################################################################
##  This program is copyright (c) 1999, 2011-2015 Bruce Ravel
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
## This program generates the Elam data from a flat text database for
## use with the Absorption::Elam module.  The data is stored as a
## Storable binary database.  The data is stored in "network" order so
## it can be accessed over a network and across disparate platforms.
##
## The Elam data is the work of Tim Elam (give a reference) (point to
## some documentation)
##
## The data is stored a big hash.  There is a hash entry for each
## element keyed off its lower case symbol.  There is an entry keyed
## off "version" which contains a scalar identifying the database.
## There is an entry called "energy_list" which is used by the
## "next_energy" method.
##
## The element entries are themselves hashes.  Keys like "energy_k"
## and "intensity_lb1" are scalar valued.  The keys "scatter" and
## "photo" are hash valued.  These hashes have keys which are array
## valued.
##
##    scatter --> "energy" "coh" "coh2" "inc" "inc2"
##
##    photo   --> "energy" "xsec" "second"
##
## These are the energy grid, the cross-section, coherent fraction,
## and incoherent fraction, and their second derivatives.
##
## An example:
##
## %elam = (
##           'ba' => { 'number'			 => 56,
##                     'atomic_weight'		 => '1.37330e+02',
##                     'density'		 => '3.50000e+00',
##                     'energy_k'		 => '3.74410e+04',
##                     'energy_ka1'		 => '3.21940e+04',
##                     'energy_ka2'		 => '3.18170e+04',
##                     'energy_ka3'		 => '3.14520e+04',
##                     'energy_kb1'		 => '3.63780e+04',
##                     'energy_kb2'		 => '3.72490e+04',
##                     'energy_kb3'		 => '3.63040e+04',
##                     'energy_kb4'		 => '3.73484e+04',
##                     'energy_kb5'		 => '3.66453e+04',
##                     'energy_l1'		 => '5.98900e+03',
##                     'energy_l2'		 => '5.62400e+03',
##                     'energy_l3'		 => '5.24700e+03',
##                     'energy_la1'		 => '4.46650e+03',
##                     'energy_la2'		 => '4.45130e+03',
##                     'energy_lb1'		 => '4.82830e+03',
##                     'energy_lb2'		 => '5.15440e+03',
##                     'energy_lb3'		 => '4.92600e+03',
##                     'energy_lb4'		 => '4.85200e+03',
##                     'energy_lb6'		 => '4.99350e+03',
##                     'energy_lg1'		 => '5.53140e+03',
##                     'energy_lg2'		 => '5.79700e+03',
##                     'energy_lg3'		 => '5.81040e+03',
##                     'energy_ll'		 => '3.95400e+03',
##                     'energy_ln'		 => '4.33100e+03',
##                     'energy_m1'		 => '1.29300e+03',
##                     'energy_m2'		 => '1.13700e+03',
##                     'energy_m3'		 => '1.06300e+03',
##                     'energy_m4'		 => '7.95700e+02',
##                     'energy_m5'		 => '7.80500e+02',
##                     'energy_ma'		 => '7.80500e+02',
##                     'energy_mb'		 => '7.95700e+02',
##                     'energy_mg'		 => '9.73100e+02',
##                     'energy_mz'		 => '6.03700e+02',
##                     'energy_n1'		 => '2.53500e+02',
##                     'energy_n2'		 => '1.92000e+02',
##                     'energy_n3'		 => '1.78600e+02',
##                     'energy_n4'		 => '9.26000e+01',
##                     'energy_n5'		 => '8.99000e+01',
##                     'energy_n6'		 => '0.00000e+00',
##                     'energy_n7'		 => '0.00000e+00',
##                     'energy_o1'		 => '3.03000e+01',
##                     'intensity_ka1'		 => '5.44945e-01',
##                     'intensity_ka2'		 => '2.95859e-01',
##                     'intensity_ka3'		 => '5.58460e-04',
##                     'intensity_kb1'		 => '9.88967e-02',
##                     'intensity_kb2'		 => '3.81462e-02',
##                     'intensity_kb3'		 => '1.97507e-02',
##                     'intensity_kb4'		 => '4.02824e-04',
##                     'intensity_kb5'		 => '1.44040e-03',
##                     'intensity_la1'		 => '7.36328e-01',
##                     'intensity_la2'		 => '8.19629e-02',
##                     'intensity_lb1'		 => '8.52142e-01',
##                     'intensity_lb2,15'	 => '1.49754e-01',
##                     'intensity_lb3'		 => '4.96835e-01',
##                     'intensity_lb4'		 => '2.95141e-01',
##                     'intensity_lb6'		 => '5.52982e-03',
##                     'intensity_lg1'		 => '1.24419e-01',
##                     'intensity_lg2'		 => '8.94302e-02',
##                     'intensity_lg3'		 => '1.18594e-01',
##                     'intensity_ll'		 => '2.64258e-02',
##                     'intensity_ln'		 => '2.34397e-02',
##                     'intensity_ma'		 => '1.00000e+00',
##                     'intensity_mb'		 => '9.97068e-01',
##                     'intensity_mg'		 => '1.00000e+00',
##                     'intensity_mz'		 => '2.93255e-03',
##                     'yield_k'		 => '9.02000e-01',
##                     'yield_l1'		 => '5.20000e-02',
##                     'yield_l2'		 => '9.60000e-02',
##                     'yield_l3'		 => '9.70000e-02',
##                     'yield_m1'		 => '7.16667e-04',
##                     'yield_m2'		 => '1.03333e-03',
##                     'yield_m3'		 => '8.86667e-04',
##                     'yield_m4'		 => '2.70000e-03',
##                     'yield_m5'		 => '0.00000e+00',
##                     'yield_n1'		 => '2.03333e-05',
##                     'yield_n2'		 => '9.16667e-05',
##                     'yield_n3'		 => '7.50000e-05',
##                     'yield_n4'		 => '1.14333e-04',
##                     'yield_n5'		 => '1.14333e-04',
##                     'yield_n6'		 => '0.00000e+00',
##                     'yield_n7'		 => '0.00000e+00',
##                     'yield_o1'		 => '0.00000e+00'
##                     'ck_l1_l2'		 => '1.90000e-01',
##                     'ck_l1_l3'		 => '2.80000e-01',
##                     'ck_l2_l3'		 => '1.53000e-01',
##                     'ck_m1_m2'		 => '2.09333e-01',
##                     'ck_m1_m3'		 => '5.05667e-01',
##                     'ck_m1_m4'		 => '8.96667e-02',
##                     'ck_m1_m5'		 => '1.34000e-01',
##                     'ck_m2_m3'		 => '3.30000e-02',
##                     'ck_m2_m4'		 => '5.75333e-01',
##                     'ck_m2_m5'		 => '2.65667e-01',
##                     'ck_m3_m4'		 => '2.00667e-01',
##                     'ck_m3_m5'		 => '6.81333e-01',
##                     'ck_n1_n2'		 => '2.13333e-01',
##                     'ck_n1_n3'		 => '4.20000e-01',
##                     'ck_n1_n4'		 => '2.10000e-01',
##                     'ck_n1_n5'		 => '3.16667e-01',
##                     'ck_n2_n3'		 => '1.20000e-02',
##                     'ck_n2_n4'		 => '7.40000e-01',
##                     'ck_n2_n5'		 => '2.10000e-01',
##                     'ck_n3_n4'		 => '2.06667e-01',
##                     'ck_n3_n5'		 => '7.53333e-01',
##                     'cktotal_l1_l2'		 => '1.90000e-01',
##                     'cktotal_l1_l3'		 => '3.09070e-01',
##                     'cktotal_l2_l3'		 => '1.53000e-01',
##                     'cktotal_m1_m2'		 => '2.09333e-01',
##                     'cktotal_m1_m3'		 => '5.12575e-01',
##                     'cktotal_m1_m4'		 => '3.12960e-01',
##                     'cktotal_m1_m5'		 => '5.38847e-01',
##                     'cktotal_m2_m3'		 => '3.30000e-02',
##                     'cktotal_m2_m4'		 => '5.81955e-01',
##                     'cktotal_m2_m5'		 => '2.88151e-01',
##                     'cktotal_m3_m4'		 => '2.00667e-01',
##                     'cktotal_m3_m5'		 => '6.81333e-01',
##                     'cktotal_n1_n2'		 => '2.13333e-01',
##                     'cktotal_n1_n3'		 => '4.22560e-01',
##                     'cktotal_n1_n4'		 => '4.55196e-01',
##                     'cktotal_n1_n5'		 => '6.79795e-01',
##                     'cktotal_n2_n3'		 => '1.20000e-02',
##                     'cktotal_n2_n4'		 => '7.42480e-01',
##                     'cktotal_n2_n5'		 => '2.19040e-01',
##                     'cktotal_n3_n4'		 => '2.06667e-01',
##                     'cktotal_n3_n5'		 => '7.53333e-01',
##                     'photo'   => { 'energy' => [ ... ],
##                                    'xsec'   => [ ... ],
##                                    'second' => [ ... ], },
##                     'scatter' => { 'energy' => [ ... ],
##                                    'coh'    => [ ... ],
##                                    'coh2'   => [ ... ],
##                                    'inc'    => [ ... ],
##                                    'inc2'   => [ ... ], },
##                   },
##
##
######################################################################
## Code:

use strict;
use Storable qw/nstore/;
## use Data::Dumper;
use File::Spec;

my $cvs_info = '$Id: elam2st.PL,v 1.4 2000/04/06 10:03:17 bruce Exp $ ';
my $version = (split(' ', $cvs_info))[2] || "pre_release";

$| = 1;

my %elam = ();
#$elam{'version'} = $version;

print "Elam data conversion tool $version for Absorption 0.10$/";

my $thisdir = &identify_self;
my $infile = File::Spec -> catfile($thisdir, "elam.data");
open ELAM, $infile or die $!;

print "  Parsing element";
my ($key, $el, $z, $weight, $density);	 # element line
my ($ed, $edge_energy, $yield, $jump);	 # edge line
my ($reading_lines, $reading_photo, $reading_scatter) = (0,0,0);
my $first_line = <ELAM>;
my @line = split(' ', $first_line);
$elam{'version'} = $line[2];
$elam{'date'} = join(" ", @line[3..$#line]);

while (<ELAM>) {

  next if (/^\/\//);			 # skip comment lines
  next if (/^\s*End\b/);		 # skip End

 OUTER: {

    (/^\s*Element/i) and do {
      ($key, $el, $z, $weight, $density) = split;
      $el = lc($el);
      $elam{$el}{'number'}	   = $z;
      ($z % 5) or print " $z";	# status message
      $elam{$el}{'atomic_weight'}  = $weight;
      $elam{$el}{'density'}	   = $density;
      last OUTER;
    };

    (/^\s*Edge/i) and do {	# use current value of $el
      ($key, $ed, $edge_energy, $yield, $jump) = split;
      $reading_lines = 0;
      $ed = lc($ed);
      $elam{$el}{"energy_".$ed} = $edge_energy*1;
      $elam{$el}{"yield_".$ed}  = $yield;
      $elam{$el}{"jump_".$ed}   = $jump;
      last OUTER;
    };

    (/^\s*Lines/i) and do {
      $reading_lines = 1;
      last OUTER;
    };

    (/^\s*Photo/i) and do {
      $reading_photo = 1;
      $elam{$el}{"photo"}{"energy"} = [];
      $elam{$el}{"photo"}{"xsec"}   = [];
      $elam{$el}{"photo"}{"second"} = [];
      last OUTER;
    };

    (/^\s*Scatter/i) and do {
      $reading_photo   = 0;
      $reading_scatter = 1;
      $elam{$el}{"scatter"}{"energy"} = [];
      $elam{$el}{"scatter"}{"coh"}    = [];
      $elam{$el}{"scatter"}{"coh2"}   = [];
      $elam{$el}{"scatter"}{"inc"}    = [];
      $elam{$el}{"scatter"}{"inc2"}   = [];
      last OUTER;
    };

    (/^\s*EndElement/i) and do {
      $reading_scatter = 0;
      last OUTER;
    };

    (/^\s*CKtotal/i) and do {	# use current value of $el and $ed
      my @line = split;
      shift @line;
      while (@line) {
        my $this	= lc(shift @line);
        my $this_value	= shift @line;
        $elam{$el}{"cktotal_".$ed."_".$this} = $this_value;
      };
      last OUTER;
    };

    (/^\s*CK/i) and do {	# use current value of $el and $ed
      $reading_lines = 0;
      my @line = split;
      shift @line;
      while (@line) {
        my $this	= lc(shift @line);
        my $this_value	= shift @line;
        $elam{$el}{"ck_".$ed."_".$this} = $this_value;
      };
      last OUTER;
    };

    ($reading_lines) and do {	# use current value of $el
      my @line = split;
      my $line = lc($line[1]);
      ($line eq "lb2,15") and ($line = "lb2"); # !!!
      $elam{$el}{"energy_".$line}    = $line[2]*1;
      $elam{$el}{"intensity_".$line} = $line[3];
      last OUTER;
    };

    ($reading_photo) and do {	# use current value of $el
      my @line = split;
      push @{$elam{$el}{"photo"}{"energy"}}, $line[0];
      push @{$elam{$el}{"photo"}{"xsec"}},   $line[1];
      push @{$elam{$el}{"photo"}{"second"}}, $line[2];
      last OUTER;
    };

    ($reading_scatter) and do {	# use current value of $el
      my @line = split;
      push @{$elam{$el}{"scatter"}{"energy"}}, $line[0];
      push @{$elam{$el}{"scatter"}{"coh"}},    $line[1];
      push @{$elam{$el}{"scatter"}{"coh2"}},   $line[2];
      push @{$elam{$el}{"scatter"}{"inc"}},    $line[3];
      push @{$elam{$el}{"scatter"}{"inc2"}},   $line[4];
      last OUTER;
    };
  };   # OUTER switch
};     # while loop
print $/;
close ELAM;



print "  Getting energy list keys ... ";
my @energy_list = ();
foreach my $key (keys %elam) {
  next if ($key eq "version");
  next if ($key eq "date");
  next if ($key eq "nu");
  foreach my $s ("k" , "l1", "l2", "l3", "m1", "m2", "m3", "m4", "m5",
		 "n1", "n2", "n3", "n4", "n5", "n6", "n7",
		 "o1", "o2", "o3", "o4", "o5", "o6", "o7",
		 "p1", "p2", "p3") {
    exists $elam{$key}->{"energy_".$s} and
      push @energy_list, $key . "_" . $s ;
  };
};

print "sorting energy list ... ";
@energy_list =
  sort {
    $elam{shift @{[split(/_/,$a)]}}{"energy_". pop @{[split(/_/,$a)]}}
       <=>
    $elam{shift @{[split(/_/,$b)]}}{"energy_". pop @{[split(/_/,$b)]}}
  } @energy_list;


print "and making energy hash$/";
#my %energy_hash = ();
while (@energy_list) {
  my $this = shift(@energy_list);
  if (@energy_list) {
    my $that = $energy_list[0];
    my ($elem, $edge) = split(/_/, $that);
    my $energy = $elam{$elem}{"energy_".$edge};
    $elam{energy_list}{$this} = [$elem, $edge, $energy];
  } else {			# taking care with last element
    $elam{energy_list}{$this} = [];
  };
};


print "  Getting line list keys ... ";
my @line_list = ();
foreach my $key (keys %elam) {
  next if ($key eq "version");
  next if ($key eq "date");
  next if ($key eq "nu");
  foreach my $s (qw(ka2 ka1 ka3 kb1 kb2 kb3 kb4 kb5 la1 la2 lb1 lb2 lb3 lb4 lb6 lg1 lg2
		   lg3 ll ln ma mb mg mz)) {
    exists $elam{$key}->{"energy_".$s} and
      push @line_list, $key . "_" . $s ;
  };
};

print "sorting line list ... ";
@line_list =
  sort {
    $elam{shift @{[split(/_/,$a)]}}{"energy_". pop @{[split(/_/,$a)]}}
       <=>
    $elam{shift @{[split(/_/,$b)]}}{"energy_". pop @{[split(/_/,$b)]}}
  } @line_list;

print "making lines hash ... ";
#my %energy_hash = ();
while (@line_list) {
  my $this = shift(@line_list);
  if (@line_list) {
    my $that = $line_list[0];
    my ($elem, $line) = split(/_/, $that);
    my $energy = $elam{$elem}{"energy_".$line};
    $elam{line_list}{$this} = [$elem, $line, $energy];
    #print join(" ", $elem, $line, $energy), $/;
  } else {			# taking care with last element
    $elam{line_list}{$this} = [];
  };
};

use DateTime;
print "and sorting lines hash\n";
my @biglist;
foreach my $key (keys %{$elam{line_list}}) {
  next unless exists ${$elam{line_list}}{$key}->[2];
  next unless (${$elam{line_list}}{$key}->[2] > 100);
  push @biglist, ${$elam{line_list}}{$key};
};

@biglist = sort {$a->[2] <=> $b->[2]} @biglist;
$elam{sorted} = \@biglist;


my $outfile = File::Spec -> catfile($thisdir, '..', 'Absorption', "elam.db");
if (-e $outfile) {
  print "  Removing stale database, $outfile.$/";
  unlink $outfile or die "could not remove old database $!";
};
print "  Saving new database, $outfile.$/";

## open (OUT, ">".$outfile) or die $!;;
##print STDOUT Data::Dumper->Dump([$elam{br}],   [qw(*elam)]);
## close OUT;
nstore(\%elam, $outfile) or die "can't store hash: $!\n";



sub identify_self {
  my @caller = caller;
  use File::Basename qw(dirname);
  return dirname($caller[1]);
};
