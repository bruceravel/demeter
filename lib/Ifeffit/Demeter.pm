package Ifeffit::Demeter;

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


## These are common to all Demeter modules
require 5.8.0;
use strict;
use warnings;
#use diagnostics;
use version;

use Carp;
use Class::Std;
use Class::Std::Utils;
use Fatal qw(open close);
use File::Spec;
use Ifeffit;
use List::Util qw(max);
use List::MoreUtils qw(any minmax zip);
use Math::Spline;
use Readonly;
use Regexp::Common;
use Regexp::List;
use Regexp::Optimizer;
use Text::Template;
use Text::Wrap;
use YAML;


use aliased 'Ifeffit::Demeter::Config';
use aliased 'Ifeffit::Demeter::Tools';

use vars qw(@ISA @EXPORT @EXPORT_OK $Gnuplot_exists);
require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw($PA);
@EXPORT_OK = qw();

$Gnuplot_exists = (eval "require Graphics::GnuplotIF");

our $VERSION = version->new('0.1.0');
$Text::Wrap::columns = 65;
ifeffit("\&screen_echo = 0\n");
Readonly my $NUMBER => $RE{num}{real};

sub identify_self {
  #my ($class);
  my @caller = caller;
  use File::Basename qw(dirname);
  return dirname($caller[1]);
};

=for LiteratureReference (import)
  Then, spent as they were from all their toil,
  they set out food, the bounty of Ceres, drenched
  in sea-salt, Ceres' utensils too, her mills and troughs,
  and bend to parch with fire the grain they had salvaged,
  grind it find on stone.
                                Virgil, The Aeneid, 1:209-213

=cut


## adopted from Tk/widgets.pm
sub import {
 my $class = shift;
 if (@_) {
   foreach (@_) {
     local $SIG{__DIE__} = \&Carp::croak;
     if ($_ eq ':all') {	# :all means import all components
       foreach my $m (qw(Atoms Data Data/Prj Path Plot Config GDS Fit Feff ScatteringPath)) {
	 next if $INC{"Ifeffit/Demeter/$m.pm"};
	 ##print "Ifeffit/Demeter/$m.pm\n";
	 require "Ifeffit/Demeter/$m.pm";
       };
     } elsif ($_ eq 'Fit') {	# Fit requires Data, Path, and GDS
       foreach my $m (qw(Data Data/Prj Path GDS Fit Plot)) {
	 next if $INC{"Ifeffit/Demeter/$m.pm"};
	 require "Ifeffit/Demeter/$m.pm";
       };
     } elsif ($_ eq 'Feff') {	# Feff requires ScatteringPath
       foreach my $m (qw(Feff ScatteringPath Plot)) {
	 next if $INC{"Ifeffit/Demeter/$m.pm"};
	 require "Ifeffit/Demeter/$m.pm";
       };
     } else {
       require "Ifeffit/Demeter/$_.pm";
     };
   };
 } else {			# no arguments is equivalent to :all
   foreach my $m (qw(Atoms Data Path Data/Prj Plot Config GDS Fit Feff ScatteringPath)) {
     next if $INC{"Ifeffit/Demeter/$m.pm"};
     ##print "Ifeffit/Demeter/$m.pm\n";
     require "Ifeffit/Demeter/$m.pm";
   };
 };
 my $plot = $class -> get_mode('plot');
 $class->set_mode({plot => Ifeffit::Demeter::Plot->new()}) if not $plot;
};


{
  use base qw(
	      Ifeffit::Demeter::Dispose
	     );

  my %group_of   :ATTR;
  my %params_of  :ATTR;
  my %seen_group;
  my %mode = (ifeffit   => 1,		  # dispatch to Ifeffit
	      screen    => 0,		  # dispatch to STDOUT
	      file      => 0,		  # dispatch to a named file
	      plotfile  => 0,		  # dispatch plot commands only to a named file
	      buffer    => 0,		  # dispatch to a scalar or an array
	      repscreen => 0,             # dispatch reprocessed commands to screen
	      repfile   => 0,		  # dispatch reprocessed commands to named file

	      echo      => q{},
	      plot      => q{},           # active Plot object
	      params    => Config->new(), # active Config object
	      fit       => q{},		  # active Fit object
	      standard  => q{},		  # standard Data object for Athena-like methods
	      theory    => q{},		  # active Feff object
	      template_process => "ifeffit",
	      template_fit     => "ifeffit",
	      template_plot    => "pgplot",
	      template_feff    => "feff6",

	      datadefault => q{},
	      external_plot_object => q{},
	     );
  ## need to turn off ifeffit channel when template_process or
  ## template_fit is set to feffit

  $mode{params} -> read_config if not $mode{params}->is_configured;
  $mode{params} -> read_ini;

  sub BUILD {
    my ($self) = @_;
    my $group = Tools -> random_string(4);
    $self->set_group($group);
    return;
  };


#   sub DEMOLISH {
#     my ($self, $ident) = @_;
#     print ref $self, $/;
# #    if (ref($self) =~ /Data/) {
#       my $string = Ifeffit::Demeter->template("process", "erase_group", {dead=>$group_of{$ident}});
#       print ">>>", $string;
# #    };
#     return;
#   };

  sub identify {
    my ($self, $full) = @_;
    $full ||= 0;
    my $string = "Demeter $VERSION, copyright (c) 2006-2008 Bruce Ravel";
    #if ($full) {
    #
    #};
    return $string;
  };

  sub location {
    my ($self) = @_;
    return identify_self();
  };

  sub set_mode {
    my ($class, $rhash) = @_;
    my $regexp = $class->regexp("modes");
    foreach my $m (keys %$rhash) {
      carp("Ifeffit::Demeter: $m is not a valid mode"), next if ($m !~ m{$regexp});
      $mode{$m} = $rhash->{$m};

      if (($m eq "template_plot") and ($rhash->{$m} eq 'gnuplot')) {
	if ($Gnuplot_exists) {
	  require Ifeffit::Demeter::Plot::Gnuplot;
	  import Ifeffit::Demeter::Plot::Gnuplot;
	  $mode{plot} = Ifeffit::Demeter::Plot::Gnuplot->new();
	  $mode{external_plot_object} =
	    Graphics::GnuplotIF -> new(persist=>$class->config->default("gnuplot", "persist"));
	  $class->get_mode("plot")->gnuplot_start;
	} else {
	  carp("Graphics::GnuplotIF is not installed -- Demeter is reverting to pgplot");
	  $mode{template_plot} = 'pgplot';
	};
      };
    };
  };
  sub get_mode {
    my ($class, $which) = @_;
    $which ||= q{};
    #if ($which eq 'plot') {	# create a Plot objet if one has not yet been created
    #  $mode{plot} ||= Ifeffit::Demeter::Plot->new();
    #  $mode{plot}   = Ifeffit::Demeter::Plot->new() if (ref($mode{plot}) !~ m{Plot});
    #};
    my $regexp = $class->regexp("modes");
    return $mode{$which} if ($which =~ m{$regexp});
    return %mode;
  };
  sub config {
    my ($self) = @_;
    return Ifeffit::Demeter->get_mode("params");
  };
  sub po {
    my ($self) = @_;
    return Ifeffit::Demeter->get_mode("plot");
  };
  sub plot_with {
    my ($self, $backend) = @_;
    my $regexp = $self->regexp("plotting_backends");
    if ($backend !~ m{$regexp}) {
      carp("'$backend' is not a valid plotting backend for Demeter -- reverting to pgplot");
      $backend = 'pgplot';
    };
    $self->set_mode({template_plot=>$backend});
  };

  sub environment {
    my ($self) = @_;
    return {demeter => $Ifeffit::Demeter::VERSION,
	    ifeffit => (split(" ", Ifeffit::get_string("\$&build")))[0],
	    perl    => $],
	    tk      => $Tk::VERSION,
	    };
  };

  ##-----------------------------------------------------------------
  ## group naming methods
  sub set_group {
    my ($self, $group) = @_;
    $group =~ s/\s+/_/g;
    $group_of{ident $self} = $group;
    return;
  };
  sub get_group : STRINGIFY {
    my ($self) = @_;
    return $group_of{ident $self};
  };
  sub data {
    return q{};
  };
  sub label {
    my ($self) = @_;
    return (ref($self) =~ /GDS/) ? $self->get('name') : $self->get('label');
  };
  {
    no warnings 'once';
    # alternate names
    *name = \ &label;
  }


=for LiteratureReference (clone)
  For the Jews, on the other hand, the apparition of the Double was
  not a foreshadowing of death, but rather a proof that the person to
  whom it appeared had achieved the rank of prophet.  This is the
  explanation offered by Gershom Scholem.  A tradition included in the
  Talmud tells the story of a man, searching for God, who met
  himself.
                                Jorge Luis Borges
                                The Book of Imaginary Beings

=cut

  ## return a new object initialized to the values of $self.  $arguments is a
  ## ref to a hash of attributes for the new object
  sub clone {
    my ($self, $arguments) = @_;
    my $class = ref $self;
    my $new_object = $class->new;
    $new_object -> set_group(Tools->random_string(4));

    ## initialize with parent's values
    foreach my $key ($self->parameter_list) {
      next if any {$key eq $_} qw(group tag file);
      my $value = $self->get($key);
      $new_object->set( {$key => $value } );
    };
    if ((ref($self) =~ m{Data}) and ($self->get("from_athena"))) {
      $new_object -> standard;
      $self -> dispose($self->template("process", "clone"));
      $new_object -> unset_standard;
      $new_object -> set({from_athena	 => 1,
			  update_data	 => 0,
			  update_columns => 0,
			  update_norm	 => $self->get('is_xmu'),
			  update_fft	 => 1});
    } else {
      $new_object->set( {file => $self->get("file") } );
    };
    ## set specified values
    foreach my $key (keys %$arguments) {
      $new_object->set( {$key=>$arguments->{$key}} );
    };

    return $new_object;
  };

  ## ---------------------------------------------------------------------
  ## accessor methods
  sub set {
    my ($self, $hashref) = @_;
    my $type = ref $self;

    my $re = $self->regexp;
    foreach my $key (keys %$hashref) {
      my $k = lc $key;
      carp("\"$key\" is not a valid $type parameter"), next if (($re !~ m{\A\s*\z}) and ($k !~ /$re/));
      $params_of{ident $self}{$k} = $hashref->{$k};
      $self->set_group($hashref->{$k}) if ($k eq 'group');
    };
    return $self;
    ## sanity checks are left for the particular object
  };
  sub Push {
    my ($self, $hashref) = @_;
    my $retval = 0;
    foreach my $key (keys %$hashref) {
      my $k = lc $key;
      push @{ $params_of{ident $self}{$k} }, $$hashref{$k};
      $retval = $#{ $params_of{ident $self}{$k} };
    };
    return $retval;
  };
  sub get {
    #my ($self, @params) = @_;
    my $self = shift;
    croak(ref($self) . ': usage: get($key) or get(@keys)') if @_ < 1;
    my $re = $self->regexp;
    my @values = ();
    foreach my $key (@_) {
      my $k = lc $key;
      carp(ref($self) . ": \"$key\" is not a valid parameter") if (($re !~ m{\A\s*\z}) and ($k !~ /$re/));
      push @values, $params_of{ident $self}{lc $key};
    };
    return wantarray ? @values : $values[0];
  };

  sub get_all {
    my ($self) = @_;
    my @keys = $self->parameter_list;
    my @values = $self->get(@keys);
    my %hash = zip(@keys, @values);
    return %hash;
  };

  sub get_params_of {
    my ($self) = @_;
    my %hash = %{ $params_of{ident $self} };
    return %hash;
  };

  sub new_params {
    my ($self, $rhash) = @_;
    $self->config->new_params($rhash);
    return $self->config;
  };

  sub serialize {
    my ($self) = @_;
    my %hash = $self->get_all;
    return YAML::Dump(\%hash);
  };

  sub yofx {
    my ($self, $suffix, $part, $x) = @_;
    my $space = ($suffix eq 'chi')   ? 'k'
              : ($suffix =~ m{chir}) ? 'r'
              : ($suffix =~ m{chiq}) ? 'q'
	      :                        "energy";
    my @x        = $self->get_array($space);
    if ($space eq 'energy') {
      @x = map {$_ + $self->get("bkg_eshift")} @x;
    };
    my @y        = $self->get_array($suffix, $part);
    my $spline   = Math::Spline->new(\@x,\@y);
    my $y_interp = sprintf("%11.8f", $spline->evaluate($x));
    return $y_interp;
  };

  sub get_array {
    my ($self, $suffix, $part) = @_;
    $part ||= q{};
    if (not $self->plottable) {
      my $class = ref $self;
      croak("$class objects have no arrays associated with them");
    };
    my $opt  = Regexp::List->new;
    my @list = $self->arrays;
    my $group_regexp = $opt->list2re(@list);
    if ($suffix !~ m{\b$group_regexp\b}) {
      croak("The group $self does not have an array $self.$suffix (" . join(" ", @list) . ")");
    };
    my $text = ($part =~ m{(?:bkg|fit|res)}) ? "${self}_$part.$suffix" : "$self.$suffix";
    return Ifeffit::get_array($text);
  };
  sub ref_array {
    my ($self, $suffix, $part) = @_;
    $part ||= q{};
    my @x = $self->get_array($suffix, $part);
    return \@x;
  };

  sub floor_ceil {
    my ($self, $suffix, $part) = @_;
    my @array = $self->get_array($suffix, $part);
    my ($min, $max) = minmax(@array);
    return ($min, $max);
  };

  sub arrays {
    my ($self) = @_;
    if (not $self->plottable) {
      my $class = ref $self;
      croak("$class objects have no arrays associated with them");
    };
    my $save = Ifeffit::get_scalar("\&screen_echo");
    ifeffit("\&screen_echo = 0\n");
    ifeffit("show \@group $self");
    my @arrays = ();
    my $lines = Ifeffit::get_scalar('&echo_lines');
    ifeffit("\&screen_echo = $save\n"), return if not $lines;
    foreach my $l (1 .. $lines) {
      my $response = Ifeffit::get_echo();
      if ($response =~ m{\A\s*$self\.([^\s]+)\s+=}) {
	push @arrays, $1;
      };
    };
    ifeffit("\&screen_echo = $save\n");
    return @arrays;
  };

  sub version {
    my ($self) = @_;
    return $VERSION
  };


  ##-----------------------------------------------------------------
  ## basic ifeffit chores, import data, FTs

=for LiteratureReference (template)
  In time, the locution 'iungentur iam grypes equis', or "cross
  Gryphons with horses," became a common saying; in the early
  sixteenth century, Ludovico Ariosto recalled the phrase, and
  invented the Hippogriff.  Eagle and lion commingle in the Gryphon of
  the ancients; in the Ariostan Hippogriff it is horse and Gryphon --
  a second degree monster, or second degree feat of imagination.
                               Jorge Luis Borges
                               The Book of Imaginary Beings

=cut


  ## common supplied hash elements: filename, kweight, titles, plot_object
  sub template {
    my ($self, $category, $file, $rhash) = @_;

    my $data     = $self->data;
    my $pf       = Ifeffit::Demeter->get_mode('plot');
    my $params   = Ifeffit::Demeter->get_mode('params');
    my $fit      = Ifeffit::Demeter->get_mode('fit');
    my $standard = Ifeffit::Demeter->get_mode('standard');
    my $theory   = Ifeffit::Demeter->get_mode('theory');

    my $tmpl = File::Spec->catfile(dirname($INC{"Ifeffit/Demeter.pm"}),
				   "Demeter",
				   "templates",
				   $category,
				   $self->get_mode("template_$category"),
				   "$file.tmpl");
    if (not -e $tmpl) {		# fall back to ifeffit/pgplot template
      my $set = ($category eq 'plot') ? "pgplot" :
	        ($category eq 'feff') ? "feff6"  :
 	        "ifeffit";
      $tmpl = File::Spec->catfile(dirname($INC{"Ifeffit/Demeter.pm"}),
				  "Demeter", "templates", $category, $set, "$file.tmpl");
    };
    croak("Unknown Demeter template file: group $category; type $file; $tmpl") if (not -e $tmpl);

    my $template = Text::Template->new(TYPE => 'file', SOURCE => $tmpl)
      or die "Couldn't construct template: $Text::Template::ERROR";
    $rhash ||= {};
    my $string = $template->fill_in(HASH => {S  => \$self,
					     D  => \$data,
					     P  => \$pf,
					     C  => \$params,
					     F  => \$fit,
					     DS => \$standard,
					     T  => \$theory,
					     %$rhash},
				    PACKAGE => "Ifeffit::Demeter::Templates");
    $string ||= q{};
    $string =~ s{^\s+}{};		# remove leading white space
    $string =~ s{\n(?:[ \t]+\n)+}{\n};	# regularize white space between blocks of text
    $string =~ s{\s+$}{\n};		# remove trailing white space
    $string =~ s{<<nl>>}{\n}g;		# convert newline token into a real newline
    $string =~ s{<<( +)>>}{$1}g;	#} # convert white space token into real white space
    return $string;
  };

  sub read_data {
    my ($self, $type) = @_;
    $type ||= q{};
    $self->dispose($self->_read_data_command($type));
    $self->set({update_data=>0});
  };
  sub _read_data_command {
    my ($self, $type) = @_;
    my $string = q[];
    if ($type eq 'xmu') {
      $string  = $self->template("process", "read_xmu");
      $string .= $self->template("process", "deriv");
    } elsif ($type eq 'chi') {
      $string = $self->template("process", "read_chi");
    } elsif ($type eq 'feff.dat') {
      $string = $self->template("process", "read_feffdat");
    } else {
      $string = $self->template("process", "read");
    };
    return $string;
  };

  sub fft {
    my ($self) = @_;
    my $how = Ifeffit::Demeter->get_mode('process');
    my $pf  = Ifeffit::Demeter->get_mode('plot');
    $self->_update("fft");
    $self->dispose($self->_fft_command);
    $self->set({update_fft=>0});
  };
  sub _fft_command {
    my ($self) = @_;
    my $pf  = Ifeffit::Demeter->get_mode('plot');
    croak(ref($self)." objects cannot be Fourier transformed") if not $self->plottable;
    my $string = $self->template("process", "fft");
    return $string;
  };

  sub bft {
    my ($self) = @_;
    $self->_update("fft");
    $self->dispose($self->_bft_command);
    $self->set({update_bft=>0});
  };
  sub _bft_command {
    my ($self) = @_;
    my $pf  = Ifeffit::Demeter->get_mode('plot');
    croak(ref($self)." objects cannot be Fourier transformed") if not $self->plottable;
    my $string = $self->template("process", "bft");
    return $string;
  };

  ##-----------------------------------------------------------------
  ## plotting methods

  sub plot {
    my ($self, $space) = @_;
    my $how = Ifeffit::Demeter->get_mode('process');
    my $pf  = Ifeffit::Demeter->get_mode('plot');
    $space ||= $pf->get('space');
    ($space = 'kq') if (lc($space) eq 'qk');
    my $which = (lc($space) eq 'e')   ? $self->_update('fft')
              : (lc($space) eq 'k')   ? $self->_update('fft')
              : (lc($space) eq 'r')   ? $self->_update('bft')
              : (lc($space) eq 'rmr') ? $self->_update('bft')
	      : (lc($space) eq 'q')   ? $self->_update('all')
	      : (lc($space) eq 'kq')  ? $self->_update('all')
              :                        q{};
    $self->plotRmr, return if (lc($space) eq 'rmr');
    $self->new_params({plot_part => q{}});
    my $command = $self->_plot_command($space);
    $self->dispose($command, "plotting");
    $pf->increment if (lc($space) ne 'e');
    if ((ref($self) =~ m{Data}) and $self->get("fitting")) {
      foreach my $p (qw(fit res bkg)) {
	next if not $pf->get("plot_$p");
	next if (($p eq 'bkg') and (not $self->get('fit_do_bkg')));
	$self->part_plot($p, $space);
	$pf->increment;
      };
      if ($pf->get("plot_win")) {
	$self->plot_window($space);
	$pf->increment;
      };
    };
    return $self;
  };
  sub _plot_command {
    my ($self, $space) = @_;
    if (not $self->plottable) {
      my $class = ref $self;
      croak("$class objects are not plottable");
    };
    if ((lc($space) eq 'e') and (not ref($self) =~ m{Data})) {
      my $class = ref $self;
      croak("$class objects are not plottable in energy");
    };
    my $string = (lc($space) eq 'e')   ? $self->_plotE_command
               : (lc($space) eq 'k')   ? $self->_plotk_command
               : (lc($space) eq 'r')   ? $self->_plotR_command
               : (lc($space) eq 'rmr') ? $self->_plotRmr_command
	       : (lc($space) eq 'q')   ? $self->_plotq_command
	       : (lc($space) eq 'kq')  ? $self->_plotkq_command
               : q{};
    return $string;
  };

  sub _plotk_command {
    my ($self, $space) = @_;
    if (not $self->plottable) {
      my $class = ref $self;
      croak("$class objects are not plottable");
    };
    $space ||= 'k';
    my $pf  = Ifeffit::Demeter->get_mode('plot');
    my $string = q{};
    my $group = $self->get_group;
    my $kw = $pf->get('kweight');

    my ($xlorig, $ylorig) = $pf->get(qw(xlabel ylabel));
    my $xl = "k (\\A\\u-1\\d)" if ($xlorig =~ /^\s*$/);
    my $yl = ($kw and ($ylorig =~ /^\s*$/))       ? sprintf("k\\u%d\\d\\gx(k) (\\A\\u-%d\\d)", $kw, $kw)
           : ((not $kw) and ($ylorig =~ /^\s*$/)) ? "\\gx(k)" # special y label for kw=0
           :                                        $ylorig;
    (my $title = "'".$self->label."'") =~ s{'D_E_F_A_U_L_T'}{Plot of paths};
    $pf->set({key    => $self->label,
	      title  => sprintf("%s in %s space", $title, $space),
	      xlabel => $xl,
	      ylabel => $yl,
	     });
    $string = ($pf->get('new'))
      ? $self->template("plot", "newk")
      : $self->template("plot", "overk");
    ## reinitialize the local plot parameters
    $pf -> reinitialize($xlorig, $ylorig);
    return $string;
  };

  sub _plotR_command {
    my ($self) = @_;
    if (not $self->plottable) {
      my $class = ref $self;
      croak("$class objects are not plottable");
    };
    my $pf  = Ifeffit::Demeter->get_mode('plot');
    my $string = q{};
    my $group = $self->get_group;
    my %open   = ('m'=>"|",        e=>"Env[",     r=>"Re[",     i=>"Im[",     p=>"Phase[");
    my %close  = ('m'=>"|",        e=>"]",        r=>"]",       i=>"]",       p=>"]");
    my %suffix = ('m'=>"chir_mag", e=>"chir_mag", r=>"chir_re", i=>"chir_im", p=>"chir_pha");
    my $part   = lc($pf->get("r_pl"));
    my $kw = $pf->get('kweight');
    my ($xl, $yl) = $pf->get(qw(xlabel ylabel));
    $pf->set({xlabel => "R (\\A)"}) if ($xl =~ /^\s*$/);
    $pf->set({ylabel => sprintf("%s\\gx(R)%s (\\A\\u-%.3g\\d)", $open{$part}, $close{$part}, $kw+1)})
      if ($yl =~ /^\s*$/);
    (my $title = "'".$self->label."'") =~ s{'D_E_F_A_U_L_T'}{Plot of paths};
    $pf->set({key    => $self->label,
	      title  => sprintf("%s in R space", $title),
	     });

    $string = ($pf->get('new'))
      ? $self->template("plot", "newr")
      : $self->template("plot", "overr");
    if ($part eq 'e') {		# envelope
      my $pm = $self->get("plot_multiplier");
      $self->set({plot_multiplier=>-1*$pm});
      my $this = $self->template("plot", "overr");
      my $datalabel = $self->label;
      ## (?<+ ) is the positive zero-width look behind -- it only # }
      ## replaces the label when it follows q{key="}, i.e. it won't get
      ## confused by the same text in the title for a newplot
      $this =~ s{(?<=key=")$datalabel}{};         # ") silly emacs!
      $string .= $this;
      $self->set({plot_multiplier=>$pm});
    };

    ## reinitialize the local plot parameters
    $pf -> reinitialize(q{}, q{});
    return $string;
  };

  sub _plotq_command {
    my ($self) = @_;
    if (not $self->plottable) {
      my $class = ref $self;
      croak("$class objects are not plottable");
    };
    my $pf  = Ifeffit::Demeter->get_mode('plot');
    my $string = q{};
    my $group = $self->get_group;
    my %open   = ('m'=>"|",        e=>"Env[",     r=>"Re[",     i=>"Im[",     p=>"Phase["   );
    my %close  = ('m'=>"|",        e=>"]",        r=>"]",       i=>"]",       p=>"]"        );
    my $part   = lc($pf->get("q_pl"));
    my $kw = $pf->get('kweight');
    my ($xl, $yl) = $pf->get(qw(xlabel ylabel));
    $pf->set({xlabel => "k (\\A\\u-1\\d)"}) if ($xl =~ /^\s*$/);
    $pf->set({ylabel => sprintf("%s\\gx(q)%s (\\A\\u-%.3g\\d)", $open{$part}, $close{$part}, $kw)})
      if ($yl =~ /^\s*$/);
    (my $title = "'".$self->label."'") =~ s{'D_E_F_A_U_L_T'}{Plot of paths};
    $pf->set({key    => $self->label,
	      title  => sprintf("%s in q space", $title),
	     });

    $string = ($pf->get('new'))
      ? $self->template("plot", "newq")
      : $self->template("plot", "overq");
    if ($part eq 'e') {		# envelope
      my $pm = $self->get("plot_multiplier");
      $self->set({plot_multiplier=>-1*$pm});
      my $this = $self->template("plot", "overr");
      my $datalabel = $self->label;
      ## (?<+ ) is the positive zero-width look behind -- it only # }
      ## replaces the label when it follows q{key="}, i.e. it won't get
      ## confused by the same text in the title for a newplot
      $this =~ s{(?<=key=")$datalabel}{};         # ") silly emacs!
      $string .= $this;
      $self->set({plot_multiplier=>$pm});
    };

    ## reinitialize the local plot parameters
    $pf -> reinitialize(q{}, q{});
    return $string;
  };

  sub _plotkq_command {
    my ($self) = @_;
    my $pf  = Ifeffit::Demeter->get_mode('plot');
    if (not $self->plottable) {
      my $class = ref $self;
      croak("$class objects are not plottable");
    };
    my $string = q{};
    my $save = $self->label;
    $self -> set({label => $save . " in k space"});
    $string .= $self->_plotk_command('k and q');
    $pf -> increment;
    $self -> set({label => $save . " in q space"});
    $string .= $self->_plotq_command;
    $self -> set({label => $save});
    return $string;
  };

  sub plotRmr {
    my ($self) = @_;
    if (not $self->plottable) {
      my $class = ref $self;
      croak("$class objects are not plottable");
    };
    my $string = q{};
    my ($lab, $yoff, $up) = ( $self->label, $self->get('y_offset'), 0.6*max($self->get_array("chir_mag")) );
    $self -> set({'y_offset' => $yoff+$up});
    $self -> po -> set({r_pl=>'m'});
    $string .= $self->plot('R');
    $self -> po -> increment;

    my $color = $self->po->get("c0");
    $self -> set({'y_offset' => $yoff,
		  label      => q{},
		 });
    $self -> po -> set({r_pl      => 'r',
			color     => $color,
			increment => 0,
		       });
    $string .= $self->plot('R');

    $self -> set({label => $lab});
    return $self;
  };






  sub default_k_weight {
    my ($self) = @_;
    my $data = $self->data;
    carp("Not an Ifeffit::Demeter::Data object"), return 1 if (ref($data) !~ /Data/);
    my $kw = 1;			# return 1 is no other selected
  SWITCH: {
      $kw = sprintf("%.3f", $data->get('fit_karb_value')), last SWITCH
	if ($data->get('karb') and ($data->get('karb_value') =~ $NUMBER));
      $kw = 1, last SWITCH if $data->get('fit_k1');
      $kw = 2, last SWITCH if $data->get('fit_k2');
      $kw = 3, last SWITCH if $data->get('fit_k3');
    };
    return $kw;
  };


  sub title_glob {
    my ($self, $globname, $space) = @_;
    my $data = $self->data;
    $space = lc($space);
    my $type = ($space eq 'e') ? " mu(E)"   :
               ($space eq 'n') ? " norm(E)" :
               ($space eq 'k') ? " chi(k)"  :
               ($space eq 'r') ? " chi(R)"  :
               ($space eq 'q') ? " chi(q)"  :
               ($space eq 'f') ? " fit"     :
	 	                 q{}        ;
    my @titles = split(/\n/, $data->data_parameter_report);
    @titles = split(/\n/, $data->fit_parameter_report) if ($space eq 'f');
    my $i = 0;
    $self->dispose("erase \$$globname\*");
    foreach my $line ("Demeter$type file -- Demeter $Ifeffit::Demeter::VERSION", @titles, "--") {
      ++$i;
      my $t = sprintf("%s%2.2d", $globname, $i);
      Ifeffit::put_string($t, $line);
    };
    return $self;
  };

  sub _save_chi {
    my ($self, $space, $filename) = @_;
    my $pf = $self->get_mode('plot');
    if (not $self->plottable) {
      my $class = ref $self;
      croak("$class objects do not have data that can be saved");
    };
    my $string = q{};
    $space = lc($space);
    croak("Ifeffit::Demeter: '$space' is not a valid space for saving chi xdata (k k1 k2 k3 r q)")
      if ($space !~ /\A(?:k$NUMBER?|r|q)\z/); # }

    my $data = $self->data;
    my $how = ($space eq 'k') ? "chi(k)" :
              ($space eq 'r') ? "chi(R)" :
		                "chi(q)" ;
    $self->title_glob("dem_data_", $space);

    my ($label, $columns) = (q{}, q{});
    if ($space =~ m{\Ak0?\z}) {
      $self->_update("bft");
      $string = $self->template("process", "save_chik", {filename => $filename,
							 titles   => "dem_data_*"});
    } elsif ($space =~ /\Ak($NUMBER)/) {
      croak("Not doing arbitrary wight chi(k) files just now");
      #$string .= sprintf("set %s.chik = %s.k^%.3f*%s.chi\n", $self, $self, $1, $self);
      #$label   = "k chi" . int($1) . " win";
      #$columns = "$self.k, $self.chik, $self.win";
      #$how = "chi(k) * k^$1";
    } elsif ($space eq 'r') {
      $self->_update("all");
      $string = $self->template("process", "save_chir", {filename => $filename,
							 titles   => "dem_data_*"});
    } elsif ($space eq 'q') {
      $self->_update("all");
      $string = $self->template("process", "save_chiq", {filename => $filename,
							 titles	  => "dem_data_*",});
    } else {
      croak("Ifeffit::Demeter::save: How did you get here?");
    }

    return $string;
  };

  my $opt  = Regexp::List->new;
  my %regexp = (
		commands   => $opt->list2re(qw{ f1f2 bkg_cl chi_noise color comment correl cursor
                                                def echo erase exit feffit ff2chi fftf fftr
                                                get_path guess history linestyle load
                                                log macro minimize newplot path pause plot
                                                plot_arrow plot_marker plot_text pre_edge print
                                                quit random read_data rename reset restore
                                                save set show spline sync unguess window
                                                write_data zoom } ), # }),
		function   => $opt->list2re(qw{abs min max sign sqrt exp log
   		                               ln log10 sin cos tan asin acos
   		                               atan sinh tanh coth gamma loggamma
   		                               erf erfc gauss loren pvoight debye
   		                               eins npts ceil floor vsum vprod
   		                               indarr ones zeros range deriv penalty
  		                               smooth interp qinterp splint eins debye } ), # }),
		program    => $opt->list2re(qw(chi_reduced chi_square core_width correl_min
                                               cursor_x cursor_y dk dr data_set data_total
                                               dk1 dk2 dk1_spl dk2_spl dr1 dr2 e0 edge_step
                                               epsilon_k epsilon_r etok kmax kmin kmax_spl
                                               kmax_suggest kmin_spl kweight kweight_spl kwindow
                                               n_idp n_varys ncolumn_label nknots norm1 norm2
                                               norm_c0 norm_c1 norm_c2 path_index pi pre1 pre2
                                               pre_offset pre_slope qmax_out qsp r_factor rbkg
                                               rmax rmax_out rmin rsp rweight rwin rwindow toler)),
		window     => $opt->list2re(qw(kaiser-bessel hanning welch parzen sine gaussian)),
		pathparams => $opt->list2re(qw(e0 ei sigma2 s02 delr third fourth dphase)),
		element    => $opt->list2re(qw(h he li be b c n o f ne na mg al si p s cl ar
                                               k ca sc ti v cr mn fe co ni cu zn ga ge as se
                                               br kr rb sr y zr nb mo tc ru rh pd ag cd in sn
                                               sb te i xe cs ba la ce pr nd pm sm eu gd tb dy
                                               ho er tm yb lu hf ta w re os ir pt au hg tl pb
                                               bi po at rn fr ra ac th pa u np pu)),
		edge      => $opt->list2re(qw(k l1 l2 l3)),
		modes     => $opt->list2re(keys %mode),
		feffcards => $opt->list2re(qw(atoms control print title end rmultiplier
                                              cfaverage overlap afolp edge hole potentials
                                              s02 exchange folp nohole rgrid scf unfreezef
                                              interstitial ion spin exafs xanes ellipticity ldos
                                              multipole polarization danes fprime rphases rsigma
                                              tdlda xes xmcd xncd fms debye rpath rmax nleg pcriteria
                                              ss criteria iorder nstar debye corrections sig2)),
		separator => '[ \t]*[ \t=,][ \t]*',
		clamp     => $opt->list2re(qw(none slight weak medium strong rigid)),
		config    => $opt->list2re(qw(type default minint maxint options
					      units onvalue offvalue)),
		stats     => $opt->list2re(qw(n_idp n_varys chi_square chi_reduced 
					      r_factor epsilon_k epsilon_r data_total
					      happiness)),
		atoms_lattice  => $opt->list2re(qw(a b c alpha beta gamma space shift)),
		atoms_gas      => $opt->list2re(qw(nitrogen argon helium krypton xenon)),
		atoms_obsolete => $opt->list2re(qw(output geom
						   fdat nepoints xanes modules
						   message noanomalous self i0
						   mcmaster dwarf reflections refile
						   egrid index corrections
						   emin emax estep egrid qvec dafs
						  )),
		spacegroup     => $opt->list2re(qw(number full new_symbol thirtyfive
						   schoenflies bravais shorthand positions
						   shiftvec npos)),
		plotting_backends => $opt->list2re(qw(pgplot gnuplot)),
		data_parts => $opt->list2re(qw(fit bkg res)),
	       );


  sub _regexp { q{} };		# fallback
  sub regexp {
    my ($self, $which, $bare) = @_;
    $which ||= q{};
    $which   = lc($which);
    $bare  ||= 0;
    my $re = ( $which and exists($regexp{$which}) ) ? $regexp{$which} : $self -> _regexp;
    return $re if (   $bare
		   or ($which eq 'separator')
		   or ($re =~ m{\A\s*\z}o)
		  );
    return '\A' . $re . '\z';
  };

  sub plottable {
    my ($self) = @_;
    return 0;
  };

  sub hashes {
    my ($self) = @_;
    my $hashes = "###__";
    return $hashes;
  };

  sub yesno {
    my ($self, $attribute) = @_;
    my $value = $self->get($attribute);
    return ($value) ? 'yes' : 'no';
  };
  sub truefalse {
    my ($self, $attribute) = @_;
    my $value = $self->get($attribute);
    return ($value) ? 'true' : 'false';
  };
  sub onezero {
    my ($self, $attribute) = @_;
    my $value = $self->get($attribute);
    return ($value) ? '1' : '0';
  };
  sub is_true {
    my ($self, $value) = @_;
    return 1 if ($value =~ m{^[ty]}i);
    return 0 if ($value =~ m{^[fn]}i);
    return 0 if (($value =~ m{$NUMBER}) and ($value == 0));
    return 1 if ($value =~ m{$NUMBER});
    return 0;
  };

  sub dumpit {
    my ($self) = @_;
    my %params=$self->get_all;
    use Data::Dumper;
    print Data::Dumper->Dump([\%params],[qw(*params)]);
  };

};


1;

=head1 NAME

Ifeffit::Demeter -  An object oriented EXAFS data analysis system using Ifeffit

=head1 VERSION

This documentation refers to Ifeffit::Demeter version 0.1.0

=head1 SYNOPSIS

Import Demeter components into your program:

  use Ifeffit::Demeter;

This will import all Demeter components into your program.  The
components are:

   Atoms Data Path Plot Config GDS Fit Feff ScatteringPath

Importing the Fit component forces the import of the Data, Path, and
GDS components.

You can also specify subsets of the Demeter system for import, which
may slightly speed up start-up.

  use Ifeffit::Demeter qw(Data);

=head1 EXAMPLE

Here is a complete script for analyzing copper data:

  #!/usr/bin/perl -I/home/bruce/codes/demeter
  use warnings;
  use strict;
  use Ifeffit::Demeter;
  #
  print "Sample fit to copper data using Demeter $Ifeffit::Demeter::VERSION\n";
  Ifeffit::Demeter->set_mode({screen=>1, ifeffit=>1});
  #
  ## Data object: set the processing and fit parameters
  my $dobject = Ifeffit::Demeter::Data -> new({group => 'data0',});
  $dobject ->set({file      => "example/cu/cu10k.chi",
                  is_chi    => 1,
		  fft_kmax  => 3, # \ note that this gets
		  fft_kmin  => 14,# / fixed automagically
		  bft_rmax  => "4.3",
		  fit_space => 'K',
		  fit_k1    => 1,
		  fit_k3    => 1,
		  label     => 'My copper data',
	         });
  #
  ## GDS objects for isotropic expansion + correlated Debye model
  my @gdsobjects =
    (Ifeffit::Demeter::GDS ->
        new({type => 'guess', name => 'alpha', mathexp => 0}),
     Ifeffit::Demeter::GDS ->
        new({type => 'guess', name => 'amp',   mathexp => 1}),
     Ifeffit::Demeter::GDS ->
        new({type => 'guess', name => 'enot',  mathexp => 0}),
     Ifeffit::Demeter::GDS ->
        new({type => 'guess', name => 'theta', mathexp => 500}),
     Ifeffit::Demeter::GDS ->
        new({type => 'set',   name => 'temp',  mathexp => 300}),
     Ifeffit::Demeter::GDS ->
        new({type => 'set',   name => 'sigmm', mathexp => 0.00052}),
    );
  #
  ## Path objects for the first 5 paths in copper (3 shell fit)
  my @pobjects = ();
  foreach my $i (0 .. 4) {
    $pobjects[$i] = Ifeffit::Demeter::Path -> new();
    $pobjects[$i ]->set({data     => $dobject,
		         folder   => 'example/cu/',
		         file     => sprintf("feff%4.4d.dat", $i+1),
		         s02      => 'amp',
		         e0       => 'enot',
		         delr     => 'alpha*reff',
		         sigma2   => 'debye(temp, theta) + sigmm',
		        });
  };
  #
  ## Fit object: collection of GDS, Data, and Path objects
  my $fitobject = Ifeffit::Demeter::Fit -> new({gds   => \@gdsobjects,
					        data  => [$dobject],
					        paths => \@pobjects,
					       });
  ## do the fit (or the sum of paths)
  $fitobject -> fit;
  #
  ## plot the data + fit + paths in a space
  $dobject -> po ->set({plot_data => 1, plot_fit  => 1,
                        plot_res  => 0, plot_win  => 1,});
  foreach my $obj ($dobject, @pobjects,) {
    $obj -> plot("r");
  };
  #
  ## save the results of the fit and write a log file
  $dobject->save_fit("cufit.fit");
  my ($header, $footer) = ("Fit to copper data\n", q{});
  $fitobject -> logfile("cufit.log", $header, $footer);

This example starts by defining each of the data objects.  There is
one data object, 5 path objects, and 6 GDS objects and these are
gathered in to one fit object.  The C<set_mode> method defines how the
Ifeffit command generated will be dispatched.  After the fit is
defined by calling the C<fit> method on the Fit object, a number of
chores can be done.  First, the results of the fit are evaluated.
This retrieves best fit values for all GDS parameters from Ifeffit,
evaluates all path parameters for all the Path objects, and retrieves
the correlations between guess parameters from Ifeffit.  Then plots
are made, theresults of the fit are saved as an ascii data file, and a
log file is written.

=head1 DESCRIPTION

This module provides an object oriented interface to the EXAFS data
analysis capabilities of the popular and powerful Ifeffit package.
Mindful that the Ifeffit API involves streams of text commands, this
package is, at heart, a code generator.  Most methods of this package
return text.  All actual interaction with Ifeffit is handled through a
single method, C<dispose>, which is described below.  The typical use
of this package is to accumulate text in a scalar variable through
successive calls to the various code generating methods.  This text is
then disposed to Ifeffit, to a file, or elsewhere.

This package is aimed at many targets.  It can be the back-end of a
graphical data analysis program, providing the glue between the
on-screen representation of the fit and the actual command executed by
Ifeffit.  It can be used for one-off data analysis chores -- indeed
most of the examples that come with the package can be reworked into
useful one-off scripts.  It can also be the back-end to sophisticated
data analysis chores such as high-throughout data fitting or complex
physical modeling.

Ifeffit::Demeter is actually a parent class for the objects that are
directly manipulated in any real program using Ifeffit::Demeter.
These are the major subclasses:

=over 4

=item L<Ifeffit::Demeter::Data>

The data object used to import chi(k) data from a file and set
parameters for Fourier transforms, fitting range, and other aspects of
the fit.  This, in turn, has several major subclasses devoted to
specific data processing chores.

=item L<Ifeffit::Demeter::Path>

The path object used to define a path in a fit and to set math
expressions for its path parameters.

=item L<Ifeffit::Demeter::GDS>

The object used to define a guess, def or set parameter for use in the
fit.  This is also used to define restraints and a few other kinds of
parameters.

=item L<Ifeffit::Demeter::Fit>

This object is the collection of Data, Path, and GDS objects which
compromises a fit.  This, in turn, has several subclasses devoted to
particular aspects of the fitting problem.

=item L<Ifeffit::Demeter::Plot>

The object which controls how plots are made from the other
Ifeffit::Demeter objects

=item L<Ifeffit::Demeter::Config>

The object which controls configuraton of the the Demeter system and
its components.  This is a singleton object (i.e. only one exists in
any instance of Demeter).

=item L<Ifeffit::Demeter::Atoms>

A crystallography object which is used to generate the structure data
for a Feff object.

=item L<Ifeffit::Demeter::Feff>

A object defining the contents of a Feff calculation and providing
methods for running parts of Feff.

=item L<Ifeffit::Demeter::ScatteringPath>

On object defining a scattering path from a Feff object.  This may be
linked to a Path object used in a fit.

=back

Each of these objects is implemented as an inside-out object, as
described in 
L<"Perl Best Practices" by Damian Conway|http://www.oreilly.com/catalog/perlbp/>
and in the L<Class::Std>
and L<Class::Std::Utils> module.  Inside-out objects provide complete
data encapsolation.  This means that the only way to access the data
associated with the various objects is to use the methods described
below and in the documentation pages for the various subclasses.

Additionally, there is an L<Ifeffit::Demeter::Tools> module which
provides a variety of useful class methods.

=head1 METHODS

An object of this class represents a part of the problem of EXAFS data
processing and analysis.  That component might be data, a path from
Feff, a parameter, a fit, or a plot.  Because all objects of this
class are inside-out objects, complete encapsolation is implemented.
The only way to interact with the data associated with each object is
through the methods described here and in the documents for each of
the sub classes.

Not every method shown in the example above is described here.  You
need to see the subclass documentation for methods specific to those
subclasses.

=head2 Constructor and accessor methods

These are the basic methods for constructing objects and accessing
their attributes.

=over 4

=item C<new>

This the constructor method.  It builds and initializes new objects.

  use Ifeffit::Demeter;
  $data_object -> Ifeffit::Demeter::Data -> new;
  $path_object -> Ifeffit::Demeter::Path -> new;
  $gds_object  -> Ifeffit::Demeter::GDS  -> new;

New can optionally take an argument which is a reference to a hash of
attributes and values for the object.  See the C<set> method for a discussion
of why you may not want to pass that hash reference to C<new>.

=item C<clone>

This method clones an object, returning the reference to the new object.

  $newobject = $oldobject->clone(\%new_arguments);

Cloning returns the reference and sets all attributes of the new
object to the values for the old object.  The optional argument is a
reference to a hash of those attributes which you wish to change for
the new object.  Passing this hash reference is equivalent to cloning
the object, then calling the C<set> method on the new object with that
hash reference.

=item C<set>

This method sets object attributes.

  $data_object -> set({kmin=>3.1, kmax=>12.7});
  $path_object -> set({file=>'feff0123.dat'});
  $gds_object  -> set({type=>'set'});

The set method of each subclass behaves slightly differently for each
subclass in the sense that error checking is performed appropriately
for each subclass.  Each subclass takes a hash reference as its
argument, as shown above.  An exception is thrown is you attempt to
C<set> an undefined attribute for every subclass except for the Config
subclass.

The argument can be an anonymous hash or a reference to a names hash.
The following are equivalent:

  $data_object -> set({file => "my.data", kmin => 2.5});

and

  %hash = {file => "my.data", kmin => 2.5};
  $data_object -> set(\%hash);

I recommend that you construct and set new objects in separate
steps. That is, do this:

  $data_object = Ifeffit::Demeter::Data -> new;
  $data_object -> set({group => "data",
                       file  => "my.data",
                       kmin  => 2.5
                      });

rather than this:

  $data_object = Ifeffit::Demeter::Data ->
        new({group => "data",
             file  => "my.data",
             kmin  => 2.5
            });

Both work and both result in the same thing.  However, the various
objects have considerable amounts of code to validate attribute
values.  The exceptions that are thrown for invalid code are more
useful if you set attributes using the accessor (C<set>) than if you
use the constructor (C<new>).  Try running these two little snippets,
each of which throws an exception because C<kmin> must take a number
as its argument:

   use Ifeffit::Demeter qw(Data);
   $data_object = Ifeffit::Demeter::Data -> new({kmin=>"x"});

and

   use Ifeffit::Demeter qw(Data);
   $data_object = Ifeffit::Demeter::Data -> new;
   $data_object -> set({kmin=>"x"});

You will see that the error message for the second is much more
indicative of where the mistake was made due to the details of the
interaction of the Carp and Class::Std modules.  On the other hand,
you might appreciate the economy of lines of code that come with
passing the arguments hash reference directly to the constructor....

=item C<Push>

This is used for pushing a value onto the array of an array-valued
attribute.  In that sense, it is much like perl's push.

   $atoms_object -> Push({titles=>"first title line"});
   $atoms_object -> Push({titles=>"another title line"});

This is similar to

   $atoms_object -> set({titles=>["first title line",
                                  "another title line"
                                 ]});

but perhaps more convenient.

=item C<get>

This is the accessor method.  It "does the right thing" in both scalar
and list context.

  $kmin = $data_object -> get('kmin');
  @window_parameters = $data_object -> get(qw(kmin kmax dk kwindow));

See the documentation for each subclass for complete lists of what
attributes are available for each subclass.  An exception is thrown if
you attempt to C<get> an undefined attribute for all subclasses except
for the Config subclass.

=item C<label> or C<name>

This is a shortcut accessor for the object label.  These are equivalent:

  $object -> label;
  $object -> get('label');

for Data, Path (and Feff (and Fit)) objects, as are

  $gds -> name;
  $gds -> get('name');

for GDS objects.  C<name> is an alias for C<label>.

=item C<serialize>

Returns the YAML serialization string for the object.  See the Fit
objects serialize method for complete details of serialization of a
fitting model.

=back

=head2 Data processing methods

A system is built into Demeter for keeping track of the state of your
objects.  It is, therefore, rarely necessary to explicitly invoke the
data processing methods.  If you call the C<plot>, Demeter will call
the C<read_data>, C<normalize>, C<fft>, and C<bft> methods as needed
to correctly make the plot.  As you change the attributes of the Data
object, Demeter will keep track of which data processing stages need
to be redone.  Consequently, the C<plot> method may be the only data
processing method you ever need to call.

These methods call the corersponding code generating methods then
dispose of that code.  The code generators are documented below, but
should rarely be necessary to call directly.

=over 4

=item C<read_data>

This method returns the Ifeffit command for importing data into
Ifeffit

  $command = $data_object->read_data;

This method is more commonly used for Data objects.  Calling this
method on a Path object will import the raw C<feffNNNN.dat> file.  See
the C<write_path> method of the Path subclass for importing a
C<feffNNNN.dat> file and turning it into chi(k) data.

=item C<fft>

This method performs a forward Fourier transform on your chi(k) data
using parameters that have been established using the C<set> method.

  $object -> fft;

If the data need to be imported, they will be automatically.

=item C<bft>

This method performs a backward Fourier transform on your chi(R) data
using parameters that have been established using the C<set> method.

  $object -> bft;

If the data need to be imported or forward transformed, they will be
automatically.

=item C<plot>

This method plots your data in the indicated space, where the space is
one of E, k, R, or q.  The details of how that plot is made are
determined by the Plot object.

  $object -> plot($space);

If the data need to be imported, forward transformed, or backward
transformed, they will be automatically.

Only Data and Path objects can be plotted.  Attempting to plot other
object types will throw and exception.

=item C<save>

This saves data or a path as a column data file.

   $command = $object -> save($argument);

The types of saved file, indicated by the argument, are

=over 4

=item xmu

7 columns: energy, mu(E), bkg(E), pre-edge line, post-edge line,
derivative of mu(E), second derivative of mu(E).

=item norm

7 columns: energy, norm(E), bkg(E), flattened mu(E), flattened
background, derivative of norm(E), second derivative of norm(E).

=item chi

6 or 7 columns: k, chi(k), window, k*chi(k), k^2*chi(k), k^3*chi(k).
If an arbitrary k-weighting is used, an additional column with that
k-weighting will be written.

=item R

6 columns: R, real part, imaginary part, magnitude, phase, R window

=item q

7 columns: q, real part, imaginary part, magnitude, phase, k window,
k-weighted chi(k) using the k-weighting of the Fourier transform.
This last column can be plotted with the real part to make a kq plot.

=item fit

6 or 7 columns: k, chi(k), fit(k), residual, background (if fitted),
window.

=back

=back

=head2 C<dispose>

This method is used to dispatch Ifeffit commands by hand.  It is used
internally by many of the methods typically used in a program.

  $object -> dispose($ifeffit_command);

See the document page for L<Ifeffit::Demeter::Dispose> for complete
details.

=head2 Operation modes

There are a few attributes of a Demeter application that are set within the
base class and so apply to all Demeter objects in use in that application.
Most of these attributes have to do with how the command generated by the
various Demeter methods get disposed of by the C<dispose> method.  Here is a
list of all these global attributes:

=over 4

=item ifeffit

This is a boolean attribute.  When true, the C<dispose> method sends commands
to the Ifeffit process.  By default this is true.

=item screen

This is a boolean attribute.  When true, the C<dispose> method sends commands
to STDOUT, which is probably displayed of the screen in a terminal emulator.
By default this is false.

=item file

When true, the C<dispose> method sends commands to a file.  The true value of
this attribute is interpreted as the file name.  The file is opened and closed
each time C<dispose> is called.  Therefore it is probably prudent to give this
attribute a value starting with an open angle bracket, such as ">filename".
This will result in commands being appended to the end of t he named file.
Note also that you will need to unlink the file at the beginning of your
script if you do not want your commands appended to the end of an existing
file.  By default this is false.

=item buffer

When true, the C<dispose> method stores commands in a memory buffer.  The true
value of this attribute can either be a reference to a scalar or a reference
to an array.  If the value is a scalar reference, the commands will be
appended to the end of the scalar.  If the value is an array reference, each
command line (where a line is terminated with a carriage return) will become
an entry in the array.  By default this is false.

=item plot

This attribute is the reference to the current Plot object.  When a plot
object is created using the normal constructor method, it becomes the value of
this attribute.  Then the attributes of that Plot object are used whenever
plots are made from other kinds of objects.  If you create and use a single
Plot object in your script, you never really need to be concerned with this
attribute.  However, if you maintain two or more Plot objects, this attribute
is the mechanism for controlling which gets used when plots are made.

=item template_process

Set the template set for data processing.  Currently in the
distribution are C<feffit>, C<ifeffit> and C<iff_columns>.

=item template_fit

Set the template set for data analysis.  Currently in the
distribution are C<feffit>, C<ifeffit> and C<iff_columns>.

=item template_plot

Set the template set for plotting.  Currently in the distribution is
C<pgplot>.

=item template_feff

Set the template set for generating feff files.  Currently in the
distribution are C<feff6>, C<feff7>, and C<feff8>.

=back

The methods for accessing the operation modes are:

=over 4

=item C<set_mode>

This is the method used to set the attributes described above.  Any Demeter
object can call this method.

   Ifeffit::Demeter -> set_mode({ifeffit=>1, screen=>1, buffer=>\@buffer_array});

See L<Ifeffit::Demeter:Dispose> for more details.

=item C<get_mode>

When called with no arguments, this method returns a hash of all attributes
their values.  When called with an argument (which must be one of the
attributes), it returns the value of that attribute.  Any Demeter object can
call this method.

   %hash = Ifeffit::Demeter -> get_mode;
   $value = Ifeffit::Demeter -> get_mode("screen");

See L<Ifeffit::Demeter:Dispose> for more details.

The first time you attempt to access the Plot object contained in the
mode hash, a Plot object will be created if one is needed.

=back

=head2 Convenience methods

=over

=item C<config>

This returns the Config object.  This is a wrapper around C<get_mode>
and is intended to be used in a method call chain with any Demeter
object.  The following are equivalent:

  my $config = $data->get_mode("params");
  $config -> set_default("clamp", "medium", 20);

and

  $data -> config -> set_default("clamp", "medium", 20);

=item C<po>

This returns the Plot object.  This is a wrapper around C<get_mode>
and is intended to be used in a method call chain with any Demeter
object.  The following are equivalent:

  my $plot = $data->get_mode("plot");
  $plot -> set("c9", 'yellowchiffon3');

and

  $data -> po -> set("c9", 'yellowchiffon3');

=back

=head2 Utility methods

Here are a number of methods used internally, but which are available
for your use.

=over 4

=item C<title_glob>

This pushes the title generated by the C<data_parameter_report> or
C<fit_parameter_report> methods into Ifeffit scalars which can then be
accessed by an Ifeffit title glob.

   $object -> title_glob($name, $which)

C<$name> is the base of the name of the string scalars in Ifeffit and
C<$which> is one of C<e>, C<n>, C<k>, C<r>, C<q>, or C<f> depending on
whether you wish to generate title lines for mu(E), normalized mu(E),
chi(k), chi(R), chi(q), or a fit.

=item C<default_k_weight>

This returns the value of the default k-weight for a Data or Path
object.  A Data object can have up to four k-weights associated with
it: 1, 2, 3, and an arbitrary value.  This method returns the
arbitrary value (if it is defined) or the lowest of the three
remaining values (if they are defined).  If none of the four are
defined, this returns 1.  For a Path object, the associated Data
object is used to determine the return value.  An exception is thrown
using Carp::carp for other objects and 1 is returned.

    $kw = $data_object -> default_k_weight;

=item C<regexp>

This returns an appropriate regular expression.

    $regexp1 = $object->regexp;
    $regexp2 = $object->regexp($arg, $bare);

When called without an argument, the regular expression returned
matches all valid attributes of the object.  This regular expression
is terminated by the C<\A> and C<\z> metacharacters.

When called with an argument, it returns a regular expression
(terminated with C<\A> and C<\z>) appropriate to the argument.  When
called with the second argument, the terminators, C<\A> and C<\z>, are
suppressed.  The current crop of arguments includes:

=over 4

=item I<commands>

All Ifeffit commands.

=item I<function>

All Ifeffit math functions.

=item I<program>

All Ifeffit program variables.

=item I<window>

All Ifeffit window types.

=item I<pathparams>

All Ifeffit path parameters.

=item I<element>

All element symbols.

=item I<edge>

All absorption edges.

=item I<feffcards>

All feff input file keywords.

=item I<separator>

The regex matching word separators in atoms or feff input files.

=item I<clamp>

All descriptive clamp values.

=item I<config>

All configuration parameter types.

=item I<stats>

All fitting statistic types.

=item I<atoms_lattice>

All Atoms attributes related to specifying the lattice.

=item I<atoms_gas>

All Atoms attributes related to specifying gases in ion chambers.

=item I<atoms_obsolete>

All deprecated Atoms attributes from earlier versions.

=item I<spacegroup>

All keys from the space groups database.

=back

=item C<get_array>

Read an array from Ifeffit.  The argument is the Ifeffit array suffix
of the array to import.

  @array = $data->get_array("xmu");

=item C<floor_ceil>

Return a two element list containingthe smallest and largest values of
an array in Ifeffit.

  ($min, $max) = $data->floor_ceil("xmu");

=item C<yofx>

Return the y value corresponding to an given x-value.  This is found
by interpolation from the specified array.

  $y = $data->yofx("xmu", q{}, $x);

The second argument (C<q{}>) in this example, is used to specify a
part of a fit, i.e. C<bkg> or C<res>.

=item C<parameter_list>

This method returns a list of all attributes of the object.  The list
is sorted asciibetically.

   @list = $object->parameter_list;

=item C<hashes>

This returns a string which can be used as a comment character in
Ifeffit.  The idea is that every comment included in the commands
generated by methods of this class use this string.  That provides a
way of distinguishing comments generated by the methods of this class
from other comment lines sent to Ifeffit.  This is a user interface
convenience.

   $string = $object->hashes;
   print "$string\n";
       ===prints===> ###___

=item C<plottable>

This returns a true value if the object is one that can be plotted.
Currently, Data and Path objects return a true value.  All others
return false.

   $can_plot = $object -> plottable;

=back

=head1 DIAGNOSTICS


=head1 CONFIGURATION AND ENVIRONMENT

See L<Ifeffit::Demeter::Config> for details about the configuration
system.

=head1 DEPENDENCIES

The dependencies of the Ifeffit::Demeter system are in the
F<Bundle/DemeterBundle.pm> file.

=head1 BUGS AND LIMITATIONS

=over 4

=item *

Serialization is incompletely implemented at this time.

=back

Please report problems to Bruce Ravel (bravel AT bnl DOT gov)

Patches are welcome.

=head1 AUTHOR

Bruce Ravel (bravel AT bnl DOT gov)

http://cars9.uchicago.edu/~ravel/software/


=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2008 Bruce Ravel (bravel AT bnl DOT gov). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
