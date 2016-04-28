package Demeter::Plugins::Beamlines::X11A;

use File::Basename;
use File::Spec;
use Demeter::Constants qw($HC);

my %months = (Jan=>1, Feb=>2, Mar=>3, Apr=>4, May=>5, Jun=>6, Jul=>7, Aug=>8, Sep=>9, Oct=>10, Nov=>11, Dec=>12);

sub is {
  my ($class, $data, $file) = @_;
  return 0 if not ($INC{'Xray/XDI.pm'});
  open(my $fh, '<', $file);
  my $first = <$fh>;

  ## this IS an XDAC file
  if ($first =~ m{NSLS/X11 EDC-(\d+)\.(\d+)}) {
    $data->xdi(Xray::XDI->new()) if not $data->xdi;
    if (exists $INC{'Xray/XDI.pm'}) {
      my $ver = (defined($Xray::XDI::VERSION)) ? $Xray::XDI::VERSION : '0';
      $data->xdi->xdi_version($ver);
    } else {
      $data->xdi->xdi_version('-1');
    };
    $data->xdi->extra_version(sprintf("EDC/%s.%s", $1, $2));
    $data->xdi->set_item('Facility', 'name',               'NSLS');
    $data->xdi->set_item('Facility', 'xray_source',        'bend magnet');
    $data->xdi->set_item('Beamline', 'collimation',        'none');
    $data->xdi->set_item('Beamline', 'focusing',           'none');
    $data->xdi->set_item('Beamline', 'harmonic_rejection', 'detuned mono');
    $data->xdi->set_item('Beamline', 'name',               'X11A');
    $data->xdi->set_item('Mono',     'name',               'Si(111)');
    $data->xdi->set_item('Mono',     'd_spacing',           3.134542);
    $data->xdi->set_item('Mono',     'stpdeg',              6400);

    if ($first =~ m{(\d+)-(\w{3})-(\d+)\s+(\d+):(\d+):(\d+)}) {
      my $year  = 1900+$3;
      my $month = $months{$2};
      my $day   = $1;
      my $time  = sprintf("%d-%2.2d-%2.2d%s%2.2d:%2.2d:%2.2d", $year, $month, $day, 'T', $4, $5, $6);
      $data->xdi->set_item('Scan', 'start_time', $time); # #1
    };
    if ($first =~ m{ENERGY=(\d)\.(\d+)}) {
      $data->xdi->set_item('Facility', 'energy', sprintf("%d.%d GeV", $1, $2));
    };

    my $second = <$fh>;
    chomp $second;
    $data->xdi->push_comment($second);


    my $flag = 0;
    my $remove_ifeffit_comments = 0;
  FILE: foreach my $li (<$fh>) {
      chomp $li;
      next if ($li =~ m{\A\s*\z});
      my @line = split(" ", $li);
    SWITCH: {

	($li =~ m{\AE0=\s+([\d.]+)}) and do {
	  $data->xdi->set_item('Scan', 'edge_energy', $1);
	  last SWITCH;
	};

	($li =~ m{HC/2D=\s+([\d.]+)\s+STPDEG=(\d+).*FOCUS=(\w)\s+TRANSLT=(\w)}) and do {
	  $data->xdi->set_item('Mono',     'd_spacing',         sprintf("%.6f", $HC/$1/2));
	  $data->xdi->set_item('Mono',     'stpdeg',            $2);
	  $data->xdi->set_item('Beamline', 'focusing',          Demeter->yesno($3));
	  $data->xdi->set_item('Beamline', 'table_translation', Demeter->yesno($4));
	  last SWITCH;
	};


	## put several useful and readily intepretable parts of the header into the XDAC family
	($li =~ m{\ASRB=}) and do {
	  $data->xdi->set_item('EDC', 'SRB', join(" ", @line[1..$#line]));
	  last SWITCH;
	};
	($li =~ m{\ADEL=}) and do {
	  $data->xdi->set_item('EDC', 'DEL', join(" ", @line[1..$#line]));
	  last SWITCH;
	};
	($li =~ m{\AGAINS}) and do {
	  $data->xdi->set_item('EDC', 'GAINS', join(" ", @line[1..$#line]));
	  last SWITCH;
	};
	($li =~ m{\AOFFSETS}) and do {
	  $data->xdi->set_item('EDC', 'OFFSETS', join(" ", @line[1..$#line]));
	  last FILE;
	};

      };
    };
    close $fh;
    $data->clear_ifeffit_titles if ($remove_ifeffit_comments);
    $data->beamline_identified(1);
    return 1;


  ## this IS NOT an X11A file
  } else {
    close $fh;
    return 0;
  };
};


1;


=head1 NAME

Demeter::Plugin::Beamlines::X11A - beamline recognition plugin for files from pre-XDAC X11A

=head1 VERSION

This documentation refers to Demeter version 0.9.25.

=head1 SYNOPSIS

This plugin recognizes files measured using EDC, the long-lost data
acquisition program at NSLS X11A.

For details about Demeter beamline recognition plugins, see
L<Demeter::Data::Beamlines>.

For information about the XAS Data Interchange format, see
L<https://github.com/XraySpectroscopy/XAS-Data-Interchange>


=head1 AUTHOR

  Bruce Ravel, L<http://bruceravel.github.io/home>
  http://bruceravel.github.io/demeter

=cut

