package Demeter::Data::Beamlines;

=for Copyright
 .
 Copyright (c) 2006-2014 Bruce Ravel (bravel AT bnl DOT gov).
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

use File::Basename;
use File::Spec;
use Moose::Role;

has 'daq'      => (is => 'rw', isa => 'Str', default => q{});
has 'beamline' => (is => 'rw', isa => 'Str', default => q{});
has 'beamline_identified' => (is => 'rw', isa => 'Bool', default => 0);

my @known;
my $bldir = File::Spec->catfile(dirname($INC{"Demeter.pm"}), 'Demeter', 'Plugins', 'Beamlines');
opendir(my $BL, $bldir);
my @files = grep {/\.pm\z/} readdir $BL;
closedir $BL;
#print join("|", $bldir, @files), $/;
foreach my $pm (@files) {
  my $command = 'require Demeter::Plugins::Beamlines::'.basename($pm, '.pm');
  eval $command;
  push @known, 'Demeter::Plugins::Beamlines::'.basename($pm, '.pm') if (not $@);
};

sub identify_beamline {
  my ($self, $file) = @_;
  return $self if not Demeter->co->default('operations', 'identify_beamline');
  return $self if ((not -e $file) or (not -r $file));
  return $self if $self->beamline_identified;
  my $ok = 0;
  foreach my $class (@known) {
    $ok = $class->is($self, $file);
    last if $ok;
  };
  return $self;
};


1;

=head1 NAME

Demeter::Data::Beamlines - Role for identifying the beamline provenance of data

=head1 VERSION

This documentation refers to Demeter version 0.9.20.

=head1 DESCRIPTION

Using plugins found in F<Demeter/Plugins/Beamlines>, attempt to
identify the beamline of origin of the data file.  If identified,
attempt to glean metadata from the file header.

=head1 ATTRIBUTES

=over 4

=item C<daq> (string)

The name of the data acquisition program used to collect the data.

=item C<beamline> (string)

The designation of the beamline at which the data were collected.

=item C<beamline_identified> (boolean)

Set to true once the beamline has been positively identified.

=back

=head1 METHODS

There is only one method -- C<identify_beamline>.  This steps through
the plugins found in F<Demeter/Plugins/Beamlines>, each of which must
provide a method called C<is>.  Each plugin's C<is> method is called
in turn.  Once one returns a positive, metadata is set and this method
returns.

These checks can be completely disabled by setting the
C<operations->identify_beamline> configuration parameter to 0.

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
