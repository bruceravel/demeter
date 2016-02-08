#!/usr/bin/perl

=for Copyright
 .
 Copyright (c) 2006-2016 Bruce Ravel (http://bruceravel.github.io/home).
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


use Demeter qw(:ui=screen);
print "Sample fit to copper data demonstrating the singlefile plotting backend.\n";

my $data = Demeter::Data -> new();

$data->set_mode(screen  => 0, backend => 1);

$data ->set(file       => "../../cu/cu10k.chi",
	    fft_kmin   => 3,	       fft_kmax   => 14,
	    fit_space  => 'r',
	    fit_k1     => 1,	       fit_k3     => 1,
	    bft_rmin   => 1.6,         bft_rmax   => 4.3,
	    fit_do_bkg => 0,
	    name       => 'My copper data',
	   );


my @gds =  (Demeter::GDS -> new(gds => 'guess', name => 'alpha', mathexp => 0),
	    Demeter::GDS -> new(gds => 'guess', name => 'amp',   mathexp => 1),
	    Demeter::GDS -> new(gds => 'guess', name => 'enot',  mathexp => 0),
	    Demeter::GDS -> new(gds => 'guess', name => 'theta', mathexp => 500),
	    Demeter::GDS -> new(gds => 'set',   name => 'temp',  mathexp => 300),
	    Demeter::GDS -> new(gds => 'set',   name => 'sigmm', mathexp => 0.00052),
	   );

my $feff = Demeter::Feff->new(file=>'../../cu/orig.inp', screen=>0, workspace=>'temp/');
$feff -> rmax(5);
$feff -> run;
my @sp = @{ $feff->pathlist };

my @paths = ();
foreach my $i (0 .. 4) {
  $paths[$i] = Demeter::Path -> new();
  $paths[$i]->set(data     => $data,
		  sp       => $sp[$i],
		  s02      => 'amp',
		  e0       => 'enot',
		  delr     => 'alpha*reff',
		  sigma2   => 'debye(temp, theta) + sigmm',
		 );
};

my $fit = Demeter::Fit -> new(gds   => \@gds,
			      data  => [$data],
			      paths => \@paths
			     );

$fit -> fit;

$data->po->set(plot_data => 1,
	       plot_fit  => 1,
	       plot_bkg  => 0,
	       plot_res  => 0,
	       plot_win  => 1,
	       plot_run  => 0,
	       kweight   => 2,
	       r_pl      => 'm',
	       'q_pl'    => 'r',
	      );

$data->po->space('R');

$data -> plot_with('gnuplot');
my $step = 0;  # stack the plot interestingly...
foreach my $obj ($data, @paths,) {
  $obj -> plot;
  $step -= 0.8;
  $data -> y_offset($step);
};
$data -> y_offset(0);
$data -> pause;

$data->plot_with('singlefile');           # 1: switch to single file backend
#$data->standard;                          # 2: use the x-axis of $data in the file
#$data->po->file('nifty_plot.dat');        # 3: set an output file name
#$data->po->start_plot;                    # 4: start a new plot

                                           # or do steps 2-4 in one method call
$data -> po -> prep(file=>'nifty_plot.dat', standard=>$data, space=>'R');

$step = 0;
foreach my $obj ($data, @paths,) {        # 5: make the plot
  $obj -> plot;
  $step -= 0.8;
  $data -> y_offset($step);
};
$data -> y_offset(0);
$data->po->finish;                        # 6: finish the plot and write the file
$data->unset_standard;                    # 7. clean up
