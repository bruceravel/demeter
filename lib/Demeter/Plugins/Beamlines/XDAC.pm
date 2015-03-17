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
    $data->xdi->set_item('Facility', 'xray_source', 'bend magnet');

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
	  $data->xdi->set_item('XDAC', 'SPP', join(", ", @line[1..$#line]));
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

This documentation refers to Demeter version 0.9.21.

=head1 SYNOPSIS

This plugin recognizes files measured using XDAC, the data acquisition
program in use at several NSLS beamlines, including U7a, X3b, X11a,
X11b, X18b, X19a, X23a2, X23b, and X24a.  Once recognized, several
pieces of XDI metadata are set appropriate to the beamline.

For details about Demeter beamline recognition plugins, see
L<Demeter::Data::Beamlines>.

For information about the XAS Data Interchange format, see
L<https://github.com/XraySpectroscopy/XAS-Data-Interchange>


=head1 AUTHOR

  Bruce Ravel, L<http://bruceravel.github.io/home>
  http://bruceravel.github.io/demeter

=cut

