#!/usr/bin/env perl
BEGIN {
  # turn off Unity feature of the Mac-like global menu bar, which
  # interacts really poorly with Wx.  See
  # http://www.webupd8.org/2011/03/disable-appmenu-global-menu-in-ubuntu.html
  $ENV{UBUNTU_MENUPROXY} = 0;
  use Demeter::Here;
  use Wx::Perl::SplashFast Demeter::Here->here.'UI/Athena/share/logo.jpg', 4000;
  ## munge the PATH env. var. under Windows, also add useful debugging
  ## info to the log file
  if (($^O eq 'MSWin32') or ($^O eq 'cygwin')) {
    require Win32;
    my @now = localtime(time);
    printf STDOUT "Started at %d-%2.2d-%2.2dT%2.2d:%2.2d:%2.2d$/", $now[5]+1900, $now[4]+1, reverse(@now[0..3]);
    print  STDOUT Win32::GetOSName(), "\t", Win32::GetOSVersion, $/, $/;
    print  STDOUT "PATH is:$/\t$ENV{PATH}$/";
    print  STDOUT "DEMETER_BASE is:$/\t$ENV{DEMETER_BASE}$/";
    print  STDOUT "IFEFFIT_DIR is:$/\t$ENV{IFEFFIT_DIR}$/$/";
    print  STDOUT "perl version: $^V$/";
    my $backend = $ENV{DEMETER_BACKEND} || 'ifeffit';
    print  STDOUT "backend: $backend$/$/";
    print  STDOUT "\@INC:$/\t" . join("$/\t", @INC) . "$/";
  };
};
use Wx;
#Wx::InitAllImageHandlers();
use Demeter::UI::Athena;
use vars qw($app);
$app  = Demeter::UI::Athena->new;
$app -> process_argv(@ARGV);
$app -> MainLoop;

=head1 NAME

athena - XAS data processing

=head1 VERSION

This documentation refers to Demeter version 0.9.25.

=head1 DESCRIPTION

Athena is a graphical interface to Ifeffit for XAS data processing.

=head1 COMMAND LINE SWITCHES

=over 4

=item C<-#>

Immediately import the #-th item from the MRU list

=back

=head1 AUTHOR

Bruce Ravel (L<http://bruceravel.github.io/home>)

http://bruceravel.github.io/demeter/


=head1 LICENCE AND COPYRIGHT

Copyright (c) 2008-2016 Bruce Ravel (L<http://bruceravel.github.io/home>). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
