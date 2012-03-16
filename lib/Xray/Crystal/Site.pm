package Xray::Crystal::Site;

=for Copyright
 .
 Copyright (c) 2006-2012 Bruce Ravel (bravel AT bnl DOT gov).
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

use Carp;
use Chemistry::Elements qw(get_symbol get_Z);
use Safe;
use Scalar::Util;
use Const::Fast;
const my $EPSILON  => 0.00001;


use Moose;
use Moose::Util::TypeConstraints;

with 'MooseX::SetGet';

sub _canonicalize_coordinate {
  my ($pos) = @_;
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

subtype 'ZeroToOne'
  => as 'Num'
  => where { ($_ >= 0) and ($_ <= 1) };

# coerce 'ZeroToOne'
#   => from 'Any'
#   => via { _canonicalize_coordinate( $_  ) };

subtype 'Elem'
  => as 'Str'
  => where { get_Z($_) };

has 'element'	  => (is => 'rw', isa => 'Elem',  default => q{},
		      trigger => sub{ my ($self, $new) = @_; $self->tag($new) if not $self->tag});
has 'tag'	  => (is => 'rw', isa => 'Str',  default => q{});
has 'utag'	  => (is => 'rw', isa => 'Str',  default => q{});
has 'x'		  => (is => 'rw', isa => 'Num',  default => 0);
has 'y'		  => (is => 'rw', isa => 'Num',  default => 0);
has 'z'		  => (is => 'rw', isa => 'Num',  default => 0);
# has 'x'		  => (is => 'rw', isa => 'ZeroToOne',  default => 0, -coerce => 1);
# has 'y'		  => (is => 'rw', isa => 'ZeroToOne',  default => 0, -coerce => 1);
# has 'z'		  => (is => 'rw', isa => 'ZeroToOne',  default => 0, -coerce => 1);
has 'b'		  => (is => 'rw', isa => 'Num',  default => 0);
has 'bx'	  => (is => 'rw', isa => 'Num',  default => 0);
has 'by'	  => (is => 'rw', isa => 'Num',  default => 0);
has 'bz'	  => (is => 'rw', isa => 'Num',  default => 0);
has 'valence'	  => (is => 'rw', isa => 'Str',  default => 0);	## -- check valence against Cromer-Mann tables
has 'occupancy'	  => (is => 'rw', isa => 'ZeroToOne',  default => 1);
has 'host'	  => (is => 'rw', isa => 'Bool', default => 1);
has 'positions'	  => (
		      traits    => ['Array'],
		      is        => 'rw',
		      isa       => 'ArrayRef',
		      default   => sub { [] },
		      handles   => {
				    'push_positions'  => 'push',
				    'pop_positions'   => 'pop',
				    'clear_positions' => 'clear',
				   }
		     );
has 'formulas'	  => (
		      traits    => ['Array'],
		      is        => 'rw',
		      isa       => 'ArrayRef',
		      default   => sub { [] },
		      handles   => {
				    'push_formulas'  => 'push',
				    'pop_formulas'   => 'pop',
				    'clear_formulas' => 'clear',
				   }
		     );
has 'file'	  => (is => 'rw', isa => 'Str',  default => q{});
has 'isite'	  => (is => 'rw', isa => 'Int',  default => 0);
has 'in_cell'	  => (is => 'rw', isa => 'Int' , default => 0);
has 'stoi'	  => (is => 'rw', isa => 'Num',  default => 0);
has 'in_cluster'  => (is => 'rw', isa => 'Bool', default => 0);
#has 'id'	  => (is => 'ro', isa => 'Int',  default => 0);
has 'ipot'	  => (is => 'rw', isa => 'Int',  default => 0);
has 'color'	  => (is => 'rw', isa => 'Str',  default => q{});

my %seen = ();



sub populate {
  my ($self, $cell) = @_;
  croak('usage: $site->populate($cell)') if (ref($cell) !~ m{Cell});

  #my ($group, $setting, $bravais, $class) = $cell->get(qw(space_group setting bravais class));
  my $group   = $cell->group;
  my $setting = $cell->group->setting;
  my $class   = $cell->group->class;
  my $bravais = $cell->group->bravais;

  my ($x, $y, $z, $utag) = $self->get(qw(x y z utag));
  ## it would be nice to do this as a coercion up at the level of the
  ## attribute, but this certainly works...
  $self->element(get_symbol($x));
  $self->x(_canonicalize_coordinate($x));
  $self->y(_canonicalize_coordinate($y));
  $self->z(_canonicalize_coordinate($z));
  $utag    = "_" . $utag;
  my @list;

  #-------------------------- handle different settings as needed
  my $positions = "positions";
  my $is_ortho = (($class eq "orthorhombic" ) and ($setting));
  my $is_tetr  = (($class eq "tetragonal" )   and ($setting ne 'positions'));
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
    my $this_setting = ($setting eq "positions") ? 0 : $setting;
  FORWARD: {
      ($this_setting == 1) and do {
	( ($x, $y, $z) = (  $y,  $x, -$z) );
	last FORWARD;
      };
      ($this_setting == 2) and do {
	( ($x, $y, $z) = (  $y,  $z,  $x) );
	last FORWARD;
      };
      ($this_setting == 3) and do {
	( ($x, $y, $z) = (  $z,  $y, -$x) );
	last FORWARD;
      };
      ($this_setting == 4) and do {
	( ($x, $y, $z) = (  $z,  $x,  $y) );
	last FORWARD;
      };
      ($this_setting == 5) and do {
	( ($x, $y, $z) = (  $x,  $z, -$y) );
	last FORWARD;
      };
    };
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
  my $r_data = $cell->group->data;

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
      my $this_setting = ($setting eq "positions") ? 0 : $setting;
      ($this_setting == 1) and (($xposi, $yposi, $zposi) = ( $yposi, $xposi,-$zposi));
      ($this_setting == 2) and (($xposi, $yposi, $zposi) = ( $zposi, $xposi, $yposi));
      ($this_setting == 3) and (($xposi, $yposi, $zposi) = (-$zposi, $yposi, $xposi));
      ($this_setting == 4) and (($xposi, $yposi, $zposi) = ( $yposi, $zposi, $xposi));
      ($this_setting == 5) and (($xposi, $yposi, $zposi) = ( $xposi,-$zposi, $yposi));
    };
    # need to rectify formulas for orthorhombic settings

    #-------------------------- permute back to F or C settings from P or I
    #($is_tetr) and ($x, $y) = ($x-$y, $x+$y);

    #-------------------------- canonicalize and push onto list
    ($xposi, $yposi, $zposi) = (_canonicalize_coordinate($xposi),
				_canonicalize_coordinate($yposi),
				_canonicalize_coordinate($zposi));
    push @list, [$xposi, $yposi, $zposi, @f];

    #-------------------------- do Bravais translations
    while ($i < $#{$bravais}) {
      ($xposi, $yposi, $zposi) = ($xpos+$$bravais[$i],
				  $ypos+$$bravais[$i+1],
				  $zpos+$$bravais[$i+2]);
      #------------------------ permute back from alt. settings (orthorhombic)
      if ($is_ortho and ($setting ne 'positions')) {
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
	};
      };

      #-------------------------- canonicalize and push this bravais position
      ($xposi, $yposi, $zposi) = (_canonicalize_coordinate($xposi),
				  _canonicalize_coordinate($yposi),
				  _canonicalize_coordinate($zposi));
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
  $self->positions([@uniq]);
  $self->formulas([@form]);
  return $self;
};


__PACKAGE__->meta->make_immutable;
1;


=head1 NAME

Xray::Crystal::Site - A crystallographic site object


=head1 VERSION

This documentation refers to Demeter version 0.9.

=head1 SYNOPSIS

  my $site = Xray::Crystal::Site->new(element=>'fe', tag=>'Fe1',
                                      x=>0.5, y=>0, z=>'1/3');

=head1 DESCRIPTION

This is a crystallographic site object.  A cell object creeated with
Xray::Crystal::Cell will be populated by these objects.  Each site is
expanded into a set of positions using the symmetries of the Cell.

=head1 ATTRIBUTES

This uses Moose, so each of these attributes has an associated
accessor by the same name.

Some of these attributes are placeholders for future functionality.

=over 4

=item C<element>

The two letter symbol for the chemical species.  As in input, this can
be a two-letter symbol, an element name, or a Z number.  It is stored
as a two-letter symbol using Chemistry::Elements.

=item C<tag>

A character string identifying a unique crystallographic site.

=item C<x>, C<y>, C<z>

The fractional coordinates of the sites.  Note that these must be
numbers.  It is up to the caller to evaluate a math expression.

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
Currently unimplemented.

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

This uses Moose, so each attributes has an accessor method of the same
name.

=over 4

=item C<get>

This a wrapper around the normal Moose accessors.

  ($x, $y, $z) = $site -> get(qw(x y z));

=item C<populate>

This is the main workhorse of this class.  This is called repeatedly
when a Cell object is expanded to populate the entire unit cell.

  $site -> populate($cell);

=back


=head1 CONFIGURATION AND ENVIRONMENT

There is nothing configurable and no environment variables are used.

=head1 DEPENDENCIES

  Moose and Moose::Util::TypeConstraints
  Scalar::Util
  Chemistry::Elements
  Carp
  Safe
  Const::Fast

=head1 BUGS AND LIMITATIONS

Please report problems to Bruce Ravel (bravel AT bnl DOT gov)

Patches are welcome.

=head1 AUTHOR

Bruce Ravel (bravel AT bnl DOT gov)

http://cars9.uchicago.edu/~ravel/software/


=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2012 Bruce Ravel (bravel AT bnl DOT gov). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
