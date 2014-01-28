package Demeter::Atoms;

=for Copyright
 .
 Copyright (c) 2006-2013 Bruce Ravel (bravel AT bnl DOT gov).
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
with 'Demeter::Tools';
with 'Demeter::Atoms::Absorption';
with 'Demeter::Atoms::Cif' if $Demeter::STAR_Parser_exists;
use Demeter::StrTypes qw( Element
			  Edge
			  AtomsLattice
			  AtomsGas
			  AtomsObsolete
			  SpaceGroup
			  FileName
			  Empty
		       );
use Demeter::NumTypes qw( Natural
			  PosInt
			  PosNum
			  NonNeg
			  OneToFour
			  FeffVersions
		       );


#use diagnostics;
use Carp;
use Chemistry::Elements qw(get_Z);
use File::Basename;
use List::Util qw(min max reduce);
#use Math::Cephes::Fraction qw(fract);
use POSIX qw(ceil);
use Safe;
use Text::Template;
use Xray::Absorption;
use Xray::Crystal;

use Demeter::Constants qw($NUMBER $SEPARATOR $EPSILON4 $FEFFNOTOK);
use Const::Fast;
const my $FRAC      => 100000;

const my %EDGE_INDEX => (k =>1,  l1=>2,  l2=>3,  l3=>4,
			 m1=>5,  m2=>6,  m3=>7,  m4=>8,  m5=>9,
			 n1=>10, n2=>11, n3=>12, n4=>13, n5=>14, n6=>15, n7=>16,
			);


#has 'cell' => (is => 'rw', isa =>Empty.'|Xray::Crystal::Cell', default=> q{});
has 'cell' => (is => 'rw', isa =>'Any', default=> sub{Xray::Crystal::Cell->new;},
	      );
has 'space'	       => (is => 'rw', isa => 'Str', default => sub{q{}},
			   trigger => sub{ my ($self, $new) = @_;
					  return if not $new;
					  $self -> cell -> space_group($new);
					  $self->is_populated(0);
					  $self->absorption_done(0);
					  $self->mcmaster_done(0);
					  $self->i0_done(0);
					  $self->self_done(0);
					});
has 'a'		       => (is => 'rw', isa => NonNeg,    default=> 0,
			   trigger => sub{ my ($self, $new) = @_; 
					  return if not $new;
					  $self->is_populated(0);
					  $self->absorption_done(0);
					  $self->mcmaster_done(0);
					  $self->i0_done(0);
					  $self->self_done(0);
					});
has 'b'		       => (is => 'rw', isa => NonNeg,    default=> 0,
			   trigger => sub{ my ($self, $new) = @_; 
					  return if not $new;
					  $self->is_populated(0);
					  $self->absorption_done(0);
					  $self->mcmaster_done(0);
					  $self->i0_done(0);
					  $self->self_done(0);
					});
has 'c'		       => (is => 'rw', isa => NonNeg,    default=> 0,
			   trigger => sub{ my ($self, $new) = @_; 
					  return if not $new;
					  $self->is_populated(0);
					  $self->absorption_done(0);
					  $self->mcmaster_done(0);
					  $self->i0_done(0);
					  $self->self_done(0);
					});
has 'alpha'	       => (is => 'rw', isa => NonNeg,    default=> 90,
			   trigger => sub{ my ($self, $new) = @_; 
					  return if not $new;
					  $self->is_populated(0);
					  $self->absorption_done(0);
					  $self->mcmaster_done(0);
					  $self->i0_done(0);
					  $self->self_done(0);
					});
has 'beta'	       => (is => 'rw', isa => NonNeg,    default=> 90,
			   trigger => sub{ my ($self, $new) = @_; 
					  return if not $new;
					  $self->is_populated(0);
					  $self->absorption_done(0);
					  $self->mcmaster_done(0);
					  $self->i0_done(0);
					  $self->self_done(0);
					});
has 'gamma'	       => (is => 'rw', isa => NonNeg,    default=> 90,
			   trigger => sub{ my ($self, $new) = @_; 
					  return if not $new;
					  $self->is_populated(0);
					  $self->absorption_done(0);
					  $self->mcmaster_done(0);
					  $self->i0_done(0);
					  $self->self_done(0);
					});
has 'rmax'	       => (is => 'rw', isa => NonNeg,    default=> sub{ shift->co->default("atoms", "rmax")  ||  8},
			   trigger => sub{ my ($self, $new) = @_; $self->is_expanded(0) if $new});
has 'rpath'	       => (is => 'rw', isa => NonNeg,    default=> sub{ shift->co->default("atoms", "rpath") ||  5},
			   trigger => sub{ my ($self, $new) = @_; $self->is_expanded(0) if $new});
has 'rscf'	       => (is => 'rw', isa => NonNeg,    default=> sub{ shift->co->default("atoms", "rscf")  ||  5},);
has 'do_scf'           => (is => 'rw', isa =>'Bool', default=> 0);

has 'rss'	       => (is => 'rw', isa => NonNeg,    default=> 0);
has 'edge'	       => (is => 'rw', isa => Empty.'|'.Edge, coerce => 1, default=> q{},
			   trigger => sub{ my ($self, $new) = @_; 
					   if (exists($EDGE_INDEX{lc($new)})) {
					     my ($central, $xcenter, $ycenter, $zcenter) = $self -> cell -> central($self->core);
					     $self->iedge($EDGE_INDEX{lc($new)});
					     $self->eedge(Xray::Absorption->get_energy($central->element, $new)) if ($central =~ m{Site});
					   } else {
					     $self->iedge(0);
					     $self->eedge(0);
					   };
					 });
has 'iedge'	       => (is => 'rw', isa => Natural,    default=> 1);
has 'eedge'	       => (is => 'rw', isa => NonNeg,    default=> 0);
has 'core'	       => (is => 'rw', isa =>'Str',      default=> q{});
has 'corel'	       => (is => 'rw', isa =>'Str',      default=> q{});
has 'partial_occupancy' => (is => 'rw', isa =>'Bool', default=> 0);
has 'shift' => (
		traits    => ['Array'],
		is        => 'rw',
		isa       => 'ArrayRef',
		default   => sub { [0, 0, 0] },
		handles   => {
			      'push_shift'  => 'push',
			      'pop_shift'   => 'pop',
			      'clear_shift' => 'clear',
			     }
	       );
has 'file'   => (is => 'rw', isa =>FileName, default=> q{},
		 trigger => sub{ my ($self, $new) = @_;
				 if ($new) {
				   $self->read_inp;
				   #$self->update_edge;
				 };
			       });
has 'cif'    => (is => 'rw', isa =>FileName, default=> q{},
		 trigger => sub{ my ($self, $new) = @_;
				 if ($new) {
				   if (not $Demeter::STAR_Parser_exists) {
				     warn "STAR::Parser is not available, so CIF files cannot be imported";
				     return;
				   };
				   $self->read_cif;
				   #$self->update_edge;
				 };
			       });
has 'record' => (is => 'rw', isa => NonNeg,    default=> 0,
		 trigger => sub{ my ($self, $new) = @_;
				 if (not $Demeter::STAR_Parser_exists) {
				   warn "STAR::Parser is not available, so CIF files cannot be imported";
				   return;
				 };
				 $self->read_cif if ($new and $self->cif);
			       });
has 'titles' => (
		 traits    => ['Array'],
		 is        => 'rw',
		 isa       => 'ArrayRef[Str]',
		 default   => sub { [] },
		 handles   => {
			       'push_titles'  => 'push',
			       'pop_titles'   => 'pop',
			       'clear_titles' => 'clear',
			      }
		);
has 'ipot_style'       => (is => 'rw', isa =>'Str', default=> sub{ shift->mo->config->default("atoms","ipot_style") || 'elements'},
			   trigger => sub{ my ($self, $new) = @_; $self->is_ipots_set(0) if $new});
has 'feff_version'     => (is => 'rw', isa => FeffVersions, default=>sub{ shift->mo->config->default("atoms","feff_version") || 6});

has 'nitrogen'	       => (is => 'rw', isa => NonNeg, default=> 0,
			   trigger => sub{ my ($self, $new) = @_; ($new) ? $self->gases_set(1) : $self->gases_set(0) });
has 'argon'	       => (is => 'rw', isa => NonNeg, default=> 0,
			   trigger => sub{ my ($self, $new) = @_; ($new) ? $self->gases_set(1) : $self->gases_set(0) });
has 'xenon'	       => (is => 'rw', isa => NonNeg, default=> 0,
			   trigger => sub{ my ($self, $new) = @_; ($new) ? $self->gases_set(1) : $self->gases_set(0) });
has 'krypton'	       => (is => 'rw', isa => NonNeg, default=> 0,
			   trigger => sub{ my ($self, $new) = @_; ($new) ? $self->gases_set(1) : $self->gases_set(0) });
has 'helium'	       => (is => 'rw', isa => NonNeg, default=> 0,
			   trigger => sub{ my ($self, $new) = @_; ($new) ? $self->gases_set(1) : $self->gases_set(0) });
has 'gases_set'        => (is => 'rw', isa =>'Bool',  default=> 0);

has 'xsec'	       => (is => 'rw', isa =>'LaxNum', default=> 0);
has 'deltamu'	       => (is => 'rw', isa =>'LaxNum', default=> 0);
has 'density'	       => (is => 'rw', isa =>'LaxNum', default=> 0);
has 'mcmaster'	       => (is => 'rw', isa =>'LaxNum', default=> 0,
			   trigger => sub{ my ($self, $new) = @_; my $n= $self->netsig; $self->netsig($n+$new); });
has 'i0'	       => (is => 'rw', isa =>'LaxNum', default=> 0,
			   trigger => sub{ my ($self, $new) = @_; my $n= $self->netsig; $self->netsig($n+$new); });
has 'selfamp'	       => (is => 'rw', isa =>'LaxNum', default=> 0);
has 'selfsig'	       => (is => 'rw', isa =>'LaxNum', default=> 0,
			   trigger => sub{ my ($self, $new) = @_; my $n= $self->netsig; $self->netsig($n+$new); });
has 'netsig'	       => (is => 'rw', isa =>'LaxNum', default=> 0);

has 'is_imported'      => (is => 'rw', isa =>'Bool', default=> 0,
			   trigger => sub{ my ($self, $new) = @_; $self->is_populated(0) if ($new==0); });
has 'is_populated'     => (is => 'rw', isa =>'Bool', default=> 0,
			   trigger => sub{ my ($self, $new) = @_; $self->is_ipots_set(0) if ($new==0); });
has 'is_ipots_set'     => (is => 'rw', isa =>'Bool', default=> 0,
			   trigger => sub{ my ($self, $new) = @_; $self->is_expanded(0)  if ($new==0); });
has 'is_expanded'      => (is => 'rw', isa =>'Bool', default=> 0);
has 'absorption_done'  => (is => 'rw', isa =>'Bool', default=> 0);
has 'mcmaster_done'    => (is => 'rw', isa =>'Bool', default=> 0);
has 'i0_done'	       => (is => 'rw', isa =>'Bool', default=> 0);
has 'self_done'	       => (is => 'rw', isa =>'Bool', default=> 0);

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
has 'cluster' => (
		  traits    => ['Array'],
		  is        => 'rw',
		  isa       => 'ArrayRef',
		  default   => sub { [] },
		  handles   => {
				'push_cluster'  => 'push',
				'pop_cluster'   => 'pop',
				'clear_cluster' => 'clear',
			       }
		 );
has 'nclus'	       => (is => 'rw', isa =>'Str', default=> 0);


sub BUILD {
  my ($self, @params) = @_;
  $self->mo->push_Atoms($self);
};

sub DEMOLISH {
  my ($self) = @_;
  $self->alldone;
};

sub refresh {
  my ($self) = @_;
  $self->is_populated(0);
};

sub out {
  my ($self, $key) = @_;
  my $format = $self->co->default("atoms", "precision") || "9.5f";
  $format = '%' . $format;
  my $val = sprintf("$format", $self->$key);
  return $val;
};

sub clear {
  my ($self) = @_;
  $self->$_(0)  foreach (qw(a b c rmax nitrogen argon xenon helium krypton gases_set));
  $self->$_(90) foreach (qw(alpha beta gamma));
  $self->space(q{});
  $self->edge(q{});
  $self->clear_sites;
  $self->clear_cluster;
  $self->clear_shift;
  $self->clear_titles;
  $self->cell->clear;
  $self->is_imported(0);
  $self->is_populated(0);
  $self->is_ipots_set(0);
  $self->is_expanded(0);
  $self->absorption_done(0);
  $self->mcmaster_done(0);
  $self->i0_done(0);
  $self->self_done(0);
};

sub read_inp {
  my ($self) = @_;
  my $reading_atoms_list = 0;
  $self->clear;
  my $file = $self->file;
  croak("Atoms: no input file provided")      if (not    $file);
  croak("Atoms: \"$file\" does not exist")    if (not -e $file);
  croak("Atoms: \"$file\" could not be read") if (not -r $file);
  #$self->set(file=>$file);

  open(my $INP, $file);
  while (my $line = (<$INP>)) {
    next if ($line =~ m{\A\s*\z});
    next if ($line =~ m{\A\s*[\#\%\!\*]});
    next if ($line =~ m{\A\s*-{2,}});

    chomp $line;
    $line =~ s{^\s+}{};
    $line =~ s{\s+$}{};

    ($reading_atoms_list) and do {
      $self->parse_atoms_line($line);
      next;
    };

    ($line =~ m{\A\s*title}) and do {
      $line =~ s{\A\s*title\s*=?\s*}{};
      $self->push_titles($line);
      next;
    };

    ($line =~ m{\A\s*atoms?}) and do {
      # read the remaining lines as the atoms list
      $reading_atoms_list = 1;
      next;
    };

    ## parse each line
    $self->parse_line($line);

  };
  close $INP;
  $self->is_imported(1);
  return $self;
};

sub parse_line {
  my ($self, $line) = @_;
  #return if not $line;
  my $file = $self->file;

  my @words = split(/$SEPARATOR/, $line);
  my $key = shift @words;

  (my $rest = $line) =~ s{\A$key$SEPARATOR}{};

  if ($key =~ m{space(?:group)?}i) {
    my $end = (length($rest) < 10) ? length($rest) : 10;
    my $sg = substr($rest, 0, $end);
    $self->space($sg);
    $rest = substr($rest, $end, -1);
  } else {
    @words = split(/$SEPARATOR/, $rest);
    my $val = shift @words;
    $rest =~ s{$val(?:$SEPARATOR)?}{};
    my $vv = ($key =~ m{\bout}) ? shift @words : q{};
    $rest =~ s{$vv(?:$SEPARATOR)?}{};
    my $vvv = ($key =~ m{shi|daf|qve|ref}) ? shift @words : q{};
    $rest =~ s{$vvv(?:$SEPARATOR)?}{};
    my $vvvv = ($key =~ m{shi|daf|qve|ref}) ? shift @words : q{};
    $rest =~ s{$vvvv(?:$SEPARATOR)?}{};

    return if ($key =~ m{\#});
    $key = lc($key);
    if (($self->meta->has_method($key)) and ($key =~ m{shi|daf|qve|ref})) {
      $self->$key([$val, $vvv, $vvvv]);
    } elsif ($self->meta->has_method($key)) {
      $self->$key(lc($val));
    } elsif (is_AtomsObsolete($key)) {
      carp("\"$key\" is a deprecated Atoms keyword ($file line $.)\n\n");
    } else {
      carp("\"$key\" is not an Atoms keyword ($file line $.)\n\n");
    };
  };
  $self->parse_line($rest) if (($rest !~ m{\A\s*\z}) and ($rest !~ m{\A\s*[\#\%\!\*]}));
  return $self;
};

sub parse_atoms_line {
  my ($self, $line) = @_;
  return 0 if ($line =~ m{\A\s*[\#\%\!\*]});
  my ($el, $x, $y, $z, $tag) = split(" ", $line);
  $tag ||= $el;
  ($tag = $el) if ($tag =~ m{\A$NUMBER\z});
  $tag =~ s{$FEFFNOTOK}{}g; # scrub characters that will confuse Feff
  my $this = join("|",$el, $x, $y, $z, $tag);
  $self->push_sites($this);
  return $self;
};


sub populate {
  my ($self) = @_;
  my @sites;
  my $ra = $self->sites;
  foreach my $s (@$ra) {
    my ($el, $x, $y, $z, $tag) = split(/\|/, $s);
    croak("$el is not a valid element symbol\n") if not is_Element($el);
    next if (lc($el) =~ m{\Anu});
    push @sites, Xray::Crystal::Site->new(element=>$el, x=>_interpret($x), y=>_interpret($y), z=>_interpret($z), tag=>$tag);
  };
  ### creating and populating cell
  return $self if not $self->space;
  $self -> cell -> space_group($self->space);
  foreach my $key (qw(a b c alpha beta gamma)) {
    my $val = $self->$key;
    $self -> cell->$key($val) if $val;
  };
  ## Group: $cell->get(qw(given_group space_group class setting))
  ## Bravais: $cell->get('bravais')
  $self -> cell -> populate(\@sites);
  foreach my $key (qw(a b c alpha beta gamma)) {
    $self->$key($self->cell->$key);
  };
  my ($central, $xcenter, $ycenter, $zcenter) = $self -> cell -> central($self->core);
  $self->update_edge;
  $self->set(is_populated => 1,
	     corel        => ucfirst(lc($central->element)),
	    );
  return $self;
};


sub element_check {
  my ($self, $sym) = @_;
  return is_Element($sym);
};

sub _interpret {
  my ($str) = @_;
  my $cpt = new Safe;
  my $retval = $cpt->reval($str);
  return $retval;
};

sub build_cluster {
  my ($self) = @_;
  $self->populate if (not $self->is_populated);
  my ($cell, $core) = $self->get("cell", "core");
  my @sites = @{ $cell->sites };
  map { $_ -> in_cluster(0) } @sites;

  my $rmax = $self->rmax;
  my @cluster = ();
  my ($central, $xcenter, $ycenter, $zcenter) = $cell -> central($core);
  #print join(" ", $xcenter, $ycenter, $zcenter), $/;
  my $setting	      = $cell->group->setting;
  my $crystal_class   = $cell->group->class;
  my $do_tetr	      = ($crystal_class eq "tetragonal" ) && ($setting);

  #### here
  my ($aa, $bb, $cc) = $cell -> get("a", "b", "c");
  #print join(" ", $aa, $bb, $cc), $/;
  my $xup = ceil($rmax/$aa - 1 + $xcenter);
  my $xdn = ceil($rmax/$aa - $xcenter);
  my $yup = ceil($rmax/$bb - 1 + $ycenter);
  my $ydn = ceil($rmax/$bb - $ycenter);
  my $zup = ceil($rmax/$cc - 1 + $zcenter);
  my $zdn = ceil($rmax/$cc - $zcenter);
  ##print join(" ", "up,dn", $xup, $xdn, $yup, $ydn, $zup, $zdn), $/;

  #my $num_z = int($rmax/$cc) + 1; # |
  my $rmax_squared = $rmax**2; # (sprintf "%9.5f", $rmax**2);
  my ($contents) = $cell -> contents;

  foreach my $nz (-$zdn .. $zup) {
    foreach my $ny (-$ydn .. $yup) {
      foreach my $nx (-$xdn .. $xup) {
	foreach my $pos (@{$contents}) {
	  my ($x, $y, $z) = ($$pos[1]+$nx, $$pos[2]+$ny,  $$pos[3]+$nz);
	  ($x, $y, $z) = ($x-$xcenter, $y-$ycenter, $z-$zcenter);
	  ($x, $y, $z) =  $cell -> metric($x, $y, $z);
	  ($do_tetr) and ($x, $y) = (($x+$y)/sqrt(2), ($x-$y)/sqrt(2));
	  #my ($fx, $fy, $fz) = &rectify_formula(@$pos[4..6], $nx, $ny, $nz);
	  #printf "out: %25s %25s %25s\n\n", $fx, $fy, $fz;
	  my $r_squared = sprintf "%9.5f", $x**2 + $y**2 + $z**2;
	  if ($r_squared < $rmax_squared) {
	    my $this_site = [$x, $y, $z, $$pos[0],
			     $r_squared,             # cache the
			     (sprintf "%11.7f", $x), # stuff needed
			     (sprintf "%11.7f", $y), # for sorting
			     (sprintf "%11.7f", $z),
			     #$fx, $fy, $fz,
			    ];
	    $$pos[0] -> in_cluster(1);
	    push @cluster, $this_site;
	    ## (push @neutral, $this_site);
	  };
	};
      };
    };
  };

  ## =============================== sort the cluster (& neutral clus.)
  @cluster = sort {
    ($a->[4] cmp $b->[4]) # sort by distance squared or ...
	or
    ($a->[3] cmp $b->[3]) # by tag alphabetically (using string coercion) or ...
	or
    ($a->[7] cmp $b->[7]) # by z value or ...
        or
    ($a->[6] cmp $b->[6]) # by y value or ...
        or
    ($a->[5] cmp $b->[5]) # by x value
      ##	or
      ## ($ {$b->[3]}->{Host} <=> $ {$a->[3]}->{Host});	# hosts before dopants
  } @cluster;
  if ($#cluster > 499) {
    warn("Your cluster has more than 500 atoms, which is the hard-wired limit for Feff6L.  You might want to reduce the value of Rmax.\n");
  };
  $self->set(cluster => \@cluster,
	     nclus   => $#cluster+1,
	     rss     => sprintf('%'.$self->co->default("atoms", "precision"),
			 $cluster[1]->[4]*$self->co->default("atoms", "smallsphere")),
	    );

#     ## final adjustment to the formulas, store the formulas for the
#     ## central atom ...
#     $keys -> {cformulas} =
#       [$$r_cluster[0][8], $$r_cluster[0][9], $$r_cluster[0][10]];
#     ##   ## ... subtract the central atom coordinates from each site ...
#     ##   foreach my $site (reverse(@$r_cluster)) {
#     ##     (@$site[8..10]) =
#     ##       ($$site[8] . " - Xc", $$site[9] . " - Yc", $$site[10] . " - Zc");
#     ##   };
#     ##   ## ... and set the central atom to an empty string
#     ##   ($$r_cluster[0][8], $$r_cluster[0][9], $$r_cluster[0][10]) = ("", "", "");

    ## if this is a tetragonal crystal in the C or F setting , rotate
    ## all the coordinates back to the original setting
  if ($do_tetr) {
    my ($a, $b) = $cell->get("a", "b");
    $cell->b($a*sqrt(2));
    $cell->b($b*sqrt(2));
  };
  $self->is_expanded(1);
  return $self;
};


sub set_ipots {
  my ($self) = @_;
  $self->build_cluster if (not $self->is_expanded);
  my ($cell, $how) = $self->get("cell", "ipot_style");
  my @sites = @{ $cell->sites };
  my $i = 1;
  my %seen = ();
  if ($how =~ m{\Ata}) {
    foreach my $s (@sites) {
      if ($s->in_cluster) {
	my $tag = lc($s->tag);
	$seen{$tag} = $i++ if (not $seen{$tag});
	$s -> ipot($seen{$tag});
      };
    };
  } elsif ($how =~ m{\Ael}) {
    foreach my $s (@sites) {
      if ($s->in_cluster) {
	my $el = lc($s->element);
	$seen{$el} = $i++ if (not $seen{$el});
	$s -> ipot($seen{$el});
      };
    };
  } else { ## sites
    foreach my $s (@sites) {
      if ($s->in_cluster) {
	$s -> ipot($i);
	++$i
      };
    };
  };

  ## get the reduced stoichiometry for feff8's potentials list
  my @count = (0,0,0,0,0,0,0,0);
  my $top = -999;
  foreach my $s (@sites) {
    my $ipot = $s->ipot;
    $count[$ipot] += $s->in_cell;
    $top = max($top, $ipot);
  };
  ## get greatest common divisor (thanks to Demeter::Tools for
  ## "euclid" (which was swiped from Math::Numbers) and List::Util for
  ## "reduce")
  if ($self->co->default("atoms", "gcd")) {
    my $gcd = reduce { ($self->euclid($a,$b))[0] } @count[1..$top];
    foreach my $s (1 .. $top) {
      $count[$s] /= $gcd;
    };
  };
  foreach my $s (@sites) {
    my $ipot = $s->ipot;
    $s->stoi($count[$ipot]);
  };

  $self->is_ipots_set(1);
  if (--$i > 7) {
    my $ii = $i+1;
    carp("You have $ii unique potentials, but Feff only allows 7.\n\n");
    return -1;
  };
  return 0;
};

override 'template' => sub {
  my ($self, $file, $rhash) = @_;

  my $cell = $self->cell;

  my $tmpl = File::Spec->catfile(dirname($INC{"Demeter.pm"}),
				 "Demeter",
				 "templates",
				 "atoms",
				 "$file.tmpl");
  croak("Unknown Atoms template file -- type $file: $tmpl") if (not -e $tmpl);
  my $template = Text::Template->new(TYPE => 'file', SOURCE => $tmpl)
    or croak("Couldn't construct template: $Text::Template::ERROR");
  $rhash ||= {};
  my $string = $template->fill_in(HASH => {A  => \$self,
					   C  => \$cell,
					   %$rhash},
				  PACKAGE => "Demeter::Templates");
  $string ||= q{};
  $string =~ s{^\s+}{};		# remove leading white space
  $string =~ s{\n(?:[ \t]+\n)+}{\n};	# regularize white space between blocks of text
  $string =~ s{\s+$}{\n};		# remove trailing white space
  $string =~ s{<<->>\n}{}g;		# convert newline token into a real newline
  $string =~ s{<<nl>>}{\n}g;		# convert newline token into a real newline
  $string =~ s{<<( *)>>}{$1}g;	#} # convert white space token into real white space
  return $string;
};


sub cluster_list {
  my ($self, $pattern) = @_;
  $pattern ||= "  %9.5f  %9.5f  %9.5f  %d  %-10s  %9.5f\n";
  $self->set_ipots if (not $self->is_ipots_set);
  my $string = q{};
  my @list = @ {$self->cluster };
  my $abs = shift @list;	# absorber must be ipot 0
  $string .= sprintf($pattern,
		     $abs->[0], $abs->[1], $abs->[2],
		     0, $abs->[3]->tag, sqrt($abs->[4])
		    );
  my %seen;			# index tags by shell
  foreach my $pos (@list) {
    if (not defined($seen{$pos->[3]->tag})) {
      $seen{$pos->[3]->tag} = [1, sqrt($pos->[4])];
    };
    ++$seen{$pos->[3]->tag}->[0] if (sqrt($pos->[4]) - $seen{$pos->[3]->tag}->[1] > $EPSILON4); # increment index if R has increased
    my $tag = join(".", $pos->[3]->tag, $seen{$pos->[3]->tag}->[0]);
    $string .= sprintf($pattern,
		       $pos->[0], $pos->[1], $pos->[2],
		       $pos->[3]->ipot, $tag, sqrt($pos->[4])
		      );
    $seen{$pos->[3]->tag}->[1] = sqrt($pos->[4]);
  };
  return $string;
};
sub R {
  my ($self, $x, $y, $z) = @_;
  return sqrt($x**2 + $y**2 + $z**2);
};

sub potentials_list {
  my ($self, $pattern) = @_;
  $self->set_ipots if (not $self->is_ipots_set);
  $pattern ||= "     %d     %-2d     %-10s\n";
  my ($cell, $core) = $self->get("cell", "core");
  my @sites = @{ $cell->sites };
  my $string = q{};
  my %seen = ();
  my ($abs) = $cell->central($core);
  my $l = Xray::Absorption->get_l($abs->element);
  $string .= sprintf($pattern, 0, get_Z($abs->element), $abs->element,
		     $l, $l, 0.001);
  foreach my $s (sort {$a->ipot <=> $b->ipot} @sites) {
    next if not $s->ipot;
    next if $seen{$s->ipot};
    $l = Xray::Absorption->get_l($s->element);
    $string .= sprintf($pattern, $s->ipot, get_Z($s->element),
		       $s->element, $l, $l, $s->stoi);
    $seen{$s->ipot} = 1;
  };
  return $string;
};


sub sites_list {
  my ($self, $rhash) = @_;
  $self->populate if (not $self->is_populated);
  my $prec = '%'.$self->co->default("atoms", "precision");
  $rhash->{pattern} ||= "  %-2s   $prec   $prec   $prec   %-10s\n";
  $rhash->{prefix}  ||= q{};
  my $cell = $self->cell;
  my $rlist = $cell->sites;
  my $string = q{};
  foreach my $l (@$rlist) {
    $string .= $rhash->{prefix} . sprintf($rhash->{pattern},
					  ucfirst(lc($l->element)),
					  $l->x, $l->y, $l->z, $l->tag);
  };
  return $string;
};
sub p1_list {
  my ($self, $rhash) = @_;
  $self->populate if (not $self->is_populated);
  my $prec = '%'.$self->co->default("atoms", "precision");
  $rhash->{pattern} ||= "  %-2s   $prec   $prec   $prec   %-10s\n";
  $rhash->{prefix}  ||= q{};
  my $cell = $self->cell;
  my $rlist = $cell->contents;
  my $string = q{};
  foreach my $l (@$rlist) {
    $string .= $rhash->{prefix} . sprintf($rhash->{pattern},
					  ucfirst(lc($l->[0]->element)),
					  $$l[1], $$l[2], $$l[3], $l->[0]->tag)
  };
  return $string;
};

sub sg {
  my ($self, $which, $pattern) = @_;
  $self->populate if (not $self->is_populated);
  ($which = "shorthand") if ($which eq 'nicknames');
  my $cell    = $self->cell;
  my $rhash   = $cell->group->data;
  $pattern  ||= "      %-8s  %-8s  %-8s\n";
  my ($prefix, $postfix) = ($which =~ m{(?:bravais|shiftvec)})
                         ? ("      ", $/)
			 : (q{}, q{});
  ## typo?
  return q{} if (not is_SpaceGroup($which));
  ## number of positions
  if ($which eq "npos") {
    my @positions = @ {$$rhash{positions}};
    return $#positions + 1;
  };
  ## key is absent from this entry in database
  return "$prefix<none>$postfix" if ((not exists($$rhash{$which})) and ($which ne "bravais"));
  ## schoenflies
  return ucfirst($$rhash{schoenflies}) if ($which eq "schoenflies");
  ## number or symbol
  return $$rhash{$which} if ($which =~ m{(?:number|full|new_symbol|thirtyfive)});
  ## nicknames
  return join(", ", @{$$rhash{shorthand}}) if ($which eq "shorthand");
  ## shift vector from Int'l Tables
  if ($which eq "shiftvec") {
    #my @shift = map {fract($FRAC*$_, $FRAC)} @{ $$rhash{shiftvec} };
    #return sprintf($pattern, map {$_->as_mixed_string} @shift);
    my @shift = map {$self->fract($_)} @{ $$rhash{shiftvec} };
    return sprintf($pattern, @shift);
  };
  ## Bravais translations
  if ($which eq "bravais") {
    my @bravais = @{ $cell->group->bravais };
    my $string = q{};
    while (@bravais) {
      #my @vec = (fract($FRAC*shift(@bravais), $FRAC),
	#	 fract($FRAC*shift(@bravais), $FRAC),
	#	 fract($FRAC*shift(@bravais), $FRAC),
	#	);
      #$string .= sprintf($pattern, map {$_->as_mixed_string} @vec);
      my @vec = ($self->fract(shift(@bravais)),
		 $self->fract(shift(@bravais)),
		 $self->fract(shift(@bravais)),
		);
      $string .= sprintf($pattern, @vec);
    };
    return $string;
  };
  ## symetric positions
  if ($which eq "positions") {
    my @positions = @ {$$rhash{positions}};
    my $string = q{};
    my $npos = $#positions + 1;
    #$string .= "  $npos positions:\n";
    foreach my $pos (@positions) {
      my @this = @{ $pos };
      map { $this[$_] =~ s{\$}{}g } (0 .. 2);
      $string .= sprintf($pattern, map {($_ =~ m{\A\-}) ? $_ : " $_"} @this);
    };
    return $string;
  };
  return q{};
};


sub all_titles {
  my ($self, $prefix) = @_;
  $prefix ||= " TITLE ";
  my @titles = @{ $self->titles };
  my $string = q{};
  foreach my $t (@titles) {
    $string   .= $prefix . $t . $/;
  };
  return $string;
};

sub update_absorption {
  my ($self) = @_;
  $self->_absorption if not $self->absorption_done;
  $self->_mcmaster   if not $self->mcmaster_done;
  $self->_i0         if (($self->gases_set) and not $self->i0_done);
  $self->_self       if (($self->gases_set) and not $self->self_done);
  return $self;
};

sub update_edge {
  my ($self) = @_;
  return $self if $self->edge;
  my ($central, $xcenter, $ycenter, $zcenter) = $self -> cell -> central($self->core);
  ##print $self->core, $/;
  ##print $central, $/;
  ##print join(" ", $central->meta->get_attribute_list), $/;
  my $z = get_Z( $central->element );
  ($z > 57) ? $self->edge('l3') : $self->edge('k');
  return $self;
};

sub Write {
  my ($self, $type) = @_;
  $type ||= "feff6";
  $type = lc($type);
  ($type = 'feff6') if ($type eq'feff');
  $self->update_absorption;
  return $self->atoms_file             if ($type eq 'atoms');
  return $self->atoms_file('p1')       if ($type eq 'p1');
  return $self->template("absorption") if (($type eq 'absorption') and $self->gases_set);
  return $self->template("mcmaster")   if (($type eq 'absorption') and not $self->gases_set);
  if ($type eq 'spacegroup') {
    $self->populate if (not $self->is_populated);
    return $self->spacegroup_file(0, '# ');
  };
  return $self->Write_feff($type) if ($type =~ m{feff});

  ## still need: overfull, p1_cartesian, gnxas

  ## fallback
  return $self->Write_feff('feff6');
};

sub Write_feff {
  my ($self, $type) = @_;
  $self->build_cluster if (not $self->is_expanded);
  my $string = q{};
  $string .= $self->template('copyright',  {type=> $type, prefix => ' * '});
  if ($self->co->default("atoms", "atoms_in_feff")) {
    $string .= $self->template('prettyline', {prefix => ' * '});
    $string .= $self->atoms_file('feff', ' * ');
    $string .= $self->template('prettyline', {prefix => ' * '});
    $string .= $/;
  }
  if ($self->gases_set) {
    $string .= $self->template('absorption', {prefix => ' * '});
  } else {
    $string .= $self->template('mcmaster', {prefix => ' * '});
  };
  $string .= $self->template($type);
};

sub atoms_file {
  my ($self, $is_p1, $prefix) = @_;
  $is_p1  ||= 0;
  $prefix ||= q{};
  $self->populate if (not $self->is_populated);
  my $cell = $self -> cell;
  my $string = q{};
  my $type = ($is_p1 eq 'p1') ? 'P1'
           : ($is_p1)         ? q{}
	                      : 'Atoms';
  $string   .= $self->template("copyright", {prefix=>$prefix, type=>$type}) if $type;
  $string   .= $self->template("atoms_header", {prefix=>$prefix, is_p1=>($type eq 'P1')});
  $string   .= ($type eq 'P1') ? $self->p1_list({prefix=>$prefix}) : $self->sites_list({prefix=>$prefix});
  return $string;
};

sub spacegroup_file {
  my ($self) = @_;
  my $prefix = '# ';
  my $string = $self->template("copyright", {prefix=>$prefix, type=>"space group"});
  $string   .= $self->template("atoms_header", {prefix=>$prefix});
  $string   .= $self->sites_list({prefix=>$prefix});
  $string   .= $/;
  $string   .= $self->template("spacegroup");
  return $string;
};

override serialization => sub {
  my ($self) = @_;

  my %cards = ();
  foreach my $key (qw(space a b c alpha beta gamma rmax rpath rss edge iedge eedge core corel partial_occupancy
		      shift cif record titles ipot_style nitrogen argon krypton xenon helium gases_set
		      xsec deltamu density mcmaster i0 selfamp selfsig netsig is_imported is_populated
		      is_ipots_set is_expanded absorption_done mcmaster_done i0_done self_done nclus)) { #  sites cluster
    $cards{$key} = $self->$key;
  };

  my $text = YAML::Tiny::Dump(\%cards);
  return $text;
};


__PACKAGE__->meta->make_immutable;
1;

=head1 NAME

Demeter::Atoms - Convert crystallographic data to atomic lists

=head1 VERSION

This documentation refers to Demeter version 0.9.18.

=head1 SYNOPSIS

These lines behave much like any other version of Atoms:

  use Demeter;
  my $atoms = Demeter::Atoms -> new()
    -> read_inp($ARGV[0]||"atoms.inp")
      -> Write('feff6');

=head1 DESCRIPTION

This module implements Atoms in the Demeter system.  The purpose of
Atoms is to convert crystallographic data into a list of atomic
coordinates of the sort used by Feff as input data.  This greatly
simplifies the chore of making Feff input files for crystalline
materials.

=head1 ATTRIBUTES

The following are the attributes of the Data object.  Attempting to
access an attribute not on this list will throw an exception.

The type of argument expected in given in parentheses. i.e. number,
integer, string, and so on.  The default value, if one exists, is
given in square brackets.

=head2 Input parameters

=over 4

=item C<space> (string)

The space group ofthe crystal.  This can be in any form recognized by
L<Xray::Crystal::Cell>, including Hermann-Maguin, Schoenflies, number,
or one of a few nicknames.

=item C<a>	(real)

The length of the A lattice constant in Angstroms.

=item C<b>	(real)

The length of the B lattice constant in Angstroms.

=item C<c>	(real)

The length of the C lattice constant in Angstroms.

=item C<alpha> (real)

The angle between B and C, in degrees.

=item C<beta> (real)

The angle between A and C, in degrees.

=item C<gamma> (real)

The angle between A and B, in degrees.

=item C<rmax> (real)

The extent of the cluster generated from the input crystal data.

=item C<rpath> (real)

The value used for the RMAX keyword in the F<feff.inp> file.  This is
the length of the longest path to be calculated by the pathfinder.  A
value much larger than about 6 will bog down Demeter's pathfinder in
its current form.

=item C<edge> (string) [k or l3 depending on Z-number]

The edge of the absorber.

=item C<core> (string) [first sitin the list]

The identifier of the absorber.  This should be one of the site tags.

=item C<shift> (vector) [0,0,0]

The value of the shift vector, should one be necessary.

=item C<file> (filename)

The name of an atoms input file.

=item C<cif> (filename)

The name of a CIF file.

=item C<record> (string) [0]

The record to import from a multi-record CIF file.  The default is to
read the first record.  Note that this is zero-based while you user
interface probably should be one-based.

=item C<titles> (array of strings)

An array of strings containing the title lines read from the input
data.

=item C<template> (output template) [feff6]

The output template.

=item C<ipot_style> (string) [elements]

The style for generating the potentials list in a Feff input file.
The choices are sites, elements, and tags.

=back

=head2 Progress flags

=over 4

=item C<is_imported> (boolean) [false]

This is set to true when data is imported from a file.

=item C<is_populated> (boolean) [false]

This is set to true when the cell is populated.

=item C<is_expanded> (boolean) [false]

This is set to true when the populated cell is expanded into a cluster.

=item C<is_ipots_set> (boolean) [false]

This is set to true when the unique potentials are assigned.

=item C<partial_occupancy>

This is set to true if the input crystal data includes sites with
partial occupancy.

=back

=head2 Crystallography

=over 4

=item C<sites> (list of Site objects)

This is a reference to the array of Site objects in the cluster.

=item C<cell> (reference to Cell object)

This is a reference to the Cell object associated with this Atoms
object.

=item C<cluster> (list)

This is a list containing the expanded cluster.  Need to describe each
list entry.

=back

=head1 METHODS

Various methods for populating the cell, explanding the cluster, and
other chores are not documented here.  These things will happen as
needed when any of the output generating methods are called.

=head2 Accessor methods

=over 4

=item C<set>

Set attributes.  This takes a single argument which is a reference to
a hash of attribute values.  The keys of that hash are any of the
valid object attributes listed above.

  $atoms -> set(a => 3.81, rmax => 6);

=item C<get>

Retrieve attribute values.  This works in scalar and list context.

  $a = $atoms -> get("a");
  @cell_constants = $atoms -> get(qw(a b c alpha beta gamma));

=back

=head2 Main methods

=over 4

=item C<read_inp>

Import crystal data from an Atoms input file.

  $atoms -> read_inp("atoms.inp");

=item C<read_cif>

Import crystal data from a CIF file.

  $atoms -> read_cif("your_data.cif");

See L<Demeter::Atoms::Cif> for more details.

=item C<atoms_file>

Generate text suitable for an atoms input file.

  print $atoms -> atoms_file;

=item C<Write>

Write out an output file using a specified output template.

  print $atoms->Write($template);

Several types are already defined, see L</TEMPLATES>.

=back

=head2 Methods for doing absorption calculations

=over 4

=item C<xsec>

Return the length in microns of the sample required for a total
absorption length of 1.

=item C<deltamu>

Return the length in microns of the sample required for an edge step
of 1.

=item C<density>

Return the density as a unitless specific gravity.  The density os
computed from the unit cell volume and the mass of the contents of the
cell.

=item C<mcmaster>

Return an approximation of the effect of unit normalization on the
sigma^2 values measured in an EXAFS analysis.

=item C<i0>

Return an approximation of the effect of the energy response of the I0
detector on the sigma^2 values in a fluorescence EXAFS measurement.

=item C<selfsig>

Return an approximation of the effect of self-absorption on the
sigma^2 values in a fluorescence EXAFS measurement.

=item C<selfamp>

Return an approximation of the effect of self-absorption on the
amplitude in a fluorescence EXAFS measurement.

=item C<netsig>

Return the sum of the three sigma^2 corrections.

=back

=head1 TEMPLATES

Atoms templates use the syntax of L<Text::Template>.  This is a simple
templating language which has snippets of perl code interspersed among
plain text.

=over 4

=item *

B<atoms>: An input file for atoms.  Calling the C<Write> method with
C<atoms> as the argument is identical to calling the C<atoms_file>
method.

=item *

B<p1>: The entrie contents of the fully decorated unit cell, written
as an input file for atoms using the C<P1> space group.

=item *

B<feff6>: An input file for feff6.

=item *

B<feff7>: An input file for feff7.

=item *

B<feff8>: An input file for feff8.

=item *

B<absorption>: Text with the results of various caluclations using
tables of xray absorption coefficients.

=item *

B<spacegroup>: A brief description of the space group, including
alternate symbols and a list of equivalent positions.

=back

New output types can be defined by writing new template files.  Any
template files found on your system can be used as the argument to the
C<Write> method.



=head1 DIAGNOSTICS

=over 4

=item C<Atoms: \"$file\" does not exist">

Your atoms input file or CIF file could not be found.

=item C<Atoms: \"$file\" could not be read">

Your atoms input file or CIF file could not be read,probably due to a
permissions problem.

=item C<Unknown Atoms template file -- type $file: $tmpl">

The template file specified in the call to the C<Write> method could
not located.

=item C<"$key" is not a valid Demeter::Atoms parameter>

You have attempted to set an unrecognized  keyword.

=item C<You have $i unique potentials, but Feff only allows 7.>

Your choice of ipot style has resulted in more than 7 unique
potentials being defined.  Feff will refuse to run with that many.

=item C<"$key" is a deprecated Atoms keyword ($file line $.)>

While reading an Atoms input file, you have come across a keyword that
was recognized in an earlier version of Atoms, but which is no longer
supported.  It's value was ignored.

=item C<"$key" is not an Atoms keyword ($file line $.)>

While reading an Atoms input file, you have come across a keyword that
is not an Atoms keyword.  It's value was ignored.

=back

=head1 SERIALIZATION AND DESERIALIZATION

The atoms input file is used for serialization of input data.  Output
data should be associated with a Feff object and serialization of the
output should be handled as a Feff object.

=head1 CONFIGURATION AND ENVIRONMENT

See L<Demeter::Config> for a description of the configuration system.
Atoms uses the C<atoms> configuration group.

=head1 DEPENDENCIES

The dependencies of the Demeter system are in the
F<Bundle/DemeterBundle.pm> file.

=head1 BUGS AND LIMITATIONS

=over 4

=item *

Need to implement a feff.inp parser for OpenBabel to enable a much
broader range of output formats.

=item *

Neutral (parallelipiped) cluster?

=item *

Need overfull, p1_cartesian, gnxas outout.

=item *

Location in user space for user-defined templates.

=item *

Need more testing of spacegroups and database.

=back

Please report problems to Bruce Ravel (bravel AT bnl DOT gov)

Patches are welcome.

=head1 AUTHOR

Bruce Ravel (bravel AT bnl DOT gov)

L<http://bruceravel.github.com/demeter/exafs/>


=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2013 Bruce Ravel (bravel AT bnl DOT gov). All
rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
