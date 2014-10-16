#!/usr/bin/perl/

use Demeter qw(:data);

my $file  = '/home/bruce/git/XAS-Data-Interchange/data/cu_metal_rt.xdi';
my $data  = Demeter::Data->new;
$data -> xdifile($file);

Demeter->Dump($data->xdi_attribute('metadata'));

print $data->xdi_datum('Mono', 'name'), $/;

Demeter->pjoin($data->xdi_families);
Demeter->pjoin($data->xdi_keys('Facility'));

print join("|", $data->xdi_attributes(qw(edge element floob dspacing))), $/;
