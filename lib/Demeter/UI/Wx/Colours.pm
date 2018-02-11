package Demeter::UI::Wx::Colours;


=for Copyright
 .
 Copyright (c) 2006-2018 Bruce Ravel (http://bruceravel.github.io/home).
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
use Wx qw(wxNullColour);

use base qw( Exporter );
our @EXPORT = qw($wxBGC);

our $wxBGC = ($^O eq 'darwin') ? Wx::Colour->new('white') : wxNullColour;
