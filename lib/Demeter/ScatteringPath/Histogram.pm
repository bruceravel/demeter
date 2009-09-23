package Demeter::ScatteringPath::Histogram;
use Moose::Role;

use Carp;
use List::Util qw(sum);
use Readonly;
Readonly my $EPSILON  => 0.00001;

sub make_histogram {
  my ($self, $rx, $ry, $common) = @_;
  my @paths = ();

  my $total = sum(@$ry);
  ##print $total, $/;
  my $rnot = $self->fuzzy;
  foreach my $i (0 .. $#{$rx}) {
    my $deltar = $rx->[$i] - $rnot;
    my $amp = $ry->[$i] / $total;
    my $this = Demeter::Path->new(sp     => $self,
				  delr   => $deltar,
				  degen  => $amp,
				  n      => 1,
				  parent => $self->feff,
				  @$common,
				 );
    $this -> make_name;
    $this -> name($this->name . " at " . sprintf("%.3f",$rx->[$i]));
    $this -> update_path(1);
    push @paths, $this;
  };

  return @paths;
};

sub histogram_from_file {
  my ($self, $fname, $xcol, $ycol, $rmin, $rmax) = @_;
  $xcol ||= 1;
  $ycol ||= 2;
  $rmin ||= 0;
  $rmax ||= 100;
  $xcol  -= 1;
  $ycol  -= 1;
  my (@x, @y);
  carp("$fname could not be imported as a histogram file"), return (\@x, \@y) if (not -e $fname);
  open(my $H, $fname);
  foreach my $line (<$H>) {
    chomp $line;
    next if ($line =~ m{\A\s*\z});
    next if ($line =~ m{\A[\#\*\%;]});
    my @list = split(" ", $line);
    next if ($list[$ycol] < $EPSILON);
    next if ($list[$xcol] < $rmin);
    next if ($list[$xcol] > $rmax);
    push @x, $list[$xcol];
    push @y, $list[$ycol];
  };
  close $H;

  return \@x, \@y;
};

sub histogram_from_function {
  my ($self, $string, $rmin, $rmax) = @_;
  my (@x, @y);
  ## use string to generate arrays in Ifeffit
  return \@x, \@y;
};

sub histogram_gamma {
  my ($self, $string, $rmin, $rmax) = @_;
  my (@x, @y);
  ## use string to generate arrays in Ifeffit
  return \@x, \@y;
};


1;

=head1 NAME

Demeter::ScatteringPath::Histogram - Arbitrary distribution functions

=head1 VERSION

This documentation refers to Demeter version 0.3.

=head1 SYNOPSIS

  my $feff = Demeter::Feff->new(yaml=>'some_feff.yaml');
  my @list_of_paths = @{ $feff->pathlist };
  my $firstshell = $list_of_paths[0];
  my ($rx, $ry) = $firstshell->histogram_from_file('RDFDAT20K', 1, 2, 2.5, 3.0);
  my @common = (s02 => 'amp', sigma2 => 'sigsqr', e0 => 'enot', data=>$data);
  my @paths = $firstshell -> make_histogram($rx, $ry, \@common);

=head1 DESCRIPTION

This role of the ScatteringPath object provides tools for generating
and parametering arbitrary distribution functions.

=head1 METHODS

=over 4

=item C<histogram_from_file>

Read data from a text file to define the distribution function.
Returns array references containing the x- and y-axis data.

  ($ref_r, $ref_y) = histogram_from_file($filename, $xcol, $ycol, $rmin, $rmax);

The arguments are the filename, the column numbers (counting from 1)
containing the R-grid and the amplitudes of the distributions, and the
minimum and maximum r-values to read from the file.

=item C<histogram_gamma>

Read data from a text file to define a gamma-like dsitribution function.

  unimplemented

=item C<make_histogram>

Given the array references from C<histogram_from_file> or
C<histogram_gamma>, return a list of Path objects defining the
historgram.

  @paths = $firstshell -> make_histogram($rx, $ry, \@common);

The caller is the ScatteringPath object used as the Feff calculation
for each bin in the histogram.  The first two arguments are the array
references.  The remaining arguments will be passed to each resulting
Path object.

=back

=head1 CONFIGURATION AND ENVIRONMENT

See L<Demeter::Config> for a description of the configuration
system.  The plot and ornaments configuration groups control the
attributes of the Plot object.

=head1 DEPENDENCIES


=head1 BUGS AND LIMITATIONS

=over 4

=item *

Need to implement Gamma-like function

=item *



=back

=head1 AUTHOR

Bruce Ravel (bravel AT bnl DOT gov)

L<http://cars9.uchicago.edu/~ravel/software/>


=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2009 Bruce Ravel (bravel AT bnl DOT gov). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut

