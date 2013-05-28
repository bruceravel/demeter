package Demeter::Plugins::X23A2MultiChannel;  # -*- cperl -*-

use File::Basename;

use Moose;
extends 'Demeter::Plugins::FileType';

has '+is_binary'   => (default => 0);
has '+description' => (default => 'the NSLS X23A2 multi-channel detector');
has '+version'     => (default => 0.1);
has '+output'      => (default => 'project');
has '+metadata_ini' => (default => File::Spec->catfile(File::Basename::dirname($INC{'Demeter.pm'}), 'Demeter', 'share', 'xdi', 'xdac.x23a2.ini'));

has 'n1'           => (is => 'rw', isa => 'Str',  default => '$2');
has 'n2'           => (is => 'rw', isa => 'Str',  default => '$3');
has 'n3'           => (is => 'rw', isa => 'Str',  default => '$4');
has 'n4'           => (is => 'rw', isa => 'Str',  default => '$5');

has 'd1'           => (is => 'rw', isa => 'Str',  default => '$6');
has 'd2'           => (is => 'rw', isa => 'Str',  default => '$7');
has 'd3'           => (is => 'rw', isa => 'Str',  default => '$8');
has 'd4'           => (is => 'rw', isa => 'Str',  default => '$9');

has 'ch1'          => (is => 'rw', isa => 'Str',  default => 'channel 1');
has 'ch2'          => (is => 'rw', isa => 'Str',  default => 'channel 2');
has 'ch3'          => (is => 'rw', isa => 'Str',  default => 'channel 3');
has 'ch4'          => (is => 'rw', isa => 'Str',  default => 'channel 4');

has 'reference'    => (is => 'rw', isa => 'Str',  default => 'reference');
has 'do_reference' => (is => 'rw', isa => 'Bool', default => 0);

has '+time_consuming'  => (default => 1);
has '+working_message' => (default => 'Converting multicolumn data file to an Athena project file');


sub is {
  my ($self) = @_;
  open (my $D, $self->file) or $self->Croak("could not open " . $self->file . " as data (X23A2 multi-channel)\n");
  my $is_xdac = (<$D> =~ m{\A\s*XDAC});
  while (<$D>) {
    last if (m{\A\s*-----});
  };
  my $is_mc = (<$D> =~ m{I01?\s+I02\s+I03\s+I04\s+It1\s+It2\s+It3\s+It4});
  close $D;
  #print join("|",$is_xdac, $is_mc), $/;
  return ($is_xdac and $is_mc);
};

sub fix {
  my ($self) = @_;

  my $file = $self->file;
  my $prj  = File::Spec->catfile($self->stash_folder, basename($self->file));

  my $mc = Demeter::Data::MultiChannel->new(file => $file, energy => '$1',);
  my @data = ($mc->make_data(numerator   => $self->n1,
			     denominator => $self->d1,
			     ln          => 1,
			     name        => $self->ch1,
			    ),
	      $mc->make_data(numerator   => $self->n2,
			     denominator => $self->d2,
			     ln          => 1,
			     name        => $self->ch2,
			    ),
	      $mc->make_data(numerator   => $self->n3,
			     denominator => $self->d3,
			     ln          => 1,
			     name        => $self->ch3,
			    ),
	      $mc->make_data(numerator   => $self->n4,
			     denominator => $self->d4,
			     ln          => 1,
			     name        => $self->ch4,
			    ),
	     );

  if ($self->do_reference) {
    $data[4] = $mc->make_data(numerator   => '$9',
			      denominator => '$10',
			      ln          => 1,
			      name        => $self->reference,
			     );
  };

  $self->dispense('process', 'erase', {items=>"\@group ".$mc->group});
  $data[0]->write_athena($prj, @data);
  $_ -> DEMOLISH foreach (@data, $mc);

  $self->fixed($prj);
  return $prj;
};

sub suggest {
  ();
};

sub add_metadata {
  my ($self, @data) = @_;
  foreach my $d (@data) {
    $d->is_xdac($self->file);
    $d->set_xdi_detector('i0', 'multichannel ionization chamber');
    $d->set_xdi_detector('it', 'multichannel ionization chamber');
  };
};


__PACKAGE__->meta->make_immutable;
1;

=head1 NAME

Demeter::Plugin::X23A2MultiChannel - filetype plugin for X23A2 multi-channel data files

=head1 VERSION

This documentation refers to Demeter version 0.9.17.

=head1 SYNOPSIS

This plugin converts data from X23A2 multi-channel ion chambers to an
Athena project file.

=head1 METHODS

=over 4

=item C<is>

The multichannel file is recognized by "XDAC" in the first header line and

  I0   I02  I03  I04  It1  It2  It3  It4

in that order as column headers.

=item C<fix>

The column data file is converted into an Athena project file using
the L<Demeter::Data::MultiChannel> object.

=back

=head1 BUGS AND SHORTCOMINGS

=over 4

=item *

Need to prompt for label columns

=item *

Tie all four channels

=item *

Prompt whether to import reference, whether to use all 4 It channels
in the numerator, tie reference to all four groups

=item *

Need a persistance file for label columns and reference

=back

=head1 REVISIONS

=over 4

=item 0.1

Initial version

=back

=head1 AUTHOR

  Bruce Ravel <bravel@bnl.gov>
  http://xafs.org/BruceRavel

=cut
