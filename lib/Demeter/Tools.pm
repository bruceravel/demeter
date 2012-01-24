package Demeter::Tools;

=for Copyright
 .
 Copyright (c) 2006-2012 Bruce Ravel (bravel AT bnl DOT gov).
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

use Moose::Role;

use Carp;
#use Demeter::GDS;
use Regexp::Assemble;
use Fcntl qw(:flock);
use List::Util qw(sum);
use String::Random qw(random_string);
use Sys::Hostname;
use DateTime;
use Data::Dumper;
use Text::Wrap;
#use Memoize;
#memoize('distance');


use Readonly;
Readonly my $FRAC => 100000;
Readonly my $NULLFILE => '@&^^null^^&@';


# use vars qw(@ISA @EXPORT @EXPORT_OK);
# require Exporter;
# @ISA = qw(Exporter);
# @EXPORT = qw(distance simpleGDS);
# @EXPORT_OK = qw();

my %seen = ();
my $ra  = Regexp::Assemble->new;
my $type_regexp = $ra->add(qw(guess def set restrain after skip merge lguess ldef))->re;

## check to make sure that the computer's time zone is set.  fall back
## to the floating time zone if not
Readonly my $tz => (eval {DateTime->now(time_zone => 'local')}) ? 'local' : 'floating';
sub now {
  my ($self) = @_;
  return sprintf("%s", DateTime->now(time_zone => $tz));
};

sub environment {
  my ($self) = @_;
  my $os = ($self->is_windows) ? windows_version() : $^O;
  return "Demeter " . $Demeter::VERSION . " with perl $] on $os";
};

sub module_environment {
  my ($self) = @_;
  my $os = ($self->is_windows) ? windows_version() : $^O;
  my $string = "Demeter " . $Demeter::VERSION . " with perl $] on $os\n";
  $string .= "using Ifeffit " . (split(" ", Ifeffit::get_string('&build')))[0] . "\n";
  $string .= "\n Major modules                   version\n";
  $string .= '=' x 50 . "\n";
  foreach my $p (qw(
		     Ifeffit
		     Moose
		     MooseX::Aliases
		     MooseX::StrictConstructor
		     MooseX::Singleton
		     MooseX::Types
		     Archive::Zip
		     Capture::Tiny
		     Chemistry::Elements
		     Config::IniFiles
		     DateTime
		     Graph
		     Graphics::GnuplotIF
		     Math::Round
		     Pod::POM
		     PDL
		     PDL::Stats
		     Readonly
		     Regexp::Assemble
		     Regexp::Common
		     Heap::Fibonacci
		     String::Random
		     Text::Template
		     Tree::Simple
		     YAML::Tiny
		  )) {
    my $v = '$' . $p . '::VERSION';
    my $l = 30 - length($p);
    $string .= sprintf(" %s %s %s\n", $p, '.' x $l, eval($v)||'?');
  };
  $string .= "\n";
  return $string;
};

sub wx_environment {
  require Wx;
  my $v = $Wx::VERSION;
  my $l = 28;
  my $string = sprintf(" Wx %s %s", '.' x $l, $v);
  $string .= ", with " . $Wx::wxVERSION_STRING;
  $string .= "\n" x 2;
  return $string;
};

## http://aspn.activestate.com/ASPN/docs/ActivePerl/5.8/lib/Win32.html
##     OS                    ID    MAJOR   MINOR
##     Win32s                 0      -       -
##     Windows 95             1      4       0
##     Windows 98             1      4      10
##     Windows Me             1      4      90
##     Windows NT 3.51        2      3      51
##     Windows NT 4           2      4       0
##     Windows 2000           2      5       0
##     Windows XP             2      5       1
##     Windows Server 2003    2      5       2
##     Windows Vista          2      6       0
##     Windows Server 2008    2      6       0  note this overlap .. not a huge issue for this app...
##     Windows 7              2      6       1
sub windows_version {
  my @os = eval "Win32::GetOSVersion()";
  my $os = "Some Windows thing";
 SWITCH: {
    $os = "Win32s",              last SWITCH if  ($os[4] == 0);
    $os = "Windows 95",          last SWITCH if (($os[4] == 1) and ($os[1] == 4) and ($os[2] == 0));
    $os = "Windows 98",          last SWITCH if (($os[4] == 1) and ($os[1] == 4) and ($os[2] == 10));
    $os = "Windows ME",          last SWITCH if (($os[4] == 1) and ($os[1] == 4) and ($os[2] == 90));
    $os = "Windows NT 3.51",     last SWITCH if (($os[4] == 2) and ($os[1] == 3) and ($os[2] == 51));
    $os = "Windows NT 4",        last SWITCH if (($os[4] == 2) and ($os[1] == 4) and ($os[2] == 0));
    $os = "Windows 2000",        last SWITCH if (($os[4] == 2) and ($os[1] == 5) and ($os[2] == 0));
    $os = "Windows XP",          last SWITCH if (($os[4] == 2) and ($os[1] == 5) and ($os[2] == 1));
    $os = "Windows Server 2003", last SWITCH if (($os[4] == 2) and ($os[1] == 5) and ($os[2] == 2));
    $os = "Windows Vista",       last SWITCH if (($os[4] == 2) and ($os[1] == 6) and ($os[2] == 0));
    $os = "Windows Server 2008", last SWITCH if (($os[4] == 2) and ($os[1] == 6) and ($os[2] == 0));
    $os = "Windows 7",           last SWITCH if (($os[4] == 2) and ($os[1] == 6) and ($os[2] == 1));
  };
  return $os;
};

## verify wonky paths to executables, falling back on the ones that
## should have been installed along with Demeter.  this is mostly a
## windows problem -- on a real operating system, we can rely upon the
## shell's path.
sub check_exe {
  my ($class, $which) = @_;
  my $param = ($which eq 'gnuplot') ? 'program'
            : ($which eq 'feff')    ? 'executable'
	    :                         'program';
  #print Demeter->co->default($which, $param), $/;
  if (-e Demeter->co->default($which, $param)) {
    return 0;
  };
  if (-e Demeter->co->demeter($which, $param)) {
    Demeter->co->set_default($which, $param, Demeter->co->demeter($which, $param));
    #print Demeter->co->default($which, $param), $/;
    return 0;
  };
  my $message = "The $which executable could not be found at your specified location" .
    "(" . Demeter->co->default($which, $param) . ")" .
      " nor at the system default location" .
	"(" . Demeter->co->demeter($which, $param) . ")\n";
  return $message;
};

sub who {
  my ($class) = @_;
  return q{} if $class->is_windows; # Win32::LoginName()  @  Win32::NodeName()
  return join("\@", scalar getpwuid($<), hostname()||"localhost");
};


sub slurp {
  my ($class, $file) = @_;
  local $/;
  return q{} if (not -e $file);
  return q{} if (not -r $file);
  open(my $FH, $file);
  my $text = <$FH>;
  close $FH;
  return $text;
};

sub readable {
  my ($self, $file) = @_;
  return "$file does not exist"  if (not -e $file);
  return "$file is not readable" if (not -r $file);
  return "$file is locked"       if $self->locked($file);
  return 0;
};

sub locked {
  my ($self, $file) = @_;
  my $rc = open(my $HANDLE, $file);
  $rc = flock($HANDLE, LOCK_EX|LOCK_NB);
  close($HANDLE);
  return !$rc;
};
  # if (open my $fh, "+<", $file) {
  #   close $fh;
  # } else {
  #   ($^E == 0x20) ? return "in use by another process" : return $!;
  # };



## see http://www.perlmonks.org/index.pl?node_id=38942
sub check_parens {
  my ($class, $string) = @_;
  my $count = 0;
  foreach my $c (split(//, $string)) {
    ++$count if ($c eq '(');
    --$count if ($c eq ')');
    return $count if $count < 0;
  };
  return $count;
};

sub simpleGDS {
  my ($self, $string) = @_;
  ($string =~ s{(?:\A\s+|\s+\z)}{}g);    # trim leading and training space

  my ($type, $name, @rest) = split(" ", $string);
  #($type, $name) = (lc $type, lc $name); # enforce lower case
  $type = lc $type;		# enforce lower case for gds attribute

  my $mathexp = lc(join(" ", @rest));
  $mathexp =~ s{\A\s*[=,]\s*}{};         # remove leading space, comma, equals sign from mathexp

  croak("simpleGDS: the first word of the string must be one of (guess def set restrain after skip merge)")
    if ($type !~ /\A$type_regexp\z/i);
  ## croak if $name is one of the program variables

  ## finally, return the GDS object
  return Demeter::GDS -> new(gds     => $type,
			     name    => $name,
			     mathexp => $mathexp,
			    ),
};

sub is_windows {
  my ($class) = @_;
  return (($^O eq 'MSWin32') or ($^O eq 'cygwin'));
};
sub is_osx {
  my ($class) = @_;
  return ($^O eq 'darwin');
};

sub slash {
  my ($class) = @_;
  return (Demeter->is_windows) ? '\\' : '/';
};

## this is an exported function
sub distance {
  my $self = shift;
  croak("usage: distance(\@coords1, \@coords2) where each list contains exactly 3 elements, 6 total")
    unless ( $#_ == 5 );
  return sqrt( ($_[0]-$_[3])**2 +($_[1]-$_[4])**2 +($_[2]-$_[5])**2 );
};

sub halflength {
  my $class = shift;
  croak("usage: halflength(\@coords1, \@coords2, ... \@coordsN) where each list contains exactly 3 elements")
    unless ( ($#_+1) % 3 == 0 );

  my @abs = (shift, shift, shift); # coordinates of absorber
  my @coords = @_;
  push @coords, @abs;		# to compute length of return leg
  my @legs = ();

  ## compute the length of the first leg
  my @this = (shift(@coords), shift(@coords), shift(@coords));
  push @legs, distance(@abs, @this);

  ## compute leg lengths as long as the coords list is non-empty
  while (@coords) {
    my @next = (shift(@coords), shift(@coords), shift(@coords));
    push @legs, distance(@this, @next);
    @this = @next;
  };

  ## sum the legs and divide by two, as is the Feff convention
  return sum(@legs)/2;
};


sub euclid {
  my $class = shift;
  my @numbers = sort {$a < $b} @_;

  my $b = abs $numbers[0];
  my $c = abs $numbers[1];

  my $rem = $b % $c;
  return $c if $rem == 0;
  if($c == 0) {
    return $c;
  } else {
    $class->euclid($c, $rem);
  };
};

sub fract {
  my ($class, $value) = @_;
  return '0' if not $value;
  $value *= $FRAC;
  my $gcd = $class->euclid($value, $FRAC);
  my $n = sprintf('%d', $value/$gcd);
  my $d = sprintf('%d', $FRAC/$gcd);
  my $string = q{};
  if (abs($d) > 25) {
    $string = sprintf("%.5f", $value/$FRAC);
  } elsif (abs($n) > abs($d)) {
    $string = sprintf('%d %d/%d', int($n / $d), abs($n) % $d, $d);
  } else {
    $string = sprintf('%d/%d', $n, $d);
  };
  return $string;
};

sub randomstring {
  my ($self, $length) = @_;
  $length ||= 6;
  return random_string('c' x $length);
};

sub ifeffit_heap {
  my ($self, $length) = @_;
  $self->mo->heap_used(Ifeffit::get_scalar('&heap_used'));
  $self->mo->heap_free(Ifeffit::get_scalar('&heap_free'));
  if (($self->mo->heap_used > 0.95) and ($self->mo->ui !~ m{wx}i)) {
    warn sprintf("You have used %.1f%% of Ifeffit's %.1f Mb of memory",
		 100*$self->mo->heap_used,
		 $self->mo->heap_free/(1-$self->mo->heap_used)/2**20);
  };
  return $self;
};

sub clear_ifeffit_titles {
  my ($self, $group) = @_;
  $group ||= $self->group;
  my @save = (Ifeffit::get_scalar("\&screen_echo"),
	      $self->get_mode("screen"),
	      $self->get_mode("plotscreen"),
	      $self->get_mode("feedback"));
  Ifeffit::ifeffit("\&screen_echo = 0\n");
  $self->set_mode(screen=>0, plotscreen=>0, feedback=>q{});
  $self->dispose('show @strings');
  my $lines = Ifeffit::get_scalar('&echo_lines');
  my $target = '\$' . $group . '_title_';
  my @all = ();
  foreach my $l (1 .. $lines) {
    my $response = Ifeffit::get_echo();
    if ($response =~ m{$target}) {
      (my $title = $response) =~ s{=.+\z}{};
      $title =~ s{\s+\z}{};
      push @all, $title;
    };
  };
  local $Text::Wrap::columns = 200;
  my $all_titles = wrap('erase ', 'erase ', join(" ", @all));
  $self->dispose($all_titles);
  Ifeffit::ifeffit("\&screen_echo = $save[0]\n");
  $self->set_mode(screen=>$save[1], plotscreen=>$save[2], feedback=>$save[3]);
  return $self;
};



sub Dump {
  my ($self, $ref, $name) = @_;
  return Data::Dumper->Dump([$ref], [$name]) if $name;
  return Dumper($ref);
};


use subs qw(BOLD RED RESET YELLOW GREEN);
my $ANSIColor_exists = (eval "require Term::ANSIColor");
if ($ANSIColor_exists) {
  import Term::ANSIColor qw(:constants);
} else {
  foreach my $s (qw(BOLD RED RESET YELLOW GREEN)) {
    eval "sub $s {q{}}";
  };
};

## see http://www.perlmonks.org/?node_id=640324
sub trace {
  my ($self) = @_;
  my $max_depth = 30;
  my $i = 0;
  my $base = substr($INC{'Demeter.pm'}, 0, -10);
  my ($green, $red, $yellow, $end) = (BOLD.GREEN, BOLD.RED, BOLD.YELLOW, RESET);
  local $|=1;
  print($/.BOLD."--- Begin stack trace ---$end\n");
  while ( (my @call_details = (caller($i++))) && ($i<$max_depth) ) {
    (my $from = $call_details[1]) =~ s{$base}{};
    my $line  = $call_details[2];
    my $color = RESET.YELLOW;
    (my $func = $call_details[3]) =~ s{(?<=::)(\w+)\z}{$color$1};
    print("$green$from$end line $red$line$end in function $yellow$func$end\n");
  }
  print(BOLD."--- End stack trace ---$end\n");
  return $self;
};
# print Devel::StackTrace->new()->as_string();

sub pjoin {
  my ($self, @stuff) = @_;
  print join("|", @stuff) . $/;
  return join("|", @stuff) . $/;
};


## this will fail if on linux or Mac and importing a shortcut from a
## network mounted folder
sub follow_link {
  my ($self, $file) = @_;
  return $file if ($file eq $NULLFILE);
  if (Demeter->is_windows) {
    require Win32::Shortcut;
    my $LINK = Win32::Shortcut->new();
    $file = $LINK->{Path} if $LINK->Load($file);
  };
  return $file;
};

1;

=head1 NAME

Demeter::Tools - Utility methods for the Demeter class

=head1 VERSION

This documentation refers to Demeter version 0.9.

=head1 DESCRIPTION

This module contains a number of methods that work better (in Bruce's
opinion) as class methods than as object methods.

=head1 METHODS

=over 4

=item C<simpleGDS>

This is syntactic sugar for the GDS object constructor.  The following are
equivalent:

  $gdsobject = Demeter::GDS ->
                  new(type    => 'guess',
		      name    => 'alpha',
		      mathexp => 0,
		     );
  #
  $gdsobject = $demeter_object -> simpleGDS("guess alpha = 0");

The text string that is the argument for this wrapper is parsed
identically to how a guess parameter in a F<feffit.inp> file is
parsed.

=item C<distance>

This returns the Cartesian distance between two points.

   my $d = distance(@point1, @point2);

Each of the arrays passed to this function must be exactly three
elements long and are assumed to contain the x, y, and z Cartesian
coordinates, in that order.

=item C<now>

This returns a string with the current date and time in a convenient,
human-readable format.

   print "The time is: ", $demeter_object -> now, $/;

=item C<environment>

This returns a string showing the version numbers of Demeter and perl,
and the identifier string for your operating system.

   print "You are running: ", $demeter_object -> environment, $/;

=item C<who>

This makes a halfhearted attempt to figure out who you are.  On a unix
machine, it returns a concatination of the USER and HOST environment
variables.  On Windows it currently returns the fairly stupid
"you@your.computer".

   print "You are: ", $demeter_object -> who, $/;


=item C<check_parens>

Return 0 if a string has matching round braces (parentheses).  A positive
(negative) return value indicates the number of excess open (close) round
braces.  This can be used a boolean check on a string.

  $is_mismatched = $demeter_object->check_parens($string);

This only matches round braces.  It ignores square, curly, or angle braces,
none of which serve a purpose in Ifeffit math expressions.

=item C<is_windows>

Return true if running on a Windows machine.

  my $is_win = $demeter_object -> is_windows;

=item C<is_osx>

Return true if running on a Macintosh OSX machine.

  my $is_mac = $demeter_object -> is_osx;

=item C<halflength>

Given a list of references to arrays -- each of which contains the x,
y, and z coordinates of an atom -- return the half length of the
path. The half length is the sum of the individual legs divided by
2. The first item in the list is assumed to the absorber at and is
tacked onto the end of the list to close the path.

  my $hl = $demeter_object ->
         halflength(\@coords1, \@coords2, ... \@coordsN);

=item C<euclid>

Return the greatest common denominator of two numbers.

  my $gcd = $demeter_object->euclid(1071, 462);
  ## $gcd is 21

This is used by Demeter::Atoms to determine stoichiometry for the
feff8 input file's potentials list.

=item C<fract>

Returns a fraction of rational numbers given an input float,using 5
significant digits beyond the decimal.

  my $frac = $demeter_object -> fract(0.5);
  ## will print as "1/2"

=item C<Dump>

This is just a wrapper around L<Data::Dumper>.  Pass it a reference
and it will be pretty-printed;

  print $any_object -> Dump(\@some_array);

=item C<trace>

Print an ANSI-colorized stack trace to STDOUT from any location.

  $any_object -> trace;

=back

=head1 CONFIGURATION AND ENVIRONMENT

See L<Demeter::Config> for a description of the configuration system.

=head1 DEPENDENCIES

The dependencies of the Demeter system are listed in the
F<Bundle/DemeterBundle.pm> file.

=head1 BUGS AND LIMITATIONS

=over 4

=item *

The C<who> method should poke at the registry on Windows.

=item *

The C<fract> method should define what a small integer is and return a
decimal representation when the ratio is not of small numbers.

=back

Please report problems to Bruce Ravel (bravel AT bnl DOT gov)

Patches are welcome.

=head1 AUTHOR

The euclid method was swiped from Math::Numbers by David Moreno Garza
and is Copyright (C) 2007 and is licensed like Perl itself.

Bruce Ravel (bravel AT bnl DOT gov)

L<http://cars9.uchicago.edu/~ravel/software/>


=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2012 Bruce Ravel (bravel AT bnl DOT gov). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
