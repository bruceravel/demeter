package Demeter::SSPath;

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

use Moose;
extends 'Demeter::Path';
use Demeter::NumTypes qw( Ipot PosNum );

use Chemistry::Elements qw(get_symbol);

has 'ipot'   => (is => 'rw', isa => 'Ipot',   default => 0);
has 'reff'   => (is => 'rw', isa => 'PosNum', default => 0.1);
has '+n'     => (default => 1);
has 'weight' => (is => 'ro', isa => 'Int',    default => 2);
has 'Type'   => (is => 'ro', isa => 'Str',    default => 'arbitrary single scattering');
has 'tag'    => (is => 'rw', isa => 'Str',    default => q{});
#  has '+parent' => (trigger => sub{ my($self, $new) = @_; 
# 				  $self->parentgroup($new->group) if $new;
# 				  my @ipots  = @{ $self->parent->potentials };
# 				  my $tag    = $ipots[$self->ipot]->[2] || get_symbol($ipots[$self->ipot]->[1]);
# 				});

sub BUILD {
  my ($self, @params) = @_;
  $self->mo->push_SSPath($self);
};

## construct the intrp line by disentangling the SP string
sub intrplist {
  my ($self) = @_;
  my $token  = $self->co->default("pathfinder", "token") || '<+>';
  my $string = sprintf("%s %-6s %s", $token, $self->tag, $token);
  return join(" ", $string);
};

sub intrpline {
  my ($self, $i) = @_;
  $i ||= 9999;
  return sprintf " %4.4d  %2d   %6.3f  ----  %-29s       %2d  %d %s",
    $i, $self->n, $self->reff, $self->intrplist, $self->weight, , $self->nleg , $self->Type;
};

sub pathsdat {
  my ($self, @arguments) = @_;
  my %args = @arguments;
  $args{index}  ||= 1;
  $args{string} ||= $self -> string;
  $self -> randstring(random_string('ccccccccc').'.sp') if ($self->randstring =~ m{\A\s*\z});

  my $feff = $self->parent;
  my @sites = @{ $feff->sites };
  my $pd = q{};

  $pd .= sprintf("  %4d    %d  %6.3f  index, nleg, degeneracy, r= %.4f\n",
		 $args{index}, $self->get(qw(nleg n fuzzy)) );
  $pd .= "      x           y           z     ipot  label";
  $pd .= "      rleg      beta        eta" if ($args{angles});
  $pd .= "\n";
  $pd .= sprintf(" %11.6f %11.6f %11.6f   %d '%-6s'\n", 0, 0, $self->reff, $self->ipot, $self->tag);
  $pd .= sprintf(" %11.6f %11.6f %11.6f   %d '%-6s'\n", $feff->central, 0, 'abs');
  return $pd;
};


__PACKAGE__->meta->make_immutable;
1;


=head1 NAME

Demeter::SSPath - Arbitrary single scattering paths

=head1 VERSION

This documentation refers to Demeter version 0.2.

=head1 SYNOPSIS

Build a single scattering path of arbitrary length from the potentials
of a Feff calculation:

  my $sspath = Demeter::SSPath->new(feff => $feff_object,
                                    name => "my SS path",
                                    ipot => 3,
                                    reff => 3.2,
                                   );
  $sspath -> plot('R');

=head1 DESCRIPTION


=head1 ATTRIBUTES

Along with the standard attributes of a Demeter object (C<name>,
C<plottable>, C<data>, and so on), a VPath has the following:

You B<must> specify a Feff object!

=over 4

=item C<ipot>

=item C<reff>

=back

=head1 METHODS

=over 4

=item C<pathsdat>

=back

=head1 SERIALIZATION AND DESERIALIZATION

Good question ...

=head1 CONFIGURATION AND ENVIRONMENT

See L<Demeter::Config> for a description of the configuration system.

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

