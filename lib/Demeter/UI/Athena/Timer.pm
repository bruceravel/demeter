package Demeter::UI::Athena::Timer;

use strict;
use warnings;

use Wx qw( :everything );
use base 'Wx::Timer';

use File::Spec;

sub Notify {
  my ($timer) = @_;

  print "here...\n";
  my $base = $timer->{base};
  opendir(my $D, $timer->{dir});
  my @hits = grep { m{\A$base\.} } readdir($D);
  closedir $D;
  @hits = sort(@hits);

  foreach my $file (@hits) {
    if (not exists $::app->{main}->{Watcher}->{seen}->{$file}) {
      $::app->{main}->{Watcher}->{$file} = -s File::Spec->catfile($timer->{dir}, $file);
      print "process $file\n";
    };
  };
};

1;
