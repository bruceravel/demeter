#!/usr/bin/perl

=for Copyright
 .
 Copyright (c) 2008-2012 Bruce Ravel (bravel AT bnl DOT gov).
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
};

use Demeter qw(:atoms);
use Getopt::Long;
use Demeter::Constants qw($NUMBER);

my ($feff6, $feff8, $abs, $sg, $p1, $rmax, $cif, $record, $atinp, $wx) = (0, 0, 0, 0, 0, 0, 0, 1, 0, 0);
my $result = GetOptions (
			 "c|cif"    => \$cif,
			 "rec=i"    => \$record,
			 "r|rmax=s" => \$rmax,
			 "6"	    => \$feff6,
			 "8"	    => \$feff8,
			 "a"	    => \$abs,
			 "s"	    => \$sg,
			 "p"	    => \$p1,
			 "atoms"    => \$atinp,
			 "wx"       => \$wx,
			);

if ($wx) {
  wx();
  exit;
};

my @call = ($cif) ? (record=>$record-1, cif => $ARGV[0]) : (file => $ARGV[0]||"atoms.inp");
my $atoms = Demeter::Atoms->new(@call);

my $which = ($feff6) ? "feff6"
          : ($feff8) ? "feff8"
          : ($abs)   ? "absorption"
          : ($sg)    ? "spacegroup"
          : ($p1)    ? "p1"
          : ($atinp) ? "atoms"
          :            "feff6" ;
$atoms -> set(rmax=>$rmax) if ($rmax and $rmax =~ m{\A$NUMBER\z});
print $atoms -> Write($which);


sub wx {
 require Wx;
 require Demeter::UI::Atoms;
 Wx::InitAllImageHandlers();
 my $window = Demeter::UI::Atoms->new;
 $window   -> MainLoop;
};



=head1 NAME

atoms - Convert crystallography data to a feff.inp file

=head1 VERSION

This documentation refers to Demeter version 0.9.9.

=head1 SYNOPSIS

  atoms [flag] [-r #] [--cif --rec=#] [--wx] mydata.inp

If no input or CIF file is specified at the command line, F<atoms.inp>
in the current working directory will be used, if available.

If the C<--wx> flag for running the GUI is given, all other command
line arguments are ignored.

=head1 DESCRIPTION

This reads an atoms input file or a CIF file (CIF is not working at
this time) and writes out the results of a calculation using that
crystallography data.  Typically the output is a F<feff.inp> file, but
it may also be a summary of the space group, calculation using tables
of X-ray absorption coefficients, etc.

=head1 COMMAND LINE SWITCHES

By default, an input file for Feff6 is written.  This and aspects of
the F<feff.inp> file can be overridden from the command line.

=over 4

=item C<--wx>

Run the wxWidgets-based GUI (ignoring all other command-line flags).

=item C<-6>

Write an input file for Feff6 (which is the default).

=item C<-8>

Write an input file for Feff8.

=item C<-a>

Write the results of calculations using tables of X-ray absorption
coefficients.

=item C<-s>

Write a space group summary file.

=item C<--atoms>

Write an atoms input file.  This is most useful for interacting with a
CIF file for which the central atom cannot be identified by Demeter's
simplistic algorithm.

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
F<Bundle/DemeterBundle.pm> file.

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

Please report problems to Bruce Ravel (bravel AT bnl DOT gov)

Patches are welcome.

=head1 AUTHOR

Bruce Ravel (bravel AT bnl DOT gov)

http://cars9.uchicago.edu/~ravel/software/


=head1 LICENCE AND COPYRIGHT

Copyright (c) 2008-2012 Bruce Ravel (bravel AT bnl DOT gov). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
