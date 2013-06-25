package Demeter::VPath;

=for Copyright
 .
 Copyright (c) 2006-2013 Bruce Ravel (bravel AT bnl DOT gov).
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
with 'Demeter::Data::IO';
with 'Demeter::Path::Process';
use Demeter::StrTypes qw( Empty );
if ($Demeter::mode->ui eq 'screen') {
  with 'Demeter::UI::Screen::Progress';
};

with 'Demeter::UI::Screen::Pause' if ($Demeter::mode->ui eq 'screen');

has '+plottable' => (default => 1);
has '+pathtype'  => (default => 1);
has '+data'      => (isa => Empty.'|Demeter::Data');
has '+name'      => (default => 'virtual path');
has 'id'         => (is => 'ro', isa => 'Str', default => 'virtual path');

has 'paths' => (
		traits    => ['Array'],
		is        => 'rw',
		isa       => 'ArrayRef[Demeter::Path]',
		default   => sub { [] },
		handles   => {
			      'push_paths'    => 'push',
			      'pop_paths'     => 'pop',
			      'shift_paths'   => 'shift',
			      'unshift_paths' => 'unshift',
			      'clear_paths'   => 'clear',
			     }
	       );
has 'pathgroups' => (
		     traits    => ['Array'],
		     is        => 'rw',
		     isa       => 'ArrayRef[Str]',
		     default   => sub { [] },
		     handles   => {
				   'push_pathgroups'    => 'push',
				   'pop_pathgroups'     => 'pop',
				   'shift_pathgroups'   => 'shift',
				   'unshift_pathgroups' => 'unshift',
				   'clear_pathgroups'   => 'clear',
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

override all => sub {
  my ($self) = @_;
  my %all = $self->SUPER::all;
  delete $all{paths};
  return %all;
};

sub label {
  my ($self) = @_;
  return $self->name;
};

sub include {
  my ($self, @paths) = @_;
  foreach my $p (@paths) {
    $self->push_paths($p);
    $self->push_pathgroups($p->group);
    $self->data($p->data) if not $self->data;
  };
  return $self;
};

sub clear {
  my ($self) = @_;
  $self->clear_paths;
  $self->clear_pathgroups;
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

## really?!? do I need to bring each consituent up to date in spaces other than k???
sub _update {
  my ($self, $which) = @_;
  foreach my $p ( @{ $self->paths } ) {  # bring each constituent path up to date
    $p->_update('fft');
  };
  $self->dispose($self->sum);
  $self->fft if ((lc($which) eq 'bft') or (lc($which) eq 'all'));
  $self->bft if (lc($which) eq 'all');
  return $self;
};

sub sum {
  my ($self, $space) = @_;
  my @list = @{ $self->paths };
  $self->start_spinner("Summing VPath ".$self->name) if ($self->mo->ui eq 'screen');
  my $command = $self->template("process", "prep_vpath");
  foreach my $p (@list[1..$#list]) {
    $self->mode->path($p);
    $command .= $self->template("process", "addto_vpath");
  };
  $self->mode->path(q{});
  $self->stop_spinner if ($self->mo->ui eq 'screen');
  return $command;
};

sub plot {
  my ($self, $space) = @_;
  return $self if not $self->is_valid;
  $space ||= $self->po->space;
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
  ## and plot the vpath
  $self->mode->path($self);
  $self->dispose($self->_plot_command($space), "plotting");
  $self->po->after_plot_hook($self);
  $self->mode->path(q{});
  $self->po->increment;
  $self->$which(0);
  return $self;
};

sub save {
  my ($self, $what, $filename) = @_;
  croak("No filename specified for save") unless $filename;
  ($what = 'chi') if (lc($what) eq 'k');
  croak("Valid save types are: chi r q") if ($what !~ m{\A(?:chi|r|q)\z});
  #$self->dispose($self->sum);
 WHAT: {
    (lc($what) eq 'chi') and do {
      $self->_update("fft");
      $self->data->_update('bft'); # need window from data object
      $self->dispose($self->_save_chi_command('k', $filename));
      last WHAT;
    };
    (lc($what) eq 'r') and do {
      $self->_update("bft");
      $self->data->_update('all');
      $self->dispose($self->_save_chi_command('r', $filename));
      last WHAT;
    };
    (lc($what) eq 'q') and do {
      $self->_update("all");
      $self->data->_update('bft');
      $self->dispose($self->_save_chi_command('q', $filename));
      last WHAT;
    };
  };
};


__PACKAGE__->meta->make_immutable;
1;


=head1 NAME

Demeter::VPath - Virtual paths for EXAFS visualization

=head1 VERSION

This documentation refers to Demeter version 0.9.18.

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

The VPath can also be saved to a column data file using the normal
C<save> and C<save_many> methods.

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

L<http://bruceravel.github.com/demeter/>


=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2013 Bruce Ravel (bravel AT bnl DOT gov). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut

