package Ifeffit::Demeter::Plot;

=for Copyright
 .
 Copyright (c) 2006-2008 Bruce Ravel (bravel AT bnl DOT gov).
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

use strict;
use warnings;
#use diagnostics;
use Class::Std;
use Carp;
use Fatal qw(open close);
use Regexp::List;
use Regexp::Optimizer;
use Regexp::Common;
use Readonly;
Readonly my $NUMBER => $RE{num}{real};
use YAML;

{
  use base qw( Ifeffit::Demeter
               Ifeffit::Demeter::Dispose
               Ifeffit::Demeter::Project
             );
  my $opt  = Regexp::List->new;
  my $config = Ifeffit::Demeter->get_mode("params");

  ## set default data parameter values
  my %plot_defaults = (
		       group              => 'plot_parameters',
		       ## font and legend have special methods
		       charsize		  => $config->default("plot", "charsize") || 1.2,
		       charfont		  => $config->default("plot", "charfont") || 1,
		       key_x		  => $config->default("plot", "key_x")    || 0.8,
		       'key_y'		  => $config->default("plot", "key_y")    || 0.9,
		       key_dy		  => $config->default("plot", "key_dy")   || 0.075,

		       ## plot area
		       bg		  => $config->default("plot", "bg")        || "white",
		       fg		  => $config->default("plot", "fg")        || "black",
		       showgrid		  => $config->default("plot", "showgrid")  || 1,
		       gridcolor	  => $config->default("plot", "gridcolor") || "grey82",

		       ## line colors
		       increment          => 0,	     # integer
		       c0		  => $config->default("plot", "c0") || "blue",
		       c1		  => $config->default("plot", "c1") || "red",
		       c2		  => $config->default("plot", "c2") || "green4",
		       c3		  => $config->default("plot", "c3") || "darkviolet",
		       c4		  => $config->default("plot", "c4") || "darkorange",
		       c5		  => $config->default("plot", "c5") || "brown",
		       c6		  => $config->default("plot", "c6") || "deeppink",
		       c7		  => $config->default("plot", "c7") || "gold3",
		       c8		  => $config->default("plot", "c8") || "cyan3",
		       c9		  => $config->default("plot", "c9") || "yellowgreen",

		       ## line styles
		       datastyle	  => $config->default("plot", "datastyle")  || "solid", # (solid dashed dotted dot-dash points linespoints)
		       fitstyle		  => $config->default("plot", "fitstyle")   || "solid", #   "
		       partstyle	  => $config->default("plot", "partstyle")  || "solid", #   "
		       pathstyle	  => $config->default("plot", "pathstyle")  || "solid", #   "

		       ## k,R,q space plots
		       space              => 'r',  # (k r q)
		       emin		  => $config->default("plot", "emin") || -200,
		       emax		  => $config->default("plot", "emax") || 800,
		       e_mu               => $config->default("plot", "e_mu") || 1,
		       e_bkg              => $config->default("plot", "e_bkg") || 0,
		       e_pre              => $config->default("plot", "e_pre") || 0,
		       e_post             => $config->default("plot", "e_post") || 0,
		       e_norm             => $config->default("plot", "e_norm") || 0,
		       e_der              => $config->default("plot", "e_der") || 0,
		       e_sec              => $config->default("plot", "e_sec") || 0,
		       e_markers          => $config->default("plot", "e_markers") || 0,    #  "
		       e_part             => q{},
		       e_smooth           => $config->default("plot", "e_smooth") || 0,
		       kmin		  => $config->default("plot", "kmin") || 0,
		       kmax		  => $config->default("plot", "kmax") || 15,
		       rmin		  => $config->default("plot", "rmin") || 0,
		       rmax		  => $config->default("plot", "rmax") || 6,
		       r_pl		  => $config->default("plot", "r_pl") || "m",
		       qmin		  => $config->default("plot", "qmin") || 0,
		       qmax		  => $config->default("plot", "qmax") || 15,
		       'q_pl'		  => $config->default("plot", "q_pl") || "r",

		       ## window, k-weight
		       kweight		  => "1",  # (1 2 3 arb)
		       window_multiplier  => 1.05, # float
		       plot_data	  => 0,    # boolean
		       plot_fit		  => 0,    # boolean
		       plot_win		  => 0,    # boolean
		       plot_res		  => 0,    # boolean
		       plot_bkg		  => 0,    # boolean
		       plot_paths	  => 0,    # boolean

		       ## indicators (not yet implemented)
		       nindicators	  => $config->default("indicator", "n")     || 8,
		       indicatorcolor	  => $config->default("indicator", "color") || "violetred",
		       indicatorline	  => $config->default("indicator", "line")  || "solid",

		       showmarker         => $config->default("marker", "show")  || 1,
		       markertype         => $config->default("marker", "type")  || 9,    # number 1 to 29, 9 is a dotted circle
		       markersize         => $config->default("marker", "size")  || 2,
		       markercolor        => $config->default("marker", "color") || "orange",

		       ## locals, mostly handled by the plot methods
		       new    => 1, # boolean
		       color  => q{},
		       xlabel => q{},
		       ylabel => q{},
		       key    => q{},
		       title  => q{},

		       tempfiles => [],
		       lastplot  => q{},

		       ## interpolation parameters
		       interp => $config->default("interpolation", "type") || "qinterp",

		      );

  my %attr = (number    => $opt->list2re(qw(charsize key_x key_y key_dy
					    emin emax kmin kmax rmin rmax qmin qmax
					    window_multiplier kweight
					    rebin_emin rebin_emax rebin_pre rebin_xanes rebin_exafs
					   )),
	      boolean   => $opt->list2re(qw(plot_data plot_fit plot_win plot_res plot_bkg showgrid
					    e_mu e_bkg e_pre e_post e_norm e_der e_sec e_markers new
					   )),
	      integer   => $opt->list2re(qw(e_smooth increment markertype)),
	      line      => $opt->list2re(qw(indicatorline datastyle fitstyle partstyle)),
	      linetypes => $opt->list2re(qw(solid dashed dotted dot-dash points linespoints)),
	      color     => $opt->list2re(qw(c0 c1 c2 c3 c4 c5 c6 c7 c8 c9
					    indicatorcolor bg fg gridcolor markercolor)),
	      interp    => $opt->list2re(qw(linterp qinterp splint)),
	     );

  sub BUILD {
    my ($self, $ident, $arguments) = @_;
    $self -> set(\%plot_defaults);

    ## plot specific attributes
    $self -> set($arguments);

    $self -> start_plot;
    $self -> set_mode({plot=>$self});
    return;
  };
  sub DEMOLISH {
    my ($self) = @_;
    return;
  };

  sub set {
    my ($self, $r_hash) = @_;
    my $re = $self->regexp;

    foreach my $key (keys %$r_hash) {
      my $k = lc $key;

      carp("\"$key\" is not a valid Ifeffit::Demeter::Plot parameter"), next
	if ($k !~ /$re/);


    SET: {
	($k =~ m{\A$attr{number}\z}) and do { # numbers must be numbers
	  croak("Ifeffit::Demeter::Plot: $k must be a number ($r_hash->{$k})")
	    if ($r_hash->{$k} !~ m{\A$NUMBER\z});
	  $self->SUPER::set({$k=>$r_hash->{$k}});
	};
	($k eq "interp") and do { # numbers must be numbers
	  croak("Ifeffit::Demeter::Plot: $k must be one of linterp/qinterp/splint ($r_hash->{$k})")
	    if ($r_hash->{$k} !~ m{\A$attr{interp}\z});
	  $self->SUPER::set({$k=>$r_hash->{$k}});
	};
	($k eq 'charfont') and do {
	  croak("Ifeffit::Demeter::Plot: charfont must be an integer from 1 to 4")
	    if ($r_hash->{$k} !~ m{\A[1-4]\z});
	  $self->SUPER::set({$k=>$r_hash->{$k}});
	};
	($k =~ m{\A$attr{line}\z}) and do {
	  croak("Ifeffit::Demeter::Plot: $k must be one of solid, dashed, dotted, dot-dash, points, or linespoints")
	    if (lc($r_hash->{$k}) !~ m{\A$attr{linetypes}\z}i);
	  $self->SUPER::set({$k=>lc($r_hash->{$k})});
	  last SET;
	};

	## norm and pre/post are mutually exclusive
	($k eq 'e_norm') and do {
	  $self->set({e_pre=>0, e_post=>0, e_sec=>0}) if ($r_hash->{$k});
	  $self->SUPER::set({$k=>$r_hash->{$k}});
	  last SET;
	};
	($k =~ m{\Ae_p(?:ost|re)}) and do {
	  $self->set({e_norm=>0, e_der=>0, e_sec=>0}) if ($r_hash->{$k});
	  $self->SUPER::set({$k=>$r_hash->{$k}});
	  last SET;
	};
	## first and second deriv are mutually exclusive
	## also derivs preclude pre/post/norm
	($k eq 'e_der') and do {
	  $self->set({e_sec=>0, e_pre=>0, e_post=>0, e_norm=>0}) if ($r_hash->{$k});
	  $self->SUPER::set({$k=>$r_hash->{$k}});
	  last SET;
	};
	($k eq 'e_sec') and do {
	  $self->set({e_der=>0, e_pre=>0, e_post=>0, e_norm=>0}) if ($r_hash->{$k});
	  $self->SUPER::set({$k=>$r_hash->{$k}});
	  last SET;
	};
	($k =~ m{\A[rq]_pl\z}) and do {
	  croak("Ifeffit::Demeter::Plot: $k must be one of m, e, r, i, or p")
	    if ($r_hash->{$k} !~ m{\A[merip]\z});
	  $self->SUPER::set({$k=>$r_hash->{$k}});
	};

	do {			# no special handling required
	  $self->SUPER::set({$k=>$r_hash->{$k}});
	};
      };
    };
  };

  ## return a list of valid plot parameter names
  sub parameter_list {
    my ($self) = @_;
    return (sort keys %plot_defaults);
  };

  my $parameter_regexp = $opt->list2re(keys %plot_defaults);
  sub _regexp {
    my ($self) = @_;
    return $parameter_regexp;
  };

  sub start_plot {
    my ($self) = @_;
    my $color = $self->get("c0");
    $self -> cleantemp -> set({new       => 1,
			       color     => $color,
			       increment => 0,
			       lastplot  => q{}});
    $self -> new_params({plot_part => q{}});
    return $self;
  };
  sub increment {
    my ($self) = @_;
    my $incr = $self->get('increment');
    ++$incr;
    $incr = $incr % 10;
    my $color = $self->get("c$incr");
    $self->set({new=>0, color=>$color, increment=>$incr});
  };
  sub reinitialize {
    my ($self, $xl, $yl) = @_;
    $self -> set({xlabel => $xl,
		  ylabel => $yl,
		  key    => q{},
		  title  => q{},
		  color  => q{},
		  #new    => 1,
		  e_part => q{},
		  #increment => 0,
		 });
  };
  sub end_plot {
    my ($self) = @_;
    return $self;
  };

  sub tempfile {
    my ($self) = @_;
    my $this = File::Spec->catfile($self->stash_folder, Ifeffit::Demeter::Tools->random_string(8));
    $self->Push({tempfiles => $this});
    return $this;
  };
  sub cleantemp {
    my ($self) = @_;
    foreach my $f (@{ $self->get('tempfiles') }) {
      unlink $f;
    };
    $self -> set({tempfiles => []});
    return $self;
  };

  sub legend {
    my ($self, $arguments) = @_;
    foreach my $which (qw(dy y x)) {
      $arguments->{$which} ||= $arguments->{"key_".$which};
      $arguments->{$which} ||= $plot_defaults{"key_".$which};
    };

    foreach my $key (keys %$arguments) {
      next if ($key !~ m{\A(?:dy|x|y)\z});
      carp("$key must be a positive number."), ($arguments->{$key}=$plot_defaults{"key_".$key}) if ($arguments->{$key} !~ m{$NUMBER});
      carp("$key must be a positive number."), ($arguments->{$key}=$plot_defaults{"key_".$key}) if ($arguments->{$key} < 0);
      $self->set({ "key_".$key=>$arguments->{$key} });
    };
    Ifeffit::put_scalar('&plot_key_x' , $self->get("key_x"));
    Ifeffit::put_scalar('&plot_key_y0', $self->get("key_y"));
    Ifeffit::put_scalar('&plot_key_dy', $self->get("key_dy"));
    #my $command = sprintf("plot(key_x=%s, key_y=%s, key_dy=%s)\n", $self->get(qw(key_x key_y key_dy)));
    #$self->dispose($command);
    return $self;
  };

  ## size cannot be negative, font must be 1-4
  sub font {
    my ($self, $arguments) = @_;
    $arguments->{font} ||= $arguments->{charfont};
    $arguments->{size} ||= $arguments->{charsize};
    $arguments->{font} ||= $plot_defaults{charfont};
    $arguments->{size} ||= $plot_defaults{charsize};
    carp("The font must be an integer from 1 to 4."), ($arguments->{font}=1)   if (($arguments->{font} < 1) or ($arguments->{font} > 4));
    carp("The size must be a positive number."),      ($arguments->{size}=1.2) if ($arguments->{size} !~ m{$NUMBER});
    carp("The size must be a positive number."),      ($arguments->{size}=1.2) if ($arguments->{size} < 0);
    foreach my $key (keys %$arguments) {
      next if ($key !~ m{\A(?:font|size)\z});
      $self->set({ "char$key"=>$arguments->{$key} });
    };
    my $command = sprintf("plot(charfont=%d, charsize=%s)\n", $self->get(qw(charfont charsize)));
    $self->dispose($command);
    return $self;
  };

  sub label {
    my ($self, $x, $y, $text) = @_;
    my $command = $self->template("plot", "label", { x    => $x,
						    'y'   => $y,
						     text => $text
						   });
    #if ($self->get_mode("template_plot") eq 'gnuplot') {
    #  $self->get_mode('external_plot_object')->gnuplot_cmd($command);
    #} else {
    $self -> dispose($command, "plotting");
    #};
    return $self;
  };

  sub file {
    my ($self, $type, $file) = @_;
    my %devices = (png => '/png', ps => '/cps');
    my $command = $self->template("plot", "file", { device => $devices{$type},
						    file   => $file });
    $self -> dispose($command, "plotting");
    return $self;
  };


};
1;

=head1 NAME

Ifeffit::Demeter::Plot - Controlling plots of XAS data

=head1 VERSION

This documentation refers to Ifeffit::Demeter version 0.1.

=head1 SYNOPSIS

  $plot_object = Ifeffit::Demeter::Plot -> new();
  $plot_object -> set({kweight=>3});

=head1 DESCRIPTION

This subclass of Ifeffit::Demeter is for holding information
pertaining to how plots of data and paths are made.

=head1 METHODS

This uses the C<new>, C<set>, and C<get> methods of the parent class.

=over 4

=item C<start_plot>

This method reinitializes a plot.  In terms of Ifeffit, the next plot made
after running this method will be a C<newplot()>.  Each subsequent plot until
the next time C<start_plot> is called will be a C<plot()>.  Also, the sequence
of colors is reset when this method is called.

  $plotobject -> start_plot;

=item C<legend>

This is a convenience method for controlling the appearence of the legend in
the plot.  This will set the legend parameters (C<key_x>, C<key_y>, and
C<key_dy>) and return the Ifeffit command to reset the legend.

  $plotobject -> legend({x=>0.6, y=>0.8, dy=>0.05});

Note that you get to drop "key" in the arguments to this method,
although C<x> and C<key_x> will be interpreted the same.

=item C<font>

This is a convenience method for controlling the appearence of the text in
the plot.  This will set the text attributes (C<charfont> and
C<charsize>) and return the Ifeffit command to reset the text.

  $plotobject -> font({font=>4, size=>1.8})

Note that you get to drop "char" in the arguments to this method,
although C<font> and C<charfont> will be interpreted the same.

The available fonts are: 1=sans serif, 2=roman, 3=italic, 4=script.
If the font is not one of those numbers, it will fall back to 1.  The
size cannot be negative.  Values larger than around 1.8 are allowed,
but are probably a poor idea.

=item C<label>

Place a textual label on the plot at a specified point.

  $plotobject -> label($x, $y, $text);

=back

=head1 ATTRIBUTES

The following are the attributes of the Plot object.  Attempting to
access an attribute not on this list will throw an exception.

The type of argument expected in given in parentheses. i.e. number,
integer, string, and so on.  The default value, if one exists, is
given in square brackets.

=over 4

=item C<group> (string) I<[a random four-letter string]>

This string is used as the unique identifier for the Plot object.

=item C<space> (letter) I<[r]>

The space in which to preform the plot.  It must be one of E, k, r, or q.

=item C<color>

The next line color to be used.  This is updated automatically by the
plotting methods.

=item C<increment>

A counter for the number of traces already drawn in the current plot.

=item C<new>

A flag indicating whether to start a new plot or to plot over the
current one.

=back

=head2 Text and colors

=over 4

=item C<charsize> (number) I<[1.2]>

The character size in PGPLOT plots.

=item C<charfont> (integer) I<[1]>

The font type used in plots with PGPLOT.  The available fonts are:
1=sans serif, 2=roman, 3=italic, 4=script.

=item C<key_x> (number) I<[0.8]>

The location in x of the plot legend as a fraction of the full window
width.

=item C<key_y> (number) I<[0.9]>

The location in y of the plot legend as a fraction of the full window
height.

=item C<key_dy> (number) I<[0.075]>

The separation in y of the entried in the plot legend as a fraction of
the full window height.

=item C<bg> (color) I<[white]>

The plot background color.

=item C<fg> (color) I<[black]>

The plot foreground color, used for text and the plot frame.

=item C<showgrid> (boolean) I<[1]>

When true, a grid will be shown on the plot.

=item C<gridcolor> (color) I<[grey82]>

The color of the grid drawn on the plot.

=item C<c0> to C<c9> (color)

The line colors.  These are the default colors (as defined in the X
windows F<rgb.txt> file) in order: blue red green4 darkviolet
darkorange brown deeppink gold3 cyan3 yellowgreen.

=back

=head2 Line types

The line type attributes take these possible values:

   solid dashed dotted dot-dash points linespoints

=over 4

=item C<datastyle> (string) I<[solid]>

The line type for plots of data.

=item C<fitstyle> (string) I<[solid]>

The line type for the fit array.

=item C<partstyle> (string) I<[solid]>

The line type for a part of the data, such as the window or the
background.

=item C<pathstyle> (string) I<[solid]>

The line type for a path.

=back

=head2 Energy plots

=over 4

=item C<emin> (number) I<[-200]>

The lower bound of the plot range in energy, relative to e0 of the
data group.

=item C<emax> (number) I<[800]>

The upper bound of the plot range in energy, relative to e0 of the
data group.

=item C<e_mu> (boolean) I<[1]>

A flag for whether to plot mu(E) in an energy plot.

=item C<e_bkg> (boolean) I<[0]>

A flag for whether to plot the background in an energy plot.

=item C<e_pre> (boolean) I<[0]>

A flag for whether to plot the pre-edge line in an energy plot.

=item C<e_post> (boolean) I<[0]>

A flag for whether to plot the post-edge line in an energy plot.

=item C<e_norm> (boolean) I<[0]>

A flag for whether to plot mu(E) and the background as normalized data
in an energy plot.

=item C<e_der> (boolean) I<[0]>

A flag for whether to plot muE() as a derivative spectrum in an energy
plot.

=item C<e_sec> (boolean) I<[0]>

A flag for whether to plot the mu(E) as a second derivative spectrum
in an energy plot.

=item C<C<e_markers>> (boolean) I<[0]>

If true, than markers will be plotted in energy as appropriate to indicate the
positions of E0 and the boundaries of the pre- and post-edge resions.

=item C<e_part> () I<[]>

q{},

=item C<e_smooth> (integer) I<[0]>

When non-sero, data plotted in energy will be smoothed using Ifeffit's
three-point smoothing function.  The number is the number of
repititions of the smoothing function.

=back

=head2 k plots

=over 4

=item C<kmin> (number) I<[0]>

The lower bound of the plot range in k.

=item C<kmax> (number) I<[15]>

The upper bound of the plot range in k.

=item C<kweight> (number) I<[1]>

The k-weighting to use when plotting in k or in a Fourier transform
before plottingin R or q.  Typically, this is 1, 2, or 3, but can
actually be any number.

=back

=head2 R plots

=over 4

=item C<rmin> (number) I<[0]>

The lower bound of the plot range in R.

=item C<rmax> (number) I<[6]>

The upper bound of the plot range in R.

=item C<r_pl> (letter) I<[m]>

The part of the Fourier transform to plot when making a multiple data
set plot in R.  The choices are m, p, r, and i for magnitude, phase,
real, and imaginary.

=back

=head2 q plots

=over 4

=item C<qmin> (number) I<[0]>

The lower bound of the plot range in backtransform k.

=item C<qmax> (number) I<[15]>

The upper bound of the plot range in backtransform k.

=item C<q_pl> (letter) I<[r]>

The part of the Fourier transform to plot when making a multiple data
set plot in q.  The choices are m, p, r, and i for magnitude, phase,
real, and imaginary.

=back

=head2 Data parts

=over 4

=item C<plot_data> (boolean) I<[1]>

When making a plot after a fit, the data will be plotted when
this is true.

=item C<plot_fit> (boolean) I<[0]>

When making a plot after a fit, the fit will be plotted when this is
true.

=item C<plot_win> (boolean) I<[0]>

When making a plot after a fit, the Fourier transform window will be
plotted when this is true.

=item C<window_multiplier> (number) I<[1.05]>

This is the scaling factor by which the window is multipled so that it
plots nicely with the data.  The window will be multiplied by the
value of the largest point in the plot, then by this number.

=item C<plot_res> (boolean) I<[0]>

When making a plot after a fit, the residual will be plotted when this
is true.

=item C<plot_bkg> (boolean) I<[0]>

When making a plot after a fit, the background will be plotted when
this is true, if the background was corefined in the fit..

=item C<plot_paths> (boolean) I<[0]>

When making a plot after a fit, all paths used in the fit will be
plotted when this is true.

=back

=head2 Plot ornaments

=over 4

=item C<nindicators> (number) I<[8]>

The maximum number of plot indicators that can be defined.

=item C<indicatorcolor> (color) I<[violetred]>

The color of the plot indicators.

=item C<indicatorline> (string) I<[solid]>

The line type of the plot indicator.  It must be one of

   solid dashed dotted dot-dash points linespoints

=item C<showmarker> (boolean) I<[1]>

Plot markers for things like e0 and the normalization range will be
displayed when this true.

=item C<markertype> (number) I<[9]>

The point style of t he plot marker.  In PGPLOT, this can be a number
between 1 and 29 and 9 is a dotted circle.

=item C<markersize> (number) I<[2]>

The size of the plot marker.

=item C<markercolor> (color) I<[orange]>

The color of the plot marker.

=back

=head1 DIAGNOSTICS


These messages are classified as follows (listed in increasing order
of desperation):

    (W) A warning (optional).
    (F) A fatal error (trappable).


=over 4

=item C<$key is not a valid Ifeffit::Demeter::Data parameter>

You have tried to set in invalid Plot parameter

=item C<Ifeffit::Demeter::Plot: $k must be a number>

You have attempted to set an attribute that takes a numerical value to
something other than a number.

=item C<key_X must be a positive number>

(W) You have tried to set one of the legend parameters to something that is
not a positive number.  It was reset to its default.

=item C<The font must be an integer from 1 to 4.>

(W) There are only four types of fonts available and they are numbered 1
through 4.  The font was reset to sans-serif, which is number 1.

=item C<The size must be a positive number>

(W) You have tried to set the font size to something that is not a positive
number.  It was reset to size 1.2.

=item C<Ifeffit::Demeter::Plot: $k must be one of solid, dashed, dotted, dot-dash, points, or linespoints>

You have attempted to set an attribute controlling a line to an
unknown line type.

=item C<Ifeffit::Demeter::Plot: $k must be one of m, e, r, i, or p>

You have set an attribute controlling which part of complex function
is plotted to something that is not understood as complex function
part.  The choices are C<m>agnitude, C<e>nvelope, C<r>eal,
C<i>maginary, and C<p>hase.

=back

=head1 SERIALIZATION AND DESERIALIZATION

Serialization of a Plot object is still an open question.

=head1 CONFIGURATION AND ENVIRONMENT

See L<Ifeffit::Demeter::Config> for a description of the configuration
system.  The plot and ornaments configuration groups control the
attributes of the Plot object.

=head1 DEPENDENCIES

Demeter's dependencies are in the F<Bundle/DemeterBundle.pm> file.

=head1 BUGS AND LIMITATIONS

There are no known bugs in this module.

Please report problems to Bruce Ravel (bravel AT bnl DOT gov)

Patches are welcome.

=head1 AUTHOR

Bruce Ravel (bravel AT bnl DOT gov)

L<http://cars9.uchicago.edu/~ravel/software/>


=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2008 Bruce Ravel (bravel AT bnl DOT gov). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
