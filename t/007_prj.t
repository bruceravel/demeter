#!/usr/bin/perl

## Test Data::Prj object functionality of Demeter under Moose

=for Copyright
 .
 Copyright (c) 2008-2009 Bruce Ravel (bravel AT bnl DOT gov).
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

use Test::More tests => 22;

use Ifeffit;
use Demeter;
use List::MoreUtils qw(all);


my $this = Demeter::Data::Prj->new(file=>'t/cyanobacteria.prj');
my $OBJ  = 'Prj';

ok( ref($this) =~ m{$OBJ},                              "made a $OBJ object");
ok(!$this->plottable,                                   "$OBJ object is not plottable");
ok( $this->group =~ m{\A\w{5}\z},                       "$OBJ object has a proper group name");
$this -> name('this');
ok( $this->name eq 'this',                              "$OBJ object has a settable label");
ok(!$this->data,                                        "$OBJ object has no associated Data object");
ok( ref($this->mo) =~ 'Mode',                         "$OBJ object can find the Mode object");
ok( ref($this->co) =~ 'Config',               "$OBJ object can find the Config object");
ok( ref($this->po) =~ 'Plot',                   "$OBJ object can find the Plot object");
ok( ($this->mo->template_plot     eq 'pgplot'  and
     $this->mo->template_feff     eq 'feff6'   and
     $this->mo->template_process  eq 'ifeffit' and
     $this->mo->template_fit      eq 'ifeffit' and
     $this->mo->template_analysis eq 'ifeffit'),
                                                        "$OBJ object can find template sets");

my @list = @{ $this->entries };
ok( $#list == 16, "parsed the project file");

my @data = $this->slurp;
ok( $#data == 16,                                       "slurped the right number of records");
ok( (all {ref($_) =~ m{Data} } @data),                  "slurped in Data objects");

## now test that (one of) the Data objects just created is a proper Data object

my $first = $data[0];
$OBJ  = 'Data';

ok( ref($first) =~ m{$OBJ},                             "made a $OBJ object");
ok( $first->plottable,                                  "$OBJ object is plottable");
ok( $first->group =~ m{\A\w{4,5}\z},                    "$OBJ object has a proper group name");
$first -> name('first');
ok( $first->name eq 'first',                            "$OBJ object has a settable label");
ok( $first->data,                                       "$OBJ object is its own Data object");
ok( ref($first->mode) =~ 'Mode',                        "$OBJ object can find the Mode object");
ok( ref($first->mode->config) =~ 'Config',              "$OBJ object can find the Config object");
ok( ref($first->mode->plot) =~ 'Plot',                  "$OBJ object can find the Plot object");
ok( ($first->mode->template_plot     eq 'pgplot'  and
     $first->mode->template_feff     eq 'feff6'   and
     $first->mode->template_process  eq 'ifeffit' and
     $first->mode->template_fit      eq 'ifeffit' and
     $first->mode->template_analysis eq 'ifeffit'),
                                                        "$OBJ object can find template sets");
ok( $first->from_athena,                                "from_athena flag is set");
