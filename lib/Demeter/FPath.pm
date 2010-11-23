package Demeter::FPath;

=for Copyright
 .
 Copyright (c) 2006-2010 Bruce Ravel (bravel AT bnl DOT gov).
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
#use MooseX::StrictConstructor;
extends 'Demeter::Path';
use Demeter::NumTypes qw( Ipot PosNum PosInt );
use Demeter::StrTypes qw( Empty ElementSymbol );

with 'Demeter::UI::Screen::Pause' if ($Demeter::mode->ui eq 'screen');

use Chemistry::Elements qw(get_symbol get_Z);
use String::Random qw(random_string);

has 'reff'	 => (is => 'rw', isa => 'Num',    default => 0.1,
		     trigger  => sub{ my ($self, $new) = @_; $self->fuzzy($new);} );
has 'fuzzy'	 => (is => 'rw', isa => 'Num',    default => 0.1);
has '+n'	 => (default => 1);
has 'weight'	 => (is => 'ro', isa => 'Int',    default => 2);
has 'Type'	 => (is => 'ro', isa => 'Str',    default => 'filtered scattering path');
has 'string'	 => (is => 'ro', isa => 'Str',    default => q{});
has 'tag'	 => (is => 'rw', isa => 'Str',    default => q{});
has 'randstring' => (is => 'rw', isa => 'Str',    default => sub{random_string('ccccccccc').'.sp'});

has 'kgrid'      => (is => 'rw', isa => 'ArrayRef',
		     default => sub{
		       [.000 , .100 , .200 , .300 , .400 , .500 , .600 , .700 , .800 , .900 ,
			1.000 , 1.100 , 1.200 , 1.300 , 1.400 , 1.500 , 1.600 , 1.700 , 1.800 ,
			1.900 , 2.000 , 2.200 , 2.400 , 2.600 , 2.800 , 3.000 , 3.200 , 3.400 ,
			3.600 , 3.800 , 4.000 , 4.200 , 4.400 , 4.600 , 4.800 , 5.000 , 5.200 ,
			5.400 , 5.600 , 5.800 , 6.000 , 6.500 , 7.000 , 7.500 , 8.000 , 8.500 ,
			9.000 , 9.500 , 10.000 , 11.000 , 12.000 , 13.000 , 14.000 , 15.000 ,
			16.000 , 17.000 , 18.000 , 19.000 , 20.000 ]
		     });
has 'chi'        => (is => 'rw', isa => 'ArrayRef', default => sub{ [] });

has 'absorber'	   => (is => 'rw', isa => ElementSymbol, default => q{Fe},
		       trigger => sub{ my ($self, $new) = @_;
				       $self->abs_z(get_Z($new));
				     } );
has 'scattering'   => (is => 'rw', isa => ElementSymbol, default => q{O},
		       trigger => sub{ my ($self, $new) = @_;
				       $self->scat_z(get_Z($new));
				     } );
has 'abs_z'	 => (is => 'rw', isa => 'Int',    default => 0);
has 'scat_z'	 => (is => 'rw', isa => 'Int',    default => 0);

has 'kmin'	 => (is => 'rw', isa => 'Num',    default =>  0.0);
has 'kmax'	 => (is => 'rw', isa => 'Num',    default => 20.0);
has 'rmin'	 => (is => 'rw', isa => 'Num',    default =>  0.0);
has 'rmax'	 => (is => 'rw', isa => 'Num',    default => 31.0);

## the sp attribute must be set to this FPath object so that the Path
## _update_from_ScatteringPath method can be used to generate the
## feffNNNN.dat file.  an ugly but functional bit of voodoo
sub BUILD {
  my ($self, @params) = @_;
  $self->sp($self);
  $self->mo->push_FPath($self);
};

override alldone => sub {
  my ($self) = @_;
  my $nnnn = File::Spec->catfile($self->folder, $self->randstring);
  unlink $nnnn if (-e $nnnn);
  $self->remove;
  return $self;
};

## construct the intrp line by disentangling the SP string
sub intrplist {
  q{};
};

1;
