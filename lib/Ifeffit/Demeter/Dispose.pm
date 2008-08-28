package Ifeffit::Demeter::Dispose;

=for Copyright
 .
 Copyright (c) 2006-2008 Bruce Ravel (bravel AT bnl DOT gov).
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


use strict;
use warnings;
use Carp;
use Class::Std;
use Class::Std::Utils;
use Fatal qw(open close);
use Ifeffit;

{

  ##-----------------------------------------------------------------
  ## dispose commands to ifeffit and elsewhere
  sub dispose {
    my ($self, $command, $plotting) = @_;

    my %how = Ifeffit::Demeter->get_mode;
    Ifeffit::Demeter->set_mode({ echo=>q{} });
    my $echo_buffer = q{};

    $command  =~ s{\+ *-}{-}g; # suppress "+-" in command strings math expressions
    $command  =~ s{- *-}{+}g;  # suppress "--" in command strings math expressions
    ($command .= "\n") if ($command !~ /\n$/);

    ## spit everything to the screen
    if ($how{screen}) {
      local $| = 1;
      print STDOUT $command;
    };

    ## dump everything to a file
    if ($how{file}) {
      local $| = 1;
      open my $FH, ">".$how{file};
      print $FH $command;
      close $FH;
    };

    ## dump plot commands to a file
    if (($how{plotfile}) and $plotting) {
      local $| = 1;
      open my $FH, ">".$how{plotfile};
      print $FH $command;
      close $FH;
    };

    ## concatinate to a scalar buffer
    if (($how{buffer}) and (ref($how{buffer}) eq 'SCALAR')) {
      ${ $how{buffer} } .=  $command;
    };

    ## unknown buffer type
    if (    ($how{buffer})
	and (ref($how{buffer}) ne 'SCALAR')
        and (ref($how{buffer}) ne 'ARRAY')  ) {
      carp("Ifeffit::Demeter::Dispose: string mode value is not a scalar or array reference");
    };

    if ($plotting and ($how{template_plot} eq 'gnuplot')) {
      print $command;
      $how{external_plot_object}->gnuplot_cmd($command);
      $how{external_plot_object}->gnuplot_pause(-1);
      my $gather = $self->po->get("lastplot");
      $gather .= $command;
      $self -> po -> set({lastplot=>$gather});
      return 0;
    };

    ## don't bother reprocessing unless an output channel that
    ## requires looping over every line
    return 0 unless (
		       ($how{buffer} and (ref($how{buffer}) eq 'ARRAY'))
		     or $how{ifeffit}
		     or $how{repscreen}
		     or $how{repfile}
		    );

    my ($reprocessed, $eol) = (q{}, $/);
    foreach my $thisline (split(/\n/, $command)) {

      if (($how{buffer}) and (ref($how{buffer}) eq 'ARRAY')) {
	push @{ $how{buffer} },  $thisline;
      };

      ## this next bit of insanity is an ifeffit optimization.  it is
      ## considerably faster to have perl process multi-line commands
      ## into long (up to 2048 characters) individual commands than to
      ## use ifeffit and the swig wrapper. the point here is to
      ## recognize parens-bound commands and concatinate them onto a
      ## single line

      ## want to not waste time on this if the output mode is for feffit!!
      next if ($thisline =~ m{^\s*\#});
      next if ($thisline =~ m{^\s*$});

      $thisline =~ s{^\s+}{};
      $thisline =~ s{\s+$}{};
      $thisline =~ s{\s+=}{ =};
      my $re = $self->regexp("commands", 1);
      $eol = ($thisline =~ m{^$re\s*\(}) ? " " : $eol;
      $eol = $/ if ($thisline =~ m{\)$});
      $reprocessed .= $thisline . $eol;
    };

    ## send reprocessed command text to ifeffit
    ifeffit($reprocessed) if $how{ifeffit};

    ## send reprocessed command text to the screen
    print STDOUT $reprocessed if $how{repscreen};

    ## send reprocessed command text to a file
    if ($how{repfile}) {
      open my $FH, ">".$how{file};
      print $FH $reprocessed;
      close $FH;
    };
    Ifeffit::Demeter->set_mode({echo=>$echo_buffer});

    return 0;
  };

  sub plot_dispose {


  };


  sub nl {
    my ($self) = @_;
    $self->dispose("\n");
  };


  sub Reset {
    my ($self) = @_;
    $self->dispose("reset");
  };

  sub cursor {
    my ($self) = @_;
    $self->dispose("cursor(show, cross-hair)");
    return(Ifeffit::get_scalar("cursor_x"), Ifeffit::get_scalar("cursor_y"));
  };

  sub screen_echo {
    my ($self, $value) = @_;
    $self->dispose("set \&screen_echo = $value");
  };

};

1;


=head1 NAME

Ifeffit::Demeter::Dispose - Process Ifeffit and plotting command strings

=head1 VERSION

This documentation refers to Ifeffit::Demeter version 0.1.

=head1 SYNOPSIS

  Ifeffit::Demeter->set_mode({ifeffit=>1, buffer=>\@buffer, screen=>1});
  my $data_object = Ifeffit::Demeter::Data -> new();
  $data_object -> dispose($ifeffit_command);


=head1 DESCRIPTION

This module contains contains the dispose method, which is used to
dispatch Ifeffit command strings to various places.  This is part of
the base of all other objects in the Demeter system, thus any object
can dispose text.

The command strings which are handled by the C<dispose> method are
typically generated using the command templating system, which is
described in L<Ifeffit::Demeter/TEMPLATES>.

=head2 Reprocessed commands

Command strings are typically generated by Demeter in a manner which
is designed to be human readable.  Unfortunately, human-readable and
Ifeffit-efficient tend to be at odds.  In the interest of speed and
efficiency, Demeter processes Ifeffit commands into a form that is
harder for a human to read, but faster for Ifeffit to process.

The main change made to Ifeffit command strings is to concatinate
multi-line commands into a single line.  This significantly reduces
the number of calls to the C<iff_exec> function in Ifeffit, which
is one of the most time-consuming parts of the Demeter/Ifeffit stack.
Given that Ifeffit allows command strings to be as much as 2048
characters long, it is rare that an command generated by Demeter
cannot be handled in this way.

Also, the preprocessed text does not contain any lines that are only
whitespace or are entirely commented out.

=head1 METHODS

=head2 C<dispose>

This method dispatches command strings to various places.  Most
methods in the Demeter system generate text.  The intent is that you
accumulate text through successive method calls and the dispose of the
text using this method.  The method takes two arguments, a scalar
containing all the text that you have accumulates, and an optional
argument that, when true, indicates that the commands are specifically
plotting commands.

Demeter is very careful to segregate plotting commands from data
processing commands and to dispose of them separately.  This allows
transparent use of different plotting backends.  The C<ifeffit>
disposal channel is used to indicate disposal of commands either to
ifeffit or to another plotting backend.  That is, if you want to
dispose of plotting commands to a gnuplot process, you must have the
C<ifeffit> disposal channel enabled.

Use the C<set_mode> class method to establish the disposal channels.

   Ifeffit::Demeter->set_mode({ifeffit=>1, screen=>1, file=>0, buffer=>0});
   $dataobject -> dispose($commands);

There are several disposal channels:

=over 6

=item ifeffit

This channel sends reprocessed command strings to ifeffit for
processing.  The value of ifeffit in the hash is interpreted as a
boolean.  By default, this channel is on and all the rest are off.

=item screen

This channel sends command strings to standard output.  The value of
screen in the hash is interpreted as a boolean.

=item file

This channel send command strings to a file.  If the value of file
evaluates false, then this channel is not used.  If it is true, the
value is taken to be the name of the output file.  At this time, IO
control is extremely simple.  If you want to append command strings to
an existing file, simply append C<E<gt>> to the beginning of the file
name:

   # clobber foo and start a new file by that name
   Ifeffit::Demeter->set_mode({file=>"foo"});
   $dataobject -> dispose($commands);

   # append to foo
   Ifeffit::Demeter->set_mode({file=>">foo"});
   $dataobject -> dispose($commands);

=item plotfile

This behaves exactly like the C<file> parameter, but applies only to
commands disposed using the plotting flag.

=item buffer

This channel pushes each command line onto an in-memory buffer.  The buffer
can be either a string or an array.  The buffer attribute is a reference to
the scalar or array.

If a scalar reference is used, the scalar is treated as a string and each
command line is concatinated to the end of the string.

   $buffer = q{};
   Ifeffit::Demeter->set_mode({buffer=>\$buffer});
   $dataobject -> dispose($commands);
   print $buffer;

If an array reference is used, each command line is pushed onto the end of the
array.

   @buffer = ();
   Ifeffit::Demeter->set_mode({buffer=>\@buffer});
   $dataobject -> dispose($commands);
   map {print $_} @buffer;

=item repscreen

This channel sends reprocessed command strings to standard output.
The value of screen in the hash is interpreted as a boolean.  The main
use of this channel is to debug the text actually sent to Ifeffit.

=item repfile

This channel send reprocessed command strings to a file.  This channel
is handled in the same manner as the normal file channel.  The main
use of this channel is to debug the text actually sent to Ifeffit.

=back

=head2 other methods

=over 4

=item C<Reset>

This method sends the C<reset> command to ifeffit.  The method name is
capitalized to avoid confusion with the perl built-in function.

=item C<cursor>

This method sends the C<cursor> command to ifeffit with the C<show> and
C<cross-hair> arguments.  It returns the x and y coordinates of the
cursor click.

   my ($xclick, $yclick) = $object->cursor;

Note that this is a blocking operation.  Your program will pause until
a click event happens in the plot window.

=item C<screen_echo>

This method sets the value of the Ifeffit program variable
C<&screen_echo>.  When set to 1, Ifeffit writes its feedback to STDOUT

  $object -> screen_echo(1);

=back

=head1 OTHER USES OF set_mode

There are several other parameters that, like the ones that directly
control the disposal of commands, have a pervasive impact on the
operations of Demeter.  Also like the disposal parameters, these are
accessed via the C<set_mode> and C<get_mode> methods.

=over 4

=item C<echo>

I<What is this used for?>

=item C<plot>

This is a reference to the active Plot object, which is the one used
to format plots.  This is the object that should be modified to change
how a plot is made.  See L<Ifeffit::Demeter::Plot>.

=item C<params>

This is a reference to the active Config object, which is the one that
stores a wide variety of configration parameters.  See
L<Ifeffit::Demeter::Config>.

=item C<fit>

This is a reference to the active Fit object, which is accessed when
templates are evaluated to create commands for the fit.  See
L<Ifeffit::Demeter::Fit>.

=item C<standard>

This is a reference to the Data object chosen as the standard for
Athena-like methods.  This is used extensively by the templates.

=item C<theory>

This is a reference to the active Feff object, which is accessed when
template for feff input files are evaluated.

=item C<template_process> [ifeffit]

This is the template set used to generate data processing commands.

=item C<template_fit> [ifeffit]

This is the template set used to generate fitting commands.

=item C<template_plot> [pgplot]

This is the template set used to generate plotting commands.  There is
also an option to use the Gnuplot plotting backend by setting this
parameter to "gnuplot".

=item C<datadefault>

This is a fallback Data object that gets created when Demeter is first
loaded.  It is necessary so that Path objects can be manipulated and
plotted even if they are not yet associated with a Data object.

=back

=head1 CONFIGURATION

See L<Ifeffit::Demeter::Config> for a description of the configuration
system.

=head1 DEPENDENCIES

Demeter's dependencies are in the F<Bundle/DemeterBundle.pm> file.

=head1 BUGS AND LIMITATIONS

=over 4

=item *

Currently, nothing is done to capture feedback from Ifeffit.
This is a serious shortcoming.

=item *

The file and repfile disposal channels is handled in the most primitive
manner that remains functional.  It may be useful to consider using
IO::File or something similar.  Further, it is only possible to
specify a single file for this channel.  Something clever with "tee"
can be done to dispatch to multiple files.

=item *

The buffer disposal channel currently only works with normal
scalars and normal arrays.  It would be reasonable for a user to want
the buffer to be, say, a tied array or some particular object.  That
will be dealt with should it ever come up.

=item *

The screen and repscreen disposal channels currently writes to
STDOUT.  The user can direct STDOUT elsewhere.  It may be useful to
have the option of specifying a filehandle for this channel.

=back

Please report problems to Bruce Ravel (bravel AT bnl DOT gov)

Patches are welcome.

=head1 AUTHOR

Bruce Ravel (bravel AT bnl DOT gov)

L<http://cars9.uchicago.edu/~ravel/software/>


=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2008 Bruce Ravel (bravel AT bnl DOT gov). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
