#!/usr/bin/perl

## Test Feff object functionality of Demeter under Moose

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

use Test::More tests => 32;

use Demeter;
my $demeter  = Demeter -> new;

use Cwd;
use File::Spec;
my $orig = File::Spec->catfile(cwd, 't', 'orig.inp');

my $where = ($demeter->is_windows) ? File::Spec->catfile(cwd, 't', 'feff') : './t/feff';

my $this = Demeter::Feff -> new(workspace => $where);
my $OBJ  = 'Feff';

ok( ref($this) =~ m{$OBJ},                              "made a $OBJ object");
ok(!$this->plottable,                                   "$OBJ object is not plottable");
ok( $this->group =~ m{\A\w{5}\z},                       "$OBJ object has a proper group name");
$this -> name('this');
ok( $this->name eq 'this',                              "$OBJ object has a settable label");
ok( !$this->data,                                       "$OBJ object has no associated Data object");
ok( ref($this->mo) =~ 'Mode',                         "$OBJ object can find the Mode object");
ok( ref($this->co) =~ 'Config',               "$OBJ object can find the Config object");
ok( ref($this->po) =~ 'Plot',                   "$OBJ object can find the Plot object");
ok( ($this->mo->template_plot     eq 'pgplot'  and
     $this->mo->template_feff     eq 'feff6'   and
     $this->mo->template_process  eq 'ifeffit' and
     $this->mo->template_fit      eq 'ifeffit' and
     $this->mo->template_analysis eq 'ifeffit'),
                                                        "$OBJ object can find template sets");

## -------- parse a feff.inp file
my $file = ($demeter->is_windows) ? $orig : 't/orig.inp';
$this -> file($file);
ok( (($this->rmax == 6.0) and
     ($this->edge eq '1') and
     ($this->s02  == 1.0)),                             'simple Feff cards read');

my $ref = $this->potentials;
ok( $#{$ref} == 1,                                      'potentials list read');

$ref = $this->sites;
ok( $#{$ref} == 86,                                     'atoms list read');

$ref = $this->titles;
my $string = join(' | ', @$ref);
ok( $string =~ m{example},                              'titles read');

$ref = $this->absorber;
ok( (($this->abs_index == 0) and
     (abs($ref->[0]) < 0.00001) and
     (abs($ref->[1]) < 0.00001) and
     (abs($ref->[2]) < 0.00001)),                       'absorber identified');

ok( $this->site_tag(19) eq 'Cu_3',                      'site_tag method works');



## -------- write different sorts of feff.inp files
$this -> make_workspace;
ok( -d $where,                                          'make workspace works');

$this->make_feffinp("potentials");
open( my $fh, "$where/feff.inp" );
my $text = do { local( $/ ) ; <$fh> } ;
ok( $text =~ m{CONTROL\s+1\s+0\s+0\s+0},                'CONTROL written for potentials');

$this->make_feffinp("genfmt");
open( $fh, "$where/feff.inp" );
$text = do { local( $/ ) ; <$fh> } ;
ok( $text =~ m{CONTROL\s+0\s+0\s+1\s+0},                'CONTROL written for genfmt');

my $new = Demeter::Feff -> new(workspace => $where, file => "$where/feff.inp");
$ref = $new->sites;
ok( $#{$ref} == 86,                                     'output feff.inp file has the correct number of sites');

## -------- run potph
$this -> screen(0);
$this -> buffer(1);
$this -> potph;
ok( ((-s "$where/phase.bin" > 30000) and (-e "$where/misc.dat")), 'feff module potph ran correctly');

ok( $#{$this->iobuffer} >= 10,                           'iobuffer works');

$this -> screen(0);
$this -> rmax(4);
$this -> pathfinder;
$this -> freeze("$where/feff.yaml");



$new = Demeter::Feff -> new(yaml => "$where/feff.yaml");


ok( (($new->rmax == 4.0) and
     ($new->edge eq '1') and
     ($new->s02  == 1.0)),                             'thaw: simple Feff cards read');

$ref = $new->potentials;
ok( $#{$ref} == 1,                                     'thaw: potentials list read');

$ref = $new->sites;
ok( $#{$ref} == 86,                                    'thaw: atoms list read');

$ref = $new->titles;
$string = join(' | ', @$ref);
ok( $string =~ m{example},                             'thaw: titles read');

$ref = $new->absorber;
ok( (($new->abs_index == 0) and
     (abs($ref->[0]) < 0.00001) and
     (abs($ref->[1]) < 0.00001) and
     (abs($ref->[2]) < 0.00001)),                      'thaw: absorber identified');

ok( $new->site_tag(19) eq 'Cu_3',                      'thaw: site_tag method works');

## -------- write different sorts of feff.inp files
$new -> make_workspace;
ok( -d $where,                                         'thaw: make workspace works');

$new->make_feffinp("potentials");
open( $fh, "$where/feff.inp" );
$text = do { local( $/ ) ; <$fh> } ;
ok( $text =~ m{CONTROL\s+1\s+0\s+0\s+0},                'thaw: CONTROL written for potentials');

$new->make_feffinp("genfmt");
open( $fh, "$where/feff.inp" );
$text = do { local( $/ ) ; <$fh> } ;
ok( $text =~ m{CONTROL\s+0\s+0\s+1\s+0},                'thaw: CONTROL written for genfmt');

$new = Demeter::Feff -> new(workspace => $where, file => "$where/feff.inp");
$ref = $new->sites;
ok( $#{$ref} == 86,                                     'thaw: output feff.inp file has the correct number of sites');

$this -> clean_workspace;
ok( not (-d $where),                                    'clean workspace works');

