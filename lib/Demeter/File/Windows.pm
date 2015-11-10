package Demeter::File::Windows;

use Moose::Role;
use Fcntl qw(:flock);
use Win32::Unicode::File qw(file_type);

sub readable {
  my ($self, $file) = @_;
  my $exists = file_type(e=>$file);
  return "$file does not exist" if (not $exists);
  my $isfile = file_type(f=>$file);
  return "$file is not a file"  if (not $isfile);
  #return "$file is locked"       if $self->locked($file);
  return 0;
};

sub locked {
  my ($self, $file) = @_;
  my $rc = open(my $HANDLE, $file);
  $rc = flock($HANDLE, LOCK_EX|LOCK_NB);
  close($HANDLE);
  return !$rc;
};


1;


=head1 NAME

Demeter::File::Windows - Utility methods for interacting with files on Windows systems

=head1 VERSION

This documentation refers to Demeter version 0.9.24.

=head1 DESCRIPTION

This module contains a number of methods for interacting with files on
Windows systems.

=head1 METHODS

=over 4

=item C<readable>

Return true if a file can be read.

=item C<locked>

Return true if a file is locked.

=back

=head1 BUGS AND LIMITATIONS

Please report problems to the Ifeffit Mailing List
(L<http://cars9.uchicago.edu/mailman/listinfo/ifeffit/>)

Patches are welcome.

=head1 AUTHOR

The euclid method was swiped from Math::Numbers by David Moreno Garza
and is Copyright (C) 2007 and is licensed like Perl itself.

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
