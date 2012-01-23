#!/usr/bin/perl

## to do:
##   1. toggle btwn deadtime correcting and not
##   2. aligning
##   3. set and recognize quickmerge attribute to remove unecessary ifeffit commands
##   4. Save after 4, 9, 25, 64, 100 -> export to a prj


use File::Basename;
use File::Spec;
use Demeter qw(:plotwith=gnuplot :ui=screen);

## get a list of files to include
my $base = dirname($0);
my $datadir = File::Spec->catfile($base, 'data');
opendir(my $D, $datadir) || die "can't opendir $datadir: $!";
my @list = map {File::Spec->catfile($datadir, $_)} sort {$a cmp $b} grep { m{\.} && -f File::Spec->catfile($datadir, $_) } readdir $D;
closedir $D;

## import the first file in the list
my $first = shift @list;

my $plugin = Demeter::Plugins::X23A2MED->new(file=>$first);
my $ok = eval {$plugin->fix};
die $@ if $@;
my $master = Demeter::Data->new(file => $plugin->fixed, $plugin->suggest('fluorescence'),
				name => "Cr2O3, first scan",
				bkg_e0=>6001, bkg_pre1=>-100, bkg_pre2=>-30,
			       );

# my $master = Demeter::Data->new(file        => $first,
# 				energy	    => '$1',
# 				numerator   => '$4+$5+$6+$7',
# 				denominator => '$2',
# 				ln	    => 0,
# 				name        => "Cr2O3, first scan",
# 				bkg_e0=>6001, bkg_pre1=>-100, bkg_pre2=>-30,
# 			       );

$master -> _update('normalize');
$master -> po -> set(e_mu=>1, e_norm=>1, e_bkg=>0, e_pre=>0, e_post=>0, emin=>-100, emax=>600, kweight=>2);
$master -> plot('E');

my $bm = Demeter::Data::BulkMerge->new(master => $master,
				       data   => \@list,
				       size   => -s $first,
				       plugin => 'X23A2MED',
				       # align > 1,
				      );
my $merged = $bm->merge;

$merged -> plot('E');
$merged -> pause;

$master -> po->start_plot;
$master -> plot('k');
$merged -> plot('k');
$merged -> pause;
