#!/usr/bin/perl

=for Explanation
 This plots Fe and Cu mu(E) data with the edge energies subtracted
 from the energy axis.

=cut

=for Copyright
 .
 Copyright (c) 2006-2009 Bruce Ravel (http://bruceravel.github.io/home).
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
			       fft_kmax    => 3,    fft_kmin    => 17,
			      );
my @data = (Demeter::Data -> new(),
	    Demeter::Data -> new(),
	   );
foreach (@data) { $_ -> set(@common_to_all_data_sets) };
$data[0] -> set(file => "$where/data/fe.060.xmu", name => 'Fe 60K',
		energy=>'$1', numerator=>'$2', denominator=>1, ln=>0);
$data[1] -> set(file => "$where/data/cu010k.dat", name => 'Cu 10K',
		energy=>'$1', numerator=>'$2', denominator=>1, ln=>0 ); #y_offset => -0.4);

my $plot = $data[0]->po;
$plot->set_mode(screen=>0, repscreen=>0);

## decide how to plot the data
$plot -> set(e_mu    => 1,
	     e_bkg   => 0,
	     e_norm  => 1,
	     e_pre   => 0,
	     e_post  => 0,
	     e_zero  => 1,	# this tells demeter to plot mu(E) from 0
	     emin    => -30,	# \ xanes
	     emax    => 150,	# / plot
	    );

print "Plotting Fe and Cu with E0 subtracted ...\n";
foreach (@data) { $_ -> plot('E') };
$plot->e_zero(0);
print "All done!\n";

1;
