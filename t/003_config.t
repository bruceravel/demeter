#!/usr/bin/perl -I../lib

## Test Config object functionality of Demeter under Moose

=for Copyright
 .
 Copyright (c) 2008 Bruce Ravel (bravel AT bnl DOT gov).
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
 
use Test::More tests => 23;

use Ifeffit;
use Demeter;

my $demeter  = Demeter -> new;
my $demeter2 = Demeter -> new;

ok( ref($demeter->mode->config) =~ 'Config',                                    'found a config object');
ok(!$demeter->mode->config->plottable,                                          "Config object is not plottable");
ok(!$demeter->mode->config->data,                                               "Config object has no associated Data object");
#ok( ref($demeter->config->mode) =~ 'Mode',                                'Config object can find the Mode object');
#ok( $demeter->config->group =~ m{\A\w{5}\z},                              'Config object has a proper group name');
#$data -> name('this');
#ok( $demeter->config->name eq 'this',                                     'Config object has a settable label');


ok( $demeter->mode->config->default (qw(bkg kw))        == 2,                   'read a configuration number: bkg:kw=2');
ok( $demeter->mode->config->default (qw(fit space))     eq 'r',                 'read a configuration string: fit:space=r');
ok( $demeter->mode->config->Type    (qw(bkg kw))        eq 'positive integer',  'Type accessor method');
ok( $demeter->mode->config->maxint  (qw(bkg kw))        == 3,                   'maxint accessor method');
ok( $demeter->mode->config->minint  (qw(plot charfont)) == 0,                   'minint accessor method');
ok( $demeter->mode->config->units   (qw(bkg spl1))      == 'inverse Angstroms', 'units accessor method');
ok( $demeter->mode->config->options (qw(fit space))     eq 'k r q',             'options accessor method');
ok( $demeter->mode->config->onvalue (qw(fit k1))        == 1,                   'onvalue accessor method');
ok( $demeter->mode->config->offvalue(qw(fit k1))        == 0,                   'offvalue accessor method');
ok( $demeter->mode->config->demeter (qw(bkg kw))        == 2,                   'demeter accessor method');


$demeter->mode->config->set(var1 => 7, var2 => 'foo');
ok( $demeter2->mode->config->get("var1") == 7,              'wrote and read an arbitrary config parameter: number');
ok( $demeter2->mode->config->get("var2") eq 'foo',          'wrote and read an arbitrary config parameter: string');

my @groups = $demeter->mode->config->groups;
ok( ($groups[0] eq 'atoms' and $#groups == 16),                  'configuration system introspection works: groups');
my $groups = $demeter->mode->config->main_groups;
ok( ($#{$groups} == 16),                                         'configuration system introspection works: main_groups');

my @parameters = $demeter->mode->config->parameters('happiness');
ok( ($parameters[0] eq 'average_color' and $#parameters == 10),  'configuration system introspection works: group parameters');

$demeter->co->read_config('test.demeter_conf');
ok( (not $demeter->co->default(qw(testing boolean))),            'reading boolean from arbitrary config file');
ok( $demeter->co->default(qw(testing string))  eq 'Hi there!',   'reading string from arbitrary config file');
ok( $demeter->co->default(qw(testing real))    == 1.0,           'reading real from arbitrary config file');
@groups = $demeter->mode->config->groups;
ok( ($#groups == 17),                                            'introspection after reading new group: groups');
$groups = $demeter->mode->config->main_groups;
ok( ($#{$groups} == 16),                                         'introspection after reading new group: main_groups');
