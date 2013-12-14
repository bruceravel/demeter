#!/usr/bin/perl

use Demeter qw(:fit :ui=screen);
use DateTime;

Demeter->po->kweight(3);

## run feff on FeS2
my $feff = Demeter::Feff->new(file=>'feff.inp', workspace=>'feff', screen=>0);
$feff -> make_workspace;
$feff -> rmax(4.6);
$feff -> run;

my $hash = {kmin=>3, kmax=>12, rmin=>1, rmax=>4};

$feff->rank_paths($ARGV[0]||'feff', $hash);
use Term::ANSIColor qw(:constants);
print $feff->intrp({comment => BOLD.RED,
		    close   => RESET,
		    1       => BOLD.YELLOW,
		    2       => BOLD.GREEN,
		    0       => q{},
		   });
exit;

$feff->rank_paths(['akc', 'feff', 'sqkc', 'aknc'], $hash);
open(my $O, '>', 'rank.dat');
Demeter->set_mode(screen=>0);
my @tests = (qw(feff akc sqkc aknc));
print $O "\n#Normalized values\n#  index   " . join("       ", @tests) . "\n";
my $i=1;
foreach my $sp (@{ $feff->pathlist }) {
  printf $O " %4.4d  %8.2f   %8.2f   %8.2f  %8.2f\n",
    $i++, map {$sp->get_rank($_)} @tests;
};
close $O;
