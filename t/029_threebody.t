#!/usr/bin/perl

## Test ThreeBody object functionality of Demeter under Moose

=for Copyright
 .
 Copyright (c) 2008-2017 Bruce Ravel (http://bruceravel.github.io/home).
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

use Test::More tests => 10;

use Demeter qw(:fit);
use Demeter::ThreeBody;

use File::Basename;
use File::Spec;
my $here  = dirname($0);

## a ThreeBody requires that a Feff object exist
my $feff = Demeter::Feff -> new(workspace => File::Spec->catfile($here, 'feff'),
				file => File::Spec->catfile($here, 'withHg.inp'),
				screen => 0);
$feff -> make_workspace;
$feff -> potph;
$feff -> rmax(4.5);
$feff -> pathfinder;

my $this = Demeter::ThreeBody -> new(parent=>$feff);
my $OBJ  = 'ThreeBody';

ok( ref($this) =~ m{$OBJ},           "made a $OBJ object");
ok( $this->plottable,                "$OBJ object is plottable"); ## or not
ok( $this->group =~ m{\A\w{5}\z},    "$OBJ object has a proper group name");
## if needed --v
ok( $this->name =~ m{Three Body}, "name set to its default (" . $this->name . ")");
$this -> name('this');
ok( $this->name eq 'this',           "$OBJ object has a settable label");
ok( $this->data,                     "$OBJ object has an associated Data object"); ## or not
ok( ref($this->mo) =~ 'Mode',        "$OBJ object can find the Mode object");
ok( ref($this->co) =~ 'Config',      "$OBJ object can find the Config object");
ok( ref($this->po) =~ 'Plot',        "$OBJ object can find the Plot object");
ok( ($this->mo->template_plot     =~ m{plot}   and
     $this->mo->template_feff     eq 'feff6'   and
     $this->mo->template_process  eq 'ifeffit' and
     $this->mo->template_fit      eq 'ifeffit' and
     $this->mo->template_analysis eq 'ifeffit'),
                                     "$OBJ object can find template sets");
