package Demeter::Data::Arrays;
use Moose::Role;
use Carp;
use Demeter::StrTypes qw( DataPart FitSpace );
use List::MoreUtils qw(pairwise minmax);
use Regexp::Assemble;

use Demeter::Constants qw($ETOK);

sub yofx {
  my ($self, $suffix, $part, $x) = @_;
  my $space = ($suffix eq 'chi')   ? 'k'
            : ($suffix =~ m{chir}) ? 'r'
            : ($suffix =~ m{chiq}) ? 'q'
	    :                        "energy";
  my @x        = $self->get_array($space);
  if ($space eq 'energy') {
    @x = map {$_ + $self->bkg_eshift} @x;
  };
  my @y        = $self->get_array($suffix, $part);
  my $spline   = Math::Spline->new(\@x,\@y);
  my $y_interp = sprintf("%11.8f", $spline->evaluate($x));
  return $y_interp;
};

sub iofx {
  my ($self, $space, $x) = @_;
  $space = lc($space);
  croak("not a valid space in iofx") if ($space !~ m{\A(?:energy|k|r|q)\z});
  my @x = $self->get_array($space);
  if ($space eq 'energy') {
    @x = map {$_ + $self->bkg_eshift} @x;
  };
  my $i = 0;
  foreach (@x) {
    last if $x<$_;
    ++$i;
  };
  return $i;
};

sub get_titles {
  my ($self) = @_;
  my @titles;
  my $string = $self->fetch_string(sprintf("%s_title_%2.2d", $self->group, 1));
  my $i = 1;
  while ($string !~ m{\A\s+\z}) {
    push @titles, $string;
    ++$i;
    $string = $self->fetch_string(sprintf("%s_title_%2.2d", $self->group, $i));
    #print sprintf("%s_title_%2.2d", $self->group, $i), ":  ", $string, $/;
  };
  return @titles;
};

sub put {
  my ($self, $eref, $xref, @args) = @_;
  my $data = $self->new();	# return a Data is called by Data, return a Data::Pixel if called by D::P
  $data -> set(@args);
  if ($data->datatype eq 'chi') {
    $data -> put_k($eref);
    $data -> put_chi($xref);
  } else {
    $data -> put_energy($eref);
    $data -> put_xmu($xref);
  };
  $data -> set(update_data=>0, update_columns=>0, update_norm=>1);
  $data -> set(update_norm=>0, update_bkg=>0, update_fft=>1) if ($data->datatype eq 'chi');
  return $data;
};

sub put_energy {
  my ($self, $arrayref) = @_;
  $self->place_array($self->group.'.energy', $arrayref);
  $self -> update_norm(1);
  return $self;
};
sub put_xmu {
  my ($self, $arrayref) = @_;
  $self->place_array($self->group.'.xmu', $arrayref);
  $self -> update_norm(1);
  return $self;
};

sub put_k {
  my ($self, $arrayref) = @_;
  $self->place_array($self->group.'.k', $arrayref);
  $self -> update_bft(1);
  return $self;
};
sub put_chi {
  my ($self, $arrayref) = @_;
  $self->place_array($self->group.'.chi', $arrayref);
  $self -> update_bft(1);
  return $self;
};

sub put_array {
  my ($self, $suffix, $arrayref) = @_;
  $suffix ||= '___';
  $self->place_array(join('.', $self->group, $suffix), $arrayref);
  return $self;
};

sub get_array {
  my ($self, $suffix, $part) = @_;
  $part ||= q{};
  if (not $self->plottable) {
    my $class = ref $self;
    croak("Demeter: $class objects have no arrays associated with them and are not plottable");
  };
  my $group = $self->group;
  my $text = ($part =~ m{(?:bkg|fit|res|run)}) ? "${group}_$part.$suffix" : "$group.$suffix";
  my @array = $self->fetch_array($text);
  if (not @array) {		# only do this error check if the specified array is not returned
    my @list = $self->arrays;	# this is the slow line -- it requires calls to ifeffit, get_scalar, and get_echo
    my $group_regexp = Regexp::Assemble->new()->add(@list)->re;
    my $grp = $self->group;
    if ($suffix !~ m{\b$group_regexp\b}) {
      #carp("The group $grp does not have an array $grp.$suffix (" . join(" ", @list) . ")");
      return ();
    };
    #$self->running if ($part eq 'run');
  };
  return @array;
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
  if ($suffix eq 'chi') {
    my @k = $self->get_array('k');
    my $w = $self->data->get_kweight;
    @array = map { $array[$_] * $k[$_] ** $w } (0 .. $#array);
  };
  my ($min, $max) = minmax(@array);
  return ($min, $max);
};

my @arrays_text = ();
sub arrays {
  my ($self) = @_;
  if (not $self->plottable) {
    my $class = ref $self;
    croak("Demeter: $class objects have no arrays associated with them and are not plottable");
  };
  my @arrays = ();

  if ($self->mo->template_process eq 'larch') {
    $self->dispense("process", "attributes");
    @arrays = $self->fetch_array($self->group.'.l___ist');
  } else {
    @arrays_text = ();		     # initialize array buffer for accumulating correlations text
    my @save = ($self->toggle_echo(0), # turn screen echo off, saving prior state
		$self->get_mode("feedback"));
    $self->set_mode(feedback=>sub{push @arrays_text, $_[0]}); # set feedback coderef
    $self->dispense("process", "show_group");
    $self->toggle_echo($save[0]);	# reset everything
    $self->set_mode(feedback=>$save[1]||q{});
    my $group = $self->group;
    foreach my $l (@arrays_text) {
      if ($l =~ m{\A\s*$group\.([^\s]+)\s+=}) {
	push @arrays, $1;
      };
    };

  };
  return @arrays;
};


sub points {
  my ($self, @arguments) = @_;
  my %args = @arguments;
  $args{space}      = lc($args{space});
  $args{shift}    ||= 0;
  $args{scale}    ||= 1;
  $args{yoffset}  ||= 0;
  $args{part}     ||= q{};
  $args{add}      ||= q{};
  $args{subtract} ||= q{};
  $args{dphase}   ||= 0;

  my @x = ($args{suffix} =~ m{margin}) ? $self->get_array('menergy')
        : ($args{space} eq 'e')     ? $self->get_array('energy')
        : ($args{space} eq 'k')     ? $self->get_array('k', $args{part})
        : ($args{space} eq 'chie')  ? $self->get_array('k')
        : ($args{space} eq 'r')     ? $self->get_array('r', $args{part})
        : ($args{space} eq 'lcf')   ? $self->get_array('x')
        : ($args{space} eq 'diff')  ? $self->get_array('energy')
        : ($args{space} eq 'lr')    ? $self->get_array('q')
        : ($args{space} eq 'x')     ? $self->get_array('x')
        : ($args{space} eq 'index') ? $self->get_array('index')
        :                             $self->get_array('q', $args{part});
  my @k = @x;
  @x = map {$_**2/$ETOK + $self->bkg_e0} @x if ($args{space} eq 'chie');
  @x = map {$_ + $args{shift}} @x;
  my @y = ();
  my @z = ();
  if (($args{suffix} eq 'chir_pha') and $args{dphase}) {
    $args{suffix} = 'dph';
    #$self->dispense('process', 'erase', {items=>'___dp_scale'});
  };
  if ($args{space} eq 'lcf') {
    @y = $self->get_array($args{suffix});
  } elsif ($args{space} eq 'lr') {
    @y = $self->get_array($args{suffix});
  } elsif ($args{space} eq 'diff') {
    @y = $self->get_array($args{suffix});
  } elsif ((ref($self) =~ m{Data}) and is_DataPart($args{part})) {
    my $suff = ($args{part} eq 'run') ? substr($args{suffix}, 0, 4) : $args{suffix};
    @y = $self->get_array($suff, $args{part});
  } elsif (ref($args{part}) =~ m{Path}) {
    #print $args{part}, "  ", ref($args{part}), "  ", $args{file}, $/;
    @y = $args{part}->get_array($args{suffix});
  } elsif ($args{add}) {
    @y = $self->get_array($args{suffix});
    @z = $self->get_array($args{add});
    @y = pairwise {$a + $b + $args{yoffset}} @y, @z;
  } elsif ($args{subtract}) {
    @y = $self->get_array($args{suffix});
    @z = $self->get_array($args{subtract});
    @y = pairwise {$a - $b + $args{yoffset}} @y, @z;
  } else {
    @y = $self->get_array($args{suffix});
  };
  if (defined $args{weight}) {
    $args{weight} || 0;
    $#y = $#k if ($#k < $#y);
    $#k = $#y if ($#k > $#y);
    @y = pairwise {$args{scale}*$a**$args{weight}*$b + $args{yoffset}} @k, @y;
  } else {
    @y = map {$args{scale}*$_ + $args{yoffset}} @y;
  };

  my $message = q{};
  pairwise { $message .= join(" ", $a, $b, $/) if (defined($a) and defined($b))} @x, @y;
  if ($args{file}) {
    open my $T, '>'.$args{file};
    print $T $message;
    close $T;
    return $args{file};
  } else {
    return $message;
  };
};


1;

=head1 NAME

Demeter::Data::Arrays - Data array methods for Demeter

=head1 VERSION

This documentation refers to Demeter version 0.9.16.

=head1 METHODS

=over 4

=item C<put>

This method is used to make a new Data object from two arrays
containing the energy and xmu data.

  $new_data = Demeter::Data -> put(\@energy, \@xmu);

The new Data object if returned.  In every way, this is like any Data
object that comes from a file.  The use would be for converting some
complex data format, e.g. a spreadsheet, into one or more Data
objects.  This method could also be used in a filetype plugin.

You can specify additional arguments like the C<new> or C<set> methods
of the Data object:

  $new_data = Demeter::Data -> put(\@energy, \@xmu, @args);

This second form must be used to make chi(k) data from arrays:

  $new_data = Demeter::Data -> put(\@energy, \@chi, datatype=>'chi');

Note that the C<put> method sets the datatype to 'xmu', so to make
chi(k) data you must explicitly specify it.

=item C<get_array>

Read an array from the data processing backend (Ifeffit/Larch).  The
argument is the Ifeffit array suffix of the array to import.

  @array = $dataobject->get_array("xmu");

=item C<ref_array>

Get a reference to an array from the data processing backend
(Ifeffit/Larch).  The argument is the Ifeffit array suffix of the
array to import.

  $ref_to_array = $dataobject->ref_array("xmu");

=item C<put_xmu>

Push an array onto a backend array representing the xmu data
associated with the Data object.  The purpose of this is to modify the
mu(E) data for a Data object in place.  An example would be to apply a
dead time correction without creating a new group to contain the
corrected data.

  $dataobject -> put_xmu(\@xmu_array);

=item C<floor_ceil>

Return a two element list containing the smallest and largest values
of an array in the data processing backend (Ifeffit/Larch).

  ($min, $max) = $dataobject->floor_ceil("xmu");

=item C<yofx>

Return the y value corresponding to a given x-value.  This is found
by interpolation from the specified array.

  $y = $dataobject->yofx("xmu", q{}, $x);

The second argument (C<q{}> in this example) is used to specify a part
of a fit, i.e. C<bkg> or C<res>.

=item C<iofx>

Return the index of the value just lower than a given x-value.  This
is found by simple comparison with the values in the specified array.

  $i = $dataobject->iofx($space, $x);

This is intended to probe the x-axis of a data space, so the first
argument must be one of C<energy>, C<k>, C<R>, or C<q>).

=item C<points>

This method is used extensively by the gnuplot plotting template set
to generate temporary files for plotting with Gnuplot.  See any of
those plotting templates for examples of how this is used.

=back

=head1 DEPENDENCIES

Demeter's dependencies are in the F<Bundle/DemeterBundle.pm> file.

L<Moose> is the basis of Demeter.  This module is implemented as a
role and used by the L<Demeter::Data> object.  I feel obliged to admit
that I am using Moose roles in the most trivial fashion here.  This is
mostly an organization tool to keep modules small and methods
organized by common functionality.

=head1 BUGS AND LIMITATIONS

Please report problems to Bruce Ravel (bravel AT bnl DOT gov)

Patches are welcome.

=head1 AUTHOR

Bruce Ravel (bravel AT bnl DOT gov)

L<http://cars9.uchicago.edu/~ravel/software/>

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2013 Bruce Ravel (bravel AT bnl DOT gov). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
