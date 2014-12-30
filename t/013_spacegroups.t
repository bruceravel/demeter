#!/usr/bin/perl

=for Copyright
 .
 Copyright (c) 2008-2015 Bruce Ravel (http://bruceravel.github.io/home).
 All rights reserved.
 .
 This file is free software; you can redistribute it and/or
 modify it under the same terms as Perl itself. See The Perl
 Artistic License.
 .
 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut

use Storable;
use Xray::Crystal;
use Test::More tests => 1300;

my $sg       = Xray::Crystal::SpaceGroup->new;
my $rhash    = retrieve($sg->database);

## 	 number      => ,             number in table
## 	 schoenflies => "_^",         Schoenflies notation
## 	 full        => "",           full Hermann-Maguin notation
##	 settings    => [ ba-c, cab, -cba, bca, a-cb], orthorhombic permutations
## 	 new_symbol  => "",           double glide plane symbol, cf. sec 1.3
##       thirtyfive  => "",           symbols from the 1935 edition

my $i = 0;
my ($groups, $tests) = 0;
foreach my $g (keys %$rhash) {
  next if ($g eq 'version');
  ++$groups;

  if (exists $rhash->{$g}->{number}) {
    my $this = $rhash->{$g}->{number};
    $sg->group($this);
    ok( $sg->group eq $g,  "$g: number -- input: $this   found: ".$sg->group);
    ++$tests;
  };

  if (exists $rhash->{$g}->{schoenflies}) {
    my $this = $rhash->{$g}->{schoenflies};
    $sg->group($this);
    ok( $sg->group eq $g,  "$g: schoenflies -- input: $this   found: ".$sg->group);
    (my $that = $this) =~ s/([cdost])(_[12346dihsv]{1,2})(\^[0-9]{1,2})/$1$3$2/;
    $sg->group($that);
    ok( $sg->group eq $g,  "$g: schoenflies reversed  -- input: $that   found: ".$sg->group);
    ++$tests;
  };

  if (exists $rhash->{$g}->{full}) {
    my $this = $rhash->{$g}->{full};
    $sg->group($this);
    ok( $sg->group eq $g,  "$g: full  -- input: $this   found: ".$sg->group);
    ++$tests;
  };

  if (exists $rhash->{$g}->{new_symbol}) {
    my $this = $rhash->{$g}->{new_symbol};
    $sg->group($this);
    ok( $sg->group eq $g, "$g: new_symbol -- input: $this   found: ".$sg->group);
    ++$tests;
  };

  if (exists $rhash->{$g}->{thirtyfive}) {
    my $this = $rhash->{$g}->{thirtyfive};
    $sg->group($this);
    ok( $sg->group eq $g,  "$g: thirtyfive -- input: $this   found: ".$sg->group);
    ++$tests;
  };

  if (exists $rhash->{$g}->{settings}) {
    my $rlist = $rhash->{$g}->{settings};
    my $i = 0;
    foreach my $this (@$rlist) {
      ++$i;
      $sg->group($this);
    SKIP: {
	skip "(c -4 2 g) is a known failure", 1 if ($sg->group eq 'c -4 2 g2');
	ok( $sg->group eq $g,  "$g: setting $i -- input: $this   found: ".$sg->group);
      };
      ++$tests;
    };
  };

  if (exists $rhash->{$g}->{short}) {
    my $rlist = $rhash->{$g}->{short};
    my $i = 0;
    foreach my $this (@$rlist) {
      ++$i;
      $sg->group($this);
      ok( $sg->group eq $g,  "$g: short $i -- input: $this   found: ".$sg->group);
      ++$tests;
    };
  };

  if (exists $rhash->{$g}->{shorthand}) {
    my $rlist = $rhash->{$g}->{shorthand};
    my $i = 0;
    foreach my $this (@$rlist) {
      ++$i;
      $sg->group($this);
      ok( $sg->group eq $g,  "$g: shorthand $i -- input: $this   found: ".$sg->group);
      ++$tests;
    };
  };

};

foreach my $this ("   p m -3 m", "pm3m", "p m3m ", "pm-3m", "pm		3m", "p   m   3    m") {
  $sg->group($this);
  ok( $sg->group eq "p m -3 m",  "p m -3 m: spaces ($this|".$sg->group."|)");
  ++$tests;
};


ok( $groups == 230,  "Correct number of groups.  ($groups, should be 230)");
ok( $tests  == 1068, "Correct number of symbols.  ($tests, should be 1068)");

1;
