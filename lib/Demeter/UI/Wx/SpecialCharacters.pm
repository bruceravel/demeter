package Demeter::UI::Wx::SpecialCharacters;

use strict;
use base qw( Exporter );
our @EXPORT_OK = qw($CHI $EPSILON $DELTA $SIGMA $SIGSQR $PHI $COPYRIGHT $LAQUO $RAQUO $MDASH);
our %EXPORT_TAGS = (all   => [qw($CHI $EPSILON $DELTA $SIGMA $SIGSQR $PHI $COPYRIGHT $LAQUO $RAQUO $MDASH)],
		    greek => [qw($CHI $EPSILON $DELTA $SIGMA $SIGSQR $PHI)],
		   );

my $is_windows = (($^O eq 'MSWin32') or ($^O eq 'cygwin'));

## -------- greek characters
our $CHI     = 'χ';
our $EPSILON = 'ε';
our $DELTA   = 'Δ';
our $SIGMA   = 'σ';
our $SIGSQR  = 'σ²';
our $PHI     = 'φ';


## -------- other special characters
our $COPYRIGHT = '©';
our $LAQUO     = '«';
our $RAQUO     = '»';
our $MDASH     = '—';

1;

=head1 NAME

Demeter::UI::Wx::SpecialCharacters - A library of special characters for use in Wx labels

=head1 VERSION

This documentation refers to Demeter version 0.3.

=head1 SYNOPSIS

This provides a library of special characters for use in labels on Wx widgets.

  use Demeter::UI::Wx::SpecialCharacters qw(:all);
  my $button = Wx::Button($parent, -1, "Plot $CHI(k)");

=head1 DESCRIPTION

This collects all the various special characters needed in Artemis and
other Wx-based GUIs into one convenient location.  Please note that
this exports B<variables> into your module's namespace.  This is a
against good practice, but is a huge convenience nonetheless.

The greek letters exported are

=over 4

=item C<$CHI>

lower case chi

=item C<$EPSILON>

lower case epsilon

=item C<$DELTA>

upper case delta

=item C<$SIGMA>

lower case sigma

=item C<$SIGSQR>

lower case sigma followed by a proper subscripted 2

=item C<$PHI>

lower case phi

=back

The other characters exported are

=over 4

=item C<$COPYRIGHT>

copyright symbol

=item C<$LABELS>

left guillemet

=item C<$RAQUO>

right guillemet

=back

The sets exported are

=over 4

=item C<:all>

As the name implies, all defined characters

=item C<:greek>

Just the greek letters

=back

=head1 BUGS AND LIMITATIONS

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
