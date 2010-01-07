package Demeter::MRU;

=for Copyright
 .
 Copyright (c) 2006-2010 Bruce Ravel (bravel AT bnl DOT gov).
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

use Config::IniFiles;
use File::Spec;
use List::MoreUtils qw(uniq);

my $max_mru = 15;

sub push_mru {
  my ($self, $group, $file) = @_;
  my $stash = $self->stash_folder;
  return $self if ($file =~ m{$stash});
  my %mru;
  my $mrufile = File::Spec->catfile($self->dot_folder, "demeter.mru");
  tie %mru, 'Config::IniFiles', ( -file => $mrufile );
  my @list_of_files;

  if (exists $mru{$group}) {
    my %hash = %{ $mru{$group} };
    @list_of_files = map { $hash{$_} } sort keys %hash;
  } else {
    $mru{$group} = {};
  };

  unshift @list_of_files, $file;
  @list_of_files = uniq @list_of_files;
  ($#list_of_files = $max_mru) if ($#list_of_files > $max_mru);
  my $i = 0;
  foreach my $f (@list_of_files) {
    $mru{$group}{$i} = $f;
    ++$i;
  };
  tied(%mru)->WriteConfig($mrufile);
  #undef %mru;
  return $self;
};

sub get_mru_list {
  my ($self, @groups) = @_;
  my %mru;
  tie %mru, 'Config::IniFiles', ( -file => File::Spec->catfile($self->dot_folder, "demeter.mru") );
  my @list_of_files = ();
  foreach my $g (@groups) {
    next if not $mru{$g};
    my %hash = %{ $mru{$g} };
    push @list_of_files, map { [$hash{$_}, $g] } sort keys %hash;
  };
  undef %mru;
  return @list_of_files;
};

1;

=head1 NAME

Demeter::MRU - Handle lists of recently used file

=head1 VERSION

This documentation refers to Demeter version 0.4.

=head1 DESCRIPTION

This module contains methods for reading from and writing to lists of
recently used files.

=head1 METHODS

=over 4

=item C<push_mru>

Push a file onto the top of the list of recently used files for a file
group.

  $atoms_object -> push_mru( "atoms", $input_file);

This pushes C<$input_file> to the head of the list of recent files in
the C<atoms> group.

You can maintain any number of groups.  For instance, you might have
separate groups for data, project files, crystal data files, and so
on.

=item C<get_mru_list>

Return the list of recently used files from a file group:

  my @list_of_files = $atoms_object->get_mru_list("atoms");

or

  my @list_of_files = $atoms_object->get_mru_list(@list_of_goups);

The argument is one or more group names.

This list is actually a list of lists, like so:

  [ [file1, group1],
    [file2, group2],
      ...
    [fileN, groupN],
  ]

where the groups are things like "atoms", "feff" -- that is categories
of files used to organize the ini file containing the recent files.

=back

=head1 DIAGNOSTICS

None.

=head1 CONFIGURATION AND ENVIRONMENT

The recently used file lists are kept in a file called F<demeter.mru>
in the dotfile directory, C<$HOME/.horae> on unix and C<something> on
WIndows.

See L<Demeter::Config> for a description of the configuration system.

=head1 DEPENDENCIES

Demeter's dependencies are in the F<Bundle/DemeterBundle.pm> file.

=head1 BUGS AND LIMITATIONS

=over 4

=item *

List length is 16 items.  This should be configurable.

=back

Please report problems to Bruce Ravel (bravel AT bnl DOT gov)

Patches are welcome.

=head1 AUTHOR

Bruce Ravel (bravel AT bnl DOT gov)

L<http://cars9.uchicago.edu/~ravel/software/>


=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2010 Bruce Ravel (bravel AT bnl DOT gov). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
