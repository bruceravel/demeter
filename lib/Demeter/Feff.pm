package Demeter::Feff;

=for Copyright
 .
 Copyright (c) 2006-2009 Bruce Ravel (bravel AT bnl DOT gov).
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

use autodie qw(open close);

use Moose;
extends 'Demeter';
use MooseX::AttributeHelpers;
use Demeter::StrTypes qw( AtomsEdge FeffCard );
use Demeter::NumTypes qw( Natural NonNeg PosInt );
with 'Demeter::Feff::Paths';
with 'Demeter::Feff::Sanity';

use Compress::Zlib;
use Cwd;
use File::Path;
use File::Spec;
#use File::Temp qw(tempdir);
use List::Util qw(sum);
use List::MoreUtils qw(any false notall);
use Regexp::List;
use Regexp::Optimizer;
use Tree::Simple;
use Heap::Fibonacci;
use Ifeffit;
use Readonly;
Readonly my $NLEGMAX      => 4;
Readonly my $CTOKEN       => '+';
Readonly my $ETASUPPRESS  => 1;
Readonly my $FUZZ_DEF     => 0.01;
Readonly my $BETAFUZZ_DEF => 3;
Readonly my $SEPARATOR    => '[ \t]*[ \t=,][ \t]*';

my @leglength = ();
my $shortest = 100000000;

my $opt  = Regexp::List->new;


has 'file'        => (is => 'rw', isa => 'Str',  default => q{},
		      trigger => sub{my ($self, $new) = @_; $self->rdinp if $new} );
has 'sites' => (
		metaclass => 'Collection::Array',
		is        => 'rw',
		isa       => 'ArrayRef',
		default   => sub { [] },
		provides  => {
			      'push'  => 'push_sites',
			      'pop'   => 'pop_sites',
			      'clear' => 'clear_sites',
			     }
	       );
has 'potentials' => (
		     metaclass => 'Collection::Array',
		     is        => 'rw',
		     isa       => 'ArrayRef',
		     default   => sub { [] },
		     provides  => {
				   'push'  => 'push_potentials',
				   'pop'   => 'pop_potentials',
				   'clear' => 'clear_potentials',
				  }
		    );
has 'titles' => (
		 metaclass => 'Collection::Array',
		 is        => 'rw',
		 isa       => 'ArrayRef',
		 default   => sub { [] },
		 provides  => {
			       'push'  => 'push_titles',
			       'pop'   => 'pop_titles',
			       'clear' => 'clear_titles',
			      }
		);
has 'absorber' => (
		   metaclass => 'Collection::Array',
		   is        => 'rw',
		   isa       => 'ArrayRef',
		   default   => sub { [] },
		   provides  => {
				 'push'  => 'push_absorber',
				 'pop'   => 'pop_absorber',
				 'clear' => 'clear_absorber',
				}
		  );
has 'abs_index'    => (is=>'rw', isa =>  Natural,   default => 0);
has 'edge'         => (is=>'rw', isa =>  AtomsEdge, default => 'K'); # 1-4 or K-L3
has 's02'          => (is=>'rw', isa =>  NonNeg,    default => 1);   # positive float
has 'rmax'         => (is=>'rw', isa =>  NonNeg,    default => 0);   # positive float
has 'nlegs'        => (is=>'rw', isa =>  PosInt,    default => 4);   # integer < 7
has 'rmultiplier'  => (is=>'rw', isa =>  NonNeg,    default => 1);   # positive float
has 'pcrit'        => (is=>'rw', isa =>  NonNeg,    default => 0);   # positive float
has 'ccrit'        => (is=>'rw', isa =>  NonNeg,    default => 0);   # positive float
has 'othercards' => (
		     metaclass => 'Collection::Array',
		     is        => 'rw',
		     isa       => 'ArrayRef',
		     default   => sub { [] },
		     provides  => {
				   'push'  => 'push_othercards',
				   'pop'   => 'pop_othercards',
				   'clear' => 'clear_othercards',
				  }
		    );
has 'workspace'    => (is=>'rw', isa => 'Str', default => q{}); # valid directory
has 'miscdat'      => (is=>'rw', isa => 'Str', default => q{});
has 'yaml'         => (is=>'rw', isa => 'Str', default => q{},
		       trigger => sub{my ($self, $new) = @_; $self->deserialize if $new} );

has 'fuzz'         => (is=>'rw', isa =>  NonNeg,    default => 0);
has 'betafuzz'     => (is=>'rw', isa =>  NonNeg,    default => 0);
has 'eta_suppress' => (is=>'rw', isa => 'Bool',     default => 0);

		       ## result of pathfinder
has 'pathlist' => (		# list of ScatteringPath objects
		   metaclass => 'Collection::Array',
		   is        => 'rw',
		   isa       => 'ArrayRef',
		   default   => sub { [] },
		   provides  => {
				 'push'  => 'push_pathlist',
				 'pop'   => 'pop_pathlist',
				 'clear' => 'clear_pathlist',
				}
		  );
has 'npaths'       => (is=>'rw', isa =>  Natural,   default => 0);

		       ## reporting and processing
has 'screen'       => (is=>'rw', isa => 'Bool', default => 1);
has 'buffer'       => (is=>'rw', isa => 'Bool', default => 0);
has 'iobuffer' => (
		   metaclass => 'Collection::Array',
		   is        => 'rw',
		   isa       => 'ArrayRef[Str]',
		   default   => sub { [] },
		   provides  => {
				 'push'  => 'push_iobuffer',
				 'pop'   => 'pop_iobuffer',
				 'clear' => 'clear_iobuffer',
				}
		  );
has 'save' => (is=>'rw', isa => 'Bool', default => 1);

sub BUILD {
  my ($self, @params) = @_;
  $self->mo->push_Feff($self);
};
sub DEMOLISH {
  my ($self) = @_;
  $self->alldone;
};

sub alldone {
  my ($self) = @_;
  $self->clean_workspace if not $self->save;
};

sub central {
  my ($self) = @_;
  return @{ $self->absorber };
};

sub nsites {
  my ($self) = @_;
  return $#{ $self->sites };
};

=for Explanation
  site_tag
    A feff.inp file formatted by a normal atoms template file will
    have a site tag as the 5th column in the atoms list.  If that is
    absent, the potentials list is used to make that tag.  If that
    potential has a tag (3rd column), that will be used.  The fall
    back is the element symbol for the potential (2nd column via
    Chemistry::Elements::get_symbol)
    .
    The argument to site_tag is for a list starting at 0.

=cut

sub site_tag {
  my ($self, $a) = @_;
  my @sites  = @{ $self->sites };
  my @ipots  = @{ $self->potentials };
  my $i = $sites[$a]->[3];
  my $tag = $sites[$a]->[4] || $ipots[$i]->[2] || get_symbol($ipots[$i]->[1]);
  return $tag;
};

sub rdinp {
  my ($self) = @_;
  my $file = $self->file;
  my $mode = q{};
  open (my $INP, $file);
  while (<$INP>) {
    chomp;
    last if (/^\s*end/i);
    next if (/^\s*$/);	# blank line
    next if (/^\s*\*/);	# commented line
    my @line = split(/$SEPARATOR/, $_);
    shift @line if ($line[0] =~ m{^\s*$});
    if (is_FeffCard($line[0])) {
      #print "elsewhere: $1 $_\n";
      $mode = q{};
      my $thiscard = lc($line[0]);
    CARDS: {			# rectify the card names
	$thiscard = 'atoms',	    last CARDS if ($thiscard =~ m{\Aato});
	$thiscard = 'potentials',   last CARDS if ($thiscard =~ m{\Apot});
	$thiscard = 'titles',	    last CARDS if ($thiscard =~ m{\Atit});
	$thiscard = 'hole',	    last CARDS if ($thiscard =~ m{\Ahol});
	$thiscard = 'edge',	    last CARDS if ($thiscard =~ m{\Aedg});
	$thiscard = 's02',	    last CARDS if ($thiscard =~ m{\As02});
	$thiscard = 'rmax',	    last CARDS if ($thiscard =~ m{\Ar(?:ma|pa)});
	$thiscard = 'rmultiplier',  last CARDS if ($thiscard =~ m{\Armu});
	$thiscard = 'nlegs',	    last CARDS if ($thiscard =~ m{\Anle});
	$thiscard = 'criteria',     last CARDS if ($thiscard =~ m{\Acri});
	                            last CARDS if ($thiscard =~ m{\A(?:con|pri)}); ## CONTROL and PRINT are under demeter's control
	$self -> push_othercards($_);  ## pass through all other cards
      };

      ##print $thiscard, $/;
      ## dispatch the card values
      $mode = $thiscard                                if ($thiscard =~ m{(?:atoms|potentials)});
      $self->$thiscard($line[1])                       if ($thiscard =~ m{(?:edge|nlegs|r(?:max|multiplier)|s02)});
      $self->set(edge  => $line[1], s02   => $line[2]) if ($thiscard eq 'hole');
      $self->set(pcrit => $line[1], ccrit => $line[2]) if ($thiscard eq 'criteria');
      $self->_title($_)                                if ($thiscard eq 'titles');

    } elsif ($mode eq 'atoms') {
      #print "atoms: $_\n";
      my @coords = $self->_site($_);
      if ($coords[4] == 0) {
	$self->set(absorber  => [@coords[1..3]],
		   abs_index => $coords[0]);
      };
    } elsif ($mode eq 'potentials') {
      #print "potentials: $_\n";
      $self->_ipot($_);
    }
  };
  close $INP;

  my %problems = (used_not_defined     => 0,
		  defined_not_used     => 0,
		  no_absorber          => 0,
		  multiple_absorbers   => 0,
		  used_ipot_gt_7       => 0,
		  defined_ipot_gt_7    => 0,
		  rmax_outside_cluster => 0,

		  errors               => [],
		  warnings             => [],
		 );
  ## sanity checks on input data
  $self->S_check_ipots(\%problems);
  $self->S_check_rmax(\%problems);
  #use Data::Dumper;
  #print Data::Dumper->Dump([\%problems],[qw(*problems)]);
  ##warnings:
  if (any {$problems{$_}} qw(rmax_outside_cluster)) {
    carp("The following warnings were issued while reading $file:\n  "
	 . join("\n  ", @{$problems{warnings}})
	 . $/ . $/);
  };
  ## errors:
  my $stop = 0;
  foreach my $k (keys %problems) {
    next if (any {$k eq $_} (qw(rmax_outside_cluster warnings errors)));
    $stop += $problems{$k};
  };
  croak("The following errors were found in $file:\n  "
	. join("\n  ", @{$problems{errors}})
	. $/) if $stop;
  return $self;
};

sub _site {
  my ($self, $line) = @_;
  my @entries = split(/$SEPARATOR/, $line);
  shift @entries if ($entries[0] =~ m{^\s*$}); # $
  my $index = $self->push_sites([@entries[0..4]]) - 1;
  my @return_array = ($index, @entries[0..3]);
  push(@return_array, $entries[4]) if (exists($entries[4]) and ($entries[4] !~ m{\A\s*\z}));
  return @return_array;
};
sub _ipot {
  my ($self, $line) = @_;
  my @entries = (q{}, q{}, q{});
  @entries = split(/$SEPARATOR/, $line);
  shift @entries if ($entries[0] =~ m{^\s*$}); # $
  $self->push_potentials([@entries[0..2]]);
  return @entries[0..2];
};
sub _title {
  my ($self, $line) = @_;
  $line =~ s{\A\s+TITLE\s+}{};
  $self->push_titles($line);
  return $line;
};

sub make_workspace {
  my ($self) = @_;
  mkpath($self->workspace) if (! -d $self->workspace);
  return $self;
};

sub clean_workspace {
  my ($self) = @_;
  rmtree($self->workspace) if (-d $self->workspace);
  return $self;
};

sub check_workspace {
  my ($self) = @_;
  return 0 if ($self->workspace and (-d $self->workspace));
  croak <<EOH

Feff is sort of an old-fashioned program.  It reads from a fixed input
file and writes fixed output files.  All this needs to happen in a
specified directory.

You must explicitly establish a workspace for this Feff calculation:
  \$feff->make_workspace("/path/to/workspace/")

EOH
  ;
};

sub potph {
  my ($self) = @_;
  ##verify_feff_processing_hash($self);
  $self->check_workspace;

  ## write a feff.inp for the first module
  $self->make_feffinp("potentials");

  ## run feff to generate phase.bin
  $self->run_feff;

  ## slurp misc.dat into this object
  {
    local( $/ );
    my $miscdat = File::Spec->catfile($self->get("workspace"), "misc.dat");
    open( my $fh, $miscdat );
    $self->miscdat(<$fh>);
    unlink $miscdat if not $self->save;
  };

  ## clean up from this feff run
  unlink File::Spec->catfile($self->get("workspace"), "feff.run");
  unlink File::Spec->catfile($self->get("workspace"), "feff.inp")
    if not $self->save;

  return $self;
};
sub genfmt {
  my ($self, @list_of_path_indeces) = @_;
  @list_of_path_indeces = (1 .. $self->npaths) if not @list_of_path_indeces;
  ##verify_feff_processing_hash($self);
  $self->check_workspace;
  ## verify that phase.bin has been written to workspace
  my $phbin = File::Spec->catfile($self->workspace, 'phase.bin');
  $self->potph if not -e $phbin;

  ## generate a paths.dat file from the list of ScatteringPath objects
  $self->pathsdat(@list_of_path_indeces);

  ## write a feff.inp for the first module
  $self->make_feffinp("genfmt");

  ## run feff to generate feffNNNN.dat files
  $self->run_feff;

  ## clean up from this feff run
  unlink File::Spec->catfile($self->workspace, "feff.run");
  unlink File::Spec->catfile($self->workspace, "nstar.dat");
  if (not $self->save) {
    unlink File::Spec->catfile($self->workspace, "feff.inp");
    unlink File::Spec->catfile($self->workspace, "files.dat");
  };
  return $self;
};
sub _pathsdat_head {
  my ($self, $prefix) = @_;
  $prefix ||= q{};
  my $header = q{};
  foreach my $t (@ {$self->titles} ) { $header .= "$prefix " . $t . "\n" };
  $header .= $prefix . " This paths.dat file was written by Demeter " . $self->version . "\n";
  $header .= sprintf("%s Distance fuzz = %.4f Angstroms\n", $prefix, $self->fuzz);
  $header .= sprintf("%s Angle fuzz = %.4f degrees\n",      $prefix, $self->betafuzz);
  $header .= sprintf("%s Suppressing eta: %s\n",            $prefix, $self->yesno("eta_suppress"));
  $header .= $prefix . " " . "-" x 79 . "\n";
  return $header;
};
sub pathsdat {
  my ($self, @paths) = @_;
  @paths = (1 .. $self->npaths) if not @paths;
  my @list_of_paths = @{ $self->pathlist };
  my $workspace = $self->workspace;
  $self->check_workspace;

  my $pd = File::Spec->catfile($workspace, "paths.dat");
  open my $PD, ">".$pd;
  print $PD $self->_pathsdat_head;

  foreach my $i (@paths) {
    my $p = $list_of_paths[$i-1];
    printf $PD $p->pathsdat(index=>$i);
  };

  close $PD;
  return $self;
};
sub make_one_path {
  my ($self, $sp) = @_;
  my $workspace = $self->workspace;
  $self->check_workspace;

  my $pd = File::Spec->catfile($workspace, "paths.dat");
  open my $PD, ">".$pd;
  print $PD $self->_pathsdat_head;
  print $PD $sp  -> pathsdat(index=>$self->co->default('pathfinder', 'one_off_index'));
  close $PD;
  return $self;
};

#   sub verify_feff_processing_hash {
#     my ($self) = @_;
#     $$rhash{screen} ||= 0;
#     $$rhash{buffer} ||= q{};
#     $$rhash{buffer}   = q{} if ($$rhash{buffer} and
# 				(ref($$rhash{buffer}) !~ m{ARRAY|SCALAR}));
#     $$rhash{save}   ||= 0;
#     return 1;
#   };


##----------------------------------------------------------------------------
## pathfinder

sub pathfinder {
  my ($self) = @_;
  my $config = $self->co;
  $self -> eta_suppress($config->default("pathfinder", "eta_suppress"));
  $self -> report("=== Preloading distances\n");
  $self -> _preload_distances;
  $self -> report("=== Cluster contains " . $self->nsites . " atoms\n");
  my $tree          = $self->_populate_tree;
  my $heap          = $self->_traverse_tree($tree);
  #exit;
  undef $tree;
  my @list_of_paths = $self->_collapse_heap($heap);
  undef $heap;
  ##$_->details foreach (@list_of_paths);
  $self->set(pathlist=>\@list_of_paths, npaths=>$#list_of_paths+1);
  return $self;
};

=for Explanation
  .
    _populate_tree
  .
    Single Scattering Paths
   -------------------------
    populate the first level of the tree with each atom that is not
    the central atom.  in the traversal of the tree, each
    visitation that stops at this level of the tree represents a
    single scattering path (with the implicit return to the
    absorber at the root of the tree)
  .
  .
    Double Scattering Paths
   -------------------------
    populate the second level of the tree with each atom that is
    not the same as its parent.  in the traversal of the tree, each
    visitation that stops at this level of the tree represents a
    double scattering path
  .
  .
    Triple Scattering Paths
   -------------------------
    populate the third level of the tree with each atom that is not
    the same as its parent in the second level and is not the
    absorber.  in the traversal of the tree, each visitation that
    stops at this level of the tree represents a triple scattering
    path

=cut
sub _populate_tree {
  my ($self) = @_;
  my @central = $self->central;
  my ($cindex, $rmax)  = $self->get(qw{abs_index rmax});
  my $rmax2 = 2*$rmax;
  ##print join(" ", $rmax, $cindex, @central), $/;
  my @sites = @{ $self->sites };
  #my @faraway = (); # use this to prune off atoms farther than Rmax away
  my $natoms = 0;

  my $outercount = 0;
  my $innercount = 0;
  my $freq     = $self->co->default("pathfinder", "tree_freq");
  my $pattern  = "(%12d nodes)";

  $self->report("=== Populating Tree (. = $freq nodes added to the tree;  + = " . $freq*20 . " nodes considered)\n    ");
  # create a tree to visit.  the root represents the absorber
  my $tree = Tree::Simple->new(Tree::Simple->ROOT);

  ##
  ## Single Scattering Paths
  my $ind = -1;
  foreach my $s (@sites) {
    ++$ind;
    ++$outercount;
    $self->click('+') if not ($outercount % ($freq*20));
    next if ($ind == $cindex); # exclude absorber from this generation of the tree
    next if ($leglength[$cindex][$ind] > $rmax);
    ++$natoms;
    ++$innercount;
    $self->click('.') if not ($innercount % $freq);
    $tree->addChild(Tree::Simple->new($ind));
  };
  if ($self->get('nlegs') == 2) {
    $self->report(sprintf("\n    (contains %d nodes from the %d atoms within %.3g Ang.)\n",
			  $tree->size, $natoms, $rmax)); # (false {$_} @faraway)
    return $tree;
  };

  ##
  ## Double Scattering Paths
  my @kids = $tree->getAllChildren;
  foreach my $k (@kids) {
    ## these represent the double scattering paths
    my $thiskid = $k->getNodeValue;
    my $ind = -1;
    foreach my $s (@sites) {
      ++$ind;
      ++$outercount;
      $self->click('+') if not ($outercount % ($freq*20));
      next if ($leglength[$cindex][$ind] > $rmax); # prune distant atoms
      next if ($thiskid == $ind); # avoid same atom twice
      next if (($self->get('nlegs') == 3) and ($ind  == $cindex)); # exclude absorber from this generation
      next if (_length($cindex, $thiskid, $ind, $cindex) > $rmax2);	     # prune long paths from the tree
      ++$innercount;
      $self->click('.') if not ($innercount % $freq);
      $k->addChild(Tree::Simple->new($ind));
    };
  };
  if ($self->get('nlegs') == 3) {
    $self->report(sprintf("\n    (contains %d nodes from the %d atoms within %.3g Ang.)\n",
			  $tree->size, $natoms, $rmax));
    return $tree;
  };


  ##
  ## Triple Scattering Paths
  @kids = $tree->getAllChildren;
  foreach my $k (@kids) {
    my $thiskid = $k->getNodeValue;
    my @grandkids = $k->getAllChildren;
    foreach my $g (@grandkids) {
      ## these represent the triple scattering paths
      my $thisgk = $g->getNodeValue;
      my $indgk = -1;
      foreach my $s (@sites) {
	++$indgk;
	++$outercount;
	$self->click('+') if not ($outercount % ($freq*20));
	next if ($leglength[$cindex][$indgk] > $rmax); # prune distant atoms
	next if ($thisgk == $indgk);  # avoid same atom twice
	##next if (($self->get('nlegs') == 4) and ($indgk  == $cindex)); # exclude absorber from this generation
	next if ($indgk  == $cindex); # exclude absorber from this generation
	next if (_length($cindex, $thiskid, $thisgk, $indgk, $cindex) > $rmax2);        # prune long paths from the tree
	++$innercount;
	$self->click('.') if not ($innercount % $freq);
	$g -> addChild(Tree::Simple->new($indgk));
      };
    };
  };
  #$self->report(sprintf("\n    (contains %d nodes from the %d atoms within %.3g Ang.)\n",
  #			$tree->size, $natoms, $rmax));
  $self->report(sprintf("\n    (contains %d nodes from the %d atoms within %.3g Ang.)\n",
			$innercount+1, $natoms, $rmax));
  return $tree;
};

sub _preload_distances {
  my ($self) = @_;
  my @sites = @{ $self->sites };
  foreach my $i (0 .. $#sites) {
    $leglength[$i][$i] = 0;
    foreach my $j ($i+1 .. $#sites) {
      $leglength[$i][$j] = $self->distance(@{ $sites[$i] }[0..2], @{ $sites[$j] }[0..2]);
      $leglength[$j][$i] = $leglength[$i][$j];
      ($shortest = $leglength[$i][$j]) if ($leglength[$i][$j] < $shortest);
    };
  };
};

## this has been optimized for speed, not readability!
## in the 7 ang. copper example, not doing the first shift reduces the total time by almost 2%)
sub _length {
  #my ($self, $first, @indeces) = @_;
  #shift;
  my $first = shift;
  my $hl = 0;
  foreach (@_) {
    $hl += $leglength[$first][$_];
    $first = $_;
  };
  return $hl;
};


sub _traverse_tree {
  my ($self, $tree) = @_;
  my $freq = $self->co->default("pathfinder", "heap_freq");
  $self->report("=== Traversing Tree and populating Heap (each dot represents $freq nodes examined)\n    ");;
  my $heap = Heap::Fibonacci->new;
  my ($heap_count, $visit_calls) = (0, 0);
  ## the traversal creates ScatteringPath objects and throws them onto the heap
  ## the syntax for the traverse method is a bit tricky...
  $tree->traverse(sub{my($tree) = @_; _visit($tree, $self, $heap, \$heap_count, \$visit_calls, $freq)});
  ## now we can destroy the tree
  $self->report("\n    (contains $heap_count elements)\n");
  return $heap;
};
sub _visit {
  my ($tree, $feff, $heap, $rhc, $rvc, $freq) = @_;
  $$rvc += 1;
  $feff->click('.') if not ($$rvc % $freq);
  my $middle = _parentage($tree, q{});
  my $ai = $feff->abs_index;
  return 0 if ($middle =~ m{\.$ai\z}); # the traversal will leave visitations ending in the
  # central atom on the tree
  my $string =  $CTOKEN . $middle . ".$CTOKEN";
  my $sp     = Demeter::ScatteringPath->new(feff=>$feff, string=>$string);
  $sp   -> evaluate;
  ## prune branches that involve non-0 eta angles (if desired)
  return 0 if ($feff->eta_suppress and $sp->etanonzero);
  $heap -> add($sp);
  $$rhc += 1;
  return 1;
}

=for Explanation
    _parentage
      Construct the path's string by resursing up its branch in the
      tree.  The string is the index (from the site list) of each atom
      in the path concatinated with dots.

=cut
sub _parentage {
  my ($tree, $this) = @_;
  if (lc($tree->getParent) eq 'root') {
    return q{};
  } else {
    return _parentage($tree->getParent, $tree->getNodeValue())
      . "."
	. $tree->getNodeValue();
  };
};


sub prep_fuzz {
  my ($self)    = @_;
  my ($fz, $bf) = ($self->co->default("pathfinder", "fuzz"),
		   $self->co->default("pathfinder", "betafuzz"));
  my $FUZZ      = defined($fz) ? $fz : $FUZZ_DEF;
  my $BETAFUZZ  = defined($bf) ? $bf : $BETAFUZZ_DEF;
  $self -> set(fuzz=>$FUZZ, betafuzz=>$BETAFUZZ);
  return $self;
};

sub _collapse_heap {
  my ($self, $heap) = @_;
  $self->prep_fuzz;

  my $bigcount = 0;
  my $freq     = $self->co->default("pathfinder", "degen_freq");;
  my $pattern  = "(%12d examined)";
  $self->report("=== Collapsing Heap to a degenerate list (each dot represents $freq heap elements compared)\n    ");

  my @list_of_paths = ();
  while (my $elem = $heap->extract_top) {
    # print $elem->string, $/;
    my $new_path = 1;
    ++$bigcount;
    $self->click('.') if not ($bigcount % $freq);

  LOP: foreach my $p (reverse @list_of_paths) {
      my $is_different = $elem->compare($p);
      last LOP if ($is_different eq 'lengths different');
      ++$bigcount;
      $self->click('.') if not ($bigcount % $freq);
      if (not $is_different) {
	my @degen = @{ $p->degeneracies };
	push @degen, $elem->string;
	$p->set(n=>$#degen+1, degeneracies=>\@degen);
	my $fuzzy = $p->fuzzy + $elem->halflength;
	$p->fuzzy($fuzzy);
	$new_path = 0;
	last LOP;
      };
    };
    if ($new_path) {
      $elem->set(fuzzy=>$elem->halflength, degeneracies=>[$elem->string]);
      push(@list_of_paths, $elem);
    };
  };

  foreach my $sp (@list_of_paths) {
    my ($fuzzy, $n) = $sp->get(qw(fuzzy n));
    $sp->fuzzy($fuzzy/$n);
  };
  my $path_count = $#list_of_paths+1;
  $self->report("\n    (found $path_count unique paths)\n");
  return @list_of_paths;
};



sub intrp_header {
  my ($self, %markup) = @_;
  map {$markup{$_} ||= q{} } qw(comment open close 0 1 2);
  my $text = q{};
  my @list_of_paths = @{ $self-> pathlist };
  my @lines = split(/\n/, $self->_pathsdat_head('#'));
  $text .= $markup{comment} . shift(@lines) . $markup{close} . "\n";
  $text .= $markup{comment} . shift(@lines) . $markup{close} . "\n";
  $text .= sprintf "%s# The central atom is denoted by this token: %s%s\n",      $markup{comment}, $self->co->default("pathfinder", "token") || '<+>', $markup{close};
  $text .= sprintf "%s# Cluster size = %.5f Angstroms, containing %s atoms%s\n", $markup{comment}, $self->rmax, $self->nsites,                         $markup{close};
  $text .= sprintf "%s# %d paths were found%s\n",                                $markup{comment}, $#list_of_paths+1,                                  $markup{close};
  $text .= sprintf "%s# Forward scattering cutoff %.2f%s\n",                     $markup{comment}, $self->co->default("pathfinder", "fs_angle"),       $markup{close};
  foreach (@lines) { $text .= $markup{comment} . $_ . $markup{close} . "\n" };
  return $text;
};

sub intrp {
  my ($self, $style, $rmax) = @_;

  my %markup  = (comment => q{}, 2 => q{}, 1=> q{}, 0=>q{}, close=>q{});
  if (defined($style) and (ref($style) eq 'HASH')) {
    foreach my $k (keys %$style) {
      $markup{$k} = $style->{$k};
    };
  };
  %markup = (comment => '<span class="comment">', close => '</span><br>', 1 => '<span class="minor">',
	     2       => '<span class="major">',   0     => '<span class="normal">')
    if (defined($style) and ($style eq 'css'));
  %markup = (comment => '{\color{commentcolor}\texttt{', close   => '}}', 0 => '{\texttt{',
	     2       => '{\color{majorcolor}\texttt{',   1       => '{\color{minorcolor}\texttt{')
    if (defined($style) and ($style eq 'latex'));

  my $text = q{};
  my @list_of_paths = @{ $self-> pathlist };
  $text .= $self->intrp_header(%markup);
  $text .=  $markup{comment} . "#     degen   Reff       scattering path                       I legs   type" .  $markup{close} . "\n";
  my $i = 0;
  foreach my $sp (@list_of_paths) {
    last if ($rmax and ($sp->halflength > $rmax));
    $text .= $markup{$sp->weight} . $sp->intrpline(++$i) . $markup{close} . $/;
  };
  return $text;
};



##-------------------------------------------------------------------------
## running Feff

sub make_feffinp {
  my ($self, $which) = @_;
  $self->set_mode(theory=>$self);
  my $string = $self->template("feff", $which);
  $self->set_mode(theory=>q{});
  my $feffinp = File::Spec->catfile($self->workspace, "feff.inp");
  open my $FEFFINP, ">$feffinp";
  print $FEFFINP $string;
  close $FEFFINP;
  return $self;
};

#   sub full_feffinp : STRINGIFY {
#     my ($self) = @_;
#     $self->set_mode(theory=>$self);
#     my $string = $self->template("feff", "full");
#     $self->set_mode(theory=>q{});
#     return $string;
#   };
sub run_feff {
  my ($self) = @_;
  my $cwd = cwd();
  chdir $self->workspace;
  my $exe = $self->co->default("feff", "executable");
  unless ($self->is_windows) { # avoid problems if feff->feff_executable isn't
    my $which = `which $exe`;
    chomp $which;
    if (not -x $which) {
      croak("Could not find the feff6 executable");
    };
  };
  local $| = 1;		# unbuffer output of fork
  my $pid = open(my $WRITEME, "feff6 |");
  while (<$WRITEME>) {
    $self->report($_);
  };
  close $WRITEME;
  chdir $cwd;
  return $self;
};


sub click {
  my ($self, $char) = @_;
  print $char if $self->screen;
}
sub report {
  my ($self, $string) = @_;
  local $| = 1;
  ## dispose of feff's output
  print $string if $self->screen;
  if ($self->buffer) {
    my @list = split("\n", $string);
    $self->push_iobuffer(@list);
  };
  return $self;
};



##-------------------------------------------------------------------------
## serializing/deserializing

sub serialize {
  my ($self, $filename, $nozip) = @_;
  croak("No filename specified for serializing Feff object") unless $filename;

  my %cards = ();
  foreach my $key (qw(abs_index edge s02 rmax nlegs npaths rmultiplier pcrit ccrit
		      workspace screen buffer save fuzz betafuzz eta_suppress miscdat group)) {
    $cards{$key} = $self->$key;
  };
  $cards{zzz_arrays} = "titles othercards potentials absorber sites";

  if ($nozip) {
    open my $Y, ">".$filename;
    ## dump attributes of the Feff object
    print $Y YAML::Dump(\%cards);
    foreach my $key (split(" ", $cards{zzz_arrays})) {
      print $Y YAML::Dump($self->get($key));
    };
    ## dump attributes of each ScatteringPath object
    my %pathinfo = ();
    foreach my $sp ( @{$self->pathlist}) {
      foreach my $key ($sp->savelist) {
	$pathinfo{$key} = $sp->$key;
      };
      print $Y YAML::Dump(\%pathinfo);
    };
    close $Y;

  } else {
    my $gzout = gzopen($filename, 'wb9');
    ## dump attributes of the Feff object
    $gzout->gzwrite(YAML::Dump(\%cards));
    foreach my $key (split(" ", $cards{zzz_arrays})) {
      $gzout->gzwrite(YAML::Dump($self->get($key)));
    };
    ## dump attributes of each ScatteringPath object
    my %pathinfo = ();
    foreach my $sp ( @{$self->pathlist}) {
      foreach my $key ($sp->savelist) {
	$pathinfo{$key} = $sp->$key;
      };
      $gzout->gzwrite(YAML::Dump(\%pathinfo));
    };
    $gzout->gzclose;

  };
};

sub deserialize {
  my ($self, $file, $group) = @_;
  $file ||= $self->yaml;
  croak("No file specified for deserializing a Feff object") unless $file;
  croak("File \"$file\" (serialized Feff object) does not exist") unless -e $file;
  $self -> group($group) if $group;

  ## this is a bit awkward -- what if the serialization is very large?
  my ($yaml, $buffer);
  my $gz = gzopen($file, 'rb');
  $yaml .= $buffer while $gz->gzreadline($buffer) > 0 ;
  my @refs = YAML::Load($yaml);
  $gz->gzclose;
  $self->read_yaml(\@refs);
  return $self;
};
sub read_yaml {
  my ($self, $refs) = @_;
  my @refs = @$refs;
  ## snarf attributes of Feff object
  my $rhash = shift @refs;
  foreach my $key (qw(abs_index edge s02 rmax nlegs npaths rmultiplier pcrit ccrit
		      workspace screen buffer save fuzz betafuzz eta_suppress miscdat)) {
    $self -> $key($rhash->{$key});
  };
  $self -> set(titles     => shift(@refs),
	       othercards => shift(@refs),
	       potentials => shift(@refs),
	       absorber   => shift(@refs),
	       sites	  => shift(@refs));
  #$self -> prep_fuzz;
  ## snarf attributes of each ScatteringPath object
  my @paths;
  foreach my $path (@refs) {
    my $sp = Demeter::ScatteringPath->new(feff=>$self);
    foreach my $key ($sp->savelist) {
      next if not defined $path->{$key};
      $sp -> $key($path->{$key});
    };
    push @paths, $sp;
  };
  $self->pathlist(\@paths);

  return $self;
};
{
  no warnings 'once';
  # alternate names
  *freeze = \ &serialize;
  *thaw   = \ &deserialize;
};


__PACKAGE__->meta->make_immutable;
1;


=head1 NAME

Demeter::Feff - Make and manipulate Feff calculations


=head1 VERSION

This documentation refers to Demeter version 0.3.


=head1 SYNOPSIS

  my $feff = Demeter::Feff -> new();
  $feff->set(workspace=>"temp", screen=>1, buffer=>q{});
  $feff->rdinp("feff.inp")
    -> potph
      -> pathfinder
        -> genfmt;


=head1 DESCRIPTION

This subclass of the Demeter class is for interacting with theory from
Feff.  Computing the C<phase.bin> file is done by Feff via a pipe, as
is running the genfmt portion of Feff.  Parsing the input file,
pathfinding, and generating the C<paths.dat> to control genfmt have
been implemented as methods of this object.

=head1 ATTRIBUTES

=over 4

=item C<sites>

Reference to a list containing all the sites found in the input
structure.  Each element of the list is a reference to a list
containing the site's x, y , and z coordinates, followed by its
potential index.

=item C<potentials>

Reference to a list containing all the unique potentials.  Each
element of the list is a reference to a list containing the site's ipot,
Z-number, and tag.

=item C<titles>

Reference to a list containing all the title lines.

=item C<absorber>

Reference to a list containing the x, y, and z coordinates of the
absorbing atoms.

=item C<abs_index>

Index, starting at 0, of the absorber in the C<sites> list.

=item C<edge>

The edge of the calculation.  This can be any of 1, 2, 3, 4, K, L1,
L2, or L3.

=item C<s02>

The S02 value.  This can be other than 1, which is a really bad idea
for the Feff calculation, but that's how Feff works.

=item C<rmax>

The Rmax value, i.e. the half length of the longest path.

=item C<nlegs>

The maximum number of legs of paths to be calculated.  In Feff this
can be as large as 7.  Demeter's implementation of the path finder is
currently limited to 4.

=item C<rmultiplier>

The value of Rmultiplier, an isotropic scaling factor for all atomic
coordinates in the atoms list.

=item C<pcrit>

The value of the plane wave criterion.  This is not used by Demeter's
pathfinder.

=item C<ccrit>

The value of the curved wave criterion.  This may be used by the
C<genfmt> method.

=item C<workspace>

A valid directory in which to run Feff.  Demeter will cd into this
directory before writing out a F<feff.inp> file, computing the
potentials, running the pathfinder, or running genfmt.

=item C<miscdat>

The contents of the F<misc.dat> file, slurped up after the
F<phase.bin> file file is generated.

=item C<pathlist>

A reference to the list of ScatteringPath objects generated by the
C<pathfinder> method.

=item C<screen>

A boolean controlling whether Feff's output is printed to STDOUT.

=item C<buffer>

A reference to a array or scalar for containing the output from Feff.
This array or scalar can then be handled by the caller.

=item C<save>

A boolean saying whether to save the minimal C<feff.inp> file after a
Feff running step is finished.

=back

=head1 METHODS

=head2 Accessor methods

This uses the C<set> and C<get> methods of the parent class,
L<Demeter>.

=head2 Feff replacement methods

=over 4

=item C<rdinp>

Parse the feff input file and store its information.  It can read from
an arbitrarily named file, which is an improvement over Feff itself..

  $feff -> rdinp("yourfeff.inp");

If called without an argument, it will look for F<feff.inp> in the
current working directory.

=item C<pathfinder>

Find all unique paths in the input atoms list.  All degenerate
geometries will be preserved.

  $feff -> rdinp("somefeff.inp") -> pathfinder;

This implementation of the path finder has two advantages over Feff's
implementation.

=over

=item *

The degeneracy is determined with fuzziness. Paths with similar, but not
equal, half-lengths and/or scattering angles will be grouped together
as effectively degenerate. The width of these fuzzily degenerate bins
is configurable.

=item *

The geometries of the degenerate paths are preserved. This will aid in
the identification of paths in a ball-and-stick view and allow easier
tracking of how structural distortions propagate into the path list.

=back

There are three shortcomings of Demeter's path finder compared to
Feff's:

=over 4

=item *

Implemented in an interpreted language, it is considerably
slower. This is exponentially true for larger clusters.

=item *

It is currently limited to 4-legged paths. This is not a fundamental
limitation, merely a lazy one. Eventually all leggedness limitations
will be removed from Demeter's implementation.

=item *

Demeter cannot compute the so-called importance factor which is used
to limit the size of the heap and to convey approximate information
about path size to the user.  This is actually a pretty serious
problem as it means that one of Feff's most important ways of trimming
the size of the pathfinder heap is unavailable to Demeter.

=back

This is not simply a drop-in-place replacement.  It actually produces
different output than Feff's path finder.  It will not miss any of the
important paths, but it treats degeneracies differently and will
include some small paths that Feff would normally exclude.

=item C<pathsdat>

Write a F<paths.dat> file from some or all of the ScatteringPath
objects found by the path finder.

  $feff -> pathsdat()
  # or
  $feff -> pathsdat(7 .. 13);

With no argument, all paths will be written to the F<paths.dat> file.
The optional argument is a list of numbers interpreted as indeces of
the list returned by the C<pathlist> method.

=back

=head2 Feff running methods

=over 4

=item C<make_feffinp>

Write out a feff.inp file suitable for computing the potentials,
running genfmt, or running all of Feff.

  $feff -> make_feffinp("potentials");
    # or
  $feff -> make_feffinp("genfmt");
    # or
  $feff -> make_feffinp("full");

=item C<potph>

Run Feff to compute the potentials.  The C<make_feffinp> method will
be run if needed.

  $feff -> potph;

This runs just the first segment of Feff, generating the F<phase.bin>
file.  Note that, when transfering a feff calculation between machines
with different CPU or different operating system, this binary file
will not be read correctly (possibly not at all) by Feff on the new
machine.

=item C<genfmt>

Run the third segment of Feff, which imports the F<phase.bin> file and
generates a F<feffNNNN.dat> file for every entry int he F<paths.dat>
file.

  $feff -> genfmt();
  # or
  $feff -> genfmt(7 .. 13);

The optional argument is a list of indeces passed to the C<pathsdat>
method.  WIthout that argument, C<pathsdat> is used to write out data
for every path found by the path finder.

=item C<run_feff>

This cds to the directory specified by the C<workspace> attribute and
runs feff using whatever F<feff.inp> file is found there.  You would
usually call the C<make_feffinp> method just before calling this.

  $feff -> make_feffinp("potentials") -> run_feff;

=item C<report>

Dispose of text, possibly gathered from a Feff run, to the channels
specified by the C<screen> and C<buffer> attributes.

  $feff -> report($some_text);

=back

=head2 Reporting methods

=over 4

=item C<intrp>

Write an interpretation of the Feff calculation.  This summarizes each
path, reporting on the F<feffNNNN.dat> index, the degeneracy, the half
path length, and a description of the scattering geometry.

The optional argument is used to add markup to add some style to the
text written.

To mark up the interpretation for an html page using CSS

   print $feff->intrp('css');

You will need to define CSS text styles called C<comment>, C<major>,
C<minor>, and C<normal> for the header, the major paths, the minor
paths, and the small paths respectively.  Here is a very simple
example:

  .comment {
    font: 1em monospace;
    color: #990000;
  }
  .major {
    font: 1em monospace;
    color: #009900;
  }
  .minor {
    font: 1em monospace;
    color: #775500;
  }
  .normal {
    font: 1em monospace;
    color: #777777;
  }

To mark up the interpretation for LaTeX

   print $feff->intrp('latex');

You will need to define colors called C<commentcolor>, C<majorcolor>,
and C<minorcolor> for the header, the major paths, and the minor
paths, respectively.  One way of defining colors in your LaTeX
document is

   \usepackage[pdftex]{color}
   \definecolor{commentcolor}{rgb}{0.70,0.00,0.00}

The argument can also be a hash reference defining some other kind of
markup.  There are five markup tags:

=over

=item C<comment>

The beginning of a header line.  In the latex style,
this is "C<{\color{commentcolor}\texttt{>".  In css style, this is
"C<E<lt>span class=commentE<gt>>".

=item C<2>

The beginning of a path of importance level 2.  In the latex style,
this is "C<{\color{majorcolor}\texttt{>".  In css style, this is
"C<E<lt>span class=majorE<gt>>".

=item C<1>

The beginning of a path of importance level 1.  In the latex style,
this is "C<{\color{minorcolor}\texttt{>".  In css style, this is
"C<E<lt>span class=minorE<gt>>".

=item C<0>

The beginning of a path of importance level 0.  In the latex style,
this is "C<{\texttt{>".  In css style, this is
"C<E<lt>span class=normalE<gt>>".

=item C<close>

The markup for the end of a style block.  In the latex style, this is
two closing curly brackets, "C<}}>".  In css style, this is
"C<E<lt>/spanE<gt>E<lt>brE<gt>>".

=back

Here is an example of adding some color when writing to a
terminal capable of displaying ANSI color:

    use Term::ANSIColor qw(:constants);
    $style = {comment => BOLD.RED,
              close   => RESET,
              1       => BOLD.YELLOW,
              2       => BOLD.GREEN,
              0       => q{},
             };
    print $feff->intrp($style);

The ANSI color example is not pre-defined so that Term::ANSIColor does
not have to be a Demeter requirement.  That said, it is probably the
most useful style.

=back

=head2 Convenience methods

These are simple wrappers around the C<get> accessor.

=over 4

=item C<central>

Returns a list of the x, y, and z coordinates of the central atom.

=item C<pathlist>

Returns a list of ScatteringPath objects found by the path finder.

=item C<nsites>

Returns the number of sites in the atoms list.

=back

=head1 SERIALIZATION AND DESERIALIZATION

The Feff object uses L<YAML> for its serialization format.  All of the
scalar valued attributes are collected into a hash, which is the first
thing serialized into the YAML file.  This is followed by the
array-valued attributes in this order: C<titles>, C<othercards>,
C<potentials>, C<absorber>, then C<sites>.  Finally each of the
ScatteringPath objects are serialized in the order they appear in the
C<pathlist> attribute.  C<freeze> is an alias for C<serialize>.

  $feff -> serialize($yaml_filename);
    # or
  $feff -> freeze($yaml_filename);

There is a second, optional argument to C<serialize>.  If true, the
serialization file is written without compression.  By default, the
serialization file is compressed using the gzip algorithm.

You can deserialize the YAML file and store it in a Feff object and a
list of ScatteringPath objects.  C<thaw> is an alias for
C<deserialize>.

  $feff -> deserialize($yaml_filename);
    # or
  $feff -> thaw($yaml_filename);

=head1 CONFIGURATION AND ENVIRONMENT

See L<Demeter> for a description of the configuration system.

=head1 DEPENDENCIES

The dependencies of the Demeter system are in the
F<Bundle/DemeterBundle.pm> file.

=head1 BUGS AND LIMITATIONS

=over 4

=item *

Need methods for identifying particular paths, for example "the single
scattering path with the phosphorous atom as the scatterer".

=item *

Automated indexing currently only works when doing a fit.  If you want
to plot paths before doing a fit, you will need to assign indeces by
hand.

=item *

Feff8 functionality is incomplete.  For instance, the C<potentials>
attribute needs to allow for longer lists for the additional
parameters in Feff8.

=item *

The C<edge> attribute should recognize M, N, O edges.

=item *

Need to keep and C<iedge> attribute, as in the Atoms object

=item *

The C<pathsdat> method should accept special arguments, like "SS" for
all single scattering paths, or "collinear" for all collinear MS
paths.

=item *

Look into doing a better job of caching halflengths.
Tools::halflength is a significanty fraction of the time spent by the
pathfinder.

=back

See L<Demeter::ScatteringPath> for limitations of the pathfinder.

Please report problems to Bruce Ravel (bravel AT bnl DOT gov)

Patches are welcome.

=head1 AUTHOR

Bruce Ravel (bravel AT bnl DOT gov)

L<http://cars9.uchicago.edu/~ravel/software/>


=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2009 Bruce Ravel (bravel AT bnl DOT gov). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
