package Demeter::Config;

=for Copyright
 .
 Copyright (c) 2006-2015 Bruce Ravel (http://bruceravel.github.io/home).
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

#use MooseX::Singleton;
use Moose;
extends 'Demeter';
use Moose::Util::TypeConstraints;
use MooseX::Aliases;
#use vars qw($singleton);	# Moose 0.61, MooseX::Singleton 0.12 seem to need this

use Carp;
#use diagnostics;
use Demeter::Constants qw($EPSILON2);
use Demeter::StrTypes qw(FileName);
use Demeter::IniReader;
use Config::INI::Writer;
use File::Basename;
use Regexp::Assemble;
#use Demeter::Constants qw($NUMBER);
use Scalar::Util qw(looks_like_number);
use Text::Wrap;
#use Data::Dumper;

## these do not get inherited as this is imported as compile time, but
## attributes get made at run time.  sigh...
has 'group'     => (is => 'rw', isa => 'Str',  default => sub{shift->_get_group()});
has 'name'      => (is => 'rw', isa => 'Str',  default => q{});
has 'plottable' => (is => 'ro', isa => 'Bool', default => 0);
has 'data'      => (is => 'rw', isa => 'Any',  default => q{});
has 'perl_base' => (is => 'rw', isa => 'Str',  default => q{});

has 'config_file' => (is => 'ro', isa => FileName,
		      default => File::Spec->catfile(dirname($INC{"Demeter.pm"}),
						     "Demeter",
						     "configuration",
						     "config.demeter_conf"));

has 'all_config_files' => (
			     traits    => ['Array'],
			     is        => 'rw',
			     isa       => 'ArrayRef[Str]',
			     default   => sub { [] },
			     handles   => {
					   'push_all_config_files'  => 'push',
					   'pop_all_config_files'   => 'pop',
					   'clear_all_config_files' => 'clear',
					  },
			    );

has 'main_groups' => (
		      traits    => ['Array'],
		      is        => 'rw',
		      isa       => 'ArrayRef[Str]',
		      default   => sub { [] },
		      handles   => {
				    'push_main_groups'  => 'push',
				    'pop_main_groups'   => 'pop',
				    'clear_main_groups' => 'clear',
				   },
		     );

has 'is_configured' => (is => 'rw', isa => 'Bool', default => 0);

my $where = (($^O eq 'MSWin32') or ($^O eq 'cygwin')) ? "APPDATA" : "HOME";
my $stem  = (($^O eq 'MSWin32') or ($^O eq 'cygwin')) ? "demeter" : ".horae";
#my $where = ($Demeter::mode->is_windows) ? "USERPROFILE" : "HOME";
our $fname = File::Spec->catfile($ENV{$where}, $stem, "demeter.ini");
has 'ini_file' => (is => 'ro', isa => FileName, default => $fname);


my %ini;
#tie %ini, 'Config::IniFiles', ();
my %params_of;

#my $one_has_been_created = 0;

sub BUILD {
  my ($self) = @_;
  #return $Demeter::mode->config if $Demeter::mode->config;

  if ($self->is_windows) {
    my ($volume,$directories,$fname) = File::Spec->splitpath( $INC{'Demeter.pm'} );
    #$directories =~ s{\A[/\\]}{};
    $directories =~ s{[/\\]\z}{};
    my @dir = File::Spec->splitdir( $directories );
    pop @dir; pop @dir; pop @dir;  # perl\site\lib
    $self->perl_base(File::Spec->catdir($volume, @dir));
  };

  $self -> dot_folder;
  $self -> read_config;
  $self -> read_ini;
  $self -> fix;
  $self -> write_ini;
  $self -> mo -> config($self);
  $self -> mo -> merge($self->default("merge", "weightby"));
  my @groups = $self->groups;
  $self->main_groups(\@groups);
  return $self;
};

sub set {
  my ($self, @list) = @_;
  my %hash = @list;
  foreach my $key (keys %hash) {
    my $k = lc $key;
    $params_of{$k} = $hash{$k};
    my ($g, $p) = split(/:/, $k);
    $ini{$g}{$p} = $params_of{lc $key}->{default} if $p;
  };
  return $self;
};
sub Push {
  my ($self, @list) = @_;
  my %hash = @list;
  my $retval = 0;
  foreach my $key (keys %hash) {
    my $k = lc $key;
    push @{ $params_of{$k} }, $hash{$k};
    $retval = $#{ $params_of{$k} };
  };
  return $retval;
};
sub get {
  my $self = shift;
  croak(ref($self) . ': usage: get($key) or get(@keys)') if @_ < 1;
  my @values = ();
  foreach my $key (@_) {
    my $k = lc $key;
    push @values, $params_of{lc $key} || 0;
  };
  return wantarray ? @values : $values[0];
};

sub groups {
  my ($self) = @_;
  my @list = @{ $self->get('___groups') };
  return sort @list;
};

sub parameters {
  my ($self, $group) = @_;
  my $hashref = $ini{$group};
  return sort keys %$hashref;
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
  my ($self, $file) = @_;
  $self->_read_config_file($file||$self->config_file);
  $self->is_configured(1);
  return $self;
};
sub _read_config_file {
  my ($self, $file) = @_;

  ## need to distinguish between a relative filename and a fully
  ## resolved file.

  carp("The Demeter configuration file ($file) does not exist\n\n"), return 0
    if (not -e $file);
  carp("The Demeter configuration file ($file) cannot be opened\n\n"), return 0
    if (not -r $file);

  my $base = (split(/\./, basename($file)))[0];
  #$self -> Push(___groups => $base);
  $self -> push_all_config_files(File::Spec->rel2abs($file));

  my $key_regex = Regexp::Assemble->new()->add(qw(type default minint maxint options windows
						  units onvalue offvalue restart))->re;


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
      if (not -e $includefile) { # this allows for arbitrary include files
	$includefile = File::Spec->catfile(dirname($file), $includefile);
      };
      $self->_read_config_file($includefile);

    } elsif ($line =~ m{^\s*section\s*=\s*(\w+)}) {
      $group = $1;
      $group =~ s{\s+$}{};
      $self -> Push(___groups => $group);
      $description = q{};

    } elsif ($line =~ m{^\s*section_description}) {
    SECDESC: while (my $next = <$CONFIG>) {
	$next =~ s{\n}{ };
	$next =~ s{^\s+}{};
	last SECDESC if ($next =~ m{^\s*$});
	$description .= $next;
      };
      $description =~ s{\s+$}{};
      $self -> set($group=>$description);

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
      ($hash{demeter} = $value) if ($1 eq 'default');
      if (($self->is_windows) and ($1 eq 'windows')) {
	my $relocated = $self->perl_base;       # make paths to executables (feff, gnuplot, etc)
	$value =~ s{__PERL_BASE__}{$relocated}; # tolerant to relocation upon installation
	$hash{default} = $value;
	$hash{demeter} = $value;
	$hash{windows} = $value;
      };
    };
  };
  $self->set_this_param($group, $param, %hash) if %hash;
  close $CONFIG;
  return $self;
};

sub set_this_param {
  my ($self, $group, $param, %hash) = @_;
  #use Data::Dumper;
  my $key = join(":", $group, $param);
  #local $| = 1;
  #print $key, $/;
  $hash{default}     ||= 0;	# sanitize several attributes
  $hash{was}         ||= 0;
  $hash{description} ||= q{};
  $hash{restart}     ||= 0;
  if ($hash{type} eq 'positive integer') {
    $hash{maxint} ||= 1e9;
    $hash{minint} ||= 0;
  } elsif ($hash{type} eq 'boolean') {
    $hash{onvalue}  ||= 1;
    $hash{offvalue} ||= 0;
  };
  if ($hash{type} eq 'real') {
    #$self->_report($group, $param, $hash{default});
    $hash{default} = (looks_like_number($hash{default})) ? $hash{default} : 0;
    $hash{demeter} = $hash{default};
    if (exists $hash{windows}) {
      $hash{windows} = (looks_like_number($hash{windows})) ? $hash{windows} : 0;
    };
  } elsif ($hash{type} eq 'positive integer') {
    $hash{default} = (looks_like_number($hash{default})) ? int($hash{default}) : 0;
    $hash{demeter} = $hash{default};
    if (exists $hash{windows}) {
      $hash{windows} = (looks_like_number($hash{windows})) ? int($hash{windows}) : 0;
    };
  };
  $self -> set($key=>\%hash);
  $ini{$group}{$param} = (($self->is_windows) and (exists $hash{windows})) ? $hash{windows} : $hash{default};
  return $self;
};

sub _report {
  my ($self, $g, $p, $val) = @_;
  Demeter->pjoin($g,$p,$val,looks_like_number($val), '<');
};

sub fix_number {
  my ($val) = @_;
  $val =~ s{,}{.} if ($val =~ m{,});
  $val .= '0' if ($val =~ m{\.\z});
  $val =~ s{\s+}{} if ($val =~ m{\s+});
  return $val;
};

## override a default value, for instance when reading an ini file

## need to take care that a key from an ini file is actually from the configuration files
sub set_default {
  my ($self, $group, $param, $value) = @_;
  return q{} if not $param;
  my $key = join(":", $group, $param);
  #local $| = 1;
  #print $key, $/;
  my $rhash = $self->get($key);
  return $self if (not $rhash);
  $rhash->{was} = $rhash->{default};
  $rhash->{default} = $value;
  if ($rhash->{type} eq 'boolean') {
    $rhash->{default} = ($self->is_true($value)) ? "true" : "false";
  } elsif ($rhash->{type} eq 'real') {
    #$rhash->{default} = 0 if (not looks_like_number($value));
    #$rhash->{default} = fix_number($value);
    $rhash->{default} = (looks_like_number($value)) ? $value : 0;
  } elsif ($rhash->{type} eq 'positive integer') {
    $rhash->{default} = 0 if (not looks_like_number($value));
    $rhash->{default} = int($value);
    ($rhash->{default} = $rhash->{maxint}) if ($value > $rhash->{maxint});
    ($rhash->{default} = $rhash->{minint}) if ($value < $rhash->{minint});
  };
  $self -> set($key=>$rhash);
  return $self;
};
# sub is_true {
#   my ($self, $value) = @_;
#   return 1 if ($value =~ m{^[ty]}i);
#   return 0 if ($value =~ m{^[fn]}i);
#   return 0 if (($value =~ m{$NUMBER}) and ($value == 0));
#   return 1 if ($value =~ m{$NUMBER});
#   return 0;
# };

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
  carp("$key is not a valid configuration parameter\n\n"), return 0 if not $rhash;
  if ($rhash->{type} eq 'boolean') {
    return $rhash->{onvalue}  || 1 if ($self->is_true($rhash->{default}));
    return $rhash->{offvalue} || 0;
  };
  if ($rhash->{type} eq 'positive integer') {
    return $rhash->{maxint} if ($rhash->{default} > $rhash->{maxint});
    return $rhash->{minint} if ($rhash->{default} < $rhash->{minint});
  };
  return $rhash->{default};
};
alias def => 'default';

sub description {
  my ($self, $group, $param) = @_;
  my $key = ($param) ? join(":", $group, $param) : $group;
  return $self->get($key) if (not $param);
  my $rhash = $self->get($key);
  carp("$key is not a valid configuration parameter\n\n"), return 0 if not $rhash;
  my $desc = $rhash->{description};
  if ($desc =~ m{\%list}) {
    $desc =~ s{\%list}{\n        }g;
    $desc =~ s{\%space}{ }g;
    $desc =~ s{\%endlist}{}g;
  #} else {
  #  $desc = wrap("    ", "    ", $desc) . "\n";
  };
  return $desc;
};
sub attribute {
  my ($self, $which, $group, $param) = @_;
  return q{} if not $param;
  my $key = join(":", $group, $param);
  my $rhash = $self->get($key);
  carp("$key is not a valid configuration parameter\n\n"), return 0 if not $rhash;
  return $rhash->{$which} || 0;
};
sub was      {my $self=shift; $self->attribute("was",      @_)};
sub Type     {my $self=shift; $self->attribute("type",     @_)};
sub units    {my $self=shift; $self->attribute("units",    @_)};
sub demeter  {my $self=shift; $self->attribute("demeter",  @_)};
sub options  {my $self=shift; $self->attribute("options",  @_)};
sub onvalue  {my $self=shift; $self->attribute("onvalue",  @_)};
sub offvalue {my $self=shift; $self->attribute("offvalue", @_)};
sub minint   {my $self=shift; $self->attribute("minint",   @_)};
sub maxint   {my $self=shift; $self->attribute("maxint",   @_)};
sub restart  {my $self=shift; $self->attribute("restart",  @_)};

sub describe_param {
  my ($self, $group, $param, $width) = @_;
  my $config = $self->mo->config;
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
    foreach my $k (qw(type default demeter options units minint maxint onvalue offvalue)) {
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
  $file ||= $self->ini_file;
  #my $ini_ref = tied %ini;
  #$ini_ref -> WriteConfig($file);
  Config::INI::Writer->write_file(\%ini, $file);
  return $self;
};

sub read_ini {
  my ($self, $group) = @_;
  my $inifile = $self->ini_file;
  if (not -e $inifile) {
    $self->write_ini($inifile);
    return $self;
  };

  my $personal_ini = Demeter::IniReader->read_file($inifile);

  # my %personal_ini;
  # my $ini_ref = tied %ini;
  # tie %personal_ini, 'Config::IniFiles', (-file=>$inifile, -import=>$ini_ref );
  # {				# this is to encourage a spurious warning
  #   no strict qw{refs};		# related to Config::IniFiles to shut up
  #   my $toss = *{"Config::IniFiles::$inifile"}; # under windows
  #   undef $toss;
  # };
  foreach my $g (keys %$personal_ini) {
    #next if $g eq 'ini__filename';
    next if ($group and ($g ne $group));
    my $hash = $personal_ini->{$g};
    foreach my $p (keys %$hash) {
      ($p = 'col'.$1) if ($p =~ m{c(\d)}); # compatibility, convert cN -> colN
      $self->set_default($g, $p, $personal_ini->{$g}{$p});
    };
  };
  return $self;
};


sub reset_all {
  my ($self) = @_;
  foreach my $g (Demeter->co->groups) {
    foreach my $p (Demeter->co->parameters($g)) {
      Demeter->co->set_default($g, $p, Demeter->co->demeter($g, $p));
    };
  };
  Demeter->co->write_ini;
  return $self;
};

## this method is used to fix parameters in a way that is backwards compatable
sub fix {
  my ($self) = @_;
  my $keyparams = $self->default("gnuplot", "keyparams");
  $keyparams =~ s{left|right|top|bottom|center}{}g;
  $keyparams =~ s{\A\s+}{};
  $self->set_default("gnuplot", "keyparams", $keyparams);

  ## somehow, it may happen that a users ini file will have
  ## zero-length plotting ranges -- very confusing, so reset to
  ## demeter defaults
  if (abs($self->default("plot", 'emax') - $self->default("plot", 'emin')) < $EPSILON2) {
    $self->set_default("plot", 'emin', $self->demeter("plot", 'emin'));
    $self->set_default("plot", 'emax', $self->demeter("plot", 'emax'));
  };
  if (abs($self->default("plot", 'kmax') - $self->default("plot", 'kmin')) < $EPSILON2) {
    $self->set_default("plot", 'kmin', $self->demeter("plot", 'kmin'));
    $self->set_default("plot", 'kmax', $self->demeter("plot", 'kmax'));
  };
  if (abs($self->default("plot", 'rmax') - $self->default("plot", 'rmin')) < $EPSILON2) {
    $self->set_default("plot", 'rmin', $self->demeter("plot", 'rmin'));
    $self->set_default("plot", 'rmax', $self->demeter("plot", 'rmax'));
  };
  if (abs($self->default("plot", 'qmax') - $self->default("plot", 'qmin')) < $EPSILON2) {
    $self->set_default("plot", 'qmin', $self->demeter("plot", 'qmin'));
    $self->set_default("plot", 'qmax', $self->demeter("plot", 'qmax'));
  };
  # foreach my $p (qw(kmax rmax qmax emin emax)) {
  #   my $val = $self->default("plot", $p);
  #   $self->set_default("plot", $p, $self->demeter("plot", $p));
  # };

  $self->set_default("athena", "autosave_frequency", $self->demeter("athena", "autosave_frequency"))
    if $self->default("athena", "autosave_frequency") < 2;

  if ($self->default('gnuplot', 'keyparams') =~ m{box(?!\slw)}) {
    my $old = $self->default('gnuplot', 'keyparams');
    $old =~ s{box}{box lw 1};
    $self->set_default('gnuplot', 'keyparams', $old);
  };
  if ($self->default('gnuplot', 'xkcd')) {
    $self->set_default('gnuplot', 'font', 'Humor Sans');
  };

  return $self;
};


__PACKAGE__->meta->make_immutable;
1;

=head1 NAME

Demeter::Config - Demeter's configuration system

=head1 VERSION

This documentation refers to Demeter version 0.9.21.

=head1 DESCRIPTION

This subclass of Demeter provides a general way of storing and
manipulating parameters of all sorts, including configuration
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
uses the standard INI format and the L<Demeter::IniReader> module.  The
user's file lives in $ENV{HOME} on unix and Mac and in
$ENV{USERPROFILE} on Windows.

Defining new parameters to be handled by Config is as simple as
entering them into the INI file using normal INI syntax.  Those
user-created parameters will not possess descriptions or other
attributes, however.

=head1 METHODS

The normal idiom for accessing method of the Config class is to chain
method calls starting with any other Demeter object.  Although you can
certainly store a reference to the Config object as a scalar, it
usually is not necessary to do so.

The C<co> method, inhereted by all other objects from the Demeter
base class, returns a reference to the Config object.  All of the
examples below use the chain idiom and C<self> can be any kind of
object.

=head2 External methods

=over 4

=item C<default>

Return the default value for a parameter.

  print "Default fft kmin is ", $object->co->default("fft", "kmin"), $/;

=item C<set_default>

This method is called repeatedly by C<read_ini> to move the
information from the user's ini file into the Config object.

  $object -> co -> set_default("bkg", "rbkg", 1.2);

=item C<describe>

Return a text description of a parameter.

  print $object -> co -> describe("bkg", "kw");
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
C<operations--E<gt>config_text_width> parameter).

  print $object -> co -> describe("bkg", "kw", 45);
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

  @groups = $object -> co -> groups;

=item C<parameters>

Return a list of parameters associated with a specified configuration group.

  @params = $object -> co -> parameters('bkg');

=back

=head2 ini file methods

=over 4

=item C<read_ini>

Read default values from a user's ini file, overwriting the values
read from the system-wide configuration file.

  $object -> co -> read_ini($filename);

=item C<write_ini>

Write an ini file for a user.

  $object -> co -> write_ini($filename);

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

=item Type

This is one of string, regex, real, "positive integer", list, boolean,
color, or font.

  print $object -> co -> Type("fft", "kwindow")
    ==prints==>
      list

=item default

This is the value associated with the parameter.  This is overridden
by an imported INI file or by the C<set_default> method.

  print $object -> co -> default("fft", "kwindow")
    ==prints==>
      hanning

=item windows

This overrides the default, but only on Windows computers.

Strings that take a fully resolved path to an executable are treated
specially.  If that executable resides beneath the perl installation
location, then the installation location should be denoted as
C<__PERL_BASE__>.  For example, Strawberry perl is typically instaled
into C<C:\strawberry>.  Rather than denoting the location of the Feff
executable as C<C:\strawberry\c\bin\feff.exe>, it should be specified
as C<__PERL_BASE__\c\bin\feff.exe>.  The C<__PERL_BASE__> tag will be
replaced by the correct installation location.  Then, if Strawberry is
installed into some other location, the Feff executable will be found
at runtime.

=item demeter

This is the default value from the configuration file shipped with
demeter.  This is untouched even when a default is overridden by an
imported INI file.

  print $object -> co -> demeter("fft", "kwindow")
    ==prints==>
      hanning

=item was

This is the previous value of the parameter from before the last time
it was changed using the C<set_default> method.  If the parameter has
not been changed since it was initialized, this method returns 0.  The
primary use of this method is to aid in post-processing a change in
parameter value in a GUI or other application.

  print $object -> co -> demeter("fft", "kwindow")
    ==prints==>
      welch

=item description

This is a text string explaining the purpose of the parameter.

  print $object -> co -> description("fft", "kwindow")
    ==prints==>
      The default window type to use for the forward Fourier transform.

This can also return the description text of a parameter group.

  print $object -> co -> description("fft")
    ==prints==>
      These parameters determine how forward Fourier transforms are done by Demeter.

=back

Some attributes are specific to a parameter type.  Each attribute has
an associated convenience method of the same name.

=over 4

=item units

This specifies the units of the parameter, if appropriate.

  print $object -> co -> units("bkg", "pre1")
    ==prints==>
      eV (relative to e0 or to the beginning of the data)

=item restart

This is true or false depending on whether changing the parameter
takes effect immediately or if a restart of the application is
required.

=item onvalue/offvalue

These are the values associated with the true and false states of a
boolean parameter.  If unspecified in the configuration file, they
default to 1 and 0.

  print $object -> co -> onvalue("bkg", "flatten")
    ==prints==>
      1

=item minint/maxint

These are the minimum and maximum allowed values of a positive integer
parameter.  If unspecified in the configuration file, they default to
0 and 1e9.

  print $object -> co -> maxint("bkg", "kw")
    ==prints==>
      3

=item options

This are the possible options for a list parameter.  They are stored
as a space-separated string.  This string will have to be split on the
spaces to be used as a list.

  print $object -> co -> options("fft", "kwindow")
    ==prints==>
      hanning kaiser-bessel welch parzen sine

=back

=head1 USER DEFINED PARAMETERS

The C<set> method creates a user-defined parameter and stores it
in the Config object for later use.

    $merged->set(ndata=>$ndata);

These user-defined parameter are the accessed via C<get> (rather than
C<default>)

    print "Number of sets in merge = ", $data->co->get("ndata");

The reason to use the Config object to store parameters is that they
are easily used by the templating system that Demeter uses to do its
work.  Also, the user-defined parameters will be serialized along with
the Config object.

This system is used extensively in the C<merge> method from
L<Demeter::Data::Process>.  See also the F<merge_*.tmpl> files in the
"process" group of templates.

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
     string                TextCtrl
     regex                 TextCtrl
     real                  TextCtrl -- validates to accept only numbers
     positive integer      SpinCtrl -- restricted to be >= 0
     list                  Choice or some other multiple selection widget
     boolean               Checkbutton
     keypress              TextCtrl -- rigged to display one character at a time
     color                 ColorPicker -- launches color browser
     font                  FontPicker -- does nothing at this time

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

See the F<Build.PL> file for a list of dependencies.

=head1 BUGS AND LIMITATIONS

=over 4

=item *

This object needs to be a singleton, but it also needs to extend
Demeter.  How is that done in Moose?  I have no idea....

=item *

Nothing prevents overwriting Config entries -- this is a potential
problem for user-defined parameetrs.

=item *

There is no introspection method for returning all (sets of) user
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

Please report problems to the Ifeffit Mailing List
(L<http://cars9.uchicago.edu/mailman/listinfo/ifeffit/>)

Patches are welcome.

=head1 AUTHOR

Bruce Ravel, L<http://bruceravel.github.io/home>

L<http://bruceravel.github.io/demeter/>

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2015 Bruce Ravel (L<http://bruceravel.github.io/home>). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
