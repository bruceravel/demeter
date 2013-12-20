package Demeter::IniReader;
use parent qw(Config::INI::Reader);
sub can_ignore {
  my ($self, $line) = @_;

  # Skip comments and empty lines
  return $line =~ /\A\s*(?:[;\#]|$)/ ? 1 : 0;
}
sub preprocess_line {
  my ($self, $line) = @_;

  # Remove inline comments
  ${$line} =~ s/\s+;.*$//g;
  ${$line} =~ s/\s+\#(?![0-9a-fA-F]+).*$//g;
}
1;

=head1 NAME

Demeter::IniReader -- Ini file parser for Demeter

=head1 VERSION

This documentation refers to Demeter version 0.9.18.

=head1 SYNOPSIS

This inherits from L<Config::INI::Reader>, changing the definition of
a comment line to include a line begining with a hash caharacter.
Also change the definition of an end-of-line comment the same way,
taking care not to remove an RGB color value of the form C<#0000FF>.

=head1 ACKNOWELDGEMENT

L<Config::INI::Reader> was written by Ricardo Signes <rjbs@cpan.org>.
This is just a thin wrapper around that module.

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
