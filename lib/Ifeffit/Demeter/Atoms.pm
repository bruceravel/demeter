package Ifeffit::Demeter::Atoms;

=for Copyright
 .
 Copyright (c) 2006-2008 Bruce Ravel (bravel AT bnl DOT gov).
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

use base qw(
	     Ifeffit::Demeter
	     Ifeffit::Demeter::Dispose
	     Ifeffit::Demeter::Atoms::Absorption
	   );
use strict;
use warnings;
#use diagnostics;
use aliased 'Ifeffit::Demeter::Tools';
use Carp;
use Chemistry::Elements qw(get_Z);
use Class::Std;
use Fatal qw(open close);
use File::Basename;
use Ifeffit;
use List::Util qw(min max reduce);
use Math::Cephes::Fraction qw(fract euclid);
use POSIX qw(ceil);
use Regexp::Common;
use Regexp::List;
use Regexp::Optimizer;
use Readonly;
use Text::Template;
use Xray::Absorption;
#use Xray::Crystal;
use Xray::Crystal::Cell;
use Xray::Crystal::Site;

Readonly my $EPSILON => 0.0001;
Readonly my $FRAC    => 100000;

{
  my $config = Ifeffit::Demeter->get_mode("params");
  my %defaults = (
		  space	   => q{},
		  a	   => 0,
		  b	   => 0,
		  c	   => 0,
		  alpha	   => 0,
		  beta	   => 0,
		  gamma	   => 0,
		  rmax	   => 0,
		  rss	   => 0,
		  edge     => 'k',
		  iedge    => 1,
		  eedge    => 0,
		  core     => q{},
		  corel    => q{},
		  shift    => [],
		  file	   => q{},
		  titles   => [],
		  template => q{},
		  ipot_style => $config->default("atoms","ipot_style") || 'elements',

		  nitrogen => 1,
		  argon    => 0,
		  xenon    => 0,
		  krypton  => 0,
		  helium   => 0,

		  xsec     => 0,
		  deltamu  => 0,
		  density  => 0,
		  mcmaster => 0,
		  i0       => 0,
		  selfamp  => 0,
		  selfsig  => 0,

		  is_imported	  => 0,
		  is_populated	  => 0,
		  is_ipots_set	  => 0,
		  is_expanded	  => 0,
		  absorption_done => 0,
		  mcmaster_done	  => 0,
		  i0_done	  => 0,
		  self_done	  => 0,

		  sites    => [],
		  cell	   => q{},
		  cluster  => [],
		  nclus    => 0,
		 );
  my %edge_index = (k =>1,  l1=>2,  l3=>3,  l3=>4,
		    m1=>5,  m2=>6,  m3=>7,  m4=>8,  m5=>9,
		    n1=>10, n2=>11, n3=>12, n4=>13, n5=>14, n6=>15, n7=>16,
		   );

  sub BUILD {
    my ($self, $ident, $arguments) = @_;
    $self -> set(\%defaults);

    ## plot specific attributes
    $self -> set($arguments);

    return;
  };
  sub DEMOLISH {
    my ($self) = @_;
    return;
  };

  sub set {
    my ($self, $r_hash) = @_;
    my $re = $self->regexp;
    my $lattice_regexp = $self->regexp("atoms_lattice");
    foreach my $key (keys %$r_hash) {
      my $k = lc $key;

      carp("\"$key\" is not a valid Ifeffit::Demeter::Atoms parameter"), next
	if ($k !~ /$re/);

      $self->SUPER::set({is_imported     =>0 }) if ($k eq "file");
      $self->SUPER::set({is_populated    =>0,
			 absorption_done =>0,
			 mcmaster_done   =>0,
			 i0_done         =>0,
			 self_done       =>0,}) if ($k =~ m{$lattice_regexp});
      $self->SUPER::set({is_expanded     =>0 }) if ($k eq "rmax");
      $self->SUPER::set({is_ipots_set    =>0 }) if ($k eq "ipot_style");

      $self->SUPER::set({iedge =>$edge_index{lc($r_hash->{$k})} }) if ($k eq "edge");

      do {			# no special handling required
	$self->SUPER::set({$k=>$r_hash->{$k}});
      };
    };
    return $self;
  };

  sub out {
    my ($self, $key) = @_;
    my $config = Ifeffit::Demeter->get_mode("params");
    my $format = $config->default("atoms", "precision") || "9.5f";
    $format = '%' . $format;
    my $val = sprintf("$format", $self->get($key));
    return $val;
  };

  my $opt = Regexp::List->new;
  my $parameter_regexp = $opt->list2re(keys %defaults);
  sub _regexp {
    my ($self) = @_;
    return $parameter_regexp;
  };

  sub read_inp {
    my ($self, $file) = @_;
    my $sep = $self->regexp("separator");
    my $reading_atoms_list = 0;
    croak("Atoms: no input file provided")      if (not    $file);
    croak("Atoms: \"$file\" does not exist")    if (not -e $file);
    croak("Atoms: \"$file\" could not be read") if (not -r $file);
    $self->set({file=>$file});

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
	$self->Push({titles=>$line});
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
    $self->set({is_imported=>1});
    return $self;
  };

  sub parse_line {
    my ($self, $line) = @_;
    #return if not $line;
    my $sep = $self->regexp("separator");
    my $file = $self->get("file");

    my @words = split(/$sep/, $line);
    my $key = shift @words;
    (my $rest = $line) =~ s{\A$key$sep}{};

    if ($key =~ m{space(?:group)?}i) {
      my $end = (length($rest) < 10) ? length($rest) : 10;
      my $sg = substr($rest, 0, $end);
      $self->set({space=>$sg});
      $rest = substr($rest, $end, -1);
    } else {
      @words = split(/$sep/, $rest);
      my $val = shift @words;
      $rest =~ s{$val(?:$sep)?}{};
      my $vv = ($key =~ m{\bout}) ? shift @words : q{};
      $rest =~ s{$vv(?:$sep)?}{};
      my $vvv = ($key =~ m{shi|daf|qve|ref}) ? shift @words : q{};
      $rest =~ s{$vvv(?:$sep)?}{};
      my $vvvv = ($key =~ m{shi|daf|qve|ref}) ? shift @words : q{};
      $rest =~ s{$vvvv(?:$sep)?}{};

      return if ($key =~ m{\#});
      my $keyword = $self->regexp;
      my $obsolete = $self->regexp("atoms_obsolete");
      if ($key =~ m{$keyword}) {
	$self->set({lc($key)=>lc($val)});
      } elsif ($key =~ m{$obsolete}) {
	carp("\"$key\" is a deprecated Atoms keyword ($file line $.)");
      } else {
	carp("\"$key\" is not an Atoms keyword ($file line $.)");
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
    my $this = join("|",$el, $x, $y, $z, $tag);
    $self->Push({sites=>$this});
    return $self;
  };


  sub populate {
    my ($self) = @_;
    my @sites;
    my $ra = $self->get("sites");
    foreach my $s (@$ra) {
      my ($el, $x, $y, $z, $tag) = split(/\|/, $s);
      push @sites, Xray::Crystal::Site->new({elem=>$el, x=>$x, y=>$y, z=>$z, tag=>$tag});
    };
    ### creating and populating cell
    my $cell = Xray::Crystal::Cell->new;
    my ($space, $a, $b, $c, $alpha, $beta, $gamma) =
      $self->get(qw(space a b c alpha beta gamma));
    $cell -> set({space_group=>$space});
    foreach my $key (qw(a b c alpha beta gamma)) {
      my $val = $self->get($key);
      $cell->set({$key=>$val}) if $val;
    };
    $self -> set({cell=>$cell});

    ## Group: $cell->get(qw(given_group space_group class setting))
    ## Bravais: $cell->get('bravais')
    $cell->populate(\@sites);
    my ($central, $xcenter, $ycenter, $zcenter) = $cell -> central($self->get("core"));
    $self->set({is_populated => 1,
		corel        => ucfirst(lc($central->get("element"))),
		eedge        => Xray::Absorption->get_energy($central->get("element"), $self->get("edge")),
	       });
    return $self;
  };


  sub build_cluster {
    my ($self) = @_;
    my $config = Ifeffit::Demeter->get_mode("params");
    $self->populate if (not $self->get("is_populated"));
    my ($cell, $core) = $self->get("cell", "core");
    my @sites = @{ $cell->get("sites") };
    map { $_ -> set({in_cluster => 0}) } @sites;

    my $rmax = $self->get('rmax');
    my @cluster = ();
    my ($central, $xcenter, $ycenter, $zcenter) = $cell -> central($core);
    #print join(" ", $xcenter, $ycenter, $zcenter), $/;
    my $setting	      = $cell -> get("setting");
    my $crystal_class = $cell -> get("class");
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
    my ($contents) = $cell -> get("contents");

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
	      $$pos[0] -> set({in_cluster => 1});
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
    $self->set({cluster => \@cluster,
		nclus   => $#cluster+1,
		rss     => sprintf('%'.$config->default("atoms", "precision"),
				   $cluster[1]->[4]*$config->default("atoms", "smallsphere")),
	       });

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
      $cell -> set({b=>$a*sqrt(2), b=>$b*sqrt(2)});
    };
    $self->set({is_expanded=>1});
    return $self;
  };


  sub set_ipots {
    my ($self) = @_;
    my $config = Ifeffit::Demeter->get_mode("params");
    $self->build_cluster if (not $self->get("is_expanded"));
    my ($cell, $how) = $self->get("cell", "ipot_style");
    my @sites = @{ $cell->get("sites") };
    my $i = 1;
    my %seen = ();
    if ($how =~ m{\Ata}) {
      foreach my $s (@sites) {
	if ($s->get("in_cluster")) {
	  my $tag = lc($s->get("tag"));
	  $seen{$tag} = $i++ if (not $seen{$tag});
	  $s -> set({ipot=>$seen{$tag}});
	};
      };
    } elsif ($how =~ m{\Ael}) {
      foreach my $s (@sites) {
	if ($s->get("in_cluster")) {
	  my $el = lc($s->get("element"));
	  $seen{$el} = $i++ if (not $seen{$el});
	  $s -> set({ipot=>$seen{$el}});
	};
      };
    } else { ## sites
      foreach my $s (@sites) {
	if ($s->get("in_cluster")) {
	  $s -> set({ipot=>$i});
	  ++$i
	};
      };
    };

    ## get the reduced stoichiometry for feff8's potentials list
    my @count = (0,0,0,0,0,0,0,0);
    my $top = -999;
    foreach my $s (@sites) {
      my $ipot = $s->get("ipot");
      $count[$ipot] += $s->get("in_cell");
      $top = max($top, $ipot);
    };
    ## get greatest common divisor (thanks to Math::Cephes::Fraction
    ## for "euclid" and List::Util for "reduce")
    if ($config->default("atoms", "gcd")) {
      my $gcd = reduce { (euclid($a,$b))[0] } @count[1..$top];
      foreach my $s (1 .. $top) {
	$count[$s] /= $gcd;
      };
    };
    foreach my $s (@sites) {
      my $ipot = $s->get("ipot");
      $s->set({stoi=>$count[$ipot]});
    };

    $self->set({is_ipots_set=>1});
    if (--$i > 7) {
      carp("You have $i unique potentials, but Feff only allows 7.");
      return -1;
    };
    return 0;
  };

  sub template {
    my ($self, $file, $rhash) = @_;

    my $cell = $self->get("cell");

    my $tmpl = File::Spec->catfile(dirname($INC{"Ifeffit/Demeter.pm"}),
				   "Demeter",
				   "templates",
				   "atoms",
				   "$file.tmpl");
    croak("Unknown Atoms template file -- type $file: $tmpl") if (not -e $tmpl);
    my $template = Text::Template->new(TYPE => 'file', SOURCE => $tmpl)
      or die "Couldn't construct template: $Text::Template::ERROR";
    $rhash ||= {};
    my $string = $template->fill_in(HASH => {A  => \$self,
					     C  => \$cell,
					     %$rhash},
				    PACKAGE => "Ifeffit::Demeter::Templates");
    $string ||= q{};
    $string =~ s{^\s+}{};		# remove leading white space
    $string =~ s{\n(?:[ \t]+\n)+}{\n};	# regularize white space between blocks of text
    $string =~ s{\s+$}{\n};		# remove trailing white space
    $string =~ s{<<->>\n}{}g;		# convert newline token into a real newline
    $string =~ s{<<nl>>}{\n}g;		# convert newline token into a real newline
    $string =~ s{<<( +)>>}{$1}g;	#} # convert white space token into real white space
    return $string;
  };


  sub cluster_list {
    my ($self, $pattern) = @_;
    $pattern ||= "  %9.5f  %9.5f  %9.5f  %d  %-10s  %9.5f\n";
    $self->set_ipots if (not $self->get("is_ipots_set"));
    my $string = q{};
    my @list = @ {$self->get("cluster") };
    my $abs = shift @list;	# absorber must be ipot 0
    $string .= sprintf($pattern,
		       $abs->[0], $abs->[1], $abs->[2],
		       0, $abs->[3], sqrt($abs->[4])
		      );
    foreach my $pos (@list) {
      ## rely upon coercions
      $string .= sprintf($pattern,
			 $pos->[0], $pos->[1], $pos->[2],
			 $pos->[3], $pos->[3], sqrt($pos->[4])
			);
    };
    return $string;
  };
  sub R {
    my ($self, $x, $y, $z) = @_;
    return sqrt($x**2 + $y**2 + $z**2);
  };

  sub potentials_list {
    my ($self, $pattern) = @_;
    $self->set_ipots if (not $self->get("is_ipots_set"));
    $pattern ||= "     %d     %-2d     %-10s\n";
    my ($cell, $core) = $self->get("cell", "core");
    my @sites = @{ $cell->get("sites") };
    my $string = q{};
    my %seen = ();
    my ($abs) = $cell->central($core);
    my $l = Xray::Absorption->get_l($abs->get("element"));
    $string .= sprintf($pattern, 0, get_Z($abs->get("element")), $abs->get("element"),
		       $l, $l, 0.001);
    foreach my $s (sort {$a->get("ipot") <=> $b->get("ipot")} @sites) {
      next if not $s->get("ipot");
      next if $seen{$s->ipot};
      $l = Xray::Absorption->get_l($s->get("element"));
      $string .= sprintf($pattern, $s, get_Z($s->get("element")),
			 $s->get("element"), $l, $l, $s->get("stoi"));
      $seen{$s->ipot} = 1;
    };
    return $string;
  };


  sub sites_list {
    my ($self, $pattern) = @_;
    $self->populate if (not $self->get("is_populated"));
    my $config = Ifeffit::Demeter->get_mode("params");
    my $prec = '%'.$config->default("atoms", "precision");
    $pattern ||= "  %-2s   $prec   $prec   $prec   %-10s\n";
    my $cell = $self->get("cell");
    my $rlist = $cell->get("sites");
    my $string = q{};
    foreach my $l (@$rlist) {
      $string .= sprintf($pattern,
			 ucfirst(lc($l->get("element"))),
			 $l->get("x"), $l->get("y"), $l->get("z"), $l);
    };
    return $string;
  };
  sub p1_list {
    my ($self, $pattern) = @_;
    $self->populate if (not $self->get("is_populated"));
    my $config = Ifeffit::Demeter->get_mode("params");
    my $prec = '%'.$config->default("atoms", "precision");
    $pattern ||= "  %-2s   $prec   $prec   $prec   %-10s\n";
    my $cell = $self->get("cell");
    my $rlist = $cell->get("contents");
    my $string = q{};
    foreach my $l (@$rlist) {
      $string .= sprintf($pattern,
			 ucfirst(lc($l->[0]->get("element"))),
			 $$l[1], $$l[2], $$l[3], $l->[0])
    };
    return $string;
  };

  sub sg {
    my ($self, $which, $pattern) = @_;
    $self->populate if (not $self->get("is_populated"));
    my $cell    = $self->get("cell");
    my $rhash   = $cell->get("data");
    $pattern ||= "      %-7s  %-7s  %-7s\n";
    my ($prefix, $postfix) = ($which =~ m{(?:bravais|shiftvec)})
                           ? ("      ", $/)
			   : (q{}, q{});
    my $re = $self->regexp("spacegroup");
    ## typo?
    return q{} if ($which !~ m{$re});
    ## number of positions
    if ($which eq "npos") {
      my @positions = @ {$rhash->{positions}};
      return $#positions + 1;
    };
    ## key is absent from this entry in database
    return "$prefix<none>$postfix" if ((not exists($rhash->{$which})) and ($which ne "bravais"));
    ## schoenflies
    return ucfirst($rhash->{schoenflies}) if ($which eq "schoenflies");
    ## number or symbol
    return $rhash->{$which} if ($which =~ m{(?:number|full|new_symbol|thirtyfive)});
    ## nicknames
    return join(", ", @{$rhash->{shorthand}}) if ($which eq "shorthand");
    ## shift vector from Int'l Tables
    if ($which eq "shiftvec") {
      my @shift = map {fract($FRAC*$_, $FRAC)} @{ $rhash->{shiftvec} };
      return sprintf($pattern, map {$_->as_mixed_string} @shift);
    };
    ## Bravais translations
    if ($which eq "bravais") {
      my @bravais = @{ $cell->get("bravais") };
      my $string = q{};
      while (@bravais) {
	my @vec = (fract($FRAC*shift(@bravais), $FRAC),
		   fract($FRAC*shift(@bravais), $FRAC),
		   fract($FRAC*shift(@bravais), $FRAC),
		  );
	$string .= sprintf($pattern, map {$_->as_mixed_string} @vec);
      };
      return $string;
    };
    ## symetric positions
    if ($which eq "positions") {
      my @positions = @ {$rhash->{positions}};
      my $string = q{};
      my $npos = $#positions + 1;
      #$string .= "  $npos positions:\n";
      foreach my $pos (@positions) {
	my @this = @{ $pos };
	map { $this[$_] =~ s{\$}{}g } (0 .. 2);
	$string .= sprintf($pattern, @this);
      };
      return $string;
    };
    return q{};
  };


  sub titles {
    my ($self, $prefix) = @_;
    $prefix ||= " TITLE ";
    my @titles = @{ $self->get("titles") };
    my $string = q{};
    foreach my $t (@titles) {
      $string   .= $prefix . $t . $/;
    };
    return $string;
  };


  sub Write {
    my ($self, $type) = @_;
    #$type ||= "feff6";
    $type = lc($type);
    ($type = 'feff6') if ($type eq'feff');
    return $self->atoms_file             if ($type eq 'atoms');
    return $self->atoms_file('p1')       if ($type eq 'p1');
    return $self->template("absorption") if ($type eq 'absorption');
    if ($type eq 'spacegroup') {
      $self->populate if (not $self->get("is_populated"));
      return $self->template("spacegroup");
    };
    if ($type =~ m{feff}) {
      $self->build_cluster if (not $self->get("is_expanded"));;
      return $self->template($type);
    };

    ## still need: overfull, p1_cartesian, gnxas

    ## fallback
    #return $self->atoms_file;
    $self->build_cluster if (not $self->get("is_expanded"));;
    return $self->template('feff6');
  };

  sub atoms_file :STRINGIFY {
    my ($self, $is_p1) = @_;
    $is_p1 = 0 if ($is_p1 and ($is_p1 =~ ident($self)));  #enable :STRINGIFY
    $self->populate if (not $self->get("is_populated"));
    my $cell = $self -> get("cell");
    my $string = $self->template("copyright", {type=>($is_p1) ? "P1" : "Atoms"});
    $string   .= $self->template("atoms_header");
    $string   .= ($is_p1) ? $self->p1_list : $self->sites_list;
    return $string;
  };

};
1;

=head1 NAME

Ifeffit::Demeter::Atoms - Convert crystallographic data to atomic lists

=head1 VERSION

This documentation refers to Ifeffit::Demeter version 0.1.

=head1 SYNOPSIS

These lines behave much like any earlier version of Atoms:

  use Ifeffit::Demeter;
  my $atoms = Ifeffit::Demeter::Atoms -> new()
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
L<Xray::Crystal::Cell>, including Hermann-Maguin, Schoenflies, number, or one
of a few nicknames.

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

=item C<edge> (string) [k or l3 depending on Z-number]

The edge of the absorber.

=item C<core> (string) [first sitin the list]

The identifier of the absorber.  This should be one of the site tags.

=item C<shift> (vector) [0,0,0]

The value of the shift vector, should one be necessary.

=item C<file> (filename)

The name of an atoms input file or a CIF file.

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

  $atoms -> set({a => 3.81, rmax => 6});

=item C<Push>

Push a single value onto a list-values attribute.

  $atoms -> Push({titles => "crystal data at room temperature"});

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

  $atoms -> read_inp("your_data.cif");

CIF import is not yet working in Demeter 0.1.

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

=item C<"$key" is not a valid Ifeffit::Demeter::Atoms parameter>

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

See L<Ifeffit::Demeter::Config> for a description of the configuration
system.  Atoms uses the C<atoms> configuration group.

=head1 DEPENDENCIES

The dependencies of the Ifeffit::Demeter system are in the
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

Please report problems to Bruce Ravel (bravel AT anl DOT gov)

Patches are welcome.

=head1 AUTHOR

Bruce Ravel (bravel AT bnl DOT gov)

L<http://cars9.uchicago.edu/~ravel/software/exafs/>


=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2008 Bruce Ravel (bravel AT bnl DOT gov). All
rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
