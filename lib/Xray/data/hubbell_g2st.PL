#!/usr/bin/perl

## each of the element-specific data files is an html file wgotten
## from the NIST web site.  Parsing the file, in this context, is
## quite simple.  The relevant data is the only thing between
## <pre></pre> tags.  The parser then just looks for the opening <pre>
## and saves everything that looks like data.  The whole
## kit-n-kaboodle is then frozen to a Storable database.

## if the html files are not seen in the right place, this script will
## attempt to wget them from the NIST web site.

use warnings;
use strict;
use version;
use Chemistry::Elements qw(get_symbol);
use File::Spec;
use Storable qw/nstore/;
#use Data::Dumper;

my $version = qv("0.2.0");
print "Hubbell data conversion tool $version for Xray::Absorption\n";

my @one_minus_g = ();
my $thisdir = &identify_self;

#chdir "hubbell";
print "  Parsing element";
foreach my $i (1 .. 92) {

  my $z = get_symbol($i);
  my $fname = sprintf("z%2.2d.html.elem", $i);

  #unless (-e File::Spec->catfile($thisdir, "hubbell", $fname)) {
  #  print "\nwgetting $fname ... \n";
  #  `wget http://physics.nist.gov/PhysRefData/XrayMassCoef/ElemTab/$fname`;
  #  rename $fname, File::Spec->catfile($thisdir, "hubbell", $fname);
  #  print "wgot $fname\n";
  #};

  ($i % 5) or print " $i";	# status message
  ##print " ****  parsing $fname ...";
  my $this = File::Spec->catfile($thisdir, "hubbell", $fname);
  #`ls -l $this`;
  open(Z, $this) or die "could not open $this for reading";
  my $flag = 0;
  my @e = ();
  my @g = ();
  while (<Z>) {
    $flag = 1 if (/pre/i);
    next unless $flag;
    last if (/\/pre/i);
    if (/^\s*\d/) {
      my @line = split(" ", $_);
      push @e, $line[0]*10**6;
      push @g, $line[1]/$line[2];
      #printf "%8d  %.3f\n", $line[0]*10**6, $line[1]/$line[2];
    };
  };
  close Z;
  $one_minus_g[$i] = {energy => [@e], one_minus_g => [@g]};
  ##print "done!\n";
};
print $/;
#chdir "..";

#print Data::Dumper->Dump([\@one_minus_g], [qw(one_minus_g)]);


my $outfile = File::Spec -> catfile($thisdir, '..', 'Absorption', "hubbell_g.db");
if (-e $outfile) {
  print "  Removing stale database, $outfile.$/";
  unlink $outfile or die "could not remove old database $!";
};
print "  Saving new database, $outfile.$/";
nstore(\@one_minus_g, $outfile) or die "can't store array: $!\n";

sub identify_self {
  my @caller = caller;
  use File::Basename qw(dirname);
  return dirname($caller[1]);
};
