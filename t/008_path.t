#!/usr/bin/perl

## Test Path object functionality of Demeter under Moose

=for Copyright
 .
 Copyright (c) 2008-2015 Bruce Ravel (http://bruceravel.github.io/home).
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

use Test::More tests => 23;

use Demeter qw(:fit);
use List::MoreUtils qw(all);


my $this = Demeter::Path -> new;
my $OBJ  = 'Path';

ok( ref($this) =~ m{$OBJ},                              "made a $OBJ object");
ok( $this->plottable,                                   "$OBJ object is plottable");
ok( $this->group =~ m{\A\w{5}\z},                       "$OBJ object has a proper group name");
$this -> name('this');
ok( $this->name eq 'this',                              "$OBJ object has a settable label");
ok( $this->data,                                        "$OBJ object has an associated Data object");
ok( ref($this->mo) =~ 'Mode',                         "$OBJ object can find the Mode object");
ok( ref($this->co) =~ 'Config',               "$OBJ object can find the Config object");
ok( ref($this->po) =~ 'Plot',                   "$OBJ object can find the Plot object");
ok( ($this->mo->template_plot     =~ m{plot}   and
     $this->mo->template_feff     eq 'feff6'   and
     $this->mo->template_process  eq 'ifeffit' and
     $this->mo->template_fit      eq 'ifeffit' and
     $this->mo->template_analysis eq 'ifeffit'),
                                                        "$OBJ object can find template sets");

$this -> folder('t');
$this -> file('feff0001.dat');
ok( (($this->degen == 12)     and
     ($this->nleg  == 2)      and
     ($this->zcwif == 100)    and
     (abs($this->reff - 2.5527)) < 0.0001),             "parse_nnnn works");

$this->update_path(0);
$this->update_fft(0);
$this->update_bft(0);
$this->update_path(1);
ok( $this->update_bft,                                  "update flags work");

$this->set(s02    => 1,
	   e0     => 'enot',
	   sigma2 => 'debye([cv], 500)',
	  );
$this -> rewrite_cv;
my $cv = $this->data->cv;
ok( $this->sigma2 eq "debye($cv, 500)",                  "rewrite_cv works (". $this->sigma2 . ")");

$this -> delr_value(0.1);
ok( abs($this->R - 2.6527) < 0.0001,                    "R works");

$this->e0_value(5);
my @list = $this->is_resonable('e0');
ok( $list[0],                                           'e0 sanity test, ok');
$this->e0_value(30);
@list = $this->is_resonable('e0');
ok(!$list[0],                                           'e0 sanity test, too large');

$this->s02_value(0.8);
@list = $this->is_resonable('s02');
ok( $list[0],                                           's02 sanity test, ok');
$this->s02_value(-0.8);
@list = $this->is_resonable('s02');
ok(!$list[0],                                           's02 sanity test, negative');

$this->sigma2_value(0.003);
@list = $this->is_resonable('sigma2');
ok( $list[0],                                           'sigma2 sanity test, ok');
$this->sigma2_value(-0.003);
@list = $this->is_resonable('sigma2');
ok(!$list[0],                                           'sigma2 sanity test, negative');
$this->sigma2_value(0.3);
@list = $this->is_resonable('sigma2');
ok(!$list[0],                                           'sigma2 sanity test, too large');

$this->delr_value(0.01);
@list = $this->is_resonable('delr');
ok( $list[0],                                           'delr sanity test, ok');
$this->delr_value(1);
@list = $this->is_resonable('delr');
ok(!$list[0],                                           'delr sanity test, too large');

my $feff = Demeter::Feff -> new;
$this->parent($feff);
ok($this->parent eq $this->feff,                        'feff as alias for parent attribute');
