package Demeter::Plugins::10BMMultiChannel;  # -*- cperl -*-

use File::Basename;
use File::Copy;
use File::Spec;
use List::MoreUtils qw(firstidx);
use Readonly;
Readonly my $INIFILE => '10bmmultichannel.demeter_conf';

use Moose;
extends 'Demeter::Plugins::FileType';

my $demeter = Demeter->new();
has '+conffile'     => (default => File::Spec->catfile($demeter->dot_folder, $INIFILE));

has '+is_binary'   => (default => 0);
has '+description' => (default => 'the APS 10BM multi-channel detector');
has '+version'     => (default => 0.2);
has '+output'      => (default => 'project');
has 'edge_energy'  => (is => 'rw', isa => 'Num', default => 0);
has '+time_consuming'  => (default => 1);
has '+working_message' => (default => 'Converting multicolumn data file to an Athena project file');

Demeter -> co -> read_config(File::Spec->catfile(dirname($INC{'Demeter.pm'}), 'Demeter', 'Plugins', $INIFILE));

sub is {
  my ($self) = @_;
  open (my $D, $self->file) or $self->Croak("could not open " . $self->file . " as data (10BM multi-channel)\n");
  my $is_mx = (<$D> =~ m{\A\s*MRCAT_XAFS});
  while (<$D>) {
    $self->edge_energy($1) if (m{E0\s*=\s*(\d*)});
    last if (m{\A\s*-----});
  };
  my $is_mc = (<$D> =~ m{mcs\d{1,2}\s+mcs\d{1,2}\s+mcs\d{1,2}\s+mcs\d{1,2}\s+mcs\d{1,2}\s+mcs\d{1,2}\s+mcs\d{1,2}\s+mcs\d{1,2}});
  close $D;
  #print join("|",$is_xdac, $is_mc), $/;
  return ($is_mx and $is_mc);
};

sub fix {
  my ($self) = @_;

  my $file = $self->file;
  my $prj  = File::Spec->catfile($self->stash_folder, basename($self->file));

  ## -------- import the multi-channel data file
  my $mc = Demeter::Data::MultiChannel->new(file => $file, energy => '$1',);
  $mc->_update('data');

  ## -------- determine the temperature from the TC voltage at the edge
  my $temperature = 0;
  if (Demeter->co->default('10bmmultichannel', 'temperature_column')) {
    my @energy = $mc->get_array('nergy');
    my $iedge = firstidx {$_ > $self->edge_energy} @energy;
    my @temp = $mc->get_array(Demeter->co->default('10bmmultichannel', 'temperature_column'));
    $temperature = (@temp) ? sprintf("%dC", 200*($temp[$iedge]/100000 - 1)) : 0;
  };

  ## -------- make 4 mu(E) spectra
  ##          the name is a concatination of the file, the sample name, and T
  my @data = ($mc->make_data(numerator   => q{$}.Demeter->co->default('10bmmultichannel', 'numer1'),
			     denominator => q{$}.Demeter->co->default('10bmmultichannel', 'denom1'),
			     ln          => 1,
			     name        => join(" - ", basename($self->file), Demeter->co->default('10bmmultichannel', 'name1'), $temperature),
			     datatype    => Demeter->co->default('10bmmultichannel', 'type'),
			     bkg_eshift  => Demeter->co->default('10bmmultichannel', 'eshift1'),
			    ),
	      $mc->make_data(numerator   => q{$}.Demeter->co->default('10bmmultichannel', 'numer2'),
			     denominator => q{$}.Demeter->co->default('10bmmultichannel', 'denom2'),
			     ln          => 1,
			     name        => join(" - ", basename($self->file), Demeter->co->default('10bmmultichannel', 'name2'), $temperature),
			     datatype    => Demeter->co->default('10bmmultichannel', 'type'),
			     bkg_eshift  => Demeter->co->default('10bmmultichannel', 'eshift2'),
			    ),
	      $mc->make_data(numerator   => q{$}.Demeter->co->default('10bmmultichannel', 'numer3'),
			     denominator => q{$}.Demeter->co->default('10bmmultichannel', 'denom3'),
			     ln          => 1,
			     name        => join(" - ", basename($self->file), Demeter->co->default('10bmmultichannel', 'name3'), $temperature),
			     datatype    => Demeter->co->default('10bmmultichannel', 'type'),
			     bkg_eshift  => Demeter->co->default('10bmmultichannel', 'eshift3'),
			    ),
	      $mc->make_data(numerator   => q{$}.Demeter->co->default('10bmmultichannel', 'numer4'),
			     denominator => q{$}.Demeter->co->default('10bmmultichannel', 'denom4'),
			     ln          => 1,
			     name        => join(" - ", basename($self->file), Demeter->co->default('10bmmultichannel', 'name4'), $temperature),
			     datatype    => Demeter->co->default('10bmmultichannel', 'type'),
			     bkg_eshift  => Demeter->co->default('10bmmultichannel', 'eshift4'),
			    ),
	     );

  ## -------- import the reference channel if requested in the ini file
  if (Demeter->co->default('10bmmultichannel', 'reference')) {
    $data[4] = $mc->make_data(numerator   => q{$}.Demeter->co->default('10bmmultichannel', 'denom1').q{+$}.Demeter->co->default('10bmmultichannel', 'denom2').q{+$}.Demeter->co->default('10bmmultichannel', 'denom3').q{+$}.Demeter->co->default('10bmmultichannel', 'denom4'),
			      denominator => q{$}.Demeter->co->default('10bmmultichannel', 'denomref'),
			      ln          => 1,
			      name        => join(" - ", basename($self->file), Demeter->co->default('10bmmultichannel', 'nameref')),
			      datatype    => Demeter->co->default('10bmmultichannel', 'type'),
			     );
  };

  ## -------- write the project file and clean up
  my $journal = Demeter::Journal->new;
  $journal->text(join($/, $mc->get_titles));
  $mc->dispose("erase \@group ".$mc->group);
  $data[0]->write_athena($prj, @data, $journal);
  $_ -> DEMOLISH foreach (@data, $mc);

  $self->fixed($prj);
  return $prj;
};

sub suggest {
  ();
};

__PACKAGE__->meta->make_immutable;
1;

=head1 NAME

Demeter::Plugins::10BMMultiChannel - filetype plugin for 10BM multi-channel data files

=head1 SYNOPSIS

This plugin converts data from 10BM multi-channel ion chambers to an
Athena project file.  An inifile, F<10bmmultichannel.ini>
(found in F<$HOME/.horae> on unix, F<%APPDATA%\demeter> on Windows),
is used to set the column labels and to identify which columns belong
to which data channels.

=head1 METHODS

=over 4

=item C<is>

The multichannel file is recognized by finding C<MRCAT_XAFS> in the
first line and having 8 or more C<mcs> channels among the column
labels.

=item C<fix>

The column data file is converted into an Athena project file using
the L<Demeter::Data::MultiChannel> object.

=back

=head1 CONF FILE

Demeter ships with a demeter_conf file for configuring this plugin.

The energy shifts are measured by placing a foil in front of all four
channels and measuring the edge shift across the horizontal extent of
the beam.

=head2 Flags

=over 4

=item C<reference>

When true (i.e. set to 1), the reference channel will be processed.

=item C<temperature_column>

The column hearder for the scalar containing the temperature signal.

=item C<edge>

The edge energy of the element currently being measured.

=item C<type>

The datatype for the imported data.  The sensible values are C<xmu>
and C<xanes>.

=back

=head2 Names

=over 4

=item C<1>

The name given to the Data object for the first channel.  This is
used, for example, as the data group name in an Athena project.

=item C<2>

The name given to the Data object for the second channel.  This is
used, for example, as the data group name in an Athena project.

=item C<3>

The name given to the Data object for the third channel.  This is
used, for example, as the data group name in an Athena project.

=item C<4>

The name given to the Data object for the fourth channel.  This is
used, for example, as the data group name in an Athena project.

=item C<reference>

The name given to the Data object for the reference channel.  This is
used, for example, as the data group name in an Athena project.

=back

=head2 Numerator

=over 4

=item C<1>

The column label of the numerator of the first channel.

=item C<2>

The column label of the numerator of the the second channel.

=item C<3>

The column label of the numerator of the the third channel.

=item C<4>

The column label of the numerator of the the fourth channel.

=back

There is no C<reference> parameter in this section.  The sum of the
four denominator channels are used as the numerator of the reference.

=head2 Denominator

=over 4

=item C<1>

The column label of the denominator of the first channel.

=item C<2>

The column label of the denominator of the the second channel.

=item C<3>

The column label of the denominator of the the third channel.

=item C<4>

The column label of the denominator of the the fourth channel.

=item C<reference>

The column label of the denominator of the the reference channel.

=back

=head2 Eshift

At 10BM, geometry effects lead to a per-channel energy shift.  This is
determined by measuring a standard, say a foil, and aligning the
spectra.  These energy shifts are applied on the fly as the data are
imported.

=over 4

=item C<1>

The per-channel energy shift measured from a standard and applied to
channel 1.

=item C<2>

The per-channel energy shift measured from a standard and applied to
channel 2.

=item C<3>

The per-channel energy shift measured from a standard and applied to
channel 3.

=item C<4>

The per-channel energy shift measured from a standard and applied to
channel 4.

=back

=head1 BUGS AND SHORTCOMINGS

=over 4

=item *

Tie all four channels to a single reference (this is a Demeter
shortcoming, not a bug of this plugin).

=back

=head1 REVISIONS

=over 4

=item 0.2

Parse edge energy from file.  Remove energy shift as data are
imported, leaving bkg_eshift = 0 for each channel.

=item 0.1

Initial version

=back

=head1 AUTHOR

  Bruce Ravel <bravel@bnl.gov>
  http://xafs.org/BruceRavel

