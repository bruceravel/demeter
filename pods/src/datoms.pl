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
BEGIN {
  # turn off Unity feature of the Mac-like global menu bar, which
  # interacts really poorly with Wx.  See
  # http://www.webupd8.org/2011/03/disable-appmenu-global-menu-in-ubuntu.html
  $ENV{UBUNTU_MENUPROXY} = 0;
  ## munge the PATH env. var. under Windows, also add useful debugging
  ## info to the log file
  if (($^O eq 'MSWin32') or ($^O eq 'cygwin')) {
    require Win32;
    my @now = localtime(time);
    printf STDOUT "Started at %d-%2.2d-%2.2dT%2.2d:%2.2d:%2.2d$/", $now[5]+1900, $now[4]+1, reverse(@now[0..3]);
    print  STDOUT Win32::GetOSName(), "\t", Win32::GetOSVersion, $/, $/;
    print  STDOUT "PATH is:$/\t$ENV{PATH}$/";
    print  STDOUT "DEMETER_BASE is:$/\t$ENV{DEMETER_BASE}$/";
    print  STDOUT "IFEFFIT_DIR is:$/\t$ENV{IFEFFIT_DIR}$/$/";
    print  STDOUT "perl version: $^V$/$/";
    print  STDOUT "\@INC:$/\t" . join("$/\t", @INC) . "$/";
  };
};

use Demeter qw(:atoms);
use Getopt::Long;
use Demeter::Constants qw($NUMBER);
use List::MoreUtils qw(none);
use vars qw($app);

my ($rmax, $cif, $record, $wx, $output) = (Demeter->co->default("atoms", "rmax"), 0, 1, 0, 'feff6');

my $result = GetOptions (
			 "c|cif"      => \$cif,
			 "rec=i"      => \$record,
			 "r|rmax=s"   => \$rmax,
			 "o|output=s" => \$output,
			 "wx"         => \$wx,
			);

if ($wx) {
  wx();
  exit;
};

my $file = $ARGV[0] || "atoms.inp";
die "Atoms terminating: $file does not exist\n" if (not -e $file);

my @call = ($cif) ? (record=>$record-1, cif => $ARGV[0]) : (file => $file);
my $atoms = Demeter::Atoms->new(@call);

$output = lc($output);
$output = 'feff6'      if ($output eq '6');
$output = 'feff8'      if ($output eq '8');
$output = 'feff85test' if ($output eq '85');

if (none {$output eq $_} (@Demeter::StrTypes::output_list)) {
  print STDERR "$output is not a recognized output type.  Writing feff6 output.\n\n";
  $output = 'feff6';
};
$atoms -> set(rmax=>$rmax) if ($rmax and $rmax =~ m{\A$NUMBER\z});
print $atoms -> Write($output);


sub wx {
  require Wx;
  require Demeter::UI::Atoms;
  Wx::InitAllImageHandlers();
  $app = Demeter::UI::Atoms->new;
  $app -> {frame} -> {Atoms} -> open_file($ARGV[0]) if $ARGV[0];
  $app -> MainLoop;
};



=head1 NAME

atoms - Convert crystallography data to a feff.inp file

=head1 VERSION

This documentation refers to Demeter version 0.9.25.

=head1 SYNOPSIS

  datoms [--output format] [--rmax #] [--cif --rec=#] [--wx] mydata.inp

If no input or CIF file is specified at the command line, F<atoms.inp>
in the current working directory will be used, if available.

If the C<--wx> flag for running the GUI is given, all other command
line arguments are ignored.

=head1 DESCRIPTION

This reads an atoms input file or a CIF file (CIF is not working at
this time) and writes the results of a calculation using that
crystallography data to standard output.  Typically the output is a
F<feff.inp> file, but it may also be a summary of the space group,
calculation using tables of X-ray absorption coefficients, etc.

=head1 COMMAND LINE SWITCHES

By default, an input file for Feff6 is written.  This and aspects of
the F<feff.inp> file can be overridden from the command line.

=over 4

=item C<--wx>

Run the wxWidgets-based GUI (ignoring all other command-line flags).

=item C<--output=format> or C<-o format>

Specify the output type.  Must be (case-insensitive) one of

=over 4 

=item C<feff6>, C<6>

Write a F<feff.inp> file for feff6.

=item C<feff8>, C<8>

Write a F<feff.inp> file for feff8.

=item C<feff85test>, C<85>

Write a F<feff.inp> file for use with the feff85exafs testing
framework.

=item C<spacegroup>

Write a file with information about the space group.

=item C<p1>

Write the crystal structure as an atoms input file using the C<P1>
space group, i.e. the fully decorated unit cell.

=item C<absorption>

Write a file with the results of calculations based on the crystal
structure and tables of X-ray absorption coefficients.

=item C<atoms>

Write the input data as an atoms input file (mostly useful for CIF to
F<atoms.inp> conversion)

=item C<xyz>

Write the cluster in the simple L<XYZ molecule format|https://en.wikipedia.org/wiki/XYZ_file_format>.

=item C<alchemy>

Write the cluster in the alchemy molecule format.

=item C<overfull>

Write the contents of the unit cell in Cartesian coordinates with all
atoms near a cell wall replicated near the opposite cell wall.  This
is written in the form of an L<XYZ molecule
format|https://en.wikipedia.org/wiki/XYZ_file_format> file.  The
purpose of this output type is generate nice figures of unit cells
with decorations on all the corners, sides, and edges.

=back

=item C<--rmax=#> or C<-r #>

Specify a cluster size from the command line.

  datoms -r 5.2 mydata.inp

=back

=head1 CIF FILES

Reding CIF files requires the use of one or two additional command
line switches:

=over 4

=item C<--cif> or C<-c>

This flag indicates that the file given on the command line is a CIF
file rather than an Atoms input file.  B<No effort> is made to figure
out whether your file is CIF or Atoms input -- it is up to you to
correctly identify it using this command line flag.

  datoms --cif --rec=2 my_cif_file.cif

=item C<--rec=#>

If your CIF file is a multi-record file, use this switch to indicate
which record to import.  The default is to read the first record, so
this switch does not need to be used for a single-record file.

=back

Note that a CIF file does not identify a central atom.  Demeter's CIF
importer assuems that the heaviest atom in the material is the
absorber.  As a command line utility, there is no convenient way to
unambiguously identify the central atom.  Probably the best solution
is to use this script to convert the CIF file to an atoms input file,
edit that, then rerun this script to generate the Feff input file.

=head1 CONFIGURATION AND ENVIRONMENT

See L<Demeter::Config> for a description of Demeter's
configuration system.  Atoms uses the C<atoms> configuration group.

=head1 DEPENDENCIES

The dependencies of the Demeter system are in the
F<Build.PL> file.

=head1 BUGS AND LIMITATIONS

See L<Demeter::Atoms> for bugs and limitations of the
underlying libraries.

Missing command line switches:

=over 4

=item *

-v and -h

=item *

ipot style

=item *

feff7, overfull

=item *

OpenBabel integration

=item *

snarf atoms.inp files from Matt's database or CIF files from the web

=back

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
