package Demeter::Plot::SingleFile;

=for Copyright
 .
 Copyright (c) 2006-2013 Bruce Ravel (bravel AT bnl DOT gov).
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

use autodie qw(open close);

use Moose;
extends 'Demeter::Plot';

has 'file'     => (is => 'rw', isa => 'Str',  default => q{});
has '+backend' => (default => q{singleplot});

has 'columns' => (
		    traits    => ['Array'],
		    is        => 'rw',
		    isa       => 'ArrayRef[Str]',
		    default   => sub { [] },
		    handles   => {
				  'add_columns'  => 'push',
				  'remove_columns'   => 'pop',
				  'clear_columns' => 'clear',
				 }
		   );
has 'labels' => (
		    traits    => ['Array'],
		    is        => 'rw',
		    isa       => 'ArrayRef[Str]',
		    default   => sub { [] },
		    handles   => {
				  'add_labels'  => 'push',
				  'remove_labels'   => 'pop',
				  'clear_labels' => 'clear',
				 }
		   );

after start_plot => sub {
  my ($self) = @_;
  $self->cleantemp;
  if ($self->mo->standard) {
    my $command = $self->template("plot", "start");
    $self->dispose($command, "plotting");
  };
  $self->lastplot(q{});
  return $self;
};

sub prep {
  my ($self, @rest) = @_;
  my %args = @rest;
  $args{standard} = $args{data} if not $args{standard};
  die "Missing filename in Demeter::Plot::SingleFile setup"               if (not $args{file});
#  die "Cannot write to filename in Demeter::Plot::SingleFile setup"       if (not -w $args{file});
  die "Missing standard in Demeter::Plot::SingleFile setup"               if (not $args{standard});
  die "Standard must be Demeter::Data in Demeter::Plot::SingleFile setup" if (ref($args{standard}) ne 'Demeter::Data');

  $args{space} = 'q' if (lc($args{space}) eq 'kq');
  $self->space($args{space}) if $args{space};
  $args{standard}->standard;
  $self->file($args{file});
  $self->start_plot;
  return $self;
};

override after_plot_hook => sub {
  my ($self, $data, $part) = @_;
  $part ||= q{};
  $self->add_columns($self->fetch_string('p___lot_string'));
  if ($part eq 'win') {
    $self->add_labels('window');
  } else {
    my $label = $data->name || $data->group;
    $label =~ s{[-,= \t]+}{_}g;
    $label .= "_fit"        if ($part eq 'fit');
    $label .= "_residual"   if ($part eq 'res');
    $label .= "_background" if ($part eq 'bkg');
    $label .= "_running"    if ($part eq 'run');
    $self->add_labels($label);
  };
  return $self;
};

override finish => sub {
  my ($self) = @_;
  my $command = $self->template("plot", "end");
  $self->dispose($command, "plotting");
  print "Wrote plot to \"".$self->file."\"\n" if ($self->mo->ui eq 'screen');
  return $self;
};

override end_plot => sub {
  my ($self) = @_;
  $self->cleantemp;
  return $self;
};


1;

=head1 NAME

Demeter::Plot::SingleFile - Sending a plot to a single file

=head1 VERSION

This documentation refers to Demeter version 0.9.16.

=head1 SYNOPSIS

This is used to send a plot to a single file for easy import into an
external plotting program.

  #!/usr/bin/perl
  use Demeter qw(:ui=screen);

  my $file = 'examples/data/fe.060';
  my $data = Demeter::Data->new(file=>$file,);
  $data -> set(fft_kmax    => 3,    fft_kmin  => 14,
	       bkg_spl2    => 18,
	       bkg_nor2    => 1800,
	       energy      => '$1',
	       numerator   => '$2',
	       denominator => '$3',
	       ln          => 1,
	      );

  ## set up the plot to output file
  $data->plot_with('singlefile');  # 1

  ## prep for the singlefile plot
  $data->po->prep(file=>"foo.dat", standard=>$data, space=>'k');

  ## prep is the same as doing the following
  #$data->standard;                 # 2
  #$data->po->space('k');           # 3
  #$data->po->file("foo.dat");      # 4
  #$data->po->start_plot;

  ## make a sequence of plots
  $data->po->set(kweight => 1, kmax => 17, space => 'k');
  $data->set(plot_multiplier => 5,   'y_offset'=>14, name=>'kw=1, scaled by 5');
  $data->plot;

  $data->po->kweight(2);
  $data->set(plot_multiplier => 1,   'y_offset'=>7,  name=>'kw=2, unscaled');
  $data->plot;

  $data->po->kweight(3);
  $data->set(plot_multiplier => 0.2, 'y_offset'=>0,  name=>'kw=3, scaled by 0.2');
  $data->plot;

  ## the finish method of the Demeter::Plot::SingleFile actually writes out the file
  $data->po->finish;               # 5

=head1 DESCRIPTION

This plotting backend does not work quite as transparently as the
other plotting backends.  In order to get the figure you actually want
written correctly to an output file, a bit more care is required than
for this than for other plotting backends.  The following steps
(marked by their numbers in the example above) must be taken when
using this plotting backend:

=over 4

=item 1.

You must use the C<plot_with> method to change to this plotting
backend.  You B<may not> use the C<:plotwith=> pragma at the top of
your script to generate a column data file -- you must explicitly
switch to this backend in the run-time part of your script.  If you
try to use the pragma, your script will fail with a confusing and
misleading error message.

Note that the C<start_plot> method gets called automatically when you
change plotting backends.

=item 2.

You B<must> set a data standard.  This is required to correctly set
the column containing the x-axis and is particularly important in
energy plots where some data might need to be interpolated onto the
correct grid.

=item 3.

It is a good idea to explicitly declare the plotting space before
calling C<start_plot>.  This is particularly true for kq plots, for
which you should set the space to C<q>.

=item 4.

You B<must> set the C<file> attribute to the name of the target output
file which will contain the data required to replicate the plot in
another program.  You should set this before starting to actually
generate the plot.

=item 2-4.

Alternately, you can use the C<prep> method of the SingleFile object
to do steps 2 through 4 in one swoop.

=item 5.

Calling the C<finish> method of the SingleFile backend is what
actually writes the output file to disk.

=back

In a GUI, of course, all these steps will be handled behind the
scenes.

=head1 BUGS AND LIMITATIONS

=over 4

=item *

markers and indicators

=item *

quadplot -- need to write out an 8 column file (e mu k chik r chir q chiq)

=item *

stddev and variance, filter, f1f2

=back

Please report problems to Bruce Ravel (bravel AT bnl DOT gov)

Patches are welcome.

=head1 AUTHOR

Bruce Ravel (bravel AT bnl DOT gov)

L<http://bruceravel.github.com/demeter/>


=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2013 Bruce Ravel (bravel AT bnl DOT gov). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut

