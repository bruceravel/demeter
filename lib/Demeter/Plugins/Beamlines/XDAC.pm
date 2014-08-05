package Demeter::Plugins::Beamlines::XDAC;

use File::Basename;
use File::Spec;


sub is {
  my ($class, $data, $file) = @_;
  return 0 if not ($INC{'Xray/XDI.pm'});
  open(my $fh, '<', $file);
  my $first = <$fh>;

  ## this IS an XDAC file
  if ($first =~ m{XDAC V(\d+)\.(\d+)}) {
    $data->xdi(Xray::XDI->new()) if not $data->xdi;
    if (exists $INC{'Xray/XDI.pm'}) {
      my $ver = (defined($Xray::XDI::VERSION)) ? $Xray::XDI::VERSION : '0';
      $data->xdi->xdi_version($ver);
    } else {
      $data->xdi->xdi_version('-1');
    };
    $data->xdi->extra_version(sprintf("XDAC/%s.%s", $1, $2));
    $data->xdi->set_item('Facility', 'name', 'NSLS');
    $data->xdi->set_item('Facility', 'source', 'bend magnet');

    my $flag = 0;
    my $remove_ifeffit_comments = 0;
  FILE: foreach my $li (<$fh>) {
      chomp $li;
      next if ($li =~ m{\A\s*\z});
      my @line = split(" ", $li);
    SWITCH: {

	## 1. identify defined XDI header: Scan.start_time
	## 2. set daq and beamline attributes of the Demeter::Data object
        ## 3. read metadata .ini file for the beamline
	($li =~ m{created on (\d+)/(\d+)/(\d+) at (\d+):(\d+):(\d+) ([AP])M on ([UX])-(\d+)([A-Z]?)(\d?)}) and do {
	  my $hour = ($7 eq 'A') ? $4 : $4+12;
	  my $year;
	  if (length($3)>2) {
	    $year=$3;
	  } else {
	    $year = ($3 < 80) ? 2000+$3 : 1900+$3;
	  };
	  my $time = sprintf("%d-%2.2d-%2.2d%s%2.2d:%2.2d:%2.2d", $year, $1, $2, 'T', $hour, $5, $6);
	  my $bl = lc(sprintf("%s%s%s%s", $8, $9, $10, $11));
	  $data->xdi->set_item('Scan', 'start_time', $time); # #1
	  $data->daq('xdac');				     # #2
	  $data->beamline($bl);
	  my $ini = join(".", 'xdac', $bl, 'ini');
	  my $inifile = File::Spec->catfile(dirname($INC{'Demeter.pm'}), 'Demeter', 'share', 'xdi', $ini);
	  $data->metadata_from_ini($inifile);                # #3
	  last SWITCH;
	};

	## bail out at the end of the header
	($li =~ m{\A\-{3,}}) and do {
	  last FILE;
	};

	## find the user comment section of the header, push each user comment line into the XDI comments
	($flag) and do {
	  $remove_ifeffit_comments = 1; # may want to set this to 1 once XDI is properly
                                        # integrated into Demeter.  will then need to fix
				        # clear_ifeffit_titles test in 004_data.t
	  $data->xdi->push_comment($li);
	  last SWITCH;
	};


	## find several defined header elements in the XDAC header
	($li =~ m{\ADiffraction element= (\w+)\s*([()0-9]+)}) and do {
	  $data->xdi->set_item('Mono', 'name', $1 . $2);
	  if ($li =~ m{Ring energy= (\d\.\d+) (\w+)}) {
	    $data->xdi->set_item('Facility', 'energy', $1 . " " . $2);
	  };
	  last SWITCH;
	};
	($li =~ m{\ARing energy= (\d\.\d+) (\w+)}) and do {
	  $data->xdi->set_item('Facility', 'energy', $1 . " " . $2);
	  last SWITCH;
	};
	($li =~ m{\AE0}) and do {
	  $data->xdi->set_item('Scan', 'edge_energy', $line[1]);
	  last SWITCH;
	};

	## put several useful and readily intepretable parts of the header into the XDAC family
	($li =~ m{\ANUM_REGIONS}) and do {
	  $data->xdi->set_item('XDAC', 'NUM_REGIONS', $line[1]);
	  last SWITCH;
	};
	($li =~ m{\ASRB}) and do {
	  $data->xdi->set_item('XDAC', 'SRB', join(", ", @line[1..$#line]));
	  last SWITCH;
	};
	($li =~ m{\ASRSS}) and do {
	  $data->xdi->set_item('XDAC', 'SRSS', join(", ", @line[1..$#line]));
	  last SWITCH;
	};
	($li =~ m{\ASPP}) and do {
	  $data->xdi->set_item('XDAC', 'SRSS', join(", ", @line[1..$#line]));
	  last SWITCH;
	};
	($li =~ m{\ASettling}) and do {
	  $data->xdi->set_item('XDAC', 'Settling_time', $line[2] . ' sec');
	  last SWITCH;
	};
	($li =~ m{\AOffsets}) and do {
	  $data->xdi->set_item('XDAC', 'Offsets', join(", ", @line[1..$#line]));
	  last SWITCH;
	};
	($li =~ m{\AGains}) and do {
	  $data->xdi->set_item('XDAC', 'Gains', join(", ", @line[1..$#line]));
	  $flag = 1;
	  last SWITCH;
	};



      };
    };
    close $fh;
    $data->clear_ifeffit_titles if ($remove_ifeffit_comments);
    $data->beamline_identified(1);
    return 1;


  ## this IS NOT an XDAC file
  } else {
    close $fh;
    return 0;
  };
};


1;


=head1 NAME

Demeter::Plugin::Beamlines::XDAC - beamline recognition plugin for files from various NSLS beamlines

=head1 VERSION

This documentation refers to Demeter version 0.9.20.

=head1 SYNOPSIS

This plugin recognizes files measured using XDAC, the data acquisition
program in use at several NSLS beamlines, including U7a, X3b, X11a,
X11b, X18b, X19a, X23a2, X23b, and X24a.  Once recognized, several
pieces of XDI metadata are set appropriate to the beamline.

See L<https://github.com/XraySpectroscopy/XAS-Data-Interchange>

=head1 Methods

A beamline plugin provides one (and only one) method.  This method
must be called C<is>.

This method is called like so:

    Demeter::Plugin::Beamlines::XDAC->is($data, $file);

where C<$data> is the Demeter::Data object that represents the data in
the file and C<$file> is the fully resolved filename of the file being
tested.

C<is> must perform the following chores:

=over 4

=item 1.

Very quickly recognize whether a file comes from the beamline.  Speed
is essential as every file will be checked sequentially against every
beamline plugin.  If a beamline plugin is slow to determine this, then
the use of Athena or other applications will be noticeably affected.

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

C<is> does B<not> read the data table, unless, I suppose, there is
semantic content in the data table intended to be interpreted as
metadata.  But ... ick ...!

=head1 Hints for plugin writers

=over 4

=item *

If possible, recognize the beamline by examination of the first line
of the file, as at lines 11 and 14.

=item *

Define an Xray::XDI object for use with the Demeter::Data object as
soon as possible.  See line 15.

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
call to C<$data->metadata_from_ini>, as at line 52.  The syntax is

    $data->metadata_from_ini($inifile);

where C<$inifile> is the name (but B<not> the fully resolved name) of
the .ini file in the F<share/xdi/> folder.

=back


=head1 AUTHOR

  Bruce Ravel <bravel@bnl.gov>
  http://bruceravel.github.io/demeter

=cut

