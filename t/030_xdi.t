#!/usr/bin/perl  -I/home/bruce/git/XAS-Data-Interchange/perl/lib

## Test import of XDI data file

=for Copyright
 .
 Copyright (c) 2008-2011 Bruce Ravel (bravel AT bnl DOT gov).
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

use Test::More tests => 7;

use Demeter;
use File::Basename;
use File::Spec;
use List::MoreUtils qw(any);

SKIP: {
    skip 'Xray::XDI is not available', 7 if (not exists $INC{'Xray/XDI.pm'});

    my $here  = dirname($0);
    my $file = File::Spec->catfile($here, 'cu_metal_rt.xdi');

    my $data  = Demeter::Data->new;
    my $xdi   = Xray::XDI->new;
    $xdi  -> file($file);
    $data -> import_xdi($xdi);

    ok( $data->xdi_version eq $Xray::XDI::VERSION,                     "version recognized");
    ok( $data->xdi_beamline->{name} eq "13ID",                         "defined header (Beamline.name) recognized");
    ok( $data->xdi_scan->{edge} eq "K",                                "defined header (Scan.edge) recognized");
    ok( (any {$_ eq "GSE.EXTRA: config 1"} @{$data->xdi_extensions}),  "extension header (MX.SRB) recognized");
    ok( $#{$data->xdi_comments} == 0,                                  "comments imported");
    ok( join(" ", @{$data->xdi_labels}) eq "energy i0 itrans mutrans", "labels imported");
    ok( $data->get_array('energy'),                                    "imported energy array");
  };
