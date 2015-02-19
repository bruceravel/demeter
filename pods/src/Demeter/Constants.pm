package Demeter::Constants;

use strict;
#use Encode;
use base qw( Exporter );
our @EXPORT_OK = qw($PI $ETOK $HBARC $HC $HBAR $R2D
		    $NUMBER $INTEGER $SEPARATOR $ELEMENT $FEFFNOTOK
		    $NULLFILE $ENDOFLINE $CTOKEN $STATS
		    $EPSILON2 $EPSILON3 $EPSILON4 $EPSILON5 $EPSILON6 $EPSILON7
		  );
our %EXPORT_TAGS = (all     => [qw($PI $ETOK $HBARC $HC $HBAR $R2D
				   $EPSILON2 $EPSILON3 $EPSILON4 $EPSILON5 $EPSILON6 $EPSILON7
				   $NUMBER $INTEGER $SEPARATOR $ELEMENT $FEFFNOTOK
				   $NULLFILE $ENDOFLINE $CTOKEN $STATS
				 )],
		    numbers => [qw($PI $ETOK $HBARC $HC $R2D
				   $EPSILON2 $EPSILON3 $EPSILON4 $EPSILON5 $EPSILON6 $EPSILON7
				 )],
		    regexps => [qw($NUMBER $INTEGER $SEPARATOR $ELEMENT $FEFFNOTOK)],
		    strings => [qw($NULLFILE $ENDOFLINE $CTOKEN $STATS)],
		   );

use Const::Fast;
use Regexp::Common;


const our $PI        => 4*atan2(1,1);
const our $ETOK      => 0.262468292;
const our $HBARC     => 1973.27053324;
const our $HC        => 12398.61;
const our $HBAR      => 4.135667516E-15;
const our $R2D       => 57.29577951;

const our $NUMBER    => $RE{num}{real};
const our $INTEGER   => $RE{num}{int};
const our $SEPARATOR => '[ \t]*[ \t=,][ \t]*';
const our $ELEMENT   => qr/\b([bcfhiknopsuvwy]|a[cglmrstu]|b[aehikr]|c[adeflmorsu]|dy|e[rsu]|f[emr]|g[ade]|h[aefgos]|i[nr]|kr|l[airu]|m[dgnot]|n[abdeiop]|os|p[abdmortu]|r[abefhnu]|s[bcegimnr]|t[abcehilm]|xe|yb|z[nr])\b/;
const our $FEFFNOTOK => qr{[^-a-zA-Z0-9_.]};


const our $NULLFILE  => '@&^^null^^&@';
const our $ENDOFLINE => $/;
const our $CTOKEN    => '+';
const our $STATS     => "n_idp n_varys chi_square chi_reduced r_factor data_total";
#const our $STATS_IFEFFIT => "epsilon_k epsilon_r";


const our $EPSILON2 => 1e-2;
const our $EPSILON3 => 1e-3;
const our $EPSILON4 => 1e-4;
const our $EPSILON5 => 1e-5;
const our $EPSILON6 => 1e-6;
const our $EPSILON7 => 1e-7;


1;

=head1 NAME

Demeter::Constants - A library of constants

=head1 VERSION

This documentation refers to Demeter version 0.9.21.

=head1 SYNOPSIS

This provides a library of constants so as to avoid redefining then
over and over.

  use Demeter::Constants qw(:all);

or

  use Demeter::Constants qw($NUMBER);

=head1 DESCRIPTION

This collects all the commonly defined constants into one place.
Please note that this exports B<variables> into your module's
namespace.  This is a against good practice, but is a huge
convenience, they are all upper case, and I am telling you about it!

The C<:all> tag can be used to import the entire library.

=head2 Numbers

The following constants are numbers.  They can be imported as a set
using the C<:numbers> export tag.

=over 4

=item C<$PI>

This is C<4*atan2(1,1)>.

=item C<$ETOK>

The conversion constant between energy and wavenumber.

  k = sqrt( ETOK * (E-E0) )

C<$ETOK> is about equal to 1 / 3.81.  10 inverse Angstroms is about
381 volts above the edge.

=item C<$HBARC>

This is hbar*c in eV*Angstrom units.

=item C<$HC>

This is h*c in eV*Angstrom units.

  $HC = $HBARC * 2 * $PI;

=item C<$HBARC>

This is hbar in eV*seconds units.

=item C<$R2D>

The conversion constant between degrees and radians, 180/PI.

=item C<$EPSILONn>

1e-n, for instance C<$EPSILON2> = 1e-2 and C<$EPSILON2> = 1e-7.  These
are defined for 2 through 7.

=back

=head2 Strings

The following constants are strings.  They can be imported as a set
using the C<:strings> export tag.

=over 4

=item C<$NULLFILE>

This is C<@&^^null^^&@>, a nonesense string to indicate an undefined
filename.

=item C<$ENDOFLINE>

The platform specific end of line character.

=item C<$CTOKEN>

The token, C<+>, denoting the central atom in a short representation
of the path geometry.

=back

=head2 Regular expressions

The following constants are regular expressions.  They can be imported
as a set using the C<:regexps> export tag.

=over 4

=item C<$NUMBER>

This is C<$RE{num}{real}> from L<Regexp::Common>, i.e. a match for
floats.

=item C<$INTEGER>

This is C<$RE{num}{int}> from L<Regexp::Common>, i.e. a match for
integers.

=item C<$SEPARATOR>

This is C<[ \t]*[ \t=,][ \t]*>, the regular expression defining the
separation between keyword and value in an input file for Feff, Atoms,
etc.

=item C<$ELEMENT>

A regular expression matching a valid element symbol.

=item C<$FEFFNOTOK>

A regular expression used to scrub strings which, when used as site
tags, will cause trouble with Feff.  This currently matches a
character that is not alphanumeric, a dot, a dash, or an underscore:
C<[^-a-zA-Z0-9_.]>

=back

=head1 BUGS AND LIMITATIONS

Please report problems to the Ifeffit Mailing List
(L<http://cars9.uchicago.edu/mailman/listinfo/ifeffit/>)

Patches are welcome.

=head1 AUTHOR

Bruce Ravel, L<http://bruceravel.github.io/home>

L<http://bruceravel.github.io/demeter/>

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2015 Bruce Ravel (L<http://bruceravel.github.io/home>). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
