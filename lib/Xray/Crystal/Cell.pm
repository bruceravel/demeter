package Xray::Crystal::Cell;

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

use strict;
use warnings;
use Chemistry::Elements qw(get_symbol);
use Class::Std;
use Carp;
use Cwd;
use File::Spec;
#use File::Temp qw(tempdir);
use List::MoreUtils qw(any false notall);
use Regexp::Common;
use Regexp::List;
use Regexp::Optimizer;
use Storable;
use Text::Abbrev;

use Readonly;
Readonly my $NUMBER   => $RE{num}{real};
Readonly my $PI       => 4*atan2(1,1);
Readonly my $EPSILON  => 0.00001;

sub identify_self {
  my @caller = caller;
  use File::Basename qw(dirname);
  return dirname($caller[1]);
};


{

  my %params_of  :ATTR;

  my %defaults = (
		  space_group => q{},	# supplied & calculated
		  given_group => q{},	#            calculated
		  a           => 0,	# supplied
		  b           => 0,	# supplied | calculated
		  c           => 0,	# supplied | calculated
		  alpha       => 90,	# supplied | calculated
		  beta        => 90,	# supplied | calculated
		  gamma       => 90,	# supplied | calculated
		  angle       => q{},	#            calculated
		  setting     => 0,	#            calculated
		  sites       => [],	# supplied
		  contents    => [],	#            calculated
		  bravais     => [],	#            calculated
		  class       => q{},   #            calculated
		  volume      => 1,	#            calculated
		  txx         => 0,	#            calculated
		  tyx         => 0,	#            calculated
		  tyz         => 0,	#            calculated
		  tzx         => 0,	#            calculated
		  tzz         => 0,	#            calculated
		  occupancy   => 1,     # supplied
		  data        => q{},   # taken from SG database
		 );

  my $opt  = Regexp::List->new;
  my $attr_re = $opt->list2re(keys %defaults);
  my %full_table   = abbrev  keys(%defaults);
  my %abbrev_table = abbrev (qw(space_group a b c alpha beta gamma angle occupancy));
  my $number_attr = $opt->list2re(qw(a b c alpha beta gamma));
  my $sh_re = $opt->list2re(qw(hex hcp zincblende zns cubic salt perov perovskite
			       gra graphite fcc salt nacl diamond bcc cscl));

  my @ambiguous_symbols = ('p b n a', 'c -4 2 g');
  my $database = File::Spec->catfile(identify_self(), 'share', 'space_groups.db');
  my $r_sg = retrieve($database);

  sub BUILD {
    my ($self, $ident, $arguments) = @_;
    foreach my $k (keys %defaults) {
      $params_of{ident $self}{$k} = $defaults{$k};
    };
    $params_of{ident $self}{id} = $ident;
    $self -> set($arguments);
    return;
  };

  sub set {
    my ($self, $r_hash) = @_;
    foreach my $key (keys %$r_hash) {
      my $k = lc($key);

      if (not exists $abbrev_table{$k}) {
	carp("\"$key\" is not a Xray::Crystal::Cell parameter that can be set");
	next;
      };
      $k = $abbrev_table{$k};
    ATTR: {

	($k eq 'space_group') and do {
	  $params_of{ident $self}{given_group} = $r_hash->{$key};
	  $self->canonicalize_symbol($r_hash->{$key});
	  $self->bravais;
	  $self->crystal_class;
	  $self->determine_monoclinic;
	  last ATTR;
	};


	($k =~ m{\A$number_attr\z}) and do {
	  if ($r_hash->{$key} !~ m{\A$NUMBER\z}) {
	    carp("Cell parameters must be numbers");
	    last ATTR;
	  };
	  my $value = ($r_hash->{$key} > 0) ? $r_hash->{$key} : 0;
	  $params_of{ident $self}{$k} = $value;
	  if ($k eq 'a') {
	    $params_of{ident $self}{b} ||= $params_of{ident $self}{a};
	    ($params_of{ident $self}{b}  = $params_of{ident $self}{a})
	      if ($params_of{ident $self}{b} < $EPSILON);
	    $params_of{ident $self}{c} ||= $params_of{ident $self}{a};
	    ($params_of{ident $self}{c}  = $params_of{ident $self}{a})
	      if ($params_of{ident $self}{c} < $EPSILON);
	  } elsif ($k =~ m{(?:alpha|beta|gamma)}) {
	    if (abs($params_of{ident $self}{$k}) < $EPSILON) {
	      ($params_of{ident $self}{$k}  = 90)
	    } elsif (abs($params_of{ident $self}{$k} - 90) > $EPSILON) {
	      $params_of{ident $self}{angle} = $k;
	    };
	    $self->determine_monoclinic;
	  };
	  $self->geometry;
	  last ATTR;
	};


      	do {
	  (my $value = $r_hash->{$key}) =~ s{\A\s+\z}{};
	  $params_of{ident $self}{$k} = $value;
	};
      };

    };

  };

  sub get {
    my ($self, @params) = @_;
    croak('$type: usage: get($key) or get(@keys)') if @_ < 2;
    my $type = ref $self;
    my @values = ();
    foreach my $key (@params) {
      my $k = lc $key;
      carp("$type: \"$key\" is not a valid parameter") if (not exists $full_table{$k});
      push @values, $params_of{ident $self}{$full_table{$k}};
    };
    return wantarray ? @values : $values[0];
  };

  sub out {
    my ($self, $key) = @_;
    my $config = Ifeffit::Demeter->get_mode("params");
    my $format = $config->default("atoms", "precision") || "9.5f";
    $format = '%' . $format;
    my $val = sprintf("$format", $self->get($key));
    return $val;
  };

  sub canonicalize_symbol {
    my ($self, $symbol) = @_;
    my $sym;
				# this is a null value
    if (! $symbol) {
      $params_of{ident $self}{space_group} = q{};
      $params_of{ident $self}{setting}     = 0;
      $params_of{ident $self}{data}        = q{};
      return (q{},0);
    };

    $symbol = lc($symbol);	# lower case and ...
    $symbol =~ s/[!\#%*].*$//;  # trim off comments
    $symbol =~ s/^\s+//;	# trim leading spaces
    $symbol =~ s/\s+$//;	# trim trailing spaces
    $symbol =~ s/\s+/ /g;	# ... single space
    $symbol =~ s|\s*/\s*|/|g;	# spaces around slash

    $symbol =~ s/2_1/21/g;	# replace `i 4_1' with `i 41'
    $symbol =~ s/3_([12])/2$1/g; #  and so on ...
    $symbol =~ s/4_([1-3])/2$1/g;
    $symbol =~ s/6_([1-5])/2$1/g;

    my $opt = Regexp::List->new;
    if ( ($symbol !~ m{[_^]})        and  # schoen
	 ($symbol !~ m{\A\d{1,3}\z}) and  # 1-230
	 ($symbol !~ m{\A($sh_re)\z}io)   # shorthands like 'cubic', 'zns'
       ) {
      #print $symbol;
      $symbol = _insert_spaces($symbol);
      #print "|$symbol|\n";
    };
				# this is the standard symbol
    if (exists($r_sg->{$symbol})) {
      $params_of{ident $self}{space_group} = $symbol;
      $params_of{ident $self}{setting}     = 0;
      my $rhash = $r_sg->{$symbol};
      $params_of{ident $self}{data}        = $rhash;
      return ($symbol, 0);
    };

    foreach $sym (keys %$r_sg ) {
      next if ($sym eq "version");
      my $rhash = $r_sg->{$sym};

				# this is the Schoenflies symbol, (it
				# must have a caret in it)
      if ($symbol =~ /\^/) {
	$symbol =~ s/\s+//g;	#   no spaces
	$symbol =~ s/^v/d/g;	#   V -> D
				# put ^ and _ in correct order
	$symbol =~ s/([cdost])(\^[0-9]{1,2})(_[12346dihsv]{1,2})/$1$3$2/;
	if ((exists $r_sg->{$sym}->{schoenflies}) and ($symbol eq $r_sg->{$sym}->{schoenflies}) ) {
	  $params_of{ident $self}{space_group} = $sym;
	  $params_of{ident $self}{setting}     = 0;
	  $params_of{ident $self}{data}        = $rhash;
	  return ($sym, 0);
	};
      };
				# scalar valued fields
				# this is a number between 1 and 230
				#    or the 1935 symbol
 				#    or a double glide plane symbol
 				#    or the full symbol
      foreach my $field ("thirtyfive", "number", "new_symbol", "full") {
	if ( (exists $r_sg->{$sym}->{$field}) and ($symbol eq $r_sg->{$sym}->{$field}) ) {
	  $params_of{ident $self}{space_group} = $sym;
	  $params_of{ident $self}{setting}     = 0;
	  $params_of{ident $self}{data}        = $rhash;
	  return ($sym, 0);
	};
      };
				# now check the array values fields
      foreach my $field ("settings", "short", "shorthand") {
	if (exists($r_sg->{$sym}->{$field})) {
	  my $i=0;
	  foreach my $setting ( @{$r_sg->{$sym}->{$field}} ) {
	    ++$i;
	    my $s = ($field eq "settings") ? $i : 0;
	    if ($symbol eq $setting) {
	      $params_of{ident $self}{space_group} = $sym;
	      $params_of{ident $self}{setting}     = $s;
	      $params_of{ident $self}{data}        = $rhash;
	      return ($sym, $s);
	    };
	  };
	};
      };
    };

				# this is not a symbol
    $params_of{ident $self}{space_group} = q{};
    $params_of{ident $self}{setting}     = 0;
    $params_of{ident $self}{data}        = {};
    return (q{},0);

  };



  ## This is the algorithm for dealing with user-supplied space group
  ## symbols that do not have the canonical single space separating the
  ## part of the symbol.
  sub _insert_spaces {
    my $sym = $_[0];

    my ($first, $second, $third, $fourth) = ("", "", "", "");

    ## a few groups don't follow the rules below ...
    ($sym =~ /\b([rhc])32\b/i)                 && return "$1 3 2";
    ($sym =~ /\bp31([2cm])\b/i)                && return "p 3 1 $1";
    ($sym =~ /\bp(3[12]?)[22][12]\b/i)         && return "p $1 2 1";
    ($sym =~ /\bp(6[1-5]?)22\b/i)              && return "p $1 2 2";
    ($sym =~ /\b([fip])(4[1-3]?)32\b/i)        && return "$1 $2 3 2";
    ($sym =~ /\b([fipc])(4[1-3]?)(21?)(2)\b/i) && return "$1 $2 $3 $4";

    ## the first symbol is always a single letter
    $first = substr($sym, 0, 1);
    my $index = 1;

    my $subsym = substr($sym, $index);
    if ($subsym =~ m{\A([ \t]+)}) {
      $index += length($1);
    };
    if (substr($sym, $index, 4) =~ /([2346][12345]\/[mnabcd])/) {
      ## second symbol as in p 42/n c m
      $second = $1;
      $index += 4;
    } elsif (substr($sym, $index, 3) =~ /([2346]\/[mnabcd])/) {
      ## second symbol as in p 4/n n c
      $second = $1;
      $index += 3;
    } elsif (substr($sym, $index, 2) =~ /(-[1346])/) {
      ## second symbol as in p -3 1 m
      $second = $1;
      $index += 2;
    } elsif (substr($sym, $index, 2) =~ /(21|3[12]|4[123]|6[12345])/) {
      ## second symbol as in p 32 1 2
      $second = $1;
      $index += 2;
    } else {
      $second = substr($sym, $index, 1);
      $index += 1;
    };

    $subsym = substr($sym, $index);
    if ($subsym =~ m{\A([ \t]+)}) {
      $index += length($1);
    };
    if (substr($sym, $index, 4) =~ /([2346][12345]\/[mnabcd])/) {
      ## third symbol as in full symbol p 21/c 21/c 2/n
      $third = $1;
      $index += 4;
    } elsif (substr($sym, $index, 3) =~ /([2346]\/[mnabcd])/) {
      ## third symbol as in full symbol p 4/m 21/b 2/m
      $third = $1;
      $index += 3;
    } elsif (substr($sym, $index, 2) =~ /(-[1346])/) {
      ## third symbol as in f d -3 m
      $third = $1;
      $index += 2;
    } elsif (substr($sym, $index, 2) =~ /(21|3[12]|4[123]|6[12345])/) {
      ## third symbol as in p 21 21 2
      $third = $1;
      $index += 2;
    } else {
      $third = substr($sym, $index, 1);
      $index += 1;
    };

    ($index < length($sym)) and $fourth = substr($sym, $index);
    $fourth =~ s/\A\s+//;

    $sym = join(" ", $first, $second, $third, $fourth);
    $sym =~ s/\s+$//;		# trim trailing spaces
    return $sym;
  };


  sub geometry {
    my ($self)= @_;
    my ($a, $b, $c, $alpha, $beta, $gamma) = $self->get(qw(a b c alpha beta gamma));
    ## radians!
    ($alpha, $beta, $gamma) = map { $_ * $PI / 180 } ($alpha, $beta, $gamma);

    ## cell volume
    my $term  = 1 - cos($alpha)**2 - cos($beta)**2 - cos($gamma)**2 +
      2*cos($alpha)*cos($beta)*cos($gamma);
    my $v = $a * $b * $c * sqrt($term);
    $params_of{ident $self}{volume} = $v;

    ## tensor metrix components
    my $cosxx = ( cos($alpha)*cos($gamma) - cos($beta)  ) / ( sin($alpha)*sin($gamma) );
    my $cosyy = ( cos($alpha)*cos($beta)  - cos($gamma) ) / ( sin($alpha)*sin($beta)  );
				# careful for the sqrt!
    my $sinxx = ($cosxx**2 < 1) ? sqrt(1-$cosxx**2) : 0;
    my $sinyy = ($cosyy**2 < 1) ? sqrt(1-$cosyy**2) : 0;
    $params_of{ident $self}{txx} = sprintf "%11.7f", $sinyy*sin($beta);
    $params_of{ident $self}{tyx} = sprintf "%11.7f", -( ($cosyy/($sinyy*sin($alpha)) )
							+ (cos($alpha)*$cosxx)/($sinxx*sin($alpha)))
                                                      * ($sinyy*sin($beta));
    $params_of{ident $self}{tyz} = sprintf "%11.7f", cos($alpha);
    $params_of{ident $self}{tzx} = sprintf "%11.7f", -( $cosxx*$sinyy*sin($beta) ) / $sinxx;
    $params_of{ident $self}{tzz} = sprintf "%11.7f", sin($alpha);

    return $v;
  };

  sub bravais {
    my ($self) = @_;
    my %table = ( f => [  0, 1/2, 1/2, 1/2,   0, 1/2, 1/2, 1/2,   0],
		  i => [1/2, 1/2, 1/2],
		  c => [1/2, 1/2,   0],
		  a => [  0, 1/2, 1/2],
		  b => [1/2,   0, 1/2],
		  r => [2/3, 1/3, 1/3, 1/3, 2/3, 2/3],
		);
    my $group   = $self->get("space_group");
    my $g       = lc(substr($group, 0, 1));
    my $setting = $self->get("setting");
    $params_of{ident $self}{bravais} = [];
    $params_of{ident $self}{bravais} = $table{r}  if (($g eq 'r') and ($setting eq 0));
    $params_of{ident $self}{bravais} = $table{$g} if ($g =~ m{[abcfi]});
    return 0;
  };

  sub crystal_class {
    my ($self)  = @_;
    my $group   = $self->get("space_group");
    if (exists $r_sg->{$group}->{number}) {
      my $num   = $r_sg->{$group}->{number};
      my $class = ($num <= 0)   ? q{}
	        : ($num <= 2)   ? "triclinic"
	        : ($num <= 15)  ? "monoclinic"
	        : ($num <= 74)  ? "orthorhombic"
	        : ($num <= 142) ? "tetragonal"
	        : ($num <= 167) ? "trigonal"
	        : ($num <= 194) ? "hexagonal"
	        : ($num <= 230) ? "cubic"
	        : q{};
      $params_of{ident $self}{class} = $class;
    };
    return 1;
  };


  sub determine_monoclinic {
    my ($self) = @_;
    my ($group, $given, $class) = $self->get(qw(space_group given_group class));
    return 0 if ($class ne "monoclinic");
    ($given = $group) if ($given =~ m{\A\d+\z});

    my $axis = ((abs( 90 - $self->get("alpha") )) > $EPSILON) ? "a"
             : ((abs( 90 - $self->get("beta")  )) > $EPSILON) ? "b"
	     : ((abs( 90 - $self->get("gamma") )) > $EPSILON) ? "c"
	     : q{};
    (! $axis) && do {
      if ($self->get("angle")) {
	$axis = lc(substr($self->get('angle'), 0, 1));
	$axis =~ tr/g/c/;
      };
    };
    #print "axis: $axis\n";
    return 0 if (not $axis);	#  angles no set yet

    # if it has, then continue...
    my $setting = $axis . "_unique";
    my $number  = $r_sg->{$group}->{number};
    ## these groups have one cell choice for each unique axis
    foreach my $n (3,4,5,6,8,10,11,12) {
      ($number == $n) && return $setting;
    };
    ## groups 7, 13, 14 are p centered and have multiple cell choices
    #print "$group   $given    $axis\n";
    if ($group =~ m{\Ap}) {
      if ($axis eq "b") {
	($setting .= "_1") if ($given =~ m{c}i);
	($setting .= "_2") if ($given =~ m{n}i);
	($setting .= "_3") if ($given =~ m{a}i);
      } elsif ($axis eq "c") {
	($setting .= "_1") if ($given =~ m{a}i);
	($setting .= "_2") if ($given =~ m{n}i);
	($setting .= "_3") if ($given =~ m{b}i);
      } elsif ($axis eq "a") {
	($setting .= "_1") if ($given =~ m{b}i);
	($setting .= "_2") if ($given =~ m{n}i);
	($setting .= "_3") if ($given =~ m{c}i);
      };
    };
    ## groups 9, 15 are c centered and have multiple cell choices
    if ($group =~ m{\Ac}) {
      if ($axis eq "b") {
	($setting .= "_1") if ($given =~ m{\Ac}i);
	($setting .= "_2") if ($given =~ m{\Aa}i);
	($setting .= "_3") if ($given =~ m{\Ai}i);
      } elsif ($axis eq "c") {
	($setting .= "_1") if ($given =~ m{\Aa}i);
	($setting .= "_2") if ($given =~ m{\Ab}i);
	($setting .= "_3") if ($given =~ m{\Ai}i);
      } elsif ($axis eq "a") {
	($setting .= "_1") if ($given =~ m{\Ab}i);
	($setting .= "_2") if ($given =~ m{\Ac}i);
	($setting .= "_3") if ($given =~ m{\Ai}i);
      };
    };
    ## if none of the preceding 6 blocks altered setting then there is a
    ## mismatch between the symbol and the unique axis, so return 0.
    ($setting = 0) if ($setting !~ /_[123]$/);
    $params_of{ident $self}{setting} = $setting;
    return $setting;
  };


  sub verify_cell {
    my ($self) = @_;
  };


  sub metric {
    my ($self, $x,$y,$z) = @_;
    my ($xp, $yp, $zp);
    my ($a, $b, $c, $txx, $tyx, $tyz, $tzx, $tzz) =
      $self->get(qw(a b c txx tyx tyz tzx tzz));
    $xp = $x*$a*$txx;
    $yp = $x*$a*$tyx + $y*$b + $z*$c*$tyz;
    $zp = $x*$a*$tzx +         $z*$c*$tzz;
    return ($xp,$yp,$zp);
  };

  sub d_spacing {
    my ($self, $h, $k, $l) = @_;
    $h ||= 0;
    $k ||= 0;
    $l ||= 0;
    return 0 unless ($h or $k or $l);
    my ($alpha, $beta, $gamma) = map {$_ * $PI / 180} $self->get(qw(alpha beta gamma));
    my ($a, $b, $c, $volume) = $self->get(qw(a b c volume));

    my $s11 = ($b*$c*sin($alpha))**2;
    my $s22 = ($a*$c*sin($beta ))**2;
    my $s33 = ($a*$b*sin($gamma))**2;

    my $s12 =  $a * $b * ($c**2) * ( cos($alpha)*cos($beta)  - cos($gamma) );
    my $s23 =  $b * $c * ($a**2) * ( cos($beta) *cos($gamma) - cos($alpha) );
    my $s13 =  $c * $a * ($b**2) * ( cos($gamma)*cos($alpha) - cos($beta)  );

    my $d = $s11*($h**2) + $s22*($k**2) + $s33*($l**2) +
      2*$s12*$h*$k + 2*$s23*$k*$l + 2*$s13*$h*$l;
    $d = $volume / sqrt($d);
    return $d;
  };

  sub multiplicity {
    my ($self, $h, $k, $l) = shift;
    my $class = $self -> get("class");
    my @r = sort($h, $k, $l);
  SWITCH:
    ($class eq 'cubic') and do {
      (not $r[0]) && (not $r[1]) && $r[2]   && return 6;
      ($r[0] == $r[1]) && ($r[1] == $r[2])  && return 8;
      (not $r[0]) && ($r[1] == $r[2])       && return 12;
      (not $r[0]) && ($r[1] != $r[2])       && return 24; #*
      ($r[0] == $r[1]) && ($r[1] != $r[2])  && return 24;
      ($r[0] != $r[1]) && ($r[1] == $r[2])  && return 24;
      return 48
    };
    (($class eq 'hexagonal') || ($class eq 'trigonal')) and do {
      (not $h) && (not $k) && $l            && return 2;
      (not $l) && ((not $h) || (not $k))    && return 6;
      (not $l) && ($h == $k)                && return 6;
      (not $l) && ($h != $k)                && return 12; #*
      $l && ((not $h) || (not $k))          && return 12; #*
      $l && ($h == $k)                      && return 12; #*
      return 24;			                  #*
    };
    ($class eq 'tetragonal') and do{
      (not $h) && (not $k) && $l            && return 2;
      (not $l) && ((not $h) || (not $k))    && return 4;
      (not $l) && ($h == $k)                && return 4;
      (not $l) && ($h != $k)                && return 8; #*
      $l && ((not $h) || (not $k))          && return 8;
      $l && ($h == $k)                      && return 8;
      return 16;			                 #*
    };
    ($class eq 'orthorhombic') and do{
      (not $r[0]) && (not $r[1])            && return 2;
      (not $r[0]) || (not $r[1])            && return 4;
      return 4;
    };
    ($class eq 'monoclinic') and do{
      (not $r[0]) || (not $r[1])            && return 2;
      return 4;
    };
    ($class eq 'triclinic') and return 2;
  };

  sub get_shift {
    my ($self) = @_;
    my $sym = $self->get("space_group");
    return (exists $r_sg->{$sym}->{shiftvec}) ? @{ $r_sg->{$sym}->{shiftvec} } : ();
  };


  sub cell_check {
    my $self = shift;
    my ($class, $aa, $bb, $cc, $alpha, $beta, $gamma) =
      $self -> get(qw(class a b c alpha beta gamma));
    my $from_cell = q{};
  DETERMINE: {
				# cubic
      $from_cell = "cubic", last DETERMINE if
	((abs($aa    - $bb) < $EPSILON) and
	 (abs($aa    - $cc) < $EPSILON) and
	 (abs($bb    - $cc) < $EPSILON) and
	 (abs($alpha - 90)  < $EPSILON) and
	 (abs($beta  - 90)  < $EPSILON) and
	 (abs($gamma - 90)  < $EPSILON));

				# tetragonal
      $from_cell = "tetragonal", last DETERMINE if
	((abs($aa    - $bb) < $EPSILON) and
	 (abs($aa    - $cc) > $EPSILON) and
	 (abs($alpha - 90)  < $EPSILON) and
	 (abs($beta  - 90)  < $EPSILON) and
	 (abs($gamma - 90)  < $EPSILON));

				# hexagonal or trigonal
      $from_cell = "hexagonal", last DETERMINE if
	((abs($aa    - $bb) < $EPSILON) and
	 (abs($aa    - $cc) > $EPSILON) and
	 (abs($alpha - 90)  < $EPSILON) and
	 (abs($beta  - 90)  < $EPSILON) and
	 (abs($gamma - 120) < $EPSILON));

				# rhombohedral
      $from_cell = "hexagonal", last DETERMINE if
	((abs($aa    - $bb)    < $EPSILON) and
	 (abs($aa    - $cc)    < $EPSILON) and
	 (abs($bb    - $cc)    < $EPSILON) and
	 (abs($alpha - $beta)  < $EPSILON) and
	 (abs($alpha - $gamma) < $EPSILON) and
	 (abs($beta  - $gamma) < $EPSILON));

				# orthorhombic
      $from_cell = "orthorhombic", last DETERMINE if
	((abs($aa    - $bb) > $EPSILON) and
	 (abs($aa    - $cc) > $EPSILON) and
	 (abs($bb    - $cc) > $EPSILON) and
	 (abs($alpha - 90)  < $EPSILON) and
	 (abs($beta  - 90)  < $EPSILON) and
	 (abs($gamma - 90)  < $EPSILON));

				# triclinic
      $from_cell = "triclinic", last DETERMINE if
	((abs($aa    - $bb) > $EPSILON) and
	 (abs($aa    - $cc) > $EPSILON) and
	 (abs($bb    - $cc) > $EPSILON) and
	 (abs($alpha - 90)  > $EPSILON) and
	 (abs($beta  - 90)  > $EPSILON) and
	 (abs($gamma - 90)  > $EPSILON));

				# monoclinic
      $from_cell = "monoclinic", last DETERMINE if
	((abs($aa - $bb) > $EPSILON) and
	 (abs($aa - $cc) > $EPSILON) and
	 (abs($bb - $cc) > $EPSILON) and
	 ( (abs($alpha - 90) > $EPSILON) or
	   (abs($beta  - 90) > $EPSILON) or
	   (abs($gamma - 90) > $EPSILON)   )  );
    };

    if ( ($from_cell eq "hexagonal") and ($class eq "trigonal") ) {
      return q{};
    };
    if ($class eq $from_cell) {
      return q{};
    };
    my $extra_message = q{};
    ($extra_message = "\nTrigonal cells have x=y<>z and alpha=beta=90 and gamma=120.")
      if ($class eq "trigonal");
    ($extra_message = "\nTriclinic cells have all unequal axes and angles.")
      if ($class eq "triclinic");

    return "The axis lengths and angles specified are not appropriate for the given space group."
      . $extra_message;

  };


  sub group_data {
    my ($self) = @_;
    my $group = $self->get("space_group");
    return $r_sg->{$group};	# reference to this groups hash of data
  };
  sub database {
    my ($self) = @_;
    return $database;
  };


  sub populate {
    my ($self, $r_sites) = @_;
    my @all_sites = @$r_sites;
    my @minimal   = ();
    my @unit_cell = ();

    my $count = 0;
    my %seen;			# need unique tags for formulas
    foreach my $site (@all_sites) {
      ++$count;
      my $tag = $site->get("tag");
      $site->set({utag => ($seen{$tag}) ? join("_", $tag, $count) : $tag});
      ++$seen{$tag};
    };
    my ($crystal_class, $setting) = $self->get(qw(class setting));

    ## rotate a tetragonal group to the standard setting
    if (($crystal_class eq "tetragonal" ) and $setting) {
      my ($a, $b) = $self->get(qw(A B));
      $self -> set({a=>$a/sqrt(2), b=>$b/sqrt(2)});
    };

    my $isite = 0;
    foreach my $site (@all_sites) {
      $site -> populate($self);
      my $tag = $site -> get("tag");
      my $count = 0;
      foreach my $list (@{ $site->get("positions") }) {
	push @unit_cell, [$site, $$list[0], $$list[1], $$list[2]]; # formulas!
	++$count;
      };
      $site -> set({in_cell=>$count});
      ++$isite;
    };
    $params_of{ident $self}{sites}    = [@all_sites];
    $params_of{ident $self}{contents} = [@unit_cell];

    #---------------------------- Check for repeats.
    my %occ  = ();
    %seen = ();
    foreach my $item (@unit_cell) {

      ## make a key from the coordinates.  the key considers 4 digits
      ## of precision -- 2.00001 and 2.00002 are the same coordinate
      my @key_parts = map { substr(sprintf("%7.5f", $_), 2, -1) } @$item[1..3];
      my $key = join(q{}, @key_parts);

      if (exists $seen{$key}) {
	my $site  = $item->[0];
	my $found = $seen{$key}->[0];
	my ($that, $this) = ($found->get("tag"), $site->get("tag"));
	$occ{$key}->[0] += $site->get("occupancy");
	push @{$occ{$key}}, $this; # add tag to list
	## flag this as a dopant
	$site -> set({host=>0});
	## 	croak "The sites \"" . $this . "\" and \"" . $that .
	## 	    "\" generate the same position in space.$/" .
	## 	      "Multiple occupancy is not allowed in this program.$/" .
	## 		"This program cannot continue due to the error";
      };
      $seen{$key} = $item;	# $ {$$item[3]}->{Tag};
      $occ{$key} ||= [ $item->[0]->get("occupancy"), $item->[0]->get("tag") ];
    };

    ## now check that a site is not overly occupied
    my @croak;
    foreach my $k (keys %occ) {
      my @list = @{$occ{$k}};
      my $val = shift @list;
      if ($val > (1+$EPSILON)) {
	croak("These sites:\n\t" .
	      join("  ", map {sprintf "\"%s\"", $_} @list) .
	      "\ngenerate one or more common positions and their occupancies\n" .
	      "sum to more than 1.");
      };
    };
    return $self;
  };


  sub central {
    my ($self, $core) = @_;
    return (q{},0,0,0,0) if (not $self->get("contents"));

    my ($list, $central, $is_host) = ([], q{}, 0);
    my @center = (0,0,0);
    foreach my $item (@{$self->get("contents")}) {
      my $site = $item->[0];
      if (lc($core) eq lc($site->get("tag"))) {
	($is_host, $list) = $site->get(qw(host positions));
	$central = $site;
	last;
      };
    };
    #my @cformula = ("", "", "");
    my ($dist, $best) = (0, 100000);
    foreach my $position (@$list) {
      $dist = sqrt((0.5-$$position[0])**2 + (0.5-$$position[1])**2 + (0.5-$$position[2])**2);
      if ($dist < $best) {
	@center = @$position;
	$best = $dist;
      };
    };
    #print join(" ", $central, $xcenter, $ycenter, $zcenter), $/;
    ##($xcenter, $ycenter, $zcenter) =
    ##  $self -> metric($xcenter, $ycenter, $zcenter);
    return wantarray ? ($central, @center, $is_host) : $central;
  };


## this for Xray::Crystal

##   sub overfull {
##     my ($self, $epsi) = @_;
##     $epsi ||= $EPSILON;
##     ($epsi = $EPSILON) if ($epsi < 0);
##
##     my @list = ();
##     foreach my $site (@{$self->get("contents")}) {
##       my @p = ([0],[0],[0]);
##       unless ($epsi < 0) {
## 	foreach my $i (0..2) {
## 	  ($$site[$i]     < $epsi) && ($p[$i] = [0,1]);  # near 0
## 	  ((1-$$site[$i]) < $epsi) && ($p[$i] = [-1,0]); # near 1
## 	};
##       };
##       foreach my $a (@{$p[0]}) {
## 	foreach my $b (@{$p[1]}) {
## 	  foreach my $c (@{$p[2]}) {
## 	    my ($x, $y, $z) =
## 	      $self -> metric($$site[0]+$a, $$site[1]+$b, $$site[2]+$c);
## 	    push @list, [$x, $y, $z, $$site[3]];
## 	    #push @list, [$$site[0]+$a, $$site[1]+$b, $$site[2]+$c, $$site[3]];
## 	  };
## 	};
##       };
##     };
##     return @list;
##   };



};
1;



=head1 NAME

Xray::Crystal::Cell - A crystallographic unit cell object


=head1 VERSION

This documentation refers to Ifeffit::Demeter version 0.1.


=head1 SYNOPSIS


=head1 DESCRIPTION

=head1 ATTRIBUTES

These are the attributes that are user-settable:

=over 4

=item C<a>

The a lattice constant.

=item C<b>

The b lattice constant.

=item C<c>

The c lattice constant.

=item C<alpha>

The angle between the b and c lattice constants.

=item C<beta>

The angle between the a and c lattice constants.

=item C<gamma>

The angle between the a and b lattice constants.

=item C<angle>

This takes the value of the most recently set angle.  This is only
needed for the peculiar situation of a monoclinic space group with all
three angles equal to 90.  The function determine monoclinic will not
be able to resolve the setting in that situation without a little
help.  The idea is that the user has to specify at least one angle in
order to unambiguously determine the setting.

=item C<space_group>

A string specifying the space group of the cell. The supplied value is
stored in the C<given_group> attribute and this is filled with the
canonical symbol.

=back

The bare minimum required to define is a cell is the a lattice
constant and the space group symbol.  All other attributes have
sensible defaults or are calculated quantities.  Of course, any space
group of lower than cubic symmetry will require that other axes and/or
angles be specified.

There are several other Cell attributes.  Except for the Contents
attribute, these are updated every time the C<make> method is called.
These include:

=over 4

=item C<given_group>

The space group symbol used as the argument for
the C<space_group> attribute when the C<make> method is called.

=item C<setting>

The setting of a low symmetry space group.  See
below for a discussion of low symmetry space groups.

=item C<contents>

This is an anonymous list of anonymous lists specifying the contents
of the fully decoded unit cell.  This attribute is set by caling the
C<populate> method.  Each list element is itself a list containing the
x, y, and z fractional coordinates of the site and a reference to the
Site obect which generated that site.  To examine the contents of the
cell, do something like this:

  my ($contents) = $cell -> attributes("Contents");
  foreach my $pos (@{$contents}) {
    printf "x=%8.5f, y=%8.5f, z=%8.5f$/",
      $$pos[0], $$pos[1], $$pos[2]
  };

=item C<volume>

The volume of the unit cell computed from the axes and angles.

=item C<txx>

The x-x element of the metric tensor computed from the axes and
angles.  This is used to translate from fractional to cartesian
coordinates.

=item C<tyx>

The y-x element of the metric tensor computed from the axes and
angles.

=item C<tyz>

The y-z element of the metric tensor computed from the axes and
angles.

=item C<tzx>

The z-x element of the metric tensor computed from the axes and
angles.

=item C<tzz>

The z-z element of the metric tensor computed from the axes and
angles.

=item other metric tensor elements

The yy element of the metric tensor is unity and the other three are
zero.

=back

=head1 METHODS

=over 4

=item C<populate>

Populate a unit cell given a list of sites.  Each element of the list
of sites must be a Site object.  The symmetries operations implied by
the space group are applied to each unique site to generate a
description of the stoichiometric contents of the unit cell.

   $cell -> populate(\@sites)

This fills the C<contents> attribute of the Cell with an anonymous
array.  Each element of the anonymous array is itself an anonymous
array whose first three elements are the x, y, and z fractional
coordinates of the site and whose fourth element is a reference to the
Site that generated the position.  This is, admitedly, a complicated
data structure and requires a lot of ``line-noise'' style perl to
dereference all its elements.  It is, however, fairly efficient.

=item C<class>

This sets the C<class> attribute withe crystal class of the psace
group.

=item C<bravais>

This sets the C<bravais> attribute with an anonymous array containing
the Bravais translations for this space group.

=item C<metric>

Takes the three fractional coordinates and returns the cartesian
coordinates of the position.  The fractional coordinates need not be
canonicalized into the first octant, thus this method can be used to
generate the cartesian coordinates for any atom in a cluster.

  ($x,$y,$z) = $cell -> metric($xf, $yf, $zf);

This method is called repeatedly by the C<build_cluster> function in
the L<Ifeffit::Demeter::Atoms> module.  The elements of the metric
tensor, i.e. the C<txx>, C<tyx>, C<tyz>, C<tzx>, and C<tzz> Cell
attributes, are used to make the transformation according to this
formula:

              / Txx   0    0  \   / xf \
   (x y z) = |  Tyx   1   Tyz  | |  yf  |
              \ Tzx   0   Tzz /   \ zf /

=item C<d_spacing>

Takes the Miller indeces of a scattering plane and returns the d
spacing of that plane in Angstroms.

  $d = $cell -> d_spacing($h, $k, $l);

=item C<multiplicity>

Returns the multiplicity of a reflection hkl for the cell.

  $p = $cell -> multiplicity($h, $k, $l);

See the footnote in Cullity page 523 for a caveat.

=item C<cell_check>

This method returns a warning if the cell axes and angles are not
appropriate to the space group, otherwise it returns an empty string.

  print $cell -> cell_check;

=back


=head1 COERCIONS

=head1 SERIALIZATION AND DESERIALIZATION


=head1 CONFIGURATION AND ENVIRONMENT

See ___ for a description of the configuration system.

=head1 DEPENDENCIES


=head1 BUGS AND LIMITATIONS

These methods are not yet implemented:

=over 4

=item *

overfull

=item *

warn_shift

=item * 

get_symmetry_table

=item *

set_ipots

=back

Please report problems to Bruce Ravel (bravel AT bnl DOT gov)

Patches are welcome.

=head1 AUTHOR

Bruce Ravel (bravel AT bnl DOT gov)

http://cars9.uchicago.edu/~ravel/software/


=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2008 Bruce Ravel (bravel AT bnl DOT gov). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
