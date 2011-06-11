#!/usr/bin/perl

## Test ScatteringPath object functionality of Demeter under Moose

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

use Test::More tests => 26;

use Demeter;
use Cwd;
use File::Basename;
use File::Spec;
my $here  = dirname($0);

my $this = Demeter::ScatteringPath -> new();
my $OBJ  = 'ScatteringPath';

ok( ref($this) =~ m{$OBJ},                              "made a $OBJ object");
ok(!$this->plottable,                                   "$OBJ object is not plottable");
ok( $this->group =~ m{\A\w{5}\z},                       "$OBJ object has a proper group name");
$this -> name('this');
ok( $this->name eq 'this',                              "$OBJ object has a settable label");
ok( !$this->data,                                       "$OBJ object has no associated Data object");
ok( ref($this->mo) =~ 'Mode',                           "$OBJ object can find the Mode object");
ok( ref($this->co) =~ 'Config',                         "$OBJ object can find the Config object");
ok( ref($this->po) =~ 'Plot',                           "$OBJ object can find the Plot object");
ok( ($this->mo->template_plot     =~ m{plot}   and
     $this->mo->template_feff     eq 'feff6'   and
     $this->mo->template_process  eq 'ifeffit' and
     $this->mo->template_fit      eq 'ifeffit' and
     $this->mo->template_analysis eq 'ifeffit'),
                                                        "$OBJ object can find template sets");

## -------- test path description semantics

my $demeter = Demeter -> new;
my $where   = File::Spec->catfile($here, 'feff');
my $orig    = File::Spec->catfile($here, 'withHg.inp');
my $file    = $orig;
my $feff    = Demeter::Feff -> new(workspace => $where, file => $orig, screen => 0);
$feff -> rmax(4.5);
$feff -> pathfinder;
#print $feff -> intrp;

my $p = $feff -> find_path(tag=>'N13');
ok($p->parent eq $p->feff,                             'parent as alias for feff attribute');
ok( abs($p->fuzzy - 4.191) < 0.001,                     sprintf("find SS path by exact tag (%s)",$p->fuzzy));

my $pp = $feff -> find_path(tagmatch=>'N');
ok( abs($pp->fuzzy - 2.040) < 0.001,                    sprintf("find SS path by tag match (%s)",$pp->fuzzy));

$p = $feff -> find_path(tagmatch=>'N', sp=>$pp);
ok( abs($p->fuzzy - 4.191) < 0.001,                     sprintf("find second SS path by tag match (%s)",$p->fuzzy));

$p = $feff -> find_path(tag=>['N13', 'N16']);
ok( abs($p->fuzzy - 4.267) < 0.001,                     sprintf("find DS path by tag (%s)",$p->fuzzy));

$p = $feff -> find_path(tag=>['N16', 'N13']);
ok( abs($p->fuzzy - 4.267) < 0.001,                     sprintf("find DS path by tag, opposite order (%s)",$p->fuzzy));

$p = $feff -> find_path(tagmatch=>['N', 'N']);
ok( abs($p->fuzzy - 4.267) < 0.001,                     sprintf("find DS path by tag match (%s)",$p->fuzzy));

$p = $feff -> find_path(element=>'O');
ok( abs($p->fuzzy - 3.036) < 0.001,                     sprintf("find SS path by element (%s)",$p->fuzzy));

$pp = $feff -> find_path(element=>['N', 'C', 'N']);
ok( abs($pp->fuzzy - 3.418) < 0.001,                    sprintf("find TS path by element (%s)",$pp->fuzzy));

$p = $feff -> find_path(element=>['N', 'C', 'N'], gt => 3.5);
ok( abs($p->fuzzy - 4.420) < 0.001,                     sprintf("find TS path by element w gt (%s)",$p->fuzzy));

$p = $feff -> find_path(element=>['N', 'C', 'N'], sp => $pp);
ok( abs($p->fuzzy - 4.420) < 0.001,                     sprintf("find TS path by element w sp (%s)",$p->fuzzy));

$p = $feff -> find_path(ipot=>1);
ok( abs($p->fuzzy - 3.036) < 0.001,                     sprintf("find SS path by ipot (%s)",$p->fuzzy));

$pp = $feff -> find_path(ipot=>[2, 3, 2]);
ok( abs($pp->fuzzy - 3.418) < 0.001,                    sprintf("find TS path by ipot (%s)",$pp->fuzzy));

$p = $feff -> find_path(ipot=>[2, 3, 2], gt => 3.5);
ok( abs($p->fuzzy - 4.420) < 0.001,                     sprintf("find TS path by ipot w gt (%s)",$p->fuzzy));

$p = $feff -> find_path(ipot=>[2, 3, 2], sp => $pp);
ok( abs($p->fuzzy - 4.420) < 0.001,                     sprintf("find TS path by ipot w sp (%s)",$p->fuzzy));


my @list = $feff -> find_all_paths(element=>'N');
##print join($/, map {$_->intrpline} @list), $/;
ok( ((abs($list[0]->fuzzy - 2.040) < 0.001) and
     (abs($list[1]->fuzzy - 4.191) < 0.001)),           "find_all_paths found both SS N paths");

#@list = $feff -> find_all_paths(nleg=>2);
#print join($/, map {$_->intrpline} @list), $/;

my $nearest = $feff -> find_nearest(reff=>4, element=>'N');
ok( (abs($nearest->fuzzy - 4.191) < 0.001),             "find_nearest");

$feff -> clean_workspace;
