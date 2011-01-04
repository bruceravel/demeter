#!/usr/bin/perl

## Test Data object functionality of Demeter under Moose

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

use Test::More tests => 59;

use File::Basename;
use File::Spec;
use List::MoreUtils qw(all);
use Demeter;

my $here  = dirname($0);
my $data  = Demeter::Data -> new;
my $data2 = Demeter::Data -> new;

ok( ref($data) =~ m{Data},              "made a Data object");
ok( $data->group ne $data2->group,      "made distinct Data objects: " . $data->group . " ne " . $data2->group);
ok( $data->plottable,                   "Data object is plottable");
ok( ref($data->mo) =~ 'Mode',           'Data object can find the Mode object');
ok( ref($data->mo->config) =~ 'Config', 'Data object can find the Config object');
ok( ref($data->mo->plot) =~ 'Plot',     'Data object can find the Plot object');
ok( $data->group =~ m{\A\w{5}\z},       'Data object has a proper group name');
$data -> name('this');
ok( $data->name eq 'this',           'Data object has a settable label');
ok( ($data->mo->template_plot     eq 'pgplot'  and
     $data->mo->template_feff     eq 'feff6'   and
     $data->mo->template_process  eq 'ifeffit' and
     $data->mo->template_fit      eq 'ifeffit' and
     $data->mo->template_analysis eq 'ifeffit'),
                                        "Data object can find template sets");


ok( $data->bkg_kw == 2,              "attribute set from configuration parameters: number");
ok( $data->bkg_stan eq 'None',       "attribute set from configuration parameters: string");
ok( $data->bkg_kwindow eq 'hanning', "attribute set from configuration parameters: window");
ok( lc($data->fft_edge) eq 'k',      "attribute set from configuration parameters: edge");
## test trigger on spl1/spl1e and spl2/spl2e

$data -> fft_kmin(4); $data -> fft_kmax(12);
$data -> bft_rmin(2); $data -> bft_rmax(3);
ok( abs($data->nidp - 5.092) < 0.001,                      "FT and fit range triggers work to compute Nidp");
ok( (($data eq $data->data) and ($data2 eq $data2->data)), "Data object is its own data");
$data->standard;
ok( $data eq $data->mo->standard,                        "can set data standard");
$data->unset_standard;
ok( !$data->mo->standard,                                "can unset data standard");

## -------- test that updating logic works correctly
$data->update_data(0); $data->update_columns(0); $data->update_norm(0); $data->update_bkg(0); $data->update_fft(0); $data->update_bft(0);
ok( !$data->update_bft,                                    "can flag all as up to date");
$data->update_fft(1);
ok( $data->update_bft,                                     "bft flagged for update when fft flagged for update");
$data->update_fft(0); $data->update_bft(0);
$data->update_bkg(1);
ok( $data->update_fft && $data->update_bft ,               "fft,bft flagged for update when bkg flagged for update");
$data->update_bkg(0); $data->update_fft(0); $data->update_bft(0);
$data->update_columns(1);
ok( $data->update_norm && $data->update_bkg &&
    $data->update_fft  && $data->update_bft,               "norm,bkg,fft,bft flagged for update when columns flagged for update");
$data->update_columns(0); $data->update_norm(0); $data->update_bkg(0); $data->update_fft(0); $data->update_bft(0);
$data->update_data(1);
ok( $data->update_columns &&
    $data->update_norm    && $data->update_bkg &&
    $data->update_fft     && $data->update_bft,            "everything flagged for update when data flagged for update");

foreach (@Demeter::StrTypes::datatype_list) {
  $data->datatype($_);
  ok( $data->datatype eq $_,                               "can set data type: $_");
};

$data -> set_windows('welch');
ok( ($data->bkg_kwindow eq 'welch' and $data->fft_kwindow eq 'welch' and $data->bft_rwindow eq 'welch'), "set_windows works");

$data->file(File::Spec->catfile($here, 'data.xmu'));
$data->determine_data_type;
ok( $data->datatype eq 'xmu',                               "determine_data_type works: xmu");
$data2->file(File::Spec->catfile($here, 'data.chi'));
$data2->determine_data_type;
ok( $data2->datatype eq 'chi',                              "determine_data_type works: chi");

my $string = $data -> template("test", "test", {x=>5});
ok( $string =~ $data->group,                                'simple template works');

## -------- Methods for setting E0
my $fuzz = 0.002;

my $data3 = Demeter::Data -> new(file=>File::Spec->catfile($here, 'fe.060'),
				 energy      => '$1', # column 1 is energy
				 numerator   => '$2', # column 2 is I0
				 denominator => '$3', # column 3 is It
				 ln          => 1,    # these are transmission data
				);
my $data4 = Demeter::Data -> new(file=>File::Spec->catfile($here, 'fe.061'),
				 energy      => '$1', # column 1 is energy
				 numerator   => '$2', # column 2 is I0
				 denominator => '$3', # column 3 is It
				 ln          => 1,    # these are transmission data
				);


my $data5 = $data3->clone;
$data5->e0('ifeffit');

$data3->e0('ifeffit'); ## how do I make this happen automatically??

ok( ($data3->fft_edge eq 'k' and $data3->bkg_z eq 'Fe'),        'find_edge works: '.join(" ", $data3->fft_edge, $data3->bkg_z));
ok( abs($data3->bkg_e0 - 7105.506) < $fuzz,                     'find e0: ifeffit (' . $data3->bkg_e0 . ')');
$data3->e0('zero');
ok( abs($data3->bkg_e0 - 7105.292) < $fuzz,                     'find e0: zero crossing (' . $data3->bkg_e0 . ')');
$data3->e0(7110);
ok( abs($data3->bkg_e0 - 7110) < $fuzz,                         'find e0: number (' . $data3->bkg_e0 . ')');
$data3->e0('fraction');

ok( abs($data3->bkg_e0 - 7112.902) < $fuzz,                     'find e0: fraction (' . $data3->bkg_e0 . ' at ' . $data3->bkg_e0_fraction . ')');
$data3->e0('atomic');
ok( abs($data3->bkg_e0 - 7112) < $fuzz,                         'find e0: atomic (' . $data3->bkg_e0 . ')');


$data3->e0($data5);
ok( abs($data3->bkg_e0 - 7105.506) < $fuzz,                     'find e0: other Data object (' . $data3->bkg_e0 . ')');

#print $data3->yofx('xmu', '', 7112), $/;
ok(abs($data3->yofx('xmu', q{}, 7112) - 1.17) < 0.01,           'yofx method works');
#print $data3->iofx('energy', 7112), $/;
ok($data3->iofx('energy', 7112) == 77,                          'iofx works');


$data3->calibrate(7105.292, 7112);
ok( (abs($data3->bkg_e0 - 7112) < $fuzz and
     abs($data3->bkg_eshift - 6.708) < $fuzz),                  'calbrate method works');
$data3->align($data4);
ok( abs($data4->bkg_eshift - 6.722) < 5*$fuzz,                  'align method works');

my $e = 0;
if ($data3->_preline_marker_command =~ m{plot_marker\((\d+)}) {
  $e = $1;
};
ok( $e == $data3->bkg_e0+$data3->bkg_pre1, 'preline marker method: '.join(" ", $e, $data3->bkg_e0, $data3->bkg_pre1));
if ($data3->_postline_marker_command =~ m{plot_marker\((\d+)}) {
  $e = $1;
};
ok( $e == $data3->bkg_e0+$data3->bkg_nor1, 'postline marker method: '.join(" ", $e, $data3->bkg_e0, $data3->bkg_nor1));


## -------- methods for dealing with mu(E)
ok( $data->clamp('none')      == 0,  'clamp: none');
ok( $data->clamp('slight')    == 3,  'clamp: slight');
ok( $data->clamp('weak')      == 6,  'clamp: weak');
ok( $data->clamp('medium')    == 12, 'clamp: medium');
ok( $data->clamp('strong')    == 24, 'clamp: strong');
ok( $data->clamp('rigid')     == 96, 'clamp: rigid');
ok( $data->clamp('frobnazz')  == 0,  'clamp: ??');
ok( $data->clamp(17)          == 17, 'clamp: 17');

$fuzz = 0.01;
ok( abs($data3->e2k(50,   'rel') - 3.622)   < $fuzz, 'e2k, relative');
ok( abs($data3->e2k(7162, 'abs') - 3.622)   < $fuzz, 'e2k, absolute');
ok( abs($data3->k2e(4,    'rel') - 60.96)   < $fuzz, 'k2e, relative');
ok( abs($data3->k2e(4,    'abs') - 7172.96) < $fuzz, 'k2e, absolute');

## -------- test tying data groups as reference channels
$data->reference($data2);
$data->bkg_eshift(5);
ok( $data2->bkg_eshift eq 5, 'tying reference channels works');
$data2->bkg_eshift(-3);
ok( $data->bkg_eshift eq -3, 'tying reference channels works both ways');


## -------- test importing chi(k) data on the wrong grid
my $nonu = Demeter::Data->new(file=>File::Spec->catfile($here, 'nonuniform.chi'),);
$nonu->_update('fft');
my @k = $nonu->get_array('k');
ok( ( ($k[0] == 0) and (all { abs($k[$_] - $k[$_-1] - 0.05) < 1e-4 } (1 .. $#k)) ), 'fixing improper chi(k)' );

## -------- Data from arrays
my @x = $data3->get_array('energy');
my @y = $data3->get_array('xmu');
my $fa = Demeter::Data->put(\@x, \@y, datatype=>'xmu');
$fa->_update('fft');
ok( abs($fa->bkg_e0 - 7105.506) < $fuzz,                     'Data from arrays works (' . $fa->bkg_e0 . ')');
