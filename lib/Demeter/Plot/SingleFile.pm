package Demeter::Plot::SingleFile;

=for Copyright
 .
 Copyright (c) 2006-2010 Bruce Ravel (bravel AT bnl DOT gov).
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
has '+backend' => (default => q{gnuplot});

has 'columns' => (
		    metaclass => 'Collection::Array',
		    is        => 'rw',
		    isa       => 'ArrayRef[Str]',
		    default   => sub { [] },
		    provides  => {
				  'push'  => 'add_columns',
				  'pop'   => 'remove_columns',
				  'clear' => 'clear_columns',
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
};

override plot_trigger => sub {
  my ($self, $data, $part) = @_;
  $self->add_columns(Ifeffit::get_string('p___lot_string'));
};

sub finish {
  my ($self) = @_;
  my $command = $self->template("plot", "end");
  $self->dispose($command, "plotting");
  ## write output file
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

This documentation refers to Demeter version 0.4.

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
  $data->plot_with('singlefile');
  $data->standard;
  $data->po->set(space => 'k');
  $data->po->start_plot;
  $data->po->file("foo.dat");

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
  $data->po->finish;

=head1 BUGS AND LIMITATIONS

Please report problems to Bruce Ravel (bravel AT bnl DOT gov)

Patches are welcome.

=head1 AUTHOR

Bruce Ravel (bravel AT bnl DOT gov)

L<http://cars9.uchicago.edu/~ravel/software/>


=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2010 Bruce Ravel (bravel AT bnl DOT gov). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut

