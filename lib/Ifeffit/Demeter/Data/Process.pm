package Ifeffit::Demeter::Data::Process;

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

use autodie qw(open close);

use Moose::Role;

use Carp;
use List::Util qw(reduce);
use List::MoreUtils qw(minmax firstval);
# use Regexp::Optimizer;
# use Regexp::Common;
use Readonly;
# Readonly my $NUMBER  => $RE{num}{real};
Readonly my $EPSILON => 1e-5;



sub rebin {
  my ($self, $rhash) = @_;
  #$$rhash{group} ||= q{};
  my $standard = $self->mode->standard;
  $self->standard;		# make self the standard for rebinning
  foreach my $k (keys %$rhash) {
    $self -> c0 -> set("rebin_$k" => $$rhash{$k});
  };
  my $rebinned = $self->clone;
  $rebinned -> generated(1);
  $rebinned -> update_norm(1);
  $rebinned -> name($self->name . " rebinned");

  my $string = $rebinned->template("process", "rebin");
  $rebinned->dispose($string);

  $string = $rebinned->template("process", "deriv");
  $rebinned->dispose($string);

  (ref($standard) =~ m{Data}) ? $standard->standard : $self->unset_standard;
  return $rebinned;
};


  ## dispersive
  ## deconvolute
  ## self-absorption

=for LiteratureReference (merge)
  We also read in Pliny that the Dragons of Ethiopia often cross the Red
  Sea into Arabia, in search of better sources of nourishment.  In order
  to perform this feat, four or five Dragons "twist and interlace
  together like so many osiers in a hurdle."
                                   Jorge Luis Borges
                                   The Book of Imaginary Beings

=cut

## merge
sub merge {
  my ($self, $how, @data) = @_;
  $how = lc($how);
  croak("Ifeffit::Demeter::Data::Process: \$data->merge(\$how, \@data) where \$how = e|k|n") if ($how !~ m{^[ekn]});
  my $standard = $self->mode->standard;
  $self->standard;		# make self the standard for merging

  my $merged = $self->clone;
  $self->mergeE('x', @data) if ($how =~ m{^e});
  $self->mergeE('n', @data) if ($how =~ m{^n});
  if ($how =~ m{^k}) {
    $merged->datatype('chi');
    $self->mergek(@data);
  };

  my $ndata = $#data + 2;
  my $config = $self->mode->config;
  $config -> set(ndata=>$ndata);

  my $string = $merged->template("process", "merge_end"); #, {ndata=>$ndata});
  $self->dispose($string);
  $merged -> generated(1);
  $merged -> is_merge($how);
  $merged -> update_norm(($how =~ m{^k}) ? 0 : 1);
  $merged -> update_fft(1);
  $merged -> bkg_eshift(0);
  $merged -> i0_string(q{});
  $merged -> name("merged data");
  ($how =~ m{^k}) ? $merged -> datatype('chi') : $merged -> datatype('xmu');

  (ref($standard) =~ m{Data}) ? $standard->standard : $self->unset_standard;
  return $merged;
};
sub mergeE {
  my ($self, $how, @data) = @_;
  carp("Ifeffit::Demeter::Data::Process::mergeE: first argument MUST be x or n.") if ($how !~ m{^[nx]});
  $self -> _update("normalize")  if ($how eq 'x');
  $self -> _update("background") if ($how eq 'n');

  my ($emin, $emax) = (-1e10, 1e10);
  ## make an array in the m___erge group containing the longest common range of data
  foreach my $d ($self, @data) {
    next if (ref($d) !~ m{Data});
    $d -> _update("normalize")  if ($how eq 'x');
    $d -> _update("background") if ($how eq 'n');
    my @array = $d->get_array("energy");
    ($emin = $array[0])  if ($array[0]  > $emin);
    ($emax = $array[-1]) if ($array[-1] < $emax);
  };
  my $config = $self->mode->config;
  $config -> set(merge_min   => $emin,
		 merge_max   => $emax,
		 merge_space => "energy",
		 merge_data  => ($how eq 'x') ? "xmu" : 'norm',
		);
  my $string = $self->template("process", "merge_subarray");
  $string   .= $self->template("process", "merge_start");
  $self->dispose($string);

  foreach my $d ($self, @data) {
    next if (ref($d) !~ m{Data});
    my $string = $d->template("process", "merge_interp");
    $string   .= $d->template("process", "merge");
    $self->dispose($string);
  };
};
sub mergek {
  my ($self, @data) = @_;
  $self -> _update("fft");

  my ($kmin, $kmax) = (-1e10, 1e10);
  ## make an array in the m___erge group containing the longest common range of data
  foreach my $d ($self, @data) {
    next if (ref($d) !~ m{Data});
    $d -> _update("fft");
    my @array = $d->get_array("k");
    #print join("|", "----------", $d, $array[0], $array[-1]), $/;
    ($kmin = $array[0])  if ($array[0]  > $kmin);
    ($kmax = $array[-1]) if ($array[-1] < $kmax);
  };
  my $config = $self->mode->config;
  $config -> set(merge_min   => $kmin,
		 merge_max   => $kmax,
		 merge_space => "k",
		 merge_data  => 'chi',
		);
  my $string = $self->template("process", "merge_subarray");
  $string   .= $self->template("process", "merge_start");
  $self->dispose($string);

  foreach my $d ($self, @data) {
    next if (ref($d) !~ m{Data});
    my $string = $d->template("process", "merge_interp");
    $string   .= $d->template("process", "merge");
    $self->dispose($string);
  };
};


=for LiteratureReference (truncate)
  Tunk-Poj pursued the Antelope across the entire firmament.  Finally,
  the Antelope, exhausted, fell to the earth and Tunk-Poj cut off its
  two hind legs. "Men," he said, "are growing smaller and weaker every
  day.  How can they hunt Six-Legged Antelopes if I myself can barely
  catch them?"  Since that day, antelopes have had four legs.
                                      Jorge Luis Borges
                                      The Book of Imaginary Beings

=cut

sub Truncate {
  my ($self, $beforeafter, $value) = @_;
  if ($self->datatype eq "xmu") {
    $self -> _update("normalize");
    $self -> mode -> config -> set(trun_x => 'energy', 'trun_y' => 'xmu');
  } elsif ($self->datatype eq "chi") {
    $self -> mode -> config -> set(trun_x => 'k', 'trun_y' => 'chi');
  };				# also not_data, trun_y can be something else
  $self -> mode -> config -> set(trun_ba => (lc($beforeafter) =~ m{\Ab}) ? 'before' : 'after',
				 trun_value => $value);

  my $string = q{};
  if (lc($beforeafter) =~ m{\Ab}) { # truncate preceding values
    $string = $self->template("process", "truncate_before");
  } else {			    # truncate following values
    $string = $self->template("process", "truncate_after");
  };
  $self->dispose($string);

  ## flag data for reprocessing
  if ($self->datatype eq "xmu") {
    $self->update_norm(1);
  } elsif ($self->datatype eq "chi") {
    $self->update_fft(1);
  };
};



=for LiteratureReference (deglitch)
  The Hsing-tien is a headless creature that fought against the gods
  and was decapitated; it has remained ever afterward headless.  Its
  eyes are in its breast and its mouth is its navel.  It hops and
  skips through the open countryside, brandishing its axe and its
  shield.
                                      T'ai Kuang Chi in
                                      Jorge Luis Borges'
                                      The Book of Imaginary Beings

=cut

sub deglitch {
  my ($self, @values) = @_;
  carp("$self is not mu(E) data"), return if ($self->datatype ne "xmu");
  $self -> _update("normalize");
  my @x = $self->get_array("energy");
  foreach my $v (@values) {
    carp("$v is not within the data range of $self"), next if (($v < $x[0]) or ($v > $x[-1]));
    my $nearest = reduce { abs($a-$v) < abs($b-$v) ? $a : $b } @x;
    if ($nearest <= $x[2]) {
      $self -> Truncate("before", $x[3]);
    } elsif ($nearest >= $x[-2]) {
      $self -> Truncate("after", $x[-3]);
    } else {
      $self -> mode -> config -> set(degl_point => $nearest);
      my $string = $self->template("process", "deglitch");
      $self->dispose($string);
    };
  };
  $self->update_norm(1); # flag for reprocessing
};


sub smooth {
  my ($self, $n) = @_;
  ($n = 1) if ($n < 1);
  if ($self->datatype eq "xmu") {
    $self -> _update("normalize");
    $self -> mode -> config -> set(smooth_suffix => 'xmu');
  } elsif ($self->datatype eq "chi") {
    $self -> mode -> config -> set(smooth_suffix => 'chi');
  };
  foreach (1 .. int($n)) {
    my $string = $self->template("process", "smooth");
    $self->dispose($string);
  };
  # flag for reprocessing
  if ($self->datatype eq "xmu") {
    $self->update_norm(1);
  } elsif ($self->datatype eq "chi") {
    $self->update_fft(1);
  };
};

sub convolve {
  my ($self, @args) = @_;
  my $config = $self->mode->config;;
  #croak("usage: \$self->convolve(width=>\$width, type=>\$type, which=>\$which)"), return
  #  if (ref($args) !~ /HASH/);
  my %args = @args;
  $args{width} ||= 0;
  ($args{width}  = 0) if ($args{width} < 0);
  $args{type}  ||= $config->default("convolve", "type");
  $args{type}    = lc($args{type});
  ($args{type}   = $config->default("convolve", "type")) if ($args{type} !~ m{\A[gl]});
  $args{which} ||= 'xmu';
  $args{which}   = lc($args{which});
  ($args{which}  = 'xmu')      if ($args{type} !~ m{\A[cx]});
  if ($args{which} eq 'xmu') {
    $self -> _update("normalize");
  };
  $config->set(conv_type  => $args{type},
	       conv_width => $args{width},
	       conv_which => $args{which},
	      );
  my $string = $self->template("process", "convolve");
  $self->dispose($string);
  if ($args{which} eq 'xmu') {
    $self->update_norm(1);
  } elsif ($args{which} eq 'chi') {
    $self->update_fft(1);
  };
};



=for LiteratureReference (noise)
  No one seems to ever have seen [a Banshee]; they are less a shape
  than a wailing that lends horror to the nights of Ireland and
  ... the mountain regions of Scotland.
                                 Jorge Luis Borges
                                 The Book of Imaginary Beings

=cut

sub noise {
  my ($self, @args) = @_;
  my $config = $self->mode->config;;
  #croak("usage: \$self->convolve({width=>\$width, which=>\$which})"), return
  #  if (ref($args) !~ /HASH/);
  my %args = @args;
  $args{noise} ||= 0;
  ($args{noise}  = 0) if ($args{noise} < 0);
  $args{which} ||= 'xmu';
  $args{which}   = lc($args{which});
  ($args{which}  = 'xmu') if ($args{which} ne 'chi');
  if ($args{which} eq 'xmu') {
    $self -> _update("normalize");
    $args{noise} *= $self->bkg_step;
  } else {
    $self -> _update("fft");
  };
  $config -> set(noise_level => $args{noise},
		 noise_which => $args{which},
		);
  my $string = $self->template("process", "noise");
  $self->dispose($string);
  if ($args{which} eq 'xmu') {
    $self->update_norm(1);
  } elsif ($args{which} eq 'chi') {
    $self->update_fft(1);
  };
};


sub interpolate {
  my ($self, @data) = @_;

};


1;


=head1 NAME

Ifeffit::Demeter::Data::Process - Processing XAS data

=head1 VERSION

This documentation refers to Ifeffit::Demeter version 0.2.

=head1 DESCRIPTION

This subclass of L<Ifeffit::Demeter::Data> contains methods for
calibrating mu(E) data and adjusting e0.

=head1 METHODS

Note that these data processing methods are not reversable (without
reimporting the data).  Many of the examples suggest the use of the
C<clone> method for easy comparison between the processed and original
data.  In those cases cloning is a good idea because the methods
B<will> alter the arrays in Ifeffit.

=over 4

=item C<rebin>

This method rebins EXAFS data onto a standard EXAFS grid defined by
parameters that can be passed to the method via an anonymous hash.  It
returns the reference to the new object and creates an appropriate set
of Ifeffit arrays.  The new object is a clone of the original object.

  $rebinned_group = $data -> rebin(pre=>-35, xanes=>0.3);
  $rebinned_group -> plot('E');

The parameter hash can contain zero or more of these parameters:

=over 4

=item I<group>

The group name of the newly created group containing the rebinned
data.  The default is to generate a unique group name.

=item I<emin>

The boundary between the pre-edge and XANES regions, expressed in
relative energy.  The default is -30 eV.

=item I<emin>

The boundary between the XANES and EXAFS regions, expressed in
relative energy.  The default is 50 eV.

=item I<pre>

The grid size in energy of the rebinned pre-edge region.  The default
is 10 eV.

=item I<xanes>

The grid size in energy of the rebinned XANES region.  The default is
0.5 eV.

=item I<exafs>

The grid size in wavenumber of the rebinned EXAFS region.  The default
is 0.07 inverse Angstrom.

=back

See L<Ifeffit::Demeter::Config> and the rebin configuration group for
details about configuring the defaults.

=item C<merge>

This method merges a list of data groups.  The merge can be done in
mu(E), norm(E), or chi(k).  A list of Data objects will be
interpolated onto the energy (or k) grid of C<$data> and merged along
with C<$data>.

  $merged_group = $data->merge('e', @groups);

The first argument is C<e>, C<n>, or C<k>.  The remaining arguments
are Data objects to be included in the merge.

=item C<Truncate>

Truncate data before or after a given value.  This discards the
truncated points from the arrays in Ifeffit.

  $data -> Truncate("after", 7700);

The truncation is exclusive -- that is the value closest in energy or
k to the supplied value remains in the array.

This is capitalized to avoid confusion with the perl built-in.

=item C<deglitch>

Remove a single data points -- glitches -- from the data.  This only
works on mu(E) data and a check is made that the supplied values are
within the data range.

  $data -> deglitch(17385.686);

or

  $data -> deglitch(@spurious_points);

In each case, the points closest in energy to the supplied values are
removed.  Glitches are simply removed from the data -- no
interpolation between surrounding values is made.

There is no method explicitly intended to find a glitchy point.  That
is left as a chore for the user interface.

Due to a quirk in Ifeffit (or perhaps in my understanding of Ifeffit)
attempting to deglitch any of the last two points of data will result
in both points being removed.  The same is true of the first two
points.  This is a bug, but not, I don't think, a horrible one.

=item C<smooth>

Perform Ifeffit's three-point smoothing on the mu(E) or chi(k) data,
as appropriate.  The argument tells Demeter how many times to reapply
the smoothing.

  $copy = $data -> clone;
  $copy -> smooth(5);

=item C<convolve>

Perform a Gaussian or Lorentzian convolution on the data.  Becuase
this has a number of possible arguments, named arguments in an
anonymous hash are used.  The width is Ifeffit's sigma value and is a
possitive number.  A negative number will be interpretted as zero.
The type is either "Gaussian" or "Lorentzian".  The type is either
"xmu" or "chi" -- that is convolute mu(E) or chi(k) data.

  $copy = $data -> clone;
  $copy -> convolve(width=>2, type=>'gaussian', which=>'xmu');

=item C<noise>

Add noise to a mu(E) or chi(k) spectrum.

  $copy = $data -> clone;
  $copy -> noise(noise=>0.02, which=>'xmu');

The amount of noise is intepretted differently for mu(E) data as for
chi(k).  For chi(k) data, the supplied noise used as the RMS value of
the noise to be applied to the un-weighted chi(k) data.  Consequently,
you probably want to use a small value -- probably something on the
order of 0.001.

For mu(E) data, the noise is interpretted as a fraction of the edge
step.  Thus the noise level for a given value scales with the size of
the edge step.  A value of 0.02, as in the example above, is 2% of the
edge step.

=back

=head1 CONFIGURATION

See L<Ifeffit::Demeter::Config> for a description of the configuration
system.

=head1 DEPENDENCIES

Demeter's dependencies are in the F<Bundle/DemeterBundle.pm> file.

=head1 BUGS AND LIMITATIONS

=over 4

=item *

The merge method does not yet return the varience array.

=item *

Adding noise to chi(k) is not working correctly.  (But adding noise to
mu(E) does.)

=back

Please report problems to Bruce Ravel (bravel AT bnl DOT gov)

Patches are welcome.

=head1 AUTHOR

Bruce Ravel (bravel AT bnl DOT gov)

L<http://cars9.uchicago.edu/~ravel/software/>

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2008 Bruce Ravel (bravel AT bnl DOT gov). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
