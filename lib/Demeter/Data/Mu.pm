package Demeter::Data::Mu;

=for Copyright
 .
 Copyright (c) 2006-2010 Bruce Ravel (bravel AT bnl DOT gov).
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

use autodie qw(open close);

use Moose::Role;
use MooseX::Aliases;

use Carp;
use File::Basename;
use File::Spec;
use List::MoreUtils qw(any all);
use Regexp::Optimizer;
use Regexp::Common;
use Readonly;
Readonly my $NUMBER  => $RE{num}{real};
Readonly my $INTEGER => $RE{num}{int};
Readonly my $ETOK    => 0.262468292;
Readonly my $PI      => 4*atan2(1,1);
Readonly my $EPSILON => 1e-4;

#use Ifeffit;
use Text::Template;
use Text::Wrap;
$Text::Wrap::columns = 65;

use Chemistry::Elements qw(get_symbol);
use Xray::Absorption;

use Demeter::StrTypes qw( Clamp );

  #my $config = Demeter->get_mode("params");
  # my %clamp = ("None"   => 0,
  # 	       "Slight" => 3,
  # 	       "Weak"   => 6,
  # 	       "Medium" => 12,
  # 	       "Strong" => 24,
  # 	       "Rigid"  => 96
  # 	      );

sub clamp {
  my ($self, $clampval) = @_;
  if ($clampval =~ m{$NUMBER}) {
    $clampval = int($clampval);
    ## this is not correct!, need to compare numeric values
    #return $1 if (lc($clampval) =~ m{\A($clamp_regex)\z});
    return $clampval;
  } elsif ( is_Clamp($clampval) ) {
    return $self->co->default("clamp", $clampval);
  } else {
    return 0;
  };
};

## recompute E or k spline boundary when the other is changed
sub spline_range {
  my ($self, $which) = @_;
  $self->tying(1);		# prevent deep recursion
 SWITCH: {
    ($which eq 'spl1') and do {
      $self->bkg_spl1e( $self->k2e($self->bkg_spl1, 'relative') );
      last SWITCH;
    };

    ($which eq 'spl1e') and do {
      $self->bkg_spl1( $self->e2k($self->bkg_spl1e, 'relative') );
      last SWITCH;
    };

    ($which eq 'spl2') and do {
      $self->bkg_spl2e( $self->k2e($self->bkg_spl2, 'relative') );
      last SWITCH;
    };

    ($which eq 'spl2e') and do {
      $self->bkg_spl2( $self->e2k($self->bkg_spl2e, 'relative') );
      last SWITCH;
    };
  };
  $self->set_nknots;
  return $self;
};

## recompute this every time the spline range or Rbkg is changed
sub set_nknots {
  my ($self) = @_;
  $self->nknots( int( 2 * ($self->bkg_spl2 - $self->bkg_spl1) * $self->bkg_rbkg / $PI ) );
  return $self;
};

# sub xmu_string {
#   my ($self) = @_;
#   carp("Demeter::Data::Mu: cannot put data unless the object contains mu(E) data\n\n"),
#     return 0 if ($self->datatype ne 'xmu');
#   my $string = q{};
#   $self->xmu_string($string);
#   return $string;
# };
sub put_data {
  my ($self) = @_;

  ## I think this next bit is supposed to do the right thing for
  ## column data, mu(E) data, or chi(k) data
  if (not $self->is_col) {
    $self->determine_data_type;
    if ($self->datatype eq "chi") {
      ##$self->plot('k');
      $self->fix_chik;
      $self->resolve_defaults;
      $self->update_columns(0);
      return 0;
    } elsif ($self->from_athena) {
      $self->update_columns(0);
      return 0;
    } else {
      $self->update_columns(0);
      $self->update_norm(1);
      $self->initialize_e0;
      return 0;
    };
  };
  $self->read_data("raw") if $self->update_data;

  ## get columns from ifeffit
  my @cols = split(" ", $self->columns);
  unshift @cols, q{};

  my $energy_string = $self->energy;
  my ($xmu_string, $i0_string, $signal_string) = (q{}, q{}, q{});
  if ($self->ln) {
    $xmu_string    =   "ln(abs(  ("
	           . $self->numerator
                   . ") / ("
		   . $self->denominator
		   . ") ))";
    $i0_string     = $self->numerator;
    $signal_string = $self->denominator;
  } else {
    $xmu_string    = "(" . $self->numerator . ") / (" . $self->denominator . ")";
    $i0_string     = $self->denominator;
    $signal_string = $self->numerator;
  };

  ## resolve column tokens
  my $group = $self->group;
  $i0_string     =~ s{\$(\d+)}{$group.$cols[$1]}g;
  $signal_string =~ s{\$(\d+)}{$group.$cols[$1]}g;
  $xmu_string    =~ s{\$(\d+)}{$group.$cols[$1]}g;
  $energy_string =~ s{\$(\d+)}{$group.$cols[$1]}g;

  $self->i0_string($i0_string);
  $self->signal_string($signal_string);
  $self->xmu_string($xmu_string);
  $self->energy_string($energy_string);

  my $command = $self->template("process", "columns");
  $command   .= $self->template("process", "deriv");
  $self->dispose($command);
  $self->i0_scale(Ifeffit::get_scalar('__i0_scale'));
  $self->signal_scale(Ifeffit::get_scalar('__signal_scale'));
  $self->update_columns(0);
  $self->update_data(0);

  $self->initialize_e0
};

sub fix_chik {
  my ($self) = @_;
  my @k = $self->get_array('k');
  return $self if ( ($k[0] == 0) and (all { abs($k[$_] - $k[$_-1] - 0.05) < $EPSILON } (1 .. $#k)) );
  my $command = $self->template("process", "fix_chik");
  ##print $command;
  $self->dispose($command);
  return $self;
};

sub initialize_e0 {
  my ($self) = @_;
  ### entering initialize_e0
  #my $command = $self->template("process", "find_e0");
  #$self->dispose($command);
  #$self->bkg_e0(Ifeffit::get_scalar("e0"));
  $self->e0('ifeffit') if not $self->bkg_e0;
  $self->resolve_defaults;
};

sub normalize {
  my ($self) = @_;
  my $group = $self->group;

  if ($self->datatype eq 'detector') {
    carp($self->name . " is a detector group, which cannot be normalized\n\n");
    return $self;
  };
  $self->_update("normalize");

  my $fixed = $self->bkg_fixstep;

  ## call pre_edge()
  my $precmd = $self->template("process", "normalize");
  $self->dispose($precmd);

  my $e0 = Ifeffit::get_scalar("e0");
  my ($elem, $edge) = $self->find_edge($e0);
  $self->bkg_e0($e0);
  $self->bkg_z($elem);
  $self->fft_edge($edge);
  $self->bkg_spl1($self->bkg_spl1); # this odd move sets the spl1e and
  $self->bkg_spl2($self->bkg_spl2); # spl2e attributes correctly for the
				    # new value of e0

  ## incorporate results of pre_edge() into data object
  $self->bkg_nc0(sprintf("%.14f", Ifeffit::get_scalar("norm_c0")));
  $self->bkg_nc1(sprintf("%.14f", Ifeffit::get_scalar("norm_c1")));
  $self->bkg_nc2(sprintf("%.14g", Ifeffit::get_scalar("norm_c2")));

  if ($self->datatype eq 'xmudat') {
    $self->bkg_slope(0);
    $self->bkg_int(0);
  } else {
    $self->bkg_slope(sprintf("%.14f", Ifeffit::get_scalar("pre_slope")));
    $self->bkg_int(sprintf("%.14f", Ifeffit::get_scalar("pre_offset")));
  };
  $self->bkg_step(sprintf("%.7f", $fixed || Ifeffit::get_scalar("edge_step")));
  $self->bkg_fitted_step($self->bkg_step) if not ($self->bkg_fixstep);
  $self->bkg_fitted_step(1) if ($self->is_nor);

  my $command = q{};
  $command .= $self->template("process", "post_autobk");
  if ($self->bkg_fixstep or $self->is_nor or ($self->datatype eq 'xanes')) {
    $command .= $self->template("process", "flatten_fit");
  } else {
    $command .= $self->template("process", "flatten_set");
  };
  $self->dispose($command);

  $self->update_norm(0);
  return $self;
};

sub autobk {
  my ($self) = @_;
  my $group = $self->group;
#      print ">>>", $self->datatype, "  ", $self->update_bkg, $/;

  if ($self->datatype eq 'detector') {
    carp($self->name . " is a detector group, which cannot have its background removed\n\n");
    return $self;
  };
  $self->_update("background");
  my $fixed = $self->bkg_fixstep;

  ## make sure that a fitted edge step actually exists...
  $self->bkg_fitted_step($self->bkg_step) if not $self->bkg_fitted_step;

  my $command = q{};

  $command = $self->template("process", "autobk");
  if ($self->bkg_fixstep) {
    $fixed = $self->bkg_step;
  };
  #$self->dispose($command);

## is it necessary to do post_autobk and flatten templates here?  they
## *were* done in the normalize method...

  ## begin setting up all the generated arrays from the background removal
  $self->update_bkg(0);
  $self->update_fft(1);
  $self->bkg_cl(0);
  $command .= $self->template("process", "post_autobk");
  #$self->dispose($command);

#     $command .= sprintf("set $group.fbkg = ($group.bkg-$group.preline+(%.5f-$group.line)*$group.theta)/%.5f\n",
# 			$self->get(qw(bkg_fitted_step bkg_step)))
#       if not $self->get('is_xanes');

  if ($self->bkg_fixstep or $self->is_nor or ($self->datatype eq 'xanes')) {
    $command .= $self->template("process", "flatten_fit");
  } else {
    $command .= $self->template("process", "flatten_set");
  };
  #$self->dispose($command);

  ## first and second derivative
  #$command .= $self->template("process", "deriv");
  $command .= $self->template("process", "nderiv");
  $self->dispose($command);

  ## note the largest value of the k array
  my @k = $self->get_array('k');
  $self->maxk($k[$#k]) if @k;

  $self->update_bkg(0);
  return $self;
};
alias spline => 'autobk';


sub plotE {
  my ($self) = @_;
  $self -> dispose($self->_plotE_command);
};
sub _plotE_command {
  my ($self) = @_;
  my $pf  = $self->mo->plot;
  if (not ref($self) =~ m{Data}) {
    my $class = ref $self;
    croak("$class objects are not plottable");
  };
  if (($self->datatype ne 'xmu') and ($self->datatype ne 'xanes')) {
    carp("$self cannot be plotted in energy\n\n");
    return;
  };

  ## need to handle single or multiple data set plots.  presumably for a
  ## multiple plot you want to increment colors and just plot data.  presumably
  ## for a single, you want to increment internally and plot several traces
  my $incr = $pf->increm;

  ## walk through the attributes of the plot object to figure out what parts
  ## off the data should be plotted
  my @suffix_list = ();
  my @color_list  = ();
  my @key_list    = ();
  my @save = ($self->bkg_eshift, $self->bkg_e0);
  if ($self->po->e_zero) {
    $self->bkg_eshift($save[0] - $self->bkg_e0);
    $self->bkg_e0(0);
  };
  if ($pf->e_bkg) { # show the background
    my $this = 'bkg';
    ($this = 'nbkg') if ($pf->e_norm);
    ($this = 'fbkg') if ($pf->e_norm and $self->bkg_flatten);
    push @suffix_list, $this;
    my $n = $incr+1;
    my $cn = "col$n";
    push @color_list,  $pf->$cn;
    push @key_list,    "background";
  };
  if ($pf->e_mu) { # show the data
    my $this = 'xmu';
    if  ($pf->e_der) {
      $this = ($pf->e_norm) ? 'nder' : 'der';
    } elsif  ($pf->e_sec) {
      $this = ($pf->e_norm) ? 'nsec' : 'sec';
    } elsif ($pf->e_norm and $self->bkg_flatten) {
      $this = 'flat';
    } elsif ($pf->e_norm) {
      $this = 'norm';
    };
    push @suffix_list, $this;
    my $n = $incr;
    my $cn = "col$n";
    push @color_list,  $pf->$cn;
    push @key_list,    $self->name;
  };
  if ($pf->e_pre)  { # show the preline
    push @suffix_list, 'preline';
    my $n = $incr+2;
    my $cn = "col$n";
    push @color_list,  $pf->$cn;
    push @key_list,    "pre-edge";
  };
  if ($pf->e_post) { # show the postline
    push @suffix_list, 'postline';
    my $n = $incr+3;
    my $cn = "col$n";
    push @color_list,  $pf->$cn;
    push @key_list,    "post-edge";
  };
  if ($pf->e_i0) { # show i0
    if ($self->i0_string) {
      push @suffix_list, 'i0';
      my $n = $incr+4;
      my $cn = "col$n";
      push @color_list,  $pf->$cn;
      push @key_list,    ($self->po->e_mu) ? $self->po->i0_text : $self->name . ": " . $self->po->i0_text;
    };
  };
  if ($pf->e_signal) { # show signal
    if ($self->signal_string) {
      push @suffix_list, 'signal';
      my $n = $incr+5;
      my $cn = "col$n";
      push @color_list,  $pf->$cn;
      push @key_list,    ($self->po->e_mu) ? 'signal' : $self->name . ": signal";
    };
  };

  ## convert plot ranges from relative to absolute energies
  my ($emin, $emax) = map {$_ + $self->bkg_e0} ($pf->emin, $pf->emax);

  my $string = q{};
  my ($xlorig, $ylorig) = ($pf->xlabel, $pf->ylabel);
  my $xl = "E (eV)" if (defined($xlorig) and ($xlorig =~ /^\s*$/));
  my $yl = q{};
  if ($ylorig =~ /^\s*$/) {
    $yl = ($pf->e_der and $pf->e_norm)  ? 'deriv normalized x\gm(E)'
        : ($pf->e_der)                  ? 'deriv x\gm(E)'
        : ($pf->e_sec and $pf->e_norm)  ? 'second deriv normalized x\gm(E)'
        : ($pf->e_sec)                  ? 'second deriv x\gm(E)'
	: ($pf->e_norm)                 ? 'normalized x\gm(E)'
	:                                 'x\gm(E)';
  };
  ($pf->showlegend) ? $pf->key($self->name) : $pf->key(q{});
  my $title = $self->name||q{Data};
  $pf->title(sprintf("%s in energy", $title)) if not $pf->title;
  #$pf->title(sprintf("%s", $self->name||q{}));
  $pf->xlabel($xl);
  $pf->ylabel($yl);

  my ($plot, $cont);
  my $counter = 0;
  foreach my $suff (@suffix_list) {  # loop through list of parts to plot
    $pf->color(shift(@color_list));  # color is used by pgplot, not gnuplot
    ($pf->showlegend) ? $pf->key(shift(@key_list)) : $pf->key(q{});
    $pf->e_part($suff);
    $string .= $self->_plotE_string;
    $pf->increment;
    $pf->New(0) if ($self->get_mode("template_plot") eq 'pgplot');;
    ++$counter;
  };
  my $markers = q{};
  if ($pf->e_markers) {
    my $this = 'xmu';
    if  ($pf->e_der) {
      $this = ($pf->e_norm) ? 'nder' : 'der';
    } elsif ($pf->e_norm) {
      $this = 'norm';
    } elsif ($pf->e_norm and $self->bkg_flatten) {
      $this = 'flat';
    };
#      my $this = 'xmu';
#      ($this = 'norm') if  ($pf->get('e_norm'));
#      ($this = 'flat') if (($pf->get('e_norm')) and $self->get('bkg_flatten'));
#      ($this = 'der')  if  ($pf->get('e_der'));
    $markers .= $self->_e0_marker_command($this);
    $markers .= $self->_preline_marker_command($this)  if $pf->e_pre;
    $markers .= $self->_postline_marker_command($this) if $pf->e_post;
  };
  ## reinitialize the local plot parameters
  #$pf -> reinitialize($xlorig, $ylorig);
  #return ($self->get_mode("template_plot") eq 'gnuplot') ? $markers.$string : $string.$markers;
  if ($self->po->e_zero) {
    $self->bkg_eshift($save[0]);
    $self->bkg_e0($save[1]);
  };
  return $string.$markers.$/;
};

sub _plotE_string {
  my ($self) = @_;
  my $group = $self->group;
  my $string = ($self->po->New)
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

sub _save_xmu_command {
  my ($self, $filename) = @_;
  croak("No filename specified for save_xmu") unless $filename;

  $self->title_glob("dem_data_", "e");
  my $string = $self->template("process", "save_xmu", {filename => $filename,
						       titles   => "dem_data_*"});
  return $string;
};
sub _save_norm_command {
  my ($self, $filename) = @_;
  croak("No filename specified for save_norm") unless $filename;
  $self->title_glob("dem_data_", "n");
  my $string = $self->template("process", "save_norm", {filename => $filename,
							titles   => "dem_data_*"});
  return $string;
};



1;


=head1 NAME

Demeter::Data::Mu - Methods for processing and plotting mu(E) data

=head1 SYNOPSIS

  my $data = Demeter::Data -> new;
  $data -> set(file      => "fe.060.xmu",
	       name      => 'My copper data',
               bkg_rbkg  => 1.4,
               bkg_spl2e => 1800,
	      );
  $data -> plot("k");

=head1 DESCRIPTION

This role of Demeter::Data contains methods for dealing with mu(E)
data.

=head1 METHODS

=head2 Data processing methods

These methods are very rarely called explicitly in a script.  Rather
they get called behind the scenes when plots are made using the
C<plot> method or if some other method is called which requires that
the data first be processed in energy.  They are documented here for
completeness.

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

=back

=head2 I/O methods

These are methods used to write out column ASCII data containing data
in energy space.

=over 4

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

Again, these are rarely needed in user scripts, but are documented for
completeness.

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

These are handy methods related to energy space data processing that
might be needed in a user script.

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

=back

=head1 CONFIGURATION

See L<Demeter::Config> for a description of the configuration
system.

=head1 DEPENDENCIES

Demeter's dependencies are in the F<Bundle/DemeterBundle.pm> file.

=head1 BUGS AND LIMITATIONS

=over 4

=item *

Cromer-Liberman normalization is not yet implemented.

=item *

Something like the Penner-Hahn mxan would be nice also.

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

Copyright (c) 2006-2010 Bruce Ravel (bravel AT bnl DOT gov). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
