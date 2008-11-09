package Xray::Crystal;

sub import {
  foreach my $package (qw(Xray/Crystal/Cell Xray/Crystal/Site)) {
    next if $INC{$package};
    require "$package.pm";
  };
};

1;
__END__

=head1 NAME

Xray::Crystal - A crystallography wrapper

=head1 VERSION

This documentation refers to Demeter version 0.2.

=head1 SYNOPSIS

This imports Xray::Crystal::Cell and Xray::Crystal::Site.

=head1 DESCRIPTION


=head1 CONFIGURATION AND ENVIRONMENT


=head1 DEPENDENCIES


=head1 BUGS AND LIMITATIONS

Please report problems to Bruce Ravel (bravel AT bnl DOT gov)

Patches are welcome.

=head1 AUTHOR

Bruce Ravel (bravel AT bnl DOT gov)

http://cars9.uchicago.edu/~ravel/software/


=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2008 Bruce Ravel (bravel AT bnl DOT gov). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
