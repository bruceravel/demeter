#!/usr/bin/perl

## Test use of directed graph for finding cycles in parameter definitions

=for Copyright
 .
 Copyright (c) 2008-2015 Bruce Ravel (http://bruceravel.github.io/home).
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

use Test::More tests => 4;

use Demeter qw(:fit);
use Demeter::StrTypes qw( IfeffitFunction IfeffitProgramVar );
use Graph;
use Demeter::Constants qw($NUMBER);

my @params = (
	      Demeter::GDS->new(gds=>'guess', name=>'a', mathexp=>5),
	      Demeter::GDS->new(gds=>'def',   name=>'b', mathexp=>"5*a"),
	      Demeter::GDS->new(gds=>'def',   name=>'c', mathexp=>"10**a"),
	      Demeter::GDS->new(gds=>'def',   name=>'d', mathexp=>"sin(b + c)"),
	      Demeter::GDS->new(gds=>'def',   name=>'e', mathexp=>"exp(-1*d)"),
	     );

my $tokenizer_regexp = '(?-xism:(?=[\t\ \(\)\*\+\,\-\/\^])[\-\+\*\^\/\(\)\,\ \t])';
#my $tokenizer_regexp = $opt->list2re('-', '+', '*', '^', '/', '(', ')', ',', " ", "\t");

my $graph = make_graph(@params);
ok( (not $graph->has_a_cycle),   "recognize acyclic graph");

$params[2] = Demeter::GDS->new(gds=>'def',   name=>'c', mathexp=>"10*E");
$graph = make_graph(@params);
ok( $graph->has_a_cycle,         "recognize cyclic graph " . join(" -> ", $graph->find_a_cycle));

$params[2] = Demeter::GDS->new(gds=>'def',   name=>'c', mathexp=>"10*a");
$graph = make_graph(@params);
ok( (not $graph->has_a_cycle),   "fixed cyclic graph");

push @params, Demeter::GDS->new(gds=>'def',   name=>'s', mathexp=>"5*S");
$graph = make_graph(@params);
ok( $graph->self_loop_vertices,  "recognize looped parameter " . join(" ", $graph->self_loop_vertices));


sub make_graph {
  my @params = @_;
  my $graph = Graph->new;
  foreach my $g (@params) {
    next if ($g->gds =~ m{(?:merge|skip)});
    my $mathexp = $g->mathexp;
    my @list = split(/$tokenizer_regexp+/, lc($mathexp));
    foreach my $token (@list) {
      next if ($token =~ m{\A\s*\z});		  # space, ok
      next if ($token =~ m{\A$NUMBER\z});	  # number, ok
      next if (is_IfeffitFunction($token));       # function, ok
      next if ($token =~ m{\A(?:etok|pi)\z});     # Ifeffit's defined constants, ok
      next if (lc($token) eq 'reff');             # reff, ok
      $graph -> add_edge(lc($g->name), $token);
    };
  };
  return $graph;
};
