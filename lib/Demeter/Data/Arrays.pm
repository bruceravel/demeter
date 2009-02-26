package Demeter::Data::Arrays;
use Moose::Role;

use Demeter::StrTypes qw( DataPart FitSpace );
use List::MoreUtils qw(pairwise);

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
  my $group = $self->group;
  my $text = ($part =~ m{(?:bkg|fit|res)}) ? "${group}_$part.$suffix" : "$group.$suffix";
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
  Ifeffit::ifeffit("\&screen_echo = 0\n");
  Ifeffit::ifeffit("show \@group ".$self->group);
  my @arrays = ();
  my $lines = Ifeffit::get_scalar('&echo_lines');
  Ifeffit::ifeffit("\&screen_echo = $save\n"), return if not $lines;
  foreach my $l (1 .. $lines) {
    my $response = Ifeffit::get_echo();
    my $group = $self->group;
    if ($response =~ m{\A\s*$group\.([^\s]+)\s+=}) {
      push @arrays, $1;
    };
  };
  Ifeffit::ifeffit("\&screen_echo = $save\n");
  return @arrays;
};


sub points {
  my ($self, @arguments) = @_;
  my %args = @arguments;
  $args{space}     = lc($args{space});
  $args{shift}   ||= 0;
  $args{scale}   ||= 1;
  $args{yoffset} ||= 0;
  $args{part}    ||= q{};

  my @x = ($args{space} eq 'e') ? $self->get_array('energy')
        : ($args{space} eq 'k') ? $self->get_array('k')
        : ($args{space} eq 'r') ? $self->get_array('r')
        :                         $self->get_array('q');
  @x = map {$_ + $args{shift}} @x;
  my @y = ();
  if ((ref($self) =~ m{Data}) and is_DataPart($args{part})) {
    @y = $self->get_array($args{suffix}, $args{part});
  } elsif (ref($args{part}) =~ m{Path}) {
    #print $args{part}, "  ", ref($args{part}), "  ", $args{file}, $/;
    @y = $args{part}->get_array($args{suffix});
  } else {
    @y = $self->get_array($args{suffix});
  };
  if (defined $args{weight}) {
    @y = pairwise {$args{scale}*$a**$args{weight}*$b + $args{yoffset}} @x, @y;
  } else {
    @y = map {$args{scale}*$_ + $args{yoffset}} @y;
  };

  my $message = q{};
  pairwise { $message .= join(" ", $a, $b, $/) } @x, @y;
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

This documentation refers to Demeter version 0.3.

=head1 METHODS

=over 4

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

=item C<points>

This method is used extensively by the gnuplot plotting template set
to generate temporary files for Gnuplot.  See any of those plotting
templates fro examples of how this is used.

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

Copyright (c) 2006-2009 Bruce Ravel (bravel AT bnl DOT gov). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
