#!/usr/bin/perl -I/home/bruce/codes/demeter/lib

use warnings;
use strict;
use Storable;

use Xray::Crystal::Cell;

my $cell     = Xray::Crystal::Cell->new;
my $database = $cell->database;
my $rhash    = retrieve($database);


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
    my @list = $cell->canonicalize_symbol($this);
    print "$g: number ($this)\n" if ($list[0] ne $g);
    ++$tests;
  };

  if (exists $rhash->{$g}->{schoenflies}) {
    my $this = $rhash->{$g}->{schoenflies};
    my @list = $cell->canonicalize_symbol($this);
    print "$g: schoenflies ($this)\n" if ($list[0] ne $g);
    (my $that = $this) =~ s/([cdost])(_[12346dihsv]{1,2})(\^[0-9]{1,2})/$1$3$2/;
    @list = $cell->canonicalize_symbol($this);
    print "$g: schoenflies reversed ($this  $that)\n" if ($list[0] ne $g);
    ++$tests;
  };

  if (exists $rhash->{$g}->{full}) {
    my $this = $rhash->{$g}->{full};
    my @list = $cell->canonicalize_symbol($this);
    print "$g: full ($this)\n" if ($list[0] ne $g);
    ++$tests;
  };

  if (exists $rhash->{$g}->{new_symbol}) {
    my $this = $rhash->{$g}->{new_symbol};
    my @list = $cell->canonicalize_symbol($this);
    print "$g: new_symbol ($this)\n" if ($list[0] ne $g);
    ++$tests;
  };

  if (exists $rhash->{$g}->{thirtyfive}) {
    my $this = $rhash->{$g}->{thirtyfive};
    my @list = $cell->canonicalize_symbol($this);
    print "$g: thirtyfive ($this)\n" if ($list[0] ne $g);
    ++$tests;
  };

  if (exists $rhash->{$g}->{settings}) {
    my $rlist = $rhash->{$g}->{settings};
    my $i = 0;
    foreach my $this (@$rlist) {
      ++$i;
      my @list = $cell->canonicalize_symbol($this);
      print "$g: setting $i ($this)\n" if ($list[0] ne $g);
      ++$tests;
    };
  };

  if (exists $rhash->{$g}->{short}) {
    my $rlist = $rhash->{$g}->{short};
    my $i = 0;
    foreach my $this (@$rlist) {
      ++$i;
      my @list = $cell->canonicalize_symbol($this);
      print "$g: short $i ($this)\n" if ($list[0] ne $g);
      ++$tests;
    };
  };

  if (exists $rhash->{$g}->{shorthand}) {
    my $rlist = $rhash->{$g}->{shorthand};
    my $i = 0;
    foreach my $this (@$rlist) {
      ++$i;
      my @list = $cell->canonicalize_symbol($this);
      print "$g: shorthand $i ($this)\n" if ($list[0] ne $g);
      ++$tests;
    };
  };

};

foreach my $this ("   p m -3 m", "pm3m", "p m3m", "pm-3m", "pm		3m", "p   m   3    m") {
  my @list = $cell->canonicalize_symbol($this);
  print "p m -3 m: spaces ($this  |$list[0]|)\n" if ($list[0] ne "p m -3 m");
  ++$tests;
};


print "Wrong number of groups!  ($groups, should be 230)\n"  if ($groups != 230);
print "Wrong number of symbols!  ($tests, should be 1068)\n" if ($tests  != 1068);

1;
