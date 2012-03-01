package Demeter::UI::Athena::Timer;

use strict;
use warnings;

use Wx qw( :everything );
use base 'Wx::Timer';

use File::Monitor::Lite;
use File::Spec;

use Demeter::UI::Athena::IO;

my $verbose = 1;

sub Notify {
  my ($timer) = @_;

  printf("here... (%s  %s)\n", $::app->{main}->{Watcher}->{monitor}->{in}, $::app->{main}->{Watcher}->{monitor}->{name}) if $verbose;
  my $base = $timer->{base};
  $::app->{main}->{Watcher}->{monitor}->check;
  my @created = $::app->{main}->{Watcher}->{monitor}->created;
  if (@created) {
    print "noticed $created[0]\n" if $verbose;
    my $fname = $created[0];
    $timer->{fname} = $fname;
    $timer->{size}  = -s $fname;
    return;
  };

  my @modified = $::app->{main}->{Watcher}->{monitor}->modified;
  if (@modified) {
    print "(1)noticed change to ".$timer->{fname}.$/ if $verbose;

  } elsif ($timer->{fname}) {

    print "(2)importing ".$timer->{fname}.$/ if $verbose;
    import_data($timer->{fname});
    $timer->{fname} = q{};
  };

};

# Use of uninitialized value $line in pattern match (m//) at
# /home/bruce/git/demeter/lib/Demeter/Plugins/X23A2MED.pm line 29,
# <$D> line 1.



sub import_data {
  my ($fname) = @_;
  open(my $Y, '>', File::Spec->catfile(Demeter->dot_folder, "athena.column_selection"));
  print $Y $::app->{main}->{Watcher}->{yaml};
  close $Y;
  $::app->Import($fname, no_main=>1, no_interactive=>1);
};


1;

=head1 NAME

Demeter::UI::Athena::Timer - A timer for use with Athena's data watcher

=head1 VERSION

This documentation refers to Demeter version 0.9.

=head1 SYNOPSIS

This module provides a timer for use with Athena's data watcher.  It
provides the functionality for watching the disk and importing data as
scans finish.

This simply overrides Wx::Timer and provides its own C<Notify> method,
which actually does the watching and data importing.

=head1 CONFIGURATION


=head1 DEPENDENCIES

Demeter's dependencies are in the F<Bundle/DemeterBundle.pm> file.

=head1 BUGS AND LIMITATIONS

=over 4

=item *

Actually import

=item *

Deal with the last file in a sequence of scans

=back

Please report problems to Bruce Ravel (bravel AT bnl DOT gov)

Patches are welcome.

=head1 AUTHOR

Bruce Ravel (bravel AT bnl DOT gov)

L<http://cars9.uchicago.edu/~ravel/software/>

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2012 Bruce Ravel (bravel AT bnl DOT gov). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
