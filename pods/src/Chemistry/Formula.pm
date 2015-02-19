######################################################################
##  This module is copyright (c) 2001-2015 Bruce Ravel
##  http://bruceravel.github.io/home
##  http://bruceravel.github.io/demeter
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
## Code:

package Chemistry::Formula;

require Exporter;

@ISA       = qw(Exporter);
@EXPORT    = qw(parse_formula);
@EXPORT_OK = qw(formula_data);

use strict;
use warnings;
use version;

use Regexp::Common;
use Const::Fast;
use File::Spec;
use vars qw(@ISA $VERSION $install_dir);
$VERSION  = version->new("3.0.1");
$install_dir = &identify_self;

const my $NUMBER => $RE{num}{real};

my $elem_match = '([BCFHIKNOPSUVWY]|A[cglrstu]|B[aeir]|C[adelorsu]|Dy|E[ru]|F[er]|G[ade]|H[efgo]|I[nr]|Kr|L[aiu]|M[gno]|N[abdeip]|Os|P[abdmortu]|R[abehnu]|S[bceimnr]|T[abcehilm]|Xe|Yb|Z[nr])';
#my $num_match  = '\d+\.?\d*|\.\d+';

my $debug = 0;
my ($ok, $count);




=for Explanation: (parse_formula)
   input: string and reference to a hash
   return: 1 if string was parsed, 0 if an error was encountered
   this throws an error after the *first* error encountered
   .
   To pre-process the string: (1) remove spaces and underscores --
   also remove $ and curly braces in an attempt to deal with TeX, (2)
   translate square braces to parens, (3) remove /sub #/ in an attempt
   to deal with INSPEC (4) count number of open and close parens

=cut

sub parse_formula {
  my $in = $_[0];
  $count = $_[1];
  $ok    = 1;
  ## string preprocessing:
  $in    =~ s{[ \t_\$\{\}]+}{}g;  # (1)
  $in    =~ tr{[]}{()};		  # (2)
  $in    =~ s{/sub(\d+)/}{$1}g;	  # (3), note that spaces have already
                                  # been removed
  my @chars = split(//, $in);	  #
  my $open  = grep /\(/g, @chars; #  (4)
  my $close = grep /\)/g, @chars; #
  if ($open != $close) {
    $$count{error} =  "$open opening and $close closing parentheses.\n";
    return 0;
  } else {
    &parse_segment($in, 1); # this fills the %count hash
    ## &normalize_count;
    return $ok;
  };
};

=for Explanation: (parse_segment)
   This works by recursion.  Pluck off the first segment of the
   string, interpret that segment, and pass the rest of the string to
   this routine for further processing.
   .
   So, for Pb(TiO3)2, interpret Pb and recurse (TiO3)2.
   Then recurse TiO3 with a multiplier of 2.

=cut

sub parse_segment {
  my ($in, $mult) = @_;
  return unless $ok;
  return if ($in =~ /^\s*$/);
  printf(":parse_segment: \"%s\" with multiplier %d\n", $in, $mult) if ($debug);
  my ($end, $scale) = (0, 1);
  $end = ($in =~ /\(/g) ? pos($in) : length($in)+1; # look for next open paren
  if ($end > 1) {
    unit(substr($in, 0, $end-1), $mult);
    --$end;
  } else {
    matchingbrace($in);
    $end = pos($in);
    if (substr($in, $end) =~ /^($NUMBER)/o) { # handle number outside parens
      $scale = $1;
      $end += length($1);
      pos($in) = $end;
      parse_segment(substr($in, 1, $end-2-length($1)), $mult*$scale);
    } else {
      parse_segment(substr($in, 1, $end-2), $mult*$scale);
    };
  };
  return unless $ok; # parse remaining bit after last paren
  ($end < length($in)) and parse_segment(substr($in, $end), $mult);
};


## interpret an unparenthesized segment
sub unit {
  my ($string, $multiplier) = @_;
  while ($string) {
    print ":unit: ", $string, $/ if ($debug);
    if ($string =~ /^([A-Z][a-z]?)/) {
      my $el = $1;
      unless ($el =~ /^($elem_match)$/o) {
	$$count{error}  = "\"$el\" is not a valid element symbol\n";
	print ":unit: ", $$count{error}, $/ if ($debug);
	$ok = 0;
	return;
      };
      $string = substr($string, length($el));
      if ($string =~ /^($NUMBER)/o) {
	$$count{$el} += $1*$multiplier;
	$string = substr($string, length($1));
      } else {
	$$count{$el} += $multiplier;
      };
    } else {
      $$count{error}  =
	"\"$string\" begins with something that is not an element symbol\n";
      $$count{error} .= "\telements must be first letter capitalized\n";
      print ":unit: ", $$count{error}, $/ if ($debug);
      $ok = 0;
      return;
    };
  };
};

## Swiped from C::Scan, found on CPAN, and written (I think) by
## Hugo van der Sanden (hv@crypt0.demon.co.uk)
sub matchingbrace {
  # pos($_[0]) is after the opening brace now
  my $n = 0;
  while ($_[0] =~ /([\{\[\(])|([\]\)\}])/g) {
    $1 ? $n++ : $n-- ;
    return 1 if $n < 0;
  }
  # pos($_[0]) is after the closing brace now
  return;				# false
}


##
## sub normalize_count {
##   my $sum = 0;
##   map { $sum += $$count{$_} } (keys %$count);
##   map { $$count{$_} /= $sum } (keys %$count);
## };


sub identify_self {
  my @caller = caller;
  use File::Basename qw(dirname);
  return dirname($caller[1]);
};


sub formula_data {
  my ($formula, $density) = @_;
  while (<DATA>) {
    next if (/^\s*$/);
    next if (/^\s*\#/);
    chomp;
    my @list = (split(/\|/, $_));
    foreach (0..2) {
      $list[$_] =~ s/^\s+//;
      $list[$_] =~ s/\s+$//;
    };
    $$formula{$list[0]} = $list[1];
    $$density{$list[0]} = $list[2];
  };
  #close FORMULA;
};



=head1 NAME

Chemistry::Formula - Enumerate elements in a chemical formula

=head1 SYNOPSIS

   use Chemistry::Formula qw(parse_formula);
   parse_formula('Pb (H (TiO3)2 )2 U [(H2O)3]2', \%count);

That is obviously not a real compound, but it demonstrates the
capabilities of the routine.  This returns

  %count = (
	    'O' => 18,
	    'H' => 14,
	    'Ti' => 4,
	    'U' => 1,
	    'Pb' => 1
	   );

=head1 DESCRIPTION

This module provides a function which parses a string containing a
chemical formula and returns the number of each element in the string.
It can handle nested parentheses and square brackets and correctly
computes stoichiometry given numbers outside the (possibly nested)
parentheses.

No effort is made to evaluate the chemical plausibility of the
formula.  The example above parses just fine using this module, even
though it is clearly not a viable compound.  Charge balancing, bond
valence, and so on is beyond the scope of this module.

Only one function is exported, C<parse_formula>.  This takes a string
and a hash reference as its arguments and returns 0 or 1.

    $ok = parse_formula('PbTiO3', \%count);

If the formula was parsed without trouble, C<parse_formula> returns
1. If there was any problem, it returns 0 and $count{error} is filled
with a string describing the problem.  It throws an error afer the
B<first> error encountered without testing the rest of the string.

If the formula was parsed correctly, the %count hash contains element
symbols as its keys and the number of each element as its values.

Here is an example of a program that reads a string from the command
line and, for the formula unit described in the string, writes the
weight and absorption in barns.

    use Data::Dumper;
    use Xray::Absorption;
    use Chemistry::Formula qw(parse_formula);

    parse_formula($ARGV[0], \%count);

    print  Data::Dumper->Dump([\%count], [qw(*count)]);
    my ($weight, $barns) = (0,0);
    foreach my $k (keys(%$count)) {
      $weight +=
	Xray::Absorption -> get_atomic_weight($k) * $count{$k};
      $barns  +=
	Xray::Absorption -> cross_section($k, 9000) * $count{$k};
    };
    printf "This weighs %.3f amu and absorbs %.3f barns at 9 keV.\n",
      $weight, $barns;

Pretty simple.

The parser is not brilliant.  Here are the ground rules:

=over 4

=item 1.

Element symbols must be first letter capitalized.

=item 2.

Whitespace is unimportant -- it will be removed from the string.  So
will dollar signs, underscores, and curly braces (in an attempt to
handle TeX).  Also a sequence like this: '/sub 3/' will be converted
to '3' (in an attempt to handle INSPEC).

=item 3.

Numbers can be integers or floating point numbers.  Things like 5,
0.5, 12.87, and .5 are all acceptible, as is exponential notation like
1e-2.  Note that exponential notation must use a leading number to
avoid confusion with element symbols.  That is, 1e-2 is ok, but e-2 is
not.

=item 4.

Uncapitalized symbols or unrecognized symbols will flag an error.

=item 5.

An error will be flagged if the number of open parens is different
from the number of close parens.

=item 6.

An error will be flagged if any unusual symbols are found in the
string.

=back

=head1 ACKNOWLEDGMENTS

This was written at the suggestion of Matt Newville, who tested early
versions.

The routine C<matchingbrace> was swiped from the C::Scan module, which
can be found on CPAN.  C::Scan is maintained by Hugo van der Sanden.

=head1 AUTHOR

Bruce Ravel, L<http://bruceravel.github.io/home>

http://bruceravel.github.io/demeter/

SVN repository: http://cars9.uchicago.edu/svn/libperlxray/


=cut


1;

__DATA__
######################################################################
##
##  This file contains formula and density data used by
##  Chemistry::Formula.  Please feel free to add to this file and to
##  contribute your additions back to the author:
##    Bruce Ravel
##    http://bruceravel.github.io/home
##    http://bruceravel.github.io/demeter/
##
######################################################################
##
## This file is a very simple database.  (1) Blank lines or lines
## beginning with a hash (#) are ignored.  (2) Entries contain three
## fields, separated by a vertical bar (|).  The first field is the
## common name of the material.  The second field is the chemical
## formula, written according to the rules of Chemistry::Formula.  The
## third field is the density of the material.
##
## The materials chosen in this file are materials of interest to the
## synchrotron scientist.
##
## Many of these materials were swiped from a list provided by Erik
## Gullikson at Berkeley's center for X-Ray Optics.
##

# Name          |  Formula        | Density (g/cm^3)

  Water         |  H2O            | 1
  Lead          |  Pb             | 11.34
  Aluminum      |  Al             | 2.72
  Kapton        |  C22 H10 O4 N2  | 1.42
  Lead Titanate |  PbTiO3         | 8.06
  Nitrogen      |  N              | 0.00125
  Argon         |  Ar             | 0.001784
  Helium        |  He             | 0.00009
  Neon          |  Ne             | 0.000905
  Krypton       |  Kr             | 0.00374
  Xenon         |  Xe             | 0.00588
  Air           |  (N2)0.78 (O2)0.21 (CO2)0.03 Ar0.01 Kr0.000001 Xe0.0000009 | 0.0013
  Carbon (Diamond)   |  C              | 3.51
  Carbon (Graphite)  |  C              | 2.25
  Boron Nitride |  BN             | 2.29
  YAG           |  Y3 Al5 O12     | 4.56
## swiped from Gullikson
  Sapphire      |  Al2O3          | 3.97
  Polymide      |  C22 H10 N2 O5  | 1.43
  Polypropylene |  C3H6           | 0.90
  PMMA          |  C5 H8 O2       | 1.19
  Polycarbonate |  C16 H14 O3     | 1.2
  Kimol         |  C16 H14 O3     | 1.2
  Mylar         |  C10 H8 O4      | 1.4
  Teflon        |  C2F4           | 2.2
  Parylene-C    |  C8 H7 Cl       | 1.29
  Parylene-N    |  C8H8           | 1.11
  Fluorite      |  CaF2           | 3.18
  Mica          |  K Al3 Si3 O12 H2   | 2.83
  Salt          |  NaCl           | 2.165
  SiO2 (Silica) |  SiO2           | 2.2
  SiO2 (Quartz) |  SiO2           | 2.65
  Rutile        |  TiO2           | 4.26
  ULE           |  Si0.925 Ti0.075 O2 | 2.205
  Zerodur       |  Si0.56 Al0.5 P0.16 Li0.04 Ti0.02 Zr0.02 Zn0.03 O2.46 | 2.53
## metals
  Beryllium     |  Be             | 1.85
  Copper        |  Cu             | 8.94
  Molybdenum    |  Mo             | 10.22
  Iron          |  Fe             | 7.86
  Zinc          |  Zn             | 7.14
  Silicon       |  Si             | 2.33
  Gold          |  Au             | 19.37
  Silver        |  Ag             | 10.5
  Platinum      |  Pt             | 21.37
  Tungsten      |  W              | 19.3
  Tantalum      |  Ta             | 16.6
## solvents
  Alcohol (Ethyl)    |  C2H5OH         | 0.789
  Acetone            |  C3H6O          | 0.790
  Alcohol (Methyl)   |  CH3OH          | 0.792
  Alcohol (Propyl)   |  C3H8O          | 0.804
  Toluene            |  C7H8           | 0.867
  Xylene             |  C6H4(CH3)2     | 0.844
