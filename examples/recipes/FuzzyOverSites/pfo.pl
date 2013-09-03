#!/usr/bin/perl

use Demeter qw(:atoms :ui=screen :p=gnuplot);

#Demeter->co->set_default('pathfinder', 'fuzz', 0.05);
#Demeter->co->set_default('pathfinder', 'betafuzz', 6);

my $atoms = Demeter::Atoms->new(file=>'BaFe12O19.inp');
$atoms->set(rmax=>8, rpath=>5, ipot_style=>'tags');
my $bigfeff = Demeter::Feff::Aggregate->new(screen=>1);
$bigfeff->setup($atoms, 'Fe');
$bigfeff->run;

Demeter->co->set_default('pathfinder', 'rank', 'kw2');
$bigfeff->rank_paths('area2_n');


use Term::ANSIColor qw(:constants);
my $intrp_style = {comment => BOLD.WHITE,
		   close   => RESET,
		   1       => BOLD.YELLOW,
		   2       => BOLD.GREEN,
		   0       => q{},
		  };
print $/, $bigfeff->intrp($intrp_style, 3.1), $/;

my $i = 0;
Demeter->set_mode(screen=>0);
foreach my $sp (@{ $bigfeff->pathlist }) {
  $sp->feff->screen(0);
  ++$i;
  my $path = Demeter::Path -> new(parent=>$sp->feff, s02=>1, name=>"path $i", sp=>$sp)
    ->plot("r");
  last if $i == 10;
};

$bigfeff->pause;

$_->clean_workspace foreach (@{$bigfeff->parts});



