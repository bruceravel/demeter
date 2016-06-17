package Demeter::File::Windows;

use Moose::Role;
use Fcntl qw(:flock);
use File::Basename;
use Text::Unidecode;
use Win32::Unicode::File qw(file_type copyW);

sub readable {
  my ($self, $file) = @_;
  my $exists = file_type(e=>$file);
  return "$file does not exist" if (not $exists);
  my $isfile = file_type(f=>$file);
  return "$file is not a file"  if (not $isfile);
  #return "$file is locked"      if $self->locked($file);
  return 0;
};

sub locked {
  my ($self, $file) = @_;
  my $rc = open(my $HANDLE, $file);
  $rc = flock($HANDLE, LOCK_EX|LOCK_NB);
  close($HANDLE);
  return !$rc;
};

sub is_unicode {
  my ($self, $file) = @_;
  ##if ($self->readable($file) and (not -r $file)) {
  ##  ## likely indicator of a problematic unicode file name
  if ($file =~ m{[^[:ascii:]]}) { # see http://perldoc.perl.org/perlrecharclass.html#POSIX-Character-Classes
    return 1;
  };
  return 0;
};

sub unicopy {
  my ($self, $file) = @_;
  my $target = File::Spec->catfile(Demeter->stash_folder, unidecode(basename($file)));
  copyW($file, $target);
  return $target;
};


1;


=head1 NAME

Demeter::File::Windows - Utility methods for interacting with files on Windows systems

=head1 VERSION

This documentation refers to Demeter version 0.9.25.

=head1 DESCRIPTION

This module contains a number of methods for interacting with files on
Windows systems.  There seems to be some confusion surrounding
encoding when using Wx::FileDialog to get the name of a file with
non-US-ASCII characters in its path and/or name.  This module provides
tools Athena and Artemis can use to manage such files.

=head1 METHODS

=over 4

=item C<readable>

Return true if a file can be read.

=item C<locked>

Return true if a file is locked.

=item C<unicopy>

Safely copy a file to the stash folder, unidecoding basename.  Returns
the safe, fully ASCII file path+name.

=back

=head1 DEPENDENCIES

The dependencies of the Demeter system are listed in the
F<Build.PL> file.

This module uses F<Win32::Unicode::File> and F<Text::Unidecode>.

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

Copyright (c) 2006-2016 Bruce Ravel (L<http://bruceravel.github.io/home>). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
