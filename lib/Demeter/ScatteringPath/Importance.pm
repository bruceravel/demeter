package Demeter::ScatteringPath::Importance;

use Moose::Role;

use Demeter::Constants qw($EPSILON5);
use List::Util qw(max);
use List::MoreUtils qw(firstidx uniq);
use Math::Spline;

has 'group_name' => (is => 'rw', isa => 'Str', default => q{_rankpath},);
has 'rankdata'   => (is => 'rw', isa => 'Any', default => q{},);
has 'importance' => (
		     traits    => ['Hash'],
		     is        => 'rw',
		     isa       => 'HashRef',
		     default   => sub { {} },
		     handles   => {
				   'set_importance'      => 'set',
				   'get_importance'      => 'get',
				   'get_importance_list' => 'keys',
				   'clear_importance'    => 'clear',
				   'importance_exists'   => 'exists',
				  },
		    );
has 'steps'  => (is => 'rw', isa => 'Int',     default =>  6);
has 'spline' => (is => 'rw', isa => 'Any',     default => 0);
has 'xmin'   => (is => 'rw', isa => 'Num',     default => 1);
has 'xmax'   => (is => 'rw', isa => 'Num',     default => 10);

sub rank {
  my ($self, $plot) = @_;
  my $path = $self->temppath;
  my $save = $path->po->kweight;

  $path->po->kweight(2);
  $path->_update('bft');

  $self->set_importance('area2', $self->rank_area($path));

  my ($c, $h) = $self->rank_height($path);
  $self->set_importance('peakpos2', $c);
  $self->set_importance('height2',  $h);

  $path->plot('r') if $plot;
  $path->po->kweight($save);
  $path->DEMOLISH;
};

sub temppath {
  my ($self) = @_;
  my $path = Demeter::Path->new(sp=>$self, data=>Demeter->dd, parent=>$self->feff,
				s02=>1, sigma2=>0.003, delr=>0, e0=>0,
			       );
  return $path;
};


sub normalize {
  my ($self, @list) = @_;
  @list = uniq($self, @list);
  foreach my $test ($self->get_importance_list) {
    next if ($test =~ m{peakpos});
    my @values = map {$_->get_importance($test)} @list;
    my $scale = max(@values);
    foreach my $sp (@list) {
      $sp->set_importance($test."_n", sprintf("%.2f", 100*$sp->get_importance($test)/$scale));
    };
  };
};

sub rank_area {
  my ($self, $path) = @_;

  my @x = $path->get_array('r');
  my @y = $path->get_array('chir_mag');
  $self->spline(Math::Spline->new(\@x,\@y));
  return $self->_integrate;
};

sub rank_height {
  my ($self, $path) = @_;
  my @x = $path->get_array('r');
  my @y = $path->get_array('chir_mag');
  my $max = max(@y);
  my $i = firstidx {$_ == $max} @y;
  my $centroid = $x[$i];
  return ($centroid, $max);
};


# adapted from Mastering Algorithms with Perl by Orwant, Hietaniemi,
# and Macdonald Chapter 16, p 632
#
# _integrate() uses the Romberg algorithm to estimate the definite integral
# of the function $func from $lo to $hi.
#
# The subroutine will compute roughly ($steps + 1) * ($steps + 2) / 2
# estimates for the integral, of which the last will be the most accurate.
#
# _integrate() returns early if intermediate estimates change by less
# than $EPSILON5.
#
sub _integrate {
  my ($self) = @_;
  my $lo = $self->xmin;
  my $hi = $self->xmax;
  my $h = $hi - $lo;
  my (@r, $sum);
  my @est;

  # Our initial estimate.
  $est[0][0] = ($h / 2) * ( $self->spline->evaluate($lo) + $self->spline->evaluate($hi) );

  # Compute each row of the Romberg array.
  my $j;
  foreach my $i (1 .. $self->steps) {

    $h /= 2;
    $sum = 0;

    # Compute the first column of the current row.
    for ($j = 1; $j < 2 ** $i; $j += 2) {
      $sum += $self->spline->evaluate($lo + $j * $h);
    }
    $est[$i][0] = $est[$i-1][0] / 2 + $sum * $h;

    # Compute the rest of the columns in this row.
    foreach $j (1 .. $i) {
      $est[$i][$j] = ($est[$i][$j-1] - $est[$i-1][$j-1]) / (4**$j - 1) + $est[$i][$j-1];
    }

    # Are we close enough?
    return $est[$i][$i] if (abs($est[$i][$i] - $est[$i-1][$i-1]) <= $EPSILON5);
  }
  return $est[$self->steps][$self->steps];
};


1;


=head1 NAME

Demeter::ScatteringPath::Importance - Ranking paths in a Feff calculation

=head1 VERSION

This documentation refers to Demeter version 0.9.11.

=head1 SYNOPSIS

This module provides a framework for evaluating path ranking formulas
and associating the results with ScatteringPath objects.  These
rankings can be used to evaluate the magnitude of a path in a Feff
calculation and, hopefully, provide some guidance about which paths to
include in a fit.

=head1 DESCRIPTION

Feff has long had a strange little feature called the "curved wave
importance factor" that purports to be an assessment of the importance
of a path.  Paths with large importance factors should, presumably, be
included in a fit.  Unfortunately, the formula Feff uses to compute
this number is not very reliable when applied to real world fits.

This module, then, provides a framework for applying a sequence of
alternative importance calculation.  This gives the user much more
information about the list of paths from a Feff calculation and
hopefully provides much better guidance for creating fitting models.

=head TESTS

=over 4

=item C<area2>

Using S02=1, sigma^2=0.003, and all other path parameters set to 0,
perform a Fourier transform on the path using k-weight of 2.
Integrate under the magnitude of chi(R) between 1 and 10 Angstroms.

=time C<height2>

Using S02=1, sigma^2=0.003, and all other path parameters set to 0,
perform a Fourier transform on the path using k-weight of 2.  Return
the maximum value of the magnitude of chi(R).

=time C<peakpos2>

Return the position of the maximum value from the C<height2> test.

=back

=head1 METHODS

=over 4

=item C<rank>

Run the sequence of path ranking tests on a ScatteringPath object and
store the results in the C<importance> attribute, which is a hash
reference.  The keys of the referenced hash are given above.

  $sp -> rank($plot);

If C<$plot> is true, the path will be plotted in R.

=item C<normalize>

For amplitude-valued rankings, scale each path in a list such that the
largest path has a value of 100.

  $sp -> normalize(@list_of_sp);

=back

=head1 DEPENDENCIES

Demeter's dependencies are in the F<Bundle/DemeterBundle.pm> file.

=head1 BUGS AND LIMITATIONS

=over 4

=item *

Need to create useful tests.

=item *

Need to integrate into Artemis.

=back

Please report problems to Bruce Ravel (bravel AT bnl DOT gov)

Patches are welcome.

=head1 AUTHOR

Bruce Ravel (bravel AT bnl DOT gov)

L<http://cars9.uchicago.edu/~ravel/software/>

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2012 Bruce Ravel (bravel AT bnl DOT gov). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
