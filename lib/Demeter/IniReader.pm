package Demeter::IniReader;
use parent qw(Config::INI::Reader);

my %filename_hash = ();

sub read_file {
  my ($self, $file) = @_;
  my $foo = $self->SUPER::read_file($file);
  $Demeter::__reading_ini = $file;
  return $foo;
};

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

sub handle_unparsed_line {
  my ($self, $line, $handle) = @_;
  my $lineno = $handle->input_line_number;
  {
    local $Carp::Verbose = 0;
    Carp::carp "Could not read INI file at line $lineno of\n".$Demeter::__reading_ini."\n\n";
  };
}


1;

=head1 NAME

Demeter::IniReader -- Ini file parser for Demeter

=head1 VERSION

This documentation refers to Demeter version 0.9.21.

=head1 SYNOPSIS

This inherits from L<Config::INI::Reader>, changing the definition of
a comment line to include a line begining with a hash character.
Also change the definition of an end-of-line comment the same way,
taking care not to remove an RGB color value of the form C<#0000FF>.

It also calls carp rather than croak for an unparsed line, using a
Demeter-specific global scalar (ick, but the best I could think of) to
structure the error message.

=head1 ACKNOWELDGEMENT

L<Config::INI::Reader> was written by Ricardo Signes <rjbs@cpan.org>.
This is just a thin wrapper around that module.

=head1 AUTHOR

Bruce Ravel, L<http://bruceravel.github.io/home>

L<http://bruceravel.github.io/demeter/>

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2015 Bruce Ravel (http://bruceravel.github.io/home). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
