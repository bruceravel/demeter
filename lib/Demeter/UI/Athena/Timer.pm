package Demeter::UI::Athena::Timer;

use strict;
use warnings;

use Wx qw( :everything );
use base 'Wx::Timer';

use File::Monitor::Lite;
use File::Spec;

use Demeter::UI::Athena::IO;

sub Notify {
  my ($timer) = @_;

  my $base = $timer->{base};
  $::app->{main}->{Watcher}->{monitor}->check;
  my @created = $::app->{main}->{Watcher}->{monitor}->created;
  my @modified = $::app->{main}->{Watcher}->{monitor}->modified;
  if (@modified) {
    $::app->{main}->status("Noticed change to " . $timer->{fname});
    $timer->{size}  = -s $timer->{fname};
  };
  if ($timer->{prev}) {
    $::app->{main}->status("Importing watched file " . $timer->{prev});
    import_data($timer->{prev});
    $timer->{prev} = q{};
  };
  if (@created) {
    my $fname = $created[0];
    $::app->{main}->status("Noticed creation of $fname");
    $timer->{prev}  = $timer->{fname};
    $timer->{fname} = $fname;
    $timer->{size}  = -s $fname;
    return;
  };

};

sub import_data {
  my ($fname) = @_;
  open(my $Y, '>', File::Spec->catfile(Demeter->dot_folder, "athena.column_selection"));
  print $Y $::app->{main}->{Watcher}->{yaml};
  close $Y;
  my $save = Demeter->po->e_smooth;
  Demeter->po->e_smooth(3);
  $::app->Import($fname, no_main=>1, no_interactive=>1);
  Demeter->po->e_smooth($save);
  $::app->plot(q{}, q{}, 'E', 'marked') if $::app->{main}->{Watcher}->{plot}->GetValue;
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

=head1 DEPENDENCIES

Demeter's dependencies are in the F<Bundle/DemeterBundle.pm> file.

=head1 BUGS AND LIMITATIONS

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
