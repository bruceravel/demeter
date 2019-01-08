#!/usr/bin/perl

## Test GDS object functionality of Demeter under Moose

=for Copyright
 .
 Copyright (c) 2008-2019 Bruce Ravel (http://bruceravel.github.io/home).
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


use Test::More tests => 28;

use Demeter qw(:fit);

my $this = Demeter::GDS->new();
my $OBJ  = 'GDS';

ok( ref($this) =~ m{$OBJ},        "made a $OBJ object");
ok(!$this->plottable,             "$OBJ object is not plottable");
ok( $this->group =~ m{\A\w{5}\z}, "$OBJ object has a proper group name");
$this -> name('this');
ok( $this->name eq 'this',        "$OBJ object has a settable label");
ok(!$this->data,                  "$OBJ object has no associated Data object");
ok( ref($this->mo) =~ 'Mode',     "$OBJ object can find the Mode object");
ok( ref($this->co) =~ 'Config',   "$OBJ object can find the Config object");
ok( ref($this->po) =~ 'Plot',     "$OBJ object can find the Plot object");
my $which = (Demeter->is_larch) ? 'larch' : 'ifeffit';
ok( ($this->mo->template_plot     =~ m{plot}   and
     $this->mo->template_feff     eq 'feff6'   and
     $this->mo->template_process  eq $which and
     $this->mo->template_fit      eq $which and
     $this->mo->template_analysis eq $which),
                                        "GDS object can find template sets");
$this -> set(name=>'foo', gds=>'guess', mathexp=>5);
if (Demeter->is_ifeffit) {
  ok( $this -> write_gds =~ m{\Aguess\s+foo\s+=\s+5},                 "write_gds works: simple (ifeffit)");
} else {
  ok( $this -> write_gds =~ m{\Agds.foo\s+=\s+param\(5.\s+vary=True\)}, "write_gds works: simple (larch)");
};
$this -> set(name=>'foo', gds=>'def', mathexp=>'sin(blarg)+a**5');

if (Demeter->is_ifeffit) {
  ok( $this -> write_gds =~ m{\Adef\s+foo\s+=\s+sin\(blarg\)\+a\*\*5}, "write_gds works: mathexp (ifeffit)");
} else {
  ok( $this -> write_gds =~ m{\Agds.foo\s+=\s+param\(expr\s*=\s*'sin\(blarg\)\+a\*\*5'\)}, "write_gds works: mathexp (larch)");
};

$this -> annotate('Hi there!');
ok( (($this->note eq 'Hi there!') and (not $this->autonote)),  'annotate works');

my $rep = $this -> report(1);
ok( (($rep =~ m{def}) and ($rep =~ m{foo}) and ($rep =~ m{blarg})),  'report works');
$rep = $this -> full_report;
ok( (($rep =~ m{def}) and ($rep =~ m{foo}) and ($rep =~ m{blarg}) and ($rep =~ m{there})),  'full report works');


$this -> set(name=>'foo', gds=>'guess', mathexp=>5);
$this -> dispose($this);
$this -> autonote(1);
$this -> evaluate;
ok( (($this->mathexp == 5) and ($this->error == 0) and ($this->note =~ m{0\s+\+/\-\s+0})), "evaluate works");

my $i = 0;
foreach my $t (@Demeter::StrTypes::gds_list) {
  $this -> gds($t);
  ++$i;
  ok( $this -> gds eq $t,   "type $i ($t) can be set");
};

foreach my $w (@Demeter::StrTypes::notreserved_list) {
  { no warnings;		# quiet an unimportant warning from the eval
    eval "$this->name(\"$w\")";
    ok($@, "refused to set name to a reserved word: $w");
  }
};
