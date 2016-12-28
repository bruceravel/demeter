package Demeter::ScatteringPath;

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
use MooseX::Aliases;
extends 'Demeter';
use Demeter::NumTypes qw( Natural );
with "Demeter::ScatteringPath::Rank";

use Chemistry::Elements qw(get_symbol);
use Carp;
use File::Spec;
use List::Util qw(reduce);
use List::MoreUtils qw(pairwise notall all any);
#use Math::Complex;
use Math::Round qw(round);
#use Math::Trig qw(acos atan);
use POSIX qw(acos);
use Demeter::Constants qw($PI $EPSILON5 $EPSILON6 $FEFFNOTOK);

# used in compute_beta and identify_path; made global as a speed
# optimization I am trying to avoid directly calling variables of
# other packages, but in this case it is warrented as a matter of
# speed
my $fsangle = $Demeter::config->default("pathfinder", "fs_angle");
my $ncangle = $Demeter::config->default("pathfinder", "nc_angle");
my $rtangle = $Demeter::config->default("pathfinder", "rt_angle");


## In principle, I would like to use Moose::Meta::Attribute::Native with
## this class as well.  I find that doing for the the ArrayRef valued
## attributes adds a measurable amount of overhead.  Since this is
## called SO MANY TIMES, it seems prudent to reduce the amount of
## Moose-y overhead

		     ## caller provides these two
has 'feff'	   => (is => 'rw', isa => 'Demeter::Feff', alias => 'parent');
has 'string'	   => (is => 'rw', isa => 'Str',      default => q{});

## this is used only by paths coming from an aggregate Feff
## calculation, which *has* to resolve details of the paths
## relatively early since the Feff calcualtion of origin will
## eventually be thrown away
has 'ipot'	   => (is => 'rw', isa => 'ArrayRef', default => sub{[]});

has 'nkey'	   => (is => 'rw', isa => 'Int',      default => 0); # integer key built from atoms indeces

has 'rleg'	   => (is => 'rw', isa => 'ArrayRef', default => sub{[]});
has 'beta'	   => (is => 'rw', isa => 'ArrayRef', default => sub{[]});
has 'fs'	   => (is => 'rw', isa => 'Int',      default => 0);
has 'eta'	   => (is => 'rw', isa => 'ArrayRef', default => sub{[]});
has 'betanotstraightish' => (is => 'rw', isa => 'Bool',     default => 0);
has 'etanonzero'   => (is => 'rw', isa => 'Bool',     default => 0);
has 'betakey'	   => (is => 'rw', isa => 'Str',      default => q{});
has 'etakey'	   => (is => 'rw', isa => 'Str',      default => q{});
has 'nleg'	   => (is => 'rw', isa => 'Int',      default => 2);
has 'halflength'   => (is => 'rw', isa => 'LaxNum',   default => 0);
has 'anglein'      => (is => 'rw', isa => 'LaxNum',   default => 0);
has 'angleout'     => (is => 'rw', isa => 'LaxNum',   default => 0);
has 'cosinout'     => (is => 'rw', isa => 'LaxNum',   default => 0);

has 'heapvalue'	   => (is => 'rw', isa => 'Any',      default => 0);

has 'n'		   => (is => 'rw', isa => 'LaxNum',   default => 1);
has 'zcwif'        => (is => 'rw', isa => 'LaxNum',   default => -1);

has 'degeneracies' => (is => 'rw', isa => 'ArrayRef', default => sub{[]});
has 'fuzzy'	   => (is => 'rw', isa => 'LaxNum',   default => 0);
has 'Type'	   => (is => 'rw', isa => 'Str',      default => q{});
has 'weight'	   => (is => 'rw', isa => 'Int',      default => 0);
has 'randstring'   => (is => 'rw', isa => 'Str',      default => q{});
has 'folder'       => (is => 'rw', isa => 'Str',      default => q{});
has 'file'         => (is => 'rw', isa => 'Str',      default => q{});
has 'fromnnnn'     => (is => 'rw', isa => 'Str',      default => q{});
has 'orig_nnnn'    => (is => 'rw', isa => 'Str',      default => q{});
has 'site_fraction'=> (is => 'rw', isa => 'LaxNum',   default => 1);

has 'pathfinding'  => (is => 'rw', isa => 'Bool',     default => 1);
has 'pathfinder_index'=> (is=>'rw', isa=>  Natural, default => 0);

has 'cleanup'      => (is => 'rw', isa => 'Bool',     default => 1);

## set by details method:
#has 'tags'         => (is => 'rw', isa => 'ArrayRef', default => sub{[]});
#has 'ipots'        => (is => 'rw', isa => 'ArrayRef', default => sub{[]});
#has 'elements'     => (is => 'rw', isa => 'ArrayRef', default => sub{[]});


sub BUILD {
  #my ($self, @params) = @_;
  ## cannot do this now, keeping track of SP objects in this while
  ## during pathfinder is too damn inefficient
  #$self->mo->push_ScatteringPath($self);
  return $_[0];
};
# a bit of optimization, skipping the "($self) = @_" step
override remove => sub {
  return $_[0] if $_[0]->pathfinding;
  $_[0]->mo->remove($_[0]) if (defined($_[0]) and ref($_[0]) =~ m{Demeter} and defined($_[0]->mo));
  return $_[0];
};
sub DEMOLISH {
  #my ($self) = @_;
  $_[0]->remove;
};

# override all => sub {
#   my ($self) = @_;
#   my %all = $self->SUPER::all;
#   delete $all{feff};
#   return %all;
# };

override 'alldone' => sub {
  my ($self) = @_;
  my $nnnn = File::Spec->catfile($self->folder, $self->file);
  unlink $nnnn if ((-e $nnnn) and ($self->cleanup));
  $self->remove;
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
override serialization => sub {
  my ($self) = @_;
  my %pathinfo = ();
  foreach my $key ($self->savelist) {
    $pathinfo{$key} = $self->$key;
  };
  return YAML::Tiny::Dump(\%pathinfo);
};

## identify the scatter for a single scattering path, return He (obviously silly) is MS
sub scatterer {
  my ($self) = @_;
  return 'He' if $self->nleg > 2;
  my @atoms  = split(/\./, $self->string);
  return $self->feff->site_species($atoms[1]);
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
  if ($#{$self->ipot} > -1) { ## this is an aggregate feff calc
    foreach my $i (1 .. $#{$self->ipot}-1) {
      my $this;
      my $a = $self->ipot->[$i];
      if ($a == 0) {
	$this = $token;
      } else {
	$this = $self->feff->potentials->[$a]->[2] || get_symbol($self->feff->potentials->[$a]->[1]);
      };
      #$this =~ s{$FEFFNOTOK}{}g; # scrub characters that will confuse Feff
      push @intrp, sprintf("%-6s", $this);
    };
  } else {		      ## this is a normal feff calc
    foreach my $a (@atoms[1 .. $#atoms-1]) {
      my $this = ($a == $feff->abs_index) ? $token : $feff->site_tag($a);
      #Demeter->pjoin($self->group, $a);
      #Demeter->trace;
      #$this =~ s{$FEFFNOTOK}{}g; # scrub characters that will confuse Feff
      push @intrp, sprintf("%-6s", $this);
    };
  }
  push @intrp, $token;
  my $text = sprintf("%-29s", join(" ", @intrp));
  if ($feff->is_polarization) {
    $text .= sprintf("%5.1f/%5.1f", $self->angleout, $self->anglein);
  };
  return $text;
};

sub intrpline {
  my ($self, $i) = @_;
  $i ||= 9999;
  my $rank = $self->get_rank(Demeter->co->default('pathfinder', 'rank'));
  $rank ||= 0;
  my $format = " %4.4d  %6.3F   %6.3f  ---  %-29s    %2d  %6.2f  %d  %s";
  $format = " %4.4d  %6.3F   %6.3f  ---  %-39s    %2d  %6.2f  %d  %s" if $self->feff->is_polarization;
  if ($self->feff->nlegs == 5) {
    $format = " %4.4d  %6.3F   %6.3f  ---  %-36s    %2d  %6.2f  %d  %s";
    $format = " %4.4d  %6.3F   %6.3f  ---  %-46s    %2d  %6.2f  %d  %s" if $self->feff->is_polarization;
  };
  if ($self->feff->nlegs == 6) {
    $format = " %4.4d  %6.3F   %6.3f  ---  %-43s    %2d  %6.2f  %d  %s";
    $format = " %4.4d  %6.3F   %6.3f  ---  %-53s    %2d  %6.2f  %d  %s" if $self->feff->is_polarization;
  };
  return sprintf $format,
    $i, $self->n, $self->fuzzy, $self->intrplist, $self->weight,
      $rank, $self->nleg, $self->Type;
};

sub labelline {
  my ($self) = @_;
  return sprintf("Reff=%5.3f, nleg=%d, degen=%-2d", $self->fuzzy, $self->nleg, $self->n);
};
alias interplist => 'intrplist';
alias interpline => 'intrpline';

sub ssipot {
  my ($self) = @_;
  my @hits = split(/\./, $self->string);
  my $this_site = $hits[1];
  my $ipot = $self->feff->sites->[$this_site]->[3];
  return $ipot;
};
sub fetch_ipots {
  my ($self) = @_;
  my @hits = split(/\./, $self->string);
  my @these;
  foreach my $h (@hits) {
    my $this_site = $h;
    my $ipot = ($this_site eq '+') ? 0 : $self->feff->sites->[$this_site]->[3];
    #$ipot = 0 if ($ipot eq Demeter->co->default('pathfinder', 'token');
    push @these, $ipot;
  };
  return @these;
};

## set halflength and beta list for this path
sub evaluate {
  my ($self) = @_;
  my ($feff, $string) = ($self->feff, $self->string);

  ## compute nlegs
  $self -> compute_nleg_nkey($string);
  $self -> compute_halflength($feff, $string);
  $self -> compute_beta($feff, $string);
  $self -> betakey($self->_betakey);
  $self -> etakey($self->_etakey);
  $self -> identify_path;
  $self -> randstring(Demeter->randomstring(9).'.sp');
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
  $self->nleg($na);
  $self->nkey($nkey);
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
  $self->halflength($halflength);
  $self->heapvalue($halflength);
  $self->compute_polarization_angles($feff, @atoms);
  return $halflength;
};

sub compute_polarization_angles {
  my ($self, $feff, @atoms) = @_;
  if (not $feff->is_polarization) {
    $self->anglein(0);
    $self->angleout(0);
    $self->cosinout(0);
    return $self;
  };
  my $first = $feff->sites->[$atoms[0]];
  my $costheta = ($first->[0]*$feff->polarization->[0] +
    $first->[1]*$feff->polarization->[1] +
      $first->[2]*$feff->polarization->[2]) /
	(sqrt($first->[0]**2 + $first->[1]**2 + $first->[2]**2) *
	 sqrt($feff->polarization->[0]**2 + $feff->polarization->[1]**2 + $feff->polarization->[2]**2));
  $self->angleout(180*acos($costheta)/$PI);
  $self->cosinout($costheta);

  my $last  = $feff->sites->[$atoms[-1]];
  $costheta = ($last->[0]*$feff->polarization->[0] +
    $last->[1]*$feff->polarization->[1] +
      $last->[2]*$feff->polarization->[2]) /
	(sqrt($last->[0]**2 + $last->[1]**2 + $last->[2]**2) *
	 sqrt($feff->polarization->[0]**2 + $feff->polarization->[1]**2 + $feff->polarization->[2]**2));
  $self->anglein(180*acos($costheta)/$PI);
  $self->cosinout(abs($costheta * $self->cosinout));
};

=for Explanation (compute_beta)
  trigonometry to determine beta and eta angles.  these are straight
  translations from mpprmd.f in the feff6 code base
                         $EPSILON6 is set to 1e-6, as in rdpath.f
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
#   my $EPSILON6 = 1e-6;
#   my $rxysqr = $x*$x + $y*$y;
#   my $r   = sqrt($rxysqr + $z*$z);
#   my $rxy = sqrt($rxysqr);
#   my ($ct, $st, $cp, $sp) = (1, 0, 1, 0);
#   ($ct, $st) = ($z/$r,   $rxy/$r) if ($r   > $EPSILON6);
#   ($cp, $sp) = ($x/$rxy, $y/$rxy) if ($rxy > $EPSILON6);
#   return ($ct, $st, $cp, $sp);
# };
sub _trig {
  my $rxysqr = $_[0]*$_[0] + $_[1]*$_[1];
  my $r   = sqrt($rxysqr + $_[2]*$_[2]);
  my $rxy = sqrt($rxysqr);
  my ($ct, $st, $cp, $sp) = (1, 0, 1, 0);

  ($ct, $st) = ($_[2]/$r,   $rxy/$r)    if ($r   > $EPSILON6);
  ($cp, $sp) = ($_[0]/$rxy, $_[1]/$rxy) if ($rxy > $EPSILON6);

  return ($ct, $st, $cp, $sp);
};
sub _arg {
  #my ($real, $imag) = @_;
  #my $th = 0;
  ($_[0] = 0) if (abs($_[0]) < $EPSILON6);
  ($_[1] = 0) if (abs($_[1]) < $EPSILON6);
  #if ((abs($real) > $EPSILON6) or (abs($imag) > $EPSILON6)) {
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
  #my @sites  = @{ $feff->sites };
  my $rsites  = $feff->sites;
  my $ai      = $feff->abs_index;
  #my @atoms   = split(/\./, $self->string);
  my @atoms   = split(/\./, $string);
  $atoms[0]   = $ai;		#  replace central atom tokens
  $atoms[-1]  = $ai;

  ## predefine variables so they do not re-instantiated during loops
  my ($im1, $i, $ip1, @asite, @bsite, @csite, @vector, $ct, $st, $cp, $sp, $ctp, $stp, $cpp, $spp, $cppp, $sppp, $b);

  my (@alpha, @beta, @gamma, @eta, @aleph, @gimel, @rleg);
  $rleg[0]  = 0;
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

    ($im1, $i, $ip1) = ($j-1, $j, $j+1);
    if ($j == $#atoms) {
      ($im1, $i, $ip1) = ($j-1, 0, 1);
    };#  elsif ($j == $#atoms+1) {
    # 	($im1, $i, $ip1) = ($#atoms-1, $#atoms, 0);
    #       };

    @asite = @{ $rsites->[$atoms[$im1]] }[0..2];
    @bsite = @{ $rsites->[$atoms[$i  ]] }[0..2];
    @csite = @{ $rsites->[$atoms[$ip1]] }[0..2];

    @vector = ( $csite[0]-$bsite[0], $csite[1]-$bsite[1], $csite[2]-$bsite[2]);
    ($ct, $st, $cp, $sp)     = _trig(@vector);
    @vector    = ( $bsite[0]-$asite[0], $bsite[1]-$asite[1], $bsite[2]-$asite[2]);
    $rleg[$j]  = sqrt($vector[0]**2 + $vector[1]**2 +$vector[2]**2);
    ($ctp, $stp, $cpp, $spp) = _trig(@vector);

    $cppp = $cp*$cpp + $sp*$spp;
    $sppp = $spp*$cp - $cpp*$sp;
    #my $phi  = atan2($sp,  $cp);
    #my $phip = atan2($spp, $cpp);

    $b = $ct*$ctp + $st*$stp*$cppp;
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

  @asite = @{ $rsites->[$atoms[$#atoms]] }[0..2];
  @bsite = @{ $rsites->[$atoms[0      ]] }[0..2];
  @vector = ( $bsite[0]-$asite[0], $bsite[1]-$asite[1], $bsite[2]-$asite[2]);
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
    ($nonzero=1) if ($eta[$j] > $EPSILON6);
  };
  my $fs = 0;
  foreach my $j (1 .. $#beta-1) {
    ++$fs if ($beta[$j] < $fsangle); # fsangle defined globally, near line 49
  };
  $self->rleg(\@rleg);
  $self->beta(\@beta);
  $self->betanotstraightish(1) if (any {($_ > $fsangle) and ($_ < (180-$fsangle))} @beta);
  $self->eta(\@eta);
  $self->etanonzero($nonzero);
  $self->fs($fs);
  return @beta;
};


## degeneracy checking
sub compare {
  my ($self, $other) = @_;
#  croak("ScatteringPaths from different Feff objects") if ($self->feff ne $other->feff);
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

  if ($#{$self->ipot} > -1) {  ## this is an Aggregate calculation
    #print $/, '>> ', join("|", @{$self->ipot}, $self->halflength), $/;
    #print '<< ', join("|", @{$other->ipot}), $/;
    my @ipot_compare = pairwise {$a == $b} @{$self->ipot}, @{$other->ipot};
    if (notall {$_} @ipot_compare) { # time reversal
      my @that = reverse(@{$other->ipot});
      @ipot_compare = pairwise {$a == $b} @{$self->ipot}, @that;
      return "ipots different" if (notall {$_} @ipot_compare);
    };
  } else { ## this is a normal Feff calculation
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

  ## polarization angles
  return "polarization angle product different" if (abs($self->cosinout - $other->cosinout) > $EPSILON5);


  #$self->set(fuzzy=>$fuzzy) if ( abs($self->halflength - $other->halflength) > $EPSILON5 );
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
  $self -> randstring(Demeter->randomstring(9).'.sp') if ($self->randstring =~ m{\A\s*\z});

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
  my @c = $feff->central;
  foreach my $a (@atoms) {
    my @coords = @{ $sites[$a] };
    ## use fuzzy length for fuzzily degenerate paths, need to scale coordinates
    my $scale = $self->fuzzy / $self->halflength;
    foreach my $j (0..2) {
      $coords[$j] = $c[$j] + ($coords[$j]-$c[$j])*$scale;
    };
    ## this bit o' yuck gets a tag from the potentials list entry if not in the sites list
    $coords[4] ||= $feff->site_tag($a);
    $coords[4] =~ s{$FEFFNOTOK}{}g; # scrub characters that will confuse Feff
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
  my ($nleg, $feff) = ($self->nleg, $self->feff);
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

    (($nleg == 5) and (any {($_ < $ncangle)} @beta[1..2]) ) and do {
      ($weight, $type) = (2, "5-legged forward scattering");
      last TYPE;
    };

    (($nleg == 6) and (any {($_ < $ncangle)} @beta[1..2]) ) and do {
      ($weight, $type) = (2, "6-legged forward scattering");
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

    ($nleg == 5) and do {
      ($weight, $type) = (0, "other 5-legged scattering");
      last TYPE;
    };

    ($nleg == 6) and do {
      ($weight, $type) = (0, "other 6-legged scattering");
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
	       $self->nkey <=> $other->nkey
                           ||
           $self->cosinout <=> $other->cosinout;
};

__PACKAGE__->meta->make_immutable;
1;

=head1 NAME

Demeter::ScatteringPath - Create and manipulate scattering paths


=head1 VERSION

This documentation refers to Demeter version 0.9.26.


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
created.  C<parent> is an alias for C<feff>.

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

=item C<rleg>

This is a reference to a list of path lengths in the path.

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
       degeneracies n randstring beta eta feff halflength fuzzy type

=item C<savelist>

This returns a list containing the subset of all ScatteringPath object
attributes that need to be saved when a Feff calculation is serialized.

  print join(" ", $sp -> savelist), $/;
    ==prints==>
       nleg string group nkey weight etanonzero rleg fs degeneracies
       n randstring beta eta halflength fuzzy type

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
F<Build.PL> file.

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

And testing has been limited.

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
