#! /usr/bin/perl -w

#! /usr/bin/perl -w

use Test::More tests => 14;
use Xray::Absorption;

my $epsilon = 0.0001;
Xray::Absorption -> load("henke");

ok( Xray::Absorption -> current_resource =~ m{henke}i,       "loaded resource");
ok( Xray::Absorption -> in_resource("dy"),                      "found element Dy");

## fetch material properties
ok( abs(Xray::Absorption -> get_atomic_weight("dy") - 162.510) < $epsilon,   "atomic weight");
ok( abs(Xray::Absorption -> get_density("dy")       - 8.536)   < $epsilon,   "density");
ok( abs(Xray::Absorption -> get_conversion("dy")    - 269.8)   < $epsilon,   "conversion");

## fetch edge energies
ok( abs(Xray::Absorption -> get_energy("dy", "k") - 53788.5) < $epsilon,     "K edge");
ok( abs(Xray::Absorption -> get_energy("dy", "l1") - 9045.8) < $epsilon,     "L1 edge");
ok( abs(Xray::Absorption -> get_energy("dy", "l2") - 8580.6) < $epsilon,     "L2 edge");
ok( abs(Xray::Absorption -> get_energy("dy", "l3") - 7790.1) < $epsilon,     "L3 edge");
ok( abs(Xray::Absorption -> get_energy("dy", "m1") - 2046.8) < $epsilon,     "M1 edge");

## fetch fluorescence lines
ok( abs(Xray::Absorption -> get_energy("dy", "kalpha") - 45985 ) < $epsilon,  "Kalpha");
ok( abs(Xray::Absorption -> get_energy("dy", "kbeta" ) - 52178 ) < $epsilon,  "Kbeta");
ok( abs(Xray::Absorption -> get_energy("dy", "lalpha") - 6495.2) < $epsilon,  "Lalpha");
ok( abs(Xray::Absorption -> get_energy("dy", "lbeta")  - 7247.7) < $epsilon,  "Lbeta");
