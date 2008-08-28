package Xray::Crystal::Site;

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
use Safe;
use Text::Abbrev;

use Readonly;
Readonly my $NUMBER   => $RE{num}{real};
Readonly my $PI       => 4*atan2(1,1);
Readonly my $EPSILON  => 0.00001;

{

  my %params_of  :ATTR;

  my %defaults = (
		  element    => q{},
		  tag	     => q{},
		  utag	     => q{},
		  x	     => 0,
		  y	     => 0,
		  z	     => 0,
		  b	     => 0,
		  bx	     => 0,  # |
		  by	     => 0,  #  > crystallographic thermal factors
		  bz	     => 0,  # |
		  valence    => 0,  # intended for Cromer-Mann tables
		  occupancy  => 1,
		  host	     => 1,
		  positions  => [], # filled in by populate method
		  formulas   => [], # filled in by populate method
		  file	     => q{},
		  isite      => 0,  # filled in by populate method
		  in_cell    => 0,
		  stoi       => 0,
		  in_cluster => 0,
		  id	     => 0,
		  ipot	     => 0,
		  color	     => q{},
		  #dopants    => [],
		 );
  my %seen = ();
  my $opt  = Regexp::List->new;
  my $attr_re = $opt->list2re(keys %defaults);
  my %abbrev_table = abbrev keys(%defaults);

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
	carp("\"$key\" is not a valid Xray::Crystal::Site parameter");
	next;
      };
      $k = $abbrev_table{$k};

    ATTR: {
	($k =~ m{(?:formulas|id|positions)}) and do {
	  carp("You may not set the $k attribute of a site by hand$/Use the populate method.$/");
	  last ATTR;
	};

	($k eq "element") and do {
	  my $sym = get_symbol($r_hash->{$key});
	  $sym ||= "--";
	  $sym = ucfirst(lc($sym));
	  $params_of{ident $self}{element} = $sym;
	  $params_of{ident $self}{tag}   ||= $sym;
	  last ATTR;
	};

	($k eq "occupancy") and do {
	  carp("Occupancies must be numbers") if ($r_hash->{$key} !~ m{\A$NUMBER\z});
	  ## occupancy must be between 0 and 1, no carping required
	  my $value = ($r_hash->{$key} < 0) ? 0
	            : ($r_hash->{$key} > 1) ? 1
		    :  $r_hash->{$key};
	  $params_of{ident $self}{occupancy} = $value;
	  last ATTR;
	};

	($k =~ /\Ab[xyz]?/) and do {
	  if ($r_hash->{$key} !~ m{\A$NUMBER\z}) {
	    carp("Thermal parameters must be numbers");
	    last ATTR;
	  };
	  my $value = ($r_hash->{$key} > 0) ? $r_hash->{$key} : 0;
	  $params_of{ident $self}{$k} = $value;
	  last ATTR;
	};

	($k =~ /\A[xyz]\z/) and do {
	  my $value = $r_hash->{$key};
	  $value = $1/$2 if $value =~ m{\A(\d+)/(\d+)\z};
	  if ($value !~ m{\A$NUMBER\z}) {
	    carp("x, y, and z coordinates must be numbers or simple fractions: '$value' set to 0");
	    last ATTR;
	  };
	  $value = $self->canonicalize_coordinate($value);
	  $params_of{ident $self}{$k} = $value;
	  last ATTR;
	};

	## some other possibilities:
	## -- check valence against Cromer-Mann tables
	## -- convert color to an RGB triplet
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
      carp("$type: \"$key\" is not a valid parameter") if (not exists $abbrev_table{$k});
      push @values, $params_of{ident $self}{$abbrev_table{$k}};
    };
    return wantarray ? @values : $values[0];
  };

  sub tag :STRINGIFY {
    my ($self) = @_;
    return $self->get("tag");
  };
  sub ipot :NUMERIFY {
    my ($self) = @_;
    return $self->get("ipot");
  };

  sub canonicalize_coordinate {
    my ($self,$pos) = @_;
    $pos -= int($pos);		# move to first octant
    ($pos += 1) if ($pos < -1*$EPSILON);
    ($pos  = 0) if (abs($pos) < $EPSILON);
  SYM: {				# positions of special symmetry
      if (abs($pos)        < $EPSILON) {($pos = 0);   last SYM;}
      if (abs($pos-0.125)  < $EPSILON) {($pos = 1/8); last SYM;}
      if (abs($pos-0.1666) < $EPSILON) {($pos = 1/6); last SYM;}
      if (abs($pos-0.25)   < $EPSILON) {($pos = 1/4); last SYM;}
      if (abs($pos-0.3333) < $EPSILON) {($pos = 1/3); last SYM;}
      if (abs($pos-0.375)  < $EPSILON) {($pos = 3/8); last SYM;}
      if (abs($pos-0.5)    < $EPSILON) {($pos = 1/2); last SYM;}
      if (abs($pos-0.625)  < $EPSILON) {($pos = 5/8); last SYM;}
      if (abs($pos-0.6666) < $EPSILON) {($pos = 2/3); last SYM;}
      if (abs($pos-0.75)   < $EPSILON) {($pos = 3/4); last SYM;}
      if (abs($pos-0.8333) < $EPSILON) {($pos = 5/6); last SYM;}
      if (abs($pos-0.875)  < $EPSILON) {($pos = 7/8); last SYM;}
      if (abs($pos-1)      < $EPSILON) {($pos = 0);   last SYM;}
    };
    return $pos;
  };


  sub populate {
    my ($self, $cell) = @_;
    croak('usage: $site->populate($cell)') if (ref($cell) !~ m{Cell});

    my ($group, $setting, $bravais, $class) = $cell->get(qw(space_group setting bravais class));
    my ($x, $y, $z, $utag) = $self->get(qw(x y z utag));
    $utag    = "_" . $utag;
    my @list;

    #-------------------------- handle different settings as needed
    my $positions = "positions";
    my $is_ortho = (($class eq "orthorhombic" ) and ($setting));
    my $is_tetr  = (($class eq "tetragonal" )   and ($setting));
				# bravais vector for the //given// symbol
    ($positions = $setting) if ($class eq "monoclinic");
    ($positions = $setting ? $setting : $positions) if ($group =~ m{\Ar}i);
    if (not $positions) {
      my $this = (caller(0))[3];
      croak "Invalid positions specifier in $this";
      return;
    };

    #-------------------------- permute to alternate settings (orthorhombic)
    #                           1..5 |--> [ ba-c, cab, -cba, bca, a-cb ]
    if ($is_ortho) {
    FORWARD: {
	($setting == 1) and do {
	  ( ($x, $y, $z) = (  $y,  $x, -$z) );
	  last FORWARD;
	};
	($setting == 2) and do {
	  ( ($x, $y, $z) = (  $y,  $z,  $x) );
	  last FORWARD;
	};
	($setting == 3) and do {
	  ( ($x, $y, $z) = (  $z,  $y, -$x) );
	  last FORWARD;
	};
	($setting == 4) and do {
	  ( ($x, $y, $z) = (  $z,  $x,  $y) );
	  last FORWARD;
	};
	($setting == 5) and do {
	  ( ($x, $y, $z) = (  $x,  $z, -$y) );
	  last FORWARD;
	};
      }
      ;
    };

    #-------------------------- rotate from F or C settings to P or I
    if ($is_tetr) {
      ($x, $y) = ($x-$y, $x+$y);
    };

    ## ----- evaluate the coordinates safely
    ## see `perldoc Safe' for details
    my $message = <<EOH
Atoms detected tainted data among the crystallography
data for this space group.
This is an emergency!  It means that the crystallography
database has been corrupted and should be reinstalled from
source.
EOH
      ;

    #---------------------------- loop over all symmetry operations
    my $r_data = $cell->group_data;

    foreach my $position (@{ $r_data->{$positions} }) {
      my $i = 0;
      my ($xpos, $ypos, $zpos) = ( $position->[0], $position->[1], $position->[2] );


      ## evaluate each symmetry position in a Safe compartment
      my $cpt = new Safe;
      $ {$cpt->varglob('x')} = $x;
      $ {$cpt->varglob('y')} = $y;
      $ {$cpt->varglob('z')} = $z;

      $ {$cpt->varglob('xx')} = $cpt->reval($xpos);
      $ {$cpt->varglob('yy')} = $cpt->reval($ypos);
      $ {$cpt->varglob('zz')} = $cpt->reval($zpos);

      ($xpos, $ypos, $zpos) = ($ {$cpt->varglob('xx')},
			       $ {$cpt->varglob('yy')},
			       $ {$cpt->varglob('zz')} );




##       foreach ($xpos, $ypos, $zpos) {
## 	## the regex is intended to be an exhaustive list of characters
## 	## found in the symmetry part of the space groups database.
## 	## This is not bomber security as it is possible to, say,
## 	## somehow alias "y56z-3" to "rm -rf ~".  But I think this will
## 	## foil the casual black hat.
## 	($_ =~ /([^-1-6xyzXYZ+\$\/])/) and
## 	  Xray::Crystal::trap_error("$message\nfirst bad character: $1$/", 0);
##       }
##       ;
##       ($xpos, $ypos, $zpos) = map {eval $_} ($xpos, $ypos, $zpos);

      ##print join("  ", $xpos, $ypos, $zpos, $/);
      my @f = @$position;	# store formulas for this position
      map {s/\$//g} @f;		# remove dollar sign
      map {s/([xyz])/$1$utag/g} @f; # append unique tag

      #print join("  ", $x, $y, $z, $/);
      ## $ {$cpt->varglob('xx')} = $cpt->reval($xpos);
      ## $ {$cpt->varglob('yy')} = $cpt->reval($ypos);
      ## $ {$cpt->varglob('zz')} = $cpt->reval($zpos);
      ## ($xpos, $ypos, $zpos) = ($ {$cpt->varglob('xx')},
      ## 			     $ {$cpt->varglob('yy')},
      ## 			     $ {$cpt->varglob('zz')} );
      ## test_safe_return($message, $xpos, $ypos, $zpos);
      ## ----- end of safe evaluation

      my ($xposi, $yposi, $zposi) = ($xpos, $ypos, $zpos);

      #-------------------------- permute back from alt. settings (orthorhombic)
      if ($is_ortho) {
	($setting == 1) and (($xposi, $yposi, $zposi) = ( $yposi, $xposi,-$zposi));
	($setting == 2) and (($xposi, $yposi, $zposi) = ( $zposi, $xposi, $yposi));
	($setting == 3) and (($xposi, $yposi, $zposi) = (-$zposi, $yposi, $xposi));
	($setting == 4) and (($xposi, $yposi, $zposi) = ( $yposi, $zposi, $xposi));
	($setting == 5) and (($xposi, $yposi, $zposi) = ( $xposi,-$zposi, $yposi));
      };
      # need to rectify formulas for orthorhombic settings

      #-------------------------- permute back to F or C settings from P or I
      #($is_tetr) and ($x, $y) = ($x-$y, $x+$y);

      #-------------------------- canonicalize and push onto list
      ($xposi, $yposi, $zposi) = ($self->canonicalize_coordinate($xposi),
				  $self->canonicalize_coordinate($yposi),
				  $self->canonicalize_coordinate($zposi));
      push @list, [$xposi, $yposi, $zposi, @f];

      #-------------------------- do Bravais translations
      while ($i < $#{$bravais}) {
	($xposi, $yposi, $zposi) = ($xpos+$$bravais[$i],
				    $ypos+$$bravais[$i+1],
				    $zpos+$$bravais[$i+2]);
	#------------------------ permute back from alt. settings (orthorhombic)
	if ($is_ortho) {
	BACKWARD: {
	    ($setting == 1) and do {
	      (($xposi, $yposi, $zposi)=( $yposi, $xposi,-$zposi));
	      last BACKWARD;
	    };
	    ($setting == 2) and do {
	      (($xposi, $yposi, $zposi)=( $zposi, $xposi, $yposi));
	      last BACKWARD;
	    };
	    ($setting == 3) and do {
	      (($xposi, $yposi, $zposi)=(-$zposi, $yposi, $xposi));
	      last BACKWARD;
	    };
	    ($setting == 4) and do {
	      (($xposi, $yposi, $zposi)=( $yposi, $zposi, $xposi));
	      last BACKWARD;
	    };
	    ($setting == 5) and do {
	      (($xposi, $yposi, $zposi)=( $xposi,-$zposi, $yposi));
	      last BACKWARD;
	    };
	  }
	  ;
	};

	#-------------------------- canonicalize and push this bravais position
	($xposi, $yposi, $zposi) = ($self->canonicalize_coordinate($xposi),
				    $self->canonicalize_coordinate($yposi),
				    $self->canonicalize_coordinate($zposi));
	my @ff = @f;		# append bravais translation to formulas
	map {$ff[$_] = $f[$_] . " + " . $$bravais[$i+$_]} (0 .. 2);
	push @list, [$xposi, $yposi, $zposi, @ff];
	$i+=3;
      };
    };
    #---------------------------- Weed out repeats.
    my (@form, %seen, @uniq) = ((), (), ());
    foreach my $item (@list) {	#   The Perl Cookbook, 1st edition
      #my @key_parts = map { substr(sprintf("%7.5f", $_), 0, -1) } @$item[0..2];
      my @key_parts = map { substr(sprintf("%6.4f", $_), 0, -1) } @$item[0..2];
      my $key = join(q{}, @key_parts);
      unless ($seen{$key}++) {
	push (@uniq, [@$item[0..2]]);
	push (@form, [@$item[3..5]]);
      };
    };
    #---------------------------- fill in attributes
    $params_of{ident $self}{positions} = [@uniq];
    $params_of{ident $self}{formulas}  = [@form];
    return $self;
  };


};
1;


=head1 NAME

Xray::Crystal::Site - A crystallographic site object


=head1 VERSION

This documentation refers to Ifeffit::Demeter version 0.1.

=head1 SYNOPSIS

  my $site = Xray::Crystal::Site->new();
  $site -> set ({element=>'fe', x=>0.5, y=>0, z=>'1/3'});

=head1 DESCRIPTION


=head1 ATTRIBUTES

=over 4

=item C<element>

The two letter symbol for the chemical species.  As in input, this can
be a two-letter symbol, an element name, or a Z number.  It is stored
as a two-letter symbol using Chemistry::Elements.

=item C<tag>

A character string identifying a unique crystallographic site.

=item C<x>, C<y>, C<z>

The fractional coordinates of the sites.

=item C<b>

The thermal spheroid parameter for the site.

=item C<bx>, C<by>, C<bz>

The thermal ellispoid parameters for the site.

=item C<valence>

The formal valence for the element occupying the site.

=item C<occupancy>

The fractional occupancy of the site.  Dopants are currently
unimplemented.

=item C<host>

This is 1 if the site is a host atom and 0 if it is a dopant.
Currently unimplements

=item C<positions>

An anonymous array of symmetry equivalent sites.  This is filled after
calling the C<populate> method.

=item C<formulas>

An anonymous array of meth expressions describing the placement of the
corresponding equivalent site.  This is filled after calling the
C<populate> method.

=item C<file>

The name of an external file to be used with the site.

=item C<id>

A pseudo-random number assigned by the C<new> method to uniquely
identify the object.

=item C<color>

The color assigned to the site in a ball-and-stick image.

=back

=head1 METHODS

=head1 COERCIONS

tag for stringify

ipot for numerify

=head1 SERIALIZATION AND DESERIALIZATION


=head1 CONFIGURATION AND ENVIRONMENT

See ___ for a description of the configuration system.

=head1 DEPENDENCIES


=head1 BUGS AND LIMITATIONS

Automated indexing currently only works when doing a fit.  If you want
to plot paths before doing a fit, you will need to assign indeces by
hand.

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
