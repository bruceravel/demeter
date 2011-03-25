#!/usr/bin/perl

use strict;
use warnings;

$/ = "\n\n";
my @pm = ();
my @bsdll = ();
open (my $m, 'modules');	# ls -R -m --color=none > modules
while (<$m>) {
  chomp;
  my @list = split(" ", $_);
  my $dir = shift @list;
  $dir =~ s{\A\./lib/}{};	# sanitize the output of ls
  $dir =~ s{:\z}{};
  foreach my $item (@list) {
    $item =~ s{,\z}{};
    $item =~ s{\*\z}{};
    if ($item =~ m{\.pm\z}) {	# captue modules
      push @pm, join("/", $dir, $item);
    } elsif ($item =~ m{\.(?:bs|dll|ix|al)\z}) { # capture stuff from auto/
      push @bsdll, join("/", $dir, $item);
    };
  };
};
close $m;

foreach my $o (@pm) {
  $o =~ s{/}{::}g;
  $o =~ s{\.pm\z}{};
#  print "$o\n";
};

foreach my $o (@bsdll) {
  print "$o\n";
};
