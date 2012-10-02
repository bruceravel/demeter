package STAR::DataBlock;

use strict;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK );
use Storable;

$VERSION = '0.58';

#  $Id: DataBlock.pm,v 1.6 2001/07/10 17:05:51 wbluhm Exp $    RCS Identification


####################
# Constructor: new #
####################

# Overloaded constructor:
# 
# The no-arg constructor is called internally by parse in STAR::Parser
#
#    $entry = STAR::DataBlock->new;
#
# To retrieve an already stored DataBlock, use this in an application:
#
#    $data = STAR::DataBlock->new("file");

sub new {
    my ($proto, @parameters) = @_;
    my $class = ref($proto) || $proto;
    my $file;
    my $self;

    $file = shift @parameters unless $#parameters;  
    #
    #  the above is executed if and only if $#parameters == 0,
    #  which means only if exactly one parameter is being passed
    #  (in "unnamed parameters" style)

    while ($_ = shift @parameters) {
        $file = shift @parameters if /-file/;
    } 

    if ( $file ) {
        $self = retrieve($file);
    }
    else {
        $self = {};
        bless ($self,$class);
    }

    return $self;
}
 

######################################
# Private object method: _all_tokens #
######################################

# This method was moved into Parser.pm
# as a class method with version 0.58



########################################
# Private object method: _tokens_check #
########################################

# This method (which had not been implemented yet)
# would also have to become a class method in Parser.

 

#############################
# Object method: add_quotes #
#############################

# Note: This method is called by STAR:Writer->write_cif
#
# There may or may not be any need for 
# explicit user calls to this method.

sub add_quotes {
    my ($self,@parameters) = @_;    
    my ($d,$s,$c,$i);                  #data, save, category, item
    my ($n,$value,$log);
    
    foreach $d ( keys %{$self->{DATA}} ) {
        foreach $s ( keys %{$self->{DATA}{$d}} ) {
            foreach $c ( keys %{$self->{DATA}{$d}{$s}} ) {
                foreach $i ( keys %{$self->{DATA}{$d}{$s}{$c}} ) {
                    foreach $n ( 0..$#{$self->{DATA}{$d}{$s}{$c}{$i}} ) {
                        $value = $self->{DATA}{$d}{$s}{$c}{$i}[$n];
                        if ( $self->{DATA}{$d}{$s}{$c}{$i}[$n]
                              =~ /(\n)/s ) {                   #if line break
                            $self->{DATA}{$d}{$s}{$c}{$i}[$n] 
                             =~ s/^([^;].*)/;\n$1;\n/s;        #if no leading ;
                            $self->{DATA}{$d}{$s}{$c}{$i}[$n]
                             =~ s/^;\n\n(.*)/;\n$1/s;          #remove leading
                                                               #blank line 
                        }
                        elsif ( $self->{DATA}{$d}{$s}{$c}{$i}[$n]
                              =~ /(\s+)/ ) {                   #if white space
                            $self->{DATA}{$d}{$s}{$c}{$i}[$n] 
                             =~ s/^([^"'].*)/"$1"/s;           #if no 
                                                               #leading quote
                        }
                        elsif ( $self->{DATA}{$d}{$s}{$c}{$i}[$n]
                              =~ /^(_.*)/ ) {
                            $self->{DATA}{$d}{$s}{$c}{$i}[$n] 
                             = '"'.$1.'"';
                        }
                    }
                }
            }
        }
    }
    return $self;
}    


################################
# Object method: get_item_data #
################################

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
    return if (! exists $self->{DATA}{$d}{$s}{$c}{$i});
    return @{$self->{DATA}{$d}{$s}{$c}{$i}};
}


# both insert_category and insert_item may be unnecessary methods

##################################
# Object method: insert_category #
##################################

sub insert_category {

    my ($self, @parameters) = @_;
    my ($d, $s, $c);

    $d = $self->title;      # default data block
    $s = '-';               # default save block

    $c = shift @parameters unless $#parameters;   # single "unnamed" parameter
    while ( $_ = shift @parameters ) {
        $d = shift @parameters if /-datablock/;
        $s = shift @parameters if /-save/;
        $c = shift @parameters if /-cat/;
    }

    if ( exists $self->{DATA}{$d}{$s}{$c} ) {
        # category already exists
        # do nothing
    } 
    else {
        $self->{DATA}{$d}{$s}{$c} = {};   #just an empty addition to the hash
                                          #no data yet
        print "inserted category $c\n";
    }
    return;
}


##############################
# Object method: insert_item #
##############################

sub insert_item {
 
    my ($self, @parameters) = @_;
    my ($d, $s, $c, $i);

    $d = $self->title;      # default data block
    $s = '-';               # default save block

    $i = shift @parameters unless $#parameters;   # single "unnamed" parameter
    while ( $_ = shift @parameters ) {
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

    #has the category already been created?
    if ( ! exists $self->{DATA}{$d}{$s}{$c} ) {
        print "category $c doesn't exist\n";
        $self->insert_category( -datablock=>$d, -save=>$s, -cat=>$c );
    }

    #has the item been created before?
    if ( exists $self->{DATA}{$d}{$s}{$c}{$i} ) {
        # item already exists
        # do nothing
    }
    else {
        $self->{DATA}{$d}{$s}{$c}{$i} = ();  # empty array, still no data
    }
    return;
}


################################
# Object method: set_item_data #
################################

sub set_item_data {

    my ($self, @parameters) = @_;
    my ($d, $s, $c, $i, $data_ref);
 
    $d = $self->title;      # default data block
    $s = '-';               # default save block

    #no single "unnamed" parameter in this case
    #need at least -item and -dataref

    while ( $_ = shift @parameters ) {
        $d = shift @parameters if /-datablock/;
        $s = shift @parameters if /-save/;
        $i = shift @parameters if /-item/;
        $data_ref = shift @parameters if /-dataref/;
    }

    if ( $i =~ /^(\S+?)\./ ) {
        $c = $1;
    }
    else {
        $c = '-';
    }

    #does the item exist?
    if ( ! exists $self->{DATA}{$d}{$s}{$c}{$i} ) {
        $self->insert_item( -datalblock=>$d, -save=>$s, -item=>$i );
    }
 
    #now add the data
    $self->{DATA}{$d}{$s}{$c}{$i} = $data_ref; 

    return;
}


###########################
# Object method: get_keys #
###########################

sub get_keys {

    my ($self,@parameters) = @_;

    my ($d, $s, $c, $i, $log);
    my $keys = '';

    $keys .= "data\tsave\n";
    $keys .= "block\tblock\tcateg.\titem\n";
    $keys .= "----------------------------\n\n";
    foreach $d ( sort keys %{$self->{DATA}} ) {
        $keys .= "$d\n";
        foreach $s ( sort keys %{$self->{DATA}{$d}} ) {
            $keys .= "\t$s\n";
            foreach $c ( sort keys %{$self->{DATA}{$d}{$s}} ) {
                $keys .= "\t\t$c\n";
                foreach $i ( sort keys %{$self->{DATA}{$d}{$s}{$c}} ) {
                    $keys .= "\t\t\t$i\n";
                }
            }
        }
    }
    return $keys;
}


############################
# Object method: get_items #
############################

sub get_items {
 
    my $self = shift;
    my ($d,$s,$c,$i);
    my (@items);   
 
    foreach $d ( sort keys %{$self->{DATA}} ) {
        foreach $s ( sort keys %{$self->{DATA}{$d}} ) {
            foreach $c ( sort keys %{$self->{DATA}{$d}{$s}} ) {
                foreach $i ( sort keys %{$self->{DATA}{$d}{$s}{$c}} ) {
                    push @items,$i;
                }
            }
        }
    }
    return @items;
}


#################################
# Object method: get_categories #
#################################

sub get_categories {
 
    my $self = shift;
    my ($d, $s, $c);
    my (@cats);   
 
    foreach $d ( sort keys %{$self->{DATA}} ) {
        foreach $s ( sort keys %{$self->{DATA}{$d}} ) {
            foreach $c ( sort keys %{$self->{DATA}{$d}{$s}} ) {
                push @cats,$c;
            }
        }
    }
    return @cats;
}


#################################
# Object method: get_attributes #
#################################

sub get_attributes {

    my $self = shift;      
    my $string;
        
    $string .= $self->{TITLE};
    $string .= " (dictionary)" if ($self->{TYPE} eq 'dictionary');
    $string .= "\n";
    $string .= "File: ".$self->{FILE}."   ";
    $string .= "Lines: ".$self->{STARTLN};
    $string .= " to ".$self->{ENDLN}."\n";

    return $string;
}


#################################
# Object methods:               #
# file_name, title, type,       #
# starting_line, ending_line    #
#################################


#############
# file_name #
#############

sub file_name {
    my ($self,@parameters) = @_;
    $self->{FILE} = shift @parameters unless $#parameters; 
    while ($_ = shift @parameters ) {
        $self->{FILE} = shift @parameters if /-file/;
    }
    return $self->{FILE};
}


#########
# title #
#########

sub title {
    my ($self,@parameters) = @_;
    $self->{TITLE} = shift @parameters unless $#parameters; 
    while ($_ = shift @parameters ) {
        $self->{TITLE} = shift @parameters if /-title/;
    }
    return $self->{TITLE};
}


########
# type #
########

sub type {
    my ($self,@parameters) = @_;
    $self->{TYPE} = shift @parameters unless $#parameters; 
    while ($_ = shift @parameters ) {
        $self->{TYPE} = shift @parameters if /-type/;
    }
    return $self->{TYPE};
}


#################
# starting_line #
#################

sub starting_line {
    my ($self,@parameters) = @_;
    $self->{STARTLN} = shift @parameters unless $#parameters; 
    while ($_ = shift @parameters ) {
        $self->{STARTLN} = shift @parameters if /-startln/;
    }
    return $self->{STARTLN};
}


###############
# ending_line #
###############

sub ending_line {
    my ($self,@parameters) = @_;
    $self->{ENDLN} = shift @parameters unless $#parameters; 
    while ($_ = shift @parameters ) {
        $self->{ENDLN} = shift @parameters if /-endln/;
    }
    return $self->{ENDLN};
}

1;
__END__


=head1 NAME

STAR::DataBlock - Perl extension for handling DataBlock objects created 
by STAR::Parser.

=head2 Version

This documentation refers to version 0.58 of this module.

=head1 SYNOPSIS

  use STAR::DataBlock;
  
  $data_obj = STAR::DataBlock->new(-file=>$ARGV[0]);  #retrieves stored file
  
  $attributes = $data_obj->get_attributes;
  print $attributes;

  @items = $data_obj->get_items;

  foreach $item ( @items ) {
      @item_data = $data_obj->get_item_data( -item=>$item );
      $count{ $_ } = $#item_data + 1;

      # do something else (hopefully more useful) with @item_data...
  }

=head1 DESCRIPTION

This package contains class and object methods for 
dealing with DataBlock objects created by STAR::Parser. 
They include methods for such tasks as reading  
objects from disk, querying their data structures 
or writing DataBlock objects as STAR compliant files.

All methods support a "named parameters" style for passing arguments. If 
only one argument is mandatory, then it may be passed in either a 
"named parameters" or "unnamed parameters" style, for example:

       $data_obj->get_item_data( -file=>$file, -save=>'-' );
   or: $data_obj->get_item_data( -file=>$file ); 
   or: $data_obj->get_item_data( $file );  

       # all of the above are the same, since -save=>'-' is the default
       # and therefore only one parameter needs to be specified 
       # in "named" or "unnamed" parameter style

Some methods may be invoked with on C<$options> string. Currently, only one 
option is supported:

  l  writes program activity log to STDERR

Future versions may support additional options.

=head1 CONSTRUCTOR

=head2 new

  Usage:  $data_obj = STAR::DataBlock->new();                #creates new object

          $data_obj = STAR::DataBlock->new( -file=>$file );  #retrieves previously
     OR:  $data_obj = STAR::DataBlock->new( $file );         #stored object

Overloaded constructor. Called as a no-arg constructor internally by STAR::Parser.
May be called with a C<$file> argument to retrieve an object previously stored with
store (see below).

=head1 OBJECT METHODS

=head2 store

  Usage:  $data_obj->store($file);

Saves a DataBlock object to disk. This method is in Storable.

=head2 get_item_data

  Usage: @item_data = $data_obj->get_item_data(-item=>$item[,
                                               -save=>$save_block]);

  Example:
  --------
  my @names=$data_obj->
            get_item_data(-item=>"_citation_author.name");
  print $names[0],"\n";  #prints first citation author name

This object method returns all the data for a specified item. 
If the C<-save> parameter is omitted, it is assumed that the item 
is not in a save block (i.e. C<$save='-'>). This is always the case 
in data files, since they do not contain save blocks. However, this 
class is sub-classed by STAR::Dictionary, where items may be in save 
blocks.
The data is returned as an array, which holds one or 
more scalars. 

=head2 get_keys

  Usage: $keys = $data_obj->get_keys;

Returns a string with a hierarchically formatted list of hash keys 
(data blocks, save blocks, categories, and items) 
found in the data structure of the DataBlock object. 

=head2 get_items

  Usage: @items = $data_obj->get_items;

Returns an array with all the items present in the DataBlock.

=head2 get_categories

  Usage: @categories = $data_obj->get_categories;

Returns an array with all the categories present in the DataBlock.

=head2 insert_category

  Usage: $data_obj->insert_category( -cat=>$cat[,
                                     -save=>$save] );

Inserts the category C<$cat> into the data structure. The default save block
(if none is specified) is C<'-'>.

=head2 insert_item

  Usage: $data_obj->insert_item( -item=>$item[,
                                 -save=>$save]  );

Inserts the item C<$item> into the data structure. The default save block 
(if none is specified) is C<'-'>.

=head2 set_item_data 

  Usage: $data_obj->set_item_data( -item=>$item, 
                                   -dataref=>$dataref[,
                                   -save=>$save] );

Sets the data of the item C<$item> to the array of data referenced by 
C<$dataref>. If the C<-save> parameter is omitted, the save block defaults to
C<'-'>. This is always correct for data blocks. In a dictionary (which inherits
from DataBlock), the save block C<'-'> contains information pertaining to the
dictionary itself.

=head2 Object attributes

The following five methods set or retrieve attributes of a DataBlock object. 
In the set mode (with argument), these methods are called internally 
to set the attributes of a DataBlock object. In the retrieve mode 
(without arguments) these methods may also be called by a user to 
retrieve object attributes (see the above examples).

=head2 file_name

  Usage:  $data_obj->file_name($name);   #set mode
          $name = $data_obj->file_name;  #get mode

Name of the file in which the DataBlock object was found

=head2 title

  Usage:  $data_obj->title($title);      #set mode
          $title = $data_obj->title;     #get mode

Title of the DataBlock object

=head2 type

  Usage:  $data_obj->type($type);        #set mode
          $type = $data_obj->type;       #get mode

Type of data contained (always 'data' for a DataBlock object, 
but 'dictionary' for an object in the sub class STAR::Dictionary) 

=head2 starting_line

  Usage:  $data_obj->starting_line($startln);    #set mode
          $startln = $data_obj->starting_line;   #get mode

Line number where data block started in the file

=head2 ending_line

  Usage:  $data_obj->ending_line($endln);        #set mode
          $endln = $data_obj->ending_line;       #get mode

Line number where data block ended in the file

=head2 get_attributes

  Usage: $info = $data_obj->get_attributes;

Returns a string containing a descriptive list of 
attributes of the DataBlock object. Two examples of output:

  RCSB011457
  File: native/1fbm.cif   Lines: 1 to 5294

  cif_mm.dic (dictionary)
  File: dictionary/mmcif_dict.txt   Lines: 89 to 38008

=head1 COMMENTS

This module provides no error checking of files or objects, 
either against the dictionary, or otherwise. 
Dictionary 
information is not currently used in the parsing 
of files by STAR::Parser. So, for example, information about 
parent-child relationships between items is not 
present in a DataBlock object. Functionality related to these 
issues is being provided in additional modules, such as STAR::Checker, 
and STAR::Filter.

=head1 AUTHOR

Wolfgang Bluhm, mail@wbluhm.com

=head2 Acknowledgments

Thanks to Phil Bourne, Helge Weissig, Anne Kuller, Doug Greer,
Michele Bluhm, and others for support, help, and comments.

=head1 COPYRIGHT

A full copyright statement is provided with the distribution
Copyright (c) 2000 University of California, San Diego

=head1 SEE ALSO

STAR::Parser, STAR::Dictionary.

=cut

