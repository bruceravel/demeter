package Demeter::IniWriter;
use parent qw(Config::INI::Writer);

sub write_handle {
  my ($invocant, $input, $handle) = @_;
  binmode $handle, ":encoding(UTF-8)"; # avoid triggering the wide character warning

  my $self = ref $invocant ? $invocant : $invocant->new;

  $input = $self->preprocess_input($input);

  $self->validate_input($input);

  my $starting_section_name = $self->starting_section;

  SECTION: for (my $i = 0; $i < $#$input; $i += 2) {
    my ($section_name, $section_data) = @$input[ $i, $i + 1 ];

    $self->change_section($section_name);
    $handle->print($self->stringify_section($section_data))
      or Carp::croak "error writing section $section_name: $!";
    $self->finish_section;
  }
}

1;

=head1 NAME

Demeter::IniWriter -- Ini file writer for Demeter

=head1 VERSION

This documentation refers to Demeter version 0.9.16.

=head1 SYNOPSIS

This inherits from L<Config::INI::Writer>, changing the
C<write_handle> method to allow for saving items to the mru lists that
contain UTF-8 path and filenames without triggering the "wide
character" warning.

=head1 ACKNOWELDGEMENT

L<Config::INI::Writer> was written by Ricardo Signes <rjbs@cpan.org>.
This is just a thin wrapper around that module.

=head1 AUTHOR

Bruce Ravel (bravel AT bnl DOT gov)

L<http://bruceravel.github.com/demeter/>

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2013 Bruce Ravel (bravel AT bnl DOT gov). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
