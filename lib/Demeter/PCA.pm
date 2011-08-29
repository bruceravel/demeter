package Demeter::PCA;

=for Copyright
 .
 Copyright (c) 2006-2011 Bruce Ravel (bravel AT bnl DOT gov).
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

use Carp;
#use Demeter::Carp;
use autodie qw(open close);

use Moose;
use Moose::Util qw(apply_all_roles);
use Moose::Util::TypeConstraints;
extends 'Demeter';
with 'Demeter::Data::Arrays';
use Demeter::StrTypes qw( Empty );

#use PDL;
use PDL::Stats::GLM;

with 'Demeter::PCA::Xanes';

if ($Demeter::mode->ui eq 'screen') {
  with 'Demeter::UI::Screen::Pause';
  with 'Demeter::UI::Screen::Progress';
};

has '+plottable'  => (default => 1);
has '+name'       => (default => 'PCA' );

has 'xmin'  => (is => 'rw', isa => 'Num',    default => 0);
has 'xmax'  => (is => 'rw', isa => 'Num',    default => 0);

enum 'PCASpaces' => [qw(e x d c k)];
coerce 'PCASpaces',
  from 'Str',
  via { lc($_) };
has space => (is => 'rw', isa => 'PCASpaces', coerce => 1,
	      trigger => sub{my ($self, $new) = @_;
			     if ($new =~ m{[xe]}) {
			       eval {apply_all_roles($self, 'Demeter::PCA::Xanes')};
			       $@ and die("Histogram backend Demeter::PCA::Xanes could not be loaded");
			     } elsif ($new eq 'd') {
			       eval {apply_all_roles($self, 'Demeter::PCA::Deriv')};
			       print $@;
			       $@ and die("Histogram backend Demeter::PCA::Deriv does not exist");
			     } elsif ($new =~ m{[ck]}) {
			       eval {apply_all_roles($self, 'Demeter::PCA::Chi')};
			       print $@;
			       $@ and die("Histogram backend Demeter::PCA::Chi does not exist");
			     };
			   });

has '_pdl' => (is => 'rw', isa => Empty.'|Demeter::Data', );

has 'ndata' => (is => 'rw', isa => 'Int', default => 0);
has 'stack' => (
		metaclass => 'Collection::Array',
		is        => 'rw',
		isa       => 'ArrayRef[Demeter::Data]',
		default   => sub { [] },
		provides  => {
			      'push'    => 'push_stack',
			      'pop'     => 'pop_stack',
			      'shift'   => 'shift_stack',
			      'unshift' => 'unshift_stack',
			      'clear'   => 'clear_stack',
			     },
	       );

has 'eignevalues'  => (is => 'rw', isa => 'ArrayRef', default => sub{[]});
has 'eignevectors' => (is => 'rw', isa => 'ArrayRef[ArrayRef]', default => sub{[]});
has 'loadings'     => (is => 'rw', isa => 'ArrayRef[ArrayRef]', default => sub{[]});
has 'pct_var'      => (is => 'rw', isa => 'ArrayRef', default => sub{[]});

sub add {
  my ($self, @groups) = @_;
  foreach my $g (@groups) {
    next if (ref($g) !~ m{Data\z});
    $self->push_stack($g);
  };
};

1;
