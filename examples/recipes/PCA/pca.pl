#!/usr/bin/perl

use Demeter qw(:analysis);

my $prj = Demeter::Data::Prj -> new(file=>'../../cyanobacteria.prj');
my $pca = Demeter::PCA->new();


my @set = $prj->records(1-4);
$pca ->add(@set);
