package Ifeffit::Demeter::Config;

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
#use diagnostics;
use Class::Std;
use Config::IniFiles;
use Fatal qw(open close);
use File::Basename;
use Regexp::List;
use Regexp::Optimizer;
use Regexp::Common;
use Readonly;
Readonly my $NUMBER => $RE{num}{real};
use YAML;
use Text::Wrap;
use aliased 'Ifeffit::Demeter::Tools';
#use Data::Dumper;

{
  use base qw( Ifeffit::Demeter
               Ifeffit::Demeter::Dispose
               Ifeffit::Demeter::Project
             );

  my @reserved = qw((chi_reduced chi_square core_width correl_min
		    cursor_x cursor_y dk dr data_set data_total
		    dk1 dk2 dk1_spl dk2_spl dr1 dr2 e0 edge_step
		    epsilon_k epsilon_r etok kmax kmin kmax_spl
		    kmax_suggest kmin_spl kweight kweight_spl kwindow
		    n_idp n_varys ncolumn_label nknots norm1 norm2
		    norm_c0 norm_c1 norm_c2 path_index pi pre1 pre2
		    pre_offset pre_slope qmax_out qsp r_factor rbkg
		    rmax rmax_out rmin rsp rweight rwin rwindow toler));

  my %ini;
  tie %ini, 'Config::IniFiles', ();

  my $one_has_been_created = 0;
  my $one_has_been_configured = 0;

  sub BUILD {
    my ($self) = @_;
    if ($one_has_been_created) { # v. crude singleton object
      carp("You cannot have more than one Config object");
      $self->DESTROY;
      return;
    };
    $one_has_been_created = 1;
  };

  sub get{
    my ($self, @params) = @_;
    my @values = $self -> SUPER::get(@params);
    @values = map { $_ ||= q{} } (@values); # always return something defined!
    return wantarray ? @values : $values[0];
  };
  sub _regexp {
    my ($self) = @_;
    return q{};
  };

  sub is_configured {
    my ($self) = @_;
    return $one_has_been_configured;
  };

  sub groups {
    my ($self) = @_;
    my @list = @{ $self->get('___groups') };
    return sort @list;
    #my %hash = $self->get_params_of;
    #my @keys = keys(%hash);
    #my %seen = ();
    #foreach my $k (@keys) {
    #  my ($g, $p) = split(/:/, $k);
    #  ++$seen{$g};
    #};
    #return (sort keys %seen);
  };

  sub parameters {
    my ($self, $group) = @_;
    my %hash = $self->get_params_of;
    my @keys = keys(%hash);
    my @seen = ();
    foreach my $k (@keys) {
      my ($g, $p) = split(/:/, $k);
      push @seen, $p if ($p and ($g eq $group));
    };
    return sort @seen;
  };

=for LiteratureReference (read_config)
  Before land was and sea -- before air and sky
  Arched over all, all Nature was Chaos.
  ...
  The God or Nature calmed the elements:
  Land fell away from sky and sea from land,
  And aether drew away from cloud and rain.
                      Ovid,
                      Metamorphoses, Book I

=cut

  sub read_config {
    my ($self) = @_;
    my $file = File::Spec->catfile(dirname($INC{"Ifeffit/Demeter.pm"}),
				   "Demeter",
				   "configuration",
				   "config.demeter_conf");
    $self->_read_config_file($file);
    $one_has_been_configured = 1;
    return $self;
  };
  sub _read_config_file {
    my ($self, $file) = @_;

    ## need to distinguish between a relative filename and a fully
    ## resolved file.

    carp("The Demeter configuration file ($file) does not exist"), return 0
      if (not -e $file);
    carp("The Demeter configuration file ($file) cannot be opened"), return 0
      if (not -r $file);

    my $base = (split(/\./, basename($file)))[0];
    $self -> Push({___groups => $base});

    ## the first time this is called, the regexp method has not yet
    ## been defined -- grrr..!
    my $opt  = Regexp::List->new;
    my $key_regex = $opt->list2re(qw(type default minint maxint options
				     units onvalue offvalue));
    ##my $key_regex = Ifeffit::Demeter -> regexp("config");

    my (%hash, $description, $group, $param, $value);
    my $line;
    open (my $CONFIG, $file);
  CONF: while (my $line = <$CONFIG>) {
      next CONF if ($line =~ m{^\s*\#});
      next CONF if ($line =~ m{^\s*$});

      chomp $line;
      $line =~ s{\s+$}{};
      if ($line =~ m{^\s*include\s*(.+)}) {
	## handle include files by recursion
	(my $includefile = $1) =~ s{\s+(?:\#.*)?$}{};
	$includefile = File::Spec->catfile(dirname($file), $includefile);
	$self->_read_config_file($includefile);
      } elsif ($line =~ m{^\s*section\s*=\s*(\w+)}) {
	$group = $1;
	$group =~ s{\s+$}{};
	$description = q{};

      } elsif ($line =~ m{^\s*section_description}) {
      SECDESC: while (my $next = <$CONFIG>) {
	  $next =~ s{\n}{ };
	  $next =~ s{^\s+}{};
	  last SECDESC if ($next =~ m{^\s*$});
	  $description .= $next;
	};
	$description =~ s{\s+$}{};
	$self -> set({$group=>$description});

      } elsif ($line =~ m{^\s*description}) {
      DESC: while (my $next = <$CONFIG>) {
 	  $next =~ s{\n}{ };
 	  $next =~ s{^\s+}{};
 	  last DESC if ($next =~ m{^\s*$});
	  if ($next =~ m{^\.}) {
	    $next =~ s{\.\s+}{\%list};
	    $next =~ s{\s}{\%space}g;
	    $next .= '%endlist';
	  };
 	  $description .= $next;
 	};
	$description =~ s{\s+$}{};
 	$hash{description} = $description;
	$self->set_this_param($group, $param, %hash);
 	next CONF;

      } elsif ($line =~ m{^\s*variable\s*=\s*(\w+)}) {
	$param = $1;
	$param =~ s{\s+$}{};
	undef %hash;
	$ini{$group}{$param} = q{};
	$description = q{};

      } elsif ($line =~ m{^\s*($key_regex)\s*=\s*(.+)}) {
	$value = $2;
	$value =~ s{\s+$}{};
	$hash{$1} = $value;
	($hash{demeter} = $value) if ($1 eq "default");
      };
    };
    $self->set_this_param($group, $param, %hash) if %hash;
    close $CONFIG;
    return $self;
  };

  sub set_this_param {
    my ($self, $group, $param, %hash) = @_;
    use Data::Dumper;
    my $key = join(":", $group, $param);
    $hash{default}     ||= 0;	# sanitize several attributes
    $hash{description} ||= q{};
    if ($hash{type} eq 'positive integer') {
      $hash{maxint} ||= 1e13;
      $hash{minint} ||= 0;
    } elsif ($hash{type} eq 'boolean') {
      $hash{onvalue}  ||= 1;
      $hash{offvalue} ||= 0;
    };
    $self -> set({$key=>\%hash});
    $ini{$group}{$param} = $hash{default};
    return $self;
  };

  ## override a default value, for instance when reading an ini file
  sub set_default {
    my ($self, $group, $param, $value) = @_;
    return q{} if not $param;
    my $key = join(":", $group, $param);
    my $rhash = $self->get($key);
    $rhash->{default} = $value;
    if ($rhash->{type} eq 'boolean') {
      $rhash->{default} = ($self->is_true($value)) ? "true" : "false";
    } elsif ($rhash->{type} eq 'positive integer') {
      ($rhash->{default} = $rhash->{maxint}) if ($value > $rhash->{maxint});
      ($rhash->{default} = $rhash->{minint}) if ($value < $rhash->{minint});
    };
    $self -> set({$key=>$rhash});
    return $self;
  };
  sub new_params {
    my ($self, $rhash) = @_;
    $self->set($rhash);
    return 1;
  };

  sub default {
    my ($self, $group, $param) = @_;
    return q{} if not $param;
    my $key = join(":", $group, $param);
    my $rhash = $self->get($key);
    carp("$key is not a valid configuration parameter"), return 0 if not $rhash;
    if ($rhash->{type} eq 'boolean') {
      return $rhash->{onvalue}  || 1 if ($rhash->{default} eq 'true');
      return $rhash->{offvalue} || 0;
    };
    if ($rhash->{type} eq 'positive integer') {
      return $rhash->{maxint} if ($rhash->{default} > $rhash->{maxint});
      return $rhash->{minint} if ($rhash->{default} < $rhash->{minint});
    };
    return $rhash->{default};
  };
  {
    no warnings 'once';
    # alternate names
    *def = \ &default;
  }

  sub description {
    my ($self, $group, $param) = @_;
    my $key = ($param) ? join(":", $group, $param) : $group;
    return $self->get($key) if (not $param);
    my $rhash = $self->get($key);
    carp("$key is not a valid configuration parameter"), return 0 if not $rhash;
    return $rhash->{description};
  };
  sub attribute {
    my ($self, $which, $group, $param) = @_;
    return q{} if not $param;
    my $key = join(":", $group, $param);
    my $rhash = $self->get($key);
    carp("$key is not a valid configuration parameter"), return 0 if not $rhash;
    return $rhash->{$which} || q{};
  };
  sub type     {my $self=shift; $self->attribute("type",     @_)};
  sub units    {my $self=shift; $self->attribute("units",    @_)};
  sub demeter  {my $self=shift; $self->attribute("demeter",  @_)};
  sub options  {my $self=shift; $self->attribute("options",  @_)};
  sub onvalue  {my $self=shift; $self->attribute("onvalue",  @_)};
  sub offvalue {my $self=shift; $self->attribute("offvalue", @_)};
  sub minint   {my $self=shift; $self->attribute("minint",   @_)};
  sub maxint   {my $self=shift; $self->attribute("maxint",   @_)};

  sub describe_param {
    my ($self, $group, $param, $width) = @_;
    my $config = Ifeffit::Demeter->get_mode("params");
    my $text = q{};
    local $Text::Wrap::columns = $width || $config->default("operations", "config_text_width");
    local $Text::Wrap::huge = "overflow";
    if ($param) {
      my $key = join(":", $group, $param);
      my $rhash = $self->get($key);
      return q{} if not $rhash;
      $text .= "$group -> $param\n";
      my $desc = wrap("    \"", "     ", $rhash->{description}) . "\"\n";
      $desc =~ s{\%list}{\n        }g;
      $desc =~ s{\%space}{ }g;
      $desc =~ s{\%endlist}{}g;
      $text .= $desc;
      foreach my $k qw(type default demeter options units minint maxint onvalue offvalue) {
	$text .= sprintf("  %-8s : %s\n", $k, $rhash->{$k}) if defined $rhash->{$k};
      };
    } else {
      my $description = $self->get($group);
      return q{} if not $description;
      $text .= "$group:\n";
      $text .= wrap("    \"", "     ", $description) . "\"\n";
    };
    return $text;
  };

  sub write_ini {
    my ($self, $file) = @_;
    my $where = (Tools->is_windows) ? "USERPROFILE" : "HOME";
    $file ||= File::Spec->catfile($ENV{$where}, ".horae", "demeter.ini");
    my $ini_ref = tied %ini;
    $ini_ref -> WriteConfig($file);
    return $self;
  };

  sub read_ini {
    my ($self) = @_;
    my $where = (Tools->is_windows) ? "USERPROFILE" : "HOME";
    my $inifile = File::Spec->catfile($ENV{$where}, ".horae", "demeter.ini");
    if (not -e $inifile) {
      $self->write_ini($inifile);
      return $self;
    };
    my %personal_ini;
    my $ini_ref = tied %ini;
    tie %personal_ini, 'Config::IniFiles', (-file=>$inifile, -import=>$ini_ref );
    foreach my $g (keys %personal_ini) {
      my $hash = $personal_ini{$g};
      foreach my $p (keys %$hash) {
	$self->set_default($g, $p, $personal_ini{$g}{$p});
      };
    };
    return $self;
  };

};
1;

=head1 NAME

Ifeffit::Demeter::Config - Demeter's configuration system

=head1 VERSION

This documentation refers to Ifeffit::Demeter version 0.1.

=head1 DESCRIPTION

This subclass of Ifeffit::Demeter provides a general way of storing
and manipulating parameters of all sorts, including configuration
parameters for controlling the behavior of Demeter's various
subsystems, parameters using by Demeter-base applications, and
parameters that get passed to the templating subsystem.  The C<$C>
special templating variable accesses this object.

Demeter uses a two-tiered configuration system.  The system-wide tier
reads from a configuration file F<demeter.config> which lives in the
F<lib/> directory beneath the F<Demeter.pm> module.  This
configuration file contains complete information about each
configuration parameter, including description text and various
attributes.  The second tier is the user's initialization file.  This
uses the standard INI format and the L<Config::IniFiles> module.  The
user's file lives in $ENV{HOME} on unix and Mac and in
$ENV{USERPROFILE} on Windows.

Defining new parameters to be handled by Config is as simple as
entering them into the INI file using normal INI syntax.  Those
user-created parameters will not possess descriptions or other
attributes, however.

=head1 METHODS

The normal idiom for accessing method of the Config class is to chain
method calls starting with any other Demeter object.  Although you are
free to store a reference to the Config object in a scalar, it usually
is not necessary to do so.

The C<config> method, inhereted by all other objects from the Demeter
base class, returns a reference to the Config object.  All of the
examples below use the chain idiom and C<self> can be any kind of
object.

=head2 External methods

=over 4

=item C<default>

Return the default value for a parameter.

  print "Default fft kmin is ", $object->config->default("fft", "kmin"), $/;

=item C<set_default>

This method is called repeatedly by C<read_ini> to move the
information from the user's ini file into the Config object.

  $object -> config -> set_default("bkg", "rbkg", 1.2);

=item C<describe>

Return a text description of a parameter.

  print $object -> config -> describe("bkg", "kw");
   == prints ==>
    bkg -> kw
        "The default value for the k-weighting used to fit the background spline."
      type     : positive integer
      default  : 2
      demeter  : 2
      minint   : 0
      maxint   : 3

There is a third argument that controls the width of the description
text, the default being 90 (as set by the
C<operations-E<gt>config_text_width> parameter).

  print $object -> config -> describe("bkg", "kw", 45);
   == prints ==>
    bkg -> kw
        "The default value for the k-weighting
         used to fit the background spline."
      type     : positive integer
      default  : 2
      demeter  : 2
      minint   : 0
      maxint   : 3

=item C<groups>

Return a list of known configuration groups.

  @groups = $object -> config -> groups;

=item C<parameters>

Return a list of parameters associated with a specified configuration group.

  @params = $object -> config -> parameters('bkg');

=back

=head2 ini file methods

=over 4

=item C<read_ini>

Read default values from a user's ini file, overwriting the values
read from the system-wide configuration file.

  $object -> config -> read_ini($filename);

=item C<write_ini>

Write an ini file for a user.

  $object -> config -> write_ini($filename);

If the filename is not given, the user's ini file will be written.

=back

=head2 Internal methods

=over 4

=item C<is_configured>

This method returns true if a Config object has been created and
initialized by the C<read_config> method.

=item C<read_config>

This method reads the system-wide configuration file,
F<demeter.config>, from it location in the F<Demeter/lib/> folder just
below the main F<Demeter.pm> module.  This loads the entire contents,
including default values, parameter descriptions, and parameter
attributes, into the Config object.

=item C<set_this_param>

Use this method to update the default value for a parameter.  For
example, the C<read_ini> method calls this repeatedly.  Note that the
original value of each parameter from the F<demeter.config> file always
stays in the object as the "demeter" parameter attribute.

   $object->set_this_param($group, $param, %hash);

where %hash contains the various attributes decribed below.

=back

=head1 PARAMETER ATTRIBUTES

All parameters have these attributes.  Each attribute has an
associated convenience method of the same name.

=over 4

=item type

This is one of string, regex, real, "positive integer", list, boolean,
or color.

  print $object -> config -> type("fft", "kwindow")
    ==prints==>
      list

=item default

This is the value associated with the parameter.  This is overridden
by an imported INI file or by the C<set_default> method.

  print $object -> config -> default("fft", "kwindow")
    ==prints==>
      hanning

=item demeter

This is the default value form the configuration file shipped with
demeter.  This is untouched even when a default is overridden by an
imported INI file.

  print $object -> config -> demeter("fft", "kwindow")
    ==prints==>
      hanning

=item description

This is a text string explaining the purpose of the parameter.

  print $object -> config -> description("fft", "kwindow")
    ==prints==>
      The default window type to use for the forward Fourier transform.

This can also return the description text of a parameter group.

  print $object -> config -> description("fft")
    ==prints==>
      These parameters determine how forward Fourier transforms are done by Demeter.

=back

Some attributes are specific to a parameter type.  Each attribute has
an associated convenience method of the same name.

=over 4

=item units

This specifies the units of the parameter, if appropriate.

  print $object -> config -> units("bkg", "pre1")
    ==prints==>
      eV (relative to e0 or to the beginning of the data)

=item onvalue/offvalue

These are the values associated with the true and false states of a
boolean parameter.  If unspecified in the configuration file, they
default to 1 and 0.

  print $object -> config -> onvalue("bkg", "flatten")
    ==prints==>
      1

=item minint/maxint

These are the minimum and maximum allowed values of a positive integer
parameter.  If unspecified in the configuration file, they default to
0 and 1e13.

  print $object -> config -> maxint("bkg", "kw")
    ==prints==>
      3

=item options

This are the possible options for a list parameter.  They are stored
as a space-separated string.  This string will have to be split on the
spaces to be used as a list.

  print $object -> config -> options("fft", "kwindow")
    ==prints==>
      hanning kaiser-bessel welch parzen sine

=back

=head1 USER DEFINED PARAMETERS

The C<new_param> method creates a user-defined parameter and stores it
in the Config object for later use.

    $merged->new_params({ndata=>$ndata});

These user-defined parameter are the accessed via C<get> (rather than
C<default>)

    print "Number of sets in merge = ", $data->config->get("ndata");

The reason to use the Config object to store parameters is that they
are easily used by the templating system that Demeter uses to do its
work.  Also, the user-defined parameters will be serialized along with
the Config object.

This system is used extensively in the C<merge> method from
L<Ifeffit::Demeter::Data::Process>.  See also the F<merge_*.tmpl>
files in the "process" group of templates.

=head1 DIAGNOSTICS

=over 4

=item C<You cannot have more than one Config object>

One Config object is created when Demeter loads.  It is forbidden to
create a second one.  Config paramaters are global to an instance of
Demeter.

=item C<The Demeter configuration file ($config_file) does not exist>

The F<demeter.config> file should be installed in the F<lib/>
subdirectory beneath the location of the F<Demeter.pm> module.  This
diagnostic says that configuration file is absent.

=item C<The Demeter configuration file ($config_file) cannot be opened>

The F<demeter.config> file should be installed in the F<lib/>
subdirectory beneath the location of the F<Demeter.pm> module.  This
diagnostic says that configuration file is unreadable, perhaps because
of a permissions setting.

=item C<$key is not a valid configuration parameter>

This diagnostic says that you have attempted to retrieve an attribute
for a parameter that does not exist.

=back


=head1 DEMETER CONFIGURATION FILES

The configuration files are broken into a simple hierarchy.  Parameter
groups tend to be contained in their own files which are included into
the master configuration file F<config.demeter_conf>.

The included configuration files are fairly structured.
Beginning-of-line whitespace (2 spaces, no more, no less) is important
in the parameter descriptions, as are the empty lines and the lines
that begin with a dot.  The empty lines denote separations between
entries.  The dots are used to build lists in the descriptions.

The parser for this file is fairly stupid, so if you make mistakes in
the use of whitespace, bad things will happen.  An L</EMACS MAJOR MODE> is
provided, the main purpose of which is to color text as an indication
of correct formatting.  Also, order matters.  It is very important
that "variable=" comes first, then "type=", then "default=", then the
rest.

The contents of the configuration files are used to populate the
Config object and to generate the files system-wide F<demeter.ini>.
It can also be used to populate the preferences dialog in a GUI.  Here
is a list of suggested widgets to use with each configuration type

   variable types         suggested widget
     string                Entry
     regex                 Entry
     real                  Entry  -- validates to accept only numbers
     positive integer      Entry with incrementers, restricted to be >= 0
     list                  Menubutton or some other multiple selection widget
     boolean               Checkbutton
     keypress              Entry  -- rigged to display one character at a time
     color                 Button -- launches color browser
     font                  Button -- does nothing at this time

=head1 EMACS MAJOR MODE

A major mode for emacs is provided with the Demeter package.  It
provides some functionality for editing Demeter configuration files.
The most significant functionality is syntax colorization that
enforces overly strict rules for the layout of the file.  Using this
major mode helps avoid introducing formatting errors into a
configuration file which has an admittedly fragile syntax.

See F<config-mode.el> in the F<tools/> subdirectory of the Demeter
distribution.  To use config-mode, simply place the file somewhere in
the Emacs load path and put this line in your .emacs file or some
other emacs initialization file.

   (autoload 'config-mode "config-mode")

The mode is tiny.  You can byte-compile or not -- as you wish.


=head1 DEPENDENCIES

See the F<Bundle/DemeterBundle.pm> file for a list of dependencies.

=head1 BUGS AND LIMITATIONS

=over 4

=item *

Nothing prevents overwriting Config entries -- this is a potential
problem for user-defined parameetrs.

=item *

There is no introspection method for returning all (sets) of user
defined parameters.

=item *

The configuration file syntax is somewhat fragile.

=item *

C<read_config_file> only handles files relative to the master config
file.  If it could understand fully resolved filenames, it could, for
instance, look for additional configuration files in userspace or
application space.  That way apps and one-off tools could use the
configuration system.

=item *

When (how often) should ini files be written out?

=back

Please report problems to Bruce Ravel (bravel AT anl DOT gov)

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
