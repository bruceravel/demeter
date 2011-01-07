package Demeter::ThreeBody;

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

use Moose;
#use MooseX::StrictConstructor;
extends 'Demeter::Path';
use Demeter::NumTypes qw( Ipot PosNum PosInt );
use Demeter::StrTypes qw( Empty );
use MooseX::Aliases;

with 'Demeter::UI::Screen::Pause' if ($Demeter::mode->ui eq 'screen');

use File::Copy;
use File::Spec;
use String::Random qw(random_string);

has 'Type'	 => (is => 'ro', isa => 'Str',    default => 'three body scattering');
has 'string'	 => (is => 'ro', isa => 'Str',    default => q{});
has 'tag'	 => (is => 'rw', isa => 'Str',    default => q{});
has 'randstring' => (is => 'rw', isa => 'Str',    default => sub{random_string('ccccccccc').'.sp'}, alias => 'dsstring');
has 'tsstring'   => (is => 'rw', isa => 'Str',    default => sub{random_string('ccccccccc').'.sp'});
has 'fuzzy'	 => (is => 'rw', isa => 'Num',    default => 0.1);
has 'weight'	 => (is => 'ro', isa => 'Int',    default => 2);

has 'halflength' => (is => 'rw', isa => 'Num',    default => 0);
has 'beta'       => (is => 'rw', isa => 'Num',    default => 0, alias => 'angle');
has 'ipot1'      => (is => 'rw', isa =>  Ipot,    default => 0, documentation => 'the ipot of the nearer atom');
has 'ipot2'      => (is => 'rw', isa =>  Ipot,    default => 0, documentation => 'the ipot of the more distant atom');

has 'dspath'     => (is => 'rw', isa =>  Empty.'|Demeter::Path',  default => q{});
has 'tspath'     => (is => 'rw', isa =>  Empty.'|Demeter::Path',  default => q{});
has 'vpath'      => (is => 'rw', isa =>  Empty.'|Demeter::VPath', default => q{});

## the sp attribute must be set to this SSPath object so that the Path
## _update_from_ScatteringPath method can be used to generate the
## feffNNNN.dat file.  an ugly but functional bit of voodoo
sub BUILD {
  my ($self, @params) = @_;
  $self->sp($self);
  $self->mo->push_ThreeBody($self);
};

override alldone => sub {
  my ($self) = @_;
  my $nnnn = File::Spec->catfile($self->folder, $self->dsstring);
  unlink $nnnn if (-e $nnnn);
  $nnnn = File::Spec->catfile($self->folder, $self->tsstring);
  unlink $nnnn if (-e $nnnn);
  $self->remove;
  return $self;
};

override make_name => sub {
  my ($self) = @_;
  $self->name(sprintf("Three Body %.5f %.5f", $self->halflength, $self->angle));
};

## construct the intrp line by disentangling the SP string
sub intrplist {
  my ($self) = @_;
  my $token  = $self->co->default("pathfinder", "token") || '<+>';
  my $string = sprintf("%s %-6s %s", $token, $self->tag, $token);
  return join(" ", $string);
};

after _update_from_ScatteringPath => sub {
  my ($self) = @_;

  my $tempfile = sprintf("feff%4.4d.dat", $self->co->default('pathfinder', 'one_off_index')-1);
  move(File::Spec->catfile($self->parent->workspace, $tempfile),
       File::Spec->catfile($self->parent->workspace, $self->tsstring));

  return $self;
};


sub pathsdat {
  my ($self, @arguments) = @_;
  my %args = @arguments;
  #$self -> randstring(random_string('ccccccccc').'.sp') if ($self->randstring =~ m{\A\s*\z});

  my $a = $self->halflength / (1+cos($self->beta / 2));
  my $c = 2 * $a * cos($self->beta / 2);

  my $feff = $self->parent;
  my @central = $feff->central;
  my @sites = @{ $feff->sites };
  my $pd = q{};
  $pd .= sprintf("  %4d    %d  %6.3f  index, nleg, degeneracy, r= %.4f\n",
		 $self->co->default('pathfinder', 'one_off_index'), 3, 2, $self->halflength);
  $pd .= "      x           y           z     ipot  label      rleg      beta        eta";
  $pd .= "\n";
  $pd .= sprintf(" %11.6f %11.6f %11.6f   %d '%-6s %9.4f %9.4f %9.4f'\n", $c, 0, 0, $self->ipot2, 'foo', $c, 180-$self->beta/2, 0); #$self->ipot, $self->tag);
  $pd .= sprintf(" %11.6f %11.6f %11.6f   %d '%-6s %9.4f %9.4f %9.4f'\n", $a*cos($self->beta / 2), $a*sin($self->beta / 2), 0, $self->ipot1, 'foo', $a, $self->beta, 0); #$self->ipot, $self->tag);
  $pd .= sprintf(" %11.6f %11.6f %11.6f   %d '%-6s %9.4f %9.4f %9.4f'\n", 0, 0, 0, 0, 'abs', $a, 180-$self->beta/2, 0);

  $pd .= sprintf("  %4d    %d  %6.3f  index, nleg, degeneracy, r= %.4f\n",
		 $self->co->default('pathfinder', 'one_off_index')-1, 4, 1, 2*$a);
  $pd .= "      x           y           z     ipot  label";
  $pd .= "      rleg      beta        eta" if ($args{angles});
  $pd .= "\n";
  $pd .= sprintf(" %11.6f %11.6f %11.6f   %d '%-6s %9.4f %9.4f %9.4f'\n", $a*cos($self->beta / 2), $a*sin($self->beta / 2), 0, $self->ipot1, 'foo', $a, $self->beta, 0); #$self->ipot, $self->tag);
  $pd .= sprintf(" %11.6f %11.6f %11.6f   %d '%-6s %9.4f %9.4f %9.4f'\n", $c, 0, 0, $self->ipot2, 'foo', $a, 180, 0); #$self->ipot, $self->tag);
  $pd .= sprintf(" %11.6f %11.6f %11.6f   %d '%-6s %9.4f %9.4f %9.4f'\n", $a*cos($self->beta / 2), $a*sin($self->beta / 2), 0, $self->ipot1, 'foo', $a, $self->beta, 0); #$self->ipot, $self->tag);
  $pd .= sprintf(" %11.6f %11.6f %11.6f   %d '%-6s %9.4f %9.4f %9.4f'\n", 0, 0, 0, 0, 'abs', $a, 180, 0);

  return $pd;
};

override get_params_of => sub {
  my ($self) = @_;
  my @list1 = Demeter::ThreeBody->meta->get_attribute_list;
  my @list2 = Demeter::Path->meta->get_attribute_list;
  return (@list1, @list2);
};

__PACKAGE__->meta->make_immutable;
1;
