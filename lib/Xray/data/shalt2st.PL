#!/usr/bin/perl -w
######################################################################
##  This program is copyright (c) 2007, 2011 Bruce Ravel
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
######################################################################
## This program generates the Shaltout data from a flat text database
## for use with the Absorption::McMaster module.  The data is stored
## as a Storable binary database.  The data is stored in "network"
## order so it can be accessed over a network and across disparate
## platforms.
######################################################################
## Code:

use strict;
use Chemistry::Elements qw(get_symbol);
use Storable qw(nstore);
use Fatal qw(open close);
use File::Spec;

my $version = 0.1;

$| = 1;

my %shaltout = ();
my $thisdir = &identify_self;

print "Shaltout data conversion tool $version for Absorption 0.10$/";
$shaltout{'nu'} = {'number'	    => '0',
		   'atomic_weight'  => '0',
		   'density'	    => '0',
		   'conversion'	    => '0',
		   'energy'	    => {}, # K L1 L2 L3 M-1-5 N1-7
		   'jump'	    => {}, # K L1 L2 L3 M-1-5 N1-7
		   'a_k'	    => [ '0', '0', '0', '0' ],
		   'a_l'	    => [ '0', '0', '0', '0' ],
		   'a_m'	    => [ '0', '0', '0', '0' ],
		   'a_n'	    => [ '0', '0', '0', '0' ],
		   'incoherent'	    => [ '0', '0', '0', '0' ],
		   'coherent'	    => [ '0', '0', '0', '0' ],
                   };

my $infile = File::Spec -> catfile($thisdir, "shaltout.data");
open my $SHALT, $infile or die $!;
my $firstline = <$SHALT>;
$shaltout{'version'} = (split(' ', $firstline))[5] ?
  (split(' ', $firstline))[5] . " " . (split(' ', $firstline))[6] :
  "pre_release";
print "  Reading element";
my $next    = q{};
my $element = q{};
while (my $line = <$SHALT>) {
  next if ($line =~ m{^\#});		# skip comment lines
  next if ($line =~ m{^\s*=});		# skip line of equals signs
  next if ($line =~ m{^\s*$});		# skip blank lines

 ELEM: {

    ($line =~ m{^\s*element}i) and do {
      $next = <$SHALT>;
      chomp $next;
      my ($el, $number, $weight, $density, $conversion) = split(" ", $next);
      $element = lc($el);
      $shaltout{$element}{number}        = $number;
      $shaltout{$element}{atomic_weight} = $weight;
      $shaltout{$element}{density}       = $density;
      $shaltout{$element}{conversion}    = $conversion;
      print " $number" if (not ($number % 5));
      next ELEM;
    };

    ($line =~ m{^\s*coherent}i) and do {
      $next = <$SHALT>;
      ## coherent coefficients
      chomp $next;
      my @coh = split(" ", $next);
      $shaltout{$element}{coherent} = \@coh;
      ## incoherent coefficients
      $next = <$SHALT>;
      chomp $next;
      my @inc = split(" ", $next);
      $shaltout{$element}{incoherent} = \@inc;
      next ELEM;
    };

    ($line =~ m{^\s*lsf}i) and do {
      $next = <$SHALT>;
      ## K coefficients
      chomp $next;
      my @k = split(" ", $next);
      $shaltout{$element}{a_k} = \@k;
      ## L coefficients
      $next = <$SHALT>;
      chomp $next;
      my @l = split(" ", $next);
      $shaltout{$element}{a_l} = \@l;
      ## M coefficients
      $next = <$SHALT>;
      chomp $next;
      my @m = split(" ", $next);
      $shaltout{$element}{a_m} = \@m;
      ## N coefficients
      $next = <$SHALT>;
      chomp $next;
      my @n = split(" ", $next);
      $shaltout{$element}{a_n} = \@n;
      next ELEM;
    };

    ($line =~ m{^\s*(k|l[123]|m[1-5]|n[1-7])\s*$}i) and do {
      my $edge = lc($1);
      $next = <$SHALT>;
      my ($energy, $ratio) = split(" ", $next);
      $shaltout{$element}{energy}{$edge} = 1000*$energy;
      $shaltout{$element}{jump}{$edge}   = $ratio;
      next ELEM;
    };

  };
};
close $SHALT;

print "\n  Parsing lines file ";
$infile =  File::Spec -> catfile($thisdir, "cl_lines");
open my $LINES, $infile or die $!;
while (<$LINES>) {
  next if /^\s*\#/;
  next if /^\s*$/;
  chomp;
  my @line = split;
  my $el = lc( get_symbol($line[0]) );
  $shaltout{$el}{energy}{kalpha} = $line[1];
  $shaltout{$el}{energy}{kbeta}  = $line[2];
  $shaltout{$el}{energy}{lalpha} = $line[3];
  $shaltout{$el}{energy}{lbeta}  = $line[4];
};
close $LINES;

#use Data::Dumper;
#print Data::Dumper->Dump([\%shaltout],[qw(*shaltout)]);

print $/;
my $outfile = File::Spec -> catfile($thisdir, '..', 'Absorption', "shaltout.db");
if (-e $outfile) {
  print "  Removing stale database, $outfile.$/";
  unlink $outfile;
};
print "  Saving new database, $outfile.$/";
nstore(\%shaltout, $outfile) or die "can't store hash: $!\n";


sub identify_self {
  my @caller = caller;
  use File::Basename qw(dirname);
  return dirname($caller[1]);
};
