package Demeter::Get;

=for Copyright
 .
 Copyright (c) 2006-2013 Bruce Ravel (bravel AT bnl DOT gov).
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

use feature "switch";
use Moose::Role;
#use Ifeffit qw(ifeffit get_echo get_scalar get_array get_string put_scalar put_array put_string);

my $mode = Demeter->mo;

sub backend_name {
  my ($self) = @_;
  given ($mode->template_process) {

    when (/ifeffit|iff_columns/) {
      return 'Ifeffit';
    };

    when ('larch') {
      return 'Larch';
    };

  };
};

sub backend_id {
  my ($self) = @_;
  given ($mode->template_process) {

    when (/ifeffit|iff_columns/) {
      return "Ifeffit " . get_string('&build')
    };

    when ('larch') {
      return 1;
    };

  };
};

sub backend_version {
  my ($self) = @_;
  given ($mode->template_process) {

    when (/ifeffit|iff_columns/) {
      return (split(" ", Ifeffit::get_string('&build')))[0];
    };

    when ('larch') {
      return 1;
    };

  };
};

sub fetch_scalar {
  my ($self, $param) = @_;
  given ($mode->template_process) {

    when (/ifeffit|iff_columns/) {
      return Ifeffit::get_scalar($param);
    };

    when ('larch') {
      given ($param) {
	my $gp = $self->group || Demeter->mo->throwaway_group;
	when (/norm_c\d/) {
	  $param = $gp.'.'.$param;
	  return Larch::get_larch_scalar($param);
	}
	when (/epsilon_([kr])/) {
	  $param = $gp.'.epsilon_'.$1;
	  return Larch::get_larch_scalar($param);
	}
	when (/\A(?:e0|edge_step|kmax_suggest)\z/) {
	  $param = $gp.'.'.$param;
	  return Larch::get_larch_scalar($param);
	};
	when (/pre_(?:offset|slope)/) {
	  $param = $gp.'.'.$param;
	  return Larch::get_larch_scalar($param);
	}
	when (/(aa__)_(esh|scale)/) {
	  $param = $1.'.'.$2;
	  return Larch::get_larch_scalar($param);
	}
	default {
	  return Larch::get_larch_scalar($param);
	};
      }
    };

  };
};

sub fetch_string {
  my ($self, $param) = @_;
  $param =~ s{\A\$}{};
  given ($mode->template_process) {

    when (/ifeffit|iff_columns/) {
      return Ifeffit::get_string($param);
    };

    when ('larch') {
      given ($param) {
	when ('column_label') {
	  my $gp = ($self->attribute_exists('group') and $self->group) ? $self->group : Demeter->mo->throwaway_group;
	  $param = $gp.'.column_labels';
	  my $list = eval(Larch::get_larch_scalar($param));
	  return q{} if not $list;
	  return join(" ", @$list);
	}
	default {
	  return Larch::get_larch_scalar($param);
	};
      };
    };

  };
};

sub fetch_array {
  my ($self, $param) = @_;
  given ($mode->template_process) {

    when (/ifeffit|iff_columns/) {
      return Ifeffit::get_array($param);
    };

    when ('larch') {
      return Larch::get_larch_array($param);
    };

  };
};



sub toggle_echo {
  my ($self, $onoff) = @_;
  my $prior = 1;
  given ($mode->template_process) {

    when (/ifeffit|iff_columns/) {
      $prior = $self->fetch_scalar("\&screen_echo");
      $self->dispose("set \&screen_echo = $onoff\n");
      return $prior;
    };

    when ('larch') {
      return $prior;
    };

  };
};


sub echo_lines {
  my ($self, $param) = @_;
  my @lines = ();
  given ($mode->template_process) {

    when (/ifeffit|iff_columns/) {

      my $save = $self->fetch_scalar("\&screen_echo");
      $self->dispose("\&screen_echo = 0\nshow \@group ".$self->group);
      my $lines = $self->fetch_scalar('&echo_lines');
      $self->dispose("\&screen_echo = $save\n"), return () if not $lines;
      foreach my $l (1 .. $lines) {
	push @lines, Ifeffit::get_echo();
      };
      $self->dispose("\&screen_echo = $save\n") if $save;
      return @lines;
    };

    when ('larch') {
      return 1;
    };

  };
};


sub place_scalar {
  my ($self, $param, $value) = @_;
  given ($mode->template_process) {

    when (/ifeffit|iff_columns/) {
      Ifeffit::put_scalar($param, $value);
    };

    when ('larch') {
      Larch::put_larch_scalar($param, $value);
    };

  };
  return 1;
};

sub place_string {
  my ($self, $param, $value) = @_;
  given ($mode->template_process) {

    when (/ifeffit|iff_columns/) {
      Ifeffit::put_string($param, $value);
    };

    when ('larch') {
      Larch::put_larch_scalar($param, $value);
    };

  };
  return 1;
};

sub place_array {
  my ($self, $param, $arrayref) = @_;
  given ($mode->template_process) {

    when (/ifeffit|iff_columns/) {
      Ifeffit::put_array($param, $arrayref);
    };

    when ('larch') {
      Larch::put_larch_array($param, $arrayref);
    };

  };
  return 1;
};


1;



=head1 NAME

Demeter::Get - Choke point for probing Ifeffit, Larch, or other backends

=head1 VERSION

This documentation refers to Demeter version 0.9.16.

=head1 SYNOPSIS

  $number = $object -> fetch_scalar('foo');
  $string = $object -> fetch_string('bar');
  @array  = $object -> fetch_array('blah.x');

  $object -> place_scalar('foo', 5);
  $object -> place_string('bar', 'Fred');
  $object -> place_array('blah.x', \@list);

=head1 DESCRIPTION

This module provides a single choke point for retrieving data from
Ifeffit, Larch, or other data processing backeeeends.  Based on the
value of the Mode objects "template_process" attribute, the correct
thing will be done to obtain scalar, string, array, or other data from
the backend.

=head1 METHODS

=head2 Methods for getting data

=over 4

=item C<fetch_scalar>

Return a scalar value from a named variable in the backend's memory.

=item C<fetch_string>

Return a string value from a named variable in the backend's memory.

=item C<fetch_array>

Return an array value from a named variable in the backend's memory.
Note that this returns an array, not an array reference.

=back

=head2 Methods for putting data

=over 4

=item C<place_scalar>

Push a scalar value to a named variable the backend.

=item C<place_string>

Push a string value to a named variable the backend.

=item C<place_array>

Push an array value to a named variable the backend.  Note that this
takes an array reference as its argument.

=back

=head1 CONFIGURATION

See L<Demeter::Config> for a description of the configuration system.

=head1 DEPENDENCIES

Demeter's dependencies are in the F<Bundle/DemeterBundle.pm> file.

=head1 BUGS AND LIMITATIONS

=over 4

=item *

Demeter and feffit backends ...

=item *

Larch backend not written....

=back

Please report problems to Bruce Ravel (bravel AT bnl DOT gov)

Patches are welcome.

=head1 AUTHOR

Bruce Ravel (bravel AT bnl DOT gov)

L<http://cars9.uchicago.edu/~ravel/software/>


=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2013 Bruce Ravel (bravel AT bnl DOT gov). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
