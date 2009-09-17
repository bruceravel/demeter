#!/usr/bin/perl
use Demeter qw(:ui=screen);
use List::Util qw(max);

my @common = (energy => '$1', numerator => '$2', denominator => '$3', ln => 1, );
my $place = '../../data/';

## import three similar scans, in this case, three scans of an Fe foil
my @data = (
	    Demeter::Data->new(file => $place . 'fe.060',
			       name => "Fe scan 1",
			       @common,
			      ),
	    Demeter::Data->new(file => $place . 'fe.061',
			       name => "Fe scan 2",
			       @common,
			      ),
	    Demeter::Data->new(file => $place . 'fe.062',
			       name => "Fe scan 3",
			       @common,
			      ),
	   );

$data[0]->plot_with('gnuplot');
$data[0]->set_mode(screen=>0);

## make a merged group
my $merged = $data[0]->merge('e', @data); # merge in mu(E)
#my $merged = $data[0]->merge('n', @data); # merge in normalized mu(E)
#my $merged = $data[0]->merge('k', @data); # merge in chi(k)

$merged->po->set(e_norm=>0,  kweight=>1);

## show the data and the merge
$_->plot('e') foreach ($merged, @data);
$merged -> pause;

## show the standard deviation plot
$merged -> plot('stddev');
$merged -> pause;

## show the variance plot
$merged -> plot('variance');
$merged -> pause;

$merged -> po -> end_plot;
