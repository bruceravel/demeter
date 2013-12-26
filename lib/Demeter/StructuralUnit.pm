package Demeter::StructuralUnit;

=for Copyright
 .
 Copyright (c) 2006-2014 Bruce Ravel (bravel AT bnl DOT gov).
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
extends 'Demeter::VPath';
use Demeter::StrTypes qw( Empty );

use String::Random qw(random_string);


has '+name'      => (default => 'structural unit',);
		     #trigger => sub{my($self, $new) = @_; $self->vpath->name($new)} );
has '+id'        => (default => 'virtual path');
has 'tag'        => (is => 'rw', isa => 'Str', default => sub{random_string('ccc')});

has 'feffs' => (
		traits    => ['Array'],
		is        => 'rw',
		isa       => 'ArrayRef[Demeter::Feff]',
		default   => sub { [] },
		handles   => {
			      'push_feffs'    => 'push',
			      'pop_feffs'     => 'pop',
			      'shift_feffs'   => 'shift',
			      'unshift_feffs' => 'unshift',
			      'clear_feffs'   => 'clear',
			     }
	       );
has 'gds' => (
	      traits    => ['Array'],
	      is        => 'rw',
	      isa       => 'ArrayRef[Demeter::GDS]',
	      default   => sub { [] },
	      handles   => {
			    'push_gds'    => 'push',
			    'pop_gds'     => 'pop',
			    'shift_gds'   => 'shift',
			    'unshift_gds' => 'unshift',
			    'clear_gds'   => 'clear',
			   }
	     );


sub BUILD {
  my ($self, @params) = @_;
  $self->mo->push_StructuralUnit($self);
};


after clear => sub {
  my ($self) = @_;
  $self->clear_feffs;
  $self->clear_gds;
  return $self;
};



override serialize => sub {
  my ($self, $fname) = @_;
  ## 1. gather up all the Path object in the SU
  ## 2. dig through and find all Feff objects
  ## 3. Dig through and find all GDS objects
  ## 4. Make yamls of everything and zip them up with phase.bin files in a zip file with .dsu extension
  return $self;
};

override deserialize => sub {
  my ($self, $fname) = @_;
  ## unpack everything, instantiate objects, fill up SU attributes.
  return $self;
};


__PACKAGE__->meta->make_immutable;
1;

=head1 NAME

Demeter::StructuralUnit - Structural units for use in fitting projects

=head1 VERSION

This documentation refers to Demeter version 0.9.19.

=head1 SYNOPSIS

Gather together the information required to define a structural units
for use in a fit.

=head1 DESCRIPTION

This is a bit challenging to use in a script -- much easier to use in a GUI.

=head1 ATTRIBUTES

=head1 METHODS

=head1 SERIALIZATION AND DESERIALIZATION

Zip file with yamls and phase.bin files with .dsu extension.

=head1 CONFIGURATION AND ENVIRONMENT

See L<Demeter::Config> for a description of the configuration system.

=head1 DEPENDENCIES

Demeter's dependencies are in the F<Build.PL> file.

=head1 BUGS AND LIMITATIONS

Please report problems to the Ifeffit Mailing List
(L<http://cars9.uchicago.edu/mailman/listinfo/ifeffit/>)

Patches are welcome.

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

