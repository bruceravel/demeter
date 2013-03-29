## Time-stamp: <16-Nov-2009 08:17:52 bruce>
######################################################################
##  This module is copyright (c) 1998-2008 Bruce Ravel
##  <bravel AT bnl DOT gov>
##  http://bruceravel.github.com/demeter/exafs/
##
## -------------------------------------------------------------------
##     All rights reserved. This program is free software; you can
##     redistribute it and/or modify it under the same terms as Perl
##     itself.
##
##     This program is distributed in the hope that it will be useful,
##     but WITHOUT ANY WARRANTY; without even the implied warranty of
##     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
##     Artistic License for more details.
## -------------------------------------------------------------------
######################################################################
## $Id: CromerMann.pm,v 1.3 1999/06/11 22:19:59 bruce Exp $
######################################################################
## Code:

package Xray::Scattering::CromerMann;

use strict;
use warnings;
use version;

use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);

require Exporter;

@ISA = qw(Exporter AutoLoader);
# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.
@EXPORT_OK = qw(get_f get_valence in_CromerMann get_CromerMann_coefficients);

# Preloaded methods go here.

use Storable;
use Chemistry::Elements qw(get_symbol);
use File::Spec;

$VERSION = version->new("3.0.0");

my $dbfile = File::Spec->catfile($Xray::Scattering::data_dir, "cromann.db");
my $r_cromann = retrieve($dbfile);

sub _identify_self {
  my @caller = caller;
  use File::Basename qw(dirname);
  return dirname($caller[1]);
};

sub tabulated {
  my $sym = lc($_[0]);
  return exists $$r_cromann{$sym} ? ucfirst($sym) : 0;
};
{
  no warnings 'once';
  # alternate names
  *has = \ &tabulated;
};

#-----------------------------------------------------------------------
#  the formula for reconstruction of f0 is:
#            4
#   f0(s) = sum [ ai*exp(-bi*s^2) ] + c ,    s = sin(theta) / lambda
#           i=1                            ==> (lambda*s / 2pi) is the
#                                               momentum transfer
#-----------------------------------------------------------------------
#  coef: 1..9 corresponding to a1,b1,a2,b2,a3,b3,a4,b4,c
#-----------------------------------------------------------------------
#      call spcing(qvect,cell,d)
#      s      = one / (2*d)

## given a symbol and the d-spacing, return the Thomson scattering
## (F0).  The symbol is one of the valence state symbols from the
## Cromer-Mann tables, or a Z number, or a normal element symbol, or
## the full name of the element.
sub get_f {
  shift;
  my $sym = lc($_[0]);
  my $s   = (1/(2*$_[1]))**2;

  ## a few special cases
  return 0 if ($sym =~ /nu/i);			     # "null"
  return 0 if ($sym =~ /^\s*$/i);		     # blank
  ($sym =~ /^\d+$/) and $sym = lc(get_symbol($sym)); # a number
  (length($sym)>4)  and $sym = lc(get_symbol($sym)); # an element name
  ## fall back to the element if the ion isn't tabulated
  $sym = substr($sym, 0, 2) if (not exists $$r_cromann{$sym});
  $sym = substr($sym, 0, 1) if (not exists $$r_cromann{$sym});
  exists $$r_cromann{$sym} or return 0; # oops! not a symbol

  my $sum = $r_cromann->{$sym}->[8];
  foreach my $i (0..3) {
    $sum += $r_cromann->{$sym}->[2*$i] *
      exp(-1 * $s * $r_cromann->{$sym}->[2*$i+1]);
  };
  return $sum;
};

sub get_coefficients {
  shift;
  my $sym = lc($_[0]);
  my @null = (0,0,0,0,0,0,0,0,0);
  return @null if ($sym =~ /nu/i);		      # "null"
  return @null if ($sym =~ /^\s*$/i);		      # blank
  ($sym =~ /^\d+$/) and $sym = lc(get_symbol($sym));  # a number
  (length($sym)>4)  and $sym = lc(get_symbol($sym));  # an element name
  ## fall back to the element if the ion isn't tabulated
  $sym = substr($sym, 0, 2) if (not exists $$r_cromann{$sym});
  $sym = substr($sym, 0, 1) if (not exists $$r_cromann{$sym});
  exists $$r_cromann{$sym} or return @null;	      # oops! not a symbol
  return @{$$r_cromann{$sym}};
};


1;

__END__

=head1 NAME

Xray::Scattering::CromerMann - Perl interface to Thomspon scattering factors

=head1 SYNOPSIS

  use Xray::Scattering;
  Xray::Scattering->load('CroMann');
  $fnot = Xray::Scattering->get_f($symb, $d);

=head1 DESCRIPTION

This module provides a functional interface to the Cromer-Mann table
of coefficients for calculating the Thomson (kinematical) scattering
factors of the elements and common valence states.  The coefficients
are stored externally in the cromann.db database file.  The
coefficients are for an Aikman expansion, which is of this form:

          4
    f0 = sum [ ai*exp(-bi*s^2) ] + c
         i=1

Thus there are 9 coefficients for each of the 213 tabulated
element/valence symbols.

C<s> is C<sin(theta)/lambda>.  C<(lambda*s)/2pi> is the momentum
transfer.  C<s> is simply related to the crystal d-spacing by
C<s=1/2d>.

The data for these tables can be found in Volume C of the
International Tables of Crystallography, ed. A.J.C. Wilson, published
by IUCr and Kluwer Academic Publishers (1992).  The table starts on
page 500 and a discussion can be found on page 487.

These tables are known to be inaccurate, particularly at high angles.
This module is a toy.  It is suitable for a student or for the sort of
quick-n-dirty crystallographic hackery that the author indulges in.



=head1 CLASS METHODS

=over 4

=item C<get_f>

This function calculates the Thomson scattering for a given symbol
and d-spacing.  The Thomson scattering depends only on the momentum
transfer.  The d-spacing of the scattering planes is a closely related
quantity and is easily calculated from the crystal structure, see
L<Xtal.pm>.

  $symb = "Ce3+";
  $fnot = Xray::Scattering->get_f($symb, $d);

If the symbol cannot be found in the table, C<get_f> returns 0.  It
also returns 0 when C<$symbol> consists of whitespace or is "null" or
"nu".  If C<$symbol> is a number or the name of an element, then it
assumes you want the Thomson scattering for the neutral element.  The
absolute value of C<$d_spacing> is used by this function.

If you ask for a valence state that is not in the table but for an element
whose 0+ state is in the table, this method returns the scattering factor for
the 0 valent atom.

=item C<get_coefficients>

This returns the 9 element list containing the coefficients for the
given symbol.

   @coefs = Xray::Scattering->get_coefficients($elem)

Returns the array a1,b1,a2,b2,a3,b3,a4,b4,c.

If you ask for a valence state that is not in the table but for an element
whose 0+ state is in the table, this method returns the coefficients for
the 0 valent atom.

=item C<has>

This is a test of whether a given symbol is tabulated in the
Cromer-Mann table.  It returns the symbol itself if found in the
table or 0 if it is not in the table.

  $symb = "Ce3+";
  $is_tabulated = Xray::Scattering->has($symb);

=back

=head1 ELEMENTS AND VALENCE STATES

The following is a list of symbols for the tabulated elements and
valence states.  The final two are ways of refering to an empty site
(i.e. a null or blank atom).

      H      H.     H1-    He     Li     Li1+   Be
      Be2+   B      C      C.     N      O      O1-
      F      F1-    Ne     Na     Na1+   Mg     Mg2+
      Al     Al3+   Si     Si.    Si4+   S      P
      Cl     Cl1-   Ar     K      K1+    Ca     Ca2+
      Sc     Sc3+   Ti     Ti2+   Ti3+   Ti4+   V
      V2+    V3+    V5+    Cr     Cr2+   Cr3+   Mn
      Mn2+   Mn3+   Mn4+   Fe     Fe2+   Fe3+   Co
      Co2+   Co3+   Ni     Ni2+   Ni3+   Cu     Cu1+
      Cu2+   Zn     Zn2+   Ga     Ga3+   Ge     Ge4+
      As     Se     Br     Br1-   Kr     Rb     Rb1+
      Sr     Sr2+   Y      Y3+    Zr     Zr4+   Nb
      Nb3+   Nb5+   Mo     Mo3+   Mo5+   Mo6+   Tc
      Ru     Ru3+   Ru4+   Rh     Rh3+   Rh4+   Pd
      Pd2+   Pd4+   Ag     Ag1+   Ag2+   Cd     Cd2+
      In     In3+   Sn     Sn2+   Sn4+   Sb     Sb3+
      Sb5+   Te     I      I1-    Xe     Cs     Cs1+
      Ba     Ba2+   La     La3+   Ce     Ce3+   Ce4+
      Pr     Pr3+   Pr4+   Nd     Nd3+   Pm     Pm3+
      Sm     Sm3+   Eu     Eu2+   Eu3+   Gd     Gd3+
      Tb     Tb3+   Dy     Dy3+   Ho     Ho3+   Er
      Er3+   Tm     Tm3+   Yb     Yb2+   Yb3+   Lu
      Lu3+   Hf     Hf4+   Ta     Ta5+   W      W6+
      Re     Os     Os4+   Ir     Ir3+   Ir4+   Pt
      Pt2+   Pt4+   Au     Au1+   Au3+   Hg     Hg1+
      Hg2+   Tl     Tl1+   Tl3+   Pb     Pb2+   Pb4+
      Bi     Bi3+   Bi5+   Po     At     Rn     Fr
      Ra     Ra2+   Ac     Ac3+   Th     Th4+   Pa
      U      U3+    U4+    U6+    Np     Np3+   Np4+
      Np6+   Pu     Pu3+   Pu4+   Pu6+   Am     Cm
      Bk     Cf     O2-.   ' '    Nu



=head1 AUTHOR

  Bruce Ravel, bravel AT bnl DOT gov
  http://bruceravel.github.com/demeter/exafs/

=cut
