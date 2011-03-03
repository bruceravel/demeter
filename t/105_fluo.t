#!/usr/bin/perl -w

use Test::More tests => 4;
use Xray::FluorescenceEXAFS;

my $contents = {Y=>1, Ba=>2, Cu=>3, O=>7};

ok( abs(0.000463  - Xray::FluorescenceEXAFS->mcmaster("Cu", "K"))            < .00001,   "mcmaster correction");
ok( abs(0.0006166 - Xray::FluorescenceEXAFS->i0("Cu", "K", {nitrogen=>0.5})) < 0.000001, "i0 correction");

my @list = Xray::FluorescenceEXAFS->self("Cu", "K", $contents);
ok( abs(1.28      - $list[0]) < 0.01,    "self absorption, amplitude");
ok( abs(0.0000573 - $list[1]) < 0.00001, "self absorption, sigma^2");
