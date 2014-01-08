package Demeter::NumTypes;

# predeclare our own types
use MooseX::Types -declare => [qw( Natural
				   NaturalC
				   PosInt
				   OneToFour
				   OneToTwentyNine
				   Ipot
				   NegInt
				   PosNum
				   NegNum
				   NonNeg
				   FeffVersions
				)];

use MooseX::Types::Moose qw(Num Int Str);
use Scalar::Util qw( looks_like_number );

my $value_type = Moose::Util::TypeConstraints::find_type_constraint('Value');

subtype Natural,
  as Int,
  where { $_ >= 0 },
  message { "Int is not larger than or equal to 0" };

subtype NaturalC,
  as Int,
  where { $_ >= 0 },
  message { "Int is not larger than or equal to 0" };

coerce NaturalC,
  from Str,
  via sub{ int($_) };

subtype PosInt,
  as Int,
  where { $_ > 0 },
  message { "Int is not larger than 0" };

subtype OneToFour,
  as Int,
  where { $_ > 0 and $_ < 5 },
  message { "Int is not between 1 and 4, inclusive" };

subtype Ipot,
  as Int,
  where { ($_ > -1) and ($_ < 8) },
  message { "Int is not an ipot index (0 and 7, inclusive)" };

subtype OneToTwentyNine,
  as Int,
  where { $_ > 0 and $_ < 30 },
  message { "Int is between 1 and 29, inclusive" };

subtype NegInt,
  as Int,
  where { $_ < 0 },
  message { "Int is not smaller than 0" };

## this follows MooseX::Types::LaxNum.
## while it would be lovely to just define these "as 'LaxNum'",
## I cannot figure out how to do so without running afoul
## of the "WARNING: String found where Type expected" warning
subtype NonNeg,
  as Str,
  where { looks_like_number($_) and $_ >= 0 },
  message { "Num is not larger than or equal to 0" };
  # => inline_as {
  #   # the long Str tests are redundant here
  #   $value_type->_inline_check($_[1])
  #     . ' && Scalar::Util::looks_like_number(' . $_[1] . ')'
  #   };

subtype PosNum,
  as Str,
  where { looks_like_number($_) and eval{$_ > 0} } =>
  message { "Num is not larger than 0" };
  # => inline_as {
  #   # the long Str tests are redundant here
  #   $value_type->_inline_check($_[1])
  #     . ' && Scalar::Util::looks_like_number(' . $_[1] . ')'
  #   };

subtype NegNum,
  as Str,
  where { looks_like_number($_) and $_ < 0 },
  message { "Num is not smaller than 0" };
  # => inline_as {
  #   # the long Str tests are redundant here
  #   $value_type->_inline_check($_[1])
  #     . ' && Scalar::Util::looks_like_number(' . $_[1] . ')'
  #   };

subtype FeffVersions,
  as Int,
  where { $_ == 6 or $_ == 8 or $_ == 9 },
  message { "Int is not either 6 or 8 for FeffVersion" };

1;

=head1 NAME

Demeter::NumTypes - Numerical type constraints

=head1 VERSION

This documentation refers to Demeter version 0.9.19.

=head1 DESCRIPTION

This module implements numerical type constraints for Moose using
L<MooseX::Types>.

=head1 CONFIGURATION AND ENVIRONMENT

See L<Demeter::Config> for a description of the configuration system.

=head1 DEPENDENCIES

Demeter's dependencies are in the F<Build.PL> file.

=head1 BUGS AND LIMITATIONS

Please report problems to the Ifeffit Mailing List
(L<http://cars9.uchicago.edu/mailman/listinfo/ifeffit/>)

Patches are welcome.

=head1 AUTHOR

Bruce Ravel (bravel AT bnl DOT gov)

L<http://bruceravel.github.io/demeter/>

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2014 Bruce Ravel (bravel AT bnl DOT gov). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
