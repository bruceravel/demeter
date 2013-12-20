#!/usr/bin/perl

## Test quenching of Demeter::Data object using MooseX::Quenchable

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

use Test::More tests => 130;

use Demeter qw(:data);

my $d = Demeter::Data->new;
my $number_quanchable = 51;

my @qatts = ();
foreach my $a ($d->meta->get_attribute_list) {
  my $t = $d->meta->get_attribute($a)->applied_traits || [];
  push @qatts, $a if $d->meta->get_attribute($a)->does('MooseX::Quenchable::Attribute');
};
print join("|", @qatts, $#qatts), $/;

ok($#qatts == $number_quanchable, "found the correct number of quenchable attributes ($#qatts)");

#my %types = ();

foreach my $qa (@qatts) {
  my $start = $d->$qa;
  #++$types{$d->meta->get_attribute($qa)->type_constraint};
  $d -> quenched(0);
  if ($d->meta->get_attribute($qa)->type_constraint =~ m{(?:Num|NonNeg)\z}) {
    $d -> $qa($start+0.1);
    ok($d->$qa == $start+0.1, "can set $qa ---------------------------- (float)");

    $d -> quenched(1);
    $d -> $qa($start+0.2);
    ok($d->$qa == $start+0.1, "quenched data, cannot set $qa");

    $d -> quenched(0);
    $d -> $qa($start+0.2);
    ok($d->$qa == $start+0.2, "melted data, can set $qa");
    $d -> $qa($start);

  } elsif ($d->meta->get_attribute($qa)->type_constraint =~ m{(?:Int|Natural)\z}) {
    $d -> $qa($start+1);
    ok($d->$qa == $start+1, "can set $qa ---------------------------- (integer)");

    $d -> quenched(1);
    $d -> $qa($start+2);
    ok($d->$qa == $start+1, "quenched data, cannot set $qa");

    $d -> quenched(0);
    $d -> $qa($start+2);
    ok($d->$qa == $start+2, "melted data, can set $qa");
    $d -> $qa($start);

  } elsif ($d -> meta->get_attribute($qa)->type_constraint =~ m{Bool\z}) {
    $d -> $qa(not $start);
    ok(($d->$qa xor $start), "can set $qa ----------------------------- (boolean)");

    $d -> quenched(1);
    $d -> $qa($start);
    ok(($d->$qa xor $start), "quenched data, cannot set $qa");

    $d -> quenched(0);
    $d -> $qa($start);
    ok(($d->$qa == $start), "melted data, can set $qa");
    $d -> $qa($start);

  } elsif ($d -> meta->get_attribute($qa)->type_constraint =~ m{Str\z}) {
    $d -> $qa($start.'a');
    ok($d->$qa eq $start.'a', "can set $qa ----------------------------- (string)");

    $d -> quenched(1);
    $d -> $qa($start.'b');
    ok($d->$qa eq $start.'a', "quenched data, cannot set $qa");

    $d -> quenched(0);
    $d -> $qa($start.'b');
    ok($d->$qa eq $start.'b', "melted data, can set $qa");
    $d -> $qa($start);
  };
};

# foreach my $k (keys %types) {
#   printf "%2d: %s\n", $types{$k}, $k;
# };

## these are tested
#  4: Demeter::NumTypes::PosNum
# 16: Num
#  7: Demeter::NumTypes::NonNeg
#  2: Demeter::NumTypes::PosInt
#  2: Demeter::NumTypes::Natural
#  8: Bool
#  3: Str

## these are not
#  1: Demeter::StrTypes::Element
#  1: Demeter::StrTypes::Edge
#  1: Demeter::StrTypes::FitSpace
#  3: Demeter::StrTypes::Window
#  2: Any
#  1: ArrayRef
