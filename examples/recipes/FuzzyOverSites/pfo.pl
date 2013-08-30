#!/usr/bin/perl

use Demeter qw(:atoms :ui=screen :p=gnuplot);


my $atoms = Demeter::Atoms->new(file=>'BaFe12O19.inp');
$atoms->set(rmax=>8, rpath=>5);
my $bigfeff = Demeter::Feff::Aggregate->new;
$bigfeff->setup($atoms, 'Fe');
$bigfeff->run;


use Term::ANSIColor qw(:constants);
my $intrp_style = {comment => BOLD.WHITE,
		   close   => RESET,
		   1       => BOLD.YELLOW,
		   2       => BOLD.GREEN,
		   0       => q{},
		  };
print $bigfeff->intrp($intrp_style, 3.1);

my $i = 0;
foreach my $sp (@{ $bigfeff->pathlist }) {
  $sp->feff->screen(0);
  ++$i;
  Demeter::Path -> new(parent=>$sp->feff, name=>"path $i", sp=>$sp) -> plot("r");
  last if $i == 10;
};

$bigfeff->pause;

$_->clean_workspace foreach (@{$bigfeff->parts});



