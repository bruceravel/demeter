package Demeter::Data::BulkMerge;

use Moose;
extends 'Demeter';

use List::MoreUtils qw(any);

has 'align'  => (is => 'rw', isa => 'Bool', default => 0);
has 'smooth' => (is => 'rw', isa => 'Int',  default => 0);
has 'plugin' => (is => 'rw', isa => 'Str',  default => q{});
has 'max'    => (is => 'rw', isa => 'Int',  default => 1e9);
has 'size'   => (is => 'rw', isa => 'Int',  default => 0);
has 'margin' => (is => 'rw', isa => 'Num',  default => 0.997);
has 'count'  => (is => 'rw', isa => 'Int',  default => 0);

has 'data' => (
	       traits    => ['Array'],
	       is        => 'rw',
	       isa       => 'ArrayRef',
	       default   => sub { [] },
	       handles   => {
			     'push_data'    => 'push',
			     'pop_data'     => 'pop',
			     'shift_data'   => 'shift',
			     'unshift_data' => 'unshift',
			     'clear_data'   => 'clear',
			    }
	      );
has 'subsample' => (
		   traits    => ['Array'],
		   is        => 'rw',
		   isa       => 'ArrayRef[Int]',
		   default   => sub { [] },
		   handles   => {
				 'push_subsample'    => 'push',
				 'pop_subsample'     => 'pop',
				 'shift_subsample'   => 'shift',
				 'unshift_subsample' => 'unshift',
				 'clear_subsample'   => 'clear',
				}
		  );
has 'sequence' => (
		   traits    => ['Array'],
		   is        => 'rw',
		   isa       => 'ArrayRef',
		   default   => sub { [] },
		   handles   => {
				 'push_sequence'    => 'push',
				 'pop_sequence'     => 'pop',
				 'shift_sequence'   => 'shift',
				 'unshift_sequence' => 'unshift',
				 'clear_sequence'   => 'clear',
				}
		  );
has 'skipped' => (
		   traits    => ['Array'],
		   is        => 'rw',
		   isa       => 'ArrayRef',
		   default   => sub { [] },
		   handles   => {
				 'push_skipped'    => 'push',
				 'pop_skipped'     => 'pop',
				 'shift_skipped'   => 'shift',
				 'unshift_skipped' => 'unshift',
				 'clear_skipped'   => 'clear',
				}
		  );

has 'master' => (is => 'rw', isa => 'Demeter::Data',
		 trigger => sub{my ($self, $new) = @_;
				if ($new) {
				  $self->sum($new->clone);
				  $self->sum->standard;
				  $self->sum->set(is_col=>0, i0_string=>q{}, signal_string=>q{}, i0_scale=>1, signal_scale=>1);
				};
			      });
has 'sum'    => (is => 'rw', isa => 'Demeter::Data');

sub BUILD {
  my ($self, @params) = @_;
  $self->mo->push_BulkMerge($self);
};


sub merge {
  my ($self) = @_;

  my $save = $self->po->e_smooth;
  $self->po->set(e_smooth=>$self->smooth);
  my $size  = $self->size || -s $self->master->source;
  my $group = 'mega';
  my ($plug, $thisdata);
  my $count = 1;
  $self->sum -> start_counter("Merging data", $#{$self->data}) if $self->mo->ui eq 'screen';

  Demeter->set_mode(screen=>0);
  foreach my $file (@{$self->data}) {
    $self->push_skipped($file), next if (not -e $file);
    $self->push_skipped($file), next if (not -r $file);
    $self->push_skipped($file), next if (-s $file < $self->margin*$size);
    last if ($count == $self->max);
    ++$count;
    $self->sum -> count if $self->mo->ui eq 'screen';

    if ($self->plugin) {
      my $which = 'Demeter::Plugins::' . $self->plugin;
      $plug     = $which->new(file=>$file);
      my $ok = eval {$plug->fix};
      die $@ if $@;
      $thisdata = Demeter::Data->new(group  => 'mega', quickmerge=>1, file=>$plug->fixed, $plug->suggest('fluorescence'),
				     bkg_e0 => $self->master->bkg_e0,
				    );
    } else {
      $thisdata = Demeter::Data->new(group=>'mega', quickmerge=>1, file=>$file,
				     energy      => $self->master->energy,
				     numerator   => $self->master->numerator,
				     denominator => $self->master->denominator,
				     ln	         => $self->master->ln,
				     bkg_e0      => $self->master->bkg_e0,
				    );
    };
    $thisdata -> _update('data');
    $self->master -> align($thisdata) if $self->align;
    $thisdata -> dispose($thisdata->template('process', 'musum'));
    if (any {$count == $_} @{$self->subsample}) {
      $self -> dispose("##| Quick merge subsample of $count spectra");
      my $sample = $self->sum->clone;
      $sample -> set(name=>"Merge of $count scans", is_col=>0, i0_string=>q{}, signal_string=>q{}, i0_scale=>1, signal_scale=>1);
      $sample -> update_norm(1);
      $sample -> dispose($sample->template('process', 'muave', {count=>$count}));
      $self->push_sequence($sample);
    };
    $thisdata->DEMOLISH;
    unlink $plug->fixed if $self->plugin;
  };
  $self->sum -> stop_counter if $self->mo->ui eq 'screen';
  $self->count($count);

  $self->sum -> dispose($self->sum->template('process', 'muave', {count=>$self->count}));
  $self->sum -> update_norm(1);
  $self->sum -> name("Merge of $count scans");

  $self->po->set(e_smooth=>$save);
  return $self->sum;
};





__PACKAGE__->meta->make_immutable;
1;


=head1 NAME

Demeter::Data::MultiChannel - Efficiantly merge many files into a single spectrum

=head1 VERSION

This documentation refers to Demeter version 0.9.

=head1 DESCRIPTION

This object provides an efficient way to merge a large number of files
into a single spectrum.  The assumption is that the user is not
interested in having each individual file processed.  This would be
the case for measuring many repititions for the sake of improving the
statistical quality of the data.

  my $data = Demeter::Data->new(file=>$file, ...);
  my $bulk = Demeter::Data::BulkMerge->new(master => $data,
                                           data => \@list_of_files);
  my $merged = $bulk->merge;
  $_->plot('E') foreach ($data, $merged);

The trick is that each file is only imported to the point of having
arrays for energy and xmu in Ifeffit.  Each file in the list is
imported to the same Ifeffit group.  The merge is computed by
accumulation and divided by the total numberof scans.

This requires that one data file be considered carefully.  This is the
C<master>.  All other data are interpolated to the energy grid of the
C<master>.

Care is taken not to include files which are less than 95%
(configurable with the C<margin> attribute) of the size of the master
data file.

Note that preprocessing the data takes time.  A run with the C<plugin>
and C<align> attributes set takes about twice as long as a straight
merge of the raw data.

=head1 ATTRIBUTES

=over 4

=item C<master> [Demeter::Data object]

This contains the L<Demeter::Data> object for the processed data group
to which all subsequent data files are merged.  This acts as the
interpolation standard and as the alignment standard (if the C<align>
attribute is true).  The merged data group will inherit attributes
from this group.  So, if the master has sensible parameters for
normalization and background removal, the merged group will have the
same sensible parameters.

=item C<data> [list of strings]

This is a list of fully resolved paths to the data files to be merged.
These can be relative or absolute paths, but they B<must> resolve
correctly to actual files.  Files that don't exist or aren't readable
will be silently ignored.

=item C<align> [boolean]

When true, this says to align each file in the C<data> list to the
C<master>.

=item C<smooth> [integer]

When non-zero, the alignment will be done using the smoothed
derivative spectrum.  The value of this parameter indicated the number
of smoothings.

=item C<plugin> [string]

The name of the plugin to use to interpret the data.  For example, to
use the L<Demeter::Data::X23A2MED> plugin, this attribute would be set
to C<X23A2MED>.

=item C<margin> [number between 0 and 1]

This number defines the margin in filesize outside of which a data
file is excluded from the merge.  The default is 0.997, thus any file
in the C<data> list which is smaller than 99.7% the size of the
C<master> file will be excluded.

=item C<subsample>  [array of integers]

This is used to specify sub-samplings of the data ensemble, presumably
to test convergence to the mean.  If this is set to C<[4, 16, 64]>
then Data groups will be saved which sum 4, 16, and 64 of the files
included in the merge.  The sub-sampled Data groups are saved to the
C<sequence> attribute.

=item C<sequence>  [array of Data objects]

Data objects from a sub-sampling sequence.

=back

=head1 METHODS

=over 4

=item C<merge>

Performs the merge using some special optimizations that minimize the
interaction with Ifeffit.  This returns a Data object containing the
merged spectrum, divided by the number of spectra included in the
merge.

=back

=head1 CONFIGURATION

There are no configuration options for this class.

See L<Demeter::Config> for a description of Demeter's
configuration system.

=head1 DEPENDENCIES

Demeter's dependencies are in the F<Bundle/DemeterBundle.pm> file.

=head1 BUGS AND LIMITATIONS

=over 4

=item *

A file that exists and is readable, but is not data will make for a
confusing error

=item *

Standard deviation not computed

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
