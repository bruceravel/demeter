package STAR::Parser;

use STAR::DataBlock;
use STAR::Dictionary;

use strict;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);

$VERSION = '0.59';

# $Id: Parser.pm,v 1.6 2004/04/08 17:03:43 wbluhm Exp $  RCS identification


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
# Class method: parse #
#######################

sub parse {

    my ($self,@parameters) = @_;      
    my ($file,$dict,$options);
    $options = '';
        
    $file = shift @parameters unless $#parameters;
    while ($_ = shift @parameters) {
       $file = shift @parameters if /-file/;
       $dict = shift @parameters if /-dict/;
       $options = shift @parameters if /-options/;
    }
    
    my ($d, $s, $c, $i);  # data and save blocks
                          # category, item
    my ($n, $m);          # loop counters
    my ($flag);
    my ($debug, $log);
    my (@entries, $entry);
    my (@cats_in_loop, @items_in_loop);
    my ($line_nums_ref, $flags_ref, $tokens_ref);

    my $token;      # Here, "token" shall mean an item name (e.g. _atom.id),
                    # or an item value, (5 examples: 1 value 'a value' . ? )
                    # or a value over several lines delimited by semicolons.

    $d = 'untitled';  # default (if no data block)
    $s = '-';         # default (if not in save block)
        
    $debug = 1      if ( $options =~ /d/ );
    $log =1         if ( $options =~ /l/ );


    ##################
    ### tokenizing ###
    ##################

    print STDERR "tokenizing complete file\n" if ( $log );

    ($line_nums_ref, $flags_ref, $tokens_ref) = STAR::Parser->_all_tokens(-file=>$file);          

    ### check integrity of token list -- pre-parsing check ###
    # this had not been implemented yet, but
    # would now have to be a class method in STAR::Parser

    if ($debug) {
        print STDERR "Start of tokens\n";
        foreach $n (0.. $#$tokens_ref) {
            print STDERR "next token: ",$$flags_ref[$n],
                        " ",$$tokens_ref[$n],"\n";
        }
        print STDERR "End of tokens\n";
    }        

    # default data block (if no data_ in file, e.g. for ERF files)

    $entry = STAR::DataBlock->new;
    $entry->file_name($file);
    $entry->type('data');
    $entry->title('untitled');
    $entry->starting_line(1);
    push @entries, $entry;


    ###############
    ### parsing ###
    ###############

    until ( (shift @$flags_ref) eq 'eof' ) {                
    
        $token = shift @$tokens_ref;
        print STDERR "next token: $token\n" if ($debug);
                            
        if ( $token =~ /^data_(.*)/ ) {        #data block 

            $d = $1;
            $s = '-';    # default (if not in save block)
            print STDERR "New data block: $token\n"  if ($debug);

            # create new "entry object" (DataBlock or Dictionary)
            # ---------------------------------------------------

            if ( $dict ) {
                $entry = STAR::Dictionary->new;
                $entry->type('dictionary');
            }
            else {
                $entry = STAR::DataBlock->new;
                $entry->type('data');
            }
            $entry->file_name($file);
            $entry->title($1);
            $entry->starting_line( shift @$line_nums_ref );   # next data block line number
            push @entries, $entry;

            print STDERR "parsing ",$entry->{TITLE},"\n" if ( $log );

            next;
        }

        if ( $token =~ /^save_(\S+)/ ) {       #save block
            $s = $1;
            print STDERR "save block: $s\n" if ($debug);
        }
        elsif ( $token =~ /^save_$/ ) {        #end of save block
            $s = '-';
        } 

        if ( $token =~ /^loop_/ ) {            #loop block
      
            print STDERR "started loop\n" if ($debug);
            $flag = shift @$flags_ref;
            $token = shift @$tokens_ref;
            @cats_in_loop = ();
            @items_in_loop = ();
            
            while ( $flag eq 'i' ) {  # need to check for $flag since _something could have 
                                      # also been a value (in quotes)

                if ( $token =~ /^(_\S+?)\.\S+/ ) {     # DDL2: _category.item
                    $c = $1;
                }
                else {                                 # DDL1: no notion of category
                    $c = '-';      
                }
                print STDERR "token (item) in loop: ", "$token\n" if ($debug);
                push @cats_in_loop, $c;
                push @items_in_loop, $token;
                $flag = shift @$flags_ref;
                $token = shift @$tokens_ref;
            }
            
            $m=0;                 
            until ( $flag ) {   #if it's NOT a value, it's got a flag

                foreach $n (0..$#items_in_loop) {
                    print STDERR "token (value) in loop: ",
                                 "$token\n" if ($debug);
                    $entry->{DATA}{$d}{$s}{$cats_in_loop[$n]}
                                          {$items_in_loop[$n]}[$m]
                          = $token;
                    $flag = shift @$flags_ref;     
                    if ( $flag && ( $n < $#items_in_loop ) ) {
                        die "fatal parsing error in category $cats_in_loop[$n]\n";
                    }
                    $token = shift @$tokens_ref;
                }
                $m++;
            }
            
            print STDERR "finished loop\n" if ($debug);
            print STDERR "last token (to be recycled): ",
                         "$token\n" if ($debug);
                        
            # the last token was out of 'loop_' 
            # and needs to be recycled at the top
            unshift @$flags_ref, $flag;
            unshift @$tokens_ref,$token;
        }
         
        elsif ( $token =~ /^_\S+/ ) {
            $i = $token;
            if ( $token =~ /^(_\S+?)\.\S+/ ) {     # DDL2: _category.item
                $c = $1;
            }
            else {                                 # DDL1: no notion of category
                $c = '-';      
            }
            $flag = shift @$flags_ref;
            if ( $flag ) {
                die "fatal parsing error in category $c\n";
            }
            $token = shift @$tokens_ref;     #this one must be a value!
            print STDERR "next token (value): ",
                         "$token\n" if ($debug);
            $entry->{DATA}{$d}{$s}{$c}{$i}[0] = $token;
        }
    }
    
    if ($#entries > 0) {   # if there is more than one entry
        shift @entries;     # discard the default "untitled" entry
    }

    # add ending line number attributes

    my @ending_lines;

    foreach $entry ( @entries ) {
        push @ending_lines, ( $entry->starting_line() - 1 );
    }

    shift @ending_lines;                              # first one didn't make sense
    push @ending_lines, ( shift @$line_nums_ref );    # last one is last line number

    foreach $entry ( @entries ) {
        $entry->ending_line( shift @ending_lines );
    }

    if ( $log ) {
        foreach $entry ( @entries ) {
            print STDERR $entry->get_attributes;
        }
    }

    return @entries;
}


#####################################
# Private class method: _all_tokens #
#####################################

# This method was moved from DataBlock to Parser in version 0.58

sub _all_tokens {

    my ($self, @parameters) = @_;
    my ($file);

    $file = shift @parameters unless $#parameters;
    while ($_ = shift @parameters) {
       $file = shift @parameters if /-file/;
    }

    my $multi_flag=0;
    my ($lines, $token, $rest);
    my (@line_nums, @flags, @tokens);

    open (IN, "<$file") or die "Can't open file $file";

    while (<IN>) {
        if ($multi_flag == 1) {
            if (  /^;\s(.*)/s ) {
                $multi_flag=0;          #one value (w/o semicolons)
                push @flags, '';
                push @tokens, $lines;   #no flag
                $_ = $1;                # continue with rest of line
                                        # closing semicolon does not have to be on line by itself
            }
            elsif ( /^;/ ) {
                $multi_flag=0;          #one value (w/o semicolons)
                push @flags, '';
                push @tokens, $lines;   #no flag
                next;
            }
            else {
                $lines .= $_;           #append
                next;
            }
        }
        elsif (  /^;(.*)/s ) {
            $multi_flag=1;              #start
            $lines = $1;                #newline still on
            next;
        }
        while ( /\S/ ) {
            last if ( /^\s*#/ );

            if ( /^\s*["']/s ) {

                /^\s*(["'])(.*?)\1\s(.*)/s;     #stuff in quotes is one token
                push @flags, '';                #it's a value, so no flag
                push @tokens, $2;
                $_ = $3;
            }
            elsif ( /^\s*(\S+)(.*)/s ) {        #one token

                $token = $1;
                push @tokens, $token;
                $_ = $2;

                unless ( $token =~ /_/ ) {
                    push @flags, '';            #without '_' certainly a value
                    next;
                }
                if ( $token =~ /^_/ ) {
                    push @flags, 'i';           #item
                }
                elsif ( $token =~ /^loop_/ ) {  #loop
                    push @flags, 'l';
                }
                elsif ( $token =~ /^save_/ ) {  #save
                    push @flags, 's';
                }
                elsif ( $token =~ /^data_/ ) {  #data
                    push @flags, 'd';
                    push @line_nums, $.;        # next data block line number
                }
                else {
                    push @flags, '';            #an unquoted value with '_'
                }
            }
        }
    }

    push @flags, 'eof';     # 'eof' added as last flag
                            # thus there should always be one more flag
    push @line_nums, $. ;   # last line number

    close (IN);

    return (\@line_nums, \@flags, \@tokens);
}


#######################################
# Private class method: _find_entries #
#######################################

# This method has been obsoleted in version 0.58.
# Since 0.58, files are no longer pre-parsed
# for data blocks, since it does not allow
# for proper functional assignment of all
# 'data' strings.      


1;
__END__


=head1 NAME

STAR::Parser - Perl extension for parsing STAR compliant files (with no 
nested loops).

=head2 Version

This documentation refers to version 0.59 of this module.

=head1 SYNOPSIS

  use STAR::Parser;
  
  ($data) = STAR::Parser->parse('1fbm.cif');

  ($dict) = STAR::Parser->parse(-file=>'mmcif_dict',
                                -dict=>1,
                                -options=>'l');  #logs activity

=head1 DESCRIPTION

STAR::Parser is one of several related Perl modules for parsing
STAR compliant files (such as CIF and mmCIF files). Currently, 
these modules include STAR::Parser, STAR::DataBlock, STAR::Dictionary,
STAR::Writer, STAR::Checker, and STAR::Filter.

STAR::Parser is the parsing module, with the class method parse 
for parsing any STAR compliant files or dictionaries, as long 
as they do B<not> contain nested loops (i.e., only B<one> level of 
loop is supported). 
Upon parsing of a file, an array of DataBlock objects is returned (one 
for each data_ entry in the file).  
The class 
STAR::DataBlock contains object methods for these objects.
STAR::DataBlock is automatically accessible through STAR::Parser.
Upon parsing of a dictionary (indicated with the C<-dict=E<gt>1> parameter), 
an array of Dictionary objects is returned. STAR::Dictionary is a sub-class 
of STAR::DataBlock.

The methods of this module and the accompanying modules 
(STAR::DataBlock, STAR::Checker, etc.) support 
"named parameters" style for passing arguments. If 
only one argument is mandatory, then it may be passed in either a 
"named parameters" or "unnamed parameters" style, for example:

       @objs = STAR::Parser->parse( -file=>$file, -options=>'d' );  #debugging

       @objs = STAR::Parser->parse( -file=>$file );  #no options
   or: @objs = STAR::Parser->parse( $file );

=head1 CLASS METHODS

=head2 parse

  Usage:  @objs = STAR::Parser->parse(-file=>$file[,
                                      -dict=>1,
                                      -options=>$options]);

     or:  @objs = STAR::Parser->parse($file);
                                    
  Examples: 
  
  1)  @objs = STAR::Parser->parse('1fbm.cif');
      $data = $objs[0];

      OR:

      ($data) = STAR::Parser->parse('1fbm.cif');

  2)  @objs = STAR::Parser->parse('7files.txt');
      foreach $obj (@objs) {
          # do something, see STAR::DataBlock
      }

  3)  @objs = STAR::Parser->parse(-file=>'mmcif_dict',
                                  -dict=>1,
                                  -options=>'l'); #logs activity
      $dict = @objs[0];

This method first searches the file and creates a DataBlock object 
for each data_ identifier found in the file. If no data_ identifier 
is found, then only one DataBlock object 
will be created (with C<$d='untitled'>, 
see below). If parse is invoked with the C<-dict=E<gt>1> option,
then a Dictionary object is created for each data_ identifier found.

Next, the method populates 
the data structure of each DataBlock or Dictionary object. 
The parsed data may be queried or accessed by 
object methods of the STAR::DataBlock and STAR::Dictionary modules. 
See the documentation for STAR::DataBlock and STAR::Dictionary.

The method always returns an array of objects, even if it contains only 
one object (if there is only one data_ block in the file). 

Internally, the parsed data is stored in a multidimensional 
hash with keys for data blocks (C<$d>), save blocks (C<$s>),
categories (C<$c>), and items (C<$i>). 
For a file, C<$s> will always be C<'-'>, since there are no 
save blocks in files. 
For a dictionary, C<$s> will be C<'-'> outside of save_ blocks, 
and C<'CATEGORY'> or C<'_item'> inside save_CATEGORY or save__item blocks 
(capitalization depends on the user's dictionary.)
If a file is parsed that contains no data_ identifier, then C<$d> becomes 
C<'untitled'>. C<$c> refers to a category, such as _atom_site and 
C<$i> refers to an item, such as _atom_site.id.

The method may be invoked with an $options string. These options 
are the following letters which may be concatenated in any order:

  d  writes debugging output to STDERR 
  l  writes program activity log to STDERR

=head1 COMMENTS

This module provides no error checking of files or objects, 
either against the dictionary, or otherwise. While 
the module is applicable to parsing either a 
file or a dictionary, dictionary 
information is not currently used in the parsing 
of files. So, for example, information about 
parent-child relationships between items is not 
present in a DataBlock object. Functionality related to these 
issues is being provided in additional modules such as STAR::Checker, 
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

STAR::DataBlock, STAR::Dictionary.

=cut
