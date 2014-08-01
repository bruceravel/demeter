#!/usr/bin/perl

## Test import of XDI data file

=for Copyright
 .
 Copyright (c) 2008-2014 Bruce Ravel (bravel AT bnl DOT gov).
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

use Demeter qw(:data);
use File::Basename;
use File::Spec;
use List::MoreUtils qw(any);

SKIP: {
    skip 'Xray::XDI is not available', 25 if (not exists $INC{'Xray/XDI.pm'});

    my $here  = dirname($0);
    my $file = File::Spec->catfile($here, 'cu_metal_rt.xdi');

    my $data  = Demeter::Data->new;
    $data    -> xdifile($file);

    ok( $data->xdi_attribute('xdi_version') == $Xray::XDI::VERSION,         "version recognized");
    ok( $data->xdi_attribute('ok'),                                         "XDI file ok");
    ok( (not $data->xdi_attribute('warning')),                              "no warnings");
    ok( (not $data->xdi_attribute('errorcode')),                            "no errorcode");
    ok( $data->xdi_attribute('extra_version') eq 'GSE/1.0',                 "extra version (moosish)");
    ok( $data->xdi_attribute('element') eq 'Cu',                            "element (moosish)");
    ok( $data->xdi_attribute('edge') eq 'K',                                "edge (moosish)");
    ok( abs($data->xdi_attribute('dspacing') - 3.13553) < 0.0001,           "d-spacing (moosish)");
    ok( $data->xdi_attribute('nmetadata') == 22,                            "nmetadata (moosish)");
    ok( $data->xdi_attribute('npts') == 408,                                "npts (moosish)");
    ok( $data->xdi_attribute('narrays') == 4,                               "narrays (moosish)");
    ok( $data->xdi_attribute('narray_labels') == 4,                         "narray labels (moosish)");


    my @list = $data->xdi_families;
    ok($#list == 8,                                                         sprintf("found correct number of families -- %d", $#list+1));
    @list = $data->xdi_keys('Facility');
    ok($#list == 2,                                                         sprintf("found correct number of keys in Facility -- %d",$#list+1));


    ok( $data->xdi_datum(qw(Beamline name)) eq "13ID",                      "defined header (Beamline.name) recognized -- " . $data->xdi_datum(qw(Beamline name)));
    ok( $data->xdi_datum(qw(Element edge)) eq "K",                          "defined header (Element.edge) recognized -- " . $data->xdi_datum(qw(Element edge)));
    ok( $data->xdi_datum(qw(GSE EXTRA)) eq "config 1",                      "extension header (GSE.EXTRA) recognized -- " . $data->xdi_datum(qw(GSE EXTRA)));


    @list = split(/\n/, $data->xdi_attribute('comments'));
    ok($#list == 1,                                                         sprintf("found correct number of user comment lines -- %d",$#list+1));

    @list = @{$data->xdi_attribute('array_labels')};
    ok($#list+1 == $data->xdi_attribute('narray_labels'),                   sprintf("found correct number of column labels -- %d",$#list+1));
    ok((($list[0] eq 'energy') and ($list[1] eq 'i0') and ($list[2] eq 'itrans') and ($list[3] eq 'mutrans')),

                                                                            "column labels fetched correctly");
    ##my %hash = %{$data->xdi_attribute('metadata')};
    ##ok(scalar(keys(%hash)) == $data->xdi_attribute('nmetadata'),            sprintf("found correct number of metadata items -- %d",scalar(keys(%hash))));

    my @e = $data->xdi_get_array('energy');
    ok(@e ,                                                                 "imported energy array");
    ok($#e+1 == $data->xdi_attribute('npts') ,                              "identified number of data points");
    @e = $data->xdi_get_iarray(2);
    ok(@e ,                                                                 "imported second array");
    ok($#e+1 == $data->xdi_attribute('npts') ,                              "identified number of data points by iarray");

    $data->xdi->set_item('Element', 'edge', 'L3');
    ok((($data->xdi_datum(qw(Element edge)) eq "L3") and ($data->xdi_datum(qw(Beamline name)) eq "13ID")),
                                                                           "setting works");
  };
