package Demeter::SSPath;

=for Copyright
 .
 Copyright (c) 2006-2009 Bruce Ravel (bravel AT bnl DOT gov).
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
use Demeter::NumTypes qw( Ipot PosNum PosInt );
use Demeter::StrTypes qw( Empty );

use Chemistry::Elements qw(get_symbol);
use String::Random qw(random_string);

has 'ipot'	 => (is => 'rw', isa => 'Int',    default => 0,
		     trigger  => \&set_tag);
has 'reff'	 => (is => 'rw', isa => 'Num',    default => 0.1,
		     trigger  => sub{ my ($self, $new) = @_; $self->fuzzy($new);} );
has 'fuzzy'	 => (is => 'rw', isa => 'Num',    default => 0.1);
has '+n'	 => (default => 1);
has 'weight'	 => (is => 'ro', isa => 'Int',    default => 2);
has 'Type'	 => (is => 'ro', isa => 'Str',    default => 'arbitrary single scattering');
has 'string'	 => (is => 'ro', isa => 'Str',    default => q{});
has 'tag'	 => (is => 'rw', isa => 'Str',    default => q{});
has 'randstring' => (is => 'rw', isa => 'Str',    default => sub{random_string('ccccccccc').'.sp'});


## the sp attribute must be set to this SSPath object so that the Path
## _update_from_ScatteringPath method can be used to generate the
## feffNNNN.dat file.  an ugly but functional bit of voodoo
sub BUILD {
  my ($self, @params) = @_;
  $self->sp($self);
  $self->mo->push_SSPath($self);
  #my $i = $self->mo->pathindex;  # this is not necessary -- handeled by Path's BUILD
  #$self->Index($i);
  #$self->mo->pathindex(++$i);
};

override alldone => sub {
  my ($self) = @_;
  my $nnnn = File::Spec->catfile($self->folder, $self->randstring);
  unlink $nnnn if (-e $nnnn);
  return $self;
};


after set_parent_method => sub {
  my ($self) = @_;
  $self->set_tag;
};
sub set_tag {
  my ($self) = @_;
  my $feff = $self->parent;
  return $self if not $feff;
  my @ipots = @{ $feff->potentials };
  my $tag   = $ipots[$self->ipot]->[2] || get_symbol($ipots[$self->ipot]->[1]);
  $self->tag($tag);
  $self->make_name;
  return $self;
};

override make_name => sub {
  my ($self) = @_;
  my $tag = $self->tag;
  my $name = $tag . " SS";
  $self->name($name); # if not $self->name;
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
    $i, $self->n, $self->reff, $self->intrplist, $self->weight, $self->nleg, $self->Type;
};

sub pathsdat {
  my ($self, @arguments) = @_;
  my %args = @arguments;
  $args{index}  ||= 1;
  #$self -> randstring(random_string('ccccccccc').'.sp') if ($self->randstring =~ m{\A\s*\z});

  my $feff = $self->parent;
  my @central = $feff->central;
  my @sites = @{ $feff->sites };
  my $pd = q{};

  $pd .= sprintf("  %4d    %d  %6.3f  index, nleg, degeneracy, r= %.4f\n",
		 $args{index}, $self->get(qw(nleg n fuzzy)) );
  $pd .= "      x           y           z     ipot  label";
  $pd .= "      rleg      beta        eta" if ($args{angles});
  $pd .= "\n";
  $pd .= sprintf(" %11.6f %11.6f %11.6f   %d '%-6s'\n", $central[0], $central[1], $central[2]+$self->reff, $self->ipot, $self->tag);
  $pd .= sprintf(" %11.6f %11.6f %11.6f   %d '%-6s'\n", $feff->central, 0, 'abs');
  return $pd;
};

override get_params_of => sub {
  my ($self) = @_;
  my @list1 = Demeter::SSPath->meta->get_attribute_list;
  my @list2 = Demeter::Path->meta->get_attribute_list;
  return (@list1, @list2);
};


__PACKAGE__->meta->make_immutable;
1;


=head1 NAME

Demeter::SSPath - Arbitrary single scattering paths

=head1 VERSION

This documentation refers to Demeter version 0.3.

=head1 SYNOPSIS

Build a single scattering path of arbitrary length from the potentials
of a Feff calculation:

  my $sspath = Demeter::SSPath->new(parent => $feff_object,
                                    data   => $data_object,
                                    name   => "my SS path",
                                    ipot   => 3,
                                    reff   => 3.2,
                                   );
  $sspath -> plot('R');

=head1 DESCRIPTION

This object behaves in much the same way as Feff's own SS keyword,
L<documented
here|http://leonardo.phys.washington.edu/feff/wiki/index.php?title=SS>.
An SSPath is, in almost every way, exactly like a Path object.  The
SSPath is a subclass of Path, so all Path attributes and methods are
also SSPath attributes and methods.  Specifically, you set all path
parameters in exactly the same way and you use an SSPath in plots and
fits exactly as a normal Path object.

The difference between a Path and SSPath is in how the geometry of the
path is specified.  For a Path object, you must specify either a
ScatteringPath object as the C<sp> attribute or you must set the
C<folder> and C<file> attributes to point at the location of a
F<feffNNNN.dat> file.

For an SSPath object, you set none of those attributes yourself (they
all get set, but not by you).  Instead, you specify the C<ipot> and
C<reff> attributes, which are new attributes for this subclass.
Demeter will then generate a single scattering path for that potential
at that distance. The resulting path will have a natural degeneracy of
1, which can, of course, be overriden by the C<n> attribute.

SSPath objects are plotted just like any Path object, as shown in the
synopsis above.  They are used in fits in the same way as ordinary
Path objects.  That is, the C<paths> attribute of the Fit object takes
a reference to a list of Path and/or SSPath objects.  Path and SSPath
objects can be used as you wish in the Fit object's path list.

=head1 ATTRIBUTES

As with any Moose object, the attribute names are the name of the
accessor methods.

Along with the standard attributes of a Demeter object (C<name>,
C<plottable>, C<data>, and so on), an SSPath has the following:

=over 4

=item C<ipot>

This takes the index of the unique potential for which you wish to
construct a single scattering path.

As with any Path object, you B<must> specify a Feff object. The value
for the C<ipot> attribute is in reference to the associated Feff
object.

=item C<reff>

The half path length of the desired single scattering path.

=back

=head1 METHODS

There are no outward-looking methods for the SSPath object beyond
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

Type constraints needed for several of the attributes.

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

Copyright (c) 2006-2009 Bruce Ravel (bravel AT bnl DOT gov). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut

