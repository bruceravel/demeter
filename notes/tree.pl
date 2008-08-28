#/usr/bin/perl

use warnings;
use strict;

use Tree::Simple;
#use Tree::Simple::Visitor;
#use Tree::Simple::VisitorFactory;

# create a visitor instance
#my $visitor = Tree::Simple::Visitor->new();
#my $vf      = Tree::Simple::VisitorFactory->new();

my @list = (1 .. 50);		# list of atom indeces

# create a tree to visit
my $tree = Tree::Simple->new(Tree::Simple->ROOT);

## populate the first level of the tree -- i.e. the single scattering paths
foreach my $i (@list) {
  $tree->addChild(Tree::Simple->new($i));
};


## now populate successively deep levels of the tree -- each
## generation corresponds to a successively higher order of scattering
my @kids = $tree->getAllChildren;

## instead of the rand's, need to check the path length of the
## proposed path and compare it to rmax
foreach my $k (@kids) {

  ## these are the double scattering paths
  my $begin = $k->getNodeValue;
  foreach my $i (@list) {
    next if ($begin == $i); # avoid letting an atom be its own child
    next if (rand(1) < 0.75);
    #$k -> addChild(Tree::Simple->new(join(".", $begin, $i)));
    $k -> addChild(Tree::Simple->new($i));
  };

  my @grandkids = $k->getAllChildren;

  ## these are the triple scattering paths
  foreach my $g (@grandkids) {
    my $begin = $g->getNodeValue;
    #my $last = (split(/\./, $begin))[-1];
    foreach my $j (@list) {
      next if ($begin == $j); # avoid letting an atom be its own child
      next if (rand(1) < 0.75);
      #$g -> addChild(Tree::Simple->new(join(".", $begin, $j)));
      $g -> addChild(Tree::Simple->new($j));
    };
  };

};

## the traversal should create Path objects and throw them onto a
## storage area for degeneracy checking
$tree->traverse(\&printit);
## now we can destroy the tree

sub printit {
  my ($_tree) = @_;
  print "0" . full_path($_tree, q{}) . ".0\n";
}

## recursalicious
sub full_path {
  my ($_tree, $this) = @_;
  if (lc($_tree->getParent) eq 'root') {
    return q{};
  } else {
    return parentage($_tree->getParent, $_tree->getNodeValue())
         . "."
         . $_tree->getNodeValue();
  };
};
