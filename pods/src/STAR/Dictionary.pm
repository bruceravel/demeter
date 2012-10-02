package STAR::Dictionary;

use strict;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK );
use STAR::DataBlock;

@ISA = qw( STAR::DataBlock );

$VERSION = '0.56';

# $Id: Dictionary.pm,v 1.2 2000/12/19 22:54:56 helgew Exp $   RCS Identification


####################
# Constructor: new #
####################

sub new {
    my ($proto, @parameters) = @_;
    my $class = ref($proto) || $proto;
    my $file;
    my $self;

    $file = shift @parameters unless $#parameters;
    while ($_ = shift @parameters) {
        $file = shift @parameters if /-file/;
    }

    if ( $file ) {
        $self = Storable::retrieve($file);
    }
    else {
        $self = {};
        bless ($self,$class);
    }

    return $self;
}


##################################
# Object method: get_save_blocks #
##################################

sub get_save_blocks {

    my $self = shift;
    my ($d, $s);
    my (@save_blocks);

    foreach $d ( sort keys %{$self->{DATA}} ) {
        foreach $s ( sort keys %{$self->{DATA}{$d}} ) {
            push @save_blocks,$s;
        }
    }
    return @save_blocks;
}

1;
__END__


=head1 NAME

STAR::Dictionary - Perl extension for handling dictionaries that 
were parsed from STAR compliant files.

=head2 Version

This documentation refers to version 0.56 of this module. 

=head1 SYNOPSIS

  use STAR::Dictionary;

  $dict_obj = STAR::Dictionary->new(-file=>$file);
  @items_in_dict = $dict_obj->get_save_blocks;

=head1 DESCRIPTION

This package contains class and object methods for Dictionary objects 
created by STAR::Parser. 
This class is a sub class of STAR::DataBlock. It supports all methods from 
STAR::DataBlock (see related documentation), as well as the 
additional method get_save_blocks.

=head1 OBJECT METHODS

=head2 get_save_blocks

  Usage:   @save_blocks = $dict_obj->get_save_blocks; 

This methods returns an array with all save_ blocks found in the Dictionary 
object. Each item defined in the dictionary is described within a save block. 
In addition, items pertaining to the dictionary itself (such as 
_dictionary.version) are found outside of save blocks in the dictionary file. 
In the data structure of a Dictionary object, these items are gathered 
in a C<$s='-'> save block.

=head1 AUTHOR

Wolfgang Bluhm, mail@wbluhm.com

=head2 Acknowledgments

Thanks to Phil Bourne, Helge Weissig, Anne Kuller, Doug Greer,
Michele Bluhm, and others for support, help, and comments.

=head1 COPYRIGHT

A full copyright statement is provided with the distribution
Copyright (c) 2000 University of California, San Diego

=head1 SEE ALSO

STAR::Parser, STAR::DataBlock.

=cut
