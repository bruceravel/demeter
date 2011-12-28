package Demeter::Data::Beamlines;

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

use autodie qw(open close);

use File::Basename;
use Moose::Role;

has 'daq'      => (is => 'rw', isa => 'Str', default => q{});
has 'beamline' => (is => 'rw', isa => 'Str', default => q{});

sub identify_beamline {
  my ($self, $file) = @_;
  return $self if ((not -e $file) or (not -r $file));
  $self->is_xdac($file);
#    ||
#  $self->is_mx($file)
  return $self;
};

sub is_xdac {
  my ($self, $file) = @_;
  open(my $fh, '<', $file);
  my $first = <$fh>;

  ## this IS an XDAC file
  if ($first =~ m{XDAC V(\d+)\.(\d+)}) {
    $self->xdi_version("$Xray::XDI::VERSION");
    $self->xdi_applications(sprintf("XDAC/%s.%s", $1, $2));
    $self->set_xdi_facility('name', 'NSLS');
    $self->set_xdi_facility('xray_source', 'bend magnet');

    my $flag = 0;
    my $remove_ifeffit_comments = 0;
  FILE: foreach my $li (<$fh>) {
      chomp $li;
      next if ($li =~ m{\A\s*\z});
      my @line = split(" ", $li);
    SWITCH: {
	($line[0] =~ m{\AE0}) and do {
	  $self->set_xdi_scan('edge_energy', $line[1]);
	  last SWITCH;
	};

	($li =~ m{created on (\d+)/(\d+)/(\d+) at (\d+):(\d+):(\d+) ([AP])M on ([UX])-(\d+)([A-Z]?)(\d?)}) and do {
	  my ($hour) = ($7 eq 'A') ? $4 : $4+12;
	  my ($year) = ($3 < 80) ? 2000+$3 : 1900+$3;
	  my $time = sprintf("%d-%2.2d-%2.2d%s%2.2d:%2.2d:%2.2d", $year, $2, $1, 'T', $hour, $5, $6);
	  my $bl = lc(sprintf("%s%s%s%s", $8, $9, $10, $11));
	  $self->set_xdi_scan('start_time', $time);
	  $self->daq('xdac');
	  $self->beamline($bl);
	  my $ini = join(".", 'xdac', $bl, 'ini');
	  my $inifile = File::Spec->catfile(dirname($INC{'Demeter.pm'}), 'Demeter', 'share', 'xdi', $ini);
	  $self->configure_from_ini($inifile);
	  last SWITCH;
	};

	($line[0] =~ m{\ANUM_REGIONS}) and do {
	  $self->push_xdi_extension('XDAC.NUM_REGIONS: ' . $line[1]);
	  last SWITCH;
	};

	($line[0] =~ m{\ASRB}) and do {
	  $self->push_xdi_extension('XDAC.SRB: ' . join(" ", @line[1..$#line]));
	  last SWITCH;
	};

	($line[0] =~ m{\ASRSS}) and do {
	  $self->push_xdi_extension('XDAC.SRSS: ' . join(" ", @line[1..$#line]));
	  last SWITCH;
	};

	($line[0] =~ m{\ASettling}) and do {
	  $self->push_xdi_extension('XDAC.Settling_time: ' . join(" ", $line[2]));
	  last SWITCH;
	};

	($line[0] =~ m{\AOffsets}) and do {
	  $self->push_xdi_extension('XDAC.Offsets: ' . join(" ", @line[1..$#line]));
	  last SWITCH;
	};

	($line[0] =~ m{\AGains}) and do {
	  $self->push_xdi_extension('XDAC.Gains: ' . join(" ", @line[1..$#line]));
	  $flag = 1;
	  last SWITCH;
	};

	($li =~ m{\A\-{3,}}) and do {
	  last FILE;
	};

	($flag) and do {
	  $remove_ifeffit_comments = 1;
	  $self->push_xdi_comment($li);
	  last SWITCH;
	};

      };
    };
    close $fh;
    $self->clear_ifeffit_titles if ($remove_ifeffit_comments);
    return 1;


  ## this IS NOT an XDAC file
  } else {
    close $fh;
    return 0;
  };
};

1;

=head1 NAME

Demeter::Data::Athena - Role for identifying the beamline provenance of data

=head1 VERSION

This documentation refers to Demeter version 0.9.

=head1 DESCRIPTION

=head1 ATTRIBUTES

=head1 METHODS

=head1 BUGS AND LIMITATIONS

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
