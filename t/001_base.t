#!/usr/bin/perl -I../lib

## Test base functionality of Demeter under Moose

=for Copyright
 .
 Copyright (c) 2008-2009 Bruce Ravel (bravel AT bnl DOT gov).
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

use List::MoreUtils qw(none);

my $demeter  = Demeter -> new;
my $demeter2 = Demeter -> new;

ok( defined($demeter) && blessed $demeter eq 'Demeter',    'new() works' );
ok( $demeter->group =~ m{\A\w{5}\z},                                'group is set: '.$demeter->group);
ok( $demeter->group ne $demeter2->group,                            'unique group names: '.$demeter->group.' & '.$demeter2->group);
ok( -d $demeter->location,                                          'installation location identified');
ok( $demeter->identify =~ m{copyright},                             'identity string');
#ok( ref($demeter->environment) eq 'HASH',                           'environment hash');
ok( !$demeter->plottable,                                           'generic object is not plottable');
ok( $demeter->data =~ m{\A\s*\z},                                   'generic object has no data');

ok( $demeter->stash_folder =~ m{horae},                             'Project role works');

my %hash = $demeter->all;
ok( (($hash{group} =~ m{\A\w{5}\z}) and !$hash{plottable}),         'demeter can do introspection');


## -------- disposal modes
ok( $demeter->get_mode('ifeffit'),                                  'ifeffit disposal mode flag: '.$demeter->get_mode('ifeffit'));
ok( !defined($demeter->get_mode('blarg')),                          'handle unknown mode gracefully');
my $this = none {$_} $demeter->get_mode(qw(screen file plotfile buffer repscreen repfile));
ok( $this,                                                          'other disposal modes all false');
## will need to test template objects and template sets

## toggle on various disposal modes and try to set an undefined mode
$demeter->set_mode(screen=>1, file=>"foo.bar", buffer=>[], blarg=>'fooey');
ok( $demeter->get_mode('screen'),                                   'turn on screen disposal mode flag');
ok( $demeter->get_mode('file') eq 'foo.bar',                        'turn on file disposal mode flag');
ok( ref($demeter->get_mode('buffer')) eq 'ARRAY',                   'turn on buffer disposal mode flag');


## other type constraint tests, see 002_types.t for exhaustive positive tests
ok(!Demeter::is_Window('Hamming'),                         'unknown window not recognized' );
ok( Demeter::is_Element('Cu'),                             'known element (Cu) is recognized' );
ok(!Demeter::is_Element('Ci'),                             'unknown element (Ci) not recognized' );

## simple tests of templates and the Disposal role -- see object specific test files for further tests
my $string = $demeter -> template("test", "test", {x=>5});
ok( $string =~ $demeter->group,                                     'simple template works');
$demeter->set_mode(screen=>0, file=>q{}, buffer=>q{});
$demeter->dispose($string);
ok( Ifeffit::get_scalar('a') == 5,                                  'simple disposal to Ifeffit: scalar');
ok( Ifeffit::get_array('t.x') == 5,                                 'simple disposal to Ifeffit: array');
$demeter->Reset;
ok( Ifeffit::get_scalar('a') == 0,                                  'simple disposal wrapper works');

SKIP: {
  eval { require Graphics::GnuplotIF };
  skip "Graphics::GnuplotIF not installed", 1 if $@;
  $demeter -> plot_with("gnuplot");
  ok( $demeter->get_mode("template_plot") eq 'gnuplot',             'plot_with works');
};
