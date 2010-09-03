#!/usr/bin/perl

## Test PeakFit object functionality of Demeter under Moose

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
use Readonly;
Readonly my $EPSILON => 1e-2;

my $here  = dirname($0);


SKIP: {
  skip "No Fityk, skipping all PeakFit tests",17 if not $Demeter::Fityk_exists;

my $this = Demeter::PeakFit -> new();
my $OBJ  = 'PeakFit';

ok( ref($this) =~ m{$OBJ},           "made a $OBJ object");
ok( $this->plottable,                "$OBJ object is plottable");
ok( $this->group =~ m{\A\w{5}\z},    "$OBJ object has a proper group name");
ok( $this->name =~ m{PeakFit},       "name set to its default (" . $this->name . ")");
$this -> name('this');
ok( $this->name eq 'this',           "$OBJ object has a settable label");
ok( ref($this->mo) =~ 'Mode',        "$OBJ object can find the Mode object");
ok( ref($this->co) =~ 'Config',      "$OBJ object can find the Config object");
ok( ref($this->po) =~ 'Plot',        "$OBJ object can find the Plot object");
ok( ($this->mo->template_plot     eq 'pgplot'  and
     $this->mo->template_feff     eq 'feff6'   and
     $this->mo->template_process  eq 'ifeffit' and
     $this->mo->template_fit      eq 'ifeffit' and
     $this->mo->template_analysis eq 'ifeffit'),
                                     "$OBJ object can find template sets");


my $xes = Demeter::XES->new(file=>File::Spec->catfile($here,'7725.11'),
			    energy => 2, emission => 3,
			    e1 => 7610, e2 => 7624, e3 => 7664, e4 => 7690,
			   );
my $peak = Demeter::PeakFit->new(screen => 0, yaxis=> 'norm',);
$peak -> data($xes);

#$peak -> add('linear', name=>'baseline');
$peak -> add('gaussian', center=>7649.5, name=>'peak 1');
$peak -> add('gaussian', center=>7647.7, name=>'peak 2');
my $ls = $peak -> add('lorentzian', center=>7636.8, name=>'peak 3');
$ls -> fix1(0);

$peak -> fit;

## results of fit
#peak 1 (Gaussian) : height = 0.648(0.0162), center = 7649.49(0.02), hwhm = 1.67(0.0359), area = 2.31
#peak 2 (Gaussian) : height = 0.413(0.0133), center = 7647.28(0.12), hwhm = 3.97(0.0923), area = 3.49
#peak 3 (Lorentzian) : height = 0.186(0.00437), center = 7637.39(0.20), hwhm = 4.95(0.22), area = 2.90

ok( abs($ls->a1 - 7637.39) < $EPSILON, "peak center from fit");
ok( abs($ls->area - 2.90)  < $EPSILON, "peak area from fit");


ok( join("|", $ls->parameter_names('PielaszekCube')) eq 'a|center|r|s',              "PielaszekCube parameters");
ok( join("|", $ls->parameter_names('Polynomial5'))   eq 'a0|a1|a2|a3|a4|a5',         "Polynomial5 parameters");
ok( join("|", $ls->parameter_names('SplitGaussian')) eq 'height|center|hwhm1|hwhm2', "SplitGaussian parameters");
ok( join("|", $ls->parameter_names('LogNormal'))     eq 'height|center|width|asym',  "LogNormal parameters");

ok( (($ls->nparams('Gaussian') == 3) and ($ls->nparams('SplitPearson7') == 6)), "nparams works");

ok( ($ls->describe('Gaussian', 1) eq 'height*exp(-ln(2)*((x-center)/hwhm)^2)'), "describe works");

}
