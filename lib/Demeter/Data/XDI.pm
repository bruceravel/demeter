package Demeter::Data::XDI;
use Moose::Role;

has 'xdi_applications'	      => (is => 'rw', isa => 'Str', default => q{});

has 'xdi_abscissa'	      => (is => 'rw', isa => 'Str', default => q{});
has 'xdi_beamline'	      => (is => 'rw', isa => 'Str', default => q{});
has 'xdi_collimation'	      => (is => 'rw', isa => 'Str', default => q{});
has 'xdi_crystal'	      => (is => 'rw', isa => 'Str', default => q{});
has 'xdi_d_spacing'	      => (is => 'rw', isa => 'Str', default => q{});
has 'xdi_edge_energy'	      => (is => 'rw', isa => 'Str', default => q{});
has 'xdi_end_time'	      => (is => 'rw', isa => 'Str', default => q{});
has 'xdi_focusing'	      => (is => 'rw', isa => 'Str', default => q{});
has 'xdi_harmonic_rejection'  => (is => 'rw', isa => 'Str', default => q{});
has 'xdi_mu_fluorescence'     => (is => 'rw', isa => 'Str', default => q{});
has 'xdi_mu_reference'	      => (is => 'rw', isa => 'Str', default => q{});
has 'xdi_mu_transmission'     => (is => 'rw', isa => 'Str', default => q{});
has 'xdi_ring_current'	      => (is => 'rw', isa => 'Str', default => q{});
has 'xdi_ring_energy'	      => (is => 'rw', isa => 'Str', default => q{});
has 'xdi_start_time'	      => (is => 'rw', isa => 'Str', default => q{});
has 'xdi_source'	      => (is => 'rw', isa => 'Str', default => q{});
has 'xdi_undulator_harmonic'  => (is => 'rw', isa => 'Str', default => q{});

has 'xdi_extensions'   => (metaclass => 'Collection::Array',
			   is => 'rw', isa => 'ArrayRef[Str]',
			   default => sub{[]},
			   provides  => {
					 'push'  => 'push_extension',
					 'pop'   => 'pop_extension',
					 'clear' => 'clear_extensions',
					},
			  );

has 'xdi_comments'     => (
			   metaclass => 'Collection::Array',
			   is        => 'rw',
			   isa       => 'ArrayRef',
			   default   => sub { [] },
			   provides  => {
					 'push'  => 'push_comment',
					 'pop'   => 'pop_comment',
					 'clear' => 'clear_comments',
					}
			  );

sub import_xdi {
  my ($self, $xdi) = @_;
  foreach my $f (qw(applications abscissa beamline collimation crystal
		    d_spacing edge_energy end_time focusing harmonic_rejection
		    mu_fluorescence mu_reference mu_transmission ring_current
		    ring_energy start_time source undulator_harmonic extensions
		    comments)) {
    my $att = 'xdi_' . $f;
    $self->$att($xdi->$f);
  };
  ## move data into Ifeffit arrays
  ## use math expressions for making spectra
};

1;


=head1 NAME

Demeter::Data::XDI - Import XDI objects into Demeter Data objects

=head1 VERSION

This documentation refers to Demeter version 0.4.

This is compliant with L<Xray::XDI> version 1.0.

=head1 METHODS

=over 4

=item C<import_xdi>

Turn an Xray::XDI object into a Demeter::Data object.

  $data  = Demeter::Data->new;
  $xdi   = Xray::Data->new;
  $xdi  -> file($file);
  $data -> import_xdi($xdi);

=back

=head1 BUGS AND LIMITATIONS

Please report problems to Bruce Ravel (bravel AT bnl DOT gov)

Patches are welcome.

=head1 AUTHOR

Bruce Ravel (bravel AT bnl DOT gov)

L<http://cars9.uchicago.edu/~ravel/software/>

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2011 Bruce Ravel (bravel AT bnl DOT gov). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
