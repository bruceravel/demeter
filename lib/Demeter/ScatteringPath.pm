package Demeter::ScatteringPath;

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

=for LiteratureReference (scattering path)
  The idea of a house built expressly so that people will become lost
  in it may be stranger than the idea of a man with the head of a
  bull, and yet the two ideas may reinforce one another.  Indeed, the
  image of the Labyrinth and the image of the Minotaur seem to "go
  together": it is fitting that at the center of a monstrous house
  there should live a monstrous inhabitant.
                                     Jorge Luis Borges
                                     The Book of Imaginary Beings

=cut

use autodie qw(open close);

use Moose;
extends 'Demeter';
#use Demeter::NumTypes qw( PosInt Natural NonNeg );

use Chemistry::Elements qw(get_symbol);
use Carp;
use List::Util qw(reduce);
use List::MoreUtils qw(pairwise notall all any);
#use Math::Complex;
use Math::Round qw(round);
#use Math::Trig qw(acos atan);
use POSIX qw(acos);
use Regexp::List;
use Regexp::Optimizer;
use Readonly;
#Readonly my $PI           => 2*atan2(1,0);
#Readonly my $EPSI         => 0.00001;
#Readonly my $TRIGEPS      => 1e-6;
use String::Random qw(random_string);



my $opt  = Regexp::List->new;

# used in compute_beta and identify_path; made global as a speed
# optimization I am trying to avoid directly calling variables of
# other packages, but in this case it is warrented as a matter of
# speed
my $fsangle = $Demeter::config->default("pathfinder", "fs_angle");
my $ncangle = $Demeter::config->default("pathfinder", "nc_angle");
my $rtangle = $Demeter::config->default("pathfinder", "rt_angle");


## In principle, I would like to use MooseX::AttributeHelpers with
## this class ass well.  I find that doing for the the ArrayRef valued
## attributes adds a measurable amount of overhead.  Since this is
## called SO MANY TIMES, it seems prudent to reduce the amount of
## Moose-y overhead

		     ## caller provides these two
has 'feff'	   => (is => 'rw', isa => 'Demeter::Feff');
has 'string'	   => (is => 'rw', isa => 'Str',      default => q{});

has 'nkey'	   => (is => 'rw', isa => 'Int',      default => 0); # integer key built from atoms indeces

has 'rleg'	   => (is => 'rw', isa => 'ArrayRef', default => sub{[]});
has 'beta'	   => (is => 'rw', isa => 'ArrayRef', default => sub{[]});
has 'fs'	   => (is => 'rw', isa => 'Int',      default => 0);
has 'eta'	   => (is => 'rw', isa => 'ArrayRef', default => sub{[]});
has 'etanonzero'   => (is => 'rw', isa => 'Bool',     default => 0);
has 'betakey'	   => (is => 'rw', isa => 'Str',      default => q{});
has 'etakey'	   => (is => 'rw', isa => 'Str',      default => q{});
has 'nleg'	   => (is => 'rw', isa => 'Int',      default => 2);
has 'halflength'   => (is => 'rw', isa => 'Num',      default => 0);

has 'heapvalue'	   => (is => 'rw', isa => 'Any',      default => 0);

has 'n'		   => (is => 'rw', isa => 'Int',      default => 1);

has 'degeneracies' => (is => 'rw', isa => 'ArrayRef', default => sub{[]});
has 'fuzzy'	   => (is => 'rw', isa => 'Num',      default => 0);
has 'Type'	   => (is => 'rw', isa => 'Str',      default => q{});
has 'weight'	   => (is => 'rw', isa => 'Int',      default => 0);
has 'randstring'   => (is => 'rw', isa => 'Str',      default => q{});
has 'file'         => (is => 'rw', isa => 'Str',      default => q{});

## set by details method:
#has 'tags'         => (is => 'rw', isa => 'ArrayRef', default => sub{[]});
#has 'ipots'        => (is => 'rw', isa => 'ArrayRef', default => sub{[]});
#has 'elements'     => (is => 'rw', isa => 'ArrayRef', default => sub{[]});


sub BUILD {
  my ($self, @params) = @_;
  $self->mo->push_ScatteringPath($self);
};
sub DEMOLISH {
  my ($self) = @_;
  $self->alldone;
};

override 'alldone' => sub {
  my ($self) = @_;
  my $nnnn = $self->file;
  unlink $nnnn if -e $nnnn;
  return $self;
};

sub _betakey {
  my ($self) = @_;
  my @beta =  sort @{ $self->beta };
  return join(q{}, @beta);
};
sub _etakey {
  my ($self) = @_;
  my @eta =  sort @{ $self->eta };
  return join(q{}, @eta);
};


sub attributes {		# returns all SP attributes
  my ($self) = @_;
  return ($self->meta->get_attribute_list, qw(group name));
};
sub savelist { # returns all SP attributes that are saved when a Feff calc is serialized
  my ($self) = @_;
  ##print join(" ", $self->attributes), $/;
  return grep { $_ !~ m{feff|heapvalue|data|plot|mode} } $self->attributes;
};

## construct the intrp line by disentangling the SP string
sub intrplist {
  my ($self, $string) = @_;
  $string  ||= $self->string;
  my $feff   = $self->feff;
  my $token  = $self->co->default("pathfinder", "token") || '<+>';
  my @atoms  = split(/\./, $self->string);
  my @intrp = ($token);
  my @sites  = @{ $feff->sites };
  foreach my $a (@atoms[1 .. $#atoms-1]) {
    my $this = ($a == $feff->abs_index) ? $token : $feff->site_tag($a);
    push @intrp, sprintf("%-6s", $this);
  };
  push @intrp, $token;
  return join(" ", @intrp);
};

sub intrpline {
  my ($self, $i) = @_;
  $i ||= 9999;
  return sprintf " %4.4d  %2d   %6.3f  ----  %-29s       %2d  %d %s",
    $i, $self->n, $self->fuzzy, $self->intrplist, $self->weight, , $self->nleg , $self->Type;
};

{
  no warnings 'once';
  # alternate names
  *interplist = \ &intrplist;
  *interpline = \ &intrpline;
};


## set halflength and beta list for this path
sub evaluate {
  my ($self) = @_;
  my ($feff, $string) = $self->get(qw{feff string});

  ## compute nlegs
  $self -> compute_nleg_nkey($string);
  $self -> compute_halflength($feff, $string);
  $self -> compute_beta($feff, $string);
  $self -> set(betakey=>$self->_betakey, etakey=>$self->_etakey);
  $self -> identify_path;
  $self -> randstring(random_string('ccccccccc').'.sp');
  return $self;
};

sub compute_nleg_nkey {
  my ($self, $string) = @_;
  my @atoms  = split(/\./, $string);
  my $na = $#atoms;
  shift(@atoms); pop(@atoms); # remove central atom tokens
  ## compute the numeric key built from the atoms in this path
  ## this is used to assure order of how paths come off the heap
  my ($nkey, $cofactor) = (0,1);
  foreach (reverse @atoms) {
    $nkey += $cofactor * $_;
    $cofactor *= 1000;
  };
  $self->set(nleg=>$na, nkey=>$nkey);
  return ($na, $nkey);
};

sub compute_halflength {
  my ($self, $feff, $string) = @_;
  croak("Demeter::ScatteringPath::compute_halflength: feff and string attributes unset")
    if not ( (ref($feff) =~ m{Feff}) and $string);
  my @sites  = @{ $feff->sites };

  ## keep a list of cartesian coordinates in this path
  my @coords = @{ $feff->absorber };
  ## each part of the string is a number which is the index of that atom
  ## in the sites list of the Feff object
  my @atoms  = split(/\./, $string);
  shift(@atoms); pop(@atoms); # remove central atom tokens

  ## deprecated
  #foreach my $i (@atoms) {
  #  ## so this pushes the cartesian coordinates of that site onto the coords list
  #  push @coords, @{ $sites[$i] }[0..2];
  #};
  #my $halflength = sprintf("%.5f", Tools->halflength(@coords));

  my $cindex = $feff->abs_index;
  #my $halflength = sprintf("%.5f", 0.5*$feff->_length($cindex, @atoms, $cindex));
  my $halflength = sprintf("%.5f", 0.5*Demeter::Feff::_length($cindex, @atoms, $cindex));
  $self->set(halflength=>$halflength, heapvalue=>$halflength);
  return $halflength;
};


=for Explanation (compute_beta)
  trigonometry to determine beta and eta angles.  these are straight
  translations from mpprmd.f in the feff6 code base
                         $TRIGEPS is set to 1e-6, as in rdpath.f
   _trig
     compute Eulerian angles for each path vertex
     conventions from Feff6:
       x=y=0 and z>0 ==> phi=0, cp=1, sp=0
       x=y=0 and z<0 ==> phi=180, cp=-1, sp=0
       x=y=z=0,  theta=0, ct=1, st=0
   _arg
     alph = exp( i*alpha )
     gamm = exp( i*gamma )
     This sub returns atan2(imag_part, real_part), taking care with
     numbers near zero
   compute_beta
     This is a straight translation of lines 32-114 in mpprmd.f.  It
     then sets the beta and eta attributes of the ScatteringPath
     object and returns the beta angles.  Most variable names were
     chosen to be the same as in the fortran source.

=cut

# sub _trig {
#   my ($x, $y, $z) = @_;
#   my $TRIGEPS = 1e-6;
#   my $rxysqr = $x*$x + $y*$y;
#   my $r   = sqrt($rxysqr + $z*$z);
#   my $rxy = sqrt($rxysqr);
#   my ($ct, $st, $cp, $sp) = (1, 0, 1, 0);
#   ($ct, $st) = ($z/$r,   $rxy/$r) if ($r   > $TRIGEPS);
#   ($cp, $sp) = ($x/$rxy, $y/$rxy) if ($rxy > $TRIGEPS);
#   return ($ct, $st, $cp, $sp);
# };
sub _trig {
  my $TRIGEPS = 1e-6;
  my $rxysqr = $_[0]*$_[0] + $_[1]*$_[1];
  my $r   = sqrt($rxysqr + $_[2]*$_[2]);
  my $rxy = sqrt($rxysqr);
  my ($ct, $st, $cp, $sp) = (1, 0, 1, 0);

  ($ct, $st) = ($_[2]/$r,   $rxy/$r)    if ($r   > $TRIGEPS);
  ($cp, $sp) = ($_[0]/$rxy, $_[1]/$rxy) if ($rxy > $TRIGEPS);

  return ($ct, $st, $cp, $sp);
};
sub _arg {
  #my ($real, $imag) = @_;
  my $TRIGEPS = 1e-6;
  #my $th = 0;
  ($_[0] = 0) if (abs($_[0]) < $TRIGEPS);
  ($_[1] = 0) if (abs($_[1]) < $TRIGEPS);
  #if ((abs($real) > $TRIGEPS) or (abs($imag) > $TRIGEPS)) {
  return atan2($_[1], $_[0]) if ($_[0] || $_[1]);
  return 0;
  };

## this sub is not necessarily as readable as possible.  this is a big
## time-sink for the pathfinder, so I am trying any little tweak that
## doesn't break things to get a bit better performance out.  in
## particular, I apologize for the confusing dereferencing in the
## lines with asite/bsite/csite
sub compute_beta {
  my ($self, $feff, $string) = @_;
  my ($TRIGEPS, $PI) = (1e-6, 2*atan2(1,0));
  #my @sites  = @{ $feff->sites };
  my $rsites  = $feff->sites;
  my $ai      = $feff->abs_index;
  #my @atoms   = split(/\./, $self->string);
  my @atoms   = split(/\./, $string);
  $atoms[0]   = $ai;		#  replace central atom tokens
  $atoms[-1]  = $ai;

  my (@alpha, @beta, @gamma, @eta, @aleph, @gimel, @rleg);
  $alpha[0] = 0;
  $beta[0]  = 0;
  $gamma[0] = 0;
  $eta[0]   = 0;
  $aleph[0] = [0,0];
  $gimel[0] = [0,0];
  foreach my $j (1 .. $#atoms) {

    ## nothing gets left undefined
    #$alpha[$j] = 0;
    #$beta[$j]  = 0;
    #$gamma[$j] = 0;
    #$eta[$j]   = 0;
    #$aleph[$j] = [0,0];
    #$gimel[$j] = [0,0];

    my ($im1, $i, $ip1) = ($j-1, $j, $j+1);
    if ($j == $#atoms) {
      ($im1, $i, $ip1) = ($j-1, 0, 1);
    };#  elsif ($j == $#atoms+1) {
    # 	($im1, $i, $ip1) = ($#atoms-1, $#atoms, 0);
    #       };

    my @asite = @{ $rsites->[$atoms[$im1]] }[0..2];
    my @bsite = @{ $rsites->[$atoms[$i  ]] }[0..2];
    my @csite = @{ $rsites->[$atoms[$ip1]] }[0..2];

    my @vector = ( $csite[0]-$bsite[0], $csite[1]-$bsite[1], $csite[2]-$bsite[2]);
    my ($ct, $st, $cp, $sp)     = _trig(@vector);
    @vector    = ( $bsite[0]-$asite[0], $bsite[1]-$asite[1], $bsite[2]-$asite[2]);
    $rleg[$j]  = sqrt($vector[0]**2 + $vector[1]**2 +$vector[2]**2);
    my ($ctp, $stp, $cpp, $spp) = _trig(@vector);

    my $cppp = $cp*$cpp + $sp*$spp;
    my $sppp = $spp*$cp - $cpp*$sp;
    #my $phi  = atan2($sp,  $cp);
    #my $phip = atan2($spp, $cpp);

    my $b = $ct*$ctp + $st*$stp*$cppp;
    if ($b < -1) {
      $beta[$j] = "180.0000";
    } elsif ($b >  1) {
      $beta[$j] = "0.0000";
    } else {
      $beta[$j] = sprintf("%.4f", 180 * acos($b)  / $PI);
    };

#     $beta[$j]  = $ct*$ctp + $st*$stp*$cppp;
#     $beta[$j]  = -1 if ($beta[$j] < -1); # care with roundoff
#     $beta[$j]  =  1 if ($beta[$j] >  1);
#     #$beta[$j]  = acos($beta[$j]);
#     $beta[$j]  = sprintf("%.4f", 180 * acos($beta[$j])  / $PI);

    $aleph[$j] = [-$st*$ctp + $ct*$stp*$cppp,   $stp*$sppp];
    $gimel[$j] = [-$st*$ctp*$cppp + $ct*$stp,  -$st *$sppp];
  };

  my @asite = @{ $rsites->[$atoms[$#atoms]] }[0..2];
  my @bsite = @{ $rsites->[$atoms[0      ]] }[0..2];
  my @vector = ( $bsite[0]-$asite[0], $bsite[1]-$asite[1], $bsite[2]-$asite[2]);
  $rleg[$#atoms+1] = sqrt($vector[0]**2 + $vector[1]**2 +$vector[2]**2);

  #$alpha[0] = $alpha[$#atoms];
  push @gimel, $gimel[0];
  my $nonzero = 0;
  foreach my $j (0 .. $#atoms) {
    my $eer = ($aleph[$j]->[0] * $gimel[$j+1]->[0]) - ($aleph[$j]->[1] * $gimel[$j+1]->[1]);
    my $eei = ($aleph[$j]->[1] * $gimel[$j+1]->[0]) + ($aleph[$j]->[0] * $gimel[$j+1]->[1]);
    #my $ee = $aleph[$j] * $gimel[$j+1];
    $eta[$j] = _arg($eer, $eei);
    $eta[$j] = sprintf("%.4f", 180 * $eta[$j] / $PI);
    ($nonzero=1) if ($eta[$j] > $TRIGEPS);
  };
  my $fs = 0;
  foreach my $j (1 .. $#beta-1) {
    ++$fs if ($beta[$j] < $fsangle); # fsangle defined globally, near line 49
  };
  $self->rleg(\@rleg);
  $self->beta(\@beta);
  $self->eta(\@eta);
  $self->etanonzero($nonzero);
  $self->fs($fs);
  return @beta;
};


## degeneracy checking
sub compare {
  my ($self, $other) = @_;
  croak("ScatteringPaths from different Feff objects") if ($self->feff ne $other->feff);
  my $feff = $self->feff;

  ## compare path lengths
  return "lengths different" if ( abs($self->halflength - $other->halflength) > $feff->fuzz );

  my @sites  = @{ $feff->sites };

  ## compare number of legs and ipots
  my @this = split(/\./,  $self->string);
  shift @this; pop @this;
  my @that = split(/\./, $other->string);
  shift @that; pop @that;

  ## number of legs
  return "nlegs different" if ($#this != $#that);

  ## ipots
  my @this_ipot = map { ($_ eq '+') ? 0 : $sites[$_] -> [3] } @this;
  my @that_ipot = map { ($_ eq '+') ? 0 : $sites[$_] -> [3] } @that;
  my @ipot_compare = pairwise {$a == $b} @this_ipot, @that_ipot;
  if (notall {$_} @ipot_compare) { # time reversal
    ##($that_ipot[0], $that_ipot[-1]) = ($that_ipot[-1], $that_ipot[0]);
    @that_ipot = reverse @that_ipot;
    @ipot_compare = pairwise {$a == $b} @this_ipot, @that_ipot;
    return "ipots different" if (notall {$_} @ipot_compare);
  };

  ## beta angles
  @this = @{ $self ->beta };
  @that = @{ $other->beta };
  my $bfuzz = $feff->betafuzz;
  return "nlegs different" if ($#this != $#that);
  my @angle_compare = pairwise { abs($a - $b) < $bfuzz } @this, @that;
  if (notall {$_} @angle_compare) { # time reversal
    ($that[0], $that[-1]) = ($that[-1], $that[0]);
    @that = reverse @that;
    @angle_compare = pairwise { abs($a - $b) < $bfuzz } @this, @that;
    return "betas different" if (notall {$_} @angle_compare);
  };

  ## eta angles
  my @this_eta = @{ $self ->eta };
  my @that_eta = @{ $other->eta };
  my @eta_compare = pairwise { abs(abs($a) - abs($b)) < $feff->betafuzz } @this_eta, @that_eta;
  if (notall {$_} @eta_compare) { # time reversal
    ($that_eta[0], $that_eta[-1]) = ($that_eta[-1], $that_eta[0]);
    @that_eta = reverse @that_eta;
    @eta_compare = pairwise { abs(abs($a) - abs($b)) < $feff->betafuzz } @this_eta, @that_eta;
    return "etas different" if (notall {$_} @eta_compare);
  };

  #$self->set(fuzzy=>$fuzzy) if ( abs($self->halflength - $other->halflength) > $EPSI );
  return q{};
};

## ----------------------------------------------------------------
## textual reporting methods

=for Explanation (pathsdat)
  pathsdat writes out a paragraph in the format read from the paths.dat file by genfmt
  args is a hash reference with these keys:
    index:  the numerical index of this path in the sense of NNNN from feffNNNN.dat
    angles: a boolean, true measn to write out the rleg, beta, and eta columns to the
            paths.dat file.  note that those columns are optional -- feff does not read them
    string: the string (in the sense of the ScatteringPath string method) to be used to expand
            into a paths.dat paragraph.  use the all_strings method to get the strings of
            all degeneracies for this SP object

=cut

sub pathsdat {
  my ($self, @arguments) = @_;
  my %args = @arguments;
  $args{index}  ||= 1;
  $args{angles}   = 1 if (not defined($args{angles}));
  $args{string} ||= $self -> string;
  $self -> randstring(random_string('ccccccccc').'.sp') if ($self->randstring =~ m{\A\s*\z});

  my $feff = $self->feff;
  my @sites = @{ $feff->sites };
  my $pd = q{};

  $pd .= sprintf("  %4d    %d  %6.3f  index, nleg, degeneracy, r= %.4f\n",
		 $args{index}, $self->get(qw(nleg n fuzzy)) );
  $pd .= "      x           y           z     ipot  label";
  $pd .= "      rleg      beta        eta" if ($args{angles});
  $pd .= "\n";
  my @atoms = split(/\./, $args{string});
  shift @atoms; pop @atoms;
  my $i=1;
  my ($rrleg, $rbeta, $reta) = $self->get(qw(rleg beta eta));
  foreach my $a (@atoms) {
    my @coords = @{ $sites[$a] };
    ## use fuzzy length for fuzzily degenerate paths, need to scale coordinates
    my $scale = $self->fuzzy / $self->halflength;
    @coords[0..2] = map {$scale*$_} @coords[0..2];
    ## this bit o' yuck gets a tag from the potentials list entry if not in the sites list
    $coords[4] ||= $feff->site_tag($a);
    $pd .= sprintf(" %11.6f %11.6f %11.6f   %d '%-6s'", @coords);
    $pd .= sprintf("  %9.4f %9.4f %9.4f",$rrleg->[$i], $rbeta->[$i], $reta->[$i]) if $args{angles};
    $pd .= "\n";
    ++$i;
  };
  $pd .= sprintf(" %11.6f %11.6f %11.6f   %d '%-6s'", $feff->central, 0, 'abs');
  $pd .= sprintf("  %9.4f %9.4f %9.4f", $rrleg->[$i], $rbeta->[$i], $reta->[$i]) if $args{angles};
  $pd .= "\n";
  return $pd;
};

sub details {
  my ($self, $string) = @_;
  my $feff = $self->feff;
  my @list_of_sites = @{ $feff->sites };
  my @list_of_ipots = @{ $feff->potentials };

  my $pathstring = $string || $self->string;

  my @this_path = split(/\./, $pathstring);
  shift @this_path; pop @this_path;

  my @ipots = map { $list_of_sites[$_]->[3] || -1  } @this_path;
  my @tags  = map { $list_of_sites[$_]->[4] || q{} } @this_path;
  my @elems = map { get_symbol($list_of_ipots[$_]->[1]) || q{} } @ipots;

  return (ipots=>\@ipots, tags=>\@tags, elements=>\@elems);
};

sub all_strings {
  my ($self) = @_;
  return @{ $self->degeneracies };
};
sub all_degeneracies {
  my ($self) = @_;
  my @dlist = @{ $self->degeneracies };
  return
    map {
      my $this = $self->intrplist($_);
      $this =~ s{ +}{ }g;
      $this;
    } @{ $self->degeneracies };
};



=for LiteratureReference (identify_path)
   And out of the ground the LORD God formed every beast of the field,
   and every fowl of the air; and brought them unto Adam to see what he
   would call them: and whatsoever Adam called every living creature,
   that was the name thereof.
                                       Genesis 2:19, KJB

=cut

=for Explanation
   An obtuse triangle has one internal angle larger than 90° (an obtuse
   angle).
   .
   An acute triangle has internal angles that are all smaller than 90°
   (three acute angles). An equilateral triangle is an acute triangle,
   but not all acute triangles are equilateral triangles.
                                       from Wikipedia

=cut

sub identify_path {
  my ($self) = @_;
  my ($nleg, $feff) = $self->get(qw(nleg feff));
  my @beta = @{ $self->beta };
  my ($type, $weight) = (q{}, 0);

 TYPE: {

    ($nleg == 2) and do {
      ($weight, $type) = (2, "single scattering");
      last TYPE;
    };

    (($nleg == 3) and (any {($_ < $ncangle)} @beta[1..2]) ) and do {
      ($weight, $type) = (2, "forward scattering");
      last TYPE;
    };

    (($nleg == 3) and (any {($_ > (180-$ncangle))} @beta[1..2]) ) and do {
      ($weight, $type) = (2, "non-forward linear");
      last TYPE;
    };

    (($nleg == 4) and ($beta[2] < $ncangle) and (all {($_ == 180)} ($beta[1],$beta[3])) ) and do {
      ($weight, $type) = (2, "forward through absorber");
      last TYPE;
    };

    (($nleg == 4) and (all {($_ < $ncangle)} ($beta[1],$beta[3])) ) and do {
      ($weight, $type) = (2, "double forward scattering");
      last TYPE;
    };

    (($nleg == 3) and (all {$_ >= (180-$rtangle)} @beta[1..3])) and do {
      ($weight, $type) = (1, "acute triangle");
      last TYPE;
    };

    (($nleg == 4) and (all {$_ == 180} @beta[1..3])) and do {
      ($weight, $type) = (1, "rattle");
      last TYPE;
    };

    (($nleg == 3) and (any {($_ < $rtangle) and ($_ > $fsangle)} @beta[1..2]) ) and do {
      ($weight, $type) = (1, "obtuse triangle");
      last TYPE;
    };

    (($nleg == 3) and (any {($_ < $rtangle) and ($_ > $fsangle)} @beta[2..3]) ) and do {
      ($weight, $type) = (1, "obtuse triangle");
      last TYPE;
    };

    (($nleg == 3) and (any {($_ < $fsangle) and ($_ > $ncangle)} @beta[1..2]) ) and do {
      ($weight, $type) = (1, "forward triangle");
      last TYPE;
    };

    (($nleg == 4) and (all {($_ < $fsangle) and ($_ > $ncangle)} ($beta[1],$beta[3])) ) and do {
      ($weight, $type) = (1, "forward triangle");
      last TYPE;
    };

    (($nleg == 4) and ($beta[2] != 180) and (all {$_ == 180} ($beta[1],$beta[3]))) and do {
      ($weight, $type) = (0, "hinge");
      last TYPE;
    };

    (($nleg == 4) and ($beta[2] == 180) and (all {$_ != 180} ($beta[1],$beta[3]))) and do {
      ($weight, $type) = (0, "dog-leg");
      last TYPE;
    };

    (($nleg == 4) and (all {($_ < $rtangle) and ($_ > $fsangle)} ($beta[1],$beta[3])) ) and do {
      ($weight, $type) = (0, "obtuse triangle");
      last TYPE;
    };

    ($nleg == 3) and do {
      ($weight, $type) = (0, "other double scattering");
      last TYPE;
    };

    ($nleg == 4) and do {
      ($weight, $type) = (0, "other triple scattering");
      last TYPE;
    };

  };

  $self -> weight($weight);
  $self -> Type($type);
  return $self;
};


## ----------------------------------------------------------------
## methods required by the Heap module
sub heap {
  my ($self, $value) = @_;
  if ($value) {
    $self->heapvalue($value);
    return 1;
  } else {
    return $self->heapvalue;
  };
};

sub cmp {
  my ($self, $other) = @_;
  return $self->halflength <=> $other->halflength
                           ||
               $self->nleg <=> $other->nleg
                           ||
             $self->etakey cmp $other->etakey
                           ||
            $self->betakey cmp $other->betakey
                           ||
	       $self->nkey <=> $other->nkey;
};

__PACKAGE__->meta->make_immutable;
1;

=head1 NAME

Demeter::ScatteringPath - Create and manipulate scattering paths


=head1 VERSION

This documentation refers to Demeter version 0.3.


=head1 SYNOPSIS

   $sp_object -> new(feff=>$feff, string=>$string);
   $sp_object -> evaluate;

Those are the only two attributes provided to the object.  Everything
else is computed from those two.

=head1 DESCRIPTION

This object handles the abstract representation of the scattering
path.  This is part of Demeter's theory subsystem, unlike
Demeter::Path, which is part of Demeter's fitting subsytem.  This
object is used by Demeter::Feff's path finder and
just-in-time path calculator.

This object requires that a Feff object has already been created and
fully populated.  That is either done by the Feff object's C<rdinp>
method or in some other manner.  These objects are created during the
Feff object's C<pathfinder> method.  Once a tree of scattering paths is
created from the Feff object's atoms list, the tree is traversed and a
ScatteringPath object is made from each visitation of the tree.  The
tree is completely depopulated, transfering each ScatteringPath object
to a heap.  ScatteringPaths are removed from the heap and placed onto
a well-ordered list of paths.  As the list is created, the paths are
collapsed by degeneracy.

Although you may interact with ScatteringPath objects extensively in
your programs, typically creation is left up to the Feff object's
C<pathfinder> method.  Similarly, you will find that you rarely C<set>
attributes, but often C<get> them.

=head1 ATTRIBUTES

=over 4

=item C<feff>

A reference to the Feff object from which this ScatteringPath was
created.

=item C<string>

A string denoting the route this path takes through the cluster.  This
string has a very specific form.  The first and last tokens in the
string represent the absorber and can be almost anything.  A plus sign
(+) is typical.  Each intermediate token is the index in the Feff
objects atoms list for that atom in the scattering path.  The tokens
are joined by dots.  For example, a ScatteringPath that represents the
path from the absorber to the 7th atom in the list to the 23rd atom in
the list and back (a double scattering path) would have this string:

   +.7.23.+

These numbers are interpreted by referring to the Feff object
contained in the feff attribute.  Typically, the value of this
attribute is the first degenerate scattering geometry found by the
path finder.

=item C<nkey>

This is a integer constructed from the atoms indeces that is used to
sort the scattering paths in the heap a predictable manner.

=item C<beta>

This is a reference to a list of beta angle in the path.

=item C<eta>

This is a reference to a list of eta angle in the path.

=item C<nleg>

This is the number of legs in the path, stored for easy reference.

=item C<halflength>

This is the half path length of this path.  This is the primary
sorting criterion.

=item C<heapvalue>

This is a value required by and used by the Heap algorithm.  It is
computed using the halflength class method from L<Demeter::Tools>.

=item C<n>

This is the degeneracy of this path after the paths have been collapsed.

=item C<degeneracies>

This is a reference to a list containing the string attribute of each
ScatteringPath object that was collapsed into this one.

=item C<fuzzy>

This is the fuzzy path length.  It is set to the average of the
lengths of the nearly degenerate paths.  For truly degenerate paths,
the half length and the fuzzy length will be the same.

=item C<random_string>

A 12-character string generated each time the C<pathsdat> method is
called.  The first 9 characters are random, the last three are F<.sp>.
This is used to name F<feffNNNN.dat> files which are generated from a
ScatteringPath object and assures that filename collisions will never
happen, even when rerunning feff calculations or combining results
from two or more feff calculations.

=back


=head1 METHODS

=head2 Accessor methods

The accessor methods of the parent class, C<get> and C<set> are used
my this class.

=over 4

=item C<attributes>

This returns a list of all ScatteringPath object attributes.

  print join(" ", $sp -> attributes), $/;
    ==prints==>
       nleg string heapvalue group nkey weight etanonzero rleg fs
       degeneracies n random_string beta eta feff halflength fuzzy type

=item C<savelist>

This returns a list containing the subset of all ScatteringPath object
attributes that need to be saved when a Feff calculation is serialized.

  print join(" ", $sp -> savelist), $/;
    ==prints==>
       nleg string group nkey weight etanonzero rleg fs degeneracies
       n random_string beta eta halflength fuzzy type

=back

=head2 Evaluation methods

Once a ScatteringPath object if defined by the C<new> method and given
feff and string attributes, the object must be evaluated.  For reasons
of efficiency, the evaluation is not done automatically, so the
example given for the C<evaluate> method should become your common
idiom for using this object.

=over 4

=item C<evaluate>

This method sets most attributes for the object based on the values of
the feff and string attributes.  It calls the remaining methods in
sequence.

   $sp_object -> new(feff=>$feff, string=>$string);
   $sp_object -> evaluate;

=item C<compute_nleg_nkey>

Determine the number of legs of this path and compute the nkey from
the atoms in this path.  Set the nleg and nkey attributes.

=item C<compute_halflength>

Determine the half path length of this path and set the halfpath
attribute.  Note that the Demeter::Tools::halflength class method is
used to compute this.


=item C<compute_beta>

Compute the beta and eta angles for this path and set the beta
and eta attributes.

=back

=head2 Textual reporting methods

=over 4

=item C<pathsdat>

This method writes out a paragraph in the format read from the
paths.dat file by genfmt

  print $sp_object -> pathsdat(\%args);

This method takes an optional argument which is a hash reference.  The
hash has can have these keys:

=over 4

=item I<index>

the numerical index of this path in the sense of NNNN from feffNNNN.dat

=item I<angles>

a boolean, true measn to write out the rleg, beta, and eta columns to
the paths.dat file.  note that those columns are optional -- feff does
not read them

=item I<string>

the string (in the sense of the ScatteringPath string method) to be
used to expand into a paths.dat paragraph.  use the all_strings method
to get the strings of all degeneracies for this SP object

=back

=item C<all_strings>

This method returns a list of text strings of the sort returned by the
C<string> method.  These can be used to reconstruct the geometry of
any of the degenerate paths subsumed into this ScatteringPath object.

  @strings = $sp_object -> all_strings;

=item C<all_degeneracies>

This returns a list of text strings.  The list contains the list from
the C<all_strings> method with each list element passed through the
C<intrplist> method.

=back

=head2 Heap methods

These are the two methods required by the L<Heap> module.

=over 4

=item C<heap>

This is used to set and access the heapvalue attribute.

=item C<cmp>

This is the comparison method used to order the items on the heap.  It
sorts first by half path length, then by nleg, then by the output of
the C<betakey> method, and finally by the nkey.

In practice this means that paths are ordered by increasing path
length, then by increasing nleg.  In the case of collinear paths, it
is guaranteed that the single scattering paths will come before the
doubles which will come before the triples.  The sort by beta assures
that forward scattering paths come before paths which scatter at other
angles.

Finally, the nkey portion of the sort makes it clear which path from a
degenerate set will be selected as the representative path.  This sort
is done in the order the atoms appear in the Feff object's atoms list.
For example, for the single scattering from the first shell, the
representative path will always be the one that scatters from the
first atom from the first coordination shell to appear in the atoms
list.

=back

=head2 Convenience methods

=over 4

=item C<feff>

Returns the Feff object for this ScatteringPath.

=item C<nleg>

Returns the nleg attribute.

=item C<nkey>

Returns the nkey attribute.

=item C<halflength>

Returns the halflength attribute.

=item C<intrplist>

Compute the interpretation line from the string attribute.  This looks
something like this:

   [+] O_1    Ti_1   O_1    [+]

With no argument, this returns the interpretation line for the primary
path:

  print $sp_object -> intrplist;

Alternately, you can provide a string from the list returned by the
C<all_strings> method to generate the interpretation line for that
degenerate path:

  print $sp_object -> intrplist($some_string);

=back

=head1 COERCIONS

When the reference to the ScatteringPath object is used in string
context, it returns the group name, like other Demeter objects.

When the reference to the ScatteringPath object is used in numerical
context, it returns the half length of the path from the C<halfpath>
method.

=head1 DIAGNOSTICS

=over 4

=item C<Demeter::ScatteringPath: \"$key\" is not a valid parameter>

You have tried to set or get an invalid ScatteringPath attribute.

=item C<Demeter::ScatteringPath::compute_halflength: feff and string attributes unset>

You have attempted to compute a halflength without defining the path geometry.

=item C<ScatteringPaths from different Feff objects>

You have attempted to compare ScatteringPath objects associated with
different Feff objects.

=back

=head1 CONFIGURATION AND ENVIRONMENT

See L<Demeter::Config> for a description of the configuration
system.  The C<pathfinder> parameter group is used to configure the
behavior of this module.

=head1 DEPENDENCIES

The dependencies of the Demeter system are listed in the
F<Bundle/DemeterBundle.pm> file.

=head1 BUGS AND LIMITATIONS

A few features have not yet been implemented:

=over 4

=item *

It is currently very awkward to get a F<feffNNNN.dat> written for one
of the degeneracies associated with a ScatteringPath.

=item *

Final eta angle is not computed correctly

=item *

Amplitude approximation

=item *

polarization

=item *

changing species of an atom in a path

=back

And testing has been extremely limited.

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
