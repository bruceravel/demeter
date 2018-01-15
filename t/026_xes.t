#!/usr/bin/perl

## Test XES object functionality of Demeter under Moose

=for Copyright
 .
 Copyright (c) 2008-2018 Bruce Ravel (http://bruceravel.github.io/home).
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

use Test::More tests => 11;

use Demeter;
use File::Basename;
use File::Spec;

my $here  = dirname($0);

my $this = Demeter::XES -> new();
my $OBJ  = 'XES';

ok( ref($this) =~ m{$OBJ},           "made a $OBJ object");
ok( $this->plottable,                "$OBJ object is plottable");
ok( $this->group =~ m{\A\w{5}\z},    "$OBJ object has a proper group name");
ok( $this->name =~ m{XES},           "name set to its default (" . $this->name . ")");
$this -> name('this');
ok( $this->name eq 'this',           "$OBJ object has a settable label");
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
SKIP: {
  skip "XES system not being maintained", 2 if 1;
  my $xes = Demeter::XES->new(file=>File::Spec->catfile($here,'7725.11'),
			      energy => 2, emission => 3,
			      e1 => 7610, e2 => 7624, e3 => 7664, e4 => 7690,
			     );
  $xes -> _background;
  ok( lc($xes->z)    eq 'co',  'found element');
  ok( lc($xes->line) eq 'kb1', 'found emission line');
};
