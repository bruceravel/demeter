package Demeter::Carp;

use 5.006;
use strict;
use warnings;

use subs qw(BOLD BLACK RED GREEN YELLOW BLUE MAGENTA CYAN WHITE ON_RED RESET);
my $ANSIColor_exists = (eval "require Term::ANSIColor");
if ($ANSIColor_exists) {
  import Term::ANSIColor qw(:constants);
} else {
  ## this eval works when Term::ANSIColor is not available AND when running tests
  eval '
  sub BOLD    {q{}};
  sub RED     {q{}};
  sub YELLOW  {q{}};
  sub RESET   {q{}};';
};

our $VERSION = '0.01';

use Carp qw(verbose); # makes carp() cluck and croak() confess

sub _warn {
  if ($_[-1] =~ /\n$/s) {
    my $arg = pop @_;
    #$arg =~ s/ at .*? line .*?\n$//s;
    $arg = YELLOW . BOLD . $arg . RESET;
    push @_, $arg;
  };
  warn &Carp::shortmess;
}

sub _die {
  if ($_[-1] =~ /\n$/s) {
    my $arg = pop @_;
    #$arg =~ s/ at .*? line .*?\n$//s;
    $arg = RED . BOLD . $arg . RESET;
    push @_, $arg;
  };
  die &Carp::shortmess;
}

my %OLD_SIG;

BEGIN {
  @OLD_SIG{qw(__DIE__ __WARN__)} = @SIG{qw(__DIE__ __WARN__)};
  $SIG{__DIE__} = \&_die;
  $SIG{__WARN__} = \&_warn;
}

END {
  @SIG{qw(__DIE__ __WARN__)} = @OLD_SIG{qw(__DIE__ __WARN__)};
}

1;
__END__

