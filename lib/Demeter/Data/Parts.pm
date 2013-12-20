package Demeter::Data::Parts;
use Moose::Role;

use Demeter::StrTypes qw( DataPart FitSpace );

use Carp;

## parts are plotted and Fourier transformed just like their
## respective data, these methods just rewrite the data plot()
## fftf() or fftr() command using the group name of the part
sub part_fft {
  my ($self, $part) = @_;
  my $command = $self->_part_fft_command($part);
  #print $command;
  $self->dispose($command);
  return $self;
};
sub _part_fft_command {
  my ($self, $pt) = @_;
  my $part = ($pt eq 'sum') ? 'fit' : $pt; # sum is a synonym for fit
  croak('part_fft: valid parts are fit, res, and bkg') if (not is_DataPart($part));
  my $datagroup = $self->group;
  my $group = join("_", $datagroup, $part);
  my $string = $self->_fft_command;
  $string =~ s{\b$datagroup\b}{$group}g; # replace group names
  return $string;
};

sub part_bft {
  my ($self, $part) = @_;
  my $command = $self->_part_bft_command($part);
  $self->dispose($command);
  return $self;
};
sub _part_bft_command {
  my ($self, $pt) = @_;
  my $part = ($pt eq 'sum') ? 'fit' : $pt; # sum is a synonym for fit
  croak('part_bft: valid parts are fit, res, and bkg') if (not is_DataPart($part));
  my $datagroup = $self->group;
  my $group = join("_", $datagroup, $part);
  my $string = $self->_bft_command;
  $string =~ s{\b$datagroup\b}{$group}g; # replace group names
  return $string;
};

sub part_plot {
  my ($self, $part, $space) = @_;
  $self->part_fft($part) if (lc($space) ne 'k');
  $self->part_bft($part) if (lc($space) eq 'q');
  my $command = $self->_part_plot_command($part, $space);
  $self->dispose($command, "plotting");
  $self->po->after_plot_hook($self, $part);
  return $self;
};
sub _part_plot_command {
  my ($self, $pt, $space) = @_;
  my $pf           = $self->mo->plot;
  $pt            ||= q{};
  my $part         = ($pt eq 'sum') ? 'fit' : $pt; # sum is a synonym for fit
  croak('part_plot: valid parts are fit, res, and bkg') if (not is_DataPart($part));
  croak('part_plot: valid plot spaces are k, R, and q') if (not is_FitSpace($space));

  my $datagroup    = $self->group;
  my $group        = (is_DataPart($part)) ? join("_", $datagroup, $part) : $self->name;  ## huh?
  my %labels       = (bkg=>'background', fit=>$self->fitsum, res=>'residual');
#  $labels{$part} ||= $part->name;
  my $datalabel    = $self->name;

  $self->co->set(plot_part=>$part);
  my $string = $self->hashes;
  $string   .= (is_DataPart($part)) ? " plot $labels{$part} ___\n" : " plot path ___\n";
  my $plstring  = $self->_plot_command($space);
  $plstring  =~ s{\b$datagroup\b}{$group}g; # replace group names
  $string .= $plstring;

  #print $string  if ($part !~ /(?:bkg|fit|res)/);

  ## (?<+ ) is the positive zero-width look behind -- it only # }
  ## replaces the label when it follows q{key="}, i.e. it won't get
  ## confused by the same text in the title for a newplot
  if ($self->get_mode("template_plot") eq "pgplot") {
    $string =~ s{(?<=key=")$datalabel}{$labels{$part}} if ($datalabel);
  } elsif ($self->get_mode("template_plot") eq "gnuplot") {
    $string =~ s{(?<=title \")fit\"}{$labels{$part}\"};# if ($pt eq 'sum');
    $string =~ s{(?<=title \").*\"}{\"}     if ($datalabel =~ m{\A\s*\z});
  };

  $self->co->set(plot_part=>q{});
  $self->co->set(plot_part=>q{});
  return $string if (not is_DataPart($part));

  ## (?! ) is the negative zero-width look ahead -- it does not
  ## replace the group name when it is followed by k, r, or q
  $string =~ s{\b$self(?!\.[krq]\b)}{$group}g;
  return $string;
};

1;

=head1 NAME

Demeter::Data::Parts - Handle fit. background, and residual parts a fit

=head1 VERSION

This documentation refers to Demeter version 0.9.19.

=head1 METHODS

These methods generate processing command for the fit, background, and
residual parts of a fit using the processing parameters of the
associated Data object.

=over 4

=item C<part_fft>

Forward Fourier transform the fit, background, or residual part of the
data.

  $dataobject -> part_fft($which);

The argument is one of 'fit', 'bkg', or 'res'.

=item C<part_bft>

Backward Fourier transform the fit, background, or residual part of the
data.

  $dataobject -> part_bft($which);

The argument is one of 'fit', 'bkg', or 'res'.

=item C<part_plot>

Plot the fit, background, or residual part of the data.

  $dataobject -> part_plot($which);

The argument is one of 'fit', 'bkg', or 'res'.

=back

=head1 CONFIGURATION

See L<Demeter::Config> for a description of the configuration
system.

=head1 DEPENDENCIES

Demeter's dependencies are in the F<Bundle/DemeterBundle.pm> file.

=head1 BUGS AND LIMITATIONS

=over 4

=item *

Cromer-Liberman normalization is not yet implemented.

=item *

Something like the Penner-Hahn mxan would be nice also.

=item *

There is currently no mechanism for importing an array into Ifeffit
and associating an object with it.

=back

Please report problems to the Ifeffit Mailing List
(L<http://cars9.uchicago.edu/mailman/listinfo/ifeffit/>)

Patches are welcome.

=head1 AUTHOR

Bruce Ravel (bravel AT bnl DOT gov)

L<http://bruceravel.github.com/demeter/>

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2014 Bruce Ravel (bravel AT bnl DOT gov). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
