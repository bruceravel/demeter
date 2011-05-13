#!/usr/bin/perl

use warnings;
use strict;
use XML::Simple;
use Data::Dumper;
use File::Basename;
use List::Util qw(max);
use List::MoreUtils qw(any);

my $requiredby;
my %seen;
opendir(my $dh, ".");
my @xmllist = grep { m{xml\z} } sort {$a cmp $b} readdir($dh);
closedir $dh;

my @in_vender = qw(Test::Moose
		   Alien::wxWidgets
		   Params::Util
		   Sub::Uplevel
		   IO::String
		   Digest::SHA
		   YAML::Tiny
		   YAML
		   File::Remove
		   Test::Tester
		   Archive::Zip
		   Task::Weaken
		   File::Slurp
		   Test::Exception
		   HTML::Entities
		   Algorithm::Diff
		   Text::Diff
		   Test::NoWarnings
		   HTML::Tagset
		   Win32::Process
		 );

my @biglist = ();
foreach my $xml (@xmllist) {
  my @sublist = ();
  ++$seen{basename($xml, '.xml')};
  my $ref = XMLin("$xml");
  #print $xml, "  ", ref($ref->{dependency}), $/;
  next if (ref($ref->{dependency}) eq 'HASH');
  foreach my $item (@{$ref->{dependency}}) {
    if ($item->{depth} eq 0) {
      $requiredby = $item->{module};
      next;
    };
    next if ($item->{textresult} eq 'Core module');
    next if $seen{$item->{module}};
    $seen{$item->{module}} ||= 0;
    $seen{$item->{module}} = max($item->{depth}, $seen{$item->{module}});

    ## special cases ...
    next if any {$item->{module} eq $_} @in_vendor;

    push @sublist, [$item->{module}, $seen{$item->{module}}, $requiredby];
  };
  @sublist = sort {$b->[1] <=> $a->[1]} @sublist;
  push @biglist, @sublist;
};

foreach my $item (@biglist) {
  printf "%-30s  %d (%s)\n", $item->[0], $seen{$item->[0]}, $item->[2];
};

print "\n\nNote that Sub::Exporter must come before Dist::CheckConflicts\n";
