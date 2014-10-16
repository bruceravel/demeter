package Demeter::Atoms::Cif;

=for Copyright
 .
 Copyright (c) 2006-2014 Bruce Ravel (http://bruceravel.github.io/home).
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

use Moose::Role;
use Demeter::StrTypes qw( Element );
use Demeter::Constants qw($EPSILON3);

use Chemistry::Elements qw(get_Z);
use File::Basename;
#use STAR::Parser; ## this is not needed since (1) all references
                   ## below use the STAR::Parser-> syntax and (2)
                   ## it got require-d in Demeter.pm

sub read_cif {
  my ($self) = @_;
  $self->clear;
  my $file = $self->cif;
  $self->confess(": no CIF file provided")                 if (not    $file);
  $self->confess(": CIF file \"$file\" does not exist")    if (not -e $file);
  $self->confess(": CIF file \"$file\" could not be read") if (not -r $file);

  my @datablocks = STAR::Parser->parse($file);
  $self->confess(": CIF file \"$file\" does not have a record number " . ($self->record + 1)) if not exists($datablocks[$self->record]);
  my $datablock = $datablocks[$self->record];
  ##    if STAR::Checker->check(-datablock=>$datablocks[0]);

  my @item;

  ## titles: consider various common title-like entries, strip white
  ## space characters and stuff them into the title attribute
  foreach my $i (qw(_chemical_name_mineral
		    _chemical_name_systematic
		    _chemical_formula_structural
		    _chemical_formula_moiety
		    _publ_author_name
		    _citation_journal_abbrev
		    _publ_section_title
		  )) {
                   #_chemical_formula_sum
    @item = $datablock->get_item_data(-item=>$i);
    $item[0] ||= "";
    $item[0] =~ s{}{}g;
    chomp $item[0];
    if ($item[0] !~ m{\A\s*\z}) {
      foreach my $t (split(/\n/, $item[0])) {
	$self->push_titles($t) if ($t !~ m{\A\s*\z});
      };
    };
  };

  ## space group: try the HM symbol then the number and canonicalize it
  @item = $datablock->get_item_data(-item=>"_symmetry_space_group_name_H-M");
  $self->cell->space_group($item[0]) if (defined $item[0]);
  if (not $self->cell->space_group) {
    @item = $datablock->get_item_data(-item=>"_symmetry_Int_Tables_number");
    $self->cell->space_group($item[0]) if (defined $item[0]);
  };
  if (not $self->cell->space_group) {
    @item = $datablock->get_item_data(-item=>"_space_group_IT_number");
    $self->cell->space_group($item[0]) if (defined $item[0]);
  };
  if (not $self->cell->space_group) {
    @item = $datablock->get_item_data(-item=>"_space_group_name_H-M_alt");
    $self->cell->space_group($item[0]) if (defined $item[0]);
  };
  $self->space($self->cell->space_group);

  ## lattice parameters
  my $min = 100000;   # use lattice constants to compute default for Rmax
  foreach my $k (qw(a b c)) {
    @item = $datablock->get_item_data(-item=>"_cell_length_$k");
    (my $this = $item[0]) =~ s{\(\d+\)}{};
    #print "$k $this\n";
    $self->$k($this);
    $min = 1.5*$this if ($min > 1.1*$this);
  };
  $min = 8 if ($min > 11);
  $self->rmax($min);
  foreach my $k (qw(alpha beta gamma)) {
    @item = $datablock->get_item_data(-item=>"_cell_angle_$k");
    (my $this = $item[0]) =~ s{\(\d+\)}{};
    #print "$k $this\n";
    $self->$k($this);
  };

  ## load up and clean up the atom positions
  my @tag = $datablock->get_item_data(-item=>"_atom_site_label");
  my @el  = $datablock->get_item_data(-item=>"_atom_site_type_symbol");
  my @x	  = $datablock->get_item_data(-item=>"_atom_site_fract_x");
  my @y	  = $datablock->get_item_data(-item=>"_atom_site_fract_y");
  my @z	  = $datablock->get_item_data(-item=>"_atom_site_fract_z");
  my @occ = $datablock->get_item_data(-item=>"_atom_site_occupancy");
  my ($core, $maxz) = (q{},0);
  my $partial = 0;
  foreach my $i (0 .. $#tag) {
    my $ee = $el[$i] || $tag[$i];
    $ee = _get_elem($ee);
    (my $xx = $x[$i]) =~ s{\(\d+\)}{}; # remove parenthesized error bars
    (my $yy = $y[$i]) =~ s{\(\d+\)}{};
    (my $zz = $z[$i]) =~ s{\(\d+\)}{};
    (my $oo = $occ[$i]||1) =~ s/\(\d+\)//;
    ++$partial if (abs($oo-1) > $EPSILON3);
    my $this = join("|",$ee, $xx, $yy, $zz, $tag[$i]);
    $self->push_sites($this);
    my $z = get_Z($ee);
    if ($z > $maxz) {
      $maxz = $z;
      $self->core($tag[$i]);
    };
  };
  $self->partial_occupancy(1) if $partial;
  $self->is_imported(1);
};

sub _get_elem {
  my $elem = $_[0];
  ($elem =~ /Wat/) and return "O";
  ($elem =~ /OH/)  and return "O";
  ($elem =~ /^D$/) and return "H";
  ## snip off the last character until an element symbol is found
  while ($elem) {
    return $elem if is_Element($elem);
    chop $elem;
  };
  return "??";
};

sub open_cif {
  my ($self) = @_;
  my @structures = STAR::Parser->parse($self->cif);
  my @id;
  foreach my $this (@structures) {
    my @str  = $this->get_item_data(-item => '_chemical_name_systematic');
    @str     = $this->get_item_data(-item => '_chemical_name_mineral') if not @str;
    @str     = $this->get_item_data(-item => '_chemical_formula_structural') if not @str;
    @str     = (basename($self->cif)) if not @str;
    push @id, @str;
  };
#   my @id = map { ($_->get_item_data(-item => '_chemical_name_systematic'   ))[0]
# 		   or
# 		 ($_->get_item_data(-item => '_chemical_name_mineral'      ))[0]
# 		   or
# 		 ($_->get_item_data(-item => '_chemical_formula_structural'))[0]
# 	       } @structures;
  return @id;
};


## I would like to avoid touching the STAR code for the time being.
## However, I need to address a bit of suckiness at the intersection
## of CIF Street and STAR Avenue.  There is, it seems, no guarentee
## that CIF tags will be capitalized consistently.  I recently (see
## mailing list post from Jiahui Qi, 10 December 2012) came across a
## CIF file with the space group specified as
## "_symmetry_Int_tables_number".  If you look above, you will find
## that I am searching for "_symmetry_Int_Tables_number".  That was
## enough to confuse the get_item_data method in STAR::DataBlock.
##
## The following silently redefines get_item_data to make it case
## insensitive.  Fuckety fuck fuck!
package STAR::DataBlock;
no warnings 'redefine';
sub get_item_data {

    my ($self,@parameters) = @_;
    my ($d,$s,$c,$i);

    $d = $self->title;               #default data block
    $s = '-';                        #default save block

    $i = shift @parameters unless $#parameters;
    while ($_ = shift @parameters) {
       $d = shift @parameters if /-datablock/;
       $s = shift @parameters if /-save/;
       $i = shift @parameters if /-item/;
    }

    if ( $i =~ /^(\S+?)\./ ) {
        $c = $1;
    }
    else {
        $c = '-';
    }

    foreach my $k (keys %{$self->{DATA}{$d}{$s}{$c}}) {
      if ($i =~ m{$k}i) {
	$i = $k;
	last;
      };
    };
    return if (! exists $self->{DATA}{$d}{$s}{$c}{$i});
    return @{$self->{DATA}{$d}{$s}{$c}{$i}};
}


1;


=head1 NAME

Demeter::Atoms::Cif - Methods for importing data from Crystallographic Information Files

=head1 VERSION

This documentation refers to Demeter version 0.9.21.

=head1 DESCRIPTION

This role allows data from a CIF file to be imported into a
L<Demeter::Atoms> object.

=head1 METHODS

=over 4

=item C<read_cif>

Read a record from a CIF file.

  my $atoms = Demeter::Atoms->new;
  $atoms->file("my_structure.cif");
  $atoms->record(2);

This example reads the second record from the given CIF file.  If the
record is not specified, the first record in the file will be
imported.  That means that the correct thing is done in the case of a
single-record CIF file.

Note that a CIF file has no concept of a central atom in the XAS
sense.  The default behavior is to select the heaviest atom as the
central atom.

=item C<open_cif>

Open a CIF file and return a list of identifiers of the structures in
that file.

  my @records = $atoms->open_cif;
  print join($/, @records), $/;
    ==prints==>
      Gold Chloride
      Gold(III) Chloride

In a GUI, this could be used to present a dialog to the user for
selecting the correct record from the CIF file.

=back

=head1 DEPENDENCIES

=over 4

=item *

L<STAR::Parser>

=item *

L<Chemistry::Elements>

=back

=head1 BUGS AND LIMITATIONS

This only reads the part of the CIF file that Demeter::Atoms uses.
All other information in the CIF file is ignored.

Please report problems to the Ifeffit Mailing List
(L<http://cars9.uchicago.edu/mailman/listinfo/ifeffit/>)

Patches are welcome.

=head1 AUTHOR

Bruce Ravel, L<http://bruceravel.github.io/home>

L<http://bruceravel.github.io/demeter/>

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006-2014 Bruce Ravel (http://bruceravel.github.io/home). All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlgpl>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
