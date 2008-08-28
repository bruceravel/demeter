#!/usr/bin/perl -I/home/bruce/codes/demeter/lib

=for Copyright
 .
 Copyright (c) 2006-2008 Bruce Ravel (bravel AT anl DOT gov).
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
#use Smart::Comments;
use Ifeffit::Demeter;
use Ifeffit::Demeter::UI::Screen::Probe qw(interview);
print "Sample fit to copper data using Demeter ", $Ifeffit::Demeter::VERSION, $/;
unlink "cufit.iff" if (-e "cufit.iff");
Ifeffit::Demeter->set_mode({screen  => 0,
			    ifeffit => 1,
			    file => ">cufit.iff",
			    template_process => "iff_columns",
			    template_fit     => "iff_columns",
			   });
Ifeffit::Demeter->plot_with('gnuplot');
my $plot_features = Ifeffit::Demeter->get_mode("plot");

### make a Data object and set the FT and fit parameters
my $dobject = Ifeffit::Demeter::Data -> new({group => 'data0',});
$dobject ->set({file      => "cu10k.chi",
		fft_kmax  => 3, # \ note that this gets
		fft_kmin  => 14,# / fixed automagically
		fit_space => 'r',
		fit_k1    => 1,
		fit_k3    => 1,
		bft_rmin  => 1.6,
		bft_rmax  => 4.3,
		fit_do_bkg => 0,
		label     => 'My copper data',
	       });

### make GDS objects for an isotropic expansion, correlated Debye model fit to copper
my @gdsobjects =  (Ifeffit::Demeter::GDS -> new({type => 'guess', name => 'alpha', mathexp => 0}),
		   Ifeffit::Demeter::GDS -> new({type => 'guess', name => 'amp',   mathexp => 1}),
		   Ifeffit::Demeter::GDS -> new({type => 'guess', name => 'enot',  mathexp => 0}),
		   Ifeffit::Demeter::GDS -> new({type => 'guess', name => 'theta', mathexp => 500}),
		   Ifeffit::Demeter::GDS -> new({type => 'set',   name => 'temp',  mathexp => 300}),
		   Ifeffit::Demeter::GDS -> new({type => 'set',   name => 'sigmm', mathexp => 0.00052}),
		  );

### make Path objects for the first 5 paths in copper (3 shell fit)
my @pobjects = ();
foreach my $i (0 .. 4) {
  my $j = $i+1;
  $pobjects[$i] = Ifeffit::Demeter::Path -> new();
  $pobjects[$i]->set({data     => $dobject,
		      folder   => './',
		      file     => "feff000$j.dat",
		      s02      => 'amp',
		      e0       => 'enot',
		      delr     => 'alpha*reff',
		      sigma2   => 'debye(temp, theta) + sigmm',
		     });
};

### make a Fit object, which is just a collection of GDS, Data, and Path objects
my $fitobject = Ifeffit::Demeter::Fit -> new({gds   => \@gdsobjects,
					      data  => [$dobject],
					      paths => \@pobjects,
					     });

### do the fit (or the sum of paths)
$fitobject -> sum;

interview($fitobject);

exit;

# ## set nice legend parameters for the plot
# $plot_features->legend({key_dy=>0.05, key_x=>0.8});

# exit if (Ifeffit::Demeter->get_mode("process") eq "feffit");
# ## plot the data + fit + paths
# my $space = 'r';
# $plot_features->set({plot_data => 1,
# 		     plot_fit  => 1,
# 		     plot_bkg  => 0,
# 		     plot_res  => 0,
# 		     plot_win  => 1,
# 		     kweight   => 2,
# 		     r_pl      => 'm',
# 		     'q_pl'    => 'r',
# 		    });
# my $s = 0;  # stack the plot interestingly...
# foreach my $obj ($dobject, @pobjects,) {
#   $obj -> plot($space);
#   $s -= 0.8;
#   $dobject -> set({'y_offset'=>$s});
# };

# ## save the results of the fit
# $dobject->save("fit", "cufit.fit");
# #$pobjects[0]->save("r", "path0.r");

# ## write a log file
# my ($header, $footer) = ("Fit to copper data", q{});
# $fitobject -> logfile("cufit.log", $header, $footer);

# #$fitobject -> serialize("cufit");
# #$dobject->screen_echo(1);
# #$dobject->dispose("show \@arrays");
