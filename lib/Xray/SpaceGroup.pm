package Xray::SpaceGroup;

=for Copyright
 .
 Copyright (c) 1999-2008 Bruce Ravel (bravel AT bnl DOT gov).
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
use MooseX::AttributeHelpers;

use Carp;
use File::Basename;
use File::Spec;
use List::MoreUtils qw(any true);
use Regexp::List;
use Storable;

use Readonly;
Readonly my $EPSILON  => 0.00001;

use vars qw($VERSION);
use version;
$VERSION = version->new("0.1.0");

has 'database'    => (is => 'ro', isa => 'Str', default => sub{File::Spec->catfile(dirname($INC{"Xray/SpaceGroup.pm"}),
										   'share',
										   'space_groups.db')});

has 'determining_group' => (is => 'rw', isa => 'Bool', default => 0);
has 'group'       => (is => 'rw', isa => 'Str', default => q{},
		      trigger => sub{ my ($self, $new) = @_;
				      if (not $self->determining_group) { # avoid deep recursion!
					$self->given($new);
					$self->_canonicalize_group;
					$self->_other_symbols;
					$self->_set_bravais;
					$self->_crystal_class;
					$self->_determine_monoclinic;
					$self->_set_positions;
				      };
				    });
has 'given'       => (is => 'rw', isa => 'Str', default => q{});
has 'number'      => (is => 'rw', isa => 'Int', default => 0);
has 'full'        => (is => 'rw', isa => 'Str', default => q{});
has 'schoenflies' => (is => 'rw', isa => 'Str', default => q{});
has 'thirtyfive'  => (is => 'rw', isa => 'Str', default => q{});
has 'newsymbol'   => (is => 'rw', isa => 'Str', default => q{});
has 'class'       => (is => 'rw', isa => 'Str', default => q{});
has 'setting'     => (is => 'rw', isa => 'Str', default => q{0});
has 'warning'     => (is => 'rw', isa => 'Str', default => q{});
has 'data'        => (is => 'rw', isa => 'HashRef', default => sub{ {} });

has 'nicknames' => (
		    metaclass => 'Collection::Array',
		    is        => 'rw',
		    isa       => 'ArrayRef',
		    default   => sub { [] },
		    provides  => {
				  'push'  => 'push_nicknames',
				  'pop'   => 'pop_nicknames',
				  'clear' => 'clear_nicknames',
				 }
		   );

has 'bravais' => (
		  metaclass => 'Collection::Array',
		  is        => 'rw',
		  isa       => 'ArrayRef',
		  default   => sub { [] },
		  provides  => {
				'push'  => 'push_bravais',
				'pop'   => 'pop_bravais',
				'clear' => 'clear_bravais',
			       }
		 );

has 'positions' => (
		    metaclass => 'Collection::Array',
		    is        => 'rw',
		    isa       => 'ArrayRef',
		    default   => sub { [] },
		    provides  => {
				  'push'  => 'push_positions',
				  'pop'   => 'pop_positions',
				  'clear' => 'clear_positions',
				 }
		   );


my $r_sg;
sub BUILD {
  my ($self) = @_;
  $r_sg = retrieve($self->database);
};

my $opt  = Regexp::List->new;
my $number_attr = $opt->list2re(qw(a b c alpha beta gamma));
my $sh_re = $opt->list2re(qw(hex hcp zincblende zns cubic salt perov perovskite
			     gra graphite fcc salt nacl diamond bcc cscl));



sub _canonicalize_group {
  my ($self) = @_;
  $self->determining_group(1);
  my $symbol = $self->given;
  my @mono3 = qw(b_unique c_unique a_unique);
  my @mono9 = qw(b_unique_1 b_unique_2 b_unique_3 c_unique_1 c_unique_2 c_unique_3 a_unique_1 a_unique_2 a_unique_3);
				# this is a null value
  $self->warning(q{});
  if (! $symbol) {
    $self->group(q{});
    $self->setting(0);
    $self->data( {} );
    $self->warning(q{Your symbol could not be recognized as a space group symbol!});
    $self->determining_group(0);
    return (q{},0);
  };

  $symbol = lc($symbol);	# lower case and ...
  $symbol =~ s{[!\#%*].*$}{};	# trim off comments
  $symbol =~ s{^\s+}{};		# trim leading spaces
  $symbol =~ s{\s+$}{};		# trim trailing spaces
  $symbol =~ s{\s+}{ }g;	# ... single space
  $symbol =~ s{\s*/\s*}{/}g;	# spaces around slash

  $symbol =~ s{2_1}{21}g;	  # replace `i 4_1' with `i 41'
  $symbol =~ s{3_([12])}{3$1}g;	  #  and so on ...
  $symbol =~ s{4_([1-3])}{4$1}g;
  $symbol =~ s{6_([1-5])}{6$1}g;

  if ( ($symbol !~ m{[_^]})        and	 # schoen
       ($symbol !~ m{\A\d{1,3}\z}) and	 # 1-230
       ($symbol !~ m{\A($sh_re)\z}io) # shorthands like 'cubic', 'zns'
     ) {
    #print $symbol;
    $symbol = _insert_spaces($symbol);
    #print "|$symbol|\n";
  };
				# this is the standard symbol
  if (exists($r_sg->{$symbol})) {
    $self->group($symbol);
    my $setting = (any {$r_sg->{$symbol}->{number} eq $_} (3..6, 10..12) ) ? "b_unique"
                : (any {$r_sg->{$symbol}->{number} eq $_} (7..9, 13..15) ) ? "b_unique_1"
	        :                                                            "positions";
    $self->setting($setting);

    my $rhash = $r_sg->{$symbol};
    $self->data($rhash);
    $self->determining_group(0);
    return ($symbol, 0);
  };

  foreach my $sym (keys %$r_sg ) {
    next if ($sym eq "version");
    my $rhash = $r_sg->{$sym};

				# this is the Schoenflies symbol, (it
				# must have a caret in it)
    if ($symbol =~ /\^/) {
      $symbol =~ s/\s+//g;	#   no spaces
      $symbol =~ s/^v/d/g;	#   V -> D
				# put ^ and _ in correct order
      $symbol =~ s/([cdost])(\^[0-9]{1,2})(_[12346dihsv]{1,2})/$1$3$2/;
      if ((exists $r_sg->{$sym}->{schoenflies}) and ($symbol eq $r_sg->{$sym}->{schoenflies}) ) {
	$self->group($sym);
	my $setting = (any {$r_sg->{$sym}->{number} eq $_} (3..6, 10..12) ) ? "b_unique"
	            : (any {$r_sg->{$sym}->{number} eq $_} (7..9, 13..15) ) ? "b_unique_1"
	            :                                                         "positions";
	$self->setting($setting);
	$self->data($rhash);
	$self->determining_group(0);
	return ($sym, 0);
      };
    };
				# scalar valued fields
				# this is a number between 1 and 230
				#    or the 1935 symbol
 				#    or a double glide plane symbol
 				#    or the full symbol
    foreach my $field ("thirtyfive", "number", "new_symbol", "full") {
      if ( (exists $r_sg->{$sym}->{$field}) and ($symbol eq $r_sg->{$sym}->{$field}) ) {
	$self->group($sym);
	my $setting = (any {$r_sg->{$sym}->{number} eq $_} (3..6, 10..12) ) ? "b_unique"
	            : (any {$r_sg->{$sym}->{number} eq $_} (7..9, 13..15) ) ? "b_unique_1"
	            :                                                         "positions";
	$self->setting($setting);
	$self->data($rhash);
	$self->determining_group(0);
	return ($sym, 0);
      };
    };
				# now check the array values fields
    foreach my $field ("settings", "short", "shorthand") {
      if (exists($r_sg->{$sym}->{$field})) {
	my $i=0;
	my $count = -1;
	foreach my $setting ( @{$r_sg->{$sym}->{$field}} ) {
	  ++$count;
	  ++$i;
	  my $s = ($field eq "settings") ? $i : 0;
	  if ($symbol eq $setting) {
	    $self->group($sym);
	    if (any {$field eq $_} qw(settings short)) {
	      if (any {$r_sg->{$sym}->{number} eq $_} (3..6, 10..12) ) {
		$self->setting($mono3[$count]);
	      } elsif (any {$r_sg->{$sym}->{number} eq $_} (7..9, 13..15) ) {
		$self->setting($mono9[$count]);
	      };
	    };
	    $self->data($rhash);
	    $self->determining_group(0);
	    return ($sym, $s);
	  };
	};
      };
    };

  };

				# this is not a symbol
  $self->space_group(q{});
  $self->setting(0);
  $self->data( {} );
  $self->warning(q{Your symbol could not be recognized as a space group symbol!});
  $self->determining_group(0);
  return (q{},0);

};


## This is the algorithm for dealing with user-supplied space group
## symbols that do not have the canonical single space separating the
## part of the symbol.
sub _insert_spaces {
  my $sym = $_[0];

  my ($first, $second, $third, $fourth) = ("", "", "", "");

  ## a few groups don't follow the rules below ...
  ($sym =~ /\b([rhc])32\b/i)                 && return "$1 3 2";
  ($sym =~ /\bp31([2cm])\b/i)                && return "p 3 1 $1";
  ($sym =~ /\bp(3[12]?)[22][12]\b/i)         && return "p $1 2 1";
  ($sym =~ /\bp(6[1-5]?)22\b/i)              && return "p $1 2 2";
  ($sym =~ /\b([fip])(4[1-3]?)32\b/i)        && return "$1 $2 3 2";
  ($sym =~ /\b([fipc])(4[1-3]?)(21?)(2)\b/i) && return "$1 $2 $3 $4";

  ## the first symbol is always a single letter
  $first = substr($sym, 0, 1);
  my $index = 1;

  my $subsym = substr($sym, $index);
  if ($subsym =~ m{\A([ \t]+)}) {
    $index += length($1);
  };
  if (substr($sym, $index, 4) =~ /([2346][12345]\/[mnabcd])/) {
    ## second symbol as in p 42/n c m
    $second = $1;
    $index += 4;
  } elsif (substr($sym, $index, 3) =~ /([2346]\/[mnabcd])/) {
    ## second symbol as in p 4/n n c
    $second = $1;
    $index += 3;
  } elsif (substr($sym, $index, 2) =~ /(-[1346])/) {
    ## second symbol as in p -3 1 m
    $second = $1;
    $index += 2;
  } elsif (substr($sym, $index, 2) =~ /(21|3[12]|4[123]|6[12345])/) {
    ## second symbol as in p 32 1 2
    $second = $1;
    $index += 2;
  } else {
    $second = substr($sym, $index, 1);
    $index += 1;
  };

  $subsym = substr($sym, $index);
  if ($subsym =~ m{\A([ \t]+)}) {
    $index += length($1);
  };
  if (substr($sym, $index, 4) =~ /([2346][12345]\/[mnabcd])/) {
    ## third symbol as in full symbol p 21/c 21/c 2/n
    $third = $1;
    $index += 4;
  } elsif (substr($sym, $index, 3) =~ /([2346]\/[mnabcd])/) {
    ## third symbol as in full symbol p 4/m 21/b 2/m
    $third = $1;
    $index += 3;
  } elsif (substr($sym, $index, 2) =~ /(-[1346])/) {
    ## third symbol as in f d -3 m
    $third = $1;
    $index += 2;
  } elsif (substr($sym, $index, 2) =~ /(21|3[12]|4[123]|6[12345])/) {
    ## third symbol as in p 21 21 2
    $third = $1;
    $index += 2;
  } else {
    $third = substr($sym, $index, 1);
    $index += 1;
  };

  ($index < length($sym)) and $fourth = substr($sym, $index);
  $fourth =~ s/\A\s+//;

  $sym = join(" ", $first, $second, $third, $fourth);
  $sym =~ s/\s+$//;		# trim trailing spaces
  return $sym;
};

sub _other_symbols {
  my ($self) = @_;
  my $sym = $self->group;
  my $rhash = $self->data;
  #use Data::Dumper;
  #print Data::Dumper->Dump([$rhash]);
  $self->number($$rhash{number} || 0);
  $self->schoenflies($$rhash{schoenflies} || q{});
  $self->thirtyfive($$rhash{thirtyfive}) if exists($$rhash{thirtyfive});
  $self->newsymbol ($$rhash{newsymbol})  if exists($$rhash{newsymbol});
  $self->nicknames ($$rhash{shorthand})  if exists($$rhash{shorthand});
  return $self;
};

sub _set_bravais {
  my ($self) = @_;
  my %table = ( f => [  0, 1/2, 1/2, 1/2,   0, 1/2, 1/2, 1/2,   0],
		i => [1/2, 1/2, 1/2],
		c => [1/2, 1/2,   0],
		a => [  0, 1/2, 1/2],
		b => [1/2,   0, 1/2],
		r => [2/3, 1/3, 1/3, 1/3, 2/3, 2/3],
	      );
  my $group   = $self->group;
  my $g       = lc(substr($group, 0, 1));
  if ($g !~ m{[ficabr]}) {
    $group   = $self->group;
    $g       = lc(substr($group, 0, 1));
  };
  my $setting = $self->setting;
  $self->bravais( [] );
  $self->bravais( $table{r}  ) if (($g eq 'r') and ($setting eq "rhombohedral"));
  $self->bravais( $table{$g} ) if ($g =~ m{[abcfi]});
  return $self;
};

sub _crystal_class {
  my ($self)  = @_;
  my $group   = $self->group;
  my $rhash   = $self->data;
  if (exists $$rhash{number}) {
    my $num   = $$rhash{number};
    my $class = ($num <= 0)   ? q{}
              : ($num <= 2)   ? "triclinic"
	      : ($num <= 15)  ? "monoclinic"
	      : ($num <= 74)  ? "orthorhombic"
	      : ($num <= 142) ? "tetragonal"
	      : ($num <= 167) ? "trigonal"
	      : ($num <= 194) ? "hexagonal"
	      : ($num <= 230) ? "cubic"
	      : q{};
    $self->class($class);
    if (($class eq 'monoclinic') and (not $self->setting)) {
      $self->setting("b_unique");
      $self->setting("b_unique_1") if any {$$rhash{number} == $_} (7,9,13,14,15);
    };
  } else {
    $self->class(q{});
  };
  return $self;
};


sub _determine_monoclinic {
  my ($self) = @_;
  my $group = $self->group;
  my $given = $self->given;
  my $class = $self->class;
  return $self if ($class ne "monoclinic");

  ($given = $group) if ($given =~ m{\A\d+\z});

  my $axis = ((abs( 90 - $self->alpha )) > $EPSILON) ? "a"
           : ((abs( 90 - $self->beta  )) > $EPSILON) ? "b"
	   : ((abs( 90 - $self->gamma )) > $EPSILON) ? "c"
	   : q{};
  (! $axis) && do {
    if ($self->angle) {
      $axis = lc(substr($self->angle, 0, 1));
      $axis =~ tr/g/c/;
    };
  };
  $axis ||= q{b};   # this probably happens when all axes are 90
  #print "axis: $axis\n";
  #return $self if (not $axis);	#  angles no set yet

  # if it has, then continue...
  my $setting = $axis . "_unique";
  my $number  = $r_sg->{$group}->{number};
  ## these groups have one cell choice for each unique axis
  foreach my $n (3,4,5,6,8,10,11,12) {
    if ($number == $n) {
      $self->setting($setting);
      return $self;
    };
  };
  ## groups 7, 13, 14 are p centered and have multiple cell choices
  #print "$group   $given    $axis\n";
  if ($group =~ m{\Ap}) {
    if ($axis eq "b") {
      ($setting .= "_1") if ($given =~ m{c}i);
      ($setting .= "_2") if ($given =~ m{n}i);
      ($setting .= "_3") if ($given =~ m{a}i);
    } elsif ($axis eq "c") {
      ($setting .= "_1") if ($given =~ m{a}i);
      ($setting .= "_2") if ($given =~ m{n}i);
      ($setting .= "_3") if ($given =~ m{b}i);
    } elsif ($axis eq "a") {
      ($setting .= "_1") if ($given =~ m{b}i);
      ($setting .= "_2") if ($given =~ m{n}i);
      ($setting .= "_3") if ($given =~ m{c}i);
    };
  };
  ## groups 9, 15 are c centered and have multiple cell choices
  if ($group =~ m{\Ac}) {
    if ($axis eq "b") {
      ($setting .= "_1") if ($given =~ m{\Ac}i);
      ($setting .= "_2") if ($given =~ m{\Aa}i);
      ($setting .= "_3") if ($given =~ m{\Ai}i);
    } elsif ($axis eq "c") {
      ($setting .= "_1") if ($given =~ m{\Aa}i);
      ($setting .= "_2") if ($given =~ m{\Ab}i);
      ($setting .= "_3") if ($given =~ m{\Ai}i);
    } elsif ($axis eq "a") {
      ($setting .= "_1") if ($given =~ m{\Ab}i);
      ($setting .= "_2") if ($given =~ m{\Ac}i);
      ($setting .= "_3") if ($given =~ m{\Ai}i);
    };
  };
  ## if none of the preceding 6 blocks altered setting then there is a
  ## mismatch between the symbol and the unique axis, so return
  ## presume it is in the standard setting.
  ($setting = 'b_unique_1') if ($setting !~ /_[123]$/);
  $self->setting($setting);
  return $self;
};

sub set_rhombohedral {
  my ($self) = @_;
  my $group = $self->group;
  my $given = $self->given;
  my $class = $self->class;
  return $self if ($class ne "trigonal");
  $self->setting('rhombohedral');
  my $rhash = $self->data;
  $self->positions($$rhash{rhombohedral});
  return $self;
};

sub _set_positions {
  my ($self) = @_;
  my $rhash = $self->data;
  my $list_ref = [];

  ## R groups in  the rhombohedral setting
  if ( ($self->group =~ m{\Ar}) and ($self->setting eq 'rhombohedral') ) {
    $list_ref = $$rhash{rhombohedral};

  ## monoclinic group settings
  } elsif ( $self->class eq 'monoclinic' ) {
    my $this = $self->get('setting');
    $list_ref = $$rhash{$this} || [];

  ## everything else uses the "positions" entry
  } else {
    $list_ref = $$rhash{positions} || [];
  };

  $self->positions($list_ref);
  return $self;
};








sub report {
  my ($self) = @_;
  my $message = sprintf("Space group: %s (%d)\n",          $self->group, $self->number);
  $message   .= sprintf("  supplied symbol        : %s\n", $self->given);
  $message   .= sprintf("  crystal class          : %s\n", $self->class);
  $message   .= sprintf("    Schoenflies symbol   : %s\n", $self->schoenflies);
  $message   .= sprintf("    full symbol          : %s\n", $self->full)                     if $self->full;
  $message   .= sprintf("    1935 symbol          : %s\n", $self->thirtyfive)               if $self->thirtyfive;
  $message   .= sprintf("    new symbol           : %s\n", $self->newsymbol)                if $self->newsymbol;
  $message   .= sprintf("    nicknames            : %s\n", join(", ", @{$self->nicknames})) if $self->nicknames;
  $message   .= sprintf("    crystal setting      : %s\n", $self->setting);
  $message   .= "    Bravais translations :\n";
  my @brav    = map { _simple_fraction($_) } @{ $self->bravais };
  $message   .= "      none\n"                                                                                   if not @brav;
  $message   .= sprintf("      %-8s   %-8s   %-8s\n",                                                     @brav) if ($#brav == 2);
  $message   .= sprintf("      %-8s   %-8s   %-8s\n      %-8s   %-8s   %-8s\n",                           @brav) if ($#brav == 5);
  $message   .= sprintf("      %-8s   %-8s   %-8s\n      %-8s   %-8s   %-8s\n      %-8s   %-8s   %-8s\n", @brav) if ($#brav == 8);
  $message   .= "    Positions :\n";
  foreach my $p (@{ $self->positions }) {
    $message .= sprintf("      %-8s   %-8s   %-8s\n", map {($_ =~ m{\A\-}) ? $_ : " $_"} @$p);
  };
  return $message;
};
sub _simple_fraction {		# stringify Bravais fractions
  my ($val) = @_;
  return (abs($val - 1/2) < $EPSILON) ? '1/2'
       : (abs($val - 1/3) < $EPSILON) ? '1/3'
       : (abs($val - 2/3) < $EPSILON) ? '2/3'
       :                                '0';
};
