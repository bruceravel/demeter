package Ifeffit::Demeter::Project;

=for Copyright
 .
 Copyright (c) 2006-2008 Bruce Ravel (bravel AT bnl DOT gov).
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


use strict;
use warnings;
use Archive::Zip qw( :ERROR_CODES :CONSTANTS );;
use Carp;
use Class::Std;
use Class::Std::Utils;
use Fatal qw(open close);
use File::Path;
use File::Spec;
use Ifeffit;
use aliased 'Ifeffit::Demeter::Tools';

sub identify_self {
  #my ($class);
  my @caller = caller;
  use File::Basename qw(dirname);
  return dirname($caller[1]);
};


{

  sub dot_folder {
    my ($self) = @_;
    my $folder = (Tools->is_windows) ? q{}
      : File::Spec->catfile($ENV{HOME}, ".horae");
    mkpath($folder) if (not -d $folder);
    return $folder;
  };
  sub stash_folder {
    my ($self) = @_;
    my $folder = (Tools->is_windows) ? q{}
      : File::Spec->catfile($ENV{HOME}, ".horae", "stash");
    mkpath($folder) if (not -d $folder);
    return $folder;
  };
  sub project_folder {
    my ($self, $proj) = @_;
    return -1 if (not $proj);
    my $folder = (Tools->is_windows) ? q{}
      : File::Spec->catfile($ENV{HOME}, ".horae", "stash", $proj);
    mkpath($folder) if (not -d $folder);
    return $folder;
  };

  sub zip_project {
    my ($self, $folder, $fname) = @_;
    my $zip = Archive::Zip->new();
    my $dir_member = $zip->addTree( $folder );
    unless ( $zip->writeToFileNamed($fname) == AZ_OK ) {
      die "error writing zip file $fname";
    };
  };

  sub share_folder {
    my ($self) = @_;
    my $folder = File::Spec->catfile(identify_self(), "share");
    return $folder;
  };

};

1;


=head1 NAME

Ifeffit::Demeter::Project - Project file management

=head1 VERSION

This documentation refers to Ifeffit::Demeter version 0.1.

=head1 DESCRIPTION

This module contains various utilities involved in project file
management for the demeter system.  It provides tools for finding and
making the various temporary directories Demeter uses as workspace and
a method for packaging a workspace up into a zip file.

=head1 METHODS

There are no user methods.  This module contains tools used by other
modules.

=head1 DIAGNOSTICS

None.

=head1 CONFIGURATION AND ENVIRONMENT

See L<Ifeffit::Demeter::Config> for a description of the configuration system.

=head1 DEPENDENCIES

Demeter's dependencies are in the F<Bundle/DemeterBundle.pm> file.

=head1 BUGS AND LIMITATIONS

Please report problems to Bruce Ravel (bravel AT bnl DOT gov)

Patches are welcome.

=head1 AUTHOR

Bruce Ravel (bravel AT bnl DOT gov)

L<http://cars9.uchicago.edu/~ravel/software/>


=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2008 Bruce Ravel (bravel AT bnl DOT gov). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
