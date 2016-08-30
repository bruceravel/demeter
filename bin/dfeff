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

use File::Basename;
use File::Copy;
use File::Path;
use File::Spec;
use Getopt::Long;
use Const::Fast;
const my $USAGE => "usage: dfeff [options] <myfeff.inp>\n";

my ($workspace, $quiet, $version, $help, $save, $rmax) = (q{./},0,0,0,0,0);
my ($all, $do_pots, $do_pf, $do_ff2chi, $keep) = (0, 0, 0, 0, 0);
GetOptions (
	    "workspace|s=s" => \$workspace,
	    "quiet|q"       => \$quiet,
	    "version|v"     => \$version,
	    "help|h"        => \$help,

	    "rmax|r=s" => \$rmax,
	    all        => \$all,
	    potentials => \$do_pots,
	    pathfinder => \$do_pf,
	    ff2chi     => \$do_ff2chi,
	    keep       => \$keep,
	    save       => \$save,
	   );

&version, exit if $version;
&help,    exit if $help;

$| = 1;		    # get Feff to write immediately to the screen

## figure out which parts of feff to run
($all = 1) if not ($do_pots or $do_pf or $do_ff2chi);
(($do_pots, $do_pf, $do_ff2chi) = (1,1,1)) if $all;
($keep = 4) if $keep;


my $inp = $ARGV[0] || q{feff.inp};
die $USAGE if not $inp;
die "rdfit: input file \"$inp\" does not exist\n" if not -e $inp;
my $base = basename($inp);


&version;
if (not -d $workspace) {
  banner("Creating workspace \"$workspace\"");
  mkpath($workspace);
};


my $feff = Demeter::Feff -> new();
## read the input file
banner("Reading \"$inp\"");
$feff->set(workspace => "$workspace",
	   screen    => !$quiet,
	   save      =>  $save,
	   ccrit     =>  $keep);
$feff->file($inp);

my $target = ($base eq 'feff.inp') ? 'original_feff.inp' : $base;
copy($inp, File::Spec->catfile($workspace, $target));
$feff -> rmax($rmax) if ($rmax > 0);

mkpath($workspace) if not -d $workspace;

## potentials
if ($do_pots) {
  banner("Computing atomic potentials");
  $feff -> potph;
};

## pathfinder
if ($do_pf) {
  banner("Finding paths");
  $feff -> pathfinder if $do_pf;
  my $yaml = $base;
  $yaml =~ s{inp$}{yaml};
  ($yaml .= '.yaml') if ($yaml !~ m{\.yaml$});
  $yaml = File::Spec->catfile($workspace, $yaml);
  $feff->freeze($yaml);
};

## genfmt
if ($do_ff2chi) {
  banner("Writing feffNNNN.dat files");
  $feff->pathsdat();
  $feff->genfmt();
};


sub version {
  print "=== dfeff, Demeter's implementation of Feff6\n";
  print "=== Demeter $Demeter::VERSION, copyright (c) 2007-2009, Bruce Ravel, L<http://bruceravel.github.io/home>\n";
  print "=== Feff6 is copyright (c) 1992-2009, The FEFF Project\n";
};
sub help {
  &version;
  print <<'EOH'

usage : dfeff [options] <myfeff.inp>

    option           effect
 -----------------------------------------------------------------
   -w, --workspace  (= folder) folder in which to run feff
   --rmax           (= number) set the maximum path length
   --all            run all parts of Feff sequentially
   --potentials     calculate the phase.bin file
   --pathfinder     run Demeter's pathfinder
   --ff2chi         write feffNNNN.dat file for every path
   --keep           use Feff's keep criteria when running genfmt
   --save           save temporary files
   -q, --quiet      suppress screen messages
   -v, --version    display version number and exit
   -h, --help       show this help and exit

EOH
    ;
};

sub banner {
  return if $quiet;
  print $/;
  print q{=} x 60, $/;
  print q{=} x 3, q{ }, $_[0];
  print q{ } x (52-length($_[0])), q{ }, q{=} x 3, $/;
  print q{=} x 60, $/;
};



=head1 NAME

dfeff - Run Demeter's implementation of Feff6

=head1 VERSION

This documentation refers to Demeter version 0.9.25.

=head1 SYNOPSIS

  dfeff <--workspace=/path/to/folder/> [options] <myfeff.inp>

If no input file is specified, F<feff.inp> is used.  If no workspace
is specified on the command line, the current directory is used.

=head1 DESCRIPTION

This runs Demeter's implementation of Feff6 somewhat similarly to how
the normal Feff behaves.  The default behavior of this program is to
run through all parts of the Feff calculation, starting with reading
the input file and ending with writing the F<feffNNNN.dat> files.
However, this program allows considerably more control over the Feff
run than you get from the normal Feff.

=head1 COMMAND LINE SWITCHES

You can specify a Feff input file at the command line.  This input
file can have any name (it is not restricted to F<feff.inp> as in
Feff6) and need not be in the current working directory nor in the
workspace where the Feff calculation will be made.  A copy of the
input file will be placed in the workspace.

You can specify the folder in which the Feff calculation will be made
using the C<--workspace> command line switch.

=over 4

=item C<-w> or C<--workspace>

Specify a folder in which to run this feff calculation.  If
unspecified, the current work directory will be used.

=item C<--rmax>

Specify a maximum path length, in Angstroms.

=item C<--all>

Run all parts of Feff.  This is the default behavior if none of the
following three flags are set.

=item C<--potentials>

Run the potentials portion of the Feff calculation.

=item C<--pathfinder>

Run the pathfinder portion of the Feff calculation.

=item C<--ff2chi>

Write out all F<feffNNNN.dat> files found by the pathfinder.

=item C<--save>

Save the temporary files written out during the feff calculation.

=item C<--keep>

Use Feff's curved wave keep criterion when generating F<feffNNNN.dat>
files.

=item C<-q> or C<--quiet>

Suppress screen messages during the Feff run.

=item C<-v> or C<--version>

Display version information and quit.

=item C<-h> or C<--help>

Display help information and quit.

=back

=head1 CONFIGURATION AND ENVIRONMENT

See L<Demeter::Config> for a description of Demeter's
configuration system.  See the C<feff> configuration group.

=head1 DEPENDENCIES

This script uses L<Term::ANSIColor> to color the terminal output, but
it defaults gracefully to colorless output if this module is not
available.

The dependencies of the Demeter system are in the
F<Build.PL> file.

=head1 BUGS AND LIMITATIONS

See L<Demeter::Feff> and L<Demeter::ScatteringPath>
for bugs and limitations of the underlying libraries.

There should be an option for running Feff's pathfinder for the sake
of bug testing Demeter's pathfinder or for using paths with more than
4 legs.

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
