package Demeter::UI::Athena::Timer;

use strict;
use warnings;

use Wx qw( :everything );
use base 'Wx::Timer';

use File::Monitor::Lite;
use File::Spec;

sub Notify {
  my ($timer) = @_;

  print "here...\n";
  my $base = $timer->{base};
  $::app->{main}->{Watcher}->{monitor}->check;
  my @created = $::app->{main}->{Watcher}->{monitor}->created;
  if (@created) {
    print "noticed $created[0]\n";
    if (exists $timer->{filemonitor}) {
      my $fname = File::Spec->catfile($timer->{filemonitor}->{name});
      if ( $timer->{size} - (-s $timer->{filemonitor}->{name}) < Demeter->co->default(qw(watcher fuzz))) {
	$timer->{size} = -s $timer->{filemonitor}->{name};
	print "(1)importing $fname  (" . $timer->{size} . ")\n";
      };
    };
    $timer->{filemonitor} = File::Monitor::Lite->new(in => $timer->{dir},
						     name => $created[0],
						    );
  };
  # if (not $::app->{main}->{Watcher}->{monitor}->anychange) {
  #   return if not exists $timer->{filemonitor};
  #   my $fname = File::Spec->catfile($timer->{filemonitor}->{name});
  #   print "(2)importing $fname\n";
  #   delete $timer->{filemonitor};
  # };

};

1;

=head1 NAME

Demeter::UI::Athena::Timer - A timer for use with Athena's data watcher

=head1 VERSION

This documentation refers to Demeter version 0.5.

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

Copyright (c) 2006-2011 Bruce Ravel (bravel AT bnl DOT gov). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
