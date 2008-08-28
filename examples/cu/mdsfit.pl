#!/usr/bin/perl -I/home/bruce/codes/demeter/lib

=for Copyright
 .
 Copyright (c) 2006-2008 Bruce Ravel (bravel AT bnl DOT gov).
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

use warnings;
use strict;

use Ifeffit;
use Ifeffit::Demeter;
use Ifeffit::Demeter::UI::Screen::Probe qw(interview);

use Smart::Comments;

print "Multiple data set fit to 10K and 150K copper data using Demeter ", $Ifeffit::Demeter::VERSION, $/;

unlink("mdsfit.iff") if (-e "mdsfit.iff");
Ifeffit::Demeter->set_mode({screen  => 0,
			    ifeffit => 1,
			    file    => ">mdsfit.iff",
			   });

###--- make 2 Data objects and set the fit parameters
my %common = (fft_kmin   => 3,	  fft_kmax   => 14,
	      bft_rmax   => 1.0,  bft_rmax   => 4.3,
	      fit_k1     => 1,	  fit_k3     => 1,);

my $data_010k = Ifeffit::Demeter::Data -> new({group => 'data0',});
$data_010k -> set(\%common);
$data_010k -> set({file	      => "cu10k.chi",
		   cv         => 10,
		   label      => '10 K copper data',
		   "y_offset" => 2,
		  });
my $data_150k = Ifeffit::Demeter::Data -> new({group => 'data1',});
$data_150k -> set(\%common);
$data_150k -> set({file       => "cu150k.chi",
		   cv         => 150,
		   label      => '150 K copper data',
		  });

###--- make GDS objects for an isotropic expansion, correlated Debye model
my @gdsobjects =  (Ifeffit::Demeter::GDS -> new({type	 => 'lguess',
						 name	 => 'alpha',
						 mathexp => 0,
						}),

		   ## here is some syntactic sugar provided by the Tools module
		   Ifeffit::Demeter::Tools -> simpleGDS("guess amp = 1"),

		   Ifeffit::Demeter::GDS -> new({type	 => 'guess',
						 name	 => 'enot',
						 mathexp => 0,
						}),
		   Ifeffit::Demeter::GDS -> new({type	 => 'guess',
						 name	 => 'theta',
						 mathexp => 500,
						}),
		   Ifeffit::Demeter::GDS -> new({type	 => 'set',
						 name	 => 'sigmm',
						 mathexp => 0.0005,
						}),
		  );

###--- make Path objects for the first 5 paths in copper (3 shell fit)
my @paths_010k = ();
foreach my $i (0 .. 4) {
  my $j = $i+1;
  $paths_010k[$i] = Ifeffit::Demeter::Path -> new();
  $paths_010k[$i]->set({data     => $data_010k,
			folder   => './',
			file     => "feff000$j.dat",
			label    => "10K, path $j",
			s02      => 'amp',
			e0       => 'enot',
			delr     => 'alpha*reff',
			sigma2   => 'debye([cv], theta) + sigmm',
		       });
};

=for Explain:
     now clone those 5 paths for the second data set, changing only those
     parameters that need to be different
     .
     note that the sigma2 path parameter does *not* need to be changed.
     the correct value will be substituted for "[cv]" before the fit is
     performed.  in this case, [cv] is the temperature of the measurement.
     .
     also note that the delr parameter does not need to be changed since 
     alpha was defined as an lguess parameter.  alpha will be rewritten
     for each data set.

=cut
my @paths_150k = ();
foreach my $i (0 .. 4) {
  my $j = $i+1;
  $paths_150k[$i] = $paths_010k[$i] -> clone({data     => $data_150k,
					      label    => "150K, path $j",
					     });
};

###--- make a Fit object (a collection of GDS, Data, and Path objects)
my $fitobject = Ifeffit::Demeter::Fit -> new({gds   => \@gdsobjects,
					      data  => [$data_010k, $data_150k],
					      paths => [@paths_010k, @paths_150k],
					     });
$fitobject -> serialize("mdsfit.dpj");
#exit;

$data_010k->po->legend({key_dy => 0.05, # set nice legend parameters for the plot
			key_x  => 0.8});

###--- do the fit (or the sum of paths)
$fitobject -> fit;
#$fitobject -> ff2chi($data_010k);
interview($fitobject);
exit;

###--- plot the data + fit + paths in a space
my $space = 'r';
$data_010k->po->set({plot_fit => 1,
		     plot_win => 0,
		     plot_res => 0,
		     kweight  => 2,
		     r_pl     =>'m',
		     'q_pl'   =>'r'});
foreach my $obj ($data_010k) { #, @paths_010k,) {
  $obj -> plot($space);
};
foreach my $obj ($data_150k) { #, @paths_150k,) {
  $obj -> plot($space);
};

##--- write files with fit results
#$data_010k->save("fit", "mdsfit_010.fit");
#$data_150k->save("fit", "mdsfit_150.fit");

###--- write a log file
my ($header, $footer) = ("Fit to 10K and 150K copper data\n", q{});
$fitobject -> logfile("mdsfit.log", $header, $footer);

###--- freeze the fit
$fitobject -> serialize("mdsfit.dpj");
