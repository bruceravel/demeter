package Demeter::Files;

=for Copyright
 .
 Copyright (c) 2006-2011 Bruce Ravel (bravel AT bnl DOT gov).
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
use MooseX::Aliases;

use Carp;
use Compress::Zlib;
use File::Basename;
use Xray::Crystal;

use Readonly;
Readonly my $ELEM => qr/([bcfhiknopsuvwy]|a[cglmrstu]|b[aehikr]|c[adeflmorsu]|dy|e[rsu]|f[emr]|g[ade]|h[aefgos]|i[nr]|kr|l[airu]|m[dgnot]|n[abdeiop]|os|p[abdmortu]|r[abefhnu]|s[bcegimnr]|t[abcehilm]|xe|yb|z[nr])/;
Readonly my $NUM  => qr/-?(\d+\.?\d*|\.\d+)/;


## an atoms.inp file is identified by having a valid space group
## symbol and by having an atoms list with at least one valid line of
## atoms
sub is_atoms {
  my ($self, $a, $verbose) = @_;
  open (my $A, $a) or die "could not open $a: $!";
  my ($space_test, $atoms_test, $toss) = (0,0,0);
  my $switch = 0;
 A: while (<$A>) {
    next if /^\s*$/;		# skip blanks
    next if /^\s*[!\#%*]/;	# skip comment lines
    $switch = 1, next if  (/^\s*ato/);
    if ($switch) {
      my @line = split(" ", $_);
      ($atoms_test=1), last A if ( (lc($line[0]) =~ /^$ELEM$/) and
				   ($line[1] =~ /^$NUM$/)  and
				   ($line[2] =~ /^$NUM$/)  and
				   ($line[3] =~ /^$NUM$/));
    } else {

      my @line = split(" ", $_);
    LINE: foreach my $word (@line) {
	last LINE if (lc($word) eq 'title');
	if (lc($word) =~ /space/) {
	  my $lline = lc($_);
	  my $space = substr($_, index($lline,"space")+6);
	  $space =~ s/^[\s=,]+//;
	  $space =  substr($space, 0, 10); # next 10 characters
	  $space =~ s/[!\#%*].*$//;   # trim off comments
	  my $sg = Xray::Crystal::SpaceGroup->new();
	  $sg -> group($space);
	  $space_test = $sg->group;
	  $sg->DESTROY;
	};
      };
    };
  };
  close $A;
  if ($verbose) {
    my $passfail = ($atoms_test && $space_test) ? 'atoms    ': 'not atoms';
    printf "\t%s   atoms_test=%d  space_test=%s\n", $passfail, $atoms_test, $space_test;
  };
  return ($space_test && $atoms_test) ? 1 : 0;
};


sub is_cif {
  my ($self, $a) = @_;
  return 1 if (basename($a) =~ /cif$/i);
  return 0;
};

## a feff.inp file is identified by having a potentials list and at
## least two valid potentials line, the absorber and one other.
sub is_feff {
  my ($self, $a, $verbose) = @_;
  open (my $A, $a) or die "could not open $a: $!";
  my $switch = 0;
  my ($abs_test, $scat_test) = (0,0);
 A: while (<$A>) {
    chomp;
    next if /^\s*$/;		# skip blanks
    next if /^\s*[!\#%*]/;	  # skip comment lines
    $switch = 1, next if  (/^\s*pot/i);
    if ($switch) {
      last A if (/^\s*[a-zA-Z]/);
      my @line = split(" ", $_);
      ($abs_test=$_),  next A if (($line[0] =~ /^0$/) and
				  ($line[1] =~ /^\d+$/) and
				  (lc($line[2]) =~ /^$ELEM$/));
      ($scat_test=$_), next A if (($line[0] =~ /^\d+$/) and
				  ($line[1] =~ /^\d+$/) and
				  (lc($line[2]) =~ /^$ELEM$/));
    };
  }
  close $A;
  if ($verbose) {
    my $passfail = ($abs_test && $scat_test) ? 'feff    ': 'not feff';
    printf "\t%s    abs_test =%s\n\t            scat_test=%s\n",
      $passfail, $abs_test, $scat_test;
  };
  return ($abs_test && $scat_test) ? 1 : 0;
};

## a data file is data if ifeffit recognizes it as such and returns a
## column_label string
sub is_data {
  my ($self, $a, $verbose) = @_;
  $self->dispose("read_data(file=$a, group=a)\n");
  my $col_string = Ifeffit::get_string('$column_label');
  if ($verbose) {
    my $passfail = ($col_string =~ /^(\s*|--undefined--)$/) ?
      'not data' : 'data    ' ;
    printf "%s\n\t%s    col_string=%s\n", $a, $passfail, $col_string;
  };
  $self->dispose("erase \@group a\n");
  return ($col_string =~ /^(\s*|--undefined--)$/) ? 0 : 1;
};

sub is_prj {
  my ($self, $file, $verbose) = @_;
  $verbose ||= 0;
  my $gz = gzopen($file, "rb") or croak "could not open $file as a record\n";
  my $first;
  $gz->gzreadline($first);
  $gz->gzclose();
  my $is_proj = ($first =~ /Athena (record|project) file/) ? $1 : 0;
  if ($verbose) {
    my $passfail = ($is_proj) ? 'athena    ' : 'not athena';
    printf "%s\n\t%s  is_project=%s\n", $file, $passfail, $is_proj;
  };
  return $is_proj;
};
alias is_athena => 'is_prj';


1;

=head1 NAME

Demeter::Files - File import tests

=head1 VERSION

This documentation refers to Demeter version 0.4.

=head1 DESCRIPTION

This role contains several methods for identifying files common to the
Feff and Ifeffit universe.

=head1 METHODS

=over 4

=item C<is_atoms>

=item C<is_cif>

=item C<is_feff>

=item C<is_data>

=back

=head1 CONFIGURATION AND ENVIRONMENT

See L<Demeter::Config> for a description of the configuration system.

=head1 DEPENDENCIES

The dependencies of the Demeter system are listed in the
F<Bundle/DemeterBundle.pm> file.

=head1 BUGS AND LIMITATIONS

All tests are fragile.

Please report problems to Bruce Ravel (bravel AT bnl DOT gov)

Patches are welcome.

=head1 AUTHOR

  Bruce Ravel (bravel AT bnl DOT gov)
  http://xafs.org/BruceRavel

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2011 Bruce Ravel (bravel AT bnl DOT gov). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut

