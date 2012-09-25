package MooseX::Quenchable;

{
  $MooseX::Quenchable::VERSION = '0.9.12';
}
use Moose::Role 0.90;
use MooseX::Aliases;
has 'quenched'    => (is => 'rw', isa => 'Bool',   default => 0, alias=>'frozen');



package MooseX::Quenchable::Attribute;
{
  $MooseX::Quenchable::Attribute::VERSION = '0.9.12';
}
use Moose::Role 0.90;



before set_value => sub { return if $_[0]->_ensure_fluid($_[1]) };



around _inline_set_value => sub {
  my $orig = shift;
  my $self = shift;
  my ($instance) = @_;


  my @source = $self->$orig(@_);
  return (
    'return if Class::MOP::class_of(' . $instance . ')->find_attribute_by_name(',
      '\'' . quotemeta($self->name) . '\'',
    ')->_ensure_fluid(' . $instance . ');',
    @source,
  );
} if $Moose::VERSION >= 1.9900;

sub _ensure_fluid {
  my ($self, $instance) = @_;
  $instance->quenched;
}

around accessor_metaclass => sub {
  my ($orig, $self, @rest) = @_;

  return Moose::Meta::Class->create_anon_class(
    superclasses => [ $self->$orig(@_) ],
    roles => [ 'MooseX::Quenchable::Accessor' ],
    cache => 1
  )->name
} if $Moose::VERSION < 1.9900;

package MooseX::Quenchable::Accessor;
{
  $MooseX::Quenchable::Accessor::VERSION = '0.9.12';
}
use Moose::Role 0.90;

around _inline_store => sub {
  my ($orig, $self, $instance, $value) = @_;

  my $code = $self->$orig($instance, $value);
  $code = sprintf qq[%s->meta->find_attribute_by_name("%s")->_ensure_fluid(%s);\n%s],
    $instance,
    quotemeta($self->associated_attribute->name),
    $instance,
    $code;

  return $code;
};

package Moose::Meta::Attribute::Custom::Trait::Quenchable;
{
  $Moose::Meta::Attribute::Custom::Trait::Quenchable::VERSION = '0.9.12';
}
sub register_implementation { 'MooseX::Quenchable::Attribute' }

1;

__END__


=head1 NAME

MooseX::Quenchable - silently freeze attribute values

=head1 VERSION

This documentation refers to Demeter version 0.9.12.

=head1 SYNOPSIS

Add the "Quenchable" trait to attributes:

  package Class;
  use Moose;
  use MooseX::Quenchable;

  has some_attr => (
    is     => 'rw',
    traits => [ qw(Quenchable) ],
  );

...and then you can silently disable changes to that attribute.

  my $object = Class->new;

  $object->quenched(0)
  $object->some_attr(10);  # as expected, some_attr = 10
  $object->quenched(1)
  $object->some_attr(20);  # silently refuses the change, some_attr = 10
  $object->quenched(0)
  $object->some_attr(20);  # es expected, some_attr = 20

=head1 DESCRIPTION

The 'Quenchable' attribute lets your class have attributes that can
have setting silently disabled.

This is an example of cargo-cult programming.  It was swiped
shamelessly from MooseX::SetOnce by Ricardo SIGNES <rjbs@cpan.org> and
slightly modified.

This does not override an attribute's clearer, so there is a way to
defeat the intent of quenching the object.

=head1 BUGS AND LIMITATIONS

Please report problems to Bruce Ravel (bravel AT bnl DOT gov)

Patches are welcome.

=head1 AUTHOR

Bruce Ravel (bravel AT bnl DOT gov)

http://cars9.uchicago.edu/~ravel/software/

=head1 LICENCE AND COPYRIGHT

L<MooseX::SetOnce> carries this copyright notice:

  This software is copyright (c) 2011 by Ricardo SIGNES.

  This is free software; you can redistribute it and/or modify it
  under the same terms as the Perl 5 programming language system
  itself.

Copyright (c) 2012 Bruce Ravel (bravel AT bnl DOT gov). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
