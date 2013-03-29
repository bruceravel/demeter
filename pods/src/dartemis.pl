#!/usr/bin/perl
BEGIN {
  # turn off Unity feature of the Mac-like global menu bar, which
  # interacts really poorly with Wx.  See
  # http://www.webupd8.org/2011/03/disable-appmenu-global-menu-in-ubuntu.html
  $ENV{UBUNTU_MENUPROXY} = 0;
  use Demeter::Here;
  use Wx::Perl::SplashFast Demeter::Here->here.'UI/Artemis/share/temple-logo.jpg',4000;
  ## munge the PATH env. var. under Windows, also add useful debugging
  ## info to the log file
  if (($^O eq 'MSWin32') or ($^O eq 'cygwin')) {
    require Win32;
    my @now = localtime(time);
    printf STDOUT "Started at %d-%2.2d-%2.2dT%2.2d:%2.2d:%2.2d$/", $now[5]+1900, $now[4]+1, reverse(@now[0..3]);
    print STDOUT Win32::GetOSName(), "\t", Win32::GetOSVersion, $/, $/;
    print STDOUT "PATH:$/\t$ENV{PATH}$/$/";
    if ($ENV{PATH} =~ m{mingw}i) {
      my @list = split(/;/, $ENV{PATH});
      my (@mingw, @not);
      foreach my $p (@list) {
	if ($p =~ m{mingw}i) {push @mingw, $p} else {push @not, $p};
      };
      $ENV{PATH} = join(';', @not, @mingw);
      print "PATH (reordered):$/\t$ENV{PATH}$/$/";
    };
    print STDOUT "perl version: $^V$/$/";
    print STDOUT "\@INC:$/\t" . join("$/\t", @INC) . "$/$/";
  };
};
use Wx;
use Demeter::UI::Artemis;
Wx::InitAllImageHandlers();
use vars qw($app);
$app = Demeter::UI::Artemis->new;
$app -> process_argv(@ARGV);
$app -> MainLoop;

=head1 NAME

artemis - EXAFS data analysis

=head1 VERSION

This documentation refers to Demeter version 0.9.16.

=head1 DESCRIPTION

Artemis is a graphical interface to Feff and Ifeffit.

=head1 AUTHOR

Bruce Ravel (bravel AT bnl DOT gov)

http://bruceravel.github.com/demeter/


=head1 LICENCE AND COPYRIGHT

Copyright (c) 2008-2013 Bruce Ravel (bravel AT bnl DOT gov). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
