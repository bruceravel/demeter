package Demeter::Files;

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

use autodie qw(open close);

use Moose::Role;
use MooseX::Aliases;

use Carp;

use Archive::Zip qw( :ERROR_CODES :CONSTANTS );
local $Archive::Zip::UNICODE = 1;
use Compress::Zlib;
use File::Basename;
use Xray::Crystal;

use Demeter::Constants qw($ELEMENT $NUMBER);


## an atoms.inp file is identified by having a valid space group
## symbol and by having an atoms list with at least one valid line of
## atoms
sub is_atoms {
  my ($self, $a, $verbose) = @_;
  open (my $A, $a) or $self->Croak("could not open $a: $!");
  my ($space_test, $atoms_test, $toss) = (0,0,0);
  my $switch = 0;
 A: while (<$A>) {
    next if /^\s*$/;		# skip blanks
    next if /^\s*[!\#%*]/;	# skip comment lines
    $switch = 1, next if  (/^\s*ato/);
    if ($switch) {
      my @line = split(" ", $_);
      ($atoms_test=1), last A if ( (lc($line[0]) =~ /^$ELEMENT$/) and
				   ($line[1] =~ /^$NUMBER$/)  and
				   ($line[2] =~ /^$NUMBER$/)  and
				   ($line[3] =~ /^$NUMBER$/));
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
  open (my $A, $a) or $self->Croak("could not open $a: $!");
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
				  (lc($line[2]) =~ /^$ELEMENT$/));
      ($scat_test=$_), next A if (($line[0] =~ /^\d+$/) and
				  ($line[1] =~ /^\d+$/) and
				  (lc($line[2]) =~ /^$ELEMENT$/));
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
  my ($self, $a, $verbose) = @_;  ## $self is a misnomer, this is a class method
  my $gp;
  if ($self eq 'Demeter') {
    $gp = Demeter->mo->throwaway_group
  } else {
    $gp = $self->group || Demeter->mo->throwaway_group;
  };
  ##my $gp = Demeter->mo->throwaway_group;
  Demeter->dispense('process', 'read_group', {file=>$a, group=>$gp, type=>'raw'});
  my $col_string = $self->fetch_string('$column_label');
  if ($verbose) {
    my $passfail = ($col_string =~ /^(\s*|--undefined--)$/) ?
      'not data' : 'data    ' ;
    printf "%s\n\t%s    col_string=%s\n", $a, $passfail, $col_string;
  };
  Demeter->dispense('process', 'erase', {items=>"\@group $gp"}), return 0
    if ($col_string =~ /^(\s*|--undefined--)$/);
  Demeter->clear_ifeffit_titles($gp);

  ## now check that the data file had more  than 1 data point
  my $onepoint = 0;
  my $tooshort = 0;
  foreach my $l (split(" ", $col_string)) {
    my $scalar = "a_".$l;
    if ($self->fetch_scalar($scalar)) {
      $onepoint = 1;
      Demeter->dispense('process', 'erase', {items=>$scalar});
    };
    my @array = Demeter->fetch_array("$gp.$l");
    if (@array) {
      my $npts = $#array+1;
      $tooshort = 1 if ($npts < Demeter->co->default(qw(file minlength)));
    };
  };
  Demeter->dispense('process', 'erase', {items=>"\@group $gp"}), return 0 if $onepoint;
  Demeter->dispense('process', 'erase', {items=>"\@group $gp"}), return 0 if $tooshort;
  Demeter->dispense('process', 'erase', {items=>"\@group $gp"});
  return 1;
};

sub is_prj {
  my ($self, $file, $verbose) = @_;
  $verbose ||= 0;
  my $gz = gzopen($file, "rb");
  return 0 if not defined $gz;
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

sub is_zipproj {
  my ($self, $file, $verbose, $type) = @_;
  $verbose ||= 0;
  $type ||= 'fpj';
  my $zip = Archive::Zip->new();
  {
    local $Archive::Zip::ErrorHandler = sub{1}; # turn off Archive::Zip errors for this check
    if ($zip->read($file) != AZ_OK) {
      print "not a zip file\n" if $verbose;
      undef $zip;
      return 0;
    };
  SWITCH: {
      ($type eq 'any') and do {
	undef $zip;
	return 1;
      };
      ($type eq 'fpj') and do {
	print "not a fitting project file\n" if $verbose;
	undef $zip, return 0 if not $zip->memberNamed('order');
	last SWITCH;
      };
      ($type eq 'dpj') and do {
	print "not a demeter fit serialization\n" if $verbose;
	undef $zip, return 0 if not $zip->memberNamed('gds.yaml');
	last SWITCH;
      };
      ($type eq 'apj') and do {
	print "not an old-style fitting project file\n" if $verbose;
	undef $zip, return 0 if not $zip->memberNamed('HORAE');
	last SWITCH;
      };
    };
  };
  undef $zip;
  return 1;
};

sub is_xdi {
  my ($self, $xdifile, $verbose) = @_;
  open (my $X, $xdifile) or $self->Croak("could not open $xdifile: $!");
  my $first = <$X>;
  close $X;
  print $first if $verbose;
  return ($first =~ m{\A\#\s+XDI});
};


1;

=head1 NAME

Demeter::Files - File import tests

=head1 VERSION

This documentation refers to Demeter version 0.9.21.

=head1 DESCRIPTION

This role contains several methods for identifying files common to the
Feff and Ifeffit/Larch universes.

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
F<Build.PL> file.

=head1 BUGS AND LIMITATIONS

All tests are fragile.

Please report problems to the Ifeffit Mailing List
(L<http://cars9.uchicago.edu/mailman/listinfo/ifeffit/>)

Patches are welcome.

=head1 AUTHOR

  Bruce Ravel (bravel AT bnl DOT gov)
  http://bruceravel.github.io/demeter

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2014 Bruce Ravel (bravel AT bnl DOT gov). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut

