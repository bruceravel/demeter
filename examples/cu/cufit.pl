#!/usr/bin/perl

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


use Demeter qw(:ui=screen :template=iff_columns);
print "Sample fit to copper data using Demeter ", $Demeter::VERSION, $/;
unlink "cufit.iff" if (-e "cufit.iff");


print "make a Data object and set the FT and fit parameters\n";
my $dobject = Demeter::Data -> new();

$dobject->set_mode(screen  => 0, ifeffit => 1, file => ">cufit.iff", );
#$dobject -> template_set("demeter"); ## similar to the template pragma
$dobject -> plot_with('gnuplot');    ## similar to the plotwith pragma
my $plot_features = $dobject->po;

$dobject ->set(file       => "cu10k.chi",
	       fft_kmin   => 3,	       fft_kmax   => 14,
	       fit_space  => 'r',
	       fit_k1     => 1,	       fit_k3     => 1,
	       bft_rmin   => 1.6,      bft_rmax   => 4.3,
	       fit_do_bkg => 0,
	       name       => 'My copper data',
	      );


print "make GDS objects for an isotropic expansion, correlated Debye model fit to copper\n";
my @gdsobjects =  (Demeter::GDS -> new(gds => 'guess', name => 'alpha', mathexp => 0),
		   Demeter::GDS -> new(gds => 'guess', name => 'amp',   mathexp => 1),
		   Demeter::GDS -> new(gds => 'guess', name => 'enot',  mathexp => 0),
		   Demeter::GDS -> new(gds => 'guess', name => 'theta', mathexp => 500),
		   Demeter::GDS -> new(gds => 'set',   name => 'temp',  mathexp => 300),
		   Demeter::GDS -> new(gds => 'set',   name => 'sigmm', mathexp => 0.00052),
		  );

print "make Path objects for the first 5 paths in copper (3 shell fit)\n";
my @pobjects = ();
foreach my $i (0 .. 4) {
  my $j = $i+1;
  $pobjects[$i] = Demeter::Path -> new();
  $pobjects[$i]->set(data     => $dobject,
		     folder   => './',
		     file     => "feff000$j.dat",
		     s02      => 'amp',
		     e0       => 'enot',
		     delr     => 'alpha*reff',
		     sigma2   => 'debye(temp, theta) + sigmm',
		    );
};

print "make a Fit object, which is just a collection of GDS, Data, and Path objects\n";
my $fitobject = Demeter::Fit -> new(gds   => \@gdsobjects,
				    data  => [$dobject],
				    paths => \@pobjects
				   );

print "do the fit (or the sum of paths)\n";
$fitobject -> fit;

$plot_features->set(plot_data => 1,
		    plot_fit  => 1,
		    plot_bkg  => 0,
		    plot_res  => 0,
		    plot_win  => 1,
		    plot_run  => 1,
		    kweight   => 2,
		    r_pl      => 'r',
		    'q_pl'    => 'r',
		   );

$dobject->plot('r');
my $end = <STDIN>;

print "save the results of the fit\n";
$dobject->save("fit", "cufit.fit");
$pobjects[0]->save("r", "path0.rsp");
exit;

$fitobject -> interview;
exit;

print "set nice legend parameters for the plot\n";
$plot_features->legend(dy=>0.05, x=>0.8);

exit if ($dobject->mode->template_process eq "feffit");
print "plot the data + fit + paths\n";
my $space = 'r';
$plot_features->set(plot_data => 1,
		    plot_fit  => 1,
		    plot_bkg  => 0,
		    plot_res  => 0,
		    plot_win  => 1,
		    plot_run  => 1,
		    kweight   => 2,
		    r_pl      => 'm',
		    'q_pl'    => 'r',
		   );

my $s = 0;  # stack the plot interestingly...
foreach my $obj ($dobject, @pobjects,) {
  $obj -> plot($space);
  $s -= 0.8;
  $dobject -> set('y_offset'=>$s);
};

print "save the results of the fit\n";
$dobject->save("fit", "cufit.fit");
$dobject->save("fit", "rmag.fit", 'rmag');
$dobject->save("fit", "rre.fit", 'rre');
$dobject->save("fit", "rim.fit", 'rim');
#$pobjects[0]->save("r", "path0.r");

print "write log and serialization files\n";
my ($header, $footer) = ("Fit to copper data", q{});
$fitobject -> logfile("cufit.log", $header, $footer);
$fitobject -> freeze(file=>"cufit.dpj");
