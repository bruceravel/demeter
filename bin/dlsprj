#!/usr/bin/env perl

=for Copyright
 .
 Copyright (c) 2008-2016 Bruce Ravel (L<http://bruceravel.github.io/home>).
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

use Cwd;
use File::Basename;
use Getopt::Long qw(GetOptionsFromString);

##                 V this is expedient....
use Demeter qw(:hephaestus :ui=screen);

my ($plot, $inc, $params, $gnuplot, $xanes, $edge, $kw, $nokey) =
  (q{}, 0.2, q{}, 0, 0, 0, 2);
my ($emin, $emax) = (0,0);
my %hash = ("plot|p=s"     => \$plot,
	    "stack=s"      => \$inc,
	    "params=s"     => \$params,
	    "g"            => \$gnuplot,
	    "xanes"        => \$xanes,
	    "edge"         => \$edge,
	    "kw|kweight=i" => \$kw,
	    "emin=i"       => \$emin,
	    "emax=i"       => \$emax,
	    "nokey"        => \$nokey,
	   );
my ($env, $args) = GetOptionsFromString($ENV{LSPRJ}, %hash) if (exists $ENV{LSPRJ});
my $result       = GetOptions(%hash);

my ($file, @groups) = @ARGV;
usage() if not $file;
die "lsprj: $file does not exist\n" if (not -e $file);
die "lsprj: $file cannot be read\n" if (not -r $file);

my $prj;
if (Demeter->is_prj($file)) {
  $prj = Demeter::Data::Prj->new();
} elsif (Demeter->is_json($file)) {
  $prj = Demeter::Data::JSON->new();
} else {
  print "\n'$file' is not an Athena project file\n";
  usage();
  exit;
};
my ($en, $ex) = ($prj->co->default('plot', 'emin'), $prj->co->default('plot', 'emax'));
$prj -> set(file=>$file);
$prj -> plot_with('gnuplot') if $gnuplot;
#$prj -> set_mode(screen => 1);

print '===> ', Cwd::abs_path($file), $/ x 2, $prj -> list(split(/,/,$params)), $/;

my $stack = 0;
if (lc($plot) =~ m{[endkrq]}) {
  my @data = (@groups) ? $prj->records(@groups) : $prj -> slurp;
  exit if ($#data == -1);
  $data[0] -> po -> title(basename($file, '.prj'));
  $data[0] -> po -> just_mu;
  $data[0] -> po -> e_norm(0)     if (lc($plot) =~ m{\A[ex]\z});
  $data[0] -> po -> e_norm(1)     if (lc($plot) eq 'n');
  $data[0] -> po -> e_der(1)      if (lc($plot) eq 'd');
  $data[0] -> po -> e_sec(1)      if (lc($plot) eq 's');
  $data[0] -> po -> kweight($kw)  if (lc($plot) =~ m{[krq]});
  $data[0] -> po -> r_pl('r')     if (lc($plot) eq 'rr');
  $data[0] -> po -> showlegend(0) if $nokey;
  ($en, $ex) = (-50, 120) if $xanes;
  ($en, $ex) = (-20, 60)  if $edge;

  $data[0] -> po -> set(emin => $emin||$en, emax =>$emax||$ex);
  my $p = $plot;
  ($p = 'e') if (lc($plot) =~ m{[xnd]});
  ($p = 'r') if (lc($plot) eq 'rr');
  foreach my $d (@data) {
    my $yoff = $d->y_offset;
    $d -> set('y_offset' => $yoff + $stack);
    $d -> plot($p);
    ($stack -= $inc) if (lc($plot) =~ m{[nkrq]});
  };

  $data[0] -> prompt("Press <Enter> to finish ");
  $data[0] -> pause;
  $data[0] -> po -> end_plot;
};

sub usage {
  print "
 usage : lsprj [options]  <projectfile> (group numbers)

 List the groups from an Athena project file.

   --plot=X, -p=X       plot data (X = e|n|d|s|k|r|q)
   --stack=val          specify stacking offset for plots
   --params=param_list  comma separated list of parameters
   --xanes              restrict energy plots to [-50:120]
   --edge               restrict energy plots to [-20:60]
   --emin, --emax       explicitly set energy plot range
   --kw=i, --kweight=i  use a k-weighting of \"i\"

 Optionally, you can list groups numbers to plot a subset of the
 contents of the project file.

";
  exit;
};


=head1 NAME

lsprj - List contents of an Athena project file

=head1 VERSION

This documentation refers to Demeter version 0.9.25.

=head1 SYNOPSIS

  lsprj my.prj

=head1 DESCRIPTION

This program writes out a list of the labels for each group in an
Athena project file.  This, then, is a quick way of peering inside a
project file without actually opening it.

The data from the project file can also be plotted by supplying the
optinal C<--plot> command line switch.  This is a quick-and-dirty
plotting tool intended for taking a peek inside a project file rather
than providing fine control over the details of the plot.

A short usage message will be printed to the screen if you leave off
the filename at the command line.

=head1 COMMAND LINE SWITCHES

=over 4

=item C<--plot> or C<-p>

Optionally plot the data from the project file in the specified
plotting space.  The plotting options are

=over 4

=item e

plot mu(E)

=item n

plot normalized mu(E)

=item d

plot derivative mu(E)

=item k

plot k-weighted chi(k)

=item r

plot the magnitude of chi(R) Fourier tranformed with k^2 weighting

=item q

plot the real part of chi(q)

=back

Values for data processing parameters are taken from the Athena
project file.  This is intended for quick-n-dirty display, so very few
plotting options are available.

Note that for large project files, the plot will be time consuming and
cluttered.  This option is most useful for smaller project files.

=item C<--stack>

Data plotted as normalized mu(E), chi(k), chi(R), or chi(q) are
stacked, with each subsequent trace being shifted downward by
0.2.  The amount of the shift can be specified with this switch.

=item C<-kw> or C<-kweight>

Override the default k-weight (which is 2).

=item C<--xanes>

When plotting mu(E) or normalized mu(E) this flag restricts the plot
to 50 volts below and 120 volts above the edge.

=item C<--edge>

When plotting mu(E) or normalized mu(E) this flag restricts the plot
to 20 volts below and 60 volts above the edge.

=item C<--emin> and C<--emax>

To fine tune the plotting ranges in energy beyond the setting
associated with C<--xanes> or C<--edge>, you can use these two
switches, which take energy vlues relative to the edge.

=item C<--params>

A comma separated list of data processing parameters to include in the
list of groups.  This is a bit awkward to use in that you must specify
the parameters using their internal representations as given explained
in the documentation for L<Demeter::Data>.  For instance,
this will show the values for the background removal R_bkg and the
forward Fourier transform kmin value:

  lsprj my.prj --params=bkg_rbkg,fft_kmin,
   ==prints==>
    #       record     bkg_rbkg   fft_kmin
    # ----------------------------------------------------
        1 : HgO        1.0        2
        2 : HgS black  1.0        2
        3 : HgS red    1.0        2

=item C<-g>

Use the gnuplot plotting backend.  The default is to use pgplot.

=back

=head1 ENVIRONMENT VARIABLE

Command line switches can be specified via an environment variable
called C<LSPRJ>.  The contents of that variable will be parsed before
the specified command line variables.  That is, the flags specified on
the command line over-ride the contents of the C<LSPRJ> environment
variable.  For example:

   export LSPRJ="--plot=e --edge -g"
   lsprj my.prj 7,12,17

This does the same as

   lsprj my.prj --plot=e --edge -g 7,12,17

=head1 DEPENDENCIES

This uses L<Demeter> and its dependencies.

=head1 BUGS AND LIMITATIONS

Please report problems to the Ifeffit Mailing List
(L<http://cars9.uchicago.edu/mailman/listinfo/ifeffit/>)

Patches are welcome.

=head1 AUTHOR

Bruce Ravel (L<http://bruceravel.github.io/home>)

L<http://bruceravel.github.io/demeter/>

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2016 Bruce Ravel (L<http://bruceravel.github.io/home>). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
