package Ifeffit::Demeter::Fit::Spinner;

=for Copyright
 .
 Copyright (c) 2006-2008 Bruce Ravel (bravel AT bnl DOT gov).
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

use Moose::Role;

use Term::Twiddle;

my $spinner = new Term::Twiddle;
$spinner->rate(0.05);
$spinner->thingy( [
		   '   -+-   ',
		   '   [ ]   ',
		   '  [   ]  ',
		   ' [     ] ',
		   '[       ]',
		   ' [     ] ',
		   '  [   ]  ',
		   '   [ ]  ',
		   '   -+-   ',
		  ] );


sub start_spinner {
  my ($self, $text) = @_;
  $text ||= 'Demeter is thinking ';
  print $text, " ";
  $spinner->start;
};
sub stop_spinner {
  my ($self) = @_;
  $spinner->stop;
  print $/;
};

1;

=head1 NAME

Ifeffit::Demeter::Fit::Spinner - On screen indicator for lengthy operations

=head1 VERSION

This documentation refers to Ifeffit::Demeter version 0.2.

=head1 SYNOPSIS

   $fitobject->start_spinner("Demeter is performing a fit");
    ...
   $fitobject->stop_spinner;

=head1 DESCRIPTION

This role for a Demeter object provides

=head1 CONFIGURATION AND ENVIRONMENT

See L<Ifeffit::Demeter::Config> for a description of the configuration
system.  See the warnings configuration group.

=head1 DEPENDENCIES

Demeter's dependencies are in the F<Bundle/DemeterBundle.pm> file.

=head1 BUGS AND LIMITATIONS

Please report problems to Bruce Ravel (bravel AT bnl DOT gov)

Patches are welcome.

=head1 AUTHOR

Bruce Ravel (bravel AT bnl DOT gov)

L<http://cars9.uchicago.edu/~ravel/software/>


=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2008 Bruce Ravel (bravel AT bnl DOT gov). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
