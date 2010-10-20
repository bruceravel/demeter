#!/usr/bin/perl

use Demeter qw(:ui=screen :plotwith=gnuplot);

my $data = Demeter::Data->new(file        => 'fe73ga27.010',
			      energy      => '$1',
			      numerator   => '$3',
			      denominator => '$2',
			      ln          =>  0
			      );

$data->set_mode(screen=>0);
my $how = $ARGV[0] || 'booth';
my ($sadata, $text) = $data->sa($how, formula=>"Fe72.74Ga27.26");

my $space = ($how eq 'fluo') ? 'E' : 'k';

if ($space eq 'E') {
  $data->po->set(e_mu=>1, e_markers=>1, e_bkg=>0, e_pre=>0, e_post=>0, e_norm=>1, e_der=>0, e_sec=>0, e_i0=>0, e_signal=>0);
};

$data -> po -> start_plot;
$data->plot($space);
$sadata->plot($space);
print $text;
$data->pause;
