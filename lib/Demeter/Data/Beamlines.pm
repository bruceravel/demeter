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

A beamline plugin provides one (and only one) method.  This method
must be called C<is>.

This method is called like so:

    Demeter::Plugin::Beamlines::MX->is($data, $file);

where C<$data> is the Demeter::Data object that represents the data in
the file and C<$file> is the fully resolved filename of the file being
tested.

Each C<is> method B<must> perform the following chores:

=over 4

=item 1.

B<Very quickly> recognize whether a file comes from the beamline.
Speed is essential as every file will be checked sequentially against
every beamline plugin.  If a beamline plugin is slow to determine
this, then the use of Athena or other applications will be noticeably
affected.

=item 2.

Recognize semantic content from the file header.  Where possible, map
this content onto defined XDI headers.  Other semantic content should
be placed into extension headers.

=item 3.

Add versioning information for the data acquisition program into the
XDI extra_version attribute.

=item 4.

Set the C<daq> and C<beamline> attributes of the Demeter::Data object
with the names of the data acquisition software and the designation of
the beamline.

=back

C<is> is not required to read the data table and is encouraged not to
do so.  Of course, if there is semantic content in the data table
intended to be interpreted as metadata, then it would be appropriate.
But ... ick ...!

=head1 Hints for plugin writers

=over 4

=item *

If possible, recognize the beamline by examination of the first line
(or first few lines) of the file.

=item *

Define an Xray::XDI object for use with the Demeter::Data object as
soon as possible, but after the bail-out point for a file that is not
from this beamline.

=item *

Use C<$data->xdi->set_item> to set a defined or extension header.  The
syntax is

    $data->xdi->set_item($family, $tag, $value);

Use defined fields wherever possible.

=item *

Use C<$data->xdi->push_comment> to push each user comment line onto
the XDi comment attribute.  The syntax is:

    $data->xdi->push_comment($comment_line);

where C<$comment_line> is free-form text and does B<not> end with an
end-of-line character.  The C<push_comment> method handles the
end-of-line character correctly for your computer.

=item *

Some metadata is constant for any file collected at a beamline.
Deposit an .ini file in Demeter's F<share/xdi/> folder and use it by a
call to C<$data->metadata_from_ini>.  The syntax is

    $data->metadata_from_ini($inifile);

where C<$inifile> is the fully resolved name of the .ini file, likely
in the F<share/xdi/> folder (but it can be anywhere).  That method
will fail gracefully if C<$inifile> does not exist.

=back

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
