package Demeter::Plugins::UOP;  # -*- cperl -*-

use File::Basename;
use File::Copy;
use File::Spec;
use List::MoreUtils qw(firstidx);

use Moose;
extends 'Demeter::Plugins::FileType';

#####################################################################################
## ADD NEW COLUMN LABELS FOR THE TEMPERATURE CHANNEL HERE ---+
##                                                           |
##                                                           |
has 'columns'      => (is => 'rw', isa => 'ArrayRef',     #  /
		       default => sub{ [qw(
					    tc_mcs
					    mcs10
					    Temp
					    scaler6
					    scaler10
					 )] }
		      );
#####################################################################################

use Demeter::StrTypes qw(Edge Element);

has '+is_binary'   => (default => 0);
has '+description' => (default => 'UOP files with temperature columns');
has '+version'     => (default => 0.2);
has '+display_new' => (default => 1);

sub is {
  my ($self) = @_;
  my $column_regex = join('|', @{$self->columns});
  open (my $D, $self->file) or $self->Croak("could not open " . $self->file . " as data (UOP)\n");
  my $is_mx = (<$D> =~ m{\A\#?\s*MRCAT_XAFS}); # find  "MRCAT_XAFS" in the first line
  while (<$D>) {
    last if (m{\A\#?\s*-----});
  };
  my $next = <$D>;
  return 0 if not $next;
  my $is_uop = ($next =~ m{$column_regex}); # find a temperature column in the column labels
  close $D;
  return ($is_mx and $is_uop);
};

sub fix {
  my ($self) = @_;

  my $file = $self->file;
  my $new = File::Spec->catfile($self->stash_folder, $self->filename);

  ## -------- fetch the data
  my $this = Demeter::Data->new(file=>$file, energy=>'$1', numerator=>'$2', denominator=>'$3', ln=>1);
  $this->read_data;

  ## -------- determine the temperature from the TC voltage at the edge, fallback to 0 (-200 C)
  ##          use enforced element and edge, if available
  my $target = (is_Element(Demeter->dd->is_z) and is_Edge(Demeter->dd->is_edge))
    ? Xray::Absorption->get_energy( Demeter->dd->is_z, Demeter->dd->is_edge)
    : $this->e0;
  my @energy = $this->get_array('energy');
  my $iedge = firstidx {$_ > $target} @energy;
  my @temp;
  foreach my $c (@{$self->columns}) {
    @temp = $this->get_array($c);
    last if @temp;
  };
  my $temperature = (@temp) ? sprintf("%dC", 200*($temp[$iedge]/100000 - 1)) : 0;

  ## -------- write stash file with T in file name
  $new =~ s{\.[^\.]+\z}{_$temperature};
  copy($file, $new);
  $self->fixed($new);
  return $new;
};


sub suggest {
  my ($self, $which) = @_;
  $which ||= 'transmission';
  if ($which eq 'transmission') {
    return (energy      => '$1',
	    numerator   => '$2',
	    denominator => '$3',
	    ln          =>  1,);
  } else {
    return ();
  };
};

__PACKAGE__->meta->make_immutable;
1;


=head1 NAME

Demeter::Plugin::UOP - filetype plugin for appending temperature to a group label

=head1 VERSION

This documentation refers to Demeter version 0.9.26.

=head1 SYNOPSIS

This plugin reads a specially named column containing voltage from a
thermocouple and computes the temperature from the voltage value at
the edge energy.  This temperature is then put into the label in the
groups list.  No other pre-processing of the data is performed.

The temperature readings are stored in a column with one of these
labels:

=over 4

=item C<tc_mcs>

=item C<mcs10>

=item C<Temp>

=item C<scaler6>

=item C<scaler10>

=back

=head1 METHODS


=over 4

=item C<is>


The multichannel file is recognized by finding C<MRCAT_XAFS> in the
first line and having a column with one of the temperature reading
labels.

=item C<fix>

The column with the temperature reading is interpreted as a
thermocouple voltage.  The voltage at the edge energy (the tabulated
energy is used is Athena's enforced element and edge are specified) is
converted to a temperature.

Copy the file to the stash directory, renaming it according the
computed temperature.  In this way, the temperature finds its way into
the group list label.

=back

=head1 AUTHOR

  Bruce Ravel, L<http://bruceravel.github.io/home>
  http://bruceravel.github.io/demeter
  and Shelly Kelly from UOP

=cut
