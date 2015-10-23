package Demeter::Plugins::Beamlines::MX;

use File::Basename;
use File::Spec;

my %months = (Jan=>1, Feb=>2, Mar=>3, Apr=>4, May=>5, Jun=>6, Jul=>7, Aug=>8, Sep=>9, Oct=>10, Nov=>11, Dec=>12);


sub is {
  my ($class, $data, $file) = @_;
  return 0 if not ($INC{'Xray/XDI.pm'});
  open(my $fh, '<', $file);
  my $first = <$fh>;

  ## this IS an XDAC file
  if ($first =~ m{MRCAT_XAFS V(\d+)\.(\d+)}) {
    $data->xdi(Xray::XDI->new()) if not $data->xdi;
    if (exists $INC{'Xray/XDI.pm'}) {
      my $ver = (defined($Xray::XDI::VERSION)) ? $Xray::XDI::VERSION : '0';
      $data->xdi->xdi_version($ver);
    } else {
      $data->xdi->xdi_version('-1');
    };
    $data->xdi->extra_version(sprintf("MX/%s.%s", $1, $2));
    $data->xdi->set_item('Facility', 'name', 'APS');

    my $flag = 0;
    my $get_labels = 0;
    my $remove_ifeffit_comments = 0;
  FILE: foreach my $li (<$fh>) {
      chomp $li;
      next if ($li =~ m{\A\s*\z});
      my @line = split(" ", $li);
    SWITCH: {

	## 1. identify defined XDI header: Scan.start_time
	## 2. set daq and beamline attributes of the Demeter::Data object
        ## 3. read metadata .ini file for the beamline
	## 4. set the source to UA or BM as appropriate
        ##                                       1       2         3       4       5       6     7     8        9
	($li =~ m{created at APS (?:Sector)?\s*(\d+)-?(BM|ID) on (\w+)\s+(\w+)\s+(\d+)\s+(\d+):(\d+):(\d+)\s+(\d{4})}) and do {
	  my $year  = $9;
	  my $month = $months{$4}; # yep, they really do this...
	  my $day   = $5;
	  my $time  = sprintf("%d-%2.2d-%2.2d%s%2.2d:%2.2d:%2.2d", $year, $month, $day, 'T', $6, $7, $8);
	  $data->xdi->set_item('Scan', 'start_time', $time); # #1
	  $data->daq('MX');				     # #2
	  $data->beamline($1.$2);
	  my $ini = join(".", 'mx', lc($1.$2), 'ini');
	  my $inifile = File::Spec->catfile(dirname($INC{'Demeter.pm'}), 'Demeter', 'share', 'xdi', $ini);
	  $data->metadata_from_ini($inifile);                # #3
	  my $source = ($2 eq 'ID') ? 'undulator A' : 'bend magnet';
	  $data->xdi->set_item('Facility', 'xray_source', $source); # #4
	  last SWITCH;
	};

	## snarf column labels then bail out at the end of the header
	($li =~ m{\A\-{3,}}) and do {
	  $get_labels = 1;
	  last FILE;
	};

	($get_labels) and do {
	  my @list = split(" ", $li);
	  my $i = 0;
	  foreach my $l (@list) {
	    ++$i;
	    #Demeter->pjoin('Column', $i, $l);
	    $data->xdi->set_item('Column', $i, $l);
	  };
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


	## find several defined header elements in the MX header
	if ($li =~ m{\ARing energy= (\d\.\d+) (\w+)}) {
	  $data->xdi->set_item('Facility', 'energy', $1 . " " . $2);
	  last SWITCH;
	};
	($li =~ m{\AE0}) and do {
	  $data->xdi->set_item('Scan', 'edge_energy', $line[1]);
	  last SWITCH;
	};

	## put several useful and readily intepretable parts of the header into the XDAC family
	($li =~ m{\ANUM_REGIONS}) and do {
	  $data->xdi->set_item('MX', 'NUM_REGIONS', $line[1]);
	  last SWITCH;
	};
	($li =~ m{\ASRB}) and do {
	  $data->xdi->set_item('MX', 'SRB', join(", ", @line[1..$#line]));
	  last SWITCH;
	};
	($li =~ m{\ASRSS}) and do {
	  $data->xdi->set_item('MX', 'SRSS', join(", ", @line[1..$#line]));
	  last SWITCH;
	};
	($li =~ m{\ASPP}) and do {
	  $data->xdi->set_item('MX', 'SPP', join(", ", @line[1..$#line]));
	  last SWITCH;
	};
	($li =~ m{\ASettling}) and do {
	  $data->xdi->set_item('MX', 'Settling_time', $line[2] . ' sec');
	  last SWITCH;
	};
	($li =~ m{\AOffsets}) and do {
	  $data->xdi->set_item('MX', 'Offsets', join(", ", @line[1..$#line]));
	  last SWITCH;
	};
	($li =~ m{\AGains}) and do {
	  $data->xdi->set_item('MX', 'Gains', join(", ", @line[1..$#line]));
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

Demeter::Plugin::Beamlines::MX - beamline recognition plugin for files from APS Sector 10, MRCAT

=head1 VERSION

This documentation refers to Demeter version 0.9.24.

=head1 SYNOPSIS

This plugin recognizes files measured using MX from MRCAT, APS sector
10.  Once recognized, several pieces of XDI metadata are set
appropriate to the beamline.

For details about Demeter beamline recognition plugins, see
L<Demeter::Data::Beamlines>.

For information about the XAS Data Interchange format, see
L<https://github.com/XraySpectroscopy/XAS-Data-Interchange>

=head1 AUTHOR

  Bruce Ravel, L<http://bruceravel.github.io/home>
  http://bruceravel.github.io/demeter

=cut

