package Demeter::ScatteringPath::Rank;

use Moose::Role;

use Demeter::Constants qw($EPSILON5);
use Demeter::StrTypes qw( Rankings );

use List::Util qw(max sum);
use List::MoreUtils qw(firstidx uniq pairwise any);
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
has 'steps'      => (is => 'rw', isa => 'Int',    default => 6); # more precision?
has 'spline'     => (is => 'rw', isa => 'Any',    default => 0);

has 'rank_kmin'  => (is => 'rw', isa => 'LaxNum', default => Demeter->co->default('pathfinder', 'rank_kmin'));
has 'rank_kmax'  => (is => 'rw', isa => 'LaxNum', default => Demeter->co->default('pathfinder', 'rank_kmax'));
has 'rank_kmini' => (is => 'rw', isa => 'Int',    default => 0);
has 'rank_kmaxi' => (is => 'rw', isa => 'Int',    default => 1);
has 'rank_rmin'  => (is => 'rw', isa => 'LaxNum', default => Demeter->co->default('pathfinder', 'rank_rmin'));
has 'rank_rmax'  => (is => 'rw', isa => 'LaxNum', default => Demeter->co->default('pathfinder', 'rank_rmax'));
has 'rank_rmini' => (is => 'rw', isa => 'Int',    default => 0);
has 'rank_rmaxi' => (is => 'rw', isa => 'Int',    default => 1);

sub rank {
  my ($self, $how, $plot) = @_;
  my @how;
  if (ref($how) eq 'ARRAY') {
    @how = @$how;
  } else {
    @how = ($how);
  };

  my $path         = $self->temppath;
  my $save         = $path->po->kweight;
  my $isave        = $self->mo->pathindex;
  my $ranksave     = Demeter->co->default('pathfinder', 'rank');
  my $tempfilesave = $self->randstring;
  $self->randstring("__ranking.sp");

  my $do_k    = any {$_ =~ m{(?:a|sq)kn?c}i} @how;
  my $do_kmag = any {$_ =~ m{mkn?c}i       } @how;
  my $do_r    = any {$_ =~ m{[ms]ft}i      } @how;

  my (@k, @m, @x, @y, @r, @c);
  if ($do_k or $do_kmag) {
    $path->_update('fft');
    @k = $path->get_array('k');
    $self->rank_kmini(firstidx {$_ >= $self->rank_kmin} @k);
    $self->rank_kmaxi(firstidx {$_ >  $self->rank_kmax} @k);
    $self->rank_kmaxi($self->rank_kmaxi - 1);
  };
  if ($do_k) {
    @y = $path->get_array('chi');
  };
  if ($do_kmag) {
    @m = $path->get_array('chi_mag');
  };
  if ($do_r) {
    $path->_update('bft');
    @r = $path->get_array('r');
    $self->rank_rmini(firstidx {$_ >= $self->rank_rmin} @r);
    $self->rank_rmaxi(firstidx {$_ >  $self->rank_rmax} @r);
    $self->rank_rmaxi($self->rank_rmaxi - 1);
    @c = $path->get_array('chir_mag');
  };

  foreach my $h (@how) {

    next if not is_Rankings($h);
    next if $h eq 'feff';
    next if $h eq 'peakpos';
    if (ref($self) =~ m{Aggregate}) {
      $h = 'akc' if lc($h) eq 'feff';
    };

    ## to add a new ranking criterion, add a clause below, add the
    ## acronym to StrTypes, write the method below, modify
    ## explain_ranking in Demeter::Feff, edit rank in
    ## pathfinder.demeter_conf
    my $hh = lc($h);
    if ($hh eq 'akc') {
      $self->set_rank('akc',   $self->rank_aknc(\@k, \@y, 1));
    } elsif ($hh eq 'aknc') {
      $self->set_rank('aknc',  $self->rank_aknc(\@k, \@y, Demeter->po->kweight));
    } elsif ($hh eq 'sqkc') {
      $self->set_rank('sqkc',  $self->rank_sqknc(\@k, \@y, 1));
    } elsif ($hh eq 'sqknc') {
      $self->set_rank('sqknc', $self->rank_sqknc(\@k, \@y, Demeter->po->kweight));
    } elsif ($hh eq 'mkc') {
      $self->set_rank('mkc',   $self->rank_mknc(\@k, \@m, 1));
    } elsif ($hh eq 'mknc') {
      $self->set_rank('mknc',  $self->rank_mknc(\@k, \@m, Demeter->po->kweight));

    } elsif ($hh eq 'mft') {
      $path->update_fft(1);
      $path->_update('bft');
      my ($c, $h) = $self->rank_height(\@r, \@c);
      $self->set_rank('peakpos', $c);
      $self->set_rank('mft',     $h);
    } elsif ($hh eq 'sft') {
      $self->set_rank('sft', $self->rank_sft(\@c));
    };
  };

  $path->plot('r') if $plot;
  $path->po->kweight($save);
  $path->rm; # clean up __ranking.sp
  $path->DEMOLISH;
  $self->randstring($tempfilesave);
  $self->mo->pathindex($isave);
  Demeter->co->set_default('pathfinder', 'rank', $ranksave);
};

sub temppath {
  my ($self) = @_;
  my $path = Demeter::Path->new(sp=>$self, data=>Demeter->dd, parent=>$self->feff,
				group=>'t__mp', save_mag=>1,
				s02=>1, sigma2=>0.003, delr=>0, e0=>0, );
  return $path;
};


sub normalize {
  my ($self, @list) = @_;
  @list = uniq($self, @list);
  #return $self if ($self->co->default('pathfinder', 'rank') =~ m{peakpos});
  #return $self if ($self->co->default('pathfinder', 'rank') eq 'feff');

  foreach my $test ($self->get_rank_list) {
    next if $test eq 'peakpos';
    next if $test eq 'feff';
    my @values = map {$_->get_rank($test)} @list;
    my $scale = max(@values);
    foreach my $sp (@list) {
      $sp->set_rank($test, sprintf("%.2f", 100*$sp->get_rank($test)/$scale));
    };
  };
};

sub rank_height {
  my ($self, $x, $y) = @_;
  my $max = max(@$y);
  my $i = firstidx {$_ == $max} @$y;
  my $centroid = $x->[$i];
  return ($centroid, $max);
};

sub rank_chimag {
  my ($self, $x, $y) = @_;
  return sum @$y;
};

## sum_i abs(k_i * chi(k_i)), i=[kmin:kmax], ref to chi(k) passed as y
## akc criterion is this with $n=1
sub rank_aknc {
  my ($self, $x, $y, $n) = @_;
  my @k = @$x[$self->rank_kmini .. $self->rank_kmaxi];
  my @c = @$y[$self->rank_kmini .. $self->rank_kmaxi];
  my @func   = pairwise {abs($a**$n*$b)} @k, @c;
  return sum @func;
}

## sum_i (k_i * chi(k_i))^2, i=[kmin:kmax], ref to chi(k) passed as y
## sqkc criterion is this with $n=1
sub rank_sqknc {
  my ($self, $x, $y, $n) = @_;
  my @k = @$x[$self->rank_kmini .. $self->rank_kmaxi];
  my @c = @$y[$self->rank_kmini .. $self->rank_kmaxi];
  my @func   = pairwise {($a**$n*$b)**2} @k, @c;
  return sqrt(sum @func);
}

## sum_i k_i * mag(chi(k_i)), i=[kmin:kmax], ref to mag(chi) is passed as $y
## mkc criterion is this with $n=1
sub rank_mknc {
  my ($self, $x, $y, $n) = @_;
  my @k = @$x[$self->rank_kmini .. $self->rank_kmaxi];
  my @c = @$y[$self->rank_kmini .. $self->rank_kmaxi];
  my @func   = pairwise {$a**$n*$b} @k, @c;
  return sum @func;
}


sub rank_sft {
  my ($self, $y) = @_;
  return sum @$y[$self->rank_rmini .. $self->rank_rmaxi];
}



sub rank_area {
  my ($self, $x, $y) = @_;
  $self->spline(Math::Spline->new($x,$y));
  return $self->_integrate;
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

This documentation refers to Demeter version 0.9.21.

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
this number is not very reliable when applied to real world fitting
problems.

This module, then, provides a framework for applying alternative
importance calculations.  This gives the user more information about
the list of paths from a Feff calculation and hopefully provides
better guidance for creating fitting models.

=head1 CRITERIA

=over 4

=item C<feff>

This is Feff's curve wave amplitude ratio.

=item C<akc>

This is the sum over the k-range of C<|k*chi(k)|>.

=item C<aknc>

This is the sum over the k-range of C<|k^n*chi(k)|>.

=item C<sqkc>

This is the square root of the sum over the k-range of C<(k*chi(k))^2>.

=item C<sqknc>

This is the square root of the sum over the k-range of C<(k^n*chi(k))^2>.

=item C<mkc>

This is the sum over the k-range of C<|k*mag(chi(k))|>.

=item C<mknc>

This is the sum over the k-range of C<|k^n*mag(chi(k))|>.

=item C<mft>

This is the maximum value of C<|chi(R)|> within the R range with the
Fourier transform performed using the current value of the plotting
k-weight.

=item C<sft>

This is the sum over the R-range of C<|chi(R)|> with the Fourier
transform performed using the current value of the plotting k-weight.

=back

=head1 METHODS

=over 4

=item C<rank>

Run the selected path ranking calculations on a ScatteringPath object
and store the results in the C<rankings> attribute, which is a hash
reference.  The keys of the referenced hash are given above.

  $sp -> rank($how, $plot);

C<$how> specifies the ranking criterion.  The configuration default
will be used if not specified.  If C<$plot> is true, the path will be
plotted in R.

=item C<normalize>

For amplitude-valued rankings, scale each path in a list such that the
largest path in the input list has a value of 100.

  $sp -> normalize(@list_of_sp);

C<$sp> will be included in the list, but care will be taken not to
include it twice.

=item C<get_rank>

Return a path's value for a given test.

  $x = $sp->get_rank('akc');

=item C<get_rank_list>

Return a list of identifying names for all the tests.

  @all = $sp -> get_rank_list;
  foreach my $r (@all) {
    print $r, " = ", $sp->get_rank($r);
  };

=back

=head1 CONFIGURATION

The C<pathfinder-E<gt>rank> parameter is used to determine which
criterion is used in the path interpretation.  Other parameters in the
C<pathfinder> configuration group set the default k- and R-ranges for
the evaluations.  Finally, C<pathfinder-E<gt>rank_high> and
C<pathfinder-E<gt>rank_low> set the cutoff between high, mid, and low
importance paths in the path interpretation.

=head1 DEPENDENCIES

Demeter's dependencies are in the F<Build.PL> file.

=head1 BUGS AND LIMITATIONS

Please report problems to the Ifeffit Mailing List
(L<http://cars9.uchicago.edu/mailman/listinfo/ifeffit/>)

Patches are welcome.

=head1 AUTHOR

Bruce Ravel (L<http://bruceravel.github.io/home>)

L<http://bruceravel.github.io/demeter/>

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2015 Bruce Ravel (L<http://bruceravel.github.io/home>). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
