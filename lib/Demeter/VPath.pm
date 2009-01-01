package Demeter::VPath;

=for Copyright
 .
 Copyright (c) 2006-2009 Bruce Ravel (bravel AT bnl DOT gov).
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

use Moose;
extends 'Demeter';
with 'Demeter::Data::Arrays';
with 'Demeter::Path::Process';
use MooseX::AttributeHelpers;
use Demeter::StrTypes qw( Empty );

has '+plottable' => (default => 1);
has '+data'      => (isa => Empty.'|Demeter::Data');
has '+name'      => (default => 'virtual path');
has 'id'         => (is => 'ro', isa => 'Str', default => 'virtual path');

has 'paths' => (
		metaclass => 'Collection::Array',
		is        => 'rw',
		isa       => 'ArrayRef[Demeter::Path]',
		default   => sub { [] },
		provides  => {
			      'push'    => 'push_paths',
			      'pop'     => 'pop_paths',
			      'shift'   => 'shift_paths',
			      'unshift' => 'unshift_paths',
			      'clear'   => 'clear_paths',
			     }
	       );

## data processing flags
has 'update_path' => (is=>'rw', isa=>  'Bool',  default => 1,
		      trigger => sub{ my($self, $new) = @_; $self->update_fft(1) if $new});
has 'update_fft'  => (is=>'rw', isa=>  'Bool',  default => 1,
		      trigger => sub{ my($self, $new) = @_; $self->update_bft(1) if $new});
has 'update_bft'  => (is=>'rw', isa=>  'Bool',  default => 1);

sub BUILD {
  my ($self, @params) = @_;
  $self->mo->push_VPath($self);
};

sub include {
  my ($self, @paths) = @_;
  foreach my $p (@paths) {
    $self->push_paths($p);
    $self->data($p->data) if not $self->data;
  };
  return $self;
};

sub clear {
  my ($self) = @_;
  $self->clear_paths;
  $self->data(q{});
  return $self;
};

## at least one consituent is required to actually do something with a VPath
sub is_valid {
  my ($self) = @_;
  my @list = @{ $self->paths };
  return 1 if scalar(@list);
  return 0;
};

sub first {			# see prep_vpath.tmpl
  my ($self) = @_;
  my @list = @{ $self->paths };
  return $list[0];
};

sub _update {
  my ($self, $which) = @_;
  foreach my $p ( @{ $self->paths } ) {  # bring each constituent path up to date
    $p->_update(lc($which));
  };
  return $self;
};

sub sum {
  my ($self, $space) = @_;
  my @list = @{ $self->paths };
  my $command = $self->template("process", "prep_vpath");
  foreach my $p (@list[1..$#list]) {
    $self->mode->path($p);
    $command .= $self->template("process", "addto_vpath");
  };
  $self->mode->path(q{});
  return $command;
};

sub plot {
  my ($self, $space) = @_;
  return $self if not $self->is_valid;
  my $which = q{};
  ## make sure all the constituent paths are up to date
  if (lc($space) eq 'k') {
    $self -> _update("fft");
    $which = "update_path";
  } elsif (lc($space) eq 'r') {
    $self -> _update("bft");
    $which = "update_fft";
  } elsif (lc($space) eq 'q') {
    $self -> _update("all");
    $which = "update_bft";
  };
  ## make the sum in k-space
  $self->dispose($self->sum);
  ## bring the vpath up to date
  $self->fft if ((lc($space) eq 'r') or (lc($space) eq 'q'));
  $self->bft if (lc($space) eq 'q');
  ## and plot the vpath
  $self->mode->path($self);
  $self->dispose($self->_plot_command($space), "plotting");
  $self->mode->path(q{});
  $self->po->increment;
  $self->$which(0);
  return $self;
};

__PACKAGE__->meta->make_immutable;
1;


=head1 NAME

Demeter::VPath - Virtual paths for EXAFS visualization

=head1 VERSION

This documentation refers to Demeter version 0.3.

=head1 SYNOPSIS

Build a virtual path from several real paths.

  my $vpath = Demeter::VPath->new(name => "my virtual path");
  $vpath -> include($path1, $path3, $path12);
  $vpath -> plot('R');

=head1 DESCRIPTION

A fit can involve I<a lot> of paths.  It is often useful to make a
plot showing your data and its fit along with some of the paths that
went into the fit.  In a fit with lots of small paths, one might want
to convey a sense of how several small paths affect the fit in
aggregate.  A plot showing each individual path will be messy and
won't actually convey the point.

The VPath object is tool for addressing this.  A VPath, or "virtual
path", is a sum of two or more paths which is Fourier transformed and
plotted as a single object.  This cleans up your plot and more
directly conveys the effect of the constituent paths on the fit.

This object carries a sufficiently low-overhead that you can safely
destroy one and recreate it with a different list of paths.  That will
usually be easier than managing the content of the C<paths> atrtibute
(although you can certainly do so, if you prefer).

=head1 ATTRIBUTES

Along with the standard attributes of a Demeter object (C<name>,
C<plottable>, C<data>, and so on), a VPath has the following:

=over 4

=item C<paths>

This is the sole user-servicable attribute specific to this class.
Its accessor returns the list of Path objects making up this VPath.

  my @list_of_paths = $vpath -> paths;

See the include method for how to set this attribute properly.

=back

You should set the C<name> attribute to something useful.  By default,
the name will be "virtual path".  The C<data> attribute is set to be
the same as the first Path in the list of paths contributing to the
VPath.

The methods C<push_paths>, C<pop_paths>, C<shift_paths>,
C<unshift_paths>, and C<clear_paths> are defined to operate on this
list.  But they should be used with caution.  The C<inlcude> and
C<clear> methods below are wrappers around these which perform
additional chores necessary for the correct operation of the VPath
object.

=head1 METHODS

=over 4

=item C<include>

Use this method to put one or more Path objects in the VPath's list of
paths:

  $vpath -> include($some_path);
    or
  $vpath -> include(@a_bunch_of_paths);

While you could, in principle, use the C<paths> attribute accessor and
its service methods to set the list of paths, this method performs the
additional chore of correctly setting the C<data> attribute.

=item C<clear>

This method empties out the path list and unsets the data attribute
without destroying the VPath object.

  $vpath -> clear;
  ## @{ $vpath->paths } is now ();

=item C<first>

Return the first path in the VPath's path list;

  $first_one = $vpath -> first;

This is used in the C<prep_vpath> template.

=back

=head1 SERIALIZATION AND DESERIALIZATION

Good question ...

=head1 CONFIGURATION AND ENVIRONMENT

See L<Demeter::Config> for a description of the configuration system.

=head1 DEPENDENCIES

Demeter's dependencies are in the F<Bundle/DemeterBundle.pm> file.

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

