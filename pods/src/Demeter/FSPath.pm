package Demeter::FSPath;

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
use MooseX::Aliases;
use MooseX::AttributeHelpers;
#use MooseX::StrictConstructor;
extends 'Demeter::Path';
use Demeter::NumTypes qw( Ipot PosNum PosInt );
use Demeter::StrTypes qw( Edge Empty ElementSymbol);

use Carp;
use Chemistry::Elements qw(get_symbol get_Z);
use File::Spec;
use List::MoreUtils qw(uniq zip);
use String::Random qw(random_string);


with 'Demeter::UI::Screen::Pause' if ($Demeter::mode->ui eq 'screen');

has 'abs'	   => (is => 'rw', isa => Empty.'|'.ElementSymbol, default => q{},
		       trigger => sub{my ($self, $new) = @_;
				      $self->absorber(get_symbol($new));
				      $self->guesses;
				      $self->feff_done(0);
				    });
has 'absorber'     => (is => 'rw', isa => 'Str',    default => q{},);
has 'scat'	   => (is => 'rw', isa => Empty.'|'.ElementSymbol, default => q{},
		       trigger => sub{my ($self, $new) = @_;
				      $self->scatterer(get_symbol($new));
				      $self->guesses;
				      $self->verify_distance;
				      $self->feff_done(0);
				    });
has 'scatterer'    => (is => 'rw', isa => 'Str',    default => q{},);
has 'edge'	   => (is => 'rw', isa =>  Edge,    coerce => 1, default => sub{ shift->co->default("fspath", "edge") },
		       trigger => sub{my ($self, $new) = @_;
				      my $this = (lc($new) eq 'k')  ? 1
					       : (lc($new) eq 'l1') ? 2
					       : (lc($new) eq 'l2') ? 3
					       : (lc($new) eq 'l3') ? 4
					       :                      1;
				      $self->hole($this);
				      $self->feff_done(0);
				    });
has 'hole'	   => (is => 'rw', isa => 'Int',    default => 1,);
has 'distance'	   => (is => 'rw', isa =>  PosNum,  default => sub{ shift->co->default("fspath", "distance") },
		       trigger => sub{my ($self, $new) = @_;
				      $self->verify_distance($new);
				      $self->feff_done(0);
				    });
has 'coordination' => (is => 'rw', isa =>  PosInt,  default => 6,);

has '+parent'      => (default => sub{ Demeter::Feff->new(name=>'qfs', screen=>0, hidden=>1) },);
has 'workspace'    => (is => 'rw', isa => 'Str',   default => q{},
		      trigger => sub{ my ($this, $new) = @_;
				      $this->parent(Demeter::Feff->new(name=>'qfs', screen=>0)) if not $this->parent;
				      $this->parent->workspace($new);
				      $this->parent->make_workspace($new);
				      $this->set_parent;
				    });


has 'fuzzy'	 => (is => 'rw', isa =>  PosNum,  default => 2.0);
has '+n'	 => (default => 1);
has 'weight'	 => (is => 'ro', isa => 'Int',    default => 2);
has 'Type'	 => (is => 'ro', isa => 'Str',    default => 'first shell single scattering');
has 'string'	 => (is => 'ro', isa => 'Str',    default => q{});
has 'tag'	 => (is => 'rw', isa => 'Str',    default => q{});
has 'randstring' => (is => 'rw', isa => 'Str',    default => sub{random_string('ccccccccc').'.sp'});

has 'use_third'  => (is => 'rw', isa => 'Bool',   default => 0);
has 'use_fourth' => (is => 'rw', isa => 'Bool',   default => 0);
has 'feff_done'  => (is => 'rw', isa => 'Bool',   default => 0);

has 'gds' => (
		metaclass => 'Collection::Array',
		is        => 'rw',
		isa       => 'ArrayRef',
		default   => sub { [] },
		provides  => {
			      'push'    => 'push_gds',
			      'clear'   => 'clear_gds',
			      'splice'  => 'splice_gds',
			     },
	       );


## the sp attribute must be set to this FSPath object so that the Path
## _update_from_ScatteringPath method can be used to generate the
## feffNNNN.dat file.  an ugly but functional bit of voodoo
sub BUILD {
  my ($self, @params) = @_;
  #$self->sp($self);
  $self->update_path(1);
  $self->mo->push_FSPath($self);
};

override 'all' => sub {
  my ($self) = @_;
  my @keys   = map {$_->name} grep {$_->name !~ m{\A(?:data|plot|plottable|is_mc|mode|parent|sp|gds|sentinal)\z}} $self->meta->get_all_attributes;
  push @keys, qw(name group mark plottable);
  #print join($/, @keys), $/;
  my @values = map {$self->$_} @keys;
  my %hash   = zip(@keys, @values);
  return %hash;
};

override alldone => sub {
  my ($self) = @_;
  $self->data(q{});
  my $nnnn = File::Spec->catfile($self->folder, $self->randstring);
  unlink $nnnn if (-e $nnnn);
  #print join(" ", caller(2)), $/;
  #print "demolishing parent and gdss\n";
  $self->parent->DEMOLISH if $self->parent;
  foreach my $g (@{$self->gds}) {
    $g->DEMOLISH if (defined $g);
  };
  $self->remove;
  return $self;
};


override make_name => sub {
  my ($self) = @_;
  $self->name(sprintf("%s(%s)-%s", $self->absorber, uc($self->edge), $self->scatterer));
};

override set_parent_method => sub {
  my ($self, $feff) = @_;
  $feff ||= $self->parent;
  return if not $feff;
  $self->parentgroup($feff->group);
  return if not $self->workspace;
  my $text = ($self->co->default("fspath","coordination") == 6)
    ? $self->template("feff", "firstshell6")
      : $self->template("feff", "firstshell4");
  my $feffinp = File::Spec->catfile($feff->workspace, $feff->group.'.inp');
  $feff->make_workspace;
  open my $FI, '>'.$feffinp;
  print $FI $text;
  close $FI;
  $feff->file($feffinp);
};

override path => sub {
  my ($self) = @_;
  if (not $self->parent) {
    my $feff = Demeter::Feff->new(workspace => $self->workspace, screen => 0, name=>'qfs');
    #$self->check_workspace;
    $self->parent($feff);
  };
  #$self->guesses;
  if (not $self->feff_done) {
    #$self->parent->screen(1);
    $self->parent->potph;
    $self->parent->pathfinder;
    $self->feff_done(1);
  };
  $_->push_ifeffit foreach @{ $self->gds };
  my @list = @{ $self->parent->pathlist };
  $self->sp($list[0]);
  $self->n(1);
  $self->_update_from_ScatteringPath;
  $self->label(sprintf("%s-%s path at %s", $self->absorber, $self->scatterer, $self->reff));
  $self->dispose($self->_path_command(1));
  $self->update_path(0);
  return $self;
};

sub check_workspace {
  my ($self) = @_;
  return 0 if ($self->workspace and (-d $self->workspace));
  croak <<EOH

Feff is sort of an old-fashioned program.  It reads from a fixed input
file and writes fixed output files.  All this needs to happen in a
specified directory.

You must explicitly establish a workspace for the Feff calculation
associated with this FSPath object:
  \$fspath->workspace("/path/to/workspace/")

EOH
  ;
};

sub save_feff_yaml {
  my ($self) = @_;
  my $yaml = File::Spec->catfile($self->workspace, $self->parent->group . '.yaml');
  $self->parent->serialize($yaml);
};

sub guesses {
  my ($self) = @_;
  return $self if ((not $self->absorber) or (not $self->scatterer));
  $self->clear_gds;
  my $elems = join('_', lc($self->absorber), lc($self->scatterer));
  #$self->name($elems) if (not $self->name or ($self->name =~ m{FS\s*\z}));
  my @list = ($self->simpleGDS("guess aa_$elems = 1"),
	      $self->simpleGDS("guess ee_$elems = 0"),
	      $self->simpleGDS("guess dr_$elems = 0"),
	      $self->simpleGDS("guess ss_$elems = 0.003"),
	     );
  $self->set(s02    => "aa_$elems",
	     e0	    => "ee_$elems",
	     delr   => "dr_$elems",
	     sigma2 => "ss_$elems");
  if ($self->use_third) {
    push @list, $self->simpleGDS("guess c3_$elems = 0");
    $self->third("c3_$elems");
  };
  if ($self->use_fourth) {
    push @list, $self->simpleGDS("guess c4_$elems = 0");
    $self->third("c4_$elems");
  };
  $self->gds(\@list);
  return $self;
};

sub unset_parameters {
  my ($self) = @_;
  $self->set(s02    => 1,
	     e0	    => 0,
	     delr   => 0,
	     sigma2 => 0,
	     third  => 0,
	     fourth => 0);
  $self -> _update('bft');	# this makes it ready to use immediately
  return $self;
};

sub verify_distance {
  my ($self, $d) = @_;
  return $self if (not $self->scatterer);
  $d ||= $self->distance;
  if ($d < $self->co->default("fspath", "min")) {
    carp(sprintf("%f is awfully short to be a scatterer!\n", $d));
  } elsif (get_Z($self->scatterer) > 17) {
    carp(sprintf("%f is awfully long for a metal scatterer (%s)!\n", $d, $self->scatterer))
      if ($d > $self->co->default("fspath", "max_metal"));
  } elsif (get_Z($self->scatterer) < 18) {
    carp(sprintf("%f is awfully long for a low Z scatterer (%s)!\n", $d, $self->scatterer))
      if ($d > $self->co->default("fspath", "max_lowz"));
  };
};

sub parameter {
  my ($self, $which) = @_;
  $which = lc($which);
  my $id = ($which eq 's02')    ? 0
         : ($which eq 'e0')     ? 1
         : ($which eq 'delr')   ? 2
         : ($which eq 'sigma2') ? 3
         : ($which eq 'third')  ? 4
         : ($which eq 'fourth') ? 5
	 :                       -1;
  return 0 if ($id == -1);
  return 0 if ($id == 4 and not $self->use_third);
  return 0 if ($id == 5 and not $self->use_fourth);
  $id = 4 if (($id == 5) and $self->use_fourth and not $self->use_third);
  return $self->gds->[$id];
};

# sub amplitude {
#   my ($self) = @_;
#   return $self->gds->[0];
# };
# sub e0 {
#   my ($self) = @_;
#   return $self->gds->[1];
# };
# sub delr {
#   my ($self) = @_;
#   return $self->gds->[2];
# };
# sub sigma2 {
#   my ($self) = @_;
#   return $self->gds->[3];
# };
# sub c3 {
#   my ($self) = @_;
#   return 0 if not $self->use_third;
#   return $self->gds->[4];
# };
# sub c4 {
#   my ($self) = @_;
#   return 0 if not $self->use_fourth;
#   return $self->gds->[4] if not $self->use_third;
#   return $self->gds->[5];
# };


__PACKAGE__->meta->make_immutable;
1;


=head1 NAME

Demeter::FSPath - Path for a quick first shell fit

=head1 VERSION

This documentation refers to Demeter version 0.4.

=head1 SYNOPSIS

Build a single scattering path of a given length for use in a quick
first shell fit.

  my $fspath = Demeter::FSPath->new(abs	      => $absorber_element,
                                    scat      => $scatterer_element,
                                    edge      => $edge,
                                    distance  => 2.0,
                                    data      => $data_object,
                                    workspace => "/path/to/work/space",
                                   );
  ##
  ## later...
  ##
  my $fit = Demeter::Fit->new(data  => [$data_object],
                              paths => [$fspath],
                              gds   => $fspath->gds);

Once defined, the FSpath object behaves exactly like a normal Path
oject.  For instance, plotting:

  $fspath -> plot('R');

=head1 DESCRIPTION

This object is rather like an SSPath except that it is not built from
an existing Feff object.  The purpose of this object is to streamline
a simple first shell fit by requiring only the element symbols of an
absorber/scatterer pair and their approximate distance apart.  The
generation of a Feff object, including the Feff calculation will be
handled automatically.  Once made, this can be treated like a normal
Path object, which it extends (in the Moose sense).

To further simplify a first shell fit, the FSPath also autogenerates a
set of four GDS parameters, which get stored in the C<gds> attribute.
The C<s02>, C<e0>, C<delr>, and C<sigma2> attributes which are
inherited from the Path object get set appropriately.  There are flags
for optionally including 3rd or 4th cumulants in the fit.

The FSPath object can be used in a fit along with ordinary Path
objects.  Like with an L<Demeter::SSPath> object, just include the
FSPath object in the list of paths when setting up a L<Demeter::Fit>
object.  The one caveat is that you have to explicitly include the
automatically generated guess parameters in the Fit object's GDS list.
This is most easily done using the C<gds> method of the FSPath object,
as explained below.  There is no way provided (and this is an
intentional design decision) for the Fit object to regognize a FSPath
object and automaticalluy include its associated GDS objects in the
fit.

Note that this object does nothing to examine or modify the attributes
of its associated Data object.  You need to set Fourier transform and
fitting ranges appropriately for a fit using an FSPath object.  One
way of doing this is to read from an Athena project file that has
those parameters sets appropriately.  The other, of course, is to
manipulate the Data object in your script.

=head1 ATTRIBUTES

As with any Moose object, the attribute names are the name of the
accessor methods.  FSPath extends Path, so it has all of Path's
attributes.

Along with the standard attributes of any Demeter object (C<name>,
C<plottable>, C<data>, and so on), an FSPath has the following:

=over 4

=item C<abs>

The element symbol, name, or number of the absorbing atom.

=item C<scat>

The element symbol, name, or number of the scattering atom.

=item C<edge>

The edge at which to make the Feff calculation.

=item C<distance>

The separation in Angstroms between the absorber and scatterer.

=item C<workspace>

You must supply a space on disk for the Feff calculation to use.  None
is assumed and not providing a workspace will result in an error and
exit.

=item C<use_third> and C<use_fourth>

These are boolean flags which tell the FSPath object whether to define
and use third and/or fourth cumulant parameters in the fit.  For
instance:

  $fspath -> use_third(1);

or

  $fspath -> set(use_third=>1, use_fourth=>1);

=item C<gds>

This contains a reference to the list of 4 (or 5 or 6, depending on
whether 3rd and 4th cumulants are used) GDS parameters which were
autogenerated as part of the FSPath object.  This is intended for use
in defining a Fit object:

  my $fit = Demeter::Fit->new(data  => [$data],
                              paths => [$fspath],
                              gds   => $fspath->gds);

=back

=head1 METHODS

=over 4

=item C<parameter>

This is a convenience methods for accessing the GDS objects that get
auto-generated by the FSPath object.  It returns the specified GDS
object.

  my $amp_gds    = $fspath->parameter('s02');
  my $e0_gds     = $fspath->parameter('e0');
  my $delr_gds   = $fspath->parameter('delr');
  my $sigma2_gds = $fspath->parameter('sigma2');
  my $third_gds  = $fspath->parameter('third');
  my $fourth_gds = $fspath->parameter('fourth');

=item C<unset_parameters>

This clears the autogenerated path parameters, setting them all
literally to 0, except for C<s02>, which is set literally to 1.

This is useful in a situation where you wish to use the quick first
shell scattering path in some other context than the quick first shell
fit shown in the Synopsis above.  An example might be to use the path
as the basis of a histogram (see
L<Demeter::ScatteringPath::Histogram>).  In that case you might do
something like:

  my ($rx, $ry, $rz) = $fspath -> sp -> histogram_gamma(1.8, 3.0, 0.1);

=back

=head1 SERIALIZATION AND DESERIALIZATION

Good question ...

=head1 CONFIGURATION AND ENVIRONMENT

See L<Demeter::Config> for a description of the configuration system.
There is an fspath group that can be adjusted to modify the default
behavior of the FSPath object.

=head1 DEPENDENCIES

Demeter's dependencies are in the F<Bundle/DemeterBundle.pm> file.

=head1 BUGS AND LIMITATIONS

=over 4

=item *

C<n> and C<label> don't get reset correctly

=item *

Serialization

=item *

Warn about weird absorber/edge combinations

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

