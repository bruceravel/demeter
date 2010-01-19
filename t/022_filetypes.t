#!/usr/bin/perl

## Test filetype plugins

=for Copyright
 .
 Copyright (c) 2008-2010 Bruce Ravel (bravel AT bnl DOT gov).
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

use Test::More tests => 33;

use Demeter;

use Readonly;
Readonly my $EPSILON => 1e-1;
Readonly my $PLOT    => 0;

my %athena = (SSRLA	=> [25521.4,   'transmission'],
	      SSRLB	=> [20003.5,   'transmission'],
	      X10C	=> [8345.3,    'transmission'],
	      X15B	=> [2433.5,    'fluorescence'],
	      HXMA	=> [11866.5,   'transmission'],
	      PFBL12C	=> [12279.296, 'transmission'],
	      CMC	=> [2473.6,    'fluorescence'],
	      SSRLmicro	=> [11107.5,   'fluorescence'],
	      X23A2MED	=> [6554.2,    'fluorescence'],
	      Lytle 	=> [8979.15,   'transmission'],
	      DUBBLE    => [12660.9,   'fluorescence'],
	     );

foreach my $type (keys %athena) {
				## the test files are carefully named
  my $file  = "t/filetypes/" . lc($type) . ".dat";
  my $this  = 'Demeter::Plugins::'.$type;
				## test 1: check against a normal data file
  my $obj   = $this->new(file=>'t/fe.060');
  $obj     -> inifile('t/filetypes/x23a2vortex.ini') if (ref($obj) =~ m{X23A2MED});
  ok( (not $obj->is), "fe.060 is not of type $type");
  $obj     -> DESTROY;
				## test 2: check against a file of this type
  $obj      = $this->new(file=>$file);
  $obj     -> inifile('t/filetypes/x23a2vortex.ini') if (ref($obj) =~ m{X23A2MED});
  ok( $obj->is, "File of type $type recognized");
				## test 3: fix the data, import it as a Data object, check the e0 value
  my $fixed = $obj->fix;
  my $e0    = dotest($obj, $athena{$type}->[1]);
  ok( abs($e0 - $athena{$type}->[0]) < $EPSILON,  $obj->description . ": E0=$e0" );
				## clean up
  unlink $fixed;
  $obj     -> DESTROY;
};



##'$6+$7+$8+$9+$10+$11+$12+$13+$14+$15+$16+$17+$18+$19+$20+$21+$22+$23+$24+$25+$26+$27+$28+$29+$30+$31+$32+$33+$34+$35+$36+$37'
sub dotest {
  my ($obj, $mode) = @_;
  $mode ||= 'transmission';
  my $data = Demeter::Data->new(file=>$obj->fixed, $obj->suggest($mode));
  $data->numerator('$6+$7+$8+$9+$10+$11+$12+$13+$14+$15+$16+$17+$18+$19+$20+$21+$22+$23+$24+$25+$26+$27+$28+$29+$30')
    if (ref($obj) =~ m{SSRLmicro});
  $data->_update('fft');
  if ($PLOT) {
    $data->po->start_plot;
    $data->po->set(emin=>-30, emax=>150);
    $data->plot('E');
    sleep 1;
  };
  return $data->bkg_e0;
};

