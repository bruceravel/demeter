#!/usr/bin/perl

use PDL;
use PDL::Filter::Linear;
use Demeter qw(:ui=screen :plotwith=gnuplot);

my $width = $ARGV[0] || 11;

my $data = Demeter::Data->new(file=>'../..//data/auo_noisy.xmu',
			      energy => '$1',
			      numerator => '$2',
			      denominator => 1,
			      ln => 0,
			     );

Demeter->po->set(emin=>-50, emax=>150, e_mu=>1, e_bkg=>0, e_norm=>0);
$data->plot('E');

my @x = $data->get_array('energy');
my @y = $data->get_array('xmu');

my $n = 11;
#my $b = new PDL::Filter::Gaussian($n,4); # 15 points, 2 std devn.
my $b = PDL::Filter::SavGol->new(11,2,2); # 15 points, 2 std devn.
print ref($b), $/;

my $pdl = PDL->new(\@y);
my ($sm, $corr) = $b->predict($pdl);
my @z = $sm->list;

splice(@x, 0, int(($n-1)/2));
@x = splice(@x, 0, $#x-int(($n-1)/2));

my $smoothed = $data->put(\@x, \@z, datatype=>'xmu', name=>'smoothed');
#my $smoothed=$data->boxcar($width);



#$data->align($smoothed);
$smoothed->e0($data);
#$smoothed->y_offset(-200);
$smoothed->plot('E');

$data->pause;

# # Savitzky-Golay (see Numerical Recipes)
# package PDL::Filter::SavGol;
# use PDL; use PDL::Basic; use PDL::Slices; use PDL::Primitive;
# use strict;

# @PDL::Filter::SavGol::ISA = qw/PDL::Filter::Linear/;

# # XXX Doesn't work
# sub new($$) {
#   my($type,$deg,$nleft,$nright) = @_;
#   my $npoints = $nright + $nleft + 1;
#   my $x = ((PDL->zeroes($npoints )->xvals) - $nleft)->float;
#   my $mat1 = ((PDL->zeroes($npoints,$deg+1)->xvals))->float;
#   my @gather;
#   for(0..$deg-1) {
#     (my $tmp = $mat1->slice(":,($_)")) .= ($x ** $_);
#     push @gather, $tmp;
#   }
#   my $b = pdl(\@gather);
#   my $t = $b->transpose x $b;
#   my $y = $t->inv x $b->transpose;
#   # Normalize to unit total
#   return PDL::Filter::Linear::new($type,{Weights => $y,
# 					 Point => $nleft});
# }
