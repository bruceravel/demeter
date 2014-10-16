#!/usr/bin/perl -w
######################################################################
## Time-stamp: <2011-10-05 16:07:35 bruce>
######################################################################
##  This program is copyright (c) 1999-2006, 2011 Bruce Ravel
##  http://bruceravel.github.io/home
##  http://bruceravel.github.io/demeter
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
## This program generates the Cromer-Mann data from a flat text
## database for use with the Xray::Scattering module.  The data is
## simply an electronic form of the coefficients in the International
## Tables of Crystallography.  The output is stored as a Storable
## binary database.  The data is stored in "network" order so it can
## be accessed over a network and across disparate platforms.
######################################################################
## Code:

use strict;
use Storable qw/nstore/;
use File::Spec;
use Chemistry::Elements qw(get_symbol);

##data (s(i),i=1,214) /
my @symbols = (
	       'h',    'h.',   'h1-',  'he',   'li',   'li1+', 'be',
	       'be2+', 'b',    'c',    'c.',   'n',    'o',    'o1-',
	       'f',    'f1-',  'ne',   'na',   'na1+', 'mg',   'mg2+',
	       'al',   'al3+', 'si',   'si.',  'si4+', 's',    'p',
	       'cl',   'cl1-', 'ar',   'k',    'k1+',  'ca',   'ca2+',
	       'sc',   'sc3+', 'ti',   'ti2+', 'ti3+', 'ti4+', 'v',
	       'v2+',  'v3+',  'v5+',  'cr',   'cr2+', 'cr3+', 'mn',
	       'mn2+', 'mn3+', 'mn4+', 'fe',   'fe2+', 'fe3+', 'co',
	       'co2+', 'co3+', 'ni',   'ni2+', 'ni3+', 'cu',   'cu1+',
	       'cu2+', 'zn',   'zn2+', 'ga',   'ga3+', 'ge',   'ge4+',
	       'as',   'se',   'br',   'br1-', 'kr',   'rb',   'rb1+',
	       'sr',   'sr2+', 'y',    'y3+',  'zr',   'zr4+', 'nb',
	       'nb3+', 'nb5+', 'mo',   'mo3+', 'mo5+', 'mo6+', 'tc',
	       'ru',   'ru3+', 'ru4+', 'rh',   'rh3+', 'rh4+', 'pd',
	       'pd2+', 'pd4+', 'ag',   'ag1+', 'ag2+', 'cd',   'cd2+',
	       'in',   'in3+', 'sn',   'sn2+', 'sn4+', 'sb',   'sb3+',
	       'sb5+', 'te',   'i',    'i1-',  'xe',   'cs',   'cs1+',
	       'ba',   'ba2+', 'la',   'la3+', 'ce',   'ce3+', 'ce4+',
	       'pr',   'pr3+', 'pr4+', 'nd',   'nd3+', 'pm',   'pm3+',
	       'sm',   'sm3+', 'eu',   'eu2+', 'eu3+', 'gd',   'gd3+',
	       'tb',   'tb3+', 'dy',   'dy3+', 'ho',   'ho3+', 'er',
	       'er3+', 'tm',   'tm3+', 'yb',   'yb2+', 'yb3+', 'lu',
	       'lu3+', 'hf',   'hf4+', 'ta',   'ta5+', 'w',    'w6+',
	       're',   'os',   'os4+', 'ir',   'ir3+', 'ir4+', 'pt',
	       'pt2+', 'pt4+', 'au',   'au1+', 'au3+', 'hg',   'hg1+',
	       'hg2+', 'tl',   'tl1+', 'tl3+', 'pb',   'pb2+', 'pb4+',
	       'bi',   'bi3+', 'bi5+', 'po',   'at',   'rn',   'fr',
	       'ra',   'ra2+', 'ac',   'ac3+', 'th',   'th4+', 'pa',
	       'u',    'u3+',  'u4+',  'u6+',  'np',   'np3+', 'np4+',
	       'np6+', 'pu',   'pu3+', 'pu4+', 'pu6+', 'am',   'cm',
	       'bk',   'cf',   'o2-.', ' ',    'nu',
	       );



#-----------------------------------------------------------------------
#  the formula for reconstruction of f0 is:
#            4
#   f0(s) = sum [ ai*exp(-bi*s^2) ] + c ,    s = sin(theta) / lambda
#           i=1                            ==> (lambda*s / 2pi) is the
#                                               momentum transfer
#-----------------------------------------------------------------------
#  coef: 1..9 corresponding to a1,b1,a2,b2,a3,b3,a4,b4,c
#-----------------------------------------------------------------------

my $cvs_info = '$Id: cromann.PL,v 1.3 1999/06/11 22:16:53 bruce Exp $ ';
my $version = (split(' ', $cvs_info))[2] || "pre_release";
print "Cromer-Mann data conversion tool $version$/";

$| = 1;
my $thisdir = &identify_self;
my $infile = File::Spec -> catfile($thisdir, "cromann.data");
open CM, $infile or die $!;

my %cromann = ();

print "  Reading Cromer-Mann data ";
my @data = ();
while (<CM>) {
  next if (/^\s*\#/);
  next if (/^\s*$/);
  if (/^[^ ]/) {
    chomp;
    my $key = lc((split)[0]);
    $_ = <CM>;
    chomp $_;
    $cromann{$key} = [split];
  };
};
close CM;
print "\n";


my $outfile = File::Spec -> catfile($thisdir, '..', 'Scattering', "cromann.db");
if (-e $outfile) {
  print "  Removing old cromann.db.\n";
  unlink($outfile);
};
print "  Writing cromann.db\n";
nstore(\%cromann, $outfile) or die "can't store hash: $!\n";

## use Data::Dumper;
## print Data::Dumper->Dump([\%cromann], [qw/*cromann/]);


sub identify_self {
  my @caller = caller;
  use File::Basename qw(dirname);
  return dirname($caller[1]);
};
