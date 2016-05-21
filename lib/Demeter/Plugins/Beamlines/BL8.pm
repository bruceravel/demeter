package Demeter::Plugins::Beamlines::BL8;

use File::Basename;
use File::Spec;

my %months = (Jan=>1, Feb=>2, Mar=>3, Apr=>4, May=>5, Jun=>6, Jul=>7, Aug=>8, Sep=>9, Oct=>10, Nov=>11, Dec=>12);

sub is {
  my ($class, $data, $file) = @_;
  return 0 if not ($INC{'Xray/XDI.pm'});
  open(my $fh, '<', $file);
  my $first = <$fh>;

  ## this IS an XDAC file
  if ($first =~ m{BL8: X-ray Absorption Spectroscopy}) {
    $data->xdi(Xray::XDI->new()) if not $data->xdi;
    $data->xdi->extra_version("SLRI/1");
    $data->xdi->set_item('Facility', 'name',               'SLRI');
    $data->xdi->set_item('Facility', 'xray_source',        'bend magnet');
    $data->xdi->set_item('Facility', 'energy',             '1.2 GeV');
    $data->xdi->set_item('Beamline', 'collimation',        'none');
    $data->xdi->set_item('Beamline', 'focusing',           'none');
    $data->xdi->set_item('Beamline', 'harmonic_rejection', 'none');
    $data->xdi->set_item('Beamline', 'name',               'BL8');
    $data->xdi->set_item('Detector', 'i0',                 'ionization chamber, N2+He');

    if ($ENV{XDIBL8} eq 'KTP') {
      $data->xdi->set_item('Mono', 'name',      'KTP(011)');
      $data->xdi->set_item('Mono', 'd_spacing',  10.955/2);
    } elsif ($ENV{XDIBL8} eq 'InSb') {
      $data->xdi->set_item('Mono', 'name',      'InSb(111)');
      $data->xdi->set_item('Mono', 'd_spacing',  7.481/2);
    } elsif ($ENV{XDIBL8} eq 'Si') {
      $data->xdi->set_item('Mono', 'name',      'Si(111)');
      $data->xdi->set_item('Mono', 'd_spacing',  6.271/2);
    } elsif ($ENV{XDIBL8} eq 'Ge') {
      $data->xdi->set_item('Mono', 'name',      'Ge(220)');
      $data->xdi->set_item('Mono', 'd_spacing',  4.001/2);
    } else {
      $data->xdi->set_item('Mono', 'name',      'Beryl(1010)');
      $data->xdi->set_item('Mono', 'd_spacing',  15.954/2);
    };

    my $date;
  FILE: foreach my $line (<$fh>) {
      $line =~ tr{\r}{}d;	# frickin' CRLF

    SWITCH: {
	($line =~ m{Siam Photon}) and do {
	  last SWITCH;
	};

	($line =~ m{\A\#?\s*Energy} ) and do {
	  my @list = split(" ", $line);
	  my $col = 1;
	  foreach my $item (@list) {
	    next if ($item =~ m{\#});
	    next if ($item =~ m{\(});
	    $data->xdi->set_item('Column', $col, $item);
	    ++$col;
	  };
	  last FILE;
	};

	($line =~ m{Experiment date}) and do {
	  my @list = split(/[, ]+/, $line);
	  my $month = $list[3];
	  $month = $months{ucfirst(substr($month,0,3))};
	  my $day   = $list[4];
	  my $year  = $list[5];
	  $date = sprintf("%4.4d-%2.2d-%2.2d", $year, $month, $day);
	  last SWITCH;
	};

	($line =~ m{Duration: (\d+:\d+:\d+) - (\d+:\d+:\d+)}) and do {
	  $data->xdi->set_item('Scan', 'start_time', sprintf("%sT%s", $date, $1));
	  $data->xdi->set_item('Scan', 'end_time',   sprintf("%sT%s", $date, $2));
	  last SWITCH;
	};

	($line =~ m{E0 \(eV\) = (\d+)}) and do {
	  $data->xdi->set_item('Scan', 'edge_energy', $1 . ' eV');
	  last SWITCH;
	};

	($line =~ m{Photon Energy Scan}) and do {
	  my @list = split(/\s+=\s+/, $line);
	  $data->xdi->set_item(q{SLRI}, 'scan', $list[1]);
	  last SWITCH;
	};

	($line =~ m{Photon Energy Step}) and do {
	  my @list = split(/\s+=\s+/, $line);
	  $data->xdi->set_item('SLRI', 'step', $list[1]);
	  last SWITCH;
	};

      	($line =~ m{Time Step}) and do {
	  my @list = split(/\s+=\s+/, $line);
	  $data->xdi->set_item('SLRI', 'time', $list[1]);
	  last SWITCH;
	};

      	($line =~ m{Gain}) and do {
	  my @list = split(/\s+=\s+/, $line);
	  $data->xdi->set_item('SLRI', 'gains', $list[1]);
	  last SWITCH;
	};

      	($line =~ m{Points/scan}) and do {
	  my @list = split(/\s+=\s+/, $line);
	  $data->xdi->set_item('SLRI', 'points', $list[1]);
	  last SWITCH;
	};

      	($line =~ m{Ar K edge step size}) and do {
	  my @list = split(/\s+=\s+/, $line);
	  $data->xdi->set_item('SLRI', 'arstep', $list[1]);
	  last SWITCH;
	};

      	($line =~ m{Transmission-mode}) and do {
	  $data->xdi->set_item('Detector', 'it', 'ionization chamber, N2+He');
	  last SWITCH;
	};

      	($line =~ m{Si Drift}i) and do {
	  $data->xdi->set_item('Detector', 'if', '4 element silicon drift');
	  last SWITCH;
	};

      	($line =~ m{Ge 13-array}i) and do {
	  $data->xdi->set_item('Detector', 'if', '13 element Ge');
	  last SWITCH;
	};

      };
    };

    close $fh;
    $data->clear_ifeffit_titles; # if ($remove_ifeffit_comments);
    $data->beamline_identified(1);
    return 1;


  ## this IS NOT an BL8 file
  } else {
    close $fh;
    return 0;
  };
};


1;


=head1 NAME

Demeter::Plugin::Beamlines::BL8 - beamline recognition plugin for files from SLRI BL8

=head1 VERSION

This documentation refers to Demeter version 0.9.25.

=head1 SYNOPSIS

This plugin recognizes files measured at SLRI BL8.

For details about Demeter beamline recognition plugins, see
L<Demeter::Data::Beamlines>.

For information about the XAS Data Interchange format, see
L<https://github.com/XraySpectroscopy/XAS-Data-Interchange>


=head1 AUTHOR

  Bruce Ravel, L<http://bruceravel.github.io/home>
  http://bruceravel.github.io/demeter

=cut

