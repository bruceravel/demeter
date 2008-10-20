#!/usr/bin/perl -I../lib

## Test Feff object functionality of Demeter under Moose

=for Copyright
 .
 Copyright (c) 2008 Bruce Ravel (bravel AT bnl DOT gov).
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

use Test::More tests => 9;

use Ifeffit;
use Ifeffit::Demeter;

my $this = Ifeffit::Demeter::ScatteringPath -> new();
my $OBJ  = 'ScatteringPath';

ok( ref($this) =~ m{$OBJ},                              "made a $OBJ object");
ok(!$this->plottable,                                   "$OBJ object is not plottable");
ok( $this->group =~ m{\A\w{5}\z},                       "$OBJ object has a proper group name");
$this -> name('this');
ok( $this->name eq 'this',                              "$OBJ object has a settable label");
ok( !$this->data,                                       "$OBJ object has no associated Data object");
ok( ref($this->mode) =~ 'Mode',                         "$OBJ object can find the Mode object");
ok( ref($this->mode->config) =~ 'Config',               "$OBJ object can find the Config object");
ok( ref($this->mode->plot) =~ 'Plot',                   "$OBJ object can find the Plot object");
ok( ($this->mode->template_plot     eq 'pgplot'  and
     $this->mode->template_feff     eq 'feff6'   and
     $this->mode->template_process  eq 'ifeffit' and
     $this->mode->template_fit      eq 'ifeffit' and
     $this->mode->template_analysis eq 'ifeffit'),
                                                        "$OBJ object can find template sets");

