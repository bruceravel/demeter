#!/usr/bin/env perl

use Demeter qw(:ui=screen);
use Getopt::Long;
use Const::Fast;
const my $USAGE => "usage: rdfit [-g] myfit.dpj\n";

my $use_gnuplot = 0;
my $result = GetOptions ( 'g' => \$use_gnuplot );


my $proj = $ARGV[0] || q{};
die $USAGE if not $proj;
die "rdfit: project file does not exist\n" if not -e $proj;

my $fit = Demeter::Fit->new(project=>$proj);
$fit -> plot_with('gnuplot') if $use_gnuplot;
$fit -> po -> set(kweight=>2);
$fit -> interview;

=head1 NAME

rdfit - Simple interaction with Demeter fit projects

=head1 VERSION

This documentation refers to Demeter version 0.9.25.

=head1 SYNOPSIS

  rdfit myfit.dpj

=head1 DESCRIPTION

This program provides a simple, screen-based interaction with the
results of a fit using Demeter which has been saved into a project
file.  All commands are entered as one or two keystrokes.  You can
plot your data in k, R, or q along with the fit and the paths.  You
can examine the guess, def, and set parameters and the fitting
statistics.  And you can view the log file.  This is a fairly
bare-bones application, but it provides most of what you need to
examine your data analysis handiwork.

Here is an example of the main interview screen:

  c#) change plotting parameter:
   1) k-weight    = 1                     g) show guess, def, set parameters
   2) plot space  = r                     s) show statistics
   3) R part      = m                    d#) show fit parameters
   4) q part      = r                     l) show log file
   5) plot paths  = 0                     v) show version
  .
  Data included in the fit
     1. data0 : 10 K copper data
     2. data1 : 150 K copper data
  .
  Choose data by number, select an operation by letter, or q=quit >

And here is an example of the guess, def, set interview with a report
on one of the parameters:

  Guess, def, set parameters:
  .
    1. g: alpha010        = -0.0067                 2. g: alpha150        = 0.0030
    3. g: amp             = 0.9782                  4. g: enot            = 1.4856
    5. g: theta           = 314.8034                6. s: sigmm           = 0.0005
  .
  alpha010
    guess parameter
    math expression: 0
    evaluates to  -0.00665617 +/-   0.00161217
    annotation: "alpha010:  -0.00665617 +/-   0.00161217"
  .
  Choose a parameter for a full report or r to return >

=head1 DEPENDENCIES

Along with needing L<Demeter> and L<Demeter::UI::Screen::Interview>,
this program requires L<Term::ANSIColor>, L<Term::ReadLine>, and
L<Term::Twiddle>.

=head1 BUGS AND LIMITATIONS

Please report problems to the Ifeffit Mailing List
(L<http://cars9.uchicago.edu/mailman/listinfo/ifeffit/>)

Patches are welcome.

=head1 AUTHOR

Bruce Ravel (L<http://bruceravel.github.io/home>)

L<http://bruceravel.github.io/demeter/>

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2016 Bruce Ravel (L<http://bruceravel.github.io/home>). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
