package Demeter::Path::Process;
use Moose::Role;


## paths are Fourier transformed just like their respective data,
## these methods just rewrite the data fftf() and fftr() command
## using the group name of the path
sub fft {
  my ($self) = @_;
  $self->_update("fft");
  $self->dispose($self->_fft_command);
  $self->update_fft(0);
};
sub _fft_command{
  my ($self) = @_;
  my $group = $self->group;
  my $dobject = $self->data->group;
  my $string = $self->data->_fft_command;
  $string =~ s{\b$dobject\b}{$group}g; # replace group names
  return $string;
};

sub bft {
  my ($self) = @_;
  $self->_update("bft");
  $self->dispose($self->_bft_command);
  $self->update_bft(0);
};
sub _bft_command{
  my ($self) = @_;
  my $group = $self->group;
  my $dobject = $self->data->group;
  my $string = $self->data->_bft_command;
  $string =~ s{\b$dobject\b}{$group}g; # replace group names
  return $string;
};

sub _plot_command{
  my ($self, $space) = @_;
  my $group     = $self->group;
  my $label     = $self->name;
  my $dobject   = $self->data->group;
  my $datalabel = $self->data->name;
  $self->set_mode(path=>$self) if (ref($self) =~ m{Path});
  my $string    = $self->data->_plot_command($space);
  $self->set_mode(path=>q{});
  $string =~ s{\b$dobject\b}{$group}g; # replace group names
  ## (?<= ) is the positive zero-width look behind -- it only replaces
  ## the label when it follows q{key="}, that way it won't get confused by
  ## the same text in the title for a newplot
  $string =~ s{(?<=key=")$datalabel}{$label};
  return $string;
};


1;


=head1 NAME

Demeter::Path::Process - Plotting and Fourier transform methods for Feff paths

=head1 VERSION

This documentation refers to Demeter version 0.9.20.

=head1 DESCRIPTION

This role of Demeter::Path contains methods for performing Fourier
transforms.  This is also used as a role by the VPath object.

=head1 METHODS

In practice, it should rarely be necessary to explicitly call these
methods.  When you plot paths or peform other chores, Demeter will
notice whether the Fourier transform is up-to-date and will call these
methods as needed.

=over 4

=item C<fft>

Perform a forward Fourier transform by generating and disposing of the
appropriate sequence of Ifeffit or Larch commands.

  $path_object -> fft;

=item C<bft>

Perform a backward Fourier transform by generating and disposing of the
appropriate sequence of Ifeffit or Larch commands.

  $path_object -> bft;

=back

=head1 CONFIGURATION

See L<Demeter::Config> for a description of the configuration
system.

=head1 DEPENDENCIES

Demeter's dependencies are in the F<Build.PL> file.

=head1 BUGS AND LIMITATIONS

Please report problems to the Ifeffit Mailing List
(L<http://cars9.uchicago.edu/mailman/listinfo/ifeffit/>)

Patches are welcome.

=head1 AUTHOR

Bruce Ravel (bravel AT bnl DOT gov)

L<http://bruceravel.github.io/demeter/>

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2014 Bruce Ravel (bravel AT bnl DOT gov). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut

