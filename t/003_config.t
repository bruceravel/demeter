#!/usr/bin/perl

## Test Config object functionality of Demeter under Moose

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

use Test::More tests => 24;

use File::Basename;
use File::Spec;
my $here  = dirname($0);

my @plugins = qw(10bmmultichannel x23a2med);
my $plregex = join("|", @plugins);
my $number_of_groups = 28;

use Demeter;

my $demeter  = Demeter -> new;
my $demeter2 = Demeter -> new;

ok( ref($demeter->co) =~ 'Config',                                    'found a config object');
ok(!$demeter->co->plottable,                                          "Config object is not plottable");
ok(!$demeter->co->data,                                               "Config object has no associated Data object");
#ok( ref($demeter->config->mode) =~ 'Mode',                                'Config object can find the Mode object');
ok( $demeter->co->group =~ m{\A\w{5}\z},                              'Config object has a proper group name');
#$data -> name('this');
#ok( $demeter->config->name eq 'this',                                     'Config object has a settable label');


ok( $demeter->co->default (qw(bkg kw))        == 2,                   'read a configuration number: bkg:kw=2');
ok( $demeter->co->default (qw(fit space))     eq 'r',                 'read a configuration string: fit:space=r');
ok( $demeter->co->Type    (qw(bkg kw))        eq 'positive integer',  'Type accessor method');
ok( $demeter->co->maxint  (qw(bkg kw))        == 3,                   'maxint accessor method');
ok( $demeter->co->minint  (qw(plot charfont)) == 0,                   'minint accessor method');
ok( $demeter->co->units   (qw(bkg spl1))      eq 'inverse Angstroms', 'units accessor method');
ok( $demeter->co->options (qw(fit space))     eq 'k r q',             'options accessor method');
ok( $demeter->co->onvalue (qw(fit k1))        == 1,                   'onvalue accessor method');
ok( $demeter->co->offvalue(qw(fit k1))        == 0,                   'offvalue accessor method');
ok( $demeter->co->demeter (qw(bkg kw))        == 2,                   'demeter accessor method');


$demeter->co->set(var1 => 7, var2 => 'foo');
ok( $demeter2->co->get("var1") == 7,              'wrote and read an arbitrary config parameter: number');
ok( $demeter2->co->get("var2") eq 'foo',          'wrote and read an arbitrary config parameter: string');

my @groups = grep {$_ !~ m{$plregex}} $demeter->co->groups;
ok( ($groups[0] eq 'artemis' and $#groups == $number_of_groups), 'configuration system introspection works: groups '.$#groups.' '.$groups[0]);
my $groups = $demeter->co->main_groups;
ok( ($#{$groups} == $number_of_groups),                          'configuration system introspection works: main_groups '.$#groups);

my @parameters = $demeter->co->parameters('happiness');
ok( ($parameters[0] eq 'average_color' and $#parameters == 13),  'configuration system introspection works: group parameters');

$demeter->co->read_config(File::Spec->catfile($here, 'test.demeter_conf'));
ok( (not $demeter->co->default(qw(testing boolean))),            'reading boolean from arbitrary config file');
ok( $demeter->co->default(qw(testing string))  eq 'Hi there!',   'reading string from arbitrary config file');
ok( $demeter->co->default(qw(testing real))    == 1.0,           'reading real from arbitrary config file');

@groups = grep {$_ !~ m{$plregex}} $demeter->co->groups;
ok( ($#groups == $number_of_groups+1),                           'introspection after reading new group: groups');
$groups = $demeter->co->main_groups;
ok( ($#{$groups} == $number_of_groups),                          'introspection after reading new group: main_groups');

#my $first = $demeter->co;
#my $new = Demeter::Config->new('Demeter::Config');
#print $first, " ", $new, $/;
