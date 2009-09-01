#!/usr/bin/perl

## Test data provenance

=for Copyright
 .
 Copyright (c) 2008-2009 Bruce Ravel (bravel AT bnl DOT gov).
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

use Test::More tests => 4;

use Demeter;

my $data = Demeter::Data->new(file=>"data.xmu");
$data->_update('data');
ok( $data->provenance =~ m{mu\(E\)},              "mu(E) file");

$data = Demeter::Data->new(file=>"fe.060",
			   energy => '$1',
			   numerator => '$2',
			   denominator => '$3',
			   ln => 1,
			  );
$data->_update('data');
ok( $data->provenance =~ m{column data},          "column data");

my $prj = Demeter::Data::Prj->new(file=>"cyanobacteria.prj");
$data=$prj->record(9);
ok( $data->provenance =~ m{Athena},               "Athena project record");

my $mc = Demeter::Data::MultiChannel->new(file=>"re4chan.000",
					  energy => '$1'
					 );
$data = $mc -> make_data(numerator=>'$2',
			 denominator=>'$6',
			 ln=>1
			);
ok( $data->provenance =~ m{multichannel},         "multichannel data file");
