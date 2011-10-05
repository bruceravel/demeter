#!/usr/bin/perl -w
######################################################################
## Time-stamp: <2011-10-05 16:07:27 bruce>
######################################################################
##  This program is copyright (c) 2005-2006, 2011 Bruce Ravel
##  <bravel@anl.gov>
##  http://cars9.uchicago.edu/~ravel/software/exafs/
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
## This program generates the Waasmaier-Kirfel data from a flat text
## database for use with the Xray::Scattering module.  The data is
## simply an electronic form of those coefficients.  The output is
## stored as a Storable binary database.  The data is stored in
## "network" order so it can be accessed over a network and across
## disparate platforms.
##
## New analytical scattering-factor functions for free atoms and ions
## D. Waasmaier and A. Kirfel
## Acta Cryst. (1995). A51, 416-431
## [ doi:10.1107/S0108767394013292 ]
######################################################################
## Code:

use strict;
use Storable qw/nstore/;
use File::Spec;
use Chemistry::Elements qw(get_symbol);

##data (s(i),i=1,214) /

my @symbols = qw(H H1- He Li Li1+ Be Be2+ B C Cval N O O1- O2- F F1- Ne Na
		 Na1+ Mg Mg2+ Al Al3+ Si Siva Si4+ P S Cl Cl1- Ar K K1+ Ca
		 Ca2+ Sc Sc3+ Ti Ti2+ Ti3+ Ti4+ V V2+ V3+ V5+ Cr Cr2+ Cr3+ Mn
		 Mn2+ Mn3+ Mn4+ Fe Fe2+ Fe3+ Co Co2+ Co3+ Ni Ni2+ Ni3+ Cu Cu1+
		 Cu2+ Zn Zn2+ Ga Ga3+ Ge Ge4+ As Se Br Br1- Kr Rb Rb1+ Sr Sr2+
		 Y Zr Zr4+ Nb Nb3+ Nb5+ Mo Mo3+ Mo5+ Mo6+ Tc Ru Ru3+ Ru4+ Rh
		 Rh3+ Rh4+ Pd Pd2+ Pd4+ Ag Ag1+ Ag2+ Cd Cd2+ In In3+ Sn Sn2+
		 Sn4+ Sb Sb3+ Sb5+ Te I I1- Xe Cs Cs1+ Ba Ba2+ La La3+ Ce Ce3+
		 Ce4+ Pr Pr3+ Pr4+ Nd Nd3+ Pm Pm3+ Sm Sm3+ Eu Eu2+ Eu3+ Gd
		 Gd3+ Tb Tb3+ Dy Dy3+ Ho Ho3+ Er Er3+ Tm Tm3+ Yb Yb2+ Yb3+ Lu
		 Lu3+ Hf Hf4+ Ta Ta5+ W W6+ Re Os Os4+ Ir Ir3+ Ir4+ Pt Pt2+
		 Pt4+ Au Au1+ Au3+ Hg Hg1+ Hg2+ Tl Tl1+ Tl3+ Pb Pb2+ Pb4+ Bi
		 Bi3+ Bi5+ Po At Rn Fr Ra Ra2+ Ac Ac3+ Th Th4+ Pa U U3+ U4+
		 U6+ Np Np3+ Np4+ Np6+ Pu Pu3+ Pu4+ Pu6+ Am Cm Bk Cf);



#-----------------------------------------------------------------------
#  the formula for reconstruction of f0 is:
#            5
#   f0(s) = sum [ ai*exp(-bi*s^2) ] + c ,    s = sin(theta) / lambda
#           i=1                            ==> (lambda*s / 2pi) is the
#                                               momentum transfer
#-----------------------------------------------------------------------
#  coef: 1..9 corresponding to a1,b1,a2,b2,a3,b3,a4,b4,c
#-----------------------------------------------------------------------

my $version = '1.0';
print "Waasmaier-Kirfel data conversion tool $version$/";

$| = 1;
my $thisdir = &identify_self;
my $infile = File::Spec -> catfile($thisdir, "f0_WaasKirf.data");
open CM, $infile or die $!;

my %cromann = ();

print "  Reading Waasmaier-Kirfel data ";
my @data = ();
while (<CM>) {
  next if (/^\s*\#([CFN]|U([DOT]|IDL|3W))/);
  next if (/^\s*$/);
  if (/^\#S/) {
    chomp;
    my $key = lc((split)[2]);
    $_ = <CM>;			# read the #N line
    $_ = <CM>;			# read the #L line
    $_ = <CM>;			# this is the data
    chomp $_;
    $cromann{$key} = [split];
  };
};
close CM;
print "\n";


my $outfile = File::Spec -> catfile($thisdir, '..', 'Scattering', "waaskirf.db");
if (-e $outfile) {
  print "  Removing old waaskirf.db.\n";
  unlink($outfile);
};
print "  Writing waaskirf.db\n";
nstore(\%cromann, $outfile) or die "can't store hash: $!\n";

## use Data::Dumper;
## print Data::Dumper->Dump([\%cromann], [qw/*cromann/]);


sub identify_self {
  my @caller = caller;
  use File::Basename qw(dirname);
  return dirname($caller[1]);
};
