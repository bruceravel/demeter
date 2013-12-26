package Demeter::Data::FT;
use Moose::Role;

sub fft {
  my ($self) = @_;
  if ($self->datatype eq 'detector') {
    carp($self->name . " is a detector group, which cannot be Frouier transformed\n\n");
    return $self;
  };
  $self->fft_kwindow('kaiser')        if ($self->is_larch   and ($self->fft_kwindow eq 'kaiser-bessel'));
  $self->fft_kwindow('kaiser-bessel') if ($self->is_ifeffit and ($self->fft_kwindow eq 'kaiser'       ));
  my $save = $self->fft_dk;
  if ($self->is_larch and ($self->fft_kwindow eq 'kaiser')) {
    $self->fft_dk(0.1) if ($self->fft_dk < 0.1); # fix numerical error in larch implementation of kaiser window
  }
  $self->dispose($self->_fft_command);
  $self->chi_noise;
  $self->fft_dk($save);
  $self->update_fft(0);
};
sub _fft_command {
  my ($self) = @_;
  croak(ref($self)." objects cannot be Fourier transformed") if not $self->plottable;
  my $string = $self->template("process", "fft");
  return $string;
};

sub bft {
  my ($self) = @_;
  if ($self->datatype eq 'detector') {
    carp($self->name . " is a detector group, which cannot be Frouier transformed\n\n");
    return $self;
  };
  $self->bft_rwindow('kaiser')        if ($self->is_larch   and ($self->bft_rwindow eq 'kaiser-bessel'));
  $self->bft_rwindow('kaiser-bessel') if ($self->is_ifeffit and ($self->bft_rwindow eq 'kaiser'       ));
  my $save = $self->bft_dr;
  if ($self->is_larch and ($self->bft_rwindow eq 'kaiser')) {
    $self->bft_dr(0.1) if ($self->bft_dr < 0.1); # fix numerical error in larch implementation of kaiser window
  }
  $self->dispose($self->_bft_command);
  $self->bft_dr($save);
  $self->update_bft(0);
};
sub _bft_command {
  my ($self) = @_;
  croak(ref($self)." objects cannot be Fourier transformed") if not $self->plottable;
  my $string = $self->template("process", "bft");
  return $string;
};

1;

=head1 NAME

Demeter::Data::FT - Fourier transform mu(E) data

=head1 VERSION

This documentation refers to Demeter version 0.9.19.

=head1 DESCRIPTION

This role of Demeter::Data contains methods for performing
Fourier transforms.

=head1 METHODS

In practice, it should rarely be necessary to explicitly call these
methods.  When you plot data or peform other chores, Demeter will
notice whether the fourier transform is up-to-date and will call these
methods as needed.

=over 4

=item C<fft>

Perform a forward Fourier transform by generating and disposing of the
appropriate sequence of commands.

  $data_object -> fft;

=item C<bft>

Perform a backward Fourier transform by generating and disposing of the
appropriate sequence of commands.

  $data_object -> bft;

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

L<http://bruceravel.github.com/demeter/>

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2014 Bruce Ravel (bravel AT bnl DOT gov). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut

