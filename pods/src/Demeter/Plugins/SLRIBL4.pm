package Demeter::Plugins::SLRIBL4;  # -*- cperl -*-

use Moose;
extends 'Demeter::Plugins::FileType';

has '+is_binary'    => (default => 1);
has '+description'  => (default => "SLRI beamline 4");
has '+version'      => (default => 0.1);
has 'dxas'          => (is => 'rw', isa => 'Str', default => File::Spec->catfile(Demeter->dot_folder, 'athena.dxas'));
has '+metadata_ini' => (default => File::Spec->catfile(File::Basename::dirname($INC{'Demeter.pm'}),
						       'Demeter', 'share', 'xdi', 'slribl4.ini'));

sub is {
  my ($self) = @_;
  open D, $self->file or $self->Croak("could not open " . $self->file . " as data (SLRIBL4)\n");
  my $first = <D>;
  close D;
  return (($first =~ m{pixel}) and ($first =~ m{stripe}));
};


sub fix {
  my ($self) = @_;
  my $new = File::Spec->catfile($self->stash_folder, $self->filename);
  ($new = File::Spec->catfile($self->stash_folder, "toss")) if (length($new) > 127);

  my $pixel = Demeter::Data::Pixel->new(file=>$self->filename);
  my $hash  = YAML::Tiny::Load($self->slurp($self->dxas));
  $pixel->offset($hash->{offset});
  $pixel->linear($hash->{linear});
  $pixel->quadratic($hash->{quadratic});
  my $temp = $pixel->apply;
  $temp->points(file => $new, space => 'E', suffix => 'xmu',);
  $temp->DEMOLISH;
  $pixel->DEMOLISH;
  $self->fixed($new);
  return $new;
}

sub suggest {
  my ($self, $which) = @_;
  $which ||= 'transmission';
  if ($which eq 'transmission') {
    return (energy      => '$1',
	    numerator   => '$2',
	    denominator => '1',
	    ln          =>  0,);
  } else {
    return ();
  };
};


__PACKAGE__->meta->make_immutable;
1;
__END__


=head1 NAME

Demeter::Plugin::SLRIBL4 - filetype plugin for SLRI BL4 dispersive XAS data

=head1 VERSION

This documentation refers to Demeter version 0.9.18.

=head1 SYNOPSIS

This plugin directly imports files from SLRI beamline 4

=head1 Methods

=over 4

=item C<is>

Recognize data from SLRI BL4 by ....

=item C<fix>

Using the calibration parameters already found using Athena's
dispesive XAS tool (and stored on disk in an initialization file),
convert DXAS data from SLRI BL4 to an energy axis and write the mu(E)
result to a temporaray file in the stash folder.

=back

=head1 BUGS AND LIMITATIONS

=over 4

=item *

Need to make sure F<athena.dxas> exists and has useful values.

=back

=head1 AUTHOR

  Bruce Ravel <bravel@anl.gov>
  http://xafs.org/BruceRavel
