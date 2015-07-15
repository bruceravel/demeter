#!/usr/bin/perl

## Test various things that don't get tested elsewhere

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

use Test::More tests => 71;

use Demeter qw(:data);
use File::Basename;
use File::CountLines qw(count_lines);
use File::Spec;
use List::Util qw(max min);

my $here  = dirname($0);
my $epsilon = 0.001;
my $d = Demeter::Data->new(fft_kmin=>3, fft_kmax=>12, fft_dk=>1, fft_kwindow=>'hanning');
$d->po->kweight(1);

## chi(k) data from an ascii column file
$d->set(datatype=>'chi', file=>File::Spec->catfile($here, 'cu10k.chi'));
$d->_update('bft');
my @y = $d->get_array('chi');
ok($#y == 499, "import chi(k) data from an ascii column file (".$#y.")");
@y = $d->get_array('chir_mag');
ok(abs(max(@y)-0.942367) < $epsilon, "chi(k) data from ascii file interpreted correctly (".max(@y).")");

## chi(k) data on a weird grid
$d->set(datatype=>'chi', file=>File::Spec->catfile($here, 'nonuniform.chi'));
$d->_update('bft');
@y = $d->get_array('chir_mag');
ok($#y == 325, "nonuniform chi(k) data binned onto standard grid (".$#y.")");
ok(abs(max(@y)-0.58562) < $epsilon, "nonuniform chi(k) data interpreted correctly (".max(@y).")");

## write_many
my $prj = Demeter::Data::Prj->new(file=>File::Spec->catfile($here, 'cyanobacteria.prj'));
my @data = $prj->records(9,10,11);
$data[0] -> save_many('many.dat', 'xmu', @data);
ok(count_lines('many.dat') == 338, 'save_many template works');
unlink 'many.dat';

## test dphase template
$d->dispense('process', 'dphase');
@y = $d->get_array('dph');
# $d->po->dphase(1);
# $d->po->r_pl('p');
# $d->po->rmax(10);
# $d->plot('r');
# $d->pause;
# print join('|', $#y, max(@y), min(@y)), $/;
ok((($#y == 325) and (max(@y)-0.58 < 0.01) and (-1*min(@y)-0.48 < 0.01)), "dphase template works");

## test normalizing a datatype=xanes group


## true/false utilities
my @true  = (qw(1 t T true True TRUE yes));
my @false = (qw(0 f F false False FALSE no), '', ' ');

foreach my $x (@true) {
  ok(Demeter->onezero($x)   eq '1',     ">$x< evaluates to 1");
  ok(Demeter->yesno($x)     eq 'yes',   ">$x< evaluates to yes");
  ok(Demeter->truefalse($x) eq 'true',  ">$x< evaluates to true");
  ok(Demeter->TrueFalse($x) eq 'True',  ">$x< evaluates to True");
};
foreach my $x (@false) {
  ok(Demeter->onezero($x)   eq '0',     ">$x< evaluates to 0");
  ok(Demeter->yesno($x)     eq 'no',    ">$x< evaluates to no");
  ok(Demeter->truefalse($x) eq 'false', ">$x< evaluates to false");
  ok(Demeter->TrueFalse($x) eq 'False', ">$x< evaluates to False");
};


## white line position
my $au = $prj->record(3);
my ($val, $err) = $au->find_white_line;
ok(abs($val-11921.743) < 0.07, 'white line position');
