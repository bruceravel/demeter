package Ifeffit::Demeter::UI::Screen::Probe;

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

use warnings;
use strict;
use Ifeffit;
use Ifeffit::Demeter;
use Term::ANSIColor qw(:constants);
use Term::ReadLine;

use vars qw($VERSION @ISA @EXPORT);
@ISA = qw(Exporter AutoLoader);
@EXPORT = qw(interview);

my $clear   = `clear`;
my $term    = new Term::ReadLine 'demeter';
my $space   = 'r';
my $message = q{};

sub interview {
  my ($fit, $noplot) = @_;
  my $plot = Ifeffit::Demeter->get_mode("plot");

  #$fit->po->start_plot; # reset the plot for the next go around
  $fit->po->set({plot_fit=>1});
  #Ifeffit::Demeter->set_mode({screen  => 1,});

  my @params = (q{}, qw(kweight space rpart qpart paths bkg res));
  #plot($fit, 1) unless $noplot;
  plot($fit, 1, 'rmr') unless $noplot;
  &query;
  my $prompt = "Choose data by number, select an operation by letter, or q=quit > ";
  while ( defined ($_ = $term->readline($prompt)) ) {
  DISPATCH: {
      $fit->po->cleantemp,    return        if ($_ =~ m{\Aq});
      &help,                  last DISPATCH if ($_ =~ m{\Ah});
      &version,               last DISPATCH if ($_ =~ m{\Av});
      &Log,                   last DISPATCH if ($_ =~ m{\Al});
      plot($fit, $1),         last DISPATCH if ($_ =~ m{\Ap?(\d+)});
      data_report($fit, $1),  last DISPATCH if ($_ =~ m{\Ad(\d+)});
      gds($fit),              last DISPATCH if ($_ =~ m{\Ag});
      #save($1),               last DISPATCH if ($_ =~ m{\As(\d+)});
      stats($fit),            last DISPATCH if ($_ =~ m{\As});
      set($fit, $params[$1]), last DISPATCH if ($_ =~ m{\Ac([1-7])});
    };
    &query($fit);
  };
};

sub help {
  $message = "No help yet";
  return 0;
};
sub version {
  $message = Ifeffit::Demeter->identify . "\n";
  return 0;
};
sub data_report {
  my ($fit, $n) = @_;
  my @data = @{ $fit->data };
  $message  = BOLD . YELLOW . $data[$n-1]->label . RESET . "\n";
  $message .= $data[$n-1]->fit_parameter_report;
  return 0;
};
sub stats {
  my ($fit) = @_;
  $message = $fit->statistics_report;
  return 0;
};

sub Log {
  my ($fit) = @_;
  my $logout = File::Spec->catfile($fit->stash_folder, "probe_log");
  $fit->logfile($logout);
  my $pager = $ENV{PAGER} || "more";
  system "$pager $logout";
  unlink $logout;
}

sub query {
  my ($fit) = @_;
  my @data  = @{ $fit->data };
  my $plot = Ifeffit::Demeter->get_mode("plot");
  print $clear;

  print BOLD, GREEN, "c#", RESET, ") change plotting parameter:\n";
  print BOLD, GREEN, " 1", RESET, ") k-weight        = ", $plot->get("kweight"),    "\t\t\t";
  print BOLD, GREEN, " g", RESET ") show guess, def, set parameters\n";

  print BOLD, GREEN, " 2", RESET, ") plot space      = ", $space,                   "\t\t\t";
  print BOLD, GREEN, " s", RESET, ") show fit statistics\n";

  print BOLD, GREEN, " 3", RESET, ") R part          = ", $plot->get("r_pl"),       "\t\t\t";
  print BOLD, GREEN, "d#", RESET, ") show fit parameters\n";

  print BOLD, GREEN, " 4", RESET, ") q part          = ", $plot->get("q_pl"),       "\t\t\t";
  print BOLD, GREEN, " l", RESET, ") show log file\n";

  print BOLD, GREEN, " 5", RESET, ") plot paths      = ", $plot->get("plot_paths"), "\t\t\t";
  print BOLD, GREEN, " v", RESET, ") show version\n";

  print BOLD, GREEN, " 6", RESET, ") plot background = ", $plot->get("plot_res"),   "\n";

  print BOLD, GREEN, " 7", RESET, ") plot residual   = ", $plot->get("plot_res"),   "\n";

  print "\n", BOLD, RED, "Data included in the fit", RESET, "\n";
  my $i = 1;
  foreach my $d (@data) {
    printf "%s%s %3d. %s%s : %s\n", BOLD, YELLOW, $i, RESET, $d, $d->get("label");
    ++$i;
  };
  print "\n", BOLD, RED, "Messages:", RESET, "\n" if $message;
  foreach my $line (split(/\n/, $message)) {
    print "\t", $line, $/;
  };
  $message = q{};
  return 0;
};

sub plot {
  my ($fit, $i, $this) = @_;
  $this ||= $space;
  $fit->po->start_plot; # reset the plot for the next go around
  my @data  = @{ $fit->data };
  my @paths = @{ $fit->paths };
  --$i;
  return if ($i > $#data);
  $data[$i] -> plot($this);
  if ($fit->po->get("plot_paths")) {
    foreach my $p (@paths) {
      next unless ($data[$i] eq $p->data);
      #next unless ($p->get("label") eq "Na");
      $p -> plot($this);
    };
  };
};


 sub save {
##   my ($i) = @_;
##   plot($i); # this assures that the data are up to date for saving
##   --$i;
##   my $k = $plot->get("kweight");
##   if ($space eq 'r') {
##     my $part = $plot->get('r_pl');
##     my $command = "write_data(file=\"$data[$i].$k.rsp\", label=\"r Mdata Mfit Rdata Rfit\",\n";
##     $command   .= "           $data[$i].r, $data[$i].chir_mag, $data[$i]_fit.chir_mag,\n";
##     $command   .= "           $data[$i].chir_re, $data[$i]_fit.chir_re)\n";
##     $data[$i] -> dispose($command);
##   };
##   print "\nWrote $data[$i].$k.rsp ", UNDERLINE, "[return to continue] >", RESET, " ";
##   my $how = <STDIN>;
##   print $/;
};


sub show_gds {
  my ($fit) = @_;
  my @gds = @{ $fit->gds };
  print $clear;
  print BOLD, RED, "Guess, def, set parameters:", RESET, "\n\n";
  my ($eol, $count) = ("\t", 0);
  foreach my $g (@gds) {
    next if ($g->type eq 'skip');
    ++$count;
    $eol = ($count%2) ? "\t\t" : "\n";
    printf(" %2d. %s%s:%s %-15s%s = %.4f%s", $count, BOLD.GREEN,
	   substr($g->type, 0, 1), YELLOW, $g->name, RESET,
	   $g->bestfit, $eol);
  };
  print "\n" if ($eol ne "\n");
};

sub gds {
  my ($fit) = @_;
  my @gds = @{ $fit->gds };
  my $prompt = "Choose a parameter for a full report or r to return >";
  show_gds($fit);
  while ( defined ($_ = $term->readline($prompt)) ) {
    return if ($_ =~ m{\Ar}i);
    if ($_ =~ m{\A\d}i) {
      if (exists $gds[$_-1]) {
	show_gds($fit);
	my $report = $gds[$_-1]->full_report;
	my $this   = $gds[$_-1]->name;
	my $that   = BOLD . YELLOW . $this . RESET;
	$report    =~ s{^$this}{$that};
	print "\n", $report,
      };
    };
  }
};


sub set {
  my ($fit, $which) = @_;
  my @data  = @{ $fit->data };
  my $prompt;
 SWITCH: {
    ($which eq 'kweight') and do {
      $prompt = "Choose a k-weight [123] >";
      while ( defined ($_ = $term->readline($prompt)) ) {
	next if ($_ !~ m{[123]});
	$fit->po->set({kweight=>$_});
	map { $_ -> set({update_fft=>1}) } @data;
	return;
      };
    };

    ($which eq 'space') and do {
      $prompt = "Choose a plotting space [krq] >";
      while ( defined ($_ = $term->readline($prompt)) ) {
	next if ($_ !~ m{[krq]});
	$space = $_;
	return;
      };
    };

    ($which eq 'rpart') and do {
      $prompt = "Choose a part to plot in R [rmip] >";
      while ( defined ($_ = $term->readline($prompt)) ) {
	next if ($_ !~ m{[rmip]});
	$fit->po->set({r_pl=>$_});
	return;
      };
    };

    ($which eq 'qpart') and do {
      $prompt = "Choose a part to plot in q [rmip] >";
      while ( defined ($_ = $term->readline($prompt)) ) {
	next if ($_ !~ m{[rmip]});
	$fit->po->set({'q_pl'=>$_});
	return;
      };
    };

    ($which eq 'paths') and do {
      $prompt = "Plot paths [yn] >";
      while ( defined ($_ = $term->readline($prompt)) ) {
	next if ($_ !~ m{[yn]});
	$fit->po->set({'plot_paths'=>($_ eq 'y')});
	return;
      };
    };

    ($which eq 'bkg') and do {
      $prompt = "Plot background [yn] >";
      while ( defined ($_ = $term->readline($prompt)) ) {
	next if ($_ !~ m{[yn]});
	$fit->po->set({'plot_bkg'=>($_ eq 'y')});
	return;
      };
    };

    ($which eq 'res') and do {
      $prompt = "Plot residual [yn] >";
      while ( defined ($_ = $term->readline($prompt)) ) {
	next if ($_ !~ m{[yn]});
	$fit->po->set({'plot_res'=>($_ eq 'y')});
	return;
      };
    };

  };
};

1;

=head1 NAME

Ifeffit::Demeter::UI::Screen::Probe - Simple screen interface to Demeter fit results

=head1 VERSION

This documentation refers to Ifeffit::Demeter version 0.1.

=head1 SYNOPSIS

  use Ifeffit::Demeter;
  use Ifeffit::Demeter::UI::Screen::Probe qw(interview);
  my $fit = Ifeffit::Demeter::Fit->thaw('project.dpj');
  interview($fit);

=head1 DESCRIPTION

This provides a simple, screen-based machanism for interacting with a
Demeter fit result imported from a project file.  The screen interview
allows you to plot data from the fit, examine the fitting parameters
and statistics, and change some of the plotting parameters.  It is
bare-bones, but still useful.  It is a handy thing to add to the end
of a Demeter fitting script as a simple plotting back-end to the fit.

=head1 EXPORTED FUNCTIONS

=over 4

=item C<interview>

Explore the Demeter project file via an on-screen interview.  The
first argument is the fit object to probe.  The optional second
argument is a boolean which, when true, suppresses the plotting of the
first data object with its fit before the beginning of the interview.

The interview understands these concise commands:

=over 4

=item C<number>

Plot the data set using its number in the data list.

=item C<c#>

Change one of the plotting parameters.  For example C<c1> is used to
change the k-weight used in the plots and Fourier transforms.

=item C<d#>

Show the operational parameters of the fit for that data set.

=item C<g>

Examine the guess, def, and set parameters from the fit.  Enter a
number from the list of parameters to see all the details of that
parameter.

=item C<s>

Examine the fitting statistics.

=item C<l>

Show the log file.

=item C<h>

Get a bit of help written to the screen.

=item C<v>

Show the Demeter version number.

=back

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

=back

=head1 CONFIGURATION AND ENVIRONMENT

See L<Ifeffit::Demeter::Config> for a description of Demeter's
configuration system.

=head1 DEPENDENCIES

Along with needing Demeter, this uses L<Term::ANSIColor> and
L<Term::ReadLine>.  The example script in the Demeter distribution
also uses L<Term::Twiddle>.

=head1 BUGS AND LIMITATIONS

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

