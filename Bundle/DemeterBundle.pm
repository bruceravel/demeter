package Bundle::DemeterBundle;
use strict;
use vars qw($VERSION);
$VERSION = '0.01';

1;

__END__

=head1 NAME

Bundle::DemeterBundle - All of Demeter's dependencies

=head1 SYNOPSIS

  perl -MCPAN -e 'install Bundle::DemeterBundle'

or, as one way of handling problems,

  perl -MCPAN -e 'force install Bundle::DemeterBundle'

Answer yes to any question posed by any package.  The YAML package
will certanly ask several, as will Tree::Simple.

=head1 CONTENTS

Digest::SHA

version

Module::Build

aliased

Archive::Zip

Chemistry::Elements

Class::Std

Class::Std::Utils

Compress::Zlib

Compress::Raw::Zlib

Config::IniFiles

Heap

Want

Graphics::GnuplotIF

IO::Prompt

List::MoreUtils

Math::Cephes

Math::Derivative

Math::Round

Math::Spline

Module::Build

Readonly

Regexp::Common

Regexp::Optimizer

Smart::Comments

Term::ANSIColor

Text::Template

Text::Wrap

Tree::Simple

YAML

Term::Twiddle

=head1 DESCRIPTION

This file provides a convenient way of using perl's CPAN module to meet
all of Demeter's prerequisites.  The procedure I describe here
presumes that you have internet access, that you can become root on
your machine, and that you have already configured CPAN to to install
new modules on your computer.  If you cannot meet those requirements,
you will have to install all of these modules in some other way.  Some
options are described below.

To install the prerequisites using this file:

=over 4

=item 1.

Become root.

=item 2.

Fire up CPAN with this command:

  perl -MCPAN -e shell

=item 3.

Issue this command at the C<cpanE<gt>> prompt:

  install Bundle::DemeterBundle

=item 4.

Be patient, make yourself comfortable, and answer "yes" everytime
you're asked a yes/no question.

=back

If all goes well, all of Demeter's prerequisites will be installed.
If you cannot use this method for some reason, here are some options:

=over 4

=item *

Download each module by hand and install using the standard C<perl
Makefile.PL; make; make install> incantation.

=item *

Some of these modules might be available as packages for your OS.  For
instance, several of them exist as Debian packages.

=item *

You can actually configure and use the CPAN module as a normal user.
You don't have to be root.  In that case, you will need to copy this
file into the C<~/.cpan/Bundle> after you have configured CPAN for use
as a normal user.

=back

See http://perldoc.perl.org/CPAN.html#Bundles for more details.

=head1 AUTHOR

Bruce Ravel <bravel AT bnl DOT gov>

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2007 Bruce Ravel (bravel AT bnl DOT gov). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
