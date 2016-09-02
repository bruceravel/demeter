#!/usr/bin/env perl

=for Copyright
 .
 Copyright (c) 2008-2016 Bruce Ravel (L<http://bruceravel.github.io/home>).
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


use Demeter;
use Demeter::Fit::Feffit;

use File::Basename;
use Getopt::Long;
my ($run, $perl, $ifeffit, $quiet,$help) = (0,1,0,0,0);
my $result = GetOptions (
			 "r" => \$run,
			 "p" => \$perl,
			 "i" => \$ifeffit,
			 "q" => \$quiet,
			 "h" => \$help,
			);
++$help if not $ARGV[0];
if ($help) {
  print <<EOH
  dfeffit -p infile outfile     --> convert to perl script (default)
  dfeffit -i infile outfile     --> convert to ifeffit script
  dfeffit -p infile [outfile]   --> run fit
    -q suppreses screen outout
    -h displays this message
EOH
  ;
  exit;
};
die "The file '$ARGV[0]' does not exist\n" if (not -e $ARGV[0]);
die "The file '$ARGV[0]' cannot be read\n" if (not -r $ARGV[0]);
($perl, $ifeffit) = (0,0) if ($run);
($perl, $run)     = (0,0) if ($ifeffit);

## parse feffit.inp file
my $inp = Demeter::Fit::Feffit->new(file=>$ARGV[0]);

## select proper output target
$inp -> template_set("demeter") if  $perl;
$inp -> template_set("ifeffit") if ($run or $ifeffit);
$inp -> set_mode(backend  => 0) if  not $run;

## screen or file output
if (exists $ARGV[1]) {
  unlink $ARGV[1] if (-e $ARGV[1]);
  $inp -> set_mode(file => '>'.$ARGV[1]);
} else {
  $inp -> set_mode(screen => 1);
};
$inp -> set_mode(screen => 0) if $quiet;

## make the Fit object and do the fit
my $fit = $inp -> convert;
$fit -> ignore_errors(1) if not $run;
$fit -> fit;

## do a few more things if a real fit was done
if ($run) {
  my $base = basename($ARGV[0]);
  $fit -> logfile($base."_with_demeter.log");
  $fit -> freeze(file=>$base.".dpj");
  $fit -> interview;
};


=head1 NAME

dfeffit - Read and use a feffit.inp file

=head1 VERSION

This documentation refers to Demeter version 0.9.25.

=head1 SYNOPSIS

Process a F<feffit.inp> file with Demeter.

  dfeffit [-r -i -p -q] inputfile savefile

If no save file is given on the command line, the script will be
echoed to the screen.

=head1 DESCRIPTION

This script is a wrapper around L<Demeter::Fit::Feffit> and can be
used to run the fit encoded in a feffit input file or to convert the
input file either to an Ifeffit script or to a perl script using
Demeter.

=head1 COMMAND LINE SWITCHES

=over 4

=item C<-r>

Run a fit using the information in the C<feffit.inp> file.  Specifying
this flag will override either of the C<-i> or C<-p> flags when (for
some reason) more than one is specified on the command line.

If the fit is run, a log file and a project file will be written and
the interview method will be called.  See L<Demeter::UI::Screen::Interview>.

=item C<-i>

Generate an ifeffit script which is equvalent to the C<feffit.inp>
file.

=item C<-p>

Generate a perl script which uses Demeter and is equvalent to the
C<feffit.inp> file.  This is the default behavior.

=item C<-q>

Suppress the echoing of the script to the screen.  This is useful with
the -r flag.

=back

=head1 CONFIGURATION AND ENVIRONMENT

See L<Demeter::Config> for a description of Demeter's
configuration system.

=head1 DEPENDENCIES

The dependencies of the Demeter system are in the
F<Build.PL> file.

=head1 BUGS AND LIMITATIONS

See L<Demeter::Fit::Feffit> for bugs and limitations of the
underlying library.

Please report problems to the Ifeffit Mailing List
(L<http://cars9.uchicago.edu/mailman/listinfo/ifeffit/>)

Patches are welcome.

=head1 AUTHOR

Bruce Ravel (L<http://bruceravel.github.io/home>)

http://bruceravel.github.io/demeter/


=head1 LICENCE AND COPYRIGHT

Copyright (c) 2008-2016 Bruce Ravel (L<http://bruceravel.github.io/home>). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
