package Demeter::LogRatio;

=for Copyright
 .
 Copyright (c) 2006-2014 Bruce Ravel (bravel AT bnl DOT gov).
 All rights reserved.
 .
 This file is free software; you can redistribute it and/or
 modify it under the same terms as Perl itself. See The Perl
 Artistic License.
 .
 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut

use Carp;

use Moose;
extends 'Demeter';

has '+name'         => (default => 'Log-Ratio/Phase-Difference' );
has 'standard'      => (is => 'rw', isa => 'Any',     default => q{},
			trigger => sub{ my($self, $new) = @_; $self->datagroup($new->group) if $new});
has 'standardgroup' => (is => 'rw', isa => 'Str',     default => q{});

has 'qmin'          => (is => 'rw', isa => 'LaxNum', default => 4);
has 'qmax'          => (is => 'rw', isa => 'LaxNum', default => 12);
has 'twopi'         => (is => 'rw', isa => 'Int',    default => 0);

has 'cumulants'     => (is => 'rw', isa => 'ArrayRef', default => sub{[]});
has 'errorbars'     => (is => 'rw', isa => 'ArrayRef', default => sub{[]});

sub BUILD {
  my ($self, @params) = @_;
  $self->mo->push_LogRatio($self);
  return $self;
};

sub fit {
  my ($self) = @_;
  foreach my $att (qw(fft_kmin fft_kmax fft_dk fft_kwindow
		      bft_rmin bft_rmax bft_dr bft_rwindow)) {
    $self->data->$att($self->standard->$att);
  };
  $self->data->_update('all');
  $self->standard->_update('all');

  $self->dispense("analysis", "lr_fit");
  my @cumulants = (sprintf("%.5f", $self->fetch_scalar("lr___pd0")),
		   sprintf("%.5f", $self->fetch_scalar("lr___pd1")),
		   sprintf("%.5f", $self->fetch_scalar("lr___pd2")),
		   sprintf("%.8f", $self->fetch_scalar("lr___pd3")),
		   sprintf("%.8f", $self->fetch_scalar("lr___pd4")));
  print join("|". @cumulants), $/;
  my @errorbars = (sprintf("%.5f", $self->fetch_scalar("delta_lr___pd0")),
		   sprintf("%.5f", $self->fetch_scalar("delta_lr___pd1")),
		   sprintf("%.5f", $self->fetch_scalar("delta_lr___pd2")),
		   sprintf("%.8f", $self->fetch_scalar("delta_lr___pd3")),
		   sprintf("%.8f", $self->fetch_scalar("delta_lr___pd4")));
  $self->cumulants(\@cumulants);
  $self->errorbars(\@errorbars);

  return $self;
};

sub report {
  my ($self) = @_;
  return $self->template("analysis", "lr_results", {cumulants=>$self->cumulants,
						    errorbars=>$self->errorbars});
};

sub plot_even {
  my ($self) = @_;
  $self->chart("plot", "lreven");
  return $self;
};

sub plot_odd {
  my ($self) = @_;
  $self->chart("plot", "lrodd");
  return $self;
};

sub save {
  my ($self, $fname) = @_;
  $fname ||= 'lrpd.dat';

  my $save_columns = {};
  my $text;
  if ($self->data->xdi) {
    $text = $self->template('analysis', 'lr_results');
    $save_columns  = $self->data->xdi->metadata->{Column};
    my $hash = {1=>'wavenumber invAng', 2=>'log ratio', 3=>'even fit', 4=>'phase difference', 5=>'odd fit'};
    $self->data->xdi_set_columns($hash);
  };

  $self->data->xdi_output_header('data', $text);
  $self->dispense("analysis", "lr_save", {file=>$fname});
  $self->data->xdi_set_columns($save_columns) if ($self->data->xdi);
  return $fname;
};

1;

=head1 NAME

Demeter::LogRatio - Log-ratio/phase-difference analysis

=head1 VERSION

This documentation refers to Demeter version 0.9.20.

=head1 SYNOPSIS

  #!/usr/bin/perl
  use Demeter qw(:ui=screen :plotwith=gnuplot);

  my $standard = Demeter::Data->new(file=>'../../data/fe.060.xmu', name => 'Fe 60K');
  my $data     = Demeter::Data->new(file=>'../../data/fe.300.xmu', name => 'Fe 60K');
  my $lrpd     = Demeter::LogRatio->new(standard=>$standard, data=>$data, qmax=>11);
  $lrpd->fit;
  print $lrpd->report;
  $lrpd->plot_odd;
  $lrpd->data->pause;

=head1 DESCRIPTION

Perform a log-ratio/phase difference analysis of two spectra in the
manner of “Application of the Ratio Method of EXAFS Analysis to
Disordered Systems”, G. Bunker, Nucl. Inst. Meth., 207, (1983)
p. 437-444.

=head1 ATTRIBUTES

=over 4

=item C<data>

The unknown Data object.

=item C<standard>

The standard Data object.

=item C<cumulants>

After the fit, this gets filled with a reference to an array of the
cumulants in order from zeroth to fourth.

=item C<errorbars>

After the fit, this gets filled with a reference to an array of the
uncertainties on the cumulants in order from zeroth to fourth.

=item C<qmin> [3]

The lower end in q of the fitting range.

=item C<qmax> [12]

The upper end in q of the fitting range.

=item C<twopi> [0]

Manually add an integer number of two-pi jumps to the phase-difference
spectrum.

=back

=head1 METHODS

=over 4

=item C<fit>

Perform the log-ratio and phase-difference fits.

  $lr -> fit;

Note that the forward and backward Fourier transform parameters of the
data are set to those of the standard before the fit is performed.
They are not restored, thus performing a fit might modify the
attributes of the unknown data.

=item C<report>

Return a text string reporting on the cumulant values.

  print $lr->report;

=item C<plot_even>

Make a plot of the log-ratio along with its polynomial fit.

  $lr->plot_even;

=item C<plot_odd>

Make a plot of the phase-difference along with its polynomial fit.

  $lr->plot_odd;

=back

=head1 SERIALIZATION AND DESERIALIZATION

Good question ...

=head1 CONFIGURATION AND ENVIRONMENT

See L<Demeter::Config> for a description of the configuration system.
See the lcf configuration group for the relevant parameters.

=head1 DEPENDENCIES

Demeter's dependencies are in the F<Build.PL> file.

=head1 BUGS AND LIMITATIONS

=over 4

=item *

Better error checking

=back

Please report problems to the Ifeffit Mailing List
(L<http://cars9.uchicago.edu/mailman/listinfo/ifeffit/>)

Patches are welcome.

=head1 AUTHOR

Bruce Ravel (bravel AT bnl DOT gov)

L<http://bruceravel.github.io/demeter/>


=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2014 Bruce Ravel (bravel AT bnl DOT gov). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut




