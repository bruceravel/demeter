#!/usr/bin/env perl

=for Copyright
 .
 Copyright (c) 2008-2016 Bruce Ravel (L<http://bruceravel.github.io/home>).
 All rights reserved.
 .
 This file is free software; you can redistribute it and/or
 modify it under the same terms as Perl itself. See The Perl
 Artistic License.
 .
 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut

use Getopt::Long;
my $wx = 0;
my $result = GetOptions ("wx" => \$wx,);

use Demeter qw(:none);
use PDL;
use PDL::Stats;
print Demeter->new->module_environment;
print Demeter->new->wx_environment if ($wx);


=head1 NAME

denv - Display Demeter's operating environment

=head1 VERSION

This documentation refers to Demeter version 0.9.25.

=head1 DESCRIPTION

This simple tool calls the C<module_environment> method and prints
it's output to the screen.  It's sole purpose in life is as a
diagnostic tool for understanding the environment in which Demeter is
running.

=head1 OPTIONS

=over 4

=item C<--wx>

Append information about Wx and WxPerl to the report.

=back

=head1 AUTHOR

Bruce Ravel (L<http://bruceravel.github.io/home>)

http://bruceravel.github.io/demeter/


=head1 LICENCE AND COPYRIGHT

Copyright (c) 2008-2009 Bruce Ravel (L<http://bruceravel.github.io/home>). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
