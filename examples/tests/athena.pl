#!/usr/bin/perl

=for Explanation
 This reads iron foil data and writes out a usable Athena project
 file.

=cut

=for Copyright
 .
 Copyright (c) 2006-2009 Bruce Ravel (bravel AT bnl DOT gov).
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

use Demeter;
my $where = $ENV{DEMETER_TEST_DIR} || "..";

my @common_to_all_data_sets = (bkg_rbkg    => 1.5,
			       bkg_spl1    => 0,    bkg_spl2    => 18,
			                            bkg_nor2    => 1800,
			       bkg_flatten => 1,
			       fft_kmin    => 3,    fft_kmax    => 17,
			       energy      => '$1',
			       numerator   => '$2', # column 2 is I0
			       denominator => '$3', # column 3 is It
			       ln          => 1,    # these are transmission data
			      );
my @data = map {Demeter::Data -> new(group => $_) } qw(data0 data1 data2);
my $plot = $data[0]->po;
$plot->set_mode(screen=>0, repscreen=>0);

print "Making Data groups\n";
foreach (@data) { $_ -> set(@common_to_all_data_sets) };
$data[0] -> set(file => "$where/data/fe.060", name => 'Fe 60K, scan 1', 'y_offset' => 1, );
$data[1] -> set(file => "$where/data/fe.061", name => 'Fe 60K, scan 2', );
$data[2] -> set(file => "$where/data/fe.062", name => 'Fe 60K, scan 3', );

print "Plotting first group\n";
$data[0] -> plot('k');

print "Writing athena file\n";
$data[0]->write_athena("athena.prj", @data);

print "Rereading athena.prj and replotting first group\n";
my $d = Demeter::Data::Prj -> new(file=>"athena.prj") -> record(1);
$d -> plot('k');
1;
