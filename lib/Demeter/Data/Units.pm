package Demeter::Data::Units;

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

use Moose::Role;

use Carp;
use Readonly;
Readonly my $ETOK    => 0.262468292;

sub e2k {
  my ($self, $e, $how) = @_;
  return 0 if (not defined($e));
  return 0 if ($e<0);
  $how ||= 'rel';
  if ($how =~ m{rel}) {	        # relative energy
    return sqrt($e*$ETOK);
  } else {			# absolute energy
    my $e0 = $self->bkg_e0;
    ($e < $e0) and ($e0 = 0);
    return sqrt(($e-$e0)*$ETOK);
  };
};

sub k2e {
  my ($self, $k, $how) = @_;
  return 0 if ($k<0);
  $how ||= 'rel';
  if ($how =~ m{rel}) {		# relative energy
    return $k**2 / $ETOK;
  } else {			# absolute energy
    my $e0 = $self->bkg_e0;
    return ($k**2 / $ETOK) + $e0;
  };
};

1;

=head1 NAME

Demeter::Data::Units - Unit conversion

=head1 SYNOPSIS

  my $data = Demeter::Data -> new;
  my $k = $data->e2k(312);
  my $e = $data->k2e(3.7);

=head1 DESCRIPTION

This role of Demeter::Data contains methods for unit conversion.

=head1 METHODS

=over 4

=item C<e2k>

This method converts between relative energy values and wavenumber
using the group's value for e0.

=item C<k2e>

This method converts between relative wavenumber and energy values
using the group's value for e0.

=back

=head1 CONFIGURATION

See L<Demeter::Config> for a description of the configuration
system.

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
