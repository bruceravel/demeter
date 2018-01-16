package Demeter::Get;

=for Copyright
 .
 Copyright (c) 2006-2018 Bruce Ravel (http://bruceravel.github.io/home).
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

use Moose::Role;

my $mode = Demeter->mo;

sub backend_name {
  my ($self) = @_;
  if ($self->is_ifeffit) {
    return 'Ifeffit';
  } elsif ($self->is_larch) {
    return 'Larch';
  };
};

sub backend_id {
  my ($self) = @_;

  if ($self->is_ifeffit) {
    return "Ifeffit " . Ifeffit::get_string('&build')
  } elsif ($self->is_larch) {
    return $self->backend_name;
    #return "Larch " . Larch::get_larch_scalar('larch.__version__');
  };
};

sub backend_version {
  my ($self) = @_;
  if ($self->is_ifeffit) {
    return (split(" ", Ifeffit::get_string('&build')))[0];
  } elsif ($self->is_larch) {
    return 'X.xx';
    #return Larch::get_larch_scalar('larch.__version__');
  };
};

sub fetch_scalar {
  my ($self, $param) = @_;

  if ($self->is_ifeffit) {
    return Ifeffit::get_scalar($param);

  ## munge ifeffit parameter names to their larch equivalent
  } elsif ($self->is_larch) {
    my $gp = $self->group || Demeter->mo->throwaway_group;
    if ($param =~ m{norm_c\d}) {
      $param = $gp.'.pre_edge_details.'.$param;

    } elsif ($param =~ m{epsilon_([kr])}) {
      #if ($self->fit_group) {
      #	my $n = $self->fit_data-1;
      #	$param = join('.', $self->fit_group, 'datasets['.$n.']', 'epsilon_'.$1);
      #	return Larch::get_larch_array($param);
      #} else {
      $param = join('.', $self->group, 'epsilon_'.$1);

      #};
    } elsif ($param =~ m{r_factor}) {
      $param = $gp.'.params.rfactor';

    } elsif ($param =~ m{(?<!demlcf\.)(chi_reduced|chi_square)}) { # NOT the ones from an LCF fit!
      $param = $gp.'.params.'.$1;

    } elsif ($param =~ m{\A(?:e0|edge_step|kmax_suggest)\z}) {
      $param = $gp.'.'.$param;

    ## normalization parameters
    } elsif ($param =~ m{pre_(?:offset|slope)}) {
      $param = $gp.'.pre_edge_details.'.$param;

    ## auto-alignment parameter
    } elsif ($param =~ m{delta_(aa__)_(esh|scale)}) {
      $param = $1.'.'.$2.'.stderr';

    } elsif ($param =~ m{(aa__)_(esh|scale)\b}) {
      $param = $1.'.'.$2.'.value';

    } elsif ($param =~ m{delta_(aa__)_(esh|scale)}) {
      $param = $1.'.'.$2.'.stderr';

    ## log ratio/phase difference parameters
    } elsif ($param =~ m{\A(lr_)__(pd[024])}) {
      $param = $1.'e.'.$2.'.value';

    } elsif ($param =~ m{\A(lr_)__(pd[13])}) {
      $param = $1.'o.'.$2.'.value';

    } elsif ($param =~ m{delta_(lr_)__(pd[024])}) {
      $param = $1.'e.'.$2.'.stderr';

    } elsif ($param =~ m{delta_(lr_)__(pd[13])}) {
      $param = $1.'o.'.$2.'.stderr';

      ## exafs fitting parameters
    } elsif ($param =~ m{delta_(.+)}) {
      $param = join('.', 'gds', $1, 'stderr');

    } elsif ($param =~ m{\Ademlcf.+_(a|e|offset|slope)\z}) {
      $param .= '.value';

    } elsif ($param =~ m{\Adempeak\.\w+_\d\z}) {
      $param .= '.value';

    } elsif ($param =~ m{_p(\d+)\z}) {
      $param = 'dempcatt._p'.$1;

    } elsif ($param eq 'filter_top') {
      $param = "f1f2.$param";

    } elsif (Demeter->mo->fit) { # a fit is happenening, this is a Parameter, need its value
      if ($param !~ m{\.(?:value|stderr)\z}) {
	$param = $param.'.value';
      };
    }
    $param = Larch::get_larch_scalar($param);
    if (not defined $param) {
      $param = 0;
    } elsif (ref($param) eq 'ARRAY') { # not 100% sure this is needed
      $param = @{$param}[0];
    }
    return $param;
  };
};

sub denull {
  return 0 if $_[0] eq 'null';
  return $_[0];
};

sub fetch_string {
  my ($self, $param) = @_;
  $param =~ s{\A\$}{};
  if ($self->is_ifeffit) {
    return Ifeffit::get_string($param);

  } elsif ($self->is_larch) {
    if ($param eq 'column_label') {
      my $gp = ($self->attribute_exists('group') and $self->group) ? $self->group : Demeter->mo->throwaway_group;
      $param = $gp.'.column_labels';
      $self->dispose("show $param");
      my $list = Larch::get_larch_scalar($param);
      $list = eval($list) if ($list and ref($list) ne 'ARRAY');
      return q{} if not $list;
      return join(" ", @$list);
    } else {
      return Larch::get_larch_scalar($param);
    };
  };
};

sub fetch_array {
  my ($self, $param) = @_;
  if ($self->is_ifeffit) {
    return Ifeffit::get_array($param);
  } elsif ($self->is_larch) {
    #if ($param =~ m{pre\z}) {
    #  $param .= '_edge';
    #}elsif ($param =~ m{post\z}) {
    #  $param .= '_edge';
    #};
    return Larch::get_larch_array($param);
  };
};



sub toggle_echo {
  my ($self, $onoff) = @_;
  my $prior = 1;
  if ($self->is_ifeffit) {
    $prior = $self->fetch_scalar("\&screen_echo");
    $self->dispose("set \&screen_echo = $onoff\n");
    return $prior;
  } elsif ($self->is_larch) {
    return $prior;
  };
};


sub echo_lines {
  my ($self, $param) = @_;
  my @lines = ();
  if ($self->is_ifeffit) {
    my $save = $self->fetch_scalar("\&screen_echo");
    $self->dispose("\&screen_echo = 0\nshow \@group ".$self->group);
    my $lines = $self->fetch_scalar('&echo_lines');
    $self->dispose("\&screen_echo = $save\n"), return () if not $lines;
    foreach my $l (1 .. $lines) {
      push @lines, Ifeffit::get_echo();
    };
    $self->dispose("\&screen_echo = $save\n") if $save;
    return @lines;
  } elsif ($self->is_larch) {
    return 1;
  };
};


sub place_scalar {
  my ($self, $param, $value) = @_;
  if ($self->is_ifeffit) {
    Ifeffit::put_scalar($param, $value);
  } elsif ($self->is_larch) {
    Larch::put_larch_scalar($param, $value);
  };
  return 1;
};

sub place_string {
  my ($self, $param, $value) = @_;
  if ($self->is_ifeffit) {
    Ifeffit::put_string($param, $value);
  } elsif ($self->is_larch) {
    Larch::put_larch_scalar($param, $value);
  };
  return 1;
};

sub place_array {
  my ($self, $param, $arrayref) = @_;
  if ($self->is_ifeffit) {
    Ifeffit::put_array($param, $arrayref);
  } elsif ($self->is_larch) {
    print '>>>>', $param, $/;
    Larch::put_larch_array($param, $arrayref);
  };
  return 1;
};


sub header_strings {
  my ($self, @list) = @_;
  my $i = 1;
  if ($self->is_ifeffit) {	# ifeffit
    foreach my $line (@list) {
      ++$i;
      my $t = sprintf("%s%2.2d", 'dem_data_', $i);
      $self->place_string($t, $line);
    };
  } else {			# larch
    $self -> co -> set(headers => \@list);
    $self->dispense("process", "save_header");
  };
  return $self;
};



1;



=head1 NAME

Demeter::Get - Choke point for probing Ifeffit, Larch, or other backends

=head1 VERSION

This documentation refers to Demeter version 0.9.26.

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

Demeter's dependencies are in the F<Build.PL> file.

=head1 BUGS AND LIMITATIONS

=over 4

=item *

Demeter and feffit backends ...

=item *

Larch backend not written....

=back

Please report problems to the Ifeffit Mailing List
(L<http://cars9.uchicago.edu/mailman/listinfo/ifeffit/>)

Patches are welcome.

=head1 AUTHOR

Bruce Ravel, L<http://bruceravel.github.io/home>

L<http://bruceravel.github.io/demeter/>


=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2018 Bruce Ravel (L<http://bruceravel.github.io/home>). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
