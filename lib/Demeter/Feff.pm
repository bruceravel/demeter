package Demeter::Feff;

=for Copyright
 .
 Copyright (c) 2006-2016 Bruce Ravel (http://bruceravel.github.io/home).
 All rights reserved.
 .
 This file is free software; you can redistribute it and/or
 modify it under the same terms as Perl itself. See The Perl
 Artistic License.
 .
 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.split

=cut

use autodie qw(open close);

use Moose;
extends 'Demeter';

use MooseX::Aliases;
use Moose::Util::TypeConstraints;
use Demeter::StrTypes qw( AtomsEdge FeffCard Empty ElementSymbol FileName Rankings);
use Demeter::NumTypes qw( Natural NonNeg PosInt );
with 'Demeter::Feff::Histogram';
with 'Demeter::Feff::Paths';
with 'Demeter::Feff::Sanity';
with 'Demeter::UI::Screen::Pause' if ($Demeter::mode->ui eq 'screen');
if ($Demeter::mode->ui eq 'screen') {
  with 'Demeter::UI::Screen::Progress';
};
use Demeter::Return;

use Capture::Tiny qw(capture tee);
use Carp;
use Chemistry::Elements qw(get_symbol);
use Compress::Zlib;
use Cwd;
use File::Basename;
use File::Path;
use File::Spec;
use File::Temp qw(tempfile);
use Heap::Fibonacci;
use List::MoreUtils qw(any false notall);
use List::Util qw(sum);
use Tree::Simple;


use Demeter::Constants qw($NUMBER $SEPARATOR $CTOKEN);
use Const::Fast;
const my $NLEGMAX      => 4;
const my $ETASUPPRESS  => 1;
const my $FUZZ_DEF     => 0.01;
const my $BETAFUZZ_DEF => 3;

my @leglength = ();
my $shortest = 100000000;


has 'source'      => (is => 'rw', isa => 'Str', default => 'demeter/feff6');
has 'file'        => (is => 'rw', isa => FileName,  default => q{},
		      trigger => sub{my ($self, $new) = @_;
				     if ($new) {
				       $self->rdinp;
				       $self->name(basename($new, '.inp')) if not $self->name;
				     }} );
has 'yaml'        => (is=>'rw', isa => FileName, default => q{},
		      trigger => sub{my ($self, $new) = @_; $self->deserialize if $new} );
has 'atoms'       => (is=>'rw', isa => Empty|'Demeter::Atoms',
		      trigger => sub{my ($self, $new) = @_; $self->run_atoms if $new});
has 'molecule'    => (is=>'rw', isa => FileName, default => q{},);

has 'sites' => (
		traits    => ['Array'],
		is        => 'rw',
		isa       => 'ArrayRef',
		default   => sub { [] },
		handles   => {
			      'push_sites'  => 'push',
			      'pop_sites'   => 'pop',
			      'clear_sites' => 'clear',
			     }
	       );
has 'nsites' => (is=>'rw', isa => 'Int', default => 0);

has 'potentials' => (
		     traits    => ['Array'],
		     is        => 'rw',
		     isa       => 'ArrayRef',
		     default   => sub { [] },
		     handles   => {
				   'push_potentials'  => 'push',
				   'pop_potentials'   => 'pop',
				   'clear_potentials' => 'clear',
				  }
		    );
has 'titles' => (
		 traits    => ['Array'],
		 is        => 'rw',
		 isa       => 'ArrayRef',
		 default   => sub { [] },
		 handles   => {
			       'unshift_titles' => 'unshift',
			       'push_titles'    => 'push',
			       'pop_titles'     => 'pop',
			       'clear_titles'   => 'clear',
			      }
		);
has 'absorber' => (
		   traits    => ['Array'],
		   is        => 'rw',
		   isa       => 'ArrayRef',
		   default   => sub { [] },
		   handles   => {
				 'push_absorber'  => 'push',
				 'pop_absorber'   => 'pop',
				 'clear_absorber' => 'clear',
				}
		  );
has 'abs_index'    => (is=>'rw', isa =>  Natural,   default => 0,
		       trigger => sub{ my ($self, $new) = @_; 
				       #return if not exists $self->sites->[$new];
				       #return if not exists $self->sites->[$new]->[3];
				       return if $#{ $self->potentials } == -1;
				       my $elem = get_symbol($self->potentials->[0]->[1]) || 'He';
				       $self->abs_species($elem);
				     });
has 'abs_species'  => (is=>'rw', isa =>  ElementSymbol, default => 'He', coerce => 1, alias=>'abs_element');
has 'edge'         => (is=>'rw', isa =>  AtomsEdge, default => 'K', coerce => 1); # 1-4 or K-L3
has 's02'          => (is=>'rw', isa =>  NonNeg,    default => 1);   # positive float
has 'rmax'         => (is=>'rw', isa =>  NonNeg,    default => 0);   # positive float
has 'nlegs'        => (is=>'rw', isa =>  PosInt,    default => 4);   # integer < 7
has 'rmultiplier'  => (is=>'rw', isa =>  NonNeg,    default => 1);   # positive float
has 'pcrit'        => (is=>'rw', isa =>  NonNeg,    default => 0);   # positive float
has 'ccrit'        => (is=>'rw', isa =>  NonNeg,    default => 0);   # positive float

has 'polarization' => (
		       traits    => ['Array'],
		       is        => 'rw',
		       isa       => 'ArrayRef',
		       default   => sub { [0,0,0] },
		       handles   => {
				     'push_polarization'  => 'push',
				     'pop_polarization'   => 'pop',
				     'clear_polarization' => 'clear',
				    }
		      );
has 'ellipticity' => (
		       traits    => ['Array'],
		       is        => 'rw',
		       isa       => 'ArrayRef',
		       default   => sub { [0,0,0,0] },
		       handles   => {
				     'push_ellipticity'  => 'push',
				     'pop_ellipticity'   => 'pop',
				     'clear_ellipticity' => 'clear',
				    }
		      );


### feff8 cards

has 'scf'          => (is=>'rw', isa =>  'ArrayRef', default => sub{[]});
has 'xanes'        => (is=>'rw', isa =>  'ArrayRef', default => sub{[]});
has 'fms'          => (is=>'rw', isa =>  'ArrayRef', default => sub{[]});
has 'ldos'         => (is=>'rw', isa =>  'ArrayRef', default => sub{[]});
has 'exafs'        => (is=>'rw', isa =>  NonNeg,    default => 0);   # positive float

has 'othercards' => (
		     traits    => ['Array'],
		     is        => 'rw',
		     isa       => 'ArrayRef',
		     default   => sub { [] },
		     handles   => {
				   'push_othercards'  => 'push',
				   'pop_othercards'   => 'pop',
				   'clear_othercards' => 'clear',
				  }
		    );
has 'workspace'    => (is=>'rw', isa => 'Str',
		       default => sub{File::Spec->catfile(Demeter->stash_folder, 'feff_'.Demeter->randomstring(9))} );
has 'miscdat'      => (is=>'rw', isa => 'Str',    default => q{});
has 'vint'         => (is=>'rw', isa => 'LaxNum', default => 0);
has 'hidden'       => (is=>'rw', isa => 'Bool',   default => 0);

has 'fuzz'         => (is=>'rw', isa =>  NonNeg,  default => Demeter->co->default('pathfinder','fuzz')||0.03);
has 'betafuzz'     => (is=>'rw', isa =>  NonNeg,  default => Demeter->co->default('pathfinder','betafuzz')||3);
has 'eta_suppress' => (is=>'rw', isa => 'Bool',   default => Demeter->co->default('pathfinder','eta_suppress')||0);

		       ## result of pathfinder
has 'site_fraction'=> (is => 'rw', isa => 'LaxNum', default => 1);
has 'pathlist' => (		# list of ScatteringPath objects
		   traits    => ['Array'],
		   alias     => 'pathslist',
		   is        => 'rw',
		   isa       => 'ArrayRef',
		   default   => sub { [] },
		   handles   => {
				 'push_pathlist'  => 'push',
				 'pop_pathlist'   => 'pop',
				 'clear_pathlist' => 'clear',
				}
		  );
has 'npaths'       => (is=>'rw', isa =>  Natural,   default => 0);
has 'postcrit'     => (is=>'rw', isa =>  NonNeg,    default => Demeter->co->default('pathfinder','postcrit'));   # positive float

		       ## reporting and processing
has 'screen'       => (is=>'rw', isa => 'Bool', default => 1);
has 'buffer'       => (is=>'rw', isa => 'Bool', default => 0);
has 'iobuffer' => (
		   traits    => ['Array'],
		   is        => 'rw',
		   isa       => 'ArrayRef[Str]',
		   default   => sub { [] },
		   handles   => {
				 'push_iobuffer'  => 'push',
				 'pop_iobuffer'   => 'pop',
				 'clear_iobuffer' => 'clear',
				}
		  );
has 'execution_wrapper' => (is=>'rw', isa => 'Any', default => 0);
has 'save'     => (is=>'rw', isa => 'Bool',    default => 1);
has 'problems' => (is=>'rw', isa => 'HashRef', default => sub{ {} });
has 'feffran'  => (is=>'rw', isa => 'Bool',    default => 0);

has 'feff_version' => (is=>'rw', isa => 'Int', default => 6);

sub BUILD {
  my ($self, @params) = @_;
  #print join(" ", caller(1)), $/;
  $self->mo->push_Feff($self);
};
sub DEMOLISH {
  my ($self) = @_;
  $self->alldone;
};

override 'Clone' => sub {
  my ($self, @arguments) = @_;
  my $new = Demeter::Feff -> new();

  my %hash = $self->all;
  delete $hash{group};

  ## deeply copy the Collection::Array attributes
  foreach my $ca (qw(sites potentials titles absorber othercards pathlist)) {
    delete $hash{$ca};
    my @list = @{ $self -> $ca };
    $new -> $ca(\@list);
  };
  $hash{atoms} = q{} if (not defined $hash{atoms});

  $new -> set(%hash);
  $new -> iobuffer([]);
  $new -> problems({});
  $new -> set(@arguments);
  return $new;
};

sub clear {
  my ($self) = @_;
  $self->clear_sites;
  $self->clear_potentials;
  $self->clear_titles;
  $self->clear_absorber;
  $self->clear_othercards;
  $self->clear_pathlist;
  $self->polarization([0,0,0]);
  $self->ellipticity([0,0,0]);
  $self->set(abs_index   => 0, edge  => 'K', s02   => 1,  rmax    => 0,   nlegs => 4,
	     rmultiplier => 1, pcrit =>  0,  ccrit => 0,  miscdat => q{},
	     npaths      => 0, scf   => [],  xanes => [], ldos    => [],  fms => [],
	    );
  return $self;
};

override 'alldone' => sub {
  my ($self) = @_;
  foreach my $sp (@{ $self->pathlist }) {
    next if not defined($sp);	# may have been demolished elsewhere
    $sp->DEMOLISH;
  };
  $self->remove;
  $self->clean_workspace if not $self->save;
};

sub central {
  my ($self) = @_;
  #print join("|", $self->group, @{ $self->absorber }), $/;
  return @{ $self->absorber };
};

#sub nsites {
#  my ($self) = @_;
#  return $#{ $self->sites };
#};

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

sub site_species {
  my ($self, $a) = @_;
  my @sites  = @{ $self->sites };
  my @ipots  = @{ $self->potentials };
  my $i = $sites[$a]->[3];
  return get_symbol($ipots[$i]->[1]);
};

sub is_polarization {
  my ($self) = @_;
  return ($self->polarization->[0] or $self->polarization->[1] or $self->polarization->[2]);
};

sub is_ellipticity {
  my ($self) = @_;
  return ($self->ellipticity->[0] or $self->ellipticity->[1] or $self->ellipticity->[2] or $self->ellipticity->[3]);
};

sub rdinp {
  my ($self) = @_;
  $self->clear;
  my $file = $self->file;
  my $mode = q{};
  my $nmodules = 0;
  open (my $INP, $file);
  while (<$INP>) {
    #chomp;
    $_ =~ s{(?:\n|\r)+\z}{}g; # how do you chomp a eol sequence from an alien OS?
    last if (m{\A\s*end}i);
    next if (m{\A\s*\z});	# blank line
    next if (m{\A\s*\*});	# commented line
    my @line = split(/$SEPARATOR/, $_);
    shift @line if ($line[0] =~ m{^\s*$});
    #print join('|', @line), $/;
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
	$thiscard = 'exafs',	    last CARDS if ($thiscard =~ m{\Aexa});
	$thiscard = 'criteria',     last CARDS if ($thiscard =~ m{\Acri});
	$thiscard = 'scf',          last CARDS if ($thiscard =~ m{\Ascf});
	$thiscard = 'fms',          last CARDS if ($thiscard =~ m{\Afms});
	$thiscard = 'ldos',         last CARDS if ($thiscard =~ m{\Aldo});
	$thiscard = 'polarization', last CARDS if ($thiscard =~ m{\Apol});
	$thiscard = 'ellipticity',  last CARDS if ($thiscard =~ m{\Aell});
	$thiscard = 'xanes',        last CARDS if ($thiscard =~ m{\Axan});
	                            last CARDS if ($thiscard =~ m{\A(?:con|pri|deb)}); ## CONTROL and PRINT are under demeter's control
	                                                                               ## DEBYE is simply ignored by Demeter
	$self -> push_othercards($_);  ## pass through all other cards
      };

      #print join("|", $thiscard, @line), $/;
      ## dispatch the card values
    DOCARD: {
	($thiscard =~ m{(?:exafs|r(?:max|multiplier)|s02)}) and do {
	  $self->$thiscard($line[1]);
	  last DOCARD;
	};
	($thiscard =~ m{(?:atoms|potentials)}) and do {
	  $mode = $thiscard;
	  last DOCARD;
	};
	($thiscard eq 'hole') and do {
	  $self->set(edge  => $line[1], s02   => $line[2]);
	  last DOCARD;
	};
	($thiscard eq 'edge') and do {
	  $self->edge($self->edge2hole($line[1]));
	  last DOCARD;
	};
	($thiscard eq 'criteria') and do {
	  $self->set(pcrit => $line[1], ccrit => $line[2]);
	  last DOCARD;
	};
	($thiscard eq 'titles') and do {
	  $self->_title(join(" ", @line));
	  last DOCARD;
	};
	($thiscard =~ m{ (?:control|print)}) and do {
	  $nmodules = $#line;
	  last DOCARD;
	};
	($thiscard eq 'scf')   and do {
	  $self->feff_version(8); $self->scf([@line[1..$#line]]);
	  last DOCARD;
	};
	($thiscard eq 'fms')   and do {
	  $self->feff_version(8); $self->fms([@line[1..$#line]]);
	  last DOCARD;
	};
	($thiscard eq 'xanes') and do {
	  $self->feff_version(8); $self->xanes([@line[1..$#line]]);
	  last DOCARD;
	};
	($thiscard eq 'ldos')  and do {
	  $self->feff_version(8); $self->ldos([@line[1..$#line]]);
	  last DOCARD;
	};
	($thiscard eq 'polarization')  and do {
	  $self->polarization([$line[1], $line[2], $line[3]]);
	  last DOCARD;
	};
	($thiscard eq 'ellipticity')  and do {
	  $self->ellipticity([$line[1], $line[2], $line[3], $line[4]]);
	  last DOCARD;
	};
      };
      # given ($thiscard) {
      # 	when (m{(?:e(?:dge|xafs)|r(?:max|multiplier)|s02)}) { $self->$thiscard($line[1])  };
      # 	when (m{(?:atoms|potentials)}) { $mode = $thiscard                                };
      # 	when ('hole')		       { $self->set(edge  => $line[1], s02   => $line[2]) };
      # 	when ('criteria')	       { $self->set(pcrit => $line[1], ccrit => $line[2]) };
      # 	when ('titles')		       { $self->_title(join(" ", @line))                  };
      # 	when (m{ (?:control|print)})   { $nmodules = $#line                               };
      # 	when ('scf')   { $self->feff_version(8); $self->scf  ([@line[1..$#line]]) };
      # 	when ('fms')   { $self->feff_version(8); $self->fms  ([@line[1..$#line]]) };
      # 	when ('xanes') { $self->feff_version(8); $self->xanes([@line[1..$#line]]) };
      # 	when ('ldos')  { $self->feff_version(8); $self->ldos ([@line[1..$#line]]) };
      # };

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
    };
  };
  close $INP;

  ## apply RMULTIPLIER
  my @rmultiplied = ();
  foreach my $s (@{$self->sites}) {
    $s->[0] *= $self->rmultiplier;
    $s->[1] *= $self->rmultiplier;
    $s->[2] *= $self->rmultiplier;
    push @rmultiplied, $s;
  };
  $self->sites(\@rmultiplied);

  $self->nsites($#{$self->sites});
  $self->feff_version(8) if any {$_ =~ m{scf|exafs|xanes|ldos}} @{$self->othercards};
  $self->feff_version(8) if $nmodules > 4;

  my %problems = (used_not_defined     => 0,
		  defined_not_used     => 0,
		  no_absorber          => 0,
		  multiple_absorbers   => 0,
		  used_ipot_gt_7       => 0,
		  defined_ipot_gt_7    => 0,
		  rmax_outside_cluster => 0,
		  cluster_too_big      => 0,

		  errors               => [],
		  warnings             => [],
		 );

  ## sanity checks on input data
  $self->S_check_ipots(\%problems);
  $self->S_check_rmax(\%problems);
  $self->S_check_cluster_size(\%problems);
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
    next if (any {$k eq $_} (qw(rmax_outside_cluster warnings errors cluster_too_big)));
    $stop += $problems{$k};
  };
  carp("The following errors were found in $file:\n  "
	. join("\n  ", @{$problems{errors}})
	. $/) if $stop;
  $self->problems(\%problems);
  return $self;
};


our %edgehash = (k=>1, l1=>2, l2=>3, l3=>4, m1=>5, m2=>6, m3=>7, m4=>8, m5=>9,
		 n1=>10, n2=>11, n3=>12, n4=>13, n5=>14, n6=>15, n7=>16,
		 o1=>17, o2=>18, o3=>19, o4=>20, o5=>21, o6=>22, o7=>23,
		 p1=>24, p2=>25, p3=>26 );
sub edge2hole {
  my ($self, $hole) = @_;
  if ($hole !~ m{\A\d}) {
    $hole = $edgehash{lc($hole)};
  };
  return $hole;
};
sub hole2edge {
  my ($self, $edge) = @_;
  if ($edge =~ m{\A\d}) {
    my %hash = reverse %edgehash;
    $edge = $hash{$edge};
  };
  return $edge;
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
  ##print ">>>>>>>", join("|", @entries[0..2]), $/;
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
  rmtree($self->workspace, 0 , 1) if (-d $self->workspace);
  return $self;
};

sub check_workspace {
  my ($self) = @_;
  return 0 if ($self->workspace and (-d $self->workspace));
  if ($self->co->default('feff','autoworkspace')) {
    $self->make_workspace;
    return 1;
  };
  my $string =
  'Feff is sort of an old-fashioned program.  It reads from a fixed input'
    . 'file and writes fixed output files.  All this needs to happen in a'
      . 'specified directory.'
	. $/ x 2
	  . 'You must explicitly establish a workspace for this Feff calculation:'
	    . $/;
  croak $string;
};


sub run {
  my ($self) = @_;
  my $ret = $self->potph;
  $ret = $self->pathfinder;
  return $self;
};

sub potph {
  my ($self) = @_;
  my $ret = Demeter::Return->new;

  local $SIG{ALRM} = sub { 1; } if not $SIG{ALRM};
  $self->check_workspace;

  ## write a feff.inp for the first module
  $self->make_feffinp("potentials");

  ## run feff to generate phase.bin
  $self->run_feff;

  ## slurp misc.dat into this object
  {
    local( $/ );
    my $miscdat = File::Spec->catfile($self->get("workspace"), "misc.dat");
    if (-e $miscdat) {
      open( my $fh, $miscdat );
      my $text = <$fh>;
      my $null = chr(0);
      $text =~ s{$null}{}g;	# frakkin' feff
      $self->miscdat($text);
      $self->vint($1) if ($text =~ m{Vint\s*=\s*($NUMBER)});
      close $fh;
      unlink $miscdat if not $self->save;
    };
  };

  ## clean up from this feff run
  unlink File::Spec->catfile($self->get("workspace"), "feff.run");
  unlink File::Spec->catfile($self->get("workspace"), "feff.inp")
    if not $self->save;

  return $self;
};
sub genfmt {
  my ($self, @list_of_path_indeces) = @_;

  local $SIG{ALRM} = sub { 1; } if not $SIG{ALRM};
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
    if ($self->feff_version == 8) {
      unlink File::Spec->catfile($self->workspace, $_)
	foreach qw(mod1.inp mod2.inp mod3.inp mod4.inp mod5.inp mod6.inp
		   log1.inp log2.inp log3.inp log4.inp log5.inp log6.inp
		   chi.dat feff.bin geom.dat fpf0.dat global.dat atoms.dat
		   s02.inp sigma.dat xsect.bin logso2.dat logdos.dat);
    };
    unlink File::Spec->catfile($self->workspace, "feff.inp");
    unlink File::Spec->catfile($self->workspace, "files.dat");
  };
  return $self;
};

sub explain_ranking {
  my ($self, $which) = @_;
  my %hints = ('feff'  => 'feff\'s curved wave amplitude ratio',
	       'akc'   => 'sum( abs(k * chi) )',
	       'aknc'  => 'sum( abs(k^n * chi) )',
	       'sqkc'  => 'sqrt( sum( (k * chi)^2 ) )',
	       'sqknc' => 'sqrt( sum( (k^n * chi)^2 ) )',
	       'mkc'   => 'sum( k * mag(chi))',
	       'mknc'  => 'sum( k^n * mag(chi))',
	       'sft'   => 'sum( mag(chi(R)) )',
	       'mft'   => 'max( mag(chi(R)) )');
  return $hints{$which};
};

sub _pathsdat_head {
  my ($self, $prefix) = @_;
  $prefix ||= q{};
  my $header = q{};
  foreach my $t (@ {$self->titles} ) { $header .= "$prefix " . $t . "\n" };
  $header .= $prefix . " This paths.dat file was written by Demeter " . $self->version . "\n";
  $header .= sprintf("%s Distance fuzz = %.3f A\n",         $prefix, $self->fuzz);
  $header .= sprintf("%s Angle fuzz = %.2f degrees\n",      $prefix, $self->betafuzz);
  $header .= sprintf("%s Rmultiplier = %.2f\n",             $prefix, $self->rmultiplier);
  $header .= sprintf("%s Suppressing eta: %s\n",            $prefix, $self->yesno($self->eta_suppress));
  if ($self->nlegs > 4) {
    $header .= sprintf("%s Suppressing steep angle for 5&6 legged paths: %s (fs_angle = %.2f)\n",
		       $prefix, $self->yesno($self->co->default('pathfinder', 'suppress_5_6_not_straight')), $self->co->default('pathfinder','fs_angle'));
  };
  $header .= sprintf("%s Ranking criterion = %s   --   %s\n", $prefix, $self->co->default('pathfinder','rank'),
		                                $self->explain_ranking($self->co->default('pathfinder','rank')));
  $header .= sprintf("%s Post criterion = %.2f\n",          $prefix, $self->postcrit);
  $header .= $prefix . " " . "-" x 70 . "\n";
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
  open(my $PD, ">", $pd);
  print $PD $self->_pathsdat_head;
  print $PD $sp  -> pathsdat(index=>$self->co->default('pathfinder', 'one_off_index'));
  #local $|=1;
  #print STDOUT $sp  -> pathsdat(index=>$self->co->default('pathfinder', 'one_off_index'));
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

sub fetch_zcwifs {
  my ($self) = @_;
  $self -> pathsdat;
  $self -> make_feffinp("genfmt") -> run_feff;

  opendir(my $D, $self->workspace);
  map {unlink File::Spec->catfile($self->workspace, $_) if $_ =~ m{feff\d+\.dat}} readdir $D;
  closedir $D;

  my @zcwifs;
  my $file = ($self->feff_version == 8) ? 'list.dat' : 'files.dat';
  ## a feff8.inp file can be parsed for used with feff6, thus using
  ## files.dat, but the feff object will be flagged as being for feff8, hence...
  $file = 'files.dat' if (($self->feff_version == 8) and (not -e File::Spec->catfile($self->workspace, $file)));
  return () if (not -e File::Spec->catfile($self->workspace, $file));
  open(my $FD, '<', File::Spec->catfile($self->workspace, $file));
  my $flag = 0;
  while (<$FD>) {
    $flag = 1, next if ($_ =~ m{amp ratio});
    next if not $flag;
    my @list = split(" ", $_);
    push @zcwifs, $list[2];
  };
  close $FD;
  unlink File::Spec->catfile($self->workspace, 'files.dat');
  unlink File::Spec->catfile($self->workspace, 'nstar.dat');
  unlink File::Spec->catfile($self->workspace, 'paths.dat');

  return @zcwifs;
};

sub rank_paths {
  my ($self, $how, $hash) = @_;
  $how ||= Demeter->co->default('pathfinder', 'rank');

  $hash->{kmin} ||= 1;
  $hash->{kmax} ||= 15;
  $hash->{rmin} ||= 1;
  $hash->{rmax} ||= 4;
  $hash->{update} ||= q{};
  my $then = DateTime->now;
  my @z = $self->fetch_zcwifs;
  my $i = 0;
  my $screen = ($self->mo->ui eq 'screen');
  my $ranksave = Demeter->co->default('pathfinder', 'rank');
  #my $save = $self->screen;
  #$self->screen(0);
  $self->start_counter("Demeter is ranking paths", $#{$self->pathlist}+1) if $screen;

  my @how = (ref($how) eq 'ARRAY') ? @$how : ($how);
  Demeter->co->set_default('pathfinder', 'rank', $how[0]);
  foreach my $sp (@{ $self->pathlist }) {
    &{$hash->{update}}("Ranking path $i") if ((not $i % 3) and $hash->{update});
    $sp->set_rank('feff', sprintf("%.2f", $z[$i]||0));
    $sp->rank_kmin($hash->{kmin});
    $sp->rank_kmax($hash->{kmax});
    $sp->rank_rmin($hash->{rmin});
    $sp->rank_rmax($hash->{rmax});
    $self->count if $screen;
    $sp->rank($how);
    $i++;
  };
  foreach my $h (@how) {
    #$self->screen($save);
    $self->pathlist->[0]->normalize(@{ $self->pathlist });
    next if not is_Rankings($h);
    next if ($h eq 'peakpos');
    foreach my $sp (@{ $self->pathlist }) {
      if ($sp->get_rank($h) >= $self->co->default('pathfinder', 'rank_high')) {
	$sp->weight(2);
      } elsif ($sp->get_rank($h) <= $self->co->default('pathfinder', 'rank_low')) {
	$sp->weight(0);
      } else {
	$sp->weight(1);
      }
    };
  };
  $self->stop_counter if $screen;

  my $now  = DateTime->now;
  my $duration = $now->subtract_datetime($then);
  printf("Ranking (" . join("+", @how) . ") took around %s seconds\n", $duration->seconds) if $screen;
  return $self;
};


##----------------------------------------------------------------------------
## pathfinder http://xkcd.com/835/


sub pathfinder {
  my ($self) = @_;

  local $SIG{ALRM} = sub { 1; } if not $SIG{ALRM};
  $self->start_spinner("Demeter's pathfinder is running") if ((not $self->screen) and ($self->mo->ui eq 'screen'));
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
  foreach my $sp (@list_of_paths) {
    $sp->pathfinding(0);
    $sp->mo->push_ScatteringPath($sp);
  };
  $self->set(pathlist=>\@list_of_paths, npaths=>$#list_of_paths+1);
  $self->stop_spinner if ((not $self->screen) and ($self->mo->ui eq 'screen'));
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

  $self->report("=== Populating Tree (nlegs = " . $self->nlegs . ";  . = $freq nodes added to the tree;  + = " . $freq*20 . " nodes considered)\n    ");
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
  if ($self->nlegs == 2) {
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
      next if (($self->nlegs == 3) and ($ind  == $cindex)); # exclude absorber from this generation
      next if (_length($cindex, $thiskid, $ind, $cindex) > $rmax2);	     # prune long paths from the tree
      ++$innercount;
      $self->click('.') if not ($innercount % $freq);
      $k->addChild(Tree::Simple->new($ind));
    };
  };
  if ($self->nlegs == 3) {
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

  if ($self->nlegs == 4) {
    $self->report(sprintf("\n    (contains %d nodes from the %d atoms within %.3g Ang.)\n",
			      $tree->size, $natoms, $rmax));
    return $tree;
  };

  ##
  ## Quadruple Scattering Paths (5-legged)
  @kids = $tree->getAllChildren;
  foreach my $k (@kids) {
    my $thiskid = $k->getNodeValue;
    my @grandkids = $k->getAllChildren;
    foreach my $g (@grandkids) {
      my @greatgrandkids = $g->getAllChildren;
      my $thisgk = $g->getNodeValue;
      foreach my $gg (@greatgrandkids) {
	## these represent the quad scattering paths
	my $thisggk = $gg->getNodeValue;
	my $indggk = -1;
	foreach my $s (@sites) {
	  ++$indggk;
	  ++$outercount;
	  $self->click('.') if not ($outercount % ($freq*20));
	  next if ($leglength[$cindex][$indggk] > $rmax); # prune distant atoms
	  next if ($thisggk == $indggk);  # avoid same atom twice
	  ##next if (($self->get('nlegs') == 4) and ($indgk  == $cindex)); # exclude absorber from this generation
	  ##next if ($indgk  == $cindex); # exclude absorber from this generation
	  next if (_length($cindex, $thiskid, $thisgk, $thisggk, $indggk, $cindex) > $rmax2);        # prune long paths from the tree
	  ++$innercount;
	  $self->click('.') if not ($innercount % $freq);
	  $gg -> addChild(Tree::Simple->new($indggk));
	};
      };
    };
  };

  if ($self->nlegs == 5) {
    $self->report(sprintf("\n    (contains %d nodes from the %d atoms within %.3g Ang.)\n",
			      $tree->size, $natoms, $rmax));
    return $tree;
  };

  ##
  ## Quintuple Scattering Paths (6-legged)
  @kids = $tree->getAllChildren;
  foreach my $k (@kids) {
    my $thiskid = $k->getNodeValue;
    my @grandkids = $k->getAllChildren;
    foreach my $g (@grandkids) {
      my @greatgrandkids = $g->getAllChildren;
      my $thisgk = $g->getNodeValue;
      foreach my $gg (@greatgrandkids) {
	my @greatgreatgrandkids = $gg->getAllChildren;
	my $thisggk = $gg->getNodeValue;
	foreach my $ggg (@greatgreatgrandkids) {
	  ## these represent the quad scattering paths
	  my $thisgggk = $ggg->getNodeValue;
	  my $indgggk = -1;
	  foreach my $s (@sites) {
	    ++$indgggk;
	    ++$outercount;
	    $self->click('.') if not ($outercount % ($freq*20));
	    next if ($leglength[$cindex][$indgggk] > $rmax); # prune distant atoms
	    next if ($thisgggk == $indgggk);  # avoid same atom twice
	    ##next if (($self->get('nlegs') == 4) and ($indgk  == $cindex)); # exclude absorber from this generation
	    ##next if ($indgk  == $cindex); # exclude absorber from this generation
	    next if (_length($cindex, $thiskid, $thisgk, $thisggk, $thisgggk, $indgggk, $cindex) > $rmax2);        # prune long paths from the tree
	    ++$innercount;
	    $self->click('.') if not ($innercount % $freq);
	    $ggg -> addChild(Tree::Simple->new($indgggk));
	  };
	};
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
  $self->report("=== Traversing Tree and populating Heap (. = $freq nodes examined)\n    ");;
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
  my $sp     = Demeter::ScatteringPath->new(feff=>$feff, string=>$string, site_fraction=>$feff->site_fraction);
  $sp       -> evaluate;
  ## prune branches that involve non-0 eta angles (if desired)
  if ($feff->eta_suppress and $sp->etanonzero) {
    $sp->DEMOLISH;
    return 0;
  };
  if (Demeter->co->default('pathfinder', 'suppress_5_6_not_straight') and ($sp->nleg > 4) and ($sp->betanotstraightish)) {
    $sp->DEMOLISH;
    return 0;
  };
  $heap -> add($sp);
  $$rhc += 1;
  return 1;
}

=for Explanation
    _parentage
      Construct the path's string by recursing up its branch in the
      tree.  The string is the index (from the site list) of each atom
      in the path concatinated with dots.

=cut
sub _parentage {
  ##my ($tree, $this) = @_;
  if (lc($_[0]->getParent) eq 'root') {
    return q{};
  } else {
    return _parentage($_[0]->getParent, $_[0]->getNodeValue())
      . "."
	. $_[0]->getNodeValue();
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
  #$self->prep_fuzz;
  if (ref($self) =~ m{Aggregate}) {
    foreach my $p (@{$self->parts}) {
      $p->set(fuzz=>$self->fuzz, betafuzz=>$self->betafuzz);
    };
  };

  local $SIG{ALRM} = sub { 1; } if not $SIG{ALRM};

  my $bigcount = 0;
  my $freq     = $self->co->default("pathfinder", "degen_freq");
  my $pattern  = "(%12d examined)";
  $self->report("=== Collapsing Heap to a degenerate list (. = $freq heap elements compared)\n    ");

  my @list_of_paths = ();
  while (my $elem = $heap->extract_top) {
    #print $elem->intrpline2, $/;
    my $new_path = 1;
    ++$bigcount;
    $self->click('.') if not ($bigcount % $freq);

    my $i = 0;
  LOP: foreach my $p (reverse @list_of_paths) {
      my $is_different = $elem->compare($p);
      #Demeter->pjoin($elem->string, $p->string, $is_different);
      last LOP if ($is_different eq 'lengths different');
      if (not $is_different) {
	my @degen = @{ $p->degeneracies };
	push @degen, $elem->string;
	$p->n( $p->n + $elem->site_fraction );
	#$p->n($#degen+1);
	$p->degeneracies(\@degen);
	my $fuzzy = $p->fuzzy + $elem->halflength*$elem->site_fraction;
	$p->fuzzy($fuzzy);
	$new_path = 0;
	last LOP;
      };
    };
    if ($new_path) {
      $elem->n($elem->site_fraction);
      $elem->fuzzy($elem->halflength*$elem->site_fraction);
      $elem->degeneracies([$elem->string]);
      push(@list_of_paths, $elem);
    } else {
      $elem->DEMOLISH;
    };
  };

  foreach my $sp (@list_of_paths) {
    $sp->fuzzy($sp->fuzzy/$sp->n);
  };
  my $path_count = $#list_of_paths+1;
  $self->report("\n    (found $path_count unique paths)\n");
  return @list_of_paths;
};

sub list_of_paths {
  my ($self) = @_;
  return @{ $self->pathlist };
};


sub intrp_header {
  my ($self, %markup) = @_;
  map {$markup{$_} ||= q{} } qw(comment open close 0 1 2);
  my $text = q{};
  my $about = (ref($self) =~ m{Aggregate}) ? q{~} : q{};
  my @list_of_paths = @{ $self-> pathlist };
  my @miscdat = map {'# '.$_} grep {$_ =~ m{\A\s*(?:Abs|Pot|Gam|Mu)}} split(/\n/, $self->miscdat);
  my @lines = (split(/\n/, $self->_pathsdat_head('#')), @miscdat, "# " . "-" x 70 . "\n");
  $text .= $markup{comment} . shift(@lines) . $markup{close} . "\n";
  $text .= $markup{comment} . shift(@lines) . $markup{close} . "\n";
  $text .= sprintf "%s# The central atom is denoted by this token: %s%s\n",      $markup{comment}, $self->co->default("pathfinder", "token") || '<+>', $markup{close};
  $text .= sprintf "%s# Cluster size = %.2f A, containing %s%s atoms%s\n", $markup{comment}, $self->rmax, $about, $self->nsites,                         $markup{close};
  $text .= sprintf "%s# %d paths were found within %.3f A%s\n",                                $markup{comment}, $#list_of_paths+1, $self->rmax,                     $markup{close};
  $text .= sprintf "%s# Forward scattering cutoff %.2f%s\n",                     $markup{comment}, $self->co->default("pathfinder", "fs_angle"),       $markup{close};
  foreach (@lines) { $text .= $markup{comment} . $_ . $markup{close} . "\n"};
  chomp $text;
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
  $text .=  $markup{comment} . "#       degen     Reff       scattering path                   ";
  $text .= " " x 11 if $self->is_polarization;
  $text .= "I    Rank  legs   type" .  $markup{close} . "\n";
  my $i = 1;
  foreach my $sp (@list_of_paths) {
    last if ($rmax and ($sp->halflength > $rmax));
    $text .= $markup{$sp->weight} . $sp->intrpline($i++) . $markup{close} . $/;
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

sub run_feff {
  my ($self) = @_;
  my $cwd = cwd();
  chdir $self->workspace;
  if ($self->is_windows) {
    my $message = Demeter->check_exe('feff');
    die $message if ($message);
  };
  my $exe = $self->co->default("feff", "executable");
  unless ($self->is_windows) { # avoid problems if feff->feff_executable isn't
    my $which = `which "$exe"`;
    chomp $which;
    if (not -x $which) {
      croak("Could not find the Feff executable (" . $self->co->default('feff', 'executable') . ")");
    };
  };

  ## -------- the following commented bit is how I have solved the
  ##          problem of running Feff since the old Tk/Artemis days
  local $| = 1;		# unbuffer output of fork
  eval '
  my $pid = open(my $WRITEME, "$exe |");
  while (<$WRITEME>) {
    $self->report($_);
  };
  close $WRITEME;';
  #&{$self->execution_wrapper}($@)  if ($@ and $self->execution_wrapper);
  #carp $@ if ($@);

  ## -------- the following is a more robust, CPAN-reliant way of
  ##          running Feff
  # if ($self->execution_wrapper) {
  #   &{$self->execution_wrapper};
  # } else {
  #   my ($stdout, $stderr) = tee { system "\"$exe\"" };
  #   $self->report($stdout);
  #   $self->report($stderr, 1);
  # };

  chdir $cwd;
  return $self;
};


sub click {
  my ($self, $char) = @_;
  &{$self->execution_wrapper}($char) if ($self->execution_wrapper);
  if ($self->screen) {
    local $|=1;
    print $char;
  }
}


## dispose of Feff's screen output to various channels
sub report {
  my ($self, $string, $err) = @_;
  local $| = 1;
  ## GUI
  &{$self->execution_wrapper}($string)  if ($self->execution_wrapper);
  ## screen
  my $which = ($err) ? 'fefferr' : 'feffout';
  if ($self->screen) {
    local $|=1;
    print $self->_ansify($string, $which);
  };
  ## buffer
  if ($self->buffer) {
    my @list = split("\n", $string);
    $self->push_iobuffer(@list);
  };
  return $self;
};



##-------------------------------------------------------------------------
## serializing/deserializing

override serialization => sub {
  my ($self) = @_;

  my %cards = ();
  foreach my $key (qw(abs_index edge s02 rmax name nlegs npaths rmultiplier pcrit ccrit
		      workspace screen buffer save fuzz betafuzz eta_suppress miscdat
		      group hidden source feff_version scf fms ldos xanes polarization ellipticity)) {
    $cards{$key} = $self->$key;
  };
  $cards{zzz_arrays} = "titles othercards potentials absorber sites";

  my $text = YAML::Tiny::Dump(\%cards);
  foreach my $key (split(" ", $cards{zzz_arrays})) {
    $text .= YAML::Tiny::Dump($self->get($key));
  };
  ## dump attributes of each ScatteringPath object
  foreach my $sp ( @{$self->pathlist}) {
    $text .= $sp->serialization;
  };
  return $text;
};

sub serialize {
  my ($self, $filename, $nozip) = @_;
  croak("No filename specified for serializing Feff object") unless $filename;

  if ($nozip) {
    open my $Y, ">".$filename;
    print $Y $self->serialization;
    close $Y;
  } else {
    my $gzout = gzopen($filename, 'wb9');
    $gzout->gzwrite($self->serialization);
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
  my @refs = YAML::Tiny::Load($yaml);
  $gz->gzclose;
  $self->read_yaml(\@refs);
  return $self;
};
sub read_yaml {
  my ($self, $refs, $ws) = @_;
  my @refs = @$refs;
  ## snarf attributes of Feff object
  my $rhash = shift @refs;
  $self -> set(titles     => shift(@refs),
	       othercards => shift(@refs),
	       potentials => shift(@refs),
	       absorber   => shift(@refs),
	       sites	  => shift(@refs));
  foreach my $key (qw(abs_index edge s02 rmax name nlegs npaths rmultiplier pcrit ccrit
		      screen buffer save fuzz betafuzz eta_suppress miscdat
		      hidden source polarization ellipticity)) {
    $self -> $key($rhash->{$key}) if exists $rhash->{$key};
  };
  if (defined $ws) {
    $self->workspace($ws);
  } else {
    $self->workspace($rhash->{workspace});
  };
  #$self -> prep_fuzz;
  ## snarf attributes of each ScatteringPath object
  my @paths;
  foreach my $path (@refs) {
    my $sp = Demeter::ScatteringPath->new(feff=>$self, pathfinding=>0);
    $sp->mo->push_ScatteringPath($sp);
    foreach my $key ($sp->savelist) {
      next if not defined $path->{$key};
      $sp -> $key($path->{$key});
    };
    push @paths, $sp;
  };
  $self->pathlist(\@paths);

  return $self;
};
alias freeze => 'serialize';
alias thaw   => 'deserialize';

sub run_atoms {
  my ($self) = @_;
  my ($fh, $fname) = tempfile(q{feff.inp.XXXXXX}, DIR=>$self->stash_folder);
  print $fh $self->atoms->Write;
  close $fh;
  $self->file($fname);
  unlink $fname;
  return $self;
};


__PACKAGE__->meta->make_immutable;
1;


=head1 NAME

Demeter::Feff - Make and manipulate Feff calculations


=head1 VERSION

This documentation refers to Demeter version 0.9.24.


=head1 SYNOPSIS

  my $feff = Demeter::Feff -> new(file => 'feff.inp');
  $feff->set(workspace=>"temp", screen=>1);
  $feff->run;
  $feff->intrp;


=head1 DESCRIPTION

This subclass of the Demeter class is for interacting with theory from
Feff.  Computing the C<phase.bin> file is done by Feff via a pipe, as
is running the genfmt portion of Feff.  Parsing the input file,
pathfinding, and generating the C<paths.dat> to control genfmt have
been implemented as methods of this object.

=head1 ATTRIBUTES

=over 4

=item C<file>

The name of a F<feff.inp> file.

=item C<yaml>

The name of a file containing a serialization of a Feff calculation.

=item C<atoms>

A L<Demeter::Atoms> object from which a F<feff.inp> file will be
generated automatically.

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
F<phase.bin> file is generated.

=item C<pathlist>

A reference to the list of ScatteringPath objects generated by the
C<pathfinder> method.

=item C<hidden>

This boolean attribute is true if this is a "hidden" Feff calculation.
As example of this is the Feff calculation associated with a
L<Demeter::FSPath> object.  In that case, the Feff calculation is
intended to be done completely bihind the scenes and the user will
normally not interact with it directly.  In the contextof Artemis,
this means that an entry in the Feff toolbar will not be shown for the
FSPath object.

=item C<source>

This is a string that is used to identify the provenance of the Feff
calculation.  The default is "demeter/feff6", indicating that the Feff
calculation was handled entirely by Demeter.  For a
Demeter::Feff::External object, this is set to "external", indicating
that the Feff calculation was imported from outside of Demeter.

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

This is triggered when the C<file> attribute is set.

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

=item C<run>

This calls C<potph> then C<pathfinder>.  It is proving common to chain
these two methods, so it seems useful to provide a shortcut.

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

=item C<rank_paths>

Perform various rankins of the importance of the various paths found
using Demeter's pathfinder.  One of these is to run Feff on the entire
path list and extract the curved wave importance factors from the
F<files.dat> file.  Other rankings are performed using
L<Demeter::ScatteringPath::Rank>.  The rankings are stored in the
ScatteringPath object.

  $feff -> pathfinder;
  ## some time later ...
  $feff->rank_paths;

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

=item C<list_of_paths>

Returns a list of ScatteringPath objects found by the path finder.
This simply dereferences the anonymous array contained in the
C<pathlist> attribute and returns the list.

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
F<Build.PL> file.

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

Please report problems to the Ifeffit Mailing List
(L<http://cars9.uchicago.edu/mailman/listinfo/ifeffit/>)

Patches are welcome.

=head1 AUTHOR

Bruce Ravel, L<http://bruceravel.github.io/home>

L<http://bruceravel.github.io/demeter/>


=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2016 Bruce Ravel (L<http://bruceravel.github.io/home>). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
