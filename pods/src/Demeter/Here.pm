package Demeter::Here;
sub here {return substr($INC{'Demeter/Here.pm'}, 0, -7)};
1;

=head1 NAME

Demeter::Here - A compile-time tool

=head1 VERSION

This documentation refers to Demeter version 0.9.19.

=head1 SYNOPSIS

This small module identifies the installation location of Demeter for
use in the BEGIN block of a GUI application.  It is currently used to
post a splashscreen during start-up.

=head1 AUTHOR

Bruce Ravel (bravel AT bnl DOT gov)

L<http://bruceravel.github.com/demeter/>

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2014 Bruce Ravel (bravel AT bnl DOT gov). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut


