#!/usr/bin/perl

## Test Fit object functionality of Demeter under Moose

=for Copyright
 .
 Copyright (c) 2008-2013 Bruce Ravel (bravel AT bnl DOT gov).
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

use Test::More tests => 25;

use Demeter qw(:fit);
use List::MoreUtils qw(all);
use File::Basename;
use File::Spec;
my $here  = dirname($0);


my $this = Demeter::Fit -> new;
my $OBJ  = 'Fit';

ok( ref($this) =~ m{$OBJ},                    "made a $OBJ object");
ok(!$this->plottable,                         "$OBJ object is not plottable");
ok( $this->group =~ m{\A\w{5}\z},             "$OBJ object has a proper group name");
$this -> name('this');
ok( $this->name eq 'this',                    "$OBJ object has a settable label");
ok( $this->data,                              "$OBJ object has an associated Data object");
ok( ref($this->mo) =~ 'Mode',                 "$OBJ object can find the Mode object");
ok( ref($this->co) =~ 'Config',               "$OBJ object can find the Config object");
ok( ref($this->po) =~ 'Plot',                 "$OBJ object can find the Plot object");
ok( ($this->mo->template_plot     =~ m{plot}   and
     $this->mo->template_feff     eq 'feff6'   and
     $this->mo->template_process  eq 'ifeffit' and
     $this->mo->template_fit      eq 'ifeffit' and
     $this->mo->template_analysis eq 'ifeffit'),
                                                        "$OBJ object can find template sets");


## -------- populate a Fit object
my @gds  = (
	    Demeter::GDS -> new(gds=>'guess', name=>'amp',  mathexp=>1),
	    Demeter::GDS -> new(gds=>'guess', name=>'enot', mathexp=>0),
	    Demeter::GDS -> new(gds=>'guess', name=>'dcu',  mathexp=>0),
	    Demeter::GDS -> new(gds=>'guess', name=>'ss',   mathexp=>0.003),
	   );
my $data = Demeter::Data->new(file     => File::Spec->catfile($here, 'data.chi'),
			      name     => 'Cu 10K',
			      fft_kmin => 3,   fft_kmax => 12,
			      bft_rmin => 1,   bft_rmax => 2.6,
);
my $path = Demeter::Path->new(folder => $here,
			      file   => 'feff0001.dat',
			      data   => $data,
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
$this -> set_mode(screen=>0, backend=>1);
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
my $text = $this->template("report", "statistics");
@lines  = split(/\n/, $text);
ok( (($#lines == 7) and ($text =~ m{Number of variables})), 'statistics reporting seems ok');

@lines  = split(/\n/, $this->gds_report);
ok( $#lines == 4,                            'gds_report seems to run correctly');

@lines  = split(/\n/, $this->happiness_report);
ok( $#lines == 2,                             'happiness_report seems to run correctly');
ok( $this->color(0.623) eq '#FD7E6F',         'color computed correctly (0.632 should = #FD7E6F) -- '.$this->color(0.623));


## -------- utilities
ok( (not $this->fetch_gds('foobar')),         'fetch_gds, nonexistant parameter');
my $ggg = $this->fetch_gds('dcu');
ok( $ggg->[1] eq 'guess',                     'fetch_gds, existing parameter');

#print $this->summary;
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
