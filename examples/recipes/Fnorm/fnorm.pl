#!/usr/bin/perl

use Demeter qw(:ui=screen);
Demeter -> set_mode(screen  => 1);

my $prj = Demeter::Data::Prj->new(file=>'per-Bruce.prj');

my $uncorr = $prj->record(1);
my $corr = $prj->record(2);

$uncorr->bkg_funnorm(1);
$corr->bkg_funnorm(0);
$uncorr->name('corrected by Demeter');
$corr->name('corrected by Giuliana');

Demeter->po->e_norm(1);
Demeter->po->e_bkg(0);
Demeter->po->kweight(2);
$uncorr->plot('k');
$corr->plot('k');
$uncorr->pause;
Demeter->po->start_plot;
$uncorr->plot('e');
$corr->plot('e');
$uncorr->pause;
