package Demeter::Atoms::Cif;

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

use Moose::Role;
use Demeter::StrTypes qw( Element );

use Chemistry::Elements qw(get_Z);
use STAR::Parser;

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
		    _chemical_formula_sum
		    _publ_author_name
		    _citation_journal_abbrev
		    _publ_section_title
		  )) {
    @item = $datablock->get_item_data(-item=>$i);
    $item[0] ||= "";
    $item[0] =~ s///g;
    chomp $item[0];
    if ($item[0] !~ m{\A\s*\z}) {
      foreach my $t (split(/\n/, $item[0])) {
	$self->push_titles($t) if ($t !~ m{\A\s*\z});
      };
    };
  };

  ## space group: try the number then the HM symbol and canonicalize it
  @item = $datablock->get_item_data(-item=>"_symmetry_space_group_name_H-M");
  my @sg = $self->cell->canonicalize_symbol($item[0]);
  @item = $datablock->get_item_data(-item=>"_symmetry_Int_Tables_number") if not $sg[0];
  $self->space($item[0]);

  ## lattic parameters
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
  foreach my $i (0 .. $#tag) {
    my $ee = $el[$i] || $tag[$i];
    $ee = _get_elem($ee);
    (my $xx = $x[$i]) =~ s/\(\d+\)//; # remove parenthesized error bars
    (my $yy = $y[$i]) =~ s/\(\d+\)//;
    (my $zz = $z[$i]) =~ s/\(\d+\)//;
    (my $oo = $occ[$i]||1) =~ s/\(\d+\)//;
    ##print "$ee, $xx, $yy, $zz, $tag[$i], $oo\n";
    my $this = join("|",$ee, $xx, $yy, $zz, $tag[$i]);
    $self->push_sites($this);
    my $z = get_Z($ee);
    if ($z > $maxz) {
      $maxz = $z;
      $self->core($tag[$i]);
    };
  };
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
  my @id = map { ($_->get_item_data(-item => '_chemical_name_systematic'   ))[0]
		   or
		 ($_->get_item_data(-item => '_chemical_name_mineral'      ))[0]
		   or
		 ($_->get_item_data(-item => '_chemical_formula_structural'))[0]
	       } @structures;
  return @id;
};


1;


=head1 NAME

Demeter::Atoms::Cif - Methods for importing data from Crystallographic Information Files

=head1 VERSION

This documentation refers to Demeter version 0.2.

=head1 DESCRIPTION

explain how to use cif and record

=head1 METHODS

=over 4

=item C<read_cif>

=item C<open_cif>

returns a list of identifiers of the structures in the CIF file

=back

=head1 BUGS AND LIMITATIONS

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
