#!/usr/bin/perl

use strict;
use warnings;

use HTML::TableExtract;
use LWP::Simple;

use JSON qw(encode_json);

my $content = get("https://www.ncnr.nist.gov/resources/n-lengths/list.html");
die "Couldn't get it!" unless defined $content;

my $te = HTML::TableExtract->new( headers => ['Isotope', 'conc', 'Coh b', 'Inc b', 'Coh xs', 'Inc xs', 'Scatt xs', 'Abs xs'] );
$te->parse($content);

my %hash = ();

foreach my $ts ($te->tables) {
  foreach my $row ($ts->rows) {
    @$row = grep {s{\s+}{}g} @$row;

    $row->[0] =~ m{(\d*)(\w+)};
    my $element = $2;
    my $isotope = $1 || 'avg';
    $hash{$element}->{$isotope}->{concentration}            = $row->[1];
    $hash{$element}->{$isotope}->{coherent_length}          = $row->[2];
    $hash{$element}->{$isotope}->{incoherent_length}        = $row->[3];
    $hash{$element}->{$isotope}->{coherent_cross_section}   = $row->[4];
    $hash{$element}->{$isotope}->{incoherent_cross_section} = $row->[5];
    $hash{$element}->{$isotope}->{scattering_cross_section} = $row->[6];
    $hash{$element}->{$isotope}->{absolute_cross_section}   = $row->[7];
  };
};

open(my $J, '>', 'neutrons.json');
print $J encode_json(\%hash);
close $J;
