#!/usr/bin/perl

## File import tests

=for Copyright
 .
 Copyright (c) 2008-2019 Bruce Ravel (http://bruceravel.github.io/home).
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

BEGIN {
  $ENV{DEMETER_NO_BACKEND} = 1;
}

use Test::More tests => 4;

use Demeter qw(:none);

use File::Basename;
use File::Spec;
my $here  = dirname($0);
my $demeter = Demeter->new;

ok( (not $demeter->is_atoms(File::Spec->catfile($here, 'fe.060'))),     'recognize data as not atoms');
ok( $demeter->is_atoms(File::Spec->catfile($here, 'PbFe12O19.inp')),    'identify atoms input file');

ok( (not $demeter->is_feff(File::Spec->catfile($here, 'fe.060'))),      'recognize data as not feff');
ok( $demeter->is_feff(File::Spec->catfile($here, 'withHg.inp')),        'identify feff input file');
