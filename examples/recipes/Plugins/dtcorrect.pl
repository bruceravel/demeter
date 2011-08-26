#!/usr/bin/perl

## this example demonstrates using an Athena filetype plugin to batch
## process data from the command line.  In this example, raw data in
## need of deadtime correction is batch processed into files of the
## same name, rewritten to have the deadtime correction applied.

## the example data is a motor scan measuring signal from the NSLS
## X23A2 4-element Vortex.  Thus it is an inconvenient file for
## reading into Athena, but it requires the same deadtime correction
## as XAS data measured with that detector.

## usage:
##
##   at the DOS command line do
##
##      C:\My data> perl dtcorrect.pl my_spiffy_data.*
##
##   this will read all data files "my_spiffy_data.000", "my_spiffy_data.001", etc;
##   perform the deadtime correction; and write files of the same names to a folder
##   called "dtcorr".


## import Demeter (we need its X23A2 plugin to do the dead time correction)
use Demeter;

## import some tools for munging files and filenames
use File::Basename;
use File::Copy;
use File::Spec;

## emulate a unix shell wildcard
@ARGV = map { glob } @ARGV;

## tell Demeter the name of the "energy" column
Demeter->co->set_default('x23a2med', 'energy', 'ot_pos');

## make a place to put the dead time corrected data
mkdir 'dtcorr' if not -d 'dtcorr';

foreach my $file (@ARGV) {
  print "$file";
  my $scan = Demeter::Plugins::X23A2MED->new(file=>$file);
  if (not $scan->is) {
    print " -- not an X23A2MED file";
    next;
  };
  ## perform the deatime correction and rewrite the data as a scratch file
  my $fixed = $scan->fix;
  ## copy the scratch file to the deadtime corrected data folder
  my $target = File::Spec->catfile('dtcorr', basename($file));
  copy($fixed, $target);
  print " --> $target\n";
};
