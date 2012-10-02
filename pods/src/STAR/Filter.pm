package STAR::Filter;

use STAR::DataBlock;
use STAR::Dictionary;

use strict;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);

$VERSION = '0.01';

# $Id: Filter.pm,v 1.2 2000/12/19 22:54:56 helgew Exp $  RCS Identification


####################
# Constructor: new #
####################

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self = {};
    bless ($self,$class);
    return $self;
}


#############################
# Class method: filter_dict #
#############################

# a simple interactive method which goes through
# the dictionary category by category and prompts
# the user whether to keep/include it

# This method is preliminary and should be considered 
# subject to change

# this filters/reduces the in-memory data representation (.cob) 
# of the dictionary, not the dictionary file (.cif)

sub filter_dict {

    my ($self, @parameters) = @_;
    my ($dict, $dict_filtered, $options);

    while ($_ = shift @parameters) {
        $dict = shift @parameters if /-dict/;
        $options = shift @parameters if /-options/;
    }

    my ($d, $s, $c, $i); #data, save, category, item
    my (@saves, $save);
    my ( %keep_cat_lookup, $incl );

    $dict_filtered = STAR::Dictionary->new;

    $dict_filtered->{TITLE} = ($dict->{TITLE})."_filtered";
    $dict_filtered->{TYPE} = $dict->{TYPE};
    $dict_filtered->{FILE} = $dict->{FILE};
    $dict_filtered->{STARTLN} = $dict->{STARTLN};
    $dict_filtered->{ENDLN} = $dict->{ENDLN};

    print $dict->get_attributes;

    #build up keep_cat_lookup
    foreach $d ( keys %{$dict->{DATA}} ) {
        foreach $s ( sort keys %{$dict->{DATA}{$d}} ) {
            if ( $s eq "-" ) {  #dictionary itself (no save block)
                $keep_cat_lookup{lc($s)} = $s;
            }
            elsif ( $s !~ /\./ ) {  #it's a category, not an item
                print "Category $s -- include? (y/n)";
                $incl = <STDIN>;
                chomp $incl;
                if ( $incl =~ /y/ ) {
                    $keep_cat_lookup{lc($s)} = $s;   #hash lookup 
                                                     #lower case => original
                }  
            }
        }
    }

    #filter dictionary according to keep_cat_lookup hash
    foreach $d ( keys %{$dict->{DATA}} ) {  
        foreach $s ( keys %{$dict->{DATA}{$d}} ) {

            if ( $s !~ /\./ && $keep_cat_lookup{lc($s)} ) {
            #save block that's a category to be included

                foreach $c ( keys %{$dict->{DATA}{$d}{$s}} ) {
                    foreach $i ( keys %{$dict->{DATA}{$d}{$s}{$c}} ) {
                            $dict_filtered->{DATA}{$d}{$s}{$c}{$i} =
                            $dict->{DATA}{$d}{$s}{$c}{$i};
                    }
                }
            }

            if ( $s =~ /^_(\S+)\./ && $keep_cat_lookup{lc($1)} ) {
            #save block that's an item in a category to be included

                foreach $c ( keys %{$dict->{DATA}{$d}{$s}} ) {
                    foreach $i ( keys %{$dict->{DATA}{$d}{$s}{$c}} ) {
                            $dict_filtered->{DATA}{$d}{$s}{$c}{$i} =
                            $dict->{DATA}{$d}{$s}{$c}{$i};
                    }
                }
            }
        }
        $dict_filtered->{DATA}{$d}{"-"}{"_dictionary"}
                        {"_dictionary.version"}[0]
          .= "_filtered";
    }

    return $dict_filtered;
}


#####################################
# Class method: filter_through_dict #
#####################################

sub filter_through_dict {

    my ($self,@parameters) = @_;
    my ($data, $out, $dict, $options);

    while ($_ = shift @parameters) {
       $data = shift @parameters if /-data/;
       $dict = shift @parameters if /-dict/;
       $options = shift @parameters if /-options/;
    }

    my ($d,$s,$c,$i);  # data, save, category, item
    my (@items);
    my ($dict_item, @dict_items, %dict_lookup);

    @items = $data ->get_items;
    @dict_items = $dict->get_save_blocks;

    foreach $dict_item (@dict_items) {
        $dict_lookup{lc($dict_item)} = $dict_item;
    }

    $out = STAR::DataBlock->new;

    $out->{TITLE} = $data->{TITLE};
    $out->{TYPE} = $data->{TYPE};
    $out->{FILE} = $data->{FILE};
    $out->{STARTLN} = $data->{STARTLN};
    $out->{ENDLN} = $data->{ENDLN};

    foreach $d ( keys %{$data->{DATA}} ) {  
        foreach $s ( keys %{$data->{DATA}{$d}} ) {
            foreach $c ( keys %{$data->{DATA}{$d}{$s}} ) {
                foreach $i ( keys %{$data->{DATA}{$d}{$s}{$c}} ) {
                    if ( $dict_lookup{lc($i)} ) {
                        $out ->{DATA}{$d}{$s}{$c}{$i} =
                        $data->{DATA}{$d}{$s}{$c}{$i};
                    }
                }
            }
        }
    }
    return $out;
}

1;
__END__

=head1 NAME

STAR::Filter - Perl extension for filtering DataBlock objects

=head2 Version

This documentation refers to version 0.01 of this module.

=head1 SYNOPSIS

  use STAR::Filter;

=head1 DESCRIPTION

Contains the filter object for filtering DataBlock objects.
DataBlock objects are created by Parser and modified by DataBlock.

=head1 CLASS METHODS

=head2 filter_dict

  Usage:  $filtered_dict = STAR::Filter->filter_dict(
                             -dict=>$dict,
                             -options=>$options);

A (very simplistic) interactive method for filtering a STAR::Dictionary 
object (.cob file). The user is prompted for each category whether 
to include (retain) it in the filtered object. The method returns a 
reference to the filtered (reduced) STAR::Dictionary object.

Note: This method is preliminary and subject to change.

=head2 filter_through_dict

  Usage:  $filtered_data = STAR::Filter->filter_through_dict(
                             -data=>$data,
                             -dict=>$dict,
                             -options=>$options);

Filters an STAR::DataBlock object through a STAR::Dictionary object. 
Returns a reference to a new STAR::DataBlock object in which only 
those items are included which were defined in the specified dictionary.

=head1 AUTHOR

Wolfgang Bluhm, mail@wbluhm.com

=head2 Acknowledgments

Thanks to Phil Bourne, Helge Weissig, Anne Kuller, Doug Greer, 
Michele Bluhm, and others for support, help, and comments.

=head1 COPYRIGHT

A full copyright statement is provided with the distribution
Copyright (c) 2000 University of California, San Diego

=head1 SEE ALSO

STAR::Parser, STAR::DataBlock, STAR::Dictionary.

=cut
