#!/usr/bin/perl -I../lib

## Test Fit object functionality of Demeter under Moose

=for Copyright
 .
 Copyright (c) 2008 Bruce Ravel (bravel AT bnl DOT gov).
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

use Test::More tests => 23;

use Ifeffit;
use Demeter;
use List::MoreUtils qw(all);


my $this = Demeter::Fit -> new;
my $OBJ  = 'Fit';

ok( ref($this) =~ m{$OBJ},                              "made a $OBJ object");
ok(!$this->plottable,                                   "$OBJ object is not plottable");
ok( $this->group =~ m{\A\w{5}\z},                       "$OBJ object has a proper group name");
$this -> name('this');
ok( $this->name eq 'this',                              "$OBJ object has a settable label");
ok( $this->data,                                        "$OBJ object has an associated Data object");
ok( ref($this->mode) =~ 'Mode',                         "$OBJ object can find the Mode object");
ok( ref($this->mode->config) =~ 'Config',               "$OBJ object can find the Config object");
ok( ref($this->mode->plot) =~ 'Plot',                   "$OBJ object can find the Plot object");
ok( ($this->mode->template_plot     eq 'pgplot'  and
     $this->mode->template_feff     eq 'feff6'   and
     $this->mode->template_process  eq 'ifeffit' and
     $this->mode->template_fit      eq 'ifeffit' and
     $this->mode->template_analysis eq 'ifeffit'),
                                                        "$OBJ object can find template sets");


## -------- populate a Fit object
my @gds  = (
	    Demeter::GDS -> new(Type=>'guess', name=>'amp',  mathexp=>1),
	    Demeter::GDS -> new(Type=>'guess', name=>'enot', mathexp=>0),
	    Demeter::GDS -> new(Type=>'guess', name=>'dcu',  mathexp=>0),
	    Demeter::GDS -> new(Type=>'guess', name=>'ss',   mathexp=>0.003),
	   );
my $data = Demeter::Data->new(file     => 't/data.chi',
			      name     => 'Cu 10K',
			      fft_kmin => 3,   fft_kmax => 12,
			      bft_rmin => 1,   bft_rmax => 2.6,
);
my $path = Demeter::Path->new(folder => 't',
			      file   => 'feff0001.dat',
			      data   => $data,
			      Index  => 1,
			      name   => 'first shell',
			      s02    => 'amp',  e0     => 'enot',
			      delr   => 'dcu',  sigma2 => 'ss',
			     );
$this -> push_gds(@gds);
$this -> push_data($data);
$this -> push_paths($path);


## -------- test that the Fit object was populated correctly
ok( $#{ $this->gds   } == 3,  'set gds array attribute');
ok( $#{ $this->data  } == 0,  'set data array attribute');
ok( $#{ $this->paths } == 0,  'set paths array attribute');


## -------- run a fit
$this -> set_mode(screen=>0, ifeffit=>1);
$this->fit;


# -------- test correlations methods
ok( $this->correl(qw(amp ss)) > 0.9,          'grabbing a high correlation: C(amp,ss) > 0.9 : '.$this->correl(qw(amp ss)));
ok( $this->correl(qw(amp enot)) < 0.2,        'grabbing a low correlation:  C(amp,e0) < 0.2 : '.$this->correl(qw(amp enot)));
my %all = $this->all_correl;
ok( keys(%all) == 6,                          'can grab all correlations');
$this->cormin(0.5);
my @lines  = split(/\n/, $this->correl_report($this->cormin));
ok( $#lines == 3,                             'correl_report returns the correct number of lines');


## -------- log file methods
@lines  = split(/\n/, $this->statistics_report);
ok( (($#lines == 7) and ($this->statistics_report =~ m{Number of variables})), 'statistics_report seems to run correctly');

@lines  = split(/\n/, $this->gds_report);
ok( $#lines == 14,                            'gds_report seems to run correctly');

@lines  = split(/\n/, $this->happiness_report);
ok( $#lines == 2,                             'happiness_report seems to run correctly');
ok( $this->color(0.623) eq '#FD7E6F',         'color computed correctly (0.632 should = #FD7E6F) -- '.$this->color(0.623));





#$this->po->plot_fit(1);
#$_ -> plot('r') foreach ($data, $path);


## -------- artifically set various things to test happiness penalties
$this -> r_factor(0.04);
my @list = $this->_penalize_rfactor;
ok( $list[0] == 20,  'R-factor penalty computed correctly');

$this -> n_idp(9);
$this -> n_varys(7);
@list = $this->_penalize_nidp;
ok( abs($list[0] - 40/3) < 0.001,  'nidp penalty computed correctly');

$path -> e0_value(30);
$path -> sigma2_value(-0.001);
@list = $this->_penalize_pathparams;
ok( $list[0] == 4,  'path parameters penalty computed correctly');
