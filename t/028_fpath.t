#!/usr/bin/perl

## Test FPath object functionality of Demeter under Moose

=for Copyright
 .
 Copyright (c) 2008-2017 Bruce Ravel (http://bruceravel.github.io/home).
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

use Test::More tests => 12;

use Demeter qw("fit);
use File::Basename;
use File::Spec;
my $here  = dirname($0);

my $this = Demeter::FPath -> new();
my $OBJ  = 'FPath';

ok( ref($this) =~ m{$OBJ},           "made a $OBJ object");
ok( $this->plottable,                "$OBJ object is plottable"); ## or not
ok( $this->group =~ m{\A\w{5}\z},    "$OBJ object has a proper group name");
## if needed --v
ok( $this->name =~ m{Filtered}, "name set to its default (" . $this->name . ")");
$this -> name('this');
ok( $this->name eq 'this',           "$OBJ object has a settable label");
ok( $this->data,                     "$OBJ object has an associated Data object"); ## or not
ok( ref($this->mo) =~ 'Mode',        "$OBJ object can find the Mode object");
ok( ref($this->co) =~ 'Config',      "$OBJ object can find the Config object");
ok( ref($this->po) =~ 'Plot',        "$OBJ object can find the Plot object");
ok( ($this->mo->template_plot     =~ m{plot}   and
     $this->mo->template_feff     eq 'feff6'   and
     $this->mo->template_process  eq 'ifeffit' and
     $this->mo->template_fit      eq 'ifeffit' and
     $this->mo->template_analysis eq 'ifeffit'),
                                     "$OBJ object can find template sets");

my $data = Demeter::Data->new(file=>File::Spec->catfile($here, 'cu010k.dat'),
			      name=>'copper metal', datatype=>'xmu');
$data->set(fft_kmin=>3, fft_kmax=>16, bft_rmin=>1, bft_rmax=>3);
my $fp = Demeter::FPath->new(absorber  => 'cOppEr',
			     scatterer => 'Cu',
			     reff      => 2.55266,
			     data      => $data,
			     n         => 12,
			     delr      => 0.0,
			     s02       => 1.09,
			    );
ok( $fp->absorber eq q{Cu},  "absorber");
ok( $fp->scat_z == 29,  "scatterer");

# $fp->set_mode(screen=>0);
# $fp->po->q_pl('r');
# $data->plot('q');
# $fp->plot('q');
# $fp->pause;
