#!/usr/bin/perl

## Test data provenance

=for Copyright
 .
 Copyright (c) 2008-2014 Bruce Ravel (http://bruceravel.github.io/home).
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

use Demeter qw(:data);
my $demeter  = Demeter -> new;
use Cwd;
use File::Basename;
use File::Spec;
my $here  = dirname($0);

my $orig = File::Spec->catfile($here, 'data.xmu');
my $file = $orig;

my $data = Demeter::Data->new(file=>$file);
$data->_update('data');
ok( $data->provenance =~ m{mu\(E\)},              "mu(E) file");

$orig = File::Spec->catfile($here, 'fe.060');
$file = $orig;
$data = Demeter::Data->new(file=>$file,
			   energy => '$1',
			   numerator => '$2',
			   denominator => '$3',
			   ln => 1,
			  );
$data->_update('data');
ok( $data->provenance =~ m{column data},          "column data");

$orig = File::Spec->catfile($here, 'cyanobacteria.prj');
$file = $orig;
my $prj = Demeter::Data::Prj->new(file=>$file);
$data=$prj->record(9);
ok( $data->provenance =~ m{Athena},               "Athena project record");

$orig = File::Spec->catfile($here, 're4chan.000');
$file = $orig;
my $mc = Demeter::Data::MultiChannel->new(file=>$file,
					  energy => '$1'
					 );
$data = $mc -> make_data(numerator=>'$2',
			 denominator=>'$6',
			 ln=>1
			);
ok( $data->provenance =~ m{multichannel},         "multichannel data file");
