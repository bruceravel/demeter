#!/usr/bin/perl

use Demeter qw(:fit :ui=screen);
use DateTime;

## run feff on FeS2
my $feff = Demeter::Feff->new(file=>'feff.inp', workspace=>'feff', screen=>0);
$feff -> make_workspace;
$feff -> rmax(4.6);
$feff -> run;


$feff->co->set_default('pathfinder', 'rank', 'kw2');
my $then = DateTime->now;
$feff   -> rank_paths;
my $now  = DateTime->now;
my $duration = $now->subtract_datetime($then);
printf("Ranking took around %s seconds\n", $duration->seconds);

use Term::ANSIColor qw(:constants);
print $feff->intrp({comment => BOLD.RED,
		    close   => RESET,
		    1       => BOLD.YELLOW,
		    2       => BOLD.GREEN,
		    0       => q{},
		   });
exit

open(my $O, '>', 'rank.dat');
Demeter->set_mode(screen=>0);
my @tests = (qw(area2_n height2_n chimag2_n zcwif));
print $O "\n#Normalized values\n#  index   " . join("     ", @tests) . "\n";
my $i=1;
foreach my $sp (@{ $feff->pathlist }) {
  printf $O " %4.4d  %8.2f   %8.2f   %8.2f  %8.2f\n",
    $i++, map {$sp->get_rank($_)} @tests;
};
close $O;
