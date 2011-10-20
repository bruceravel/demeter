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
      print "(1)importing $fname\n";
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
