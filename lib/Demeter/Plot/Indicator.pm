package Demeter::Plot::Indicator;

use Moose;
extends 'Demeter';
with 'Demeter::Data::Units';

use Demeter::StrTypes qw( PlotSpace );

has '+name'  => (default => q{indicator});
has 'space'  => (is => 'rw', isa => PlotSpace,  default => 'e', coerce => 1);
has 'x'      => (is => 'rw', isa => 'Num',      default =>  0,
		 trigger => sub{my ($self, $new) = @_;
				if ($self->space eq 'e') {
				  $self->x2($self->e2k($new));
				} elsif ($self->space eq 'r') {
				  $self->x2($new);
				} else {
				  $self->x2($self->k2e($new));
				};
			      });
has 'x2'     => (is => 'rw', isa => 'Num',  default =>  0);
has 'active' => (is => 'rw', isa => 'Bool', default =>  1);
has 'i'      => (is => 'rw', isa => 'Int',  default => -1);

has 'ymin'   => (is => 'rw', isa => 'Num',  default =>  0,
		trigger => sub{my ($self, $new) = @_;
			       if ($new < 0) {
				 $self->y1($new * $self->co->default('indicator','margin'));
			       } else {
				 $self->y1($new / $self->co->default('indicator','margin'));
			       };
			     });
has 'ymax'   => (is => 'rw', isa => 'Num',  default =>  0,
		trigger => sub{my ($self, $new) = @_;
			       if ($new < 0) {
				 $self->y2($new / $self->co->default('indicator','margin'));
			       } else {
				 $self->y2($new * $self->co->default('indicator','margin'));
			       };
			     });
has 'y1'     => (is => 'rw', isa => 'Num',  default =>  0);
has 'y2'     => (is => 'rw', isa => 'Num',  default =>  0);

sub BUILD {
  my ($self, @params) = @_;
  $self->mo->push_Indicator($self);
  my $i = $#{$self->mo->Indicator} + 1;
  $self->i($i); # index for use in Gnuplot backend ... this is arrow number $i ...
};

sub plot {
  my ($self, $space) = @_;
  return if (not $self->active);
  $space ||= $self->po->space;
  ($space  = 'kq') if (lc($space) eq 'qk');
  $space   = lc($space);
  $self->po->space(substr($space, 0, 1));

  return if ( (lc($self->po->space) eq 'r') and (lc($self->space) ne 'r') );
  return if ( (lc($self->po->space) ne 'r') and (lc($self->space) eq 'r') );

  my $command = $self->template('plot', 'indicator');
  ##print $command;
  $self->dispose($command, 'plotting');
};

sub xcoord {
  my ($self) = @_;
  my $x = ($self->po->space eq $self->space) ? $self->x : $self->x2;
  $x    = $self->x if (($self->po->space eq 'q') and ($self->space eq 'k'));
  $x    = $self->x if (($self->po->space eq 'k') and ($self->space eq 'q'));
  my $e0 = ($self->po->space eq 'e') ? $self->mo->standard->bkg_e0 : 0;
  return sprintf("%.8g", $x+$e0);
};
sub y1coord {
  my ($self) = @_;
  my $y1 = 0;
  if ($self->y1) {
    $y1 = $self->y1;
  } else {
    my $x  = ($self->po->space eq $self->space) ? $self->x : $self->x2;
    $x     = $self->x if (($self->po->space eq 'q') and ($self->space eq 'k'));
    $x     = $self->x if (($self->po->space eq 'k') and ($self->space eq 'q'));

    my $kw = ($self->po->space eq 'k') ? ($self->po->kweight) : 0;
    my $yy = $self->mo->standard->yofx($self->mo->standard->suffix, q{}, $self->xcoord) * $x**$kw;
    my @m  = $self->mo->standard->floor_ceil($self->mo->standard->suffix);
    my $sy = abs($m[0] - $m[1]) / 4;
    $y1    = $yy-$sy;
  };
  return sprintf("%.8g", $y1 + $self->mo->standard->y_offset);
};
sub y2coord {
  my ($self) = @_;
  my $y2 = 0;
  if ($self->y2) {
    $y2 = $self->y2;
  } else {
    my $x  = ($self->po->space eq $self->space) ? $self->x : $self->x2;
    $x     = $self->x if (($self->po->space eq 'q') and ($self->space eq 'k'));
    $x     = $self->x if (($self->po->space eq 'k') and ($self->space eq 'q'));

    my $kw = ($self->po->space eq 'k') ? ($self->po->kweight) : 0;
    my $yy = $self->mo->standard->yofx($self->mo->standard->suffix, q{}, $self->xcoord) * $x**$kw;
    my @m  = $self->mo->standard->floor_ceil($self->mo->standard->suffix);
    my $sy = abs($m[0] - $m[1]) / 4;
    $y2    = $yy+$sy;
  };
  return sprintf("%.8g", $y2 + $self->mo->standard->y_offset);
};

sub report {
  my ($self) = @_;
  return sprintf("at %s = %.3f (%s)", $self->space, $self->x, ($self->active)?'active':'inactive');
};

__PACKAGE__->meta->make_immutable;
1;


=head1 NAME

Demeter::Plot::Indicator - Vertical lines marking points on a plot

=head1 VERSION

This documentation refers to Demeter version 0.9.

=head1 SYNOPSIS

Mark a position in k-space:

  my $data = Demeter::Data->new( ... );
  $data -> standard;
  $data -> plot('E');
  my $indic = Demeter::Plot::Indicator->new(space=>'k', x=>42);
  $indic -> plot;

then, show where that energy value is in k:

  $data  -> plot('k');
  $indic -> plot;

=head1 DESCRIPTION

Indicators are vertical lines used to draw attention to specific
points in plots of your data. This can be useful for comparing
specific features in different data sets or for seeing how a
particular feature propagates from energy to k to q.

Points selected in energy, k, or q are plotted in any of those
spaces. Points selected in R can only be plotted in R.

Note that you B<must> set a data standard (see L<Demeter::Mode>) to be
able to plot an indicator.  The indicator is always scaled to the size
of the standard data set.  It also uses the C<y_offset> attribute of
the standard and its E0 shift when plotting in energy.

In normal operation, the upper and lower bounds of the indicator are
genertated automatically, but they can be explicitly set using the
C<ymin> and C<ymax> attributes.

=head1 ATTRIBUTES

=over 4

=item C<space>

An indicator is associated with a space, one of E, k, R, or q.

=item C<x>

The position on the x-axis of the indicator.  For an energy indicator,
this must be an energy in eV I<relative> to the edge (i.e. something
like 70 rather than 7182).

=item C<x2>

For an energy indicator, this is the corresponding k value.  For a k
or q indicator, this is the corresponding energy value.  It gets
updated whenever C<x> is set.  For an R indicator, this is the same as
C<x>, although it wont actually be used for anything.

=item C<active>

This turns plotting of the indicator on and off.  When set to 0, the
C<plot> method returns silently.  This, then, is the equivalent of
"commenting out" an indicator without deleting it.

=item C<i>

This is an auto-generated index associated with the indicator.  In
practice, this is used in gnuplot to provide a tag for the (headless)
arrow that is plotted as the indicator.  There is no need to set this.
This attribute is accessed by the gnuplot indicator template.

=item C<ymin>

The lower bound of the indicator.  If left as 0, the lower bound will
be generated automatically based on the contents of the data standard.

=item C<ymax>

The upper bound of the indicator.  If left as 0, the upper bound will
be generated automatically based on the contents of the data standard.

=item C<y1>

The actual lower bound of the indicator.  This is C<ymin> scaled by is
the configured indicator margin.  Setting this does nothing as it will
be overwritten the next time that C<ymin> is set.

=item C<y2>

The actual upper bound of the indicator.  This is C<ymax> scaled by is
the configured indicator margin.  Setting this does nothing as it will
be overwritten the next time that C<ymax> is set.

=back

=head1 METHODS

=over

=item C<plot>

Plot the indicator in the space oset by the C<space> attribute of the
Plot object.

  $indic -> plot;

An indicator created in energy, k, or q will be plotted in energy, k,
or q.  Attempting to plot in R an indicator created in energy, k, or q
will silently do nothing.  Similarly, an indicator created in R will
silently do nothing when plotted in energy, k, or q.  This behavior
allows you to do something like this:

  $_ -> plot($space) foreach (@all_data, @all_indicators);

This will plot sensibly without regard to the value of C<$space> or
how the indicators were created.

=item C<xcoord>

Return the value of the x-coordinate of the indicator based on the
current settings of the Plot and standard Data object.

  my $x = $indic->xcoord;

=item C<y1coord>

Return the value of the lower y-coordinate of the indicator based on
the value of C<ymax> or current settings of the Plot and standard Data
object.

  my $y1 = $indic->y1coord;

=item C<y2coord>

Return the value of the upper y-coordinate of the indicator based on
the value of C<ymin> or current settings of the Plot and standard Data
object.

  my $y2 = $indic->y2coord;

=back

The C<xcoord>, C<y1coord>, and C<y2coord> are used in the templates
for plotting indicators.

=head1 SERIALIZATION AND DESERIALIZATION

Good question ...

=head1 CONFIGURATION AND ENVIRONMENT

See L<Demeter::Config> for a description of the configuration system.
There is an indicator group that can be adjusted to modify the default
behavior of this object.  It is in the F<ornaments.demeter_conf>
file.

=head1 DEPENDENCIES

Demeter's dependencies are in the F<Bundle/DemeterBundle.pm> file.

=head1 BUGS AND LIMITATIONS

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
