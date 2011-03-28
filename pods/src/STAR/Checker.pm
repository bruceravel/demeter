package STAR::Checker;

use STAR::DataBlock;
use STAR::Dictionary;

use strict;
use Time::localtime;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);

$VERSION = '0.02';

#  $Id: Checker.pm,v 1.2 2000/12/19 22:54:56 helgew Exp $   RCS Identification


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


#######################
# Class method: check #
#######################

sub check {

    my ($self, @parameters) = @_;                 
    my ($data,$dict,$options);
    $options = "";
	
    while ($_ = shift @parameters) {
       $data = shift @parameters if /-datablock/;
       $dict = shift @parameters if /-dictionary/;
       $options = shift @parameters if /-options/;
    }

    my ($n, $d, $save, @saves, $cat, @cats, $item, @items);
    my (@depend_items, $depend_item);
    my ($value, @values);
    my (%dict_lookup, %item_lookup, %cat_lookup);
    my (@parent_items, @child_items);
    my (%cp_hash, $cp_hash_ref);   #child parent hash
    my ($mand);
    my ($construct, @constructs, $code, @code_data, @codes, %item_types);
    my ($debug, $log,$problem);

    $log = 1       if $options =~ /l/;
    $debug = 1     if $options =~ /d/;
    
    if ( $data->type eq 'dictionary' ) {
        print STDERR "Method check_against_dict is to be invoked only on\n",
          "DataBlock objects, not on dictionaries themselves.\n";
        return;
    }

    print STDERR "-"x50,"\n" if $log;
    print STDERR "$0 ", ctime(),"\n" if $log;
    print STDERR "Checking ",$data->title,
      " against ",$dict->title,"\n" if $log;

    @items = $data->get_items;
    @cats = $data->get_categories;
    @saves = $dict->get_save_blocks;

    #make a dictionary lookup hash -- keys: lowercase, values: original case
    foreach $save (@saves) {
        $dict_lookup{lc($save)} = $save;
    }

    #same for an file item lookup hash
    foreach $item (@items) {
        $item_lookup{lc($item)} = $item;
    }

    #same for a file category lookup hash
    foreach $cat (@cats) {
        $cat_lookup{lc($cat)} = $cat;
    }

    # 1) checking whether items are present in dictionary
    # ---------------------------------------------------

    print STDERR "Checking whether items are present in dictionary\n" if $log;

    foreach $item (@items) {
        if ( ! exists $dict_lookup{lc($item)} ) {
	    $problem=1;
	    print STDERR "\t$item not in dictionary\n" if $log;
	}
    }
  
    # 2) checking for presence of mandatory items in file
    # ---------------------------------------------------

    print STDERR "Checking whether mandatory items ",
     "are present in file\n" if $log;

    foreach $save ( @saves ) {
        if ( $save =~ /^(_\S+?)\.\S+/ ) { # $save is item, not cat 
            $cat = $1;
            $item = $save;
            $mand = ($dict->get_item_data(-save=>$save,
                                 -item=>"_item.mandatory_code"))[0];
            if ( $mand eq "yes" ) {  #item is mandatory
                if ( exists $cat_lookup{lc($cat)} ) { #the cat is in the file
                    if ( ! exists $item_lookup{lc($item)} ) { #oops, should've
                                                             #been present
                        $problem=1;
                        print STDERR "\t$item not present\n" if $log;
                    }
                }
            }
        }
    } 
    
    # 3) checking for presence of dependent items in file
    # ---------------------------------------------------

    print STDERR "Checking whether dependent items",
     " are present in file\n" if $log;

    foreach $item ( @items ) {
        if ( exists $dict_lookup{lc($item)} ) {
            @depend_items = $dict->get_item_data(
                              -save=>$dict_lookup{lc($item)},
                              -item=>"_item_dependent.dependent_name");
            foreach $depend_item ( @depend_items ) {
                if ( ! exists $item_lookup{lc($depend_item)} ) {
                    $problem=1;
                    print STDERR "\t$depend_item not present ",
                      "(required by $item)\n" if $log;
                }
            }
        }
    }
 
    # 4) checking for presence of parent items
    # ----------------------------------------

    print STDERR "Checking for presence of parent items\n" if $log;

    if ( -r "cp_hash" ) {
        print "Retrieving previously stored cp_hash\n" if $log;
        $cp_hash_ref = Storable::retrieve("cp_hash");
        %cp_hash = %$cp_hash_ref;
    }
    else {
        print "Assembling and storing new cp_hash\n" if $log;
        foreach $save ( @saves ) {
            @parent_items  = $dict->get_item_data(-save=>$save,
                                      -item=>"_item_linked.parent_name");
            @child_items   = $dict->get_item_data(-save=>$save,
                                      -item=>"_item_linked.child_name");
            if ( $#parent_items >=0 ) {
                foreach $n ( 0..$#parent_items ) {
                    $cp_hash{lc($child_items[$n])} = lc($parent_items[$n]);
                }
            }
        }
        Storable::store \%cp_hash, "cp_hash";
    }
 
    foreach $item ( @items ) {
        if ( exists $cp_hash{lc($item)} ) {
            if ( ! exists $item_lookup{$cp_hash{lc($item)}} ) {
                print STDERR "\t",$cp_hash{lc($item)}, " not present ",
                  "(parent to $item)\n" if $log;
            }
        }
    }
    
    # 5) checking for correct item types
    # ----------------------------------

    print STDERR "Checking values against type definitions\n" if $log;

    @constructs=$dict->get_item_data(-save=>'-',
                                     -item=>'_item_type_list.construct');
    @codes=$dict->get_item_data(-save=>'-',
                                -item=>'_item_type_list.code');
    foreach $n (0..$#codes) {
        $item_types{$codes[$n]} = $constructs[$n];
    }

    foreach $item ( @items ) {
        $code="";
        print STDERR "data item: $item\n" if $debug;
        print STDERR "dict item: ",$dict_lookup{lc($item)},"\n" if $debug;
        if ($dict_lookup{lc($item)}) {
            $code = ($dict->get_item_data
                          (-save=>$dict_lookup{lc($item)},
                           -item=>'_item_type.code'))[0];
		     # not all items have this defined
            $construct = $item_types{$code} if $code;
        }
		
	if ( !$code ) {
            print STDERR "type code undefined\n" if $debug;
	}
	else {
            @values = $data->get_item_data(-item=>$item);
	    print STDERR "values 0..",$#values,"\n" if $debug;
            $n=0;
	    foreach $value (@values) {
                if ( $value eq '.' || $value eq '?' ) {
                    print STDERR "$n item value undefined\n" if $debug;
                }
                elsif ( $value =~ /^$construct$/ ) {
                    print STDERR "$n type $code ok\n" if $debug;
                }              
                else {
	            $problem = 1;
                    if ($log) {
                        print STDERR "\t","-"x14,"\n","\ttype mismatch:\n"; 
                        print STDERR "\titem: $item\n";
                        print STDERR "\titeration: $n\n";
                        print STDERR "\tvalue: $value\n";
                        print STDERR "\tcode: $code\n";
                        print STDERR "\tconstruct: $construct\n";
                    }
                }
            $n++;
            }
	}
    }
    return ( $problem ? 0 : 1 );  #returns 1 if check ok (no problem)
                                  #returns 0 if problem found
}

1;
__END__

=head1 NAME

STAR::Checker - Perl extension for checking DataBlock objects

=head2 Version

This documentation refers to version 0.02 of this module.

=head1 SYNOPSIS

  use STAR::Checker;
 
  $check = STAR::Checker->check( -datablock=>$ARGV[0],
                                 -dictionary=>$ARGV[1] );

=head1 DESCRIPTION

Contains the checker object, with methods for checking DataBlock object against 
STAR rules and against a specified dictionary.
DataBlock objects are created by Parser and modified by DataBlock.

=head1 CLASS METHODS

=head2 check

  Usage:   $check = STAR::Checker->check(-datablock=>$data, 
                                         -dictionary=>$dict [,
                                         -options=>$options ] );

Checks the DataBlock object C<$data> against the dictionary object 
C<$dict> (see STAR::Parser and STAR::DataBlock). Checks 1) whether 
all items in the DataBlock are defined in the dictionary, 
2) whether mandatory items are present in the file, 3) whether dependent 
items are present in the file (e.g. cartn_x makes cartn_y and cartn_z 
dependent), 4) whether parent items are present,  
and 5) whether the item values in the DataBlock conform to the item type 
definitions in the dictionary.

Returns 1 if the check was successful (no problems were found), 
and 0 if the check was unsuccessful (problems were found). 
A list of the specific problems is written to STDERR when C<-options=E<gt>'l'> 
is specified.

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
