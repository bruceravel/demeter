package Demeter::Files;

=for Copyright
 .
 Copyright (c) 2006-2019 Bruce Ravel (http://bruceravel.github.io/home).
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

sub is_json {
  my ($self, $file, $verbose) = @_;
  $verbose ||= 0;
  my $gz = gzopen($file, "rb");
  return 0 if not defined $gz;
  my $is_jsn = 0;
  my $line;
  foreach my $l (1..4) {	# look for _____header1 in the first four lines
    $gz->gzreadline($line);
    #print $line, $/;
    last if not defined($line);
    $is_jsn = ($line =~ /_____header\d.+Athena project file/) ? 1 : 0;
    last if $is_jsn;
  };
  $gz->gzclose();
  if ($verbose) {
    my $passfail = ($is_jsn) ? 'athena    ' : 'not athena';
    printf "%s\n\t%s  is_json=%s\n", $file, $passfail, $is_jsn;
  };
  return $is_jsn;
};


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
      ($type eq 'guess') and do {
	my $ret = 1;
	$ret = -1 if $zip->memberNamed('order');
	$ret = -2 if $zip->memberNamed('gds.yaml');
	$ret = -3 if $zip->memberNamed('HORAE');
	undef $zip;
	return $ret;
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

This documentation refers to Demeter version 0.9.26.

=head1 DESCRIPTION

This role contains several methods for identifying files common to the
Demeter, Feff, and Ifeffit/Larch universes.

=head1 METHODS

=over 4

=item C<is_atoms>

Return true if a file is recognized as an atoms input file.  This uses
simple semantics based on the file contents.

  my $yesno = Demeter->is_atoms($file, $verbose);

=item C<is_cif>

Return true if a file is recognized as a CIF file.  This is a pretty
dumb method -- it returns true if the file extension is C<.cif>.

  my $yesno = Demeter->is_cif($file, $verbose);

=item C<is_feff>

Return true if a file is recognized as a Feff input file.  This uses
simple semantics based on the file contents.

  my $yesno = Demeter->is_feff($file, $verbose);

=item C<is_data>

Return true is Ifeffit/Larch recognizes this file as a data file.

  my $yesno = Demeter->is_data($file, $verbose);

=item C<is_prj>

Return true if this is a conventional Athena project file.

  my $yesno = Demeter->is_prj($file, $verbose);

=item C<is_json>

Return true if this is a JSON-style Athena project file.

  my $yesno = Demeter->is_json($file, $verbose);

=item C<is_zipproj>

Return true if this is a zip file which can be recognized as a save
file for some aspect of Artemis.

  my $yesno = Demeter->is_zipproj($file, $verbose, $type);

C<$type> can be one of:

=over 4

=item C<any>

Returns true if the file is any kind of recognized save file in a zip
format.

=item C<guess>

Returns true if the file is any kind of recognized save file in a zip
format.  The return value tells you what kind.  -1 means an Artemis
project file., -2 means a Demeter fit serialization file, and -3 means
an old-style Artemis project file.

=item C<fpj>

Returns true only if the file is an Artemis project file.

=item C<dpj>

Returns true only if the file is a Demeter fit serialization file.

=item C<apj>

Returns true only if the file is an old-style Artemis project file.

=back

=item C<is_xdi>

Return true if the file is recognizably an XDI file.

  my $yesno = Demeter->is_xdi($file, $verbose);

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

  Bruce Ravel, L<http://bruceravel.github.io/home>
  http://bruceravel.github.io/demeter

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2019 Bruce Ravel (L<http://bruceravel.github.io/home>). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut

