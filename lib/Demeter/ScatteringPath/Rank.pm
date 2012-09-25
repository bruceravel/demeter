package Demeter::ScatteringPath::Rank;

use Moose::Role;

use Demeter::Constants qw($EPSILON5);
use List::Util qw(max sum);
use List::MoreUtils qw(firstidx uniq pairwise);
use Math::Spline;

has 'group_name' => (is => 'rw', isa => 'Str', default => q{_rankpath},);
has 'rankdata'   => (is => 'rw', isa => 'Any', default => q{},);
has 'rankings' => (
		   traits    => ['Hash'],
		   is        => 'rw',
		   isa       => 'HashRef',
		   default   => sub { {} },
		   handles   => {
				 'set_rank'      => 'set',
				 'get_rank'      => 'get',
				 'get_rank_list' => 'keys',
				 'clear_rank'    => 'clear',
				 'rank_exists'   => 'exists',
				},
		  );
has 'steps'  => (is => 'rw', isa => 'Int',     default => 6); # more precision?
has 'spline' => (is => 'rw', isa => 'Any',     default => 0);
has 'xmin'   => (is => 'rw', isa => 'Num',     default => 1);
has 'xmax'   => (is => 'rw', isa => 'Num',     default => 10);

sub rank {
  my ($self, $plot) = @_;
  my $path = $self->temppath;
  my $save = $path->po->kweight;

  ## area and peak height/position for each of kw=1,2,3
  my @weights = ($self->co->default('pathfinder', 'rank') eq 'all') ? (1..3) : (2);
  foreach my $i (@weights) {
    $path->po->kweight($i);
    $path->update_fft(1);
    $path->_update('bft');

    my @x = $path->get_array('r');
    my @y = $path->get_array('chir_mag');

    $self->set_rank('area'.$i, $self->rank_area($path, \@x, \@y));

    my ($c, $h) = $self->rank_height($path, \@x, \@y);
    $self->set_rank('peakpos'.$i, $c);
    $self->set_rank('height'.$i,  $h);

    my @k = $path->get_array('k');
    my @m = $path->get_array('chi_mag');
    @m = pairwise {$a * $b**$i} @m, @k;
    my $mag = $self->rank_chimag($path, \@k, \@m);
    $self->set_rank('chimag'.$i, $mag);
  };

  $path->plot('r') if $plot;
  $path->po->kweight($save);
  $path->DEMOLISH;
};

sub temppath {
  my ($self) = @_;
  my $path = Demeter::Path->new(sp=>$self, data=>Demeter->dd, parent=>$self->feff,
				group=>$self->group_name, save_mag=>1,
				s02=>1, sigma2=>0.003, delr=>0, e0=>0, );
  return $path;
};


sub normalize {
  my ($self, @list) = @_;
  @list = uniq($self, @list);
  foreach my $test ($self->get_rank_list) {
    next if ($test =~ m{peakpos});
    next if ($test eq 'zcwif');
    my @values = map {$_->get_rank($test)} @list;
    my $scale = max(@values);
    foreach my $sp (@list) {
      $sp->set_rank($test."_n", sprintf("%.2f", 100*$sp->get_rank($test)/$scale));
    };
  };
  if ($self->co->default('pathfinder', 'rank') eq 'all') {
    foreach my $type (qw(area height chimag)) {
      foreach my $sp (@list) {
	my $sum = $sp->get_rank($type.'1_n') +
	          $sp->get_rank($type.'2_n') +
	          $sp->get_rank($type.'3_n');
	$sp->set_rank($type, sprintf("%.2f", $sum/3));
      };
    };
  };
};

sub rank_area {
  my ($self, $path, $x, $y) = @_;
  $self->spline(Math::Spline->new($x,$y));
  return $self->_integrate;
};

sub rank_height {
  my ($self, $path, $x, $y) = @_;
  my $max = max(@$y);
  my $i = firstidx {$_ == $max} @$y;
  my $centroid = $x->[$i];
  return ($centroid, $max);
};

sub rank_chimag {
  my ($self, $path, $x, $y) = @_;
  return sum @$y;
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

Demeter::ScatteringPath::Rank - Ranking paths in a Feff calculation

=head1 VERSION

This documentation refers to Demeter version 0.9.12.

=head1 SYNOPSIS

This module provides a framework for evaluating path ranking formulas
and associating the results with ScatteringPath objects.  These
rankings can be used to evaluate the importance of a path in a Feff
calculation and, hopefully, provide some guidance about which paths to
include in a fit.

This module is adapted from similar work by Karine Provost of Institut
de Chimie et des Materiaux Paris-Est.

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

=item C<chimagW>

The sum of the magnitude of chi(k) is computed after k-weighting by
W=(1,2,3).  The magnitude is obtained by running Ifeffit's C<ff2chi>
function with the flag set for saving the magnitude of chi.  This is
controlled by the C<save_mag> attribute of the Path object which is
used to compute the various tests.

=item C<areaW>

Using S02=1, sigma^2=0.003, and all other path parameters set to 0,
perform a Fourier transform on the path using k-weight of W=(1,2,3).
Integrate under the magnitude of chi(R) between 1 and 10 Angstroms.

=item C<areaW_n>

The value of C<areaW> normalized over a list by the C<normalize>
method.  The largest ranking in the list will be 100.

=time C<heightW>

Using S02=1, sigma^2=0.003, and all other path parameters set to 0,
perform a Fourier transform on the path using k-weight of W=(1,2,3).
Return the maximum value of the magnitude of chi(R).

=item C<heightW_n>

The value of C<heightW> normalized over a list by the C<normalize>
method.  The largest ranking in the list will be 100.

=time C<peakposW>

Return the position of the maximum value from the C<heightW> test.

=back

=head1 METHODS

=over 4

=item C<rank>

Run the sequence of path ranking tests on a ScatteringPath object and
store the results in the C<rankings> attribute, which is a hash
reference.  The keys of the referenced hash are given above.

  $sp -> rank($plot);

If C<$plot> is true, the path will be plotted in R.

=item C<normalize>

For amplitude-valued rankings, scale each path in a list such that the
largest path in the input list has a value of 100.

  $sp -> normalize(@list_of_sp);

C<$sp> will be included in the list, but care will be taken not to
include it twice.

=item C<get_rank>

Return a path's value for a given test.

  $x = $sp->get_rank('area2');

=item C<get_rank_list>

Return a list of identifying names for all the tests.

  @all = $sp -> get_rank_list;
  foreach my $r (@all) {
    print $r, " = ", $sp->get_rank($r);
  };

=back

=head1 CONFIGURATION

The C<pathfinder -&gt; rank> parameter is used to determine which
tests are run.  If set to C<all>, the tests will be evaluated at all
three k-weights.  If set to C<kw2>, the tests will only be evaluated
with k-weight of 2.

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
