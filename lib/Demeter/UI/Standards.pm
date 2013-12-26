package Demeter::UI::Standards;

=for Copyright
 .
 Copyright (c) 2006-2014 Bruce Ravel (bravel AT bnl DOT gov).
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

use Moose;

use autodie qw(open close);

use Carp;
use Chemistry::Elements qw(get_Z get_name);
use File::Basename;
use File::Copy;
use File::Spec;
use Text::Template;
use Text::Wrap;
$Text::Wrap::columns = 75;

use Xray::Absorption;
use Demeter qw(:hephaestus);
my $demeter = Demeter->new;

use Demeter::IniReader;
use Regexp::Assemble;


has 'ini' => (is => 'rw', isa => 'Str',  default => q{},
	      trigger => sub { my ($self, $new) = @_; $self->read_ini($new); });

my %materials_of;
my %elements_of;

my $attribute_regex = Regexp::Assemble->new()->add(qw(tag comment crystal file element record
						      energy numerator denominator ln xmu from_web
						      rebin calibrate xanes deriv
						    ))->re;
my $config_regex = Regexp::Assemble->new()->add(qw(emin emax key_x key_y))->re;



sub read_ini {
  my ($self) = @_;
  my $file = File::Spec->catfile(Demeter->location, "Demeter", "share", "standards", "standards.ini");
  my $ini = Demeter::IniReader->read_file($file);
  #tie %ini, 'Config::IniFiles', ( -file => $file );

  foreach my $k (keys %$ini) {
    $ini->{$k}{element} ||= $k;
    $ini->{$k}{element} = lc($ini->{$k}{element});

    $materials_of{$k} = $ini->{$k};
    ++$elements_of{ $ini->{$k}{element} };

    ## untabulated (generated) attributes
    $materials_of{$k}{from_web} = 0;

    ## sensible fallbacks
    foreach my $att (qw(xmu energy numerator denominator ln comment crystal)) {
      $materials_of{$k}{$att} ||= q{};
    };

    ## deal gracefully with missing callibrate, xanes, or deriv attributes
    my $edge = (get_Z($ini->{$k}{element}) > 57) ? 'l3' : 'k';
    my $edge_energy = Xray::Absorption->get_energy($ini->{$k}{element}, $edge);
    if ( (not exists($materials_of{$k}{calibrate})) or (not $materials_of{$k}{calibrate}) ) {
      $materials_of{$k}{calibrate} = join(", ", $edge_energy, $edge_energy);
    };
    foreach my $plot (qw(xanes deriv)) {
      if ( (not exists($materials_of{$k}{$plot})) or (not $materials_of{$k}{$plot}) ) {
	$materials_of{$k}{$plot} = $edge_energy;
      };
    };

  };
};

sub material_exists {
  my ($self, $mat) = @_;
  return 0 if ($mat eq 'config');
  return 1 if exists $materials_of{ lc($mat) };
  return 0;
};
sub element_exists {
  my ($self, $el) = @_;
  return 0 if ($el eq 'config');
  return 1 if exists $elements_of{ lc($el) };
  return 0;
};

sub get {
  my ($self, $material, $attribute) = @_;
  croak("$attribute is not an attribute of a standard") if ($attribute !~ m{\A$attribute_regex\z});
  return $materials_of{$material}{$attribute};
};
sub config {
  my ($self, $attribute) = @_;
  croak("$attribute is not a standards configuration parameter") if ($attribute !~ m{\A$config_regex\z});
  return $materials_of{config}{$attribute};
};

sub material_list {
  my ($self) = @_;
  return sort {
    (get_Z($materials_of{$a}{element}) <=> get_Z($materials_of{$b}{element}))
      or
    ($a cmp $b)
  } keys(%materials_of );
};

sub resolve_file {
  my ($self, $choice) = @_;
  my $file = $self->get($choice, 'file');
  if ($file =~ m{\Ahttp://}) {
    my $UserAgent_exists = (eval "require LWP::UserAgent");
    return '^^PLOP^^: nolibwww' if not $UserAgent_exists;
    my $ua = LWP::UserAgent->new;
    $ua->timeout(10);
    $ua->env_proxy;
    my $response = $ua->get($file);
    if ($response->is_success) {
      my $dlfile = File::Spec->catfile($demeter->stash_folder, basename($file));
      open my $DAT, ">$dlfile";
      print $DAT $response->content;
      close $DAT;
      $materials_of{$choice}{from_web} = $dlfile;
      $file = $dlfile;
    } else {
      $file = '^^PLOP^^: unsuccessful';
    };
  } else {
    my ($token, $location) = (qw{%share%},
			      File::Spec->catfile($demeter->location, "Demeter", "share")
			     );
    $file =~ s{$token}{$location};
  };
  return $file;
};

sub fetch {
  my ($self, $choice, $thisfile) = @_;
  my $data;
  if ($self->get($choice, 'record')) { # this is an Athena project
    my $prj = Demeter::Data::Prj->new(file=>$thisfile);
    $data = $prj->record( $self->get($choice, 'record') );
  } else {			# this is a file
    my @common_to_all_data_sets = (bkg_rbkg    => 1.0,
				   bkg_spl1    => 0,    bkg_spl2    => 18,
				   bkg_nor1    => 100,  bkg_nor2    => 1000,
				   bkg_flatten => 1,
				   fft_kmax    => 3,    fft_kmin    => 17,
				  );
    $data = Demeter::Data -> new(@common_to_all_data_sets);
    $data -> set(file => $thisfile,
		 name => $self->get($choice, 'tag'),
		);
  };
  $data -> po -> start_plot;

  if ($self->get($choice, 'xmu')) {
    $data -> set( is_col => 0 );
  } elsif ($self->get($choice, 'record')) {
    1;
  } else {
    $data -> set(
		 energy      => $self->get($choice, 'energy'),
		 numerator   => $self->get($choice, 'numerator'),
		 denominator => $self->get($choice, 'denominator'),
		 ln          => $self->get($choice, 'ln'),
		 datatype    => 'xmu',
		);
  };
  return $data;
};

sub save {
  my ($self, $choice, $fname) = @_;
  my $cc = $choice;
  $choice = lc($choice);
  my $thisfile = $self->resolve_file($choice);
  return "The download of the remote data file for \"$cc\" failed."                    if ($thisfile eq '^^PLOP^^: unsuccessful');
  return "You do not have perl's libwww installed, so remote files cannot be plotted." if ($thisfile eq '^^PLOP^^: nolibwww');
  my $data = $self->fetch($choice, $thisfile);
  $data->save("xmu", $fname);
  return $self;
};

sub plot {
  my ($self, $choice, $which, $target) = @_;
  my $cc = $choice;
  $choice = lc($choice);
  my $thisfile = $self->resolve_file($choice);
  return "The download of the remote data file for \"$cc\" failed."                    if ($thisfile eq '^^PLOP^^: unsuccessful');
  return "You do not have perl's libwww installed, so remote files cannot be plotted." if ($thisfile eq '^^PLOP^^: nolibwww');

  my $data = $self->fetch($choice, $thisfile);

  my $rebinned;
  if ($self->get($choice, 'rebin')) {
    $rebinned = $data->rebin;
    $rebinned -> name($data->name);
  };
  my $ddd = ($self->get($choice, 'rebin')) ? $rebinned : $data;
  $ddd->update_norm(1);
  $ddd->calibrate(split(/,\s*/, $self->get($choice, 'calibrate'))) if not ($self->get($choice, 'record'));

  return $ddd if ($target eq 'athena');

  $ddd -> po -> legend(x => $self->config('key_x'),
		       y => $self->config('key_y'),
		      );
  $ddd -> po -> set(e_der  => ($which =~ m{deriv}) ? 1 : 0,
		    e_bkg  => 0,
		    e_sec  => 0,
		    e_norm => ($which =~ m{mu})    ? 1 : 0,
		    e_pre  => 0,
		    e_post => 0,
		    e_markers => 0,
		    e_smooth => $ddd->co->default("plot", "e_smooth"),
		    emin   => $self->config('emin'),
		    emax   => $self->config('emax'),
		    );
  $ddd -> plot('E');
  my $part = ($which =~ m{deriv}) ? 'der'   : 'flat';
  my $list = ($which =~ m{deriv}) ? 'deriv' : 'xanes';

  my @points = split(/,\s*/, $self->get($choice, $list));
  $ddd -> plot_marker($part, \@points);

  foreach my $x (@points) {
    my $y = $ddd->yofx($part, q{}, $x);
    $ddd->po->textlabel($x+3, 1.02*$y, $x);
  };

  if ($target =~ m{\.png\z}) {
    $ddd -> po -> file("png", $target);
  } elsif ($target =~ m{\.ps\z}) {
    $ddd -> po -> file("ps", $target);
  };

  ## clean up stash_folder
  if ($self->get($choice, 'from_web')) {
    unlink $self->get($choice, 'from_web');
  };

  ## clean up in ifeffit before returning
  return 0;
};

sub filter_plot {
  my ($self, $elem) = @_;
  my $po     = $demeter->po;
  my $config = $demeter->co;

  my $z      = get_Z($elem);
  my $filter = Xray::Absorption -> recommended_filter($z);
  my $edge   = ($z < 57) ? "K"   : "L3";
  #my $line1  = ($z < 57) ? "Ka1" : "Lb2";
  my $line2  = ($z < 57) ? "Ka2" : "La1";
  #my $line3  = ($z < 57) ? q{}   : "La2";

  $config->set(
	       filter_abs => get_Z($elem),
	       filter_edge     => $edge,
	       filter_filter   => $filter,
	       filter_emin     => Xray::Absorption -> get_energy($z, $line2) - 400,
	       filter_emax     => Xray::Absorption -> get_energy($z, $edge)  + 300,
	       filter_file     => $po->tempfile,
	      );
  $po -> start_plot;
  my $command = $demeter->template('plot', 'prep_filter');
  $po -> dispose($command);

  $command = $demeter->template('plot', 'filter');
  $po -> legend(x => 0.15, y => 0.85, );
  $po -> dispose($command, "plotting");
  #Demeter -> set_mode(screen=>0);
};

my @periodic_table =
  (
   ['H',  q{},  q{},  q{},  q{},  q{},  q{},  q{},  q{},  q{},  q{},  q{},  q{},  q{},  q{},  q{},  q{},  'He'],
   ['Li', 'Be', q{},  q{},  q{},  q{},  q{},  q{},  q{},  q{},  q{},  q{},  'B',  'C',  'N',  'O',  'F',  'Ne'],
   ['Na', 'Mg', q{},  q{},  q{},  q{},  q{},  q{},  q{},  q{},  q{},  q{},  'Al', 'Si', 'P',  'S',  'Cl', 'Ar'],
   ['K',  'Ca', 'Sc', 'Ti', 'V',  'Cr', 'Mn', 'Fe', 'Co', 'Ni', 'Cu', 'Zn', 'Ga', 'Ge', 'As', 'Se', 'Br', 'Kr'],
   ['Rb', 'Sr', 'Y',  'Zr', 'Nb', 'Mo', 'Tc', 'Ru', 'Rh', 'Pd', 'Ag', 'Cd', 'In', 'Sn', 'Sb', 'Te', 'I',  'Xe'],
   ['Cs', 'Ba', 'La', 'Hf', 'Ta', 'W',  'Re', 'Os', 'Ir', 'Pt', 'Au', 'Hg', 'Tl', 'Pb', 'Bi', 'Po', 'At', 'Rn'],
   ['Fr', 'Ra', 'Ac', 'Rf', 'Ha', 'Sg', 'Bh', 'Hs', 'Mt',  q{},  q{},  q{},  q{},  q{},  q{},  q{},  q{}, q{} ],

   ['Ce', 'Pr', 'Nd', 'Pm', 'Sm', 'Eu', 'Gd', 'Tb', 'Dy', 'Ho', 'Er', 'Tm', 'Yb', 'Lu',],
   ['Th', 'Pa', 'U',  'Np', 'Pu', 'Am', 'Cm', 'Bk', 'Cf', 'Es', 'Fm', 'Md', 'No', 'Lr',],
  );
my $clear = (($^O eq 'MSWin32') or ($^O eq 'cygwin')) ? q{} : `clear`;

use subs qw(BOLD RED RESET YELLOW GREEN BLUE MAGENTA CYAN UNDERLINE REVERSE);
my $ANSIColor_exists = (eval "require Term::ANSIColor");
if ($ANSIColor_exists) {
  import Term::ANSIColor qw(:constants);
} else {
  foreach my $s (qw(BOLD RED RESET YELLOW GREEN BLUE MAGENTA CYAN UNDERLINE REVERSE)) {
    eval "sub $s {q{}}";
  };
};

sub screen {
  my ($self, $choice, $element, $light, $error) = @_;
  my $text = q{};

  my $INDIC  = ($light) ? BLUE    : YELLOW;
  my $MARKED = ($light) ? REVERSE : CYAN;

  $text .= $clear;
  $text .= RED . BOLD . "Standard reference materials (Demeter " . $demeter->version . ")\n\n" . RESET;

  my $count = 0;
  foreach my $row (@periodic_table) {
    $text .= " " x 6;
    $text .= " " x 6 if ($count > 6);
    foreach my $elem (@$row) {
      next if ($elem eq 'Mt');
      my $this = sprintf(" %-3s", $elem);
      if ($self -> element_exists(lc($elem))) {
	if ((lc($choice) eq lc($elem)) or
	    ( $self -> material_exists($choice) and
	      ($self -> get($choice,"element") eq lc($elem)) ) ) {
	  ($this = BOLD . $MARKED . sprintf("*%-3s", $elem) . RESET);
	} else {
	  ($this = BOLD . $INDIC . sprintf(" %-3s", $elem) . RESET);
	};
      };
      $text .= $this;
    };
    ++$count;
    $text .= "\n";
  };

  my $stan =  ($self -> material_exists($choice))
    ? get_name($self -> get($choice, 'element')) : get_name($choice);
  $text .= RED . BOLD . "\nAvailable $stan standard reference materials\n\n" . RESET;
  my $i = 1;
  my $template = " %s%s%14s%s : (%2d) %-15s";
  foreach my $data ($self->material_list) {
    next if ($data eq 'config');
    next if ($element ne $self->get($data, 'element'));

    if (lc($data) eq lc($choice)) {
      $text .= sprintf($template, BOLD, $MARKED, '*'.ucfirst(lc($data)), RESET, get_Z($self->get($data, 'element')), $self->get($data, 'tag'));
    } else {
      $text .= sprintf($template, BOLD, $INDIC,      ucfirst(lc($data)), RESET, get_Z($self->get($data, 'element')), $self->get($data, 'tag'));
    };
    $text .= ($i % 2) ? "    " : "\n";
    ++$i;
  };
  $text .= ($i % 2) ? "\n" : "\n\n";

  ## q to quit
  $text .= sprintf("      %s%s%s%s = %s    %s%s%s%s = %s    %s%s%s%s = %s    %s%s%s%s = %s\n\n",
		   BOLD, $INDIC, "q", RESET, "quit",
		   BOLD, $INDIC, "1", RESET, "plot mu(E)",
		   BOLD, $INDIC, "2", RESET, "plot derivative",
		   BOLD, $INDIC, "3", RESET, "plot filter",
		  );
  if ($self->material_exists($choice)) {
    my $record = $self->get($choice, 'record')
      ? join(q{}, GREEN, "\tRecord: ", RESET, $self->get($choice, 'record'))
	: q{};

                       ## red comment line
    $text .= join(q{}, RED, BOLD, "Comment: ", RESET, "\n",
		  ## file and crystal
		  GREEN, "\tFile: ",    RESET, basename($self->get($choice, 'file')),
		  $record,
		  GREEN, "\tCrystal: ", RESET, $self->get($choice, 'crystal'), "\n",
		  ## comment, nicely wrapped
		  wrap("\t", "\t", $self->get($choice, 'comment')), "\n"
		 );
  };
  if ($error) {
    $text .= "\n\t*** " . BOLD . MAGENTA . $error . RESET . "\n";
  };
  return $text;
};




sub html_index {
  my ($self, $indexfile) = @_;
  $indexfile ||= "index.html";
  my $tmpl = File::Spec->catfile($demeter->location,
				 "Demeter",
				 "share",
				 "standards",
				 "templates",
				 "htmlindex.tmpl"
				);
  my $template = Text::Template->new(TYPE => 'file', SOURCE => $tmpl)
    or die "Couldn't construct template: $Text::Template::ERROR";
  open my $OUT, ">$indexfile";
  print $OUT $template -> fill_in(HASH => { S => \$self });
  close $OUT;
  return $self;
}

sub html {
  my ($self, $args) = @_;

  my $which = $args->{material};
  my $elem  = $self->get($which, 'element');
  my $outfile = File::Spec->catfile($args->{folder}, "$which.html");
  my $filterimage = File::Spec->catfile($args->{folder}, $elem."_filter.png");
  return $self if ($args->{skip} and (-e $outfile));
  my $share = File::Spec->catfile($demeter->location,
				  "Demeter",
				  "share"
				 );
  my $tmpl = File::Spec->catfile($share,
				 "standards",
				 "templates",
				 "htmlpage.tmpl"
				);
  print $which, " ";

  if (not $args->{noimage}) {
    $demeter -> po -> start_plot;
    print "XANES ..." if $args->{verbose};
    $self -> plot($which, "mu",         File::Spec->catfile($args->{folder}, $which."_mu.png" ));
    $demeter -> po -> start_plot;
    print " derivative ..." if $args->{verbose};
    $self -> plot($which, "derivative", File::Spec->catfile($args->{folder}, $which."_der.png"));

    if (not -e $filterimage) {
      print " filter ..." if $args->{verbose};
      $self -> filter_plot($elem);
      $demeter -> po -> file("png", $filterimage);
    };
  };

  print " html ..." if $args->{verbose};

  my $datadir = File::Spec -> catfile($args->{folder}, "data");
  mkdir $datadir if not -d $datadir;

  my $token = qw{%share%};
  my $file  = $self->get($which, "file");
  if ($file =~ m{\Ahttp://}) {
    1;
  } elsif ($file =~ m{$token}) {
    $file =~ s{$token}{$share};
    copy($file, $datadir);
  } else {
    copy($file, $datadir);
  };
  $file = basename($file);

  my $template = Text::Template->new(TYPE => 'file', SOURCE => $tmpl)
    or die "Couldn't construct template: $Text::Template::ERROR";

  open my $OUT, ">$outfile";
  print $OUT $template ->
    fill_in(HASH => {
		     S         => \$self,
		     this      => $which,
		     file      => $file,
		    }
	   );
  close $OUT;
  print " done!\n" if $args->{verbose};
  return $self;
};

sub athena {
  my ($self, $args) = @_;
  $args->{prjfile} ||= "standards.prj";
  my @list = @{$args->{elements}};
  my @materials = $self->material_list;
  my $regex = join("|", @list);
  my @groups = ();
  print "Writing athena project file for:" if $args->{verbose};
  foreach my $m (@materials) {
    next if ($m eq 'config');
    next if not ($self->get($m, 'element') =~ m{\A(?:$regex)\z}i);
    print " $m" if $args->{verbose};
    my $response = $self->plot($m, 0, 'athena');
    push @groups, $response if (ref($response) =~ m{Demeter});
  };
  die "\n *** No available elements specified.  Exiting.\n" if (not @groups);
  $groups[0] -> write_athena($args->{prjfile}, @groups);
  return $#groups+1;
};


1;


=head1 NAME

Demeter::UI::Standards - Standard reference material database interaction

=head1 VERSION

This documentation refers to Demeter version 0.9.19.

=head1 SYNOPSIS

  use Demeter;
  use Demeter::UI::Standards;
  my $standards = Demeter::UI::Standards -> new;

=head1 DESCRIPTION

This module provides methods for an attempt to expand and improve upon
the L<pictures of metal foils
spectra|http://exafsmaterials.com/Ref_Spectra_0.4MB.pdf> that come
with a box of foils from L<EXAFS Materials|http://exafsmaterials.com>.

That document is fine as far as it goes, but the spectra are not all
of the highest resolution and it only includes foils of a few select
elements.  This implementation expands upon that by including
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

This module is a wrapper around four distinct ways of visualizing
standards data.  It can be used to interactively plot standards,
selecting elements from an on-screen periodic table or with a GUI.  It
can be used to generate a sequence of web pages that can be dropped on
a web site. It can be used to generate a latex document that can be
converted to PDF and printed to replace the one from EXAFS Materials.
Finally, is can be used to create an Athena project file containing a
subset of the reference materials.

=head1 METHODS

=head2 General methods

These are the methods for handling the Standards object, which
encapsolates the metadata describing the standard reference materials.

=over 4

=item C<material_exists>

This method returns true if the argument string identifies a material
in the database.

  $exists = $standards -> material_exists("Zn");

=item C<element_exists>

This method returns true if the argument string identifies an element
represented by one or more materials in the data base.

  $exists = $standards -> element_exists("U");

=item C<get>

This method returns one of the attributes of a database entry.

  $comment = $standards -> get("fe", "comment");

=item C<config>

This method returns one of the plotting configuration parameters.

  $emin = $standards -> config("emin");

Currently, the Standards-specific configuration parameters control the
plotting range and the placement of the legend.  The keywords are
C<emin>, C<emax>, C<key_x>, and C<key_y>

=item C<material_list>

This returns a list of all keys identifying the materials in the
database.  The list is sorted first by Z number of the absorber then
alphabetically by material name.

=back

=head2 Formatting methods

These methods are used to control the output for the various
visualization modes.  Available modes are

=over 4

=item *

screen

=item *

web

=item *

athena

=back

LaTeX mode is not yet working.

=over 4

=item C<plot>

This is the workhorse.  It reads and processes a data file according
to the metadata and prepares the data for display in the chosen output
mode.

  $response = $standards -> plot($material, $plot_type, $target);

C<$material> is a material contained in the database.  C<$plot_type>
is an integer between 1 and 3.  A value of 1 says to prepare to plot
XANES data.  A value of 2 says to prepare to plot the derivative
spectrum.  A value of 3 says to prepare a plot explaining the use of a
fluorescence filter.

C<$target> identifies the visualization mode and takes one of four
values:

=over

=item C<screen>

The data will be plotted on screen.  For this target the return value
will be an empty string is no problems are encountered or a error
message explaining the source of the error.

=item C<athena>

The data processing will be stopped before any plotting actually
happens.  In this case, the return value is a reference to a Data
object conatining that standard.  This can then be written to an
athena project file or otherwise handled in the manner of Data object.

=item I<filename>C<.png>

If the target ends in C<.png>, then the plot will be written to a PNG
file with that name.  When using PGPLOT, it is recommended that you
set the C<PGPLOT_DEV> environment variable to C</null>.  That will
suppress all plots to the screen before the PNG file is generated.
The return value is the same as for the screen target.

=item I<filename>C<.ps>

If the target ends in C<.ps>, then the plot will be written to a
postscript file with that name.  When using PGPLOT, it is recommended
that you set the C<PGPLOT_DEV> environment variable to C</null>.  That
will suppress all plots to the screen before the postscript file is
generated.  The return value is the same as for the screen target.

=back

=item C<html_index>

This method writes an index file for the html output.  The index file
contains links to each of the individual material files in a simple
table.  The argument is the fully resolved name for the index file.

  $standard -> html_index($indexfile);

=item C<html>

This method writes a page for a given material.  All arguments are
passed as a hash reference.  The C<folder> argument is the output
location for the html file and all image files.  The C<skip> argument
says to skip this material if the html file already exists in the
output folder.  Setting C<verbose> to 0 turns off all messages to
STDOUT.

  $standards -> html({
		      material => "fe",
		      folder   => "html",
		      verbose  => 1,
		      skip     => 0,
		     });

=item C<latex>

Not written yet.

=item C<athena>

This method generates an Athena project file for all materials with an
absorber in the list specified by the C<elements> key of the has
reference which is passed as the sole argument.  The output project
file is specified by C<prjfile>.  It will be written to
F<standards.prj> in the current directory if not otherwise stated.
Setting C<verbose> to 0 turns off all messages to STDOUT.

  $standards -> athena({
                        elements => \@list_of_elements,
			prjfile  => "standards.prj",
			verbose  => 1,
                       });

=back

=head1 CONFIGURATION AND ENVIRONMENT

The meta data -- that is the data about the reference data -- is
contained in the F<standards.ini> file.  Here is an example:

  [fe]
  tag         = Iron foil
  comment     = Iron foil measured at NSLS X11A 10/4/2002 by BR
  crystal     = Si(111)
  file        = %share%/standards/data/fe.stan
  energy      = $1
  numerator   = $2
  denominator = $3
  ln          = 1
  calibrate   = 7106.135, 7112
  xanes       = 7112, 7116.41, 7131.22, 7141.83
  deriv       = 7112, 7120.88, 7129.263

The first few lines describe the data.  The C<file> line identifies
the data file containing the reference.  The "C<%share%>" token is
replaced with the actual installation location of Demeter.  The next
four lines explain how to for mu(E) data from the columns in the file.
The last three lines are used to calibrate the data and mark the
interesting points in the XANES or derivative spectra.

Another option is to import data from an Athena project file.  Here is
an example:

  [cd]
  tag         = Cadmium foil
  comment     = Cadmium foil, measured at APS 10ID Nov 18, 2006
  crystal     = Si(111)
  file        = %share%/standards/data/Cd.prj
  record      = 1
  xanes       = 26711, 26720.06, 25740.66, 25772.57
  deriv       = 26711, 26714, 26734.60, 26745.10

In this case, the C<record> parameter is used to identify the location
of the data in the project file.  The Athena project file is presumed
to contain well processed data, thus the rebinning and calibration
steps are never performed for data from an project file.

The first section of the F<standards.ini> file contains the
configuration data and is used to control some aspects of the plots
made of the reference data.

The output html and latex files are formatted using L<Text::Template>
templates, which can be found in the F<share> directory of the Demeter
installation.  This is the same formatting system as used for
Demeter's output, but the template files are in a different location.

All other configuration is handled using Demeter's configuration
system.

=head1 DEPENDENCIES

This uses Demeter and its dependencies.

=head1 BUGS AND LIMITATIONS

=over 4

=item *

latex output

=item *

load user ini files (i.e. ~/.horae/standards.ini)

=item *

load site-specific ini files

=item *

other local data locations, other web locations

=back

Please report problems to the Ifeffit Mailing List
(L<http://cars9.uchicago.edu/mailman/listinfo/ifeffit/>)

Patches are welcome.

=head1 AUTHOR

Bruce Ravel (bravel AT bnl DOT gov)

L<http://bruceravel.github.io/demeter/>


=head1 LICENCE AND COPYRIGHT

Copyright (c) 2008-2014 Bruce Ravel (bravel AT bnl DOT gov). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut


