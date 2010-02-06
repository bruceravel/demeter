#!/usr/bin/perl

## Test SSPath object functionality of Demeter under Moose

=for Copyright
 .
 Copyright (c) 2008-2010 Bruce Ravel (bravel AT bnl DOT gov).
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

use Test::More tests => 17;

use Demeter;

use File::Basename;
use File::Spec;
my $here  = dirname($0);

## an SSPath requires that a Feff object exist
my $feff = Demeter::Feff -> new(workspace => File::Spec->catfile($here, 'feff'),
				file => File::Spec->catfile($here, 'withHg.inp'),
				screen => 0);
$feff -> make_workspace;
$feff -> potph;
$feff -> rmax(4.5);
$feff -> pathfinder;

my $this = Demeter::SSPath -> new(parent=>$feff, ipot=>2, reff=>3.5);
my $OBJ  = 'SSPath';

ok( ref($this) =~ m{$OBJ},           "made a $OBJ object");
ok( $this->plottable,                "$OBJ object is plottable");
ok( $this->group =~ m{\A\w{5}\z},    "$OBJ object has a proper group name");
ok( $this->name =~ m{SS},            "name set to its default (" . $this->name . ")");
$this -> name('this');
ok( $this->name eq 'this',           "$OBJ object has a settable label");
ok( $this->data,                     "$OBJ object has an associated Data object");
ok( ref($this->mo) =~ 'Mode',        "$OBJ object can find the Mode object");
ok( ref($this->co) =~ 'Config',      "$OBJ object can find the Config object");
ok( ref($this->po) =~ 'Plot',        "$OBJ object can find the Plot object");
ok( ($this->mo->template_plot     eq 'pgplot'  and
     $this->mo->template_feff     eq 'feff6'   and
     $this->mo->template_process  eq 'ifeffit' and
     $this->mo->template_fit      eq 'ifeffit' and
     $this->mo->template_analysis eq 'ifeffit'),
                                     "$OBJ object can find template sets");

$this->path;
ok( (($this->degen == 1)      and
     ($this->nleg  == 2)      and
     (abs($this->reff - 3.5)) < 0.0001),
                                     "parse_nnnn works");

$this->update_path(0);
$this->update_fft(0);
$this->update_bft(0);
$this->update_path(1);
ok( $this->update_bft,               "update flags work");

$this->set(s02    => 1,
	   e0     => 'enot',
	   sigma2 => 'debye([cv], 500)',
	  );
$this -> rewrite_cv;
my $cv = $this->data->cv;
ok( $this->sigma2 eq "debye($cv, 500)", "rewrite_cv works (". $this->sigma2 . ")");

$this -> delr(0.1);
ok( abs($this->R - 3.5) < 0.0001,      "R works");

$this->e0_value(5);
my @list = $this->is_resonable('e0');
ok( $list[0],                          'e0 sanity test, ok');
$this->e0_value(30);
@list = $this->is_resonable('e0');
ok(!$list[0],                          'e0 sanity test, too large');

ok($this->parent eq $this->feff,           'feff as alias for parent attribute');

$feff -> clean_workspace;
