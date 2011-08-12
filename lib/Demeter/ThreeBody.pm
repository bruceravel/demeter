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
use Readonly;
Readonly my $PI => 4*atan2(1,1);

has 'Type'	 => (is => 'ro', isa => 'Str',    default => 'three body scattering');
has 'string'	 => (is => 'ro', isa => 'Str',    default => q{});
has 'tag'	 => (is => 'rw', isa => 'Str',    default => q{});
has 'randstring' => (is => 'rw', isa => 'Str',    default => sub{random_string('ccccccccc').'.sp'}, alias => 'dsstring');
has 'tsstring'   => (is => 'rw', isa => 'Str',    default => sub{random_string('ccccccccc').'.sp'});
has 'fuzzy'	 => (is => 'rw', isa => 'Num',    default => 0.1);
has 'weight'	 => (is => 'ro', isa => 'Int',    default => 2);

#has 'halflength' => (is => 'rw', isa => 'Num',    default => 0, documentation => 'the half path length of the double scattering path');
has 'r1'         => (is => 'rw', isa => 'Num',    default => 0,
		     trigger => sub{my($self, $new) = @_; $self->calc_r3},
		     documentation => 'the length of the leg between the absorber and the nearer atom');
has 'r2'         => (is => 'rw', isa => 'Num',    default => 0,
		     trigger => sub{my($self, $new) = @_; $self->calc_r3},
		     documentation => 'the length of the leg between the nearer amd more distant atom');
has 'beta'       => (is => 'rw', isa => 'Num',    default => 0,
		     trigger => sub{my($self, $new) = @_; $self->calc_r3},
		     documentation => 'the scattering angle through the intervening atom', alias => 'angle');
has 'r3'         => (is => 'rw', isa => 'Num',    default => 0,
		     documentation => 'the length of the leg between the absorber and the distant atom in DS path');
has 'ipot1'      => (is => 'rw', isa =>  Ipot,    default => 0, documentation => 'the ipot of the intervening atom');
has 'ipot2'      => (is => 'rw', isa =>  Ipot,    default => 0, documentation => 'the ipot of the more distant atom');

has 'dspath'     => (is => 'rw', isa =>  Empty.'|Demeter::Path',  default => q{});
has 'tspath'     => (is => 'rw', isa =>  Empty.'|Demeter::Path',  default => q{});
has 'vpath'      => (is => 'rw', isa =>  Empty.'|Demeter::VPath', default => q{});

has 'through'    => (is => 'ro', isa => 'Bool', default => 0);

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
  $self->dspath->DEMOLISH if (ref($self->dspath) =~ m{Demeter});
  $self->tspath->DEMOLISH if (ref($self->tspath) =~ m{Demeter});
  $self->vpath ->DEMOLISH if (ref($self->vpath)  =~ m{Demeter});
  $self->remove;
  return $self;
};

override make_name => sub {
  my ($self) = @_;
  $self->name(sprintf("Three Body %.5f %.5f %.5f", $self->r1, $self->r2, $self->angle));
};

## construct the intrp line by disentangling the SP string
sub intrplist {
  my ($self) = @_;
  my $token  = $self->co->default("pathfinder", "token") || '<+>';
  my $string = sprintf("%s %-6s %s", $token, $self->tag, $token);
  return join(" ", $string);
};

override path => sub {
  my ($self, $do_ff2chi) = @_;
  $self->_update_from_ScatteringPath if $self->sp;
  $self->update_path(0);
  return $self;
};

override fft => sub {
  my ($self) = @_;
  $self->dspath->fft;
  $self->tspath->fft;
  $self->update_fft(0);
  return $self;
};

override bft => sub {
  my ($self) = @_;
  $self->dspath->bft;
  $self->tspath->bft;
  $self->update_bft(0);
  return $self;
};

override halflength => sub {
  my ($self) = @_;
  return $self->r1+$self->r2;
};

sub calc_r3 {
  my ($self) = @_;
  my $c = sqrt( $self->r1**2 + $self->r2**2 + 2*$self->r1*$self->r2*cos($PI*$self->beta/180) );
  $self->r3($c);
};


after _update_from_ScatteringPath => sub {
  my ($self) = @_;
  ## DS path gets handled by the parent class
  my $tempfile = sprintf("feff%4.4d.dat", $self->co->default('pathfinder', 'one_off_index')-1);
  move(File::Spec->catfile($self->parent->workspace, $tempfile),
       File::Spec->catfile($self->parent->workspace, $self->tsstring));

  #my $c = sqrt( $self->r1**2 + $self->r2**2 + 2*$self->r1*$self->r2*cos($PI*$self->beta/180) );
  my $ds = Demeter::Path->new(folder => $self->parent->workspace,
			      file   => $self->dsstring,
			      name   => sprintf("DS at R=%.5f, beta=%.3f", ($self->r1+$self->r2+$self->r3)/2, $self->beta),
			     );
  my $ts = Demeter::Path->new(folder => $self->parent->workspace,
			      file   => $self->tsstring,
			      name   => sprintf("TS at R=%.5f, beta=%.3f", $self->r1+$self->r2, $self->beta),
			     );
  foreach my $att (qw(s02 e0 delr sigma2 ei third fourth dphase)) {
    $ds->$att($self->$att);
    $ts->$att($self->$att);
  };
  $self->dspath($ds);
  $self->tspath($ts);
  my $vp = Demeter::VPath->new(name=>'sum of DS and TS');
  $vp->include($ds,$ts);
  $self->vpath($vp);
  return $self;
};

override plot => sub {
  my ($self, $space) = @_;
  my $which;
  if (lc($space) eq 'k') {
    $self -> _update("fft");
    $which = "update_path";
  } elsif (lc($space) eq 'r') {
    $self -> _update("bft");
    $which = "update_fft";
  } elsif (lc($space) eq 'q') {
    $self -> _update("all");
    $which = "update_bft";
  };
  $self->dspath->plot($space);
  $self->tspath->plot($space);
  $self->$which(0);
  return $self;
};

sub pathsdat {
  my ($self) = @_;
  my $text = ($self->through) ? $self->pathsdat_through : $self->pathsdat_forward;
  #print $text;
  return $text;
};

sub pathsdat_through {
  my ($self) = @_;
  my $tag1 = $self->parent->potentials->[$self->ipot1]->[2];
  my $tag2 = $self->parent->potentials->[$self->ipot2]->[2];
  my $pd = q{};
  $pd .= sprintf("  %4d    %d  %6.3f  index, nleg, degeneracy, r= %.4f\n",
		 $self->co->default('pathfinder', 'one_off_index'), 3, 1, ($self->r1+$self->r2+$self->r3)/2);
  $pd .= "      x           y           z     ipot  label      rleg      beta        eta";
  $pd .= "\n";
  $pd .= sprintf(" %11.6f %11.6f %11.6f   %d '%-6s' %9.4f %9.4f %9.4f\n", $self->r1, 0, 0, $self->ipot1, $tag1, $self->r1, 180-$self->beta/2, 0);
  $pd .= sprintf(" %11.6f %11.6f %11.6f   %d '%-6s' %9.4f %9.4f %9.4f\n", -1*$self->r2*cos($PI*$self->beta/180), -1*$self->r2*sin($PI*$self->beta/180), 0, $self->ipot2, $tag2, $self->r3, 180-$self->beta/2, 0);
  $pd .= sprintf(" %11.6f %11.6f %11.6f   %d '%-6s' %9.4f %9.4f %9.4f\n", 0, 0, 0, 0, 'abs', $self->r2, $self->beta, 0);

  $pd .= sprintf("  %4d    %d  %6.3f  index, nleg, degeneracy, r= %.4f\n",
		 $self->co->default('pathfinder', 'one_off_index')-1, 4, 1, $self->r1+$self->r2);
  $pd .= "      x           y           z     ipot  label      rleg      beta        eta";
  $pd .= "\n";
  $pd .= sprintf(" %11.6f %11.6f %11.6f   %d '%-6s' %9.4f %9.4f %9.4f\n", $self->r1, 0, 0, $self->ipot1, $tag1, $self->r1, 180, 0);
  $pd .= sprintf(" %11.6f %11.6f %11.6f   %d '%-6s' %9.4f %9.4f %9.4f\n", 0, 0, 0, 0, 'abs', $self->r1, $self->beta, 0);
  $pd .= sprintf(" %11.6f %11.6f %11.6f   %d '%-6s' %9.4f %9.4f %9.4f\n", -1*$self->r2*cos($PI*$self->beta/180), -1*$self->r2*sin($PI*$self->beta/180), 0, $self->ipot2, $tag2, $self->r2, 180, 0);
  $pd .= sprintf(" %11.6f %11.6f %11.6f   %d '%-6s' %9.4f %9.4f %9.4f\n", 0, 0, 0, 0, 'abs', $self->r2, $self->beta, 0);

  return $pd;
};

sub pathsdat_forward {
  my ($self) = @_;

#  my $c = sqrt( $self->r1**2 + $self->r2**2 + 2*$self->r1*$self->r2*cos($PI*$self->beta/180) );

  my $tag1 = $self->parent->potentials->[$self->ipot1]->[2];
  my $tag2 = $self->parent->potentials->[$self->ipot2]->[2];

  my $pd = q{};
  $pd .= sprintf("  %4d    %d  %6.3f  index, nleg, degeneracy, r= %.4f\n",
		 $self->co->default('pathfinder', 'one_off_index'), 3, 2, ($self->r1+$self->r2+$self->r3)/2);
  $pd .= "      x           y           z     ipot  label      rleg      beta        eta";
  $pd .= "\n";
  $pd .= sprintf(" %11.6f %11.6f %11.6f   %d '%-6s' %9.4f %9.4f %9.4f\n", $self->r1+$self->r2*cos($PI*$self->beta/180), $self->r2*sin($PI*$self->beta/180), 0, $self->ipot2, $tag2, $self->r3, 180-$self->beta/2, 0);
  $pd .= sprintf(" %11.6f %11.6f %11.6f   %d '%-6s' %9.4f %9.4f %9.4f\n", $self->r1, 0, 0, $self->ipot1, $tag1, $self->r2, $self->beta, 0);
  $pd .= sprintf(" %11.6f %11.6f %11.6f   %d '%-6s' %9.4f %9.4f %9.4f\n", 0, 0, 0, 0, 'abs', $self->r1, 180-$self->beta/2, 0);

  $pd .= sprintf("  %4d    %d  %6.3f  index, nleg, degeneracy, r= %.4f\n",
		 $self->co->default('pathfinder', 'one_off_index')-1, 4, 1, $self->r1+$self->r2);
  $pd .= "      x           y           z     ipot  label      rleg      beta        eta";
  $pd .= "\n";
  $pd .= sprintf(" %11.6f %11.6f %11.6f   %d '%-6s' %9.4f %9.4f %9.4f\n", $self->r1, 0, 0, $self->ipot1, $tag1, $self->r2, $self->beta, 0);
  $pd .= sprintf(" %11.6f %11.6f %11.6f   %d '%-6s' %9.4f %9.4f %9.4f\n", $self->r1+$self->r2*cos($PI*$self->beta/180), $self->r2*sin($PI*$self->beta/180), 0, $self->ipot2, $tag2, $self->r1, 180, 0);
  $pd .= sprintf(" %11.6f %11.6f %11.6f   %d '%-6s' %9.4f %9.4f %9.4f\n", $self->r1, 0, 0, $self->ipot1, $tag1, $self->r2, $self->beta, 0);
  $pd .= sprintf(" %11.6f %11.6f %11.6f   %d '%-6s' %9.4f %9.4f %9.4f\n", 0, 0, 0, 0, 'abs', $self->r1, 180, 0);

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

=head1 NAME

Demeter::ThreeBody - Multiple scattering from an arbitrary three-body configuration

=head1 VERSION

This documentation refers to Demeter version 0.5.

=head1 SYNOPSIS

Build a single scattering path of arbitrary length from the potentials
of a Feff calculation:

  my $tb = Demeter::ThreeBody->new(parent   => $feff_object,
                                   data     => $data_object,
                                   r1       => 2.7,
                                   r2       => 2.6,
                                   beta     => 1.1,
                                   ipot1    => 1,
                                   ipot2    => 3,
                                  );
  $tb -> plot('R');

=head1 DESCRIPTION

Given an arrangement of three atoms -- presmuably a nearly collinear
configuration -- generate the double and tripple scattering paths
associated with that configuration.

This object is treated just like a normal Path object in that it is
parameterized in much the same way:

  $tb -> set(s02 => 'amp', e0 => 'enot');

These parameters are passed along to the double and triple scattering
paths that are generated by the use of this object.  The assumption,
therefore, is that the double and triple scattering paths would get
the same parameters.  This is probably a decent assumption for a
nearly collinear configuration.  In the collinear case, the fourth
shell of copper metal for instance, deltaR and sigma^2 really should
be parametrized the same as the single scattering path to th distant
atom.

The degeneracies of the double and triple scattering paths are set to
2 and 1.  It is up to you to make sure that the C<s02> path parameter
is set correctly, presumably the same as the number of single
scattering paths to the distant atom.

=head1 ATTRIBUTES

As with any Moose object, the attribute names are the name of the
accessor methods.

This extends L<Demeter::Path>.  Along with the standard attributes of
any Demeter object (C<name>, C<plottable>, C<data>, and so on), and of
the Path object, a ThreeBody object has the following:

The C<r1>, C<r2>, C<beta>, C<ipot1>, and C<ipot2> attributes must be
specified as these are used to construct the constituent paths.

The C<dspath> and C<tspath> attributes are set as the output of
creating a ThreeBody object.  Sensible things will happen when
plotting or using in a fit, so it should not normally be necessary to
access these directly.

When a ThreeBody is used in a fit, the Path objects contained in
C<dspath> and C<tspath> will be pushed onto the Fit objects list of
paths.  When plotting a ThreeBody, each of those Path objects will
beplotted.  When added to a VPath, both will be added.

=over 4

=item C<r1>

The length of the leg between the absorber and the nearer atom.

=item C<r1>

The length of the leg between the nearer atom and the more distant
atom.

=item C<beta>

The scattering angle through the intervening atom.

=item C<ipot1>

From the Feff object specified by the C<parent> attribute, the
potential index of the intervening atom.

=item C<ipot2>

From the Feff object specified by the C<parent> attribute, the
potential index of the distant atom.

=item C<dspath>

This contains the Path object for the double scattering (3-legged)
path.

=item C<tspath>

This contains the Path object for the triple scattering (4-legged)
path.

=item C<through>

When true, this computes paths which scatter through the absorber:

     Absorber ---> Atom1 ---> Absorber ---> Atom2 ---> Absorber

plus the three-legged path which skips the absorber

When false, this computes paths which scatter through the first atom:

     Absorber ---> Atom1 ---> Atom2 ---> Atom1 ---> Absorber

plus the three-legged path which skips Atom1.

=back

=head1 METHODS

There are no outward-looking methods for the ThreeBody object beyond
those of the Path object.  All methods in this module are used behind
the scenes and need never be called by the user.

=head1 SERIALIZATION AND DESERIALIZATION

Good question ...

=head1 CONFIGURATION AND ENVIRONMENT

See L<Demeter::Config> for a description of the configuration system.

=head1 DEPENDENCIES

Demeter's dependencies are in the F<Bundle/DemeterBundle.pm> file.

=head1 BUGS AND LIMITATIONS

=over 4

=item *

Do the right thing in a fit and in a VPath.

=item *

Sanity checking, for instance, need to check that the requested ipot
actually exists; that parent and data are set before anything is done;
...

=item *

Think about serialization by itself and in a fit.

=back

Please report problems to Bruce Ravel (bravel AT bnl DOT gov)

Patches are welcome.

=head1 AUTHOR

Bruce Ravel (bravel AT bnl DOT gov)

L<http://cars9.uchicago.edu/~ravel/software/>


=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2011 Bruce Ravel (bravel AT bnl DOT gov). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
