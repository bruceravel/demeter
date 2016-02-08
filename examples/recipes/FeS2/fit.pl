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


use Demeter qw(:fit);
print "Fit to FeS2 data using Demeter ", $Demeter::VERSION, $/;
unlink "fes2.iff" if (-e "fes2.iff");

print "Import data from an Athena project file\n";
my $prj = Demeter::Data::Prj -> new(file=>'FeS2.prj');
my $data = $prj -> record(1);
$data ->set(fft_kmin   => 3,	       fft_kmax   => 12,
	    bft_rmin   => 1.2,         bft_rmax   => 4.1,
	   );

$data->set_mode(screen  => 0, backend => 1); #, file => ">fes2.iff", );
$data -> plot_with('gnuplot');    ## similar to the :plotwith pragma

my @gds =  (Demeter::GDS -> new(gds => 'guess', name => 'alpha', mathexp => 0),
	    Demeter::GDS -> new(gds => 'guess', name => 'amp',   mathexp => 1),
	    Demeter::GDS -> new(gds => 'guess', name => 'enot',  mathexp => 0),
	    Demeter::GDS -> new(gds => 'guess', name => 'ss',    mathexp => 0.003),
	    Demeter::GDS -> new(gds => 'guess', name => 'ss2',   mathexp => 0.003),
	    Demeter::GDS -> new(gds => 'def',   name => 'ss3',   mathexp => 'ss2'),
	    Demeter::GDS -> new(gds => 'guess', name => 'ssfe',  mathexp => 0.003),
	   );

my $atoms = Demeter::Atoms->new(file=>'FeS2.inp');
my $feff = Demeter::Feff -> new(atoms=>$atoms);
$feff   -> set(workspace=>"temp", screen=>0);
$feff   -> run;
print "Done with feff\n";
my @sp   = @{$feff->pathlist};
#print $feff -> intrp;
#exit;

my @paths = ();
push(@paths, Demeter::Path -> new(sp     => $sp[0],
				  data   => $data,
				  s02    => 'amp',
				  e0     => 'enot',
				  delr   => 'alpha*reff',
				  sigma2 => 'ss'
				 ));
push(@paths, Demeter::Path -> new(sp     => $sp[1],
				  data   => $data,
				  s02    => 'amp',
				  e0     => 'enot',
				  delr   => 'alpha*reff',
				  sigma2 => 'ss2'
				 ));
push(@paths, Demeter::Path -> new(sp     => $sp[2],
				  data   => $data,
				  s02    => 'amp',
				  e0     => 'enot',
				  delr   => 'alpha*reff',
				  sigma2 => 'ss3'
				 ));
push(@paths, Demeter::Path -> new(sp     => $sp[4],
				  data   => $data,
				  s02    => 'amp',
				  e0     => 'enot',
				  delr   => 'alpha*reff',
				  sigma2 => 'ssfe'
				 ));
push(@paths, Demeter::Path -> new(sp     => $sp[6],
				  data   => $data,
				  s02    => 'amp',
				  e0     => 'enot',
				  delr   => 'alpha*reff',
				  sigma2 => 'ss*1.5'
				 ));
push(@paths, Demeter::Path -> new(sp     => $sp[7],
				  data   => $data,
				  s02    => 'amp',
				  e0     => 'enot',
				  delr   => 'alpha*reff',
				  sigma2 => 'ss/2 + ssfe'
				 ));
push(@paths, Demeter::Path -> new(sp     => $sp[13],
				  data   => $data,
				  s02    => 'amp',
				  e0     => 'enot',
				  delr   => 'alpha*reff',
				  sigma2 => 'ss*2'
				 ));
push(@paths, Demeter::Path -> new(sp     => $sp[14],
				  data   => $data,
				  s02    => 'amp',
				  e0     => 'enot',
				  delr   => 'alpha*reff',
				  sigma2 => 'ss*2'
				 ));
push(@paths, Demeter::Path -> new(sp     => $sp[15],
				  data   => $data,
				  s02    => 'amp',
				  e0     => 'enot',
				  delr   => 'alpha*reff',
				  sigma2 => 'ss*4'
				 ));

foreach my $p (@paths) {
  $p->sp->cleanup(0);
};

my $fit = Demeter::Fit -> new(name  => 'FeS2 fit',
			      gds   => \@gds,
			      data  => [$data],
			      paths => \@paths
			     );
print "about to fit\n";
$fit -> fit;

$data->po->set(plot_data => 1, plot_fit  => 1, );
$data->plot('rmr');
$data->pause;

my $keypress = <STDIN>;


my ($header, $footer) = ("Fit to FeS2 data", q{});
$fit -> logfile("fes2.log", $header, $footer);

exit;

