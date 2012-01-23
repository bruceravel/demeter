package Demeter::Data::BulkMerge;

use Moose;
use MooseX::AttributeHelpers;
#use MooseX::StrictConstructor;
extends 'Demeter';

has 'align'  => (is => 'rw', isa => 'Bool', default => 0);
has 'plugin' => (is => 'rw', isa => 'Str', default => q{});
has 'max'    => (is => 'rw', isa => 'Int', default => 1e9);
has 'size'   => (is => 'rw', isa => 'Int', default => 0);

has 'data' => (
	       metaclass => 'Collection::Array',
	       is        => 'rw',
	       isa       => 'ArrayRef',
	       default   => sub { [] },
	       provides  => {
			     'push'    => 'push_data',
			     'pop'     => 'pop_data',
			     'shift'   => 'shift_data',
			     'unshift' => 'unshift_data',
			     'clear'   => 'clear_data',
			    }
	      );

has 'master' => (is => 'rw', isa => 'Demeter::Data',
		 trigger => sub{my ($self, $new) = @_;
				$self->sum($new->clone) if $new;
				$self->sum->standard;
			      });
has 'sum'    => (is => 'rw', isa => 'Demeter::Data');

sub BUILD {
  my ($self, @params) = @_;
  $self->mo->push_BulkMerge($self);
};


sub merge {
  my ($self) = @_;

  my $size  = $self->size || -s $self->master->file;
  my $group = 'mega';
  my ($plug, $thisdata);
  my $count = 0;
  $self->sum -> start_counter("Merging data", $#{$self->data}) if $self->mo->ui eq 'screen';
  Demeter->set_mode(screen=>0);

  foreach my $file (@{$self->data}) {
    next if (-s $file < 0.95*$size);
    ++$count;
    $self->sum -> count if $self->mo->ui eq 'screen';

    if ($self->plugin) {
      my $which = 'Demeter::Plugins::' . $self->plugin;
      $plug     = $which->new(file=>$file);
      my $ok = eval {$plug->fix};
      die $@ if $@;
      $thisdata = Demeter::Data->new(group=>'mega', quickmerge=>1, file=>$plug->fixed, $plug->suggest('fluorescence'));
    } else {
      $thisdata = Demeter::Data->new(group=>'mega', quickmerge=>1, file=>$file,
				     energy      => $self->master->energy,
				     numerator   => $self->master->numerator,
				     denominator => $self->master->denominator ,
				     ln	         => $self->master->ln
				    );
    };
    $thisdata -> _update('data');
    $thisdata -> dispose($thisdata->template('process', 'musum'));
    unlink $plug->fixed if $self->plugin;
  };
  $self->sum -> stop_counter if $self->mo->ui eq 'screen';

  $self->sum -> dispose($self->sum->template('process', 'muave', {count=>$count}));
  $self->sum -> update_norm(1);
  $self->sum -> name("Merge of $count scans");

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

Care is taken not to include files which are less than 95% of the size
of the master data file.

=head1 ATTRIBUTES

=over 4

=item C<master>

L<Demeter::Data> object...

=item C<data>

Fully resolved paths....

=item C<align>

=item C<plugin>

=item C<size>

=back

=head1 METHODS

=over 4

=item C<merge>

This returns a Data object containing the merged spectrum, divided by
the number of spectra included in the merge.

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

Standard deviation not computed

=item *

Plugins

=item *

alignment

=item *

use quickmerge attribute

=item *

Save intermediate spectra, demonstrate central limit theorem

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
