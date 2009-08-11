#!/usr/bin/perl

use warnings;
use strict;
use autodie qw(open close);
use File::Path;
use List::Util qw(sum);
use List::MoreUtils qw(pairwise);
use Text::Template;


use Ifeffit qw(put_scalar get_scalar ifeffit);
use Readonly;
Readonly my $X => 1;
Readonly my $Y => 2;
Readonly my $Z => 3;

my $dnafile = 'thymidine.pdb';

die "specify an amino acid [-a -c -g -t]\n" if (not $dnafile);

## atoms positions: thymidine
## 18,20,12: C on pyrimidine
## 13,15,16: N on pyrimidine
##  8,10,11: C on sugar
##  6, 7,11: O on sugar

Readonly my $L => $ARGV[1] || 13;
Readonly my $C => $ARGV[0] || 15;
Readonly my $R => $ARGV[2] || 16;

### indeces CLR:  $C,  $L,  $R

my @sites = ();
open (my $XYZ, "thymidine.pdb");
while (<$XYZ>) {
  chomp;
  next if m{\A\s*\z};
  next if not m{\AHETATM};
  my @this = split(" ", $_);
  $this[2] = substr($this[2], 0, 1);
  push @sites, [@this[2,5,6,7]];
};
close $XYZ;

my @left  = ($sites[$L]->[$X], $sites[$L]->[$Y], $sites[$L]->[$Z]);
my @c     = ($sites[$C]->[$X], $sites[$C]->[$Y], $sites[$C]->[$Z]);
my @right = ($sites[$R]->[$X], $sites[$R]->[$Y], $sites[$R]->[$Z]);
### center: @c

### Define vectors (left to center) and (right to center)
my @vec1 = diff(\@c, \@left);
my @vec2 = diff(\@c, \@right);

### Define the plane containing those three atoms
my @cross = cross(\@vec1, \@vec2);
### Cross product:  sprintf("%.4f %.4f %.4f", @cross)

my $dot = dot(\@cross, \@vec1);
### normal dot vec1 should be 0: sprintf("%.4f", $dot)
$dot = dot(\@cross, \@vec2);
### normal dot vec2 should be 0: sprintf("%.4f", $dot)


#my @hat = pairwise { ($a + $b) / 2 } @vec1, @vec2;
my @hat = diff(\@vec2, \@vec1);
my $hatnorm = norm(@hat);
@hat = pairwise { $a + 2.04 * $b/$hatnorm } @c, @hat;
### guess for Hg position: sprintf("%.4f %.4f %.4f", @hat)

### dd, dot, dc should be 0, dleft = dright
my $iffscript =<<"EOH"

guess(a=$hat[0], b=$hat[1], c=$hat[2])
def dot    = (a-$c[0])*$cross[0] + (b-$c[1])*$cross[1] + (c-$c[2])*$cross[2]
def dc     = sqrt( (a-$c[0]    )**2 + (b-$c[1]    )**2 + (c-$c[2]    )**2 ) - 2.04
def dleft  = sqrt( (a-$left[0] )**2 + (b-$left[1] )**2 + (c-$left[2] )**2 )
def dright = sqrt( (a-$right[0])**2 + (b-$right[1])**2 + (c-$right[2])**2 )
def dd     = dleft - dright
def d.min  = (dd**2 + dc**2 + dot**2) * indarr(12)

minimize d.min

show d.min a b c dd dot dc dleft dright

EOH
;
ifeffit($iffscript);

### write output
mkpath("$C") if (not -d "$C");
write_xyz(\@sites, $C);
write_inp(\@sites, $C);


##-- output files
sub write_xyz {
  my ($rsites, $center) = @_;
  open HGA, ">$center/list.xyz";
  print HGA $#{$rsites}+2, "\n";
  print HGA "Hg1_amp.xyz\n";
  foreach my $s (@$rsites) {
    printf HGA "%-2s        %8.5f       %8.5f       %8.5f\n", @$s;
  };
  printf HGA "Hg        %8.5f       %8.5f       %8.5f\n",
    get_scalar("a"), get_scalar("b"), get_scalar("c");
  close HGA;
  print " wrote \"$center/list.xyz\"\n";
};

sub write_inp {
  my ($rsites, $center) = @_;
  my $template = Text::Template->new(SOURCE => 'feff6.tmpl')
    or die "Couldn't construct template: $Text::Template::ERROR";
  my @list = ();

  my @central = (get_scalar("a"), get_scalar("b"), get_scalar("c"));
  foreach my $s (@$rsites) {
    my @this = ($s->[1], $s->[2], $s->[3]);
    my $d = sprintf("%.5f", dist(\@this, \@central));
    push @list, [@$s, $d];
  };

  unshift @list, ["Hg", @central, 0];
  my $result = $template->fill_in(HASH => {
					   center => $center,
					   sites  => \@list,
					   ipot   => {Hg=>0, O=>1, N=>2, C=>3, P=>4},
					  });
  open HGA, ">$center/withHg.inp";
  print HGA $result;
  close HGA;
  print " wrote \"$center/withHg.inp\"\n";
};


##-- Vector algebra

sub diff {
  my ($r1, $r2) = @_;
  return pairwise {$a - $b} @$r1, @$r2;
};
sub dist {
  my ($r1, $r2) = @_;
  return sqrt( sum( pairwise { ($a-$b)**2 } @$r1, @$r2 ) );
};
sub cross {
  my ($r1, $r2) = @_;
  return ($r1->[1]*$r2->[2] - $r1->[2]*$r2->[1], ##(a1b2 − a2b1,
	  $r1->[2]*$r2->[0] - $r1->[0]*$r2->[2], ## a2b0 − a0b2,
	  $r1->[0]*$r2->[1] - $r1->[1]*$r2->[0]	 ## a0b1 − a1b0)
	 );
};
sub dot {
  my ($r1, $r2) = @_;
  return sum( pairwise { $a*$b } @$r1, @$r2 );
};
sub norm {
  my @vec = @_;
  return sqrt( sum( map { $_**2 } @vec ) );
};
