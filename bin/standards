#!/usr/bin/env perl

# Copyright (c) 2008-2016 Bruce Ravel (L<http://bruceravel.github.io/home>). All rights reserved.
#
# This example is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself. See L<perlgpl>.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.


BEGIN {
  my $target = q{};
  foreach my $a (@ARGV) {
    ($target = $a) if ($a =~ m{athena|latex|screen|web});
  };
  if ($target eq 'screen') {
    my $width = (split(" ", `stty size`))[1];
    die "Your screen must be at least 80 characters wide for this program.\n" if ($width<80);
  } elsif (($target eq 'web') or ($target eq 'latex')) {
    $ENV{PGPLOT_DEV} = '/null';
  };
};


use Chemistry::Elements qw(get_Z get_name);
use File::Basename;
use File::Spec;
use Term::ReadLine;
use Text::Template;

use Demeter qw{:hephaestus};
use Demeter::UI::Standards;
my $demeter = Demeter->new;
$demeter->set_mode(screen=>0, repscreen=>0);
my $standards = Demeter::UI::Standards->new();
$standards -> ini(q{});

$| = 1;

use Getopt::Long;
my ($light_background, $dark_background) = (0, 1);
my ($folder, $quiet, $skip, $noimage) = ('./', 0, 0, 0);
my ($prjfile, $elements, $all) = (q{}, q{}, 0);
my ($help, $use_gnuplot) = (0, 0);
my $result = GetOptions (
			 "d"            => \$dark_background,
			 "l"            => \$light_background,
			 "folder|f=s"   => \$folder,
			 "quiet|q"      => \$quiet,
			 "skip|s"       => \$skip,
			 "noimage|n"    => \$noimage,
			 'outfile|o=s'  => \$prjfile,
			 'elements|e=s' => \$elements,
			 'a'            => \$all,
			 "help|h"       => \$help,
			 "g"            => \$use_gnuplot,
			);
help() if $help;
($light_background = 1) if (not $dark_background);
$demeter->plot_with('gnuplot') if $use_gnuplot;

my $target = $ARGV[0] || 'screen';
TARGET: {
  ($target eq 'screen') and do {
    screen($standards);
    last TARGET;
  };

  ($target eq 'web') and do {
    web($standards);
    last TARGET;
  };

  ($target eq 'latex') and do {
    #tex($standards);
    warn "not doing latex yet\n";
    last TARGET;
  };

  ($target eq 'athena') and do {
    athena($standards);
    last TARGET;
  };

  screen($standards);
};

sub screen {
  my ($standards) = @_;
  my ($choice, $element, $which, $error) = ('fe', 'fe', 'mu', q{});
  #$demeter->po->start_plot; # reset the plot for the next go around
  my $term = new Term::ReadLine 'Reference spectra';
  my ($text, $list) = $standards->screen($choice, $element, $light_background, $error);
  print $text;
  my $prompt = "Enter an element, material or number; m|d|f to plot; or q=quit > ",;
  while ( defined ($_ = $term->readline($prompt)) ) {
    $demeter->po->cleantemp, exit if ($_ =~ m{\Aq});
    $error = q{};

    if (($_ =~ m{\A\d+\z}) and ($_ != 0)) {
      $_ = $list->[$_];
    };

    if ($standards -> element_exists (lc($_)) or
	$standards -> material_exists(lc($_)))   {
      $choice = lc($_);
      $element = $choice;
      ($element = $standards->get($choice,"element")) if $standards -> material_exists($choice);

    } elsif ($_ =~ m{\A([mdf])}) {
      $demeter->po->start_plot; # reset the plot for the next go around
      if ($standards -> material_exists($choice)) {
	$which  = ($1 eq 'm') ? 'mu'
	        : ($1 eq 'd') ? 'derivative'
                :               'filter';
	if ($which eq 'filter') {
	  $standards -> filter_plot($element);
	} else {
	  $error = $standards->plot($choice, $which, 'screen');
	};
      };
    };

    ($text, $list) = $standards->screen($choice, $element, $light_background, $error);
    print $text;
  };
};


sub web {
  my ($standards) = @_;
  mkdir $folder if not -d $folder;
  my @materials = $standards->material_list;

  print "writing index file\n" if not $quiet;
  ## make index.html
  my $indexfile = File::Spec->catfile($folder, "index.html");
  $standards -> html_index($indexfile);

  ## make each page
  foreach my $m (@materials) {
    next if ($m eq 'config');
    $standards -> html({
			material => $m,
			folder   => $folder,
			verbose  => !$quiet,
			skip     => $skip,
			noimage  => $noimage,
		       });
  };
};

sub athena {
  my ($standards) = @_;
  die "no output project filename specified.\n" if (not $prjfile);
  my @materials = $standards->material_list;
  my @list = ();
  if ($all) {
    @list = @materials;
  } else {
    @list = split(/,\s*/, $elements);
  };

  my $number = $standards -> athena({elements => \@list,
				     prjfile  => $prjfile,
				     verbose  => !$quiet,
				    });
  printf("\nWrote %s with %d groups\n", $prjfile, $number) if not $quiet;
};

sub help {
  print <<EOH
A visual interface to a database of XAS standard reference materials.

On-screen:
   standards [-l] screen
      -l                choose colors appropriate to a light background

Generate web pages:
   standards [options] web
      --folder=<folder>, -f <folder>    destination for web pages
      --quiet, -q                       suppress progress message
      --skip, -s                        do not overwrite existing pages
      --noimage, -n                     do not generate images (just html)

Generate latex pages:  (not working yet)
   standards [options] latex

Generate an athena project:
   standards [options] athena
      --output=<file>, -o <file>        athena project file
      --elements=<list>, -e <list>      comma separated list of elements
      -a                                put all materials in project file
EOH
  ;
  exit;
};
__END__

=head1 NAME

standards - Visualization of a library of standard reference materials

=head1 VERSION

This documentation refers to Demeter version 0.9.25.

=head1 SYNOPSIS

  standards [options] <mode>

Available modes are

=over 4

=item *

screen

=item *

web

=item *

athena

=back

LaTeX mode is not yet working.

=head1 DESCRIPTION

This program is an attempt to expand and improve upon the
L<pictures of metal foils spectra|http://exafsmaterials.com/Ref_Spectra_0.4MB.pdf>
that come with a box of foils from L<EXAFS Materials|http://exafsmaterials.com>.

That document is fine as far as it goes, but the spectra are not all
of the highest resolution and it only includes foils of a few select
elements.  This implementation expands upon that by inlcuding
reference spectra other than foils.  It is extensible in the sense
that new materials can be added easily.  Thus this visualization of
standard reference spectra can cover more of the periodic table and
include various common (or even uncommon) species of any element.

A small database of reference data ships with Demeter and various
mechanisms are provided for extending the list of materials in the
database.  You can use files on your own computer simply by pointing
the program at that file's location.  You can also grab data from the
web by pointing the program at the data file's URL.

Ideally, adequate metadata is provided about each material such that a
useful and thorough presentation of the data can be made.  This
metadata includes some comments identifying the provenance of the
data, the crystal type used to measure the data, enough information to
properly calibrate the data, and lists of points to mark in mu(E) or
the derivative of mu(E).  The program behaves well in the absence of
any of this metadata, but the utility of the program is dimished.

This program is a wrapper around four distinct ways of visualizing
standards data.  It can be used to interactively plot standards,
selecting elements from an on-screen periodic table.  It can be used
to generate a sequance of web pages that can be dropped on a web
site. It can be used to generate a latex document that can be
converted to PDF and printed to replace the one from EXAFS Materials.
Finally, is can be used to create an Athena project file containing a
subset of the reference materials.

Using this program in these four modes is explained in the following
section.

=head1 MODES

The available modes of operation are:

=over 4

=item screen

In this mode, this is an interactive utility with a simple keyboard
interface.  The user is presented with a screen that looks like this
(albeit in color, if L<Term::ANSIColor> is available):

 Standard reference materials (Demeter 0.9.21)
 .
       H                                                                   He
       Li  Be                                          B   C   N   O   F   Ne
       Na  Mg                                          Al  Si  P   S   Cl  Ar
       K   Ca  Sc  Ti  V   Cr  Mn *Fe  Co  Ni  Cu  Zn  Ga  Ge  As  Se  Br  Kr
       Rb  Sr  Y   Zr  Nb  Mo  Tc  Ru  Rh  Pd  Ag  Cd  In  Sn  Sb  Te  I   Xe
       Cs  Ba  La  Hf  Ta  W   Re  Os  Ir  Pt  Au  Hg  Tl  Pb  Bi  Po  At  Rn
       Fr  Ra  Ac  Rf  Ha  Sg  Bh  Hs
             Ce  Pr  Nd  Pm  Sm  Eu  Gd  Tb  Dy  Ho  Er  Tm  Yb  Lu
             Th  Pa  U   Np  Pu  Am  Cm  Bk  Cf  Es  Fm  Md  No  Lr
 .
 Available Iron (26) standard reference materials
 .
  1) Chromite       : Fe2+Cr2O4             2) Fe             : Iron foil
  3) Ferrihydrite   : 5Fe2O3.9H2O           4) Goethite       : alpha-FeOOH
  5) Hematite       : alpha-Fe2O3           6) Hercynite      : Fe2+Al2O4
  7) Lepidocrocite  : gamma-FeOOH           8) Olivine (Fo0)  : Fe2+2SiO4
  9) Olivine (Fo40) : Fe2+1.2Mg0.8SiO4     10) Olivine (Fo80) : Fe2+1.62Mg0.4SiO4
 11) Pentlandite    : Fe2+4.5Ni4.5S8       12) Pyrrhotite     : Fe2+0.95S
 13) *Troilite      : Fe2+S
 .
      q = quit    m = plot mu(E)    d = plot derivative    f = plot filter
 .
 Comment: 
        File: Fe-K-ALS-10.3.2.prj       Record: 5       Crystal: Si(111)        Edge: K
        Troilite powder on kapton tape, HxV slits = 100x30 um, measured by
        Sirine Fakra, Matthew A. Marcus (10:57 PM 3/15/2007) at ALS 10.3.2
 Enter an element, material or number; m|d|f to plot; or q=quit >

By entering an element symbol, all standards for which that element is
the absorber are listed below the periodic table.  By entering the
name of a material or its number, that one is selected for plotting.
By entering C<m>, C<d>, or C<f>, a useful plot is made of that
material.

Screen mode is the default mode.

=item web

In this mode, the program loops over all materials in the database,
generating an html file for each material as well as a PNG file for
each plot type.  This collection of files can be dropped onto a web
site or viewed locally.  L<Here is an
example|http://bruceravel.github.io/demeter/doc/Standards/>
using the database that ships with Demeter.

=item latex

In this mode, the program loops over all materials in the database,
generating an latex file for each material as well as a PNG file for
each plot type.  This mode has not yet been written.

=item athena

In this mode, one or more elements is selected at the command line and
an Athena project file is generated for every material with those
elements as the absorber.  The idea here is that you can generate a
project file with data analysis standards that can be inorporated into
a project file containing your own data.

=back


=head1 COMMAND LINE SWITCHES

Each mode has its own set of command line switches.  The switches for
one mode are ignored by other modes.

=head2 Screen mode

Example:

  standards -l screen

=over 4

=item C<-l>

Choose screen colors suitable for viewing in a terminal using a light
background color.  The default is to choose colors that look good on a
dark backdrop.

=back

=head2 Web mode

Example:

  standards --folder=html web

=over 4

=item C<--folder>, C<-f>

This takes a string containing the name of the folder in which to
place all generated files.  If the folder does not exist, it will be
created.

=item C<--quiet>, C<-q>

Suppress all screen messages.

=item C<--skip>, C<-s>

Skip all materials for which an html file already exists in the folder
indicated by the C<folder> command line switch.

=item C<--noimage>, C<-n>

Do not generate the image files, while still generating the html
files.

=back

=head2 Athena mode

Example:

  standards --elements="fe,zn" -o mine.prj athena

=over 4

=item C<--outfile>, C<-o>

The name of the output Athena project file.

=item C<--elements>, C<-e>

A comma separated list of element symbols to include in the project
file.  You may need to quote the list for more than one element

=item C<-a>

Include all elements in the database in the project file.

=back

=head1 PLOT TYPES

There are currently three plot types.  All three are available in
screen mode and all three get included in the html page in web mode.

=over 4

=item XANES

This plots the normalized, calibrated XANES data with several
interesting points marked.

=item derivative

This plots the derivative of the XANES data with several interesting
points marked.  The XANES and derivative points are specified
separately in the metadata file.

=item filter

This plots something just like the filter plot in Hephaestus.  Using
the bext guess for fluorescence filter material, this plot shows the
edge of filter along with the edge and line energies of the absorber.

=back

=head1 CONFIGURATION AND ENVIRONMENT

The F<standards.ini> file (which is found under the Demeter F<share>
directory) is used to specify metadata about the various standard
reference materials.  The C<config> section of the file is used to
control a few details of plots that are generated by this program.
All other aspects of Demeter are configured via its configuration
system.

=head1 DEPENDENCIES

The dependencies of the Demeter system are in the
F<Build.PL> file.

=head1 BUGS AND LIMITATIONS

See L<Demeter::Atoms> for bugs and limitations of the underlying
libraries.

=over 4

=item *

LaTeX mode

=item *

More plot types: chi(k), chi(R), second derivative, extended XAS

=item *

Prettier CSS in web mode

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
