#!/usr/bin/perl -w
######################################################################
##  This program is copyright (c) 1999, 2011 Bruce Ravel
##  http://bruceravel.github.io/home
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
## This program generates the McMaster data from a flat text database
## for use with the Absorption::McMaster module.  The data is stored
## as a Storable binary database.  The data is stored in "network"
## order so it can be accessed over a network and across disparate
## platforms.
######################################################################
## Code:

use strict;
use Storable qw/nstore/;
use File::Spec;

my $cvs_info = '$Id: dat2st.PL,v 1.1 1999/05/20 17:47:43 bruce Exp $ ';
my $version = (split(' ', $cvs_info))[2] || "pre_release";

$| = 1;

my %mcmaster = ();
my $thisdir = &identify_self;

print "McMaster data conversion tool $version for Absorption 0.10$/";
$mcmaster{'nu'} = {'number'	    => '0',
		   'atomic_weight'  => '0',
		   'density'	    => '0',
		   'conversion'	    => '0',
		   'energy_k'	    => '0',
		   'energy_l1'	    => '0',
		   'energy_l2'	    => '0',
		   'energy_l3'	    => '0',
		   'energy_m'	    => '0',
		   'kalpha'	    => '0',
		   'kbeta'	    => '0',
		   'lalpha'	    => '0',
		   'lbeta'	    => '0',
		   'ljump_3'	    => '0',
		   'a_k'	    => [ '0', '0', '0', '0' ],
		   'a_l'	    => [ '0', '0', '0', '0' ],
		   'a_m'	    => [ '0', '0', '0', '0' ],
		   'a_n'	    => [ '0', '0', '0', '0' ],
		   'incoherent'	    => [ '0', '0', '0', '0' ],
		   'coherent'	    => [ '0', '0', '0', '0' ],
                   };

my $infile = File::Spec -> catfile($thisdir, "mcmaster.data");
open MCM, $infile or die $!;
my $firstline = <MCM>;
$mcmaster{'version'} = (split(' ', $firstline))[5] ?
  (split(' ', $firstline))[5] . " " . (split(' ', $firstline))[6] :
  "pre_release";
print "  Reading element";
while (<MCM>) {
  next if (/^\#/);		# skip comment lines
  next if (/^\s*$/);		# skip blank lines
  if (/^\s*([a-z]){1,2}/i) {	# first line in a record start with
                                # element symbol
    chomp;
    my @line = split;
    my $key = lc($line[0]);
    $mcmaster{$key}{'number'}	      = $line[1];
    $mcmaster{$key}{'atomic_weight'}  = $line[2];
    $mcmaster{$key}{'density'}	      = $line[3];
    $mcmaster{$key}{'conversion'}     = $line[4];
    (not ($line[1] % 5)) and print " $line[1]";

    ## line with edge energies
    $_ = <MCM>;
    chomp;
    @line = split;
    $mcmaster{$key}{'energy_k'}  = $line[0];
    $mcmaster{$key}{'energy_l1'} = $line[1];
    $mcmaster{$key}{'energy_l2'} = $line[2];
    $mcmaster{$key}{'energy_l3'} = $line[3];
    $mcmaster{$key}{'energy_m'}  = $line[4];

    ## line with line energies + ljump3
    $_ = <MCM>;
    chomp;
    @line = split;
    $mcmaster{$key}{'kbeta'}   = $line[0];
    $mcmaster{$key}{'lbeta'}   = $line[1];
    $mcmaster{$key}{'kalpha'}  = $line[2];
    $mcmaster{$key}{'lalpha'}  = $line[3];
    $mcmaster{$key}{'ljump_3'} = $line[4];

    ## line with k edge coefficients
    $_ = <MCM>;
    chomp;
    @line = split;
    $mcmaster{$key}{'a_k'} = [@line];

    ## line with l edge coefficients
    $_ = <MCM>;
    chomp;
    @line = split;
    $mcmaster{$key}{'a_l'} = [@line];

    ## line with m edge coefficients
    $_ = <MCM>;
    chomp;
    @line = split;
    $mcmaster{$key}{'a_m'} = [@line];

    ## line with n edge coefficients
    $_ = <MCM>;
    chomp;
    @line = split;
    $mcmaster{$key}{'a_n'} = [@line];

    ## line with incoherent coefficients
    $_ = <MCM>;
    chomp;
    @line = split;
    $mcmaster{$key}{'incoherent'} = [@line];

    ## line with coherent coefficients
    $_ = <MCM>;
    chomp;
    @line = split;
    $mcmaster{$key}{'coherent'} = [@line];

  };

};
close MCM;
print $/;
my $outfile = File::Spec -> catfile($thisdir, '..', 'Absorption', "mcmaster.db");
if (-e $outfile) {
  print "  Removing stale database, $outfile.$/";
  unlink $outfile;
};
print "  Saving new database, $outfile.$/";
nstore(\%mcmaster, $outfile) or die "can't store hash: $!\n";


sub identify_self {
  my @caller = caller;
  use File::Basename qw(dirname);
  return dirname($caller[1]);
};
