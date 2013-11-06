package Xray::Crystal;
use strict;
use warnings;

sub import {
  strict->import;
  warnings->import;

  foreach my $p (qw(SpaceGroup Cell Site)) {
    next if $INC{"Xray/Crystal/$p.pm"};
    #print "Xray/Crystal/$p.pm\n";
    require "Xray/Crystal/$p.pm";
  };
};

1;
__END__

=head1 NAME

Xray::Crystal - A crystallography wrapper

=head1 VERSION

This documentation refers to Demeter version 0.9.18.

=head1 SYNOPSIS

This imports L<Xray::Crystal::SpaceGroup>, L<Xray::Crystal::Cell> and
L<Xray::Crystal::Site> into your program.  It also imports L<strict>
and L<warnings> into your program.

  use Xray::Crystal;
  my $sg   = Xray::Crystal::SpaceGroup->new;
  my $cell = Xray::Crystal::Cell->new;
  my $site = Xray::Crystal::Site->new;


=head1 DESCRIPTION


=head1 CONFIGURATION AND ENVIRONMENT


=head1 DEPENDENCIES


=head1 BUGS AND LIMITATIONS

Please report problems to the Ifeffit Mailing List
(http://cars9.uchicago.edu/mailman/listinfo/ifeffit/)

Patches are welcome.

=head1 AUTHOR

Bruce Ravel (bravel AT bnl DOT gov)

http://bruceravel.github.com/demeter/


=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2013 Bruce Ravel (bravel AT bnl DOT gov). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
