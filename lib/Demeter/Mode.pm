package Ifeffit::Demeter::Mode;
use Moose;
use Ifeffit::Demeter::Config;
use Ifeffit::Demeter::StrTypes qw( Empty
				   TemplateProcess
				   TemplateFit
				   TemplatePlot
				   TemplateFeff
				   TemplateAnalysis
				);
use Regexp::List;
use Regexp::Optimizer;
my $opt = Regexp::List->new;

## -------- disposal modes
has 'ifeffit' => (is => 'rw', isa => 'Bool',         default => 1);
has $_        => (is => 'rw', isa => 'Bool',         default => 0)   foreach (qw(screen plotscreen repscreen));
has $_        => (is => 'rw', isa => 'Str',          default => q{}) foreach (qw(file plotfile repfile));
has 'buffer'  => (is => 'rw', isa => 'ArrayRef|Str', default => q{});

## -------- default objects for templates
has 'config'   => (is => 'rw', isa => 'Any');  #         Ifeffit::Demeter::Config);
has 'plot'     => (is => 'rw', isa => 'Any');  #         Ifeffit::Demeter::Plot);
has 'fit'      => (is => 'rw', isa => 'Any');  # Empty.'|Ifeffit::Demeter::Fit');
has 'standard' => (is => 'rw', isa => 'Any');  # Empty.'|Ifeffit::Demeter::Data');
has 'theory'   => (is => 'rw', isa => 'Any');  # Empty.'|Ifeffit::Demeter::Feff');
has 'path'     => (is => 'rw', isa => 'Any');  # Empty.'|Ifeffit::Demeter::Path');

## -------- templates sets
has 'template_process'  => (is => 'rw', isa => 'TemplateProcess',  default => 'ifeffit');
has 'template_fit'      => (is => 'rw', isa => 'TemplateFit',      default => 'ifeffit');
has 'template_analysis' => (is => 'rw', isa => 'TemplateAnalysis', default => 'ifeffit');
has 'template_plot'     => (is => 'rw', isa => 'TemplatePlot',     default => 'pgplot');
has 'template_feff'     => (is => 'rw', isa => 'TemplateFeff',     default => 'feff6');
has 'template_test'     => (is => 'ro', isa => 'Str',              default => 'test');

## -------- The Professor and Mary Anne
has 'echo'		   => (is => 'rw', isa => 'Any');
has 'datadefault'	   => (is => 'rw', isa => 'Any');
has 'external_plot_object' => (is => 'rw', isa => 'Any');
has 'ui'                   => (is => 'rw', isa => 'Str', default => 'none',);

1;

=head1 NAME

Ifeffit::Demeter::Mode - Global attributes of the Demeter system

=head1 VERSION

This documentation refers to Ifeffit::Demeter version 0.2.

=head1 DESCRIPTION

This special object is used to store global attributes of the Demeter
system in a way that makes those attributes available to any Demeter
object.

Access to this object is via the C<get_mode> and C<set_mode> methods
of the Ifeffit::Demeter base class.  The convenience methods C<co> and
C<po> of the Ifeffit::Demeter base class are used to gain access to
the Config and Plot objects.  Any of these methods can be called by
any Demeter object:

  $to_screen = $data_object     -> get_mode('screen');
  $to_screen = $gds_object      -> get_mode('screen');
  $to_screen = $path_object     -> get_mode('screen');
  $to_screen = $scattering_path -> get_mode('screen');
  $to_screen = $prj_object      -> get_mode('screen');

=head1 ATTRIBUTES

=head2 Disposal modes

=over 4

=item C<ifeffit>

Dispose commands to Ifeffit when true.

=item C<screen>

Dispose commands to STDOUT when true.

=item C<plotscreen>

Dispose plotting commands to STDOUT when true.

=item C<repscreen>

Dispose reprocessed commands to STDOUT when true.

=item C<file>

Dispose commands to a file when a filename is given.

=item C<plotfile>

Dispose plotting commands to a file when a filename is given.

=item C<repfile>

Dispose reprocessed commands to a file when a filename is given.

=item C<buffer>

Dispose commands to a string or array when given a reference to a
string or array.

=back

=head2 Template objects

=over 4

=item C<config>

A reference to the singleton Config object.  C<$C> is the special
template variable.

=item C<plot>

A reference to the current Plot object.  C<$P> is the special
template variable.

=item C<fit>

A reference to the current Fit object.  C<$F> is the special
template variable.

=item C<standard>

A reference to the current Data object used a data processing
standard.  C<$DS> is the special template variable.

=item C<theory>

A reference to the current Feff object.  C<$T> is the special
template variable.

=item C<path>

A reference to the current Path object.  C<$PT> is the special
template variable.

=back

=head2 Template sets

=over 4

=item C<template_process>

The template set to use for processing data.

=item C<template_fit>

The template set to use for fitting data.

=item C<template_analysis>

The template set to use for analyzing mu(E) data.

=item C<template_plot>

The template set to use for plotting data.

=item C<template_feff>

The template set to use for writing F<feff.inp> files.

=item C<template_test>

A special template set used for testing Demeter.

=back

=head2 Other attributes

=over 4

=item echo

???

=item datadefault

This is a Data object used as a fallback.  For instance, one might
want to process and plot Path objects without having imported a Data
object.  This global attribute will be used in that case to properly
process and plot the Path.

=item external_plot_object

For plotting backends that have an objective interface, this global
attribute carried the refernece to that object.  For example, in the
gnuplot backend, this contains a reference to the
L<Graphics::GnuplotIF> object.

=item ui

This is a string identifying the user interface backend.  At this
time, its only use is to tell the Fit object to import the
curses-based methods in
L<Ifeffit::Demeter::UI::Screen::Interview> and
L<Ifeffit::Demeter::UI::Screen::Spinner>.

=back

=head1 DIAGNOSTICS

Moose type constraints are used on several of the GDS object
attributes.  Error messages appropriate to the type constrain will be
generated.

=head1 SERIALIZATION AND DESERIALIZATION

See the discussion of serialization and deserialization in
C<Ifeffit::Demeter::Fit>.

=head1 CONFIGURATION AND ENVIRONMENT

See L<Ifeffit::Demeter::Config> for a description of the configuration
system.

=head1 DEPENDENCIES

Demeter's dependencies are in the F<Bundle/DemeterBundle.pm> file.

=head1 BUGS AND LIMITATIONS

=over 4

=item *

Errors should be propagated into def parameters

=back

Please report problems to Bruce Ravel (bravel AT bnl DOT gov)

Patches are welcome.

=head1 AUTHOR

Bruce Ravel (bravel AT bnl DOT gov)

L<http://cars9.uchicago.edu/~ravel/software/>

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2008 Bruce Ravel (bravel AT bnl DOT gov). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
