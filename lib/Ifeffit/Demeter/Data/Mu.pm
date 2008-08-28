package Ifeffit::Demeter::Data::Mu;

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
use Carp;
use Class::Std;
use Class::Std::Utils;
use Fatal qw(open close);
use File::Basename;
use File::Spec;
use List::MoreUtils qw(any);
use Regexp::Optimizer;
use Regexp::Common;
use Readonly;
Readonly my $NUMBER  => $RE{num}{real};
Readonly my $INTEGER => $RE{num}{int};
Readonly my $ETOK    => 0.262468292;

use Ifeffit;
use Ifeffit::Demeter::Tools;
use Text::Template;
use Text::Wrap;
$Text::Wrap::columns = 65;

use Chemistry::Elements qw(get_symbol);
use Xray::Absorption;

{

  my $config = Ifeffit::Demeter->get_mode("params");
  # my %clamp = ("None"   => 0,
  # 	       "Slight" => 3,
  # 	       "Weak"   => 6,
  # 	       "Medium" => 12,
  # 	       "Strong" => 24,
  # 	       "Rigid"  => 96
  # 	      );

  sub clamp {
    my ($self, $clampval) = @_;
    my $clamp_regex = $self -> regexp("clamp");
    if ($clampval =~ m{$NUMBER}) {
      $clampval = int($clampval);
      ## this is not correct!, need to compare numeric values
      return $1 if (lc($clampval) =~ m{\A($clamp_regex)\z});
      return $clampval;
    } elsif ( lc($clampval) =~ m{\A$clamp_regex\z} ) {
      return $config->default("clamp", $clampval);
    } else {
      return 0;
    };
  };

  sub e2k {
    my ($self, $e, $how) = @_;
    return 0 if ($e<0);
    $how ||= 'rel';
    if ($how =~ m{rel}) {	# relative energy
      return sqrt($e*$ETOK);
    } else {			# absolute energy
      my $e0 = $self->get('bkg_e0');
      ($e < $e0) and ($e0 = 0);
      return sqrt(($e-$e0)*$ETOK);
    };
  };

  ## convert a k value to an absolute energy value
  sub k2e {
    my ($self, $k, $how) = @_;
    return 0 if ($k<0);
    $how ||= 'rel';
    if ($how =~ m{rel}) {	# relative energy
      return $k**2 / $ETOK;
    } else {			# absolute energy
      my $e0 = $self->get('bkg_e0');
      return ($k**2 / $ETOK) + $e0;
    };
  };

  sub xmu_string {
    my ($self) = @_;
    carp("Ifeffit::Demeter::Data::Mu: cannot put data unless the object contains mu(E) data"),
      return 0 if (not $self->get("is_xmu"));
    my $string = q{};
    $self->set({xmu_string => $string});
    return $string;
  };
  sub put_data {
    my ($self) = @_;

    ## I think this next bit is supposed to do the right thing for
    ## column data, mu(E) data, or chi(k) data
    if (not $self->get("is_col")) {
      if ($self->get("is_chi")) {
	$self->resolve_defaults;
	$self->set({update_columns => 0});
	return 0;
      } elsif ($self->get('from_athena')) {
	$self->set({update_columns => 0});
	return 0;
      } else {
	$self->initialize_e0;
	$self->set({update_columns => 0});
	return 0;
      };
    };
    $self->read_data("raw") if $self->get("update_data");

    ## get columns from ifeffit
    my @cols = split(" ", $self->get("columns"));
    unshift @cols, q{};

    my $energy_string = $self->get("energy");
    my $xmu_string  = q{};
    my $i0_string   = q{};
    if ($self->get("ln")) {
      $xmu_string =   "ln(abs(  ("
	        . $self->get("numerator")
                . ") / ("
		. $self->get("denominator")
		. ") ))";
      $i0_string = $self->get("numerator");
    } else {
      $xmu_string = "(" . $self->get("numerator") . ") / (" . $self->get("denominator") . ")";
      $i0_string = $self->get("denominator");
    };

    ## resolve column tokens
    $i0_string     =~ s{\$(\d+)}{$self.$cols[$1]}g;
    $xmu_string    =~ s{\$(\d+)}{$self.$cols[$1]}g;
    $energy_string =~ s{\$(\d+)}{$self.$cols[$1]}g;
    $self->set({i0_string     => $i0_string,
		xmu_string    => $xmu_string,
		energy_string => $energy_string});

    my $command = $self->template("process", "columns");
    $command   .= $self->template("process", "deriv");
    $self->dispose($command);
    $self->set({update_columns => 0, update_data => 0});

    $self->initialize_e0
  };

  sub initialize_e0 {
    my ($self) = @_;
    ### entering initialize_e0
    my $command = $self->template("process", "find_e0");
    $self->dispose($command);
    $self->set({bkg_e0=>Ifeffit::get_scalar("e0")});
    $self->resolve_defaults;
  };

  sub normalize {
    my ($self) = @_;
    my $group = $self->get_group;

    $self->_update("normalize");

    my $fixed = $self->get("bkg_fixstep");

    ## call pre_edge()
    my $precmd = $self->template("process", "normalize");
    $self->dispose($precmd);

    my $e0 = Ifeffit::get_scalar("e0");
    my ($elem, $edge) = $self->find_edge($e0);
    $self->set({
		bkg_e0   => $e0,
		bkg_z    => $elem,
		fft_edge => $edge,
		bkg_spl1 => $self->get('bkg_spl1'), # this odd move sets the spl1e and
		bkg_spl2 => $self->get('bkg_spl2'), # spl2e attributes correctly for the
	       });		                    # new value of e0

    ## incorporate results of pre_edge() into data object
    $self->set({
		bkg_nc0 => sprintf("%.14f", Ifeffit::get_scalar("norm_c0")),
		bkg_nc1 => sprintf("%.14f", Ifeffit::get_scalar("norm_c1")),
		bkg_nc2 => sprintf("%.14g", Ifeffit::get_scalar("norm_c2")) 
	       });

    if ($self->get('is_xmudat')) {
      $self->set({bkg_slope => 0, bkg_int => 0});
    } else {
      $self->set({
		  bkg_slope => sprintf("%.14f", Ifeffit::get_scalar("pre_slope")),
		  bkg_int   => sprintf("%.14f", Ifeffit::get_scalar("pre_offset")),
		 });
    };
    $self->set({bkg_step  => sprintf("%.7f", $fixed || Ifeffit::get_scalar("edge_step"))});
    $self->set({bkg_fitted_step => $self->get('bkg_step')}) if not ($self->get('bkg_fixstep'));
    $self->set({bkg_fitted_step => 1}) if ($self->get('is_nor'));

    $self->set({update_norm=>0});

  };

  sub autobk {
    my ($self) = @_;
    my $group = $self->get_group;

    $self->_update("background");
    my $fixed = $self->get("bkg_fixstep");

    ## make sure that a fitted edge step actually exists...
    $self->set({bkg_fitted_step => $self->get('bkg_step')})
      if not $self->get('bkg_fitted_step');

    my $command = q{};

    $command = $self->template("process", "autobk");
    if ($self->get('bkg_fixstep')) {
      $fixed = $self->get("bkg_step");
    };
    $self->dispose($command);


    ## begin setting up all the generated arrays from the background removal
    $self->set({update_bkg => 0,
		update_fft => 1,
		bkg_cl     => 0,});
    $command = $self->template("process", "post_autobk");
    $self->dispose($command);

#     $command .= sprintf("set $group.fbkg = ($group.bkg-$group.preline+(%.5f-$group.line)*$group.theta)/%.5f\n",
# 			$self->get(qw(bkg_fitted_step bkg_step)))
#       if not $self->get('is_xanes');

    if ($self->get('bkg_fixstep') or $self->get('is_nor') or $self->get('is_xanes')) {
      $command = $self->template("process", "flatten_fit");
    } else {
      $command = $self->template("process", "flatten_set");
    };
    $self->dispose($command);

    ## first and second derivative
    $command = $self->template("process", "nderiv");
    $self->dispose($command);

    $self->set({update_bkg=>0});
  };
  {
    no warnings 'once';
    # alternate names
    *spline = \ &autobk;
  }


  sub plotE {
    my ($self) = @_;
    $self->dispose($self->_plotE_command)
  };
  sub _plotE_command {
    my ($self) = @_;
    my $pf  = Ifeffit::Demeter->get_mode('plot');
    if (not ref($self) =~ m{Data}) {
      my $class = ref $self;
      croak("$class objects are not plottable");
    };
    if (not $self->get('is_xmu')) {
      carp("$self cannot be plotted in energy");
      return;
    };

    ## need to handle single or multiple data set plots.  presumably for a
    ## multiple plot you want to increment colors and just plot data.  presumably
    ## for a single, you want to increment internally and plot several traces
    my $incr = $pf->get('increment');

    ## walk through the attributes of the plot object to figure out what parts
    ## off the data should be plotted
    my @suffix_list = ();
    my @color_list  = ();
    my @key_list    = ();
    if ($pf->get('e_bkg')) { # show the background
      my $this = 'bkg';
      ($this = 'nbkg') if  ($pf->get('e_norm'));
      ($this = 'fbkg') if (($pf->get('e_norm')) and $self->get('bkg_flatten'));
      push @suffix_list, $this;
      my $n = $incr+1;
      push @color_list,  $pf->get("c$n");
      push @key_list,    "background";
    };
    if ($pf->get('e_mu')) { # show the data
      my $this = 'xmu';
      if  ($pf->get('e_der')) {
	$this = ($pf->get('e_norm')) ? 'nder' : 'der';
      } elsif (($pf->get('e_norm')) and $self->get('bkg_flatten')) {
	$this = 'flat';
      } elsif  ($pf->get('e_norm')) {
	$this = 'norm';
      };
      push @suffix_list, $this;
      my $n = $incr;
      push @color_list,  $pf->get("c$n");
      push @key_list,    $self->label;
    };
    if ($pf->get('e_pre'))  { # show the preline
      push @suffix_list, 'preline' if ($pf->get('e_pre'));
      my $n = $incr+2;
      push @color_list,  $pf->get("c$n");
      push @key_list,    "pre-edge";
    };
    if ($pf->get('e_post')) { # show the postline
      push @suffix_list, 'postline' if ($pf->get('e_post'));
      my $n = $incr+3;
      push @color_list,  $pf->get("c$n");
      push @key_list,    "post-edge";
    };

    ## convert plot ranges from relative to absolute energies
    my ($emin, $emax) = map {$_ + $self->get("bkg_e0")} $pf->get(qw(emin emax));
    my %this_plot = (emin=>$emin, emax=>$emax);

    my $string = q{};
    my ($xlorig, $ylorig) = $pf->get(qw(xlabel ylabel));
    my $xl = "E (eV)" if ($xlorig =~ /^\s*$/);
    my $yl = q{};
    if ($ylorig =~ /^\s*$/) {
      $yl = (($pf->get('e_der')) and ($pf->get('e_der')))  ? 'deriv normalized x\gm(E)'
          : ($pf->get('e_der'))                            ? 'deriv x\gm(E)'
          : ($pf->get('e_sec'))                            ? 'second deriv x\gm(E)'
	  : ($pf->get('e_norm'))                           ? 'normalized x\gm(E)'
	  :                                                  'x\gm(E)';
    };
    $pf->set({key    => $self->label,
	      title  => sprintf("%s", $self->label),
	      xlabel => $xl,
	      ylabel => $yl,
	     });

    my ($plot, $cont);
    my $counter = 0;
    foreach my $suff (@suffix_list) { # loop through list of parts to plot
      $pf->set({color  => shift(@color_list), # color is used by pgplot, not gnuplot
		key    => shift(@key_list),
		e_part => $suff,
	       });
      $this_plot{suffix} = $suff;
      $string .= $self->_plotE_string($pf, \%this_plot);
      $pf->increment;
      $pf->set({new=>0}) if ($self->get_mode("template_plot") eq 'pgplot');;
      ++$counter;
    };
    my $markers = q{};
    if ($pf->get("e_markers")) {
      my $this = 'xmu';
      if  ($pf->get('e_der')) {
	$this = ($pf->get('e_norm')) ? 'nder' : 'der';
      } elsif  ($pf->get('e_norm')) {
	$this = 'norm';
      } elsif (($pf->get('e_norm')) and $self->get('bkg_flatten')) {
	$this = 'flat';
      };
#      my $this = 'xmu';
#      ($this = 'norm') if  ($pf->get('e_norm'));
#      ($this = 'flat') if (($pf->get('e_norm')) and $self->get('bkg_flatten'));
#      ($this = 'der')  if  ($pf->get('e_der'));
      $markers .= $self->_e0_marker_command($this);
      $markers .= $self->_preline_marker_command($this)  if $pf->get('e_pre');
      $markers .= $self->_postline_marker_command($this) if $pf->get('e_post');
    };
    ## reinitialize the local plot parameters
    $pf -> reinitialize($xlorig, $ylorig);
    #return ($self->get_mode("template_plot") eq 'gnuplot') ? $markers.$string : $string.$markers;
    return $string.$markers;
  };

  sub _plotE_string {
    my ($self, $pf, $this) = @_;
    my $group = $self->get_group;
    my $string = ($pf->get('new'))
      ? $self->template("plot", "newe")
      : $self->template("plot", "overe");
    return $string;
  };





=for LiteratureReference (find_edge) (e0)
  "Gnosis," in Greek, means "knowledge"; it has been conjectured that
  [the Swiss alchemist] Paracelsus invented the word "gnome" because
  these creatures knew, and could reveal to men, the exact location of
  hidden metals.
                                   Jorge Luis Borges
                                   The Book of Imaginary Beings

=cut

  sub find_edge {
    my ($self, $e0) = @_;
    ##return ('H', 'K') unless ($absorption_exists);
    my $input = $e0;
    my ($edge, $answer, $this) = ("K", 1, 0);
    my $diff = 100000;
    foreach my $ed (qw(K L1 L2 L3)) {  # M1 M2 M3 M4 M5
    Z: foreach (1..104) {
	last Z unless (Xray::Absorption->in_resource($_));
	my $e = Xray::Absorption -> get_energy($_, $ed);
	next Z unless $e;
	$this = abs($e - $input);
	last Z if (($this > $diff) and ($e > $input));
	if ($this < $diff) {
	  $diff = $this;
	  $answer = $_;
	  $edge = $ed;
	  #print "$answer  $edge\n";
	};
      };
    };
    my $elem = get_symbol($answer);
    ##if ($config{general}{rel2tmk}) {
    do {
      ## give special treatment to the case of fe oxide.
      ($elem, $edge) = ("Fe", "K")  if (($elem eq "Nd") and ($edge eq "L1"));
      ## give special treatment to the case of mn oxide.
      ($elem, $edge) = ("Mn", "K")  if (($elem eq "Ce") and ($edge eq "L1"));
      ## prefer Bi K to Ir L1
      ($elem, $edge) = ("Bi", "L3") if (($elem eq "Ir") and ($edge eq "L1"));
      ## prefer Se K to Tl L2
      ($elem, $edge) = ("Se", "K")  if (($elem eq "Tl") and ($edge eq "L3"));
      ## prefer Pt L3 to W L2
      #($elem, $edge) = ("Pt", "L3") if (($elem eq "W") and ($edge eq "L2"));
      ## prefer Se K to Pb L2
      ($elem, $edge) = ("Rb", "K")  if (($elem eq "Pb") and ($edge eq "L2"));
      ## prefer Np L3 to At L1
      #($elem, $edge) = ("Np", "L3")  if (($elem eq "At") and ($edge eq "L1"));
      ## prefer Cr K to Ba L1
      ($elem, $edge) = ("Cr", "K")  if (($elem eq "Ba") and ($edge eq "L1"));
    };
    return ($elem, $edge);
  };

  sub save_xmu {
    my ($self, $filename) = @_;
    croak("No filename specified for save_xmu") unless $filename;

    $self->title_glob("dem_data_", "e");
    my $string = $self->template("process", "save_xmu", {filename => $filename,
							 titles   => "dem_data_*"});
    $self->dispose($string);
  };
  sub save_norm {
    my ($self, $filename) = @_;
    croak("No filename specified for save_norm") unless $filename;
    $self->title_glob("dem_data_", "n");
    my $string = $self->template("process", "save_norm", {filename => $filename,
							  titles   => "dem_data_*"});
    $self->dispose($string);
  };



};

1;


=head1 NAME

Ifeffit::Demeter::Data::Mu - Background removal and normalization of XAS mu(E) data

=head1 VERSION

This documentation refers to Ifeffit::Demeter version 0.1.

=head1 SYNOPSIS

  my $data = Ifeffit::Demeter::Data ->
       new({group => 'data0',});
  $data -> set({file      => "fe.060.xmu",
	        label     => 'My copper data',
                bkg_rbkg  => 1.4,
                bkg_spl2e => 1800,
	       });
  $data -> plot("k");

=head1 DESCRIPTION

This subclass of Ifeffit::Demeter::Data contains methods for dealing
with mu(E) data.

=head1 METHODS

=head2 Data processing methods

None of these methods are called explicitly in a script, rather they
get called behind the scenes when plots are made using the C<plot>
or C<save> methods.  They are documented here for completeness.

=over 4

=item C<normalize>

This method normalizes the data and calculates the flattened,
normalized spectrum.

  $data_object -> normalize;

=item C<autobk>

This method computes the background spline using the Autobk algorithm
and extracts chi(k) from the mu(E) data.

  $data_object -> autobk;

=item C<spline>

This is an alias for C<autobk>.

=item C<plotE>

This method plots the data in energy using information from the Plot
object.

  $data_object -> plotE;

This method is not typically called directly.  Instead it is called as
one of the options of the more generic C<plot> method.

=item C<save_xmu>

This method writes an output mu(E) file containing the background,
pre- and post-edge lines, and first and second derivatives.

  $data_object -> save_xmu($filename);

This method is not typically called directly.  Instead it is called as
one of the options of the more generic C<save> method.

=item C<save_norm>

This method writes an output mu(E) file containing the normalized data
and background, flattened data and background, and the first and second
derivatives of the normalized data.

  $data_object -> save_norm($filename);

This method is not typically called directly.  Instead it is called as
one of the options of the more generic C<save> method.

=back

=head2 Code generating methods

=over 4

=item C<step>

This method generates code for making an Ifeffit array containing a
Heaviside step function centered at the edge energy and placed on the
grid of the energy array associated with the object.  The resulting
array containing the step function will have the suffix C<step>.

    $string = $self->step;

=item C<_plotE_command>

This method generates a string containing the commands required to
plot data in energy.  It is called by the C<plotE> method, which then
disposes of the commands.

=back

=head2 Utility methods

=over 4

=item C<find_edge>

This method determines the absorber and edge of mu(E) data by
comparing the edge energy for these data to a table of edge energies
of the elements.

   ($elem, $edge) = $self->find_edge($e0);


=item C<clamp>

This method translates between numeric and descriptive values of
clamping strengths.  See the clamp configuration group for tuning the
translation between string and numeric clamp values.

=item C<e2k>

This method converts between relative energy values and wavenumber
using the group's value for e0.

=item C<k2e>

This method converts between relative wavenumber and energy values
using the group's value for e0.

=back

=head1 CONFIGURATION

See L<Ifeffit::Demeter::Config> for a description of the configuration
system.

=head1 DEPENDENCIES

Demeter's dependencies are in the F<Bundle/DemeterBundle.pm> file.

=head1 BUGS AND LIMITATIONS

=over 4

=item *

Cromer-Liberman normalization is not yet implemented.

=item *

There is currently no mechanism for importing an array into Ifeffit
and associating an object with it.

=back

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
