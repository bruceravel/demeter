#!/usr/bin/perl

## Test Plot object functionality of Demeter under Moose

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

use Test::More tests => 17;

use Ifeffit;
use Demeter;

my $demeter = Demeter->new;
my $this    = $demeter->po;
my $OBJ     = 'Plot';

ok( ref($this) =~ m{$OBJ},                "made a $OBJ object");
ok(!$this->plottable,                     "$OBJ object is not plottable");
ok( $this->group =~ m{\A\w{5}\z},         "$OBJ object has a proper group name: \"" . $this->group . "\"");
$this -> name('this');
ok( $this->name eq 'this',                "$OBJ object has a settable label");
ok(!$this->data,                          "$OBJ object has no associated Data object");
ok( ref($this->mo) =~ 'Mode',           "$OBJ object can find the Mode object");
ok( ref($this->co) =~ 'Config', "$OBJ object can find the Config object");
ok( ref($this->mo->plot) =~ 'Plot',     "$OBJ object can find the Plot object");
ok( ($this->mo->template_plot     eq 'pgplot'  and
     $this->mo->template_feff     eq 'feff6'   and
     $this->mo->template_process  eq 'ifeffit' and
     $this->mo->template_fit      eq 'ifeffit' and
     $this->mo->template_analysis eq 'ifeffit'),
                                       "$OBJ object can find template sets");

$this->increment;
ok( ($this->increm == 1 and $this->color eq 'red'), "incrementing works");

## -------- temporary files
my $string = $this->tempfile;
$this->tempfile;
$this->tempfile;
ok( ($string =~ m{\w{8}\z} and $#{$this->tempfiles} == 2),            "tempfile method works");
$this->cleantemp;
ok( $#{$this->tempfiles} == -1,            "cleantemp method works");

$this->legend('x'=>0.1, 'y'=>0.2, dy=>0.3);
ok( (Ifeffit::get_scalar('&plot_key_x')  == 0.1 and
     Ifeffit::get_scalar('&plot_key_y0') == 0.2 and
     Ifeffit::get_scalar('&plot_key_dy') == 0.3),                     "pgplot legend method works");

$this->set_mode(ifeffit=>0);
$this->font(size=>7, font=>4);
ok( ($this->charfont == 4 and $this->charsize == 7),                  "pgplot font method (seems to) work");
$this->set_mode(ifeffit=>1);

ok( $this -> textlabel(0.1, 0.2, "Hi there!"),                        "pgplot textlabel method (seems to) work");
ok( $this -> outfile("png", "/dev/null"),                             "pgplot outfile method (seems to) work");

$string = $this -> template("test", "test", {x=>5});
ok( $string =~ $this->group,                                'simple template works');
