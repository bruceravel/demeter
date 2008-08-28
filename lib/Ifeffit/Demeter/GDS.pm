package Ifeffit::Demeter::GDS;

=for Copyright
 .
 Copyright (c) 2006-2008 Bruce Ravel (bravel AT bnl DOT gov).
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

use strict;
use warnings;
use Class::Std;
use Carp;
use Fatal qw(open close);
use Regexp::List;
use Regexp::Optimizer;
use Regexp::Common;
use Readonly;
Readonly my $NUMBER => $RE{num}{real};

{
  use base qw( Ifeffit::Demeter
               Ifeffit::Demeter::Dispose
               Ifeffit::Demeter::Project
              );

  ## set default data parameter values
  my %gds_defaults = (
		      group    => 'gds',
		      type     => 'guess', # (guess def set skip after merge restrain)
		      name     => q{_},
		      mathexp  => q{},
		      stored   => q{},
		      bestfit  => 0, # float
		      error    => 0, # float
		      modified => 1, # boolean
		      note     => q{},
		      autonote => 1, # boolean
		      use      => 1,
		     );
  my $opt  = Regexp::List->new;
  my $number_attr   = $opt->list2re(qw(bestfit error));
  my $boolean_attr  = $opt->list2re(qw(modified autonote));
  my $type_regexp   = $opt->list2re(qw(guess def set after merge restrain skip
				       lguess ldef lafter lrestrain));

  sub BUILD {
    my ($self, $ident, $arguments) = @_;
    my $group = 'plot parameters';
    $self -> set(\%gds_defaults);

    ## need to verify that type is one of (guess def set skip after merge restrain)
    ## need to verify that name is not an Ifeffit program variable
    ## need to verify that mathexp does not contain an unknown function()
    ## group and name should be the same

    ## plot specific attributes
    $self -> set($arguments);

    return;
  };
  sub DEMOLISH {
    my ($self) = @_;
    return;
  };


  sub set {
    my ($self, $r_hash) = @_;
    my $re = $self->regexp;

    my %range_check = (k=>0, r=>0);
    foreach my $key (keys %$r_hash) {
      my $k = lc $key;

      carp("\"$key\" is not a valid Ifeffit::Demeter::GDS attribute"), next
	if ($k !~ /$re/);

    SET: {
	($k eq 'name') and do {
	  croak("Ifeffit::Demeter::GDS: $r_hash->{$k} is not a valid parameter name")
	    if ($r_hash->{$k} !~ m{\A[_a-z][a-z0-9:_\?&]{0,63}\z}io);
	  croak("Ifeffit::Demeter::GDS: reff, pi, and etok are reserved parameter names in Ifeffit")
	    if ($r_hash->{$k} =~ m{\A(?:etok|pi|reff)\z}i);
	  croak("Ifeffit::Demeter::GDS: cv is a reserved parameter name in Demeter")
	    if (lc($r_hash->{$k}) eq 'cv');
	  $self->SUPER::set({$k=>$r_hash->{$k}});
	  last SET;
	};
	($k eq 'type') and do {
	  ($r_hash->{$k} = "restrain") if (lc($r_hash->{$k}) eq "restraint");
	  croak("Ifeffit::Demeter::GDS: $r_hash->{$k} is not a valid parameter type")
	    if (lc($r_hash->{$k}) !~ m{\A$type_regexp\z});
	  $self->SUPER::set({$k=>$r_hash->{$k}});
	  last SET;
	};
	($k =~ m{\A$number_attr\z}) and do { # numbers must be numbers
	  croak("Ifeffit::Demeter::GDS: $k must be a number")
	    if ($r_hash->{$k} !~ m{\A$NUMBER\z});
	  ++$range_check{$1} if ($k =~ /\b([kr])m(?:ax|in)\b/);
	  $self->SUPER::set({$k=>$r_hash->{$k}});
	  last SET;
	};
	($k eq 'mathexp') and do {
	  $self->SUPER::set({$k=>$r_hash->{$k}, stored=>$r_hash->{$k}});
	  last SET;
	};
	do {			# no special handling required
	  $self->SUPER::set({$k=>$r_hash->{$k}});
	};
      };

    };
  };

  ## return a list of valid plot parameter names
  sub parameter_list {
    my ($self) = @_;
    return (sort keys %gds_defaults);
  };
  my $parameter_regexp = $opt->list2re(keys %gds_defaults);
  sub _regexp {
    my ($self) = @_;
    return $parameter_regexp;
  };

  # skip after merge
  sub write_gds : STRINGIFY {
    my ($self) = @_;
    my $string = $self->template("fit", "gds");
    return $string;
  };

  sub data {
    my ($self) = @_;
    return $self;
  };

  sub name {
    my ($self) = @_;
    return $self->get('name');
  };
  sub type {
    my ($self) = @_;
    return $self->get('type');
  };
  sub mathexp {
    my ($self) = @_;
    return $self->get('mathexp');
  };
  sub bestfit : NUMERIFY {
    my ($self) = @_;
    return $self->get('bestfit');
  };
  sub error {
    my ($self) = @_;
    return $self->get('error');
  };
  sub note {
    my ($self) = @_;
    return $self->get('note');
  };
  sub autonote {
    my ($self) = @_;
    return $self->get('autonote');
  };
  sub Use {
    my ($self) = @_;
    return $self->get('use');
  };

  sub annotate {
    my ($self, $string) = @_;
    my $auto = (defined $string) ? 1 : 0;
    $self->set({note=>$string, autonote=>$auto});
  };

  sub report {
    my ($self, $identify) = @_;
    my $string = q{};
    my $type = 	($identify) ? sprintf("%-8s: ", $self->type) : q{};
  SWITCH: {
      ($self->type eq 'guess') and do {
	$string = sprintf("%s%-18s = %12.8f    # +/- %12.8f     [%s]\n", $type, $self->get(qw(name bestfit error mathexp)));
	last SWITCH;
      };
      ($self->type eq 'set') and do {
	if ($self->get("mathexp") =~ m{\A$NUMBER\z}) {
	  $string = sprintf("%s%-18s = %12.8f\n",                   $type, $self->get(qw(name mathexp)));
	} else {
	  $string = sprintf("%s%-18s = %12.8f    # [%s]\n",          $type, $self->get(qw(name bestfit mathexp)));
	};
	last SWITCH;
      };
      ($self->type eq 'lguess') and do {
	$string = sprintf("%s%-18s = %12.8f\n",                     $type, $self->get(qw(name mathexp)));
	last SWITCH;
      };
      ($self->type eq 'def') and do {
	$string = sprintf("%s%-18s = %12.8f    # [%s]\n",            $type, $self->get(qw(name bestfit mathexp)));
	last SWITCH;
      };
      ($self->type eq 'restrain') and do {
	$string = sprintf("%s%-18s = %12.8f # [:= %s]\n",               $type, $self->get(qw(name bestfit mathexp)));
	last SWITCH;
      };
      ($self->type eq 'after') and do {
	$string = sprintf("%s%-18s = %12.8f    # [%s]\n",            $type, $self->get(qw(name bestfit mathexp)));
	last SWITCH;
      };
      ($self->type eq 'skip') and do {
	$string = sprintf("%s is a skip parameter\n",               $self->name);
	last SWITCH;
      };
      ($self->type eq 'merge') and do {
	$string = sprintf("%s is a merge parameter\n",              $self->name);
	last SWITCH;
      };
    };
    return $string;
  };
  sub full_report {
    my ($self) = @_;
    my $string = $self->name . "\n";
    $string   .= sprintf("  %s parameter\n", $self->type);
    return $string if (($self->type eq 'skip') or ($self->type eq 'merge'));

    $string   .= sprintf("  math expression: %s\n", $self->mathexp);
  SWITCH: {
      $string   .= sprintf("  evaluates to %12.8f +/- %12.8f\n", $self->get(qw(bestfit error))), last SWITCH if ($self->type eq 'guess');
      $string   .= sprintf("  evaluates to %12.8f\n", $self->bestfit);
    };
    $string   .= sprintf("  annotation: \"%s\"\n", $self->note);
    return $string;
  };


  sub evaluate {
    my ($self) = @_;
    return 0 if (($self->type eq 'skip') or ($self->type eq 'merge'));
    $self->set({modified=>0});
    my $name = $self->name;
    my $value = Ifeffit::get_scalar($name);
    if ($self->type eq 'guess') {
      my $error = Ifeffit::get_scalar("delta_$name");
      $self -> set({bestfit=>$value, error=>$error});
    } else {
      $self -> set({bestfit=>$value, error=>0});
    };
    if ($self->autonote) {
      if ($self->type eq 'guess') {
	$self->set({note=>sprintf("%s: %12.8f +/- %12.8f", $self->get(qw(name bestfit error)))});
      } else {
	$self->set({note=>sprintf("%s: %12.8f", $self->get(qw(name bestfit)))});
      };
    };
    return 1;
  };

};
1;


=head1 NAME

Ifeffit::Demeter - Guess, Set, Def, and other parameters for EXAFS fitting

=head1 VERSION

This documentation refers to Ifeffit::Demeter version 0.1.

=head1 SYNOPSIS

   $gds_object = Ifeffit::Demeter::GDS ->
       new({type    => 'guess',
	    name    => 'alpha',
            mathexp => 0,
          });
   $gds_object -> report;
   ## after a fit....
   $gds_object -> evaluate;


=head1 DESCRIPTION

This subclass of the Ifeffit::Demeter class is inteded to hold
information pertaining to guess, def, set, and other parameters for
use in a fit.

=head1 ATTRIBUTES

A GDS object has these attributes:

=over 4

=item C<name> (string)

This is the name of the parameter.  It must respect the conventions
for a parameter name in Ifeffit.  They can contain only letters,
numbers, '&', '?', ':', and `_' (underscore).  They are limited to 64
characters.  and cannot begin with a numeral.

=item C<type> (guess def set restrain after merge skip)

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
described in the L<Ifeffit::Demeter> documentation.

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

   $gds_object -> set({note=>$string, autonote=>0});
   $gds_object -> set({note=>q{}, autonote=>1});

but using this method saves you the bother of remembering to toggle the
C<autonote> attribute.

=back

=head2 Convenience methods

A number of convenience methods exist for probing attribute values.
These are all wrappers around the C<get> method.

=over 4

=item C<name>

Returns the parameter name.

  $name = $gds_object -> name;

=item C<type>

Returns the parameter type.

  $type = $gds_object -> type;

=item C<mathexp>

Returns the parameter's math expression.

  $mathexp = $gds_object -> mathexp;

=item C<bestfit>

Returns the value of the parameter after the fit has been evaluated.

  $value = $gds_object -> bestfit;

Before a fit is evaluated, this method returns 0.

=item C<error>

Returns the uncertainty of a guess parameter after the fit has been
evaluated.

  $name = $gds_object -> name;

Before a fit is evaluated and for all parameters which are not of type
guess, this method returns 0.

=item C<note>

Returns the parameter's annotation.

  $string = $gds_object -> note;

=item C<autonote>

Returns true if the parameter is flagged for automatic annotation
after a fit.

  $is_automatic = $gds_object -> autonote;

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

=head1 COERCIONS

When the reference to the GDS object is used in string context, it returns the
string from the C<write_gds> method.  That string looks something like:

  guess alpha = 0.0

When the reference to the GDS object is used in numerical context, it returns
the the bestfit value of the parameter.  These two lines of perl are the same:

  printf("%s is %.7f\n", $gdsobjects[0]->name, $gdsobjects[0]->bestfit);

  printf("%s is %.7f\n", $gdsobjects[0]->name, $gdsobjects[0]);

=head1 DIAGNOSTICS

These messages are classified as follows (listed in increasing order
of desperation):

    (W) A warning (optional).
    (F) A fatal error (trappable).

=over 4

=item C<Ifeffit::Demeter::GDS: $r_hash->{$k} is not a valid parameter name>

(F) You parameter does not observe Ifeffit's rules for parameter names.

=item C<Ifeffit::Demeter::GDS: reff, pi, and etok are reserved parameter names in Ifeffit>

(F) These words cannot be used as parameter names because they have
special meaning in Ifeffit.

=item C<Ifeffit::Demeter::GDS: cv is a reserved parameter name in Demeter>

(F) These words cannot be used as parameter names because they have
special meaning in Demeter.

=item C<Ifeffit::Demeter::GDS: $k must be a number>

(F) You have attempted to set a numerical attribute with something
that cannot be interpretted as a number.

=item C<Ifeffit::Demeter::GDS: "name" is not a valid parameter name>

(F) You have used a parameter name that does not follow Ifeffit's rules for
group names.  The parameter name must start with a letter.  After that only
letters, numbers, &, ?, _, and : are acceptable characters.  The name must be
no longer than 64 characters.

=item C<Ifeffit::Demeter::GDS: "type" is not a valid parameter type>

(F) The complete list of valid parameter types is guess, def, set, after,
merge, restrain (without a "t" at the end), and skip.

=back

=head1 SERIALIZATION AND DESERIALIZATION

See the discussion of serialization and deserialization in
C<Ifeffit::Demeter::Fit>.

=head1 CONFIGURATION AND ENVIRONMENT

See L<Ifeffit::Demeter::Config> for a description of the configuration
system.

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

Copyright (c) 2006-2008 Bruce Ravel (bravel AT bnl DOT gov). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
