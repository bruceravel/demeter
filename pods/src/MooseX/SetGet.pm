package MooseX::SetGet;
use Moose::Role;
use Carp;

## This is swiped verbatim from MooseX::MutatorAttributes
sub set {
  my ($self, %opts) = @_;
  while ( my ($name, $value) = each %opts ) {
    croak sprintf q{[!!!] %s is not an attribute to set for %s}, $name, $self
      unless defined $self->meta->find_attribute_by_name($name);

    my $setter = $self->meta->find_attribute_by_name($name)->get_write_method;
    croak sprintf q{[!!!] %s is not writable, no setter defined}, $name
      unless defined $setter;

    $self->$setter($value);
  };
  return $self;
};

## and this is modeled off set from MooseX::MutatorAttributes
sub get {
  my ($self, @opts) = @_;
  my @list;
  foreach my $o (@opts) {
    croak sprintf q{[!!!] %s is not an attribute to get for %s}, $o, $self
      unless defined $self->meta->find_attribute_by_name($o);

    my $reader = $self->meta->find_attribute_by_name($o)->get_read_method;
    croak sprintf q{[!!!] %s is not readable, no reader defined}, $o
      unless defined $reader;

    push @list, $self->$reader;
  };
  return wantarray ? @list : $list[0];
};

1;

=head1 NAME

MooseX::SetGet - Moose Role to add a quick set and get methods

=head1 VERSION

This documentation refers to Demeter version 0.9.25.

=head1 SYNOPSIS

This swipes the C<set> method from L<MooseX::MutatorAttributes> and
adds a get method.  Like the C<set> from MooseX::MutatorAttributes,
this one returns self.  The C<get> method will return a scalar or an
array.

    with qw{MooseX::MutatorAttributes};
    $obj->set( attr1 => $value1, attr2 => $value2 )->method_that_uses_attr;
    $value  = $obj->get('attr1');
    @values = $obj->get(qw(attr1 attr2));

=head1 METHODS

=head2 set

    $self->set( HASH );

This takes a hash, keys are expected to be attributes, if they are not
then we Carp::croak. If a key is an acceptable attribute then we
attempt to set with $value.

=head2 get

    $value  = $self->get("attribute");
    @values = $self->get(@attributes);

This takes a list of one or more attributes and returns either a
scalar or an array containing the values associated with the
attributes.

=head1 ACKNOWLEDGEMENTS

C<set> was swiped from L<MooseX::MutatorAttributes> by ben hengst,
C<&lt;notbenh at cpan.org&gt;>.  C<get> was based closely upon C<set>.

=head1 BUGS AND LIMITATIONS

Please report problems to the Ifeffit Mailing List
(L<http://cars9.uchicago.edu/mailman/listinfo/ifeffit/>)

Patches are welcome.

=head1 AUTHOR

Bruce Ravel (L<http://bruceravel.github.io/home>)

http://bruceravel.github.io/demeter/


=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2016 Bruce Ravel (L<http://bruceravel.github.io/home>). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
