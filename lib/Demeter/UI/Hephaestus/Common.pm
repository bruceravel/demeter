package Demeter::UI::Hephaestus::Common;

=for Copyright
 .
 Copyright (c) 2006-2015 Bruce Ravel (L<http://bruceravel.github.io/home>).
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

use warnings;
use strict;
use version;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);

use Demeter::Constants qw($PI $HBARC);

use Wx qw(wxVERSION_STRING);

require Exporter;
@ISA       = qw(Exporter);
#@EXPORT    = qw(e2l);
@EXPORT_OK = qw(e2l hversion hcopyright hdescription);

sub hversion {
  return $Demeter::VERSION;
};

sub hcopyright {
  return "copyright (c) 2006-2015 Bruce Ravel"
};

sub hdescription {
  my $wxversion = wxVERSION_STRING;
  my $string = "A souped-up periodic table for the X-ray absorption spectroscopist\n";
  $string   .= "Using perl $], $wxversion, wxPerl $Wx::VERSION  ";
};

sub e2l {
  ($_[0] and ($_[0] > 0)) or return "";
  return 2*$PI*$HBARC / $_[0];
};


=head1 NAME

Demeter::UI::Hephaestus::Common - Common functions used in Hephaestus

=head1 VERSION

This documentation refers to Demeter version 0.9.21.

=head1 SYNOPSIS

This module contains functions used by many parts of Hephaestus.

  use Demeter::UI::Hephaestus::Common qw(e2l);

=head1 DESCRIPTION

Several common functions are conatined in this moduel for use
throughout Hephaestus.

=over 4

=item C<e2l>

Convert between energy and wavelength.

  $l = e2l($e);
   #  or
  $e = e2l($l);

=item C<hversion>

Return a string giving the Hephaestus version number.

=item C<hcopyright>

Return a string giving the Hephaestus copyright statement.

=item C<hdescription>

Return a string giving a description of Hephaestus' operating
environment, including version numbers for perl, WxWidgets, and
WxPerl.

=back

=head1 CONFIGURATION


=head1 DEPENDENCIES

Demeter's dependencies are in the F<Build.PL> file.

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
