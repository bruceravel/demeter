#!/usr/bin/env perl

use strict;
use warnings;

use File::Basename;
use File::Spec;
use JSON;
use Regexp::Assemble;
use Scalar::Util qw(looks_like_number);


print "Demeter configuration conversion tool$/";

my %params_of;
my $perl_base = q{};
if (is_windows()) {
  my ($volume,$directories,$fname) = File::Spec->splitpath( $^X );
  #$directories =~ s{\A[/\\]}{};
  $directories =~ s{[/\\]\z}{};
  my @dir = File::Spec->splitdir( $directories );
  pop @dir; pop @dir;  # perl\bin
  $perl_base = File::Spec->catdir($volume, @dir);
};

my $file = File::Spec->catfile(dirname($0), 'config.demeter_conf');
_read_config_file($file);
my $json = JSON->new->allow_nonref;

my $outfile = File::Spec->catfile(dirname($0), 'demeter_config.db');
open(my $OUT, '>', $outfile);
print $OUT $json->pretty->encode(\%params_of);
close $OUT;

print "  Saving new database, $outfile.$/";

sub Push {
  my (@list) = @_;
  my %hash = @list;
  my $retval = 0;
  foreach my $key (keys %hash) {
    my $k = lc $key;
    push @{ $params_of{$k} }, $hash{$k};
    $retval = $#{ $params_of{$k} };
  };
  return $retval;
};

sub _read_config_file {
  my ($file) = @_;

  ## need to distinguish between a relative filename and a fully
  ## resolved file.

  #carp("The Demeter configuration file ($file) does not exist\n\n"),
    return 0
    if (not -e $file);
  #carp("The Demeter configuration file ($file) cannot be opened\n\n"),
    return 0
    if (not -r $file);

  my $base = (split(/\./, basename($file)))[0];
  Push(___groups => $base);

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
      #print "    reading $includefile\n";
      _read_config_file($includefile);

    } elsif ($line =~ m{^\s*section\s*=\s*(\w+)}) {
      $group = $1;
      $group =~ s{\s+$}{};
      Push(___groups => $group);
      $description = q{};

    } elsif ($line =~ m{^\s*section_description}) {
    SECDESC: while (my $next = <$CONFIG>) {
	$next =~ s{\n}{ };
	$next =~ s{^\s+}{};
	last SECDESC if ($next =~ m{^\s*$});
	$description .= $next;
      };
      $description =~ s{\s+$}{};
      set($group=>$description);

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
      set_this_param($group, $param, %hash);
      next CONF;

    } elsif ($line =~ m{^\s*variable\s*=\s*(\w+)}) {
      $param = $1;
      $param =~ s{\s+$}{};
      undef %hash;
      $description = q{};

    } elsif ($line =~ m{^\s*($key_regex)\s*=\s*(.+)}) {
      my $key = $1;
      $value = $2;
      $value =~ s{\s+$}{};
      if (($value =~ m{__METIS_BASE__}) and ($INC{"Demeter/UI/Metis.pm"})) {
	my $new = dirname($INC{"Demeter/UI/Metis.pm"});
	$value =~ s{__METIS_BASE__}{$new};
	$value = abs_path(File::Spec->canonpath($value));
      }
      $hash{$key} = $value;
      ($hash{demeter} = $value) if ($key eq 'default');
      if (is_windows() and ($key eq 'windows')) {
	my $relocated = $perl_base;             # make paths to executables (feff, gnuplot, etc)
	$value =~ s{__PERL_BASE__}{$relocated}; # tolerant to relocation upon installation
	$hash{default} = $value;
	$hash{demeter} = $value;
	$hash{windows} = $value;
      };
    };
  };
  set_this_param($group, $param, %hash) if %hash;
  close $CONFIG;
};

sub set {
  my (@list) = @_;
  my %hash = @list;
  foreach my $key (keys %hash) {
    my $k = lc $key;
    $params_of{$k} = $hash{$k};
  };
};


sub set_this_param {
  my ($group, $param, %hash) = @_;
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
  set($key=>\%hash);
};


sub is_windows {
  return (($^O eq 'MSWin32') or ($^O eq 'cygwin'));
};
