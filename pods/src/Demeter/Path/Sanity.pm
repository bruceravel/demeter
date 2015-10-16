package Demeter::Path::Sanity;

=for Copyright
 .
 Copyright (c) 2006-2015 Bruce Ravel (http://bruceravel.github.io/home).
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

use Moose::Role;

use Carp;
use List::MoreUtils qw(any);
use Demeter::Constants qw($EPSILON5 $NUMBER);


my %pp_trans = ('3rd'=>"third", '4th'=>"fourth", dphase=>"dphase",
		dr=>"delr", e0=>"e0", ei=>"ei", s02=>"s02", ss2=>"sigma2");
sub is_resonable {
  my ($self, $param) = @_;
  $param = lc($param);
  ($param = "s02") if ($param eq "so2");
  my ($value, $explanation) = (1, q{});
 SWITCH: {
    ($param eq "e0") and do {
      ($value, $explanation) = $self->test_e0;
      last SWITCH;
    };
    ($param eq "s02") and do {
      ($value, $explanation) = $self->test_s02;
      last SWITCH;
    };
    ($param =~ m{^s(?:ig|s)}) and do {
      ($value, $explanation) = $self->test_sigma2;
      last SWITCH;
    };
    ($param eq "delr") and do {
      ($value, $explanation) = $self->test_delr;
      last SWITCH;
    };
    (($param eq "3rd") or ($param eq "third")) and do {
      ($value, $explanation) = $self->test_third;
      last SWITCH;
    };
    (($param eq "4th") or ($param eq "fourth")) and do {
      ($value, $explanation) = $self->test_fourth;
      last SWITCH;
    };
    ($param eq "dphase") and do {
      ($value, $explanation) = (1, q{});
      last SWITCH;
    };
    ($param =~ m{array}) and do {
      ($value, $explanation) = (1, q{});
      last SWITCH;
    };
  };

  return ($value, $explanation);
};

sub test_e0 {
  my ($self) = @_;
  my $config = $self->co;
  my $e0_max = $config->default("warnings", "e0_max");
  my $this = abs($self->e0_value);
  return (1, q{}) if ($e0_max == 0);
  return (1, q{}) if ($this < $e0_max);
  my $id = $self->identity;
  return (0, sprintf("The absolute value of e0 for \"$id\" is greater than %s.", $e0_max));
};

sub test_s02 {
  my ($self) = @_;
  my $config = $self->co;
  my $this = $self->s02_value;
  my $id = $self->identity;
  return (0, "S02 for \"$id\" is negative.")
    if ($config->default("warnings", "s02_neg") and ($this < -1*$EPSILON5));
  return (1, q{}) if ($config->default("warnings", "s02_max") == 0);
  ## return(0, "Too big") if too big
  ## return(0, "Too small") if too small
  return (1, q{});
};

sub test_sigma2 {
  my ($self) = @_;
  my $config = $self->co;
  my $this = $self->sigma2_value;
  my $id = $self->identity;
  return (0, "sigma2 for \"$id\" is negative.")
    if ($config->default("warnings", "ss2_neg") and ($this < -1*$EPSILON5));
  return (1, q{}) if ($config->default("warnings", "ss2_max") == 0);
  return (0, "sigma2 for \"$id\" is suspiciously large.")
    if ($this > $config->default("warnings", "ss2_max"));
  return (1, q{});
};

sub test_delr {
  my ($self) = @_;
  my $config = $self->co;
  my $this = abs($self->delr_value);
  my $id = $self->identity;
  return (0, "delr for \"$id\" is suspiciously large.") 
    if ($this > $config->default("warnings", "dr_max"));
  return (1, q{});
};

sub test_third {
  my ($self) = @_;
  my $this = $self->third_value;
  my $id = $self->identity;
  return (1, q{});
};

sub test_fourth {
  my ($self) = @_;
  my $this = $self->fourth_value;
  my $id = $self->identity;
  return (1, q{});
};


1;


=head1 NAME

Demeter::Path::Sanity - Sanity checks for path parameter values

=head1 VERSION

This documentation refers to Demeter version 0.9.23.

=head1 SYNOPSIS

  my ($isok, $reason) = $pathobject -> is_reasonable("e0");
  print $reason if (not $is_ok);

     ==> The absolute value of e0 for "path label" is greater than 10 ev

=head1 DESCRIPTION

This module provides a series of rules for determining the
appropriateness of fitted path parameter values.  These rules are all
configurable, but tend to be checks on the magnitude and/or parity of
the evaluated parameter.  See the warnings configuration group.

The user should never need to call the methods explicitly since they
are called automatically whenever a fit or a sum is performed.
However they are documented here so that the scope of such checks made
is clearly understood.

These rules are among the criteria used to evaluate the fit happiness.
See <Demeter::Fit::Happiness>.

=head1 METHODS

Test are made on the reasonableness of the C<e0>, C<s02>, C<delr>,
C<sigma2>, C<ei>, C<third>, and C<fourth> path parameters, as defined
by the warnings configuration group.

The only method intended for external use is C<is_reasonable>, as
shown in the L</SYNOPIS>.  It returns a two-element list, the first
element being a flag indicating whether the path parameter passed its
tests and the second being an explanation of the problem, if one is
found.

=head1 CONFIGURATION AND ENVIRONMENT

See L<Demeter::Config> for a description of the configuration system.
See the warnings configuration group.

=head1 DEPENDENCIES

Demeter's dependencies are in the F<Build.PL> file.

=head1 BUGS AND LIMITATIONS

Please report problems to the Ifeffit Mailing List
(L<http://cars9.uchicago.edu/mailman/listinfo/ifeffit/>)

Patches are welcome.

=head1 AUTHOR

Bruce Ravel (L<http://bruceravel.github.io/home>)

L<http://bruceravel.github.io/demeter/>


=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2015 Bruce Ravel (L<http://bruceravel.github.io/home>). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
