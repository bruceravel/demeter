package Demeter::Dispose;

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

use Moose::Role;

use Ifeffit;

use subs qw(BOLD BLACK RED GREEN YELLOW BLUE MAGENTA CYAN WHITE ON_RED RESET);
my $ANSIColor_exists = (eval "require Term::ANSIColor");
if ($ANSIColor_exists) {
  import Term::ANSIColor qw(:constants);
} else {
  ## this eval works when Term::ANSIColor is not available AND when running tests
  eval '
  sub BOLD    {q{}};
  sub BLACK   {q{}};
  sub RED     {q{}};
  sub GREEN   {q{}};
  sub YELLOW  {q{}};
  sub BLUE    {q{}};
  sub MAGENTA {q{}};
  sub CYAN    {q{}};
  sub WHITE   {q{}};
  sub ON_RED  {q{}};
  sub RESET   {q{}};';
};
sub _ansify {
  my ($self, $thisline, $kind) = @_;
  my ($start, $end) = (q{}, q{});

  my %color_of = (
		  black	  => BLACK,
		  red	  => RED,
		  green	  => GREEN,
		  yellow  => YELLOW,
		  blue	  => BLUE,
		  magenta => MAGENTA,
		  cyan	  => CYAN,
		  white	  => WHITE,
	       );
 COLOR:{
    ($kind eq 'comment') and do {
      if ($thisline =~ m{\A\#\#\|}) {
	($start, $end) = (BOLD.$color_of{$self->co->default("screen", "comment")}, RESET);
      } elsif ($thisline =~ m{\A\#\#\#__}) {
	($start, $end) = (BOLD.$color_of{$self->co->default("screen", "hashes" )}, RESET);
      } elsif ($thisline =~ m{\A\#}) {
	($start, $end) = (BOLD.$color_of{$self->co->default("screen", "other"  )}, RESET);
      };
      last COLOR;
    };
    ($kind eq 'feedback') and do {
      if ($thisline =~ m{\A\s*\*}) {
	print STDOUT WHITE, ON_RED, $thisline, RESET;
      } else {
	print STDOUT $color_of{$self->co->default("screen", "feedback")}, $thisline, RESET;
      };
    };
  };

  return ($start, $end);
};



##-----------------------------------------------------------------
## dispose commands to ifeffit and elsewhere
sub dispose {
  my ($self, $command, $plotting) = @_;
  return if not $command;

  $self->set_mode( echo=>q{} );
  my $echo_buffer = q{};

  $command  =~ s{\+ *-}{-}g; # suppress "+-" in command strings math expressions
  $command  =~ s{- *-}{+}g;  # suppress "--" in command strings math expressions
  return 0 if ($command =~ m{\A\s*\z});
  ($command .= "\n") if ($command !~ /\n$/);

  ## -------- spit everything to the screen, use ANSI colors if available and ui=screen
  if ($self->get_mode("screen")) {
    local $| = 1;
    foreach my $thisline (split(/\n/, $command)) {
      my ($start, $end) = ($self->mo->ui eq 'screen') ? $self->_ansify($thisline, 'comment') : (q{}, q{});
      print STDOUT $start, $thisline, $end, $/;
    };
  };

  ## -------- spit plot commands to the screen, use ANSI colors if available and ui=screen
  if (($self->get_mode("plotscreen"))  and $plotting) {
    local $| = 1;
    foreach my $thisline (split(/\n/, $command)) {
      my ($start, $end) = ($self->mo->ui eq 'screen') ? $self->_ansify($thisline, 'comment') : (q{}, q{});
      print STDOUT $start, $thisline, $end, $/;
    };
  };

  ## -------- dump everything to a file
  if ($self->get_mode("file")) {
    local $| = 1;
    open my $FH, ">".$self->get_mode("file");
    print $FH $command;
    close $FH;
  };

  ## -------- dump plot commands to a file
  if (($self->get_mode("plotfile")) and $plotting) {
    if ($self->mo->template_plot eq 'gnuplot') {
      my $crstring = $self->po->copyright_text;	## insert the copyright statement in a plot made with gnuplot
      $command =~ s{(unset label)}{$1\n$crstring}g;
    };
    local $| = 1;
    open my $FH, ">".$self->get_mode("plotfile");
    print $FH $command;
    close $FH;
  };

  ## -------- use a disposal callback
  if ($self->get_mode("callback")) {
    my $coderef = $self->get_mode("callback");
    if (not $plotting) {
      &$coderef($command);
    } elsif ($plotting and not $self->get_mode("plotcallback")) {
      &$coderef($command);
    } else {
      1;
    };
  };
  if ($plotting and $self->get_mode("plotcallback")) {
    my $coderef = $self->get_mode("plotcallback");
    &$coderef($command);
  };

  ## -------- concatinate to a scalar buffer
  if (($self->get_mode("buffer")) and (ref($self->get_mode("buffer")) eq 'SCALAR')) {
    if (not $plotting) {
      ${ $self->get_mode("buffer") } .=  $command;
    } elsif ($plotting and not $self->get_mode("plotbuffer")) {
      ${ $self->get_mode("buffer") } .=  $command;
    } else {
      1;
    };
  };

  if ($plotting and $self->get_mode("plotbuffer") and (ref($self->get_mode("plotbuffer")) eq 'SCALAR')) {
    ${ $self->get_mode("plotbuffer") } .=  $command;
  };

  ## -------- unknown buffer type
  if (    ($self->get_mode("buffer"))
	  and (ref($self->get_mode("buffer")) ne 'SCALAR')
	  and (ref($self->get_mode("buffer")) ne 'ARRAY')  ) {
    carp("Demeter::Dispose: string mode value is not a scalar or array reference\n\n");
  };

  if ($plotting and ($self->mo->template_plot eq 'gnuplot')) {
    my $crstring = $self->po->copyright_text; ## insert the copyright statement in a plot made with gnuplot
    $command =~ s{(unset label)}{$1\n$crstring}g;

    $self->mo->external_plot_object->gnuplot_cmd($command);
    # $self->mo->external_plot_object->gnuplot_pause(-1);
    my $gather = $self->po->lastplot;
    $gather .= $command;
    $self -> po -> lastplot($gather);
    return 0; ## need to short-circuit this so the gnuplot commands do not go to Ifeffit
  };

  ## -------- don't bother reprocessing unless an output channel that
  ##          requires looping over every line
  return 0 unless (
		   ($self->get_mode("buffer") and (ref($self->get_mode("buffer")) eq 'ARRAY'))
		   or $self->get_mode("ifeffit")
		   or $self->get_mode("repscreen")
		   or $self->get_mode("repfile")
		  );

  my ($reprocessed, $eol) = (q{}, $/);
  foreach my $thisline (split(/\n/, $command)) {

    if (($self->get_mode("buffer")) and (ref($self->get_mode("buffer")) eq 'ARRAY')) {
      push @{ $self->get_mode("buffer") },  $thisline;
    };

    ## this next bit of insanity is an ifeffit optimization.  it is
    ## considerably faster to have perl process multi-line commands
    ## into long (up to 2048 characters) individual commands than to
    ## use ifeffit and the swig wrapper. the point here is to
    ## recognize parens-bound commands and concatinate them onto a
    ## single line

    next if ($thisline =~ m{^\s*\#});
    next if ($thisline =~ m{^\s*$});

    $thisline =~ s{^\s+}{};
    $thisline =~ s{\s+$}{};
    $thisline =~ s{\s+=}{ =};
    my $re = $Demeter::StrTypes::command_regexp;
    $eol = ($thisline =~ m{^$re\s*\(}) ? " " : $eol;
    $eol = $/ if ($thisline =~ m{\)$});
    $reprocessed .= $thisline . $eol;
  };

  ## -------- send reprocessed command text to ifeffit
  if ($self->get_mode("ifeffit")) {
    ifeffit($reprocessed);
    $self -> po -> copyright_text if ($plotting and ($self->mo->template_plot eq 'pgplot')); ## insert the copyright statement in a plot made with pgplot

    ## this mess parses Ifeffit's feedback and sends it either to the feedback code ref or to the screen
    my $coderef = $self->get_mode("feedback");
    if ($coderef or $self->get_mode("screen") or  $self->get_mode("plotscreen")) {
      my ($lines, $response) = (Ifeffit::get_scalar('&echo_lines')||0, "");
      if ($lines) {		# is there feedback?
	foreach my $i (1 .. $lines) {
	  my $response = Ifeffit::get_echo();

	  ## send to feedback code ref
	  if ($coderef) {
	    ($response) and &$coderef($response."\n");

	  ## send to the screen with ANSI colorization
	  } elsif ($self->get_mode("screen") or ($self->get_mode("plotscreen") and $plotting)) {
	    $self->_ansify($response.$/, "feedback")
	  };

	};
      };
    };
  };

  ## -------- send reprocessed command text to the screen
  print STDOUT $reprocessed if $self->get_mode("repscreen");

  ## -------- send reprocessed command text to a file
  if ($self->get_mode("repfile")) {
    open my $FH, ">".$self->get_mode("file");
    print $FH $reprocessed;
    close $FH;
  };
  $self->set_mode(echo=>$echo_buffer);

  return 0;
};

sub nl {
  my ($self) = @_;
  $self->dispose("\n");
  return $self;
};


sub Reset {
  my ($self) = @_;
  $self->dispose("reset");
  return $self;
};

sub cursor {
  my ($self) = @_;
  $self->dispose("cursor(show, cross-hair)");
  return(Ifeffit::get_scalar("cursor_x"), Ifeffit::get_scalar("cursor_y"));
};

sub screen_echo {
  my ($self, $value) = @_;
  Ifeffit::ifeffit("set \&screen_echo = $value");
  return $self;
};

1;


=head1 NAME

Demeter::Dispose - Process Ifeffit and plotting command strings

=head1 VERSION

This documentation refers to Demeter version 0.3.

=head1 SYNOPSIS

  my $data_object = Demeter::Data -> new();
  $data_object -> set_mode(ifeffit=>1, buffer=>\@buffer, screen=>1);
  $data_object -> dispose($ifeffit_command);


=head1 DESCRIPTION

This module contains contains the dispose method, which is used to
dispatch Ifeffit command strings to various places.  This is part of
the base of all other objects in the Demeter system, thus any object
can dispose text.

The command strings which are handled by the C<dispose> method are
typically generated using the command templating system, which is
described in L<Demeter/TEMPLATES>.

=head2 Reprocessed commands

Command strings are typically generated by Demeter in a manner which
is designed to be human readable.  Unfortunately, human-readable and
Ifeffit-efficient tend to be at odds.  In the interest of speed and
efficiency, Demeter processes Ifeffit commands into a form that is
harder for a human to read, but faster for Ifeffit to process.

The main change made to Ifeffit command strings is to concatinate
multi-line commands into a single line and to squeeze white space into
a single space.  This significantly reduces the number of calls to the
C<iff_exec> function in Ifeffit, which is one of the most
time-consuming parts of the Demeter/Ifeffit stack.  Given that Ifeffit
allows command strings to be as much as 2048 characters long, it is
rare that an command generated by Demeter cannot be handled in this
way.

Also, the preprocessed text does not contain any lines that are only
whitespace or are entirely commented out.

=head1 METHODS

=head2 C<dispose>

This method dispatches command strings to various places.  Many
methods in the Demeter system are command generators.  The intent is
that to accumulate text through successive method calls and then
dispose of the text using this method.  The method takes two
arguments, a scalar containing all the text that you have accumulates,
and an optional argument that, when true, indicates that the commands
are specifically plotting commands.

Demeter is very careful to segregate plotting commands from data
processing commands and to dispose of them separately.  This allows
transparent use of different plotting backends.  The C<ifeffit>
disposal channel is used to indicate disposal of commands either to
ifeffit or to another plotting backend.  That is, if you want to
dispose of plotting commands to a gnuplot process, you must have the
C<ifeffit> disposal channel enabled.

Use the C<set_mode> class method to establish the disposal channels.

   Demeter->set_mode(ifeffit=>1, screen=>1, file=>0, buffer=>0);
   $dataobject -> dispose($commands);

When explicitly disposing a plotting command, use the plotting flag:

   $dataobject -> dispose($commands, "plotting");

There are several disposal channels:

=over 6

=item ifeffit

This channel sends reprocessed command strings to ifeffit for
processing.  This is a boolean.  By default, this channel is on and
all the rest are off.

=item screen

This channel sends command strings to standard output.  This is a
boolean.  If the UI is set to screen (see L<Demeter::Mode>) and the
L<Term::ANSIColor> package is installed, then comments in the screen
output will be colored red, pink, or yellow depending on the comment
character.

The default colors are:

  red           data processing comments
  pink          plotting comments
  yellow        fitting comments
  light blue    feedback from Ifeffit
  white on red  error messages from Ifeffit

These colors are configurable in the screen group.

=item file

This channel send command strings to a file.  If the value of file
evaluates false, then this channel is not used.  If it is true, the
value is taken to be the name of the output file.  At this time, IO
control is extremely simple.  If you want to append command strings to
an existing file, simply append C<E<gt>> to the beginning of the file
name:

   # clobber foo and start a new file by that name
   $dataobject -> set_mode(file=>"foo");
   $dataobject -> dispose($commands);
   #
   # append to foo
   $dataobject -> set_mode(file=>">foo");
   $dataobject -> dispose($commands);

=item plotscreen

This behaves exactly like the C<screen> parameter, but applies only to
commands disposed using the plotting flag.  If the UI is set to screen
(see L<Demeter::Mode>) and the L<Term::ANSIColor> package is
installed, then comments in the screen output will be colored red,
pink, or yellow depending on the comment character.

=item plotfile

This behaves exactly like the C<file> parameter, but applies only to
commands disposed using the plotting flag.  This allows you to
accumulate plotting commands into plotting scripts, which is handy for
the gnuplot backend.

=item buffer

This channel pushes each command line onto an in-memory buffer.  The buffer
can be either a string or an array.  The buffer attribute is a reference to
the scalar or array.

If a scalar reference is used, the scalar is treated as a string and each
command line is concatinated to the end of the string.

   $buffer = q{};
   $dataobject -> set_mode(buffer=>\$buffer);
   $dataobject -> dispose($commands);
   print $buffer;

If an array reference is used, each command line is pushed onto the end of the
array.

   @buffer = ();
   $dataobject -> set_mode(buffer=>\@buffer);
   $dataobject -> dispose($commands);
   map {print $_} @buffer;

An obvious improvement to this would be to allow the buffer attribute
to be a reference to an arbitrary object which can be used in some
domain-specific, user-defined manner.

=item plotbuffer

This is an optional output channel for the plotting commands.  If
unset, plotting commands go to the same channel as specified by
C<buffer>.  This channel works identically to C<buffer>, albeit
redirected to a different place.

=item callback

This channel sends disposed text to a user supplied code reference.
For instance, in Artemis, this is a subroutine that prints the
disposed lines to the command buffer.  This code ref takes a single
argument, which is the text to be disposed.

=item plotcallback

This optional channel redirects plotting commands to a differnt code
reference from C<callback>.  If unset, plotting commands are disposed
to C<callback>'s code ref.

=item feedback

This channel sends feedback from Ifeffit to a user supplied code
reference.  Note that lines indicating a problem in Ifeffit's output
start with a star (*).  Information lines start with text.

=item repscreen

This channel sends reprocessed command strings to standard output.
The value of screen in the hash is interpreted as a boolean.  The main
use of this channel is to debug the text actually sent to Ifeffit.  No
colorizing is done because comments are stripped from the reprocessed
commands.

=item repfile

This channel send reprocessed command strings to a file.  This channel
is handled in the same manner as the normal file channel.  The main
use of this channel is to debug the text actually sent to Ifeffit.

=back

Note that the C<dispose> method is also used to place a copyright
statement on every plot.  This behavior can be suppressed by setting
the C<plot-&gt;showcopyright> configuration parameter to a false
value.

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

For more information about effecting command generation and disposal,
see L<Demeter::Mode>.

=head1 CONFIGURATION

See L<Demeter::Config> for a description of the configuration system.

=head1 DEPENDENCIES

Demeter's dependencies are in the F<Bundle/DemeterBundle.pm> file.

=head1 BUGS AND LIMITATIONS

=over 4

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

The screen, plotscreen, and repscreen disposal channels currently
write to STDOUT.  The user can direct STDOUT elsewhere.  It may be
useful to have the option of specifying a filehandle for this channel.

=back

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
