#!/usr/bin/perl

## Test StructuralUnit object functionality of Demeter under Moose

=for Copyright
 .
 Copyright (c) 2008-2011 Bruce Ravel (bravel AT bnl DOT gov).
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

use Test::More tests => 12;

use Demeter;

my $this = Demeter::StructuralUnit -> new();
my $OBJ  = 'StructuralUnit';

ok( ref($this) =~ m{$OBJ},           "made a $OBJ object");
ok( $this->plottable,                "$OBJ object is plottable");
ok( $this->group =~ m{\A\w{5}\z},    "$OBJ object has a proper group name");
ok( $this->name =~ m{structural unit}, "name set to its default (" . $this->name . ")");
$this -> name('this');
ok( $this->name eq 'this',           "$OBJ object has a settable label");
ok(!$this->data,                     "$OBJ object has no associated Data object");
ok( ref($this->mo) =~ 'Mode',        "$OBJ object can find the Mode object");
ok( ref($this->co) =~ 'Config',      "$OBJ object can find the Config object");
ok( ref($this->po) =~ 'Plot',        "$OBJ object can find the Plot object");
ok( ($this->mo->template_plot     eq 'pgplot'  and
     $this->mo->template_feff     eq 'feff6'   and
     $this->mo->template_process  eq 'ifeffit' and
     $this->mo->template_fit      eq 'ifeffit' and
     $this->mo->template_analysis eq 'ifeffit'),
                                     "$OBJ object can find template sets");

my @paths = (Demeter::Path->new(), Demeter::Path->new(), Demeter::Path->new());
$this->include(@paths);
ok( $#{$this->pathgroups} == 2,      "extends VPath and includes Paths");
ok( length($this->tag) == 3,         "random tag generated properly (" . $this->tag . ")");
