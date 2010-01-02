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

use Test::More tests => 14;

use Demeter;

use Readonly;
Readonly my $EPSILON => 1e-1;
my $plot = 0;

my %athena = (SSRLB	=> [20003.5,   'transmission'],
	      X10C	=> [8345.3,    'transmission'],
	      X15B	=> [2433.5,    'fluorescence'],
	      HXMA	=> [11866.5,   'transmission'],
	      PFBL12C	=> [12279.296, 'transmission'],
	      CMC	=> [2473.6,    'fluorescence'],
	      SSRLmicro	=> [11107.5,   'fluorescence'],
	     );

foreach my $type (keys %athena) {
  my $file  = "t/filetypes/" . lc($type) . ".dat";
  my $this  = 'Demeter::Plugins::'.$type;
  my $obj   = $this->new(file=>$file);
  ok( $obj->is, "File of type $type recognized");
  my $fixed = $obj->fix;
  my $e0    = dotest($obj, $fixed, $athena{$type}->[1]);
  ok( abs($e0 - $athena{$type}->[0]) < $EPSILON,  $obj->description . ": $e0" );
  unlink $fixed;
  $obj->DESTROY;
};



##'$6+$7+$8+$9+$10+$11+$12+$13+$14+$15+$16+$17+$18+$19+$20+$21+$22+$23+$24+$25+$26+$27+$28+$29+$30+$31+$32+$33+$34+$35+$36+$37'
sub dotest {
  my ($obj, $fixed, $mode) = @_;
  $mode ||= 'transmission';
  my $data = Demeter::Data->new(file=>$fixed, $obj->suggest($mode));
  $data->numerator('$6+$7+$8+$9+$10+$11+$12+$13+$14+$15+$16+$17+$18+$19+$20+$21+$22+$23+$24+$25+$26+$27+$28+$29+$30')
    if (ref($obj) =~ m{SSRLmicro});
  $data->_update('fft');
  if ($plot) {
    $data->po->start_plot;
    $data->po->set(emin=>-30, emax=>60);
    $data->plot('E');
    sleep 1;
  };
  return $data->bkg_e0;
};

