#!/usr/bin/perl

## Test FSPath object functionality of Demeter under Moose

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

use Test::More tests => 16;

use Demeter qw(:fit);
use File::Basename;
use File::Path;
use File::Spec;
my $here  = dirname($0);

my $this = Demeter::FSPath -> new();
my $OBJ  = 'FSPath';

ok( ref($this) =~ m{$OBJ},           "made a $OBJ object");
ok( $this->plottable,                "$OBJ object is plottable");
ok( $this->group =~ m{\A\w{5}\z},    "$OBJ object has a proper group name");
#ok( $this->name =~ m{FS},            "name set to its default (" . $this->name . ")");
$this -> name('this');
ok( $this->name eq 'this',           "$OBJ object has a settable label");
ok( $this->data,                     "$OBJ object has an associated Data object");
ok( ref($this->mo) =~ 'Mode',        "$OBJ object can find the Mode object");
ok( ref($this->co) =~ 'Config',      "$OBJ object can find the Config object");
ok( ref($this->po) =~ 'Plot',        "$OBJ object can find the Plot object");
my $which = (Demeter->is_larch) ? 'larch' : 'ifeffit';
ok( ($this->mo->template_plot     =~ m{plot}   and
     $this->mo->template_feff     eq 'feff6'   and
     $this->mo->template_process  eq $which and
     $this->mo->template_fit      eq $which and
     $this->mo->template_analysis eq $which),
                                     "$OBJ object can find template sets");

$this->abs(29);
ok( $this->absorber eq 'Cu',         'Setting absorber works');
$this->scat('fluorine');
ok( $this->scatterer eq 'F',         'Setting scatterer works');
my @list = @{ $this->gds };
ok( $#list == 3,                     'GDS list correct length');
ok( (    ($list[0]->name eq 'aa_cu_f_0')
     and ($list[1]->name eq 'ee_cu_f_0')
     and ($list[2]->name eq 'dr_cu_f_0')
     and ($list[3]->name eq 'ss_cu_f_0')),   'GDS parameters named correctly');
$this->workspace(File::Spec->catfile($here, 'fs'));
$this->_update('path');
ok( $this->parent =~ m{Feff},              'Feff object associated');
ok( $this->feff_done,                      'Feff calculation was made');

ok($this->parent eq $this->feff,           'feff as alias for parent attribute');

rmtree(File::Spec->catfile($here, 'fs'));
