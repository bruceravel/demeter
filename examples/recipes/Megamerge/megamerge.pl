#!/usr/bin/perl

## grab the data from this zip file:
##    http://cars.uchicago.edu/ifeffit/Demeter?action=AttachFile&do=view&target=CLT_data.zip
## unpack in the same folder as this script

use File::Basename;
use File::Spec;
use Demeter qw(:plotwith=gnuplot :ui=screen :data);
use Demeter::Data::BulkMerge;

#Demeter->set_mode(template_process=>"larch", screen=>0);

## get a list of files to include
my $base = dirname($0);
#my $datadir = '/home/bruce/TeX/XAS-Education/Examples/Cr2O3';
my $datadir = File::Spec->catfile($base, 'data');
opendir(my $D, $datadir) || die "can't opendir $datadir: $!";
my @list = map {File::Spec->catfile($datadir, $_)} sort {$a cmp $b} grep { m{Cr2O3\.} && -f File::Spec->catfile($datadir, $_) } readdir $D;
closedir $D;

## import the first file in the list
my $first = shift @list;

my $plugin = Demeter::Plugins::X23A2MED->new(file=>$first);
my $ok = eval {$plugin->fix};
die $@ if $@;
my $master = Demeter::Data->new($plugin->data_attributes,
				name => "Cr2O3, first scan",
				bkg_e0=>6001, bkg_pre1=>-100, bkg_pre2=>-30,
			       );

## this is how it's done not using the plugin...
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

my $bm = Demeter::Data::BulkMerge->new(master	 => $master,
				       data	 => \@list,
				       plugin	 => 'X23A2MED',
				       align 	 => 1,
				       smooth 	 => 3,
				       subsample => [4, 16, 36, 64, 100],
				      );
my $merged = $bm->merge;
print join($/, @{$bm->skipped}), $/;

$master -> write_athena("quickmerge.prj", $merged, @{$bm -> sequence});
print "wrote sum of quickmerge.prj\n";
