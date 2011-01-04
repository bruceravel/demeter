#!/usr/bin/perl

## Test Feff object functionality of Demeter under Moose

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

use Test::More tests => 18;

use Demeter;

use File::Basename;
use File::Spec;
my $here  = dirname($0);
my $this = Demeter::Atoms -> new();
my $OBJ  = 'Atoms';

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

$this->file(File::Spec->catfile($here, 'PbFe12O19.inp'));
ok( abs($this->a - 5.873) < 0.001,                      "parsed an input file");
ok( $#{ $this->sites } == 10,                           "number of sites parsed correctly");
my $string = $this->Write('spacegroup');
ok( (
     ($string =~ m{(\d+) positions}) and ($1 eq '24') and
     ($this->sg('number') == 194 ) and
     ($this->sg('shorthand') eq 'hex, hcp' )
    ), "spacegroup database consulted correctly");
$this -> rmax(6);
$string = $this->Write;
ok( (($string =~ m{contains (\d+) atoms}) and ($1 eq '77')), "feff atoms list expanded to correct number"); 

$this->co->set_default("atoms", "precision", "10.6f");
ok( $this->out('a') eq '  5.873000',                          "setting output precision works: >".$this->out('a')."<");
$this->co->set_default("atoms", "precision", "10.5f");
ok( $this->out('a') eq '   5.87300',                          "setting output precision works: >".$this->out('a')."<");


## need to test absorption calculations

my @list;
$this->ipot_style("tags");
@list = split("\n", $this->potentials_list);
ok( $#list == 6,  "ipot style tags works");

$this->ipot_style("elements");
@list = split("\n", $this->potentials_list);
ok( $#list == 3,  "ipot style elements works");

## this should be the last test
$this->ipot_style("sites");
open(STDERR, ">/dev/null");
@list = split("\n", $this->potentials_list);
ok( $#list == 10,  "ipot style sites works");
