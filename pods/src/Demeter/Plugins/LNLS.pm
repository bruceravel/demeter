package Demeter::Plugins::LNLS;  # -*- cperl -*-

use Moose;
extends 'Demeter::Plugins::FileType';

has '+is_binary'   => (default => 0);
has '+description' => (default => "XAS beamlines at the LNLS");
has '+version'     => (default => 0.1);
has 'is_transmission' => (is => 'rw', isa => 'Bool', default => 0);
has 'is_datetime'    => (is => 'rw', isa => 'Bool', default => 0);

use Carp;
use Scalar::Util qw(looks_like_number);


sub is {
  my ($self) = @_;
  open D, $self->file or $self->Croak("could not open " . $self->file . " as data (LNLS)");
  my $first = <D>;
  $self->is_datetime(1) if ($first =~ m{"Data"	"Hora"});
  while (<D>) {
    $self->is_datetime(1) if ($_ =~ m{\d\d/\d\d/\d\d\t\d\d:\d\d:\d\d});	#06/07/12	15:26:20
  };
  close D;
  return $self->is_datetime;
};



sub fix {
  my ($self) = @_;
  my $file = $self->file;

  my $new = File::Spec->catfile($self->stash_folder, $self->filename);
  ($new = File::Spec->catfile($self->stash_folder, "toss")) if (length($new) > 127);
  open D, $file or die "could not open $file as data (fix in LNLS)\n";
  open N, ">".$new or die "could not write to $new (fix in LNLS)\n";

  while (<D>) {
    if (/^"Data"\s*"Hora"/) {
      if (/"Fluorescencia"/) {
	$self->is_transmission(0);
      } else {
	$self->is_transmission(1);
      }
      my @list = split(" ", $_);
      print N "# ", join("  ", @list[2..$#list]), "\n";
	  #    $self->is_transmission(0);
    } else {
      chomp;
      my @line = split(" ", $_);
      shift @line; shift @line;
      foreach (@line) {
	if (isfloat($_)) { 
	  printf N "\t%.4f", $_;
	}
	else {
	  print N "\t",$_;
	};
      };
      print N "\n";
    };
  };
  close D;
  close N;
  $self->fixed($new);
  return $new;
};

sub suggest {
  my ($self, $which) = @_;
  $which ||= 'fluorescence';
  $which = 'transmission' if $self->is_transmission;
  if ($which eq 'transmission') {
    return (energy      => '$1',
	    numerator   => '$2',
	    denominator => '$3', 
	    ln          =>  1,);
  } else {
    return (energy      => '$1',
	    numerator   => '$5',
	    denominator => '$2',
	    ln          =>  0,);
  };
};


sub isfloat{

	my $val = shift;
    return $val =~ m/^\d+.\d+$/;
};



__PACKAGE__->meta->make_immutable;
1;
__END__

=head1 NAME

Demeter::Plugin::LNLS - Import data from the XAS beamlines at LNLS

=head1 VERSION

This documentation refers to Demeter version 0.9.21.

=head1 SYNOPSIS

This plugin makes an LNLS file readable by Athena by stripping the
first two columns from the data file.

=head1 Methods

=over 4

=item C<is>

Recognize the LNLS file by the first line, which contains the words
"Data" and "Hora" and by subsequent lines, which have dates and times
rather than nice, sensible numbers in the first two columns.

=item C<fix>

Strip the first two columns from the LNLS data file.

=back

=head1 ACKNOWLEDGMENTS

This module was written by Eric Breynaert and touched up by Bruce.

=head1 BUGS AND LIMITATIONS


=head1 AUTHOR

  Bruce Ravel, L<http://bruceravel.github.io/home>
  http://bruceravel.github.io/demeter
  Athena copyright (c) 2001-2015
