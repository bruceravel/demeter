package Demeter::GDS;

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

use autodie qw(open close);

use Moose;
use MooseX::StrictConstructor;
extends 'Demeter';
use Demeter::StrTypes qw( GDS NotReserved );

use Carp;
use Regexp::List;
use Regexp::Optimizer;
use Regexp::Common;
use Readonly;
Readonly my $NUMBER => $RE{num}{real};

has '+name'	  => (isa => NotReserved);
has 'gds'	  => (is => 'rw', isa =>  GDS,    default => 'guess');
has 'mathexp'	  => (is => 'rw', isa => 'Str',   default => q{});	##,trigger => sub{ my ($self, $new) = @_; $self->stored($new));
has 'stored'	  => (is => 'rw', isa => 'Str',   default => q{});
has 'bestfit'	  => (is => 'rw', isa => 'Num',   default => 0,
		      trigger => sub{my ($self, $new) = @_; $self->modified(1) if $new} );
has 'error'	  => (is => 'rw', isa => 'Num',   default => 0);
has 'modified'	  => (is => 'rw', isa => 'Bool',  default => 1);
has 'note'	  => (is => 'rw', isa => 'Str',   default => q{},
		     trigger => sub{my ($self, $new) = @_; $self->autonote(1) if ($new =~ m{\A\s*\z})} );
has 'autonote'	  => (is => 'rw', isa => 'Bool',  default => 1);
has 'highlighted' => (is => 'rw', isa => 'Bool',  default => 0);
has 'Use'	  => (is => 'rw', isa => 'Bool',  default => 1);
has 'is_merge'	  => (is => 'rw', isa => 'Bool',  default => 0);

has 'expandsto'	  => (is => 'rw', isa => 'Str',   default => q{});

sub BUILD {
  my ($self, @params) = @_;
  $self->mo->push_GDS($self);
};
sub DEMOLISH {
  my ($self) = @_;
  $self->alldone;
  ## --- this would be nice, but it seems to happen after Ifeffit is
  ##     shut down in certain cases when exiting Artemis
  # $self->dispose("erase ".$self->name);
};

## return a list of valid GDS attributes
sub parameter_list {
  my ($self) = @_;
  return (sort $self->meta->get_attribute_list);
};

# skip after merge
sub write_gds {
  my ($self) = @_;
  my $string = $self->template("fit", "gds");
  return $string;
};

sub annotate {
  my ($self, $string) = @_;
  my $auto = (defined($string) and ($string !~ m{\A\s*\z})) ? 0 : 1;
  $self->set(note=>$string, autonote=>$auto);
};

sub autoannotate {
  my ($self) = @_;
  return if not $self->autonote;
  my $string = q{};
  if ($self->gds eq 'guess') {
    $string = sprintf("%s : %.5f +/- %.5f", $self->name, $self->bestfit, $self->error);
  } elsif ($self->gds =~ m{(?:def|after|penalty|restrain)}) {
    $string = sprintf("%s : %.5f (:= %s)", $self->name, $self->bestfit, $self->mathexp);
  } elsif ($self->gds eq 'lguess') {
    $string = $self->expandsto;
  };
  #
  # do nothing with skip, set, merge
};

sub report {
  my ($self, $identify) = @_;
  my $string = q{};
  my $type   = ($identify) ? sprintf("%-8s: ", $self->gds) : q{};
 SWITCH: {
    ($self->gds eq 'guess') and do {
      $string = sprintf("%s%-18s = %12.8f    # +/- %12.8f     [%s]\n", $type, $self->get(qw(name bestfit error mathexp)));
      last SWITCH;
    };
    ($self->gds eq 'set') and do {
      if ($self->mathexp =~ m{\A$NUMBER\z}) {
	$string = sprintf("%s%-18s = %12.8f\n",                        $type, $self->get(qw(name mathexp)));
      } else {
	$string = sprintf("%s%-18s = %12.8f    # [%s]\n",              $type, $self->get(qw(name bestfit mathexp)));
      };
      last SWITCH;
    };
    ($self->gds eq 'lguess') and do {
      $string = sprintf("%s%-18s = %12.8f\n",                          $type, $self->get(qw(name mathexp)));
      last SWITCH;
    };
    ($self->gds eq 'def') and do {
      $string = sprintf("%s%-18s = %12.8f    # [%s]\n",                $type, $self->get(qw(name bestfit mathexp)));
      last SWITCH;
    };
    ($self->gds eq 'restrain') and do {
      $string = sprintf("%s%-18s = %12.8f # [:= %s]\n",                $type, $self->get(qw(name bestfit mathexp)));
      last SWITCH;
    };
    ($self->gds eq 'after') and do {
      $string = sprintf("%s%-18s = %12.8f    # [%s]\n",                $type, $self->get(qw(name bestfit mathexp)));
      last SWITCH;
    };
    ($self->gds eq 'skip') and do {
      $string = sprintf("%s is a skip parameter\n",                    $self->name);
      last SWITCH;
    };
    ($self->gds eq 'merge') and do {
      $string = sprintf("%s is a merge parameter\n",                   $self->name);
      last SWITCH;
    };
  };
  return $string;
};

sub full_report {
  my ($self) = @_;
  my $string = $self->name . "\n";
  $string   .= sprintf("  %s parameter\n", $self->gds);
  return $string if (($self->gds eq 'skip') or ($self->gds eq 'merge'));

  $string   .= sprintf("  math expression: %s\n", $self->mathexp);
 SWITCH: {
    $string   .= sprintf("  evaluates to %12.8f +/- %12.8f\n", $self->get(qw(bestfit error))), last SWITCH if ($self->gds eq 'guess');
    $string   .= sprintf("  evaluates to %12.8f\n", $self->bestfit);
  };
  $string   .= sprintf("  annotation: \"%s\"\n", $self->note);
  return $string;
};


sub evaluate {
  my ($self) = @_;
  return 0 if (($self->gds eq 'skip') or ($self->gds eq 'merge'));
  $self->modified(0);
  my $name = $self->name;
  my $value = Ifeffit::get_scalar($name);
  if ($self->gds eq 'guess') {
    my $error = Ifeffit::get_scalar("delta_$name");
    $self -> set(bestfit=>$value, error=>$error);
  } else {
    $self -> set(bestfit=>$value, error=>0);
  };
  if ($self->autonote) {
    if ($self->gds eq 'guess') {
      $self->set(note=>sprintf("%s: %12.8f +/- %12.8f", $self->get(qw(name bestfit error))));
    } else {
      $self->set(note=>sprintf("%s: %12.8f", $self->get(qw(name bestfit))));
    };
  };
  return 1;
};

sub push_ifeffit {
  my ($self) = @_;
  $self->dispose($self->write_gds);
  return $self;
};

__PACKAGE__->meta->make_immutable;
1;


=head1 NAME

Demeter::GDS - Guess, Set, Def, and other parameters for EXAFS fitting

=head1 VERSION

This documentation refers to Demeter version 0.4.

=head1 SYNOPSIS

   $gds_object = Demeter::GDS ->
       new(gds     => 'guess',
	   name    => 'alpha',
           mathexp => 0,
          );
   $gds_object -> report;
   ## after a fit....
   $gds_object -> evaluate;


=head1 DESCRIPTION

This subclass of the Demeter class is inteded to hold information
pertaining to guess, def, set, and other parameters for use in a fit.

=head1 ATTRIBUTES

A GDS object has these attributes:

=over 4

=item C<name> (string)

This is the name of the parameter.  It must respect the conventions
for a parameter name in Ifeffit.  They can contain only letters,
numbers, '&', '?', ':', and '_' (underscore).  They are limited to 64
characters and cannot begin with a numeral.

=item C<gds> (guess def set lguess restrain after merge skip)

This is one of:

=over 4

=item I<guess>

A parameter varied in the fit.

=item I<def>

A parameter whose math expression is continuously updated throughout
the fit.

=item I<set>

A parameter which is evaluated at the beginning of the fit and remains
unchanged after that.

=item I<lguess>

A locally guessed parameter.  In a multiple data set fit, this will be
expanded to one guess parameter per data set.

=item I<restrain>

A restrain parameter is defined in an Ifeffit script as a def
parameter but is used as a restraint in the call to the feffit
function.  In a multiple data set fit, all restraints are defined in
the first call to the feffit command.

=item I<after>

This is like a def parameter, but is not evaluated until the fit
finishes.  It is then reported in the log file.

=item I<merge>

A merge is the type given to a parameter that cannot be unambiguously
resolved when two Fit objects are merged into a single Fit object. A
fit cannot proceed until all merge parameters are resolved.

=item I<skip>

A skip is a parameter that is defined but then ignored.  Setting a
variable to a skip is the Demeter equivalent of commenting it out.

=back

=item C<mathexp> (string)

This is the math expression assigned to the parameter.  For a guess or
set parameter this is often just a number -- the initial guess.

=item C<stored> (string)

This is the math expression as provided by the user before any
rewriting for local parameters.

=item C<bestfit> (number)

After the fit is evaluated, this contains the result of the fit for this
parameter.  This is normally not set explicitly with the C<set> method.
Rather it is set using the C<evaluate> method so that the math expression is
correctly evaluated by Ifeffit.

=item C<error> (number)

After the fit is evaluated, this contains the error on this guess parameter.
For all other types, this is 0.  This is normally not set explicitly with the
C<set> method.  Rather it is set using the C<evaluate> method after a fit.

=item C<modified> (boolean)

This is true if the parameter has been modified but not evaluated.

=item C<note> (string)

This is a text string -- an annotation -- used to describe something
about the parameter.

=item C<autonote> (boolean)

When this is true, the annotation is set automatically when the
parameter is evaluated.

=item C<use> (boolean)

This is a flag disables the use of a global restraint or a global
after when local guess parameters are in play.

=back

=head1 METHODS

=head2 Object handling methods

The GDS object uses the C<new>, C<clone>, C<set>, and C<get> methods
described in the L<Demeter> documentation.

=over 4

=item C<annotate>

This method sets the C<note> and C<autonote> attributes in a stroke.
It takes a single argument, the annotation string for the parameter.

   $gds_object -> annotate($string)
   $gds_object -> annotate(q{})

If the string is not empty, the C<note> will be set to the string and the
autonote attribute will be set to 0.  If the string is empty, the C<note>
attribute will be cleared and the autonote attribute will be set to 1.  These
are completely equivalent to

   $gds_object -> set(note=>$string, autonote=>0);
   $gds_object -> set(note=>q{},     autonote=>1);

but using this method saves you the bother of remembering to toggle the
C<autonote> attribute.

=back

=head2 Reporting and evaluation methods

=over 4

=item C<write_gds>

This returns a string which is the command to define the parameter in
Ifeffit.

   $string = $gds_object -> write_gds

This returns a string something like

   guess enot = 0.0

The first word is the parameter type.  "def" is used for after and
restrain parameters.  Other parameter types (skip and merge) return
string which will not be valid Ifeffit commands.

=item C<report>

This returns a one-line string which reports on the value of a
parameter after a fit is complete.  This method is used in the
C<logfile> method of the Fit subclass.

   $string = $gds_object -> report;

The strings returned for the various parameter types are different.
All contain the best fit value and the math expression (or initial
guess).  The error is included for guess parameters.

=item C<full_report>

This is like the C<report> method, but it returns a more verbose,
multiline string and includes the annotation.

   $string = $gds_object -> report;

This is not used in the logfile, but may be useful in an interactive
application.

=item C<evaluate>

This method is called after a fit is performed to evaluate the bestfit
and error attributes of the object.  It also sets the annotation is
the autonote attribute is true.  It returns 1 in most cases, but
returns 0 for unevaluatable parameter types (skip and merge).

   $is_ok = $gds_object -> evaluate;

This is called as part of the C<evaluate> method of the Fit class on
all parameters used in the fit.  Thus, it normally does not need to be
called explicitly.  However, it may be useful in interactive use.

=back

=head1 DIAGNOSTICS

Moose type constraints are used on several of the GDS object
attributes.  Error messages appropriate to the type constrain will be
generated.

=head1 SERIALIZATION AND DESERIALIZATION

See the discussion of serialization and deserialization in
C<Demeter::Fit>.

=head1 CONFIGURATION AND ENVIRONMENT

See L<Demeter::Config> for a description of the configuration system.

=head1 DEPENDENCIES

Demeter's dependencies are in the F<Bundle/DemeterBundle.pm> file.

=head1 BUGS AND LIMITATIONS

=over 4

=item *

Errors should be propagated into def parameters

=back

Please report problems to Bruce Ravel (bravel AT bnl DOT gov)

Patches are welcome.

=head1 AUTHOR

Bruce Ravel (bravel AT bnl DOT gov)

L<http://cars9.uchicago.edu/~ravel/software/>

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2010 Bruce Ravel (bravel AT bnl DOT gov). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
