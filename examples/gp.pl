#!/usr/bin/perl -I../lib/

use strict;
use warnings;

use Graphics::GnuplotIF qw(GnuplotIF);
use Demeter;
use List::MoreUtils qw(pairwise);

Demeter->set_mode({screen=>0, ifeffit=>1, template_plot=>'gnuplot'});
my @data = Demeter::Data::Prj -> new({file=>'cyanobacteria.prj'})
   -> records(11, 9, 10);
map { $_ -> _update('fft') } @data;

#foreach my $d (@data) {
my $d = $data[0];
  $d->po->set({
	       emin=>-200, emax=>800,
	       e_mu      => 1,    e_bkg     => 0,
	       e_norm    => 0,    e_der     => 0,
	       e_pre     => 0,    e_post    => 0,
	       e_markers => 0,
	       kweight   => 3,
	       r_pl      => 'm',
	      });
  $d -> set({bkg_pre2=>-200, bkg_pre2=>-70});
  $d -> plot('e');
#};

my $e = $d -> clone({label=>'clone'});
$e -> plot('e');



# print "Hit return to write file ";
# my $toss0 = <>;
# $data[0]->po->file("postscript", "foo.ps");

# #$data[0]->po->replot;
print "Hit return to finish ";
my $toss = <>;
# $data[0]->po->cleantemp;

exit;



my $plot1 = Graphics::GnuplotIF->new(title	    => "all marked groups",
				     style	    => "lines",
				     persist	    => 0,
	     		             'silent_pause' => 0)
  -> gnuplot_cmd("set term wxt font 'Droid Sans,11' enhanced")
  -> gnuplot_cmd("set encoding iso_8859_15");

$plot1 -> gnuplot_set_plot_titles($data[0]->get('label'),
				  $data[1]->get('label'))
  -> gnuplot_set_xlabel('Energy (eV)')
  -> gnuplot_set_ylabel('Normalized {/Symbol m}(E)')
  -> gnuplot_set_xrange(11880,12100);

$plot1 -> gnuplot_plot_many(
			    $data[0]->ref_array('energy'),
			    $data[0]->ref_array('flat'),
			    $data[1]->ref_array('energy'),
			    $data[1]->ref_array('flat'),
			   )
  -> gnuplot_pause(0);                   # hit RETURN to continue
$plot1 -> gnuplot_plot_many_style(
				  {'x_values'   => $data[0]->ref_array('energy'),
				   'y_values'   => $data[0]->ref_array('flat'),
				   'style_spec' => "lines lw 5",
				  },
				  {'x_values'   => $data[1]->ref_array('energy'),
				   'y_values'   => $data[1]->ref_array('flat'),
				   'style_spec' => "points pointtype 4 pointsize 2",
				  },
				 )
  -> gnuplot_pause(0);                   # hit RETURN to continue

$plot1->gnuplot_reset;


# my $w = 1;
# $plot1->gnuplot_set_plot_titles($d1->get('label'), $d2->get('label'));
# $plot1->gnuplot_set_xlabel("Wavenumber ({\101}^{-1})"); # \305 = &Aring;
# $plot1->gnuplot_set_ylabel(sprintf '{/Symbol c}(k) {\267} k^%s ({\101}^{-%s})', $w, $w);

# $plot1->gnuplot_plot_xy(
# 			$d1->ref_array('k'),
# 			[pairwise {$a**$w * $b} @{ $d1->ref_array('k') }, @{ $d1->ref_array('chi') }],
# 			[pairwise {$a**$w * $b} @{ $d2->ref_array('k') }, @{ $d2->ref_array('chi') }],
# 		       );
# $plot1->gnuplot_pause(0);                   # hit RETURN to continue
