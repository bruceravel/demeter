## Time-stamp: <16-Nov-2009 08:17:50 bruce>
######################################################################
##  This module is copyright (c) 2005-2008 Bruce Ravel
##  <bravel AT bnl DOT gov>
##  http://bruceravel.github.io/demeter/exafs/
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

package Xray::Scattering::WaasKirf;

use strict;
use warnings;
use version;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);

require Exporter;

@ISA = qw(Exporter AutoLoader);
@EXPORT_OK = qw();

use Chemistry::Elements qw(get_symbol);
use File::Spec;
use Storable;

$VERSION = version->new("3.0.0");

my $dbfile = File::Spec->catfile($Xray::Scattering::data_dir, "waaskirf.db");
my $r_waaskirf = retrieve($dbfile);

sub _identify_self {
  my @caller = caller;
  use File::Basename qw(dirname);
  return dirname($caller[1]);
};

sub tabulated {
  shift;
  my $sym = lc($_[0]);
  return exists $$r_waaskirf{$sym} ? ucfirst($sym) : 0;
};
{
  no warnings 'once';
  # alternate names
  *has = \ &tabulated;
};


#-----------------------------------------------------------------------
#  the formula for reconstruction of f0 is:
#            5
#   f0(s) = sum [ ai*exp(-bi*s^2) ] + c ,    s = sin(theta) / lambda
#           i=1                            ==> (lambda*s / 2pi) is the
#                                               momentum transfer
#-----------------------------------------------------------------------
#  coef: 1..11 corresponding to a1,a2,a3,a4,a5,c,b1,b2,b3,b4,b5
#-----------------------------------------------------------------------
#      call spcing(qvect,cell,d)
#      s      = one / (2*d)

## given a symbol and the d-spacing, return the Thomson scattering (F0).  The
## symbol is one of the valence state symbols from the Waaskirf-Kirfel tables,
## or a Z number, or a normal element symbol, or the full name of the element.
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
  $sym = substr($sym, 0, 2) if (not exists $$r_waaskirf{$sym});
  $sym = substr($sym, 0, 1) if (not exists $$r_waaskirf{$sym});
  exists $$r_waaskirf{$sym} or return 0; # oops! not a symbol

  my $sum = $r_waaskirf->{$sym}->[5];
  foreach my $i (0..4) {
    $sum += $r_waaskirf->{$sym}->[$i] *
      exp(-1 * $s * $r_waaskirf->{$sym}->[$i+6]);
  };
  return $sum;
};

sub get_coefficients {
  shift;
  my $sym = lc($_[0]);
  my @null = (0,0,0,0,0,0,0,0,0,0,0);
  return @null if ($sym =~ /nu/i);		      # "null"
  return @null if ($sym =~ /^\s*$/i);		      # blank
  ($sym =~ /^\d+$/) and $sym = lc(get_symbol($sym));  # a number
  (length($sym)>4)  and $sym = lc(get_symbol($sym));  # an element name
  ## fall back to the element if the ion isn't tabulated
  $sym = substr($sym, 0, 2) if (not exists $$r_waaskirf{$sym});
  $sym = substr($sym, 0, 1) if (not exists $$r_waaskirf{$sym});
  exists $$r_waaskirf{$sym} or return @null;	      # oops! not a symbol
  return @{$$r_waaskirf{$sym}};
};



1;

__END__

=head1 NAME

Xray::Scattering::WassKirf - Perl interface to the Waaskirf-Kirfel tables

=head1 SYNOPSIS

  use Xray::Scattering;
  Xray::Scattering->load('WaasKirf');
  $fnot = Xray::Scattering->get_f($symb, $d);

=head1 DESCRIPTION

This module provides a functional interface to the Waasmaier-Kirfel tables of
coefficients for calculating the Thomson (kinematical) scattering factors of
the elements and common valence states.  The coefficients are stored
externally in the waaskirf.db database file.  The coefficients are for an
Aikman expansion, which is of this form:

          5
    f0 = sum [ ai*exp(-bi*s^2) ] + c
         i=1

Thus there are 11 coefficients for each of the 211 tabulated
element/valence symbols.

C<s> is C<sin(theta)/lambda>.  C<(lambda*s)/2pi> is the momentum transfer.
C<s> is simply related to the crystal d-spacing by C<s=1/2d>.

The reference for these tables is "New Analytical Scattering Factor
Functions for Free Atoms and Ions for Free Atoms and Ions",
D. Waasmaier & A. Kirfel, Acta Cryst. (1995) A51, pp. 416-413.
[doi:10.1107/S0108767394013292] These data, computed for neutral atoms
and ions, are valid for the full range of sin(theta)/lambda from 0.0
to 6.0 A-1.

The actual data used in the W-K Aikman expansion can be found in a few
places on the web.  Here is where I obtained the file used with this
module: http://ftp.esrf.fr/pub/scisoft/xop/DabaxFiles/f0_WaasKirf.dat



=head1 METHODS

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

This returns the 11 element list containing the coefficients for the
given symbol.

   @coefs = Xray::Scattering->get_coefficients($symb)

This returns a1,b1,a2,b2,a3,b3,a4,b4,c.

If you ask for a valence state that is not in the table but for an element
whose 0+ state is in the table, this method returns the coefficients for
the 0 valent atom.

=item C<has>

This is a test of whether a given symbol is tabulated in the Waasmaier-Kirfel
table.  It returns the symbol itself if found in the table or 0 if it is not
in the table.

  $symb = "Ce3+";
  $is_tabulated = Xray::Scattering->has($symb);

=back

=head1 ELEMENTS AND VALENCE STATES

The following is a list of symbols for the tabulated elements and
valence states.  The final two are ways of refering to an empty site
(i.e. a null or blank atom).

  H     H1-   He    Li    Li1+    Be    Be2+   B     C
  Cval  N     O     O1-   O2-     F     F1-    Ne    Na
  Na1+  Mg    Mg2+  Al    Al3+    Si    Siva   Si4+  P
  S     Cl    Cl1-  Ar    K       K1+   Ca     Ca2+  Sc
  Sc3+  Ti    Ti2+  Ti3+  Ti4+    V     V2+    V3+   V5+
  Cr    Cr2+  Cr3+  Mn    Mn2+    Mn3+  Mn4+   Fe    Fe2+
  Fe3+  Co    Co2+  Co3+  Ni      Ni2+  Ni3+   Cu    Cu1+
  Cu2+  Zn    Zn2+  Ga    Ga3+    Ge    Ge4+   As    Se
  Br    Br1-  Kr    Rb    Rb1+    Sr    Sr2+   Y     Zr
  Zr4+  Nb    Nb3+  Nb5+  Mo      Mo3+  Mo5+   Mo6+  Tc
  Ru    Ru3+  Ru4+  Rh    Rh3+    Rh4+  Pd     Pd2+  Pd4+
  Ag    Ag1+  Ag2+  Cd    Cd2+    In    In3+   Sn    Sn2+
  Sn4+  Sb    Sb3+  Sb5+  Te      I     I1-    Xe    Cs
  Cs1+  Ba    Ba2+  La    La3+    Ce    Ce3+   Ce4+  Pr
  Pr3+  Pr4+  Nd    Nd3+  Pm      Pm3+  Sm     Sm3+  Eu
  Eu2+  Eu3+  Gd    Gd3+  Tb      Tb3+  Dy     Dy3+  Ho
  Ho3+  Er    Er3+  Tm    Tm3+    Yb    Yb2+   Yb3+  Lu
  Lu3+  Hf    Hf4+  Ta    Ta5+    W     W6+    Re    Os
  Os4+  Ir    Ir3+  Ir4+  Pt      Pt2+  Pt4+   Au    Au1+
  Au3+  Hg    Hg1+  Hg2+  Tl      Tl1+  Tl3+   Pb    Pb2+
  Pb4+  Bi    Bi3+  Bi5+  Po      At    Rn     Fr    Ra
  Ra2+  Ac    Ac3+  Th    Th4+    Pa    U      U3+   U4+
  U6+   Np    Np3+  Np4+  Np6+    Pu    Pu3+   Pu4+  Pu6+
  Am    Cm    Bk    Cf    ' '     Nu


=head1 AUTHOR

  Bruce Ravel, bravel AT bnl DOT gov
  http://bruceravel.github.io/demeter/exafs/

=cut
