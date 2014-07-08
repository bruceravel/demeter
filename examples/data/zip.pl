#!/usr/bin/perl

use Demeter qw(:data :p=gnuplot :ui=screen);
use File::Path;

my $this = Demeter::Plugins::Zip->new(file=>'examples/data/data.zip');
($this->is) ? print "this is a zip file\n" : print "this is not a zip file\n";
my $fixed = $this->fix;

Demeter->po->e_bkg(0);

## now do something whith each file extracted from the zip file
## note: that 'something' could be to test against some other plugin
foreach my $f (@{$this->fixed}) {
  my $data = Demeter::Data -> new();
  $data -> set(file   =>  $f,  datatype  => 'xmu',
	       energy => '$1', numerator => '$2', denominator => '$3', ln => 1, );
  $data->plot('E');
  $data->pause if ($f eq $this->fixed->[-1]); # pause on the last file
};
## give a hoot! don't pollute!
$this->clean;
