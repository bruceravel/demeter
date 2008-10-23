package Ifeffit::Demeter::Tools;

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

use autodie qw(open close);

use Moose::Role;

use Carp;
#use Ifeffit::Demeter::GDS;
use Regexp::List;
use Regexp::Optimizer;
use List::Util qw(sum);
use Sys::Hostname;
use POSIX qw(tzset tzname);
tzset();
#use Memoize;
#memoize('distance');

# use vars qw(@ISA @EXPORT @EXPORT_OK);
# require Exporter;
# @ISA = qw(Exporter);
# @EXPORT = qw(distance simpleGDS);
# @EXPORT_OK = qw();

my %seen = ();
my $opt  = Regexp::List->new;
my $type_regexp = $opt->list2re(qw(guess def set restrain after skip merge lguess ldef));


sub now {
  my ($self) = @_;
  my @tz = POSIX::tzname();
  my @time = localtime;
  my $month = (qw/January February March April May June July
	          August September October November December/)[$time[4]];
  my $year = 1900 + $time[5];
  my $zone = ($time[8]) ? $tz[1] : $tz[0];
  return sprintf "%2.2u:%2.2u:%2.2u %s on %s %s, %s",
    reverse(@time[0..2]), $zone, $time[3], $month, $year;
  # ^^^ this gives hour:min:sec
};

sub environment {
  my ($self) = @_;
  my $os = ($self->is_windows) ? windows_version() : $^O;
  return "Demeter " . $Ifeffit::Demeter::VERSION . " with perl $] on $os";
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
    $os = "Windows Vista",       last SWITCH if (($os[4] == 2) and ($os[1] == 6));
    #$os = "Windows Vista",       last SWITCH if (($os[4] == 2) and ($os[1] == 6) and ($os[2] == 0));
  };
  return $os;
};

sub who {
  my ($class) = @_;
  return q{} if $class->is_windows; # Win32::LoginName()  @  Win32::NodeName()
  return join("\@", scalar getpwuid($<), hostname()||"localhost");
};

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

## take care in case this is called as a class method rather than as an exported function
sub simpleGDS {
  my ($self, $string) = @_;
  ($string =~ s{(?:\A\s+|\s+\z)}{}g);    # trim leading and training space

  my ($type, $name, @rest) = split(" ", $string);
  ($type, $name) = (lc $type, lc $name); # enforce lower case

  my $mathexp = lc(join(" ", @rest));
  $mathexp =~ s{\A\s*[=,]\s*}{};         # remove leading space, comma, equals sign from mathexp

  croak("simpleGDS: the first word of the string must be one of (guess def set restrain after skip merge)")
    if ($type !~ /\A$type_regexp\z/i);
  ## croak if $name is one of the program variables

  ## finally, return the GDS object
  return Ifeffit::Demeter::GDS -> new(gds     => $type,
				      name    => $name,
				      mathexp => $mathexp,
				     ),
};
# {
#   no warnings 'once';
#   # alternate names
#   *GDS = \ &simpleGDS;
# }

sub is_windows {
  my ($class) = @_;
  return (($^O eq 'MSWin32') or ($^O eq 'cygwin'));
};
sub is_osx {
  my ($class) = @_;
  return ($^O eq 'darwin');
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




1;

=head1 NAME

Ifeffit::Demeter::Tools - Utility methods for the Demeter class

=head1 VERSION

This documentation refers to Ifeffit::Demeter version 0.2.

=head1 DESCRIPTION

This module contains a number of methods that work better (in Bruce's
opinion) as class methods than as object methods.

=head1 METHODS

=over 4

=item C<simpleGDS>

This is syntactic sugar for the GDS object constructor.  The following are
equivalent:

  $gdsobject = Ifeffit::Demeter::GDS ->
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

=back

=head1 CONFIGURATION AND ENVIRONMENT

See L<Ifeffit::Demeter::Config> for a description of the configuration
system.

=head1 DEPENDENCIES

The dependencies of the Ifeffit::Demeter system are listed in the
F<Bundle/DemeterBundle.pm> file.

=head1 BUGS AND LIMITATIONS

The C<who> method should poke at the registry on Windows.

Please report problems to Bruce Ravel (bravel AT bnl DOT gov)

Patches are welcome.

=head1 AUTHOR

Bruce Ravel (bravel AT bnl DOT gov)

L<http://cars9.uchicago.edu/~ravel/software/>


=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2008 Bruce Ravel (bravel AT bnl DOT gov). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
