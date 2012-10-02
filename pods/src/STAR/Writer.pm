package STAR::Writer;

use STAR::DataBlock;
use STAR::Dictionary;

use strict;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);

$VERSION = '0.01';

# $Id: Writer.pm,v 1.2 2000/12/19 22:54:56 helgew Exp $  RCS Identification


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


##########################
# Class method write_cif #
##########################

sub write_cif {

    my ($self,@parameters) = @_;      
    my ($file, $data);
    my $options = "";
        
#   single unnamed parameter doesn't make sense here, 
#   need -dataref and -file

    while ($_ = shift @parameters) {
       $file = shift @parameters if /-file/;
       $data = shift @parameters if /-dataref/;
       $options = shift @parameters if /-options/;
    }
    
    my ($d, $s, $c, $i);  #data, save, category, item
    my ($m);   # loop counter
    my ($string, $dict, $log, $debug);
    my ($cat, $item, @cats, @items, $next);
    
    $dict = 1     if ( $data->type eq 'dictionary' );
    $log  = 1     if ( $options =~ /l/ );
    $debug = 1    if ( $options =~ /d/ );
    
    $data->add_quotes;
    
    open (OUT, ">$file");
    
    print STDERR "writing $file\n" if ( $log );
    
    foreach $d ( sort keys %{$data->{DATA}} ) {
        print OUT "data_$d\n";

        foreach $s ( sort keys %{$data->{DATA}{$d}} ) {

            print STDERR "$s\n" if $debug ; # for debugging

            unless ( $s eq '-' ) { 
                print OUT "\n","#"x(length($s)+4),"\n";
                print OUT "# $s #\n";
                print OUT "#"x(length($s)+4),"\n\n";
                print OUT "save_$s\n"; 
            }
            if ( $dict && ( $s eq '-' ) ) {
                print OUT "\n##############\n";
                print OUT   "# DICTIONARY #\n";
                print OUT   "##############\n\n";
            }

        
            foreach $c ( sort keys %{$data->{DATA}{$d}{$s}} ) {
 
                print STDERR "\t$c\n" if $debug ; #for debugging

                unless ( $dict ) {
                    print OUT "\n","#"x(length($c)+4),"\n";
                    print OUT "# $c #\n";
                    print OUT "#"x(length($c)+4),"\n\n";
                }
            
                @items = sort keys %{$data->{DATA}{$d}{$s}{$c}};
                if ( $#{$data->{DATA}{$d}{$s}{$c}{$items[0]}} == 0 ) {

                    print STDERR "\t\tin items if\n" if $debug; #debugging

                    foreach $item ( @items ) {

                        print STDERR "\t\t$item\n" if $debug;  #for debugging

                        print OUT $item, "   ";
                        $next = $data->{DATA}{$d}{$s}{$c}{$item}[0];
                        if ( $next =~ /^;/ ||
                             length($item.$next) >= 77 ) {
                            print OUT "\n";
                        }
                        print OUT "$next\n";
                    }
                }
                else {                              #loop

                    print STDERR "\t\tin items else\n" if $debug ; #debugging

                    print OUT "loop_\n";
                
                    foreach $item ( @items ) {      #items in loop
                        print OUT "$item\n";
                    }
                
                    #values in loop:
                    foreach $m (0..$#{$data->{DATA}{$d}{$s}{$c}{$items[0]}}) {
                        $string='';
                        foreach $i ( @items ) {    
                            $next = $data->{DATA}{$d}{$s}{$c}{$i}[$m];
                            if ( $next =~ /^;/ ) {
                                $string .="\n" unless ( $string eq '' );
                                print OUT $string,$next;
                                $string = '';
                            }
                            elsif ( length($string.$next) >= 80 ) {
                                $string .= "\n";
                                print OUT $string;
                                $string = $next.' ';
                            }
                            else {
                                $string .= $next;
                                $string .= ' ';
                            }
                        } 
                        print OUT "$string\n";
                    } 
                }
            }
            print OUT "save_\n" unless ( $s eq '-' );
        }
    }
    
    print STDERR "writing $file\n" if $log;
    
    close (OUT);
}


##########################
# Class method write_xml #
##########################

# This is very premature and "undocumented". 
# Just keeping the code here for convenience.

sub write_xml {

    my ($self,@parameters) = @_;      
    my ($file, $data);
    my $options = "";
        
#   single unnamed parameter doesn't make sense here, 
#   need -dataref and -file

    while ($_ = shift @parameters) {
       $file = shift @parameters if /-file/;
       $data = shift @parameters if /-dataref/;
       $options = shift @parameters if /-options/;
    }

    my ($d, $s, $c, $i);  #data, save, category, item
    my ($dx, $sx, $cx, $ix); #xml compatible
    my ($m);   # loop counter
    my ($string, $dict, $log);
    my ($cat, $item, @cats, @items, $next);

    $dict = 1     if ( $data->type eq 'dictionary' );
    $log  = 1     if ( $options =~ /l/ );

    open (OUT, ">$file");

    print STDERR "writing $file\n" if ( $log );

    foreach $d ( sort keys %{$data->{DATA}} ) {
        $dx = $d;
        print OUT "<data_$dx>\n";
        foreach $s ( sort keys %{$data->{DATA}{$d}} ) {
            $sx = $s;
            print OUT "\t<save_$sx>\n";
            foreach $c ( sort keys %{$data->{DATA}{$d}{$s}} ) {
                $cx = xml_tag($c); 
                print OUT "\t\t<$cx>\n";
                @items = sort keys %{$data->{DATA}{$d}{$s}{$c}};
                foreach $m (0..$#{$data->{DATA}{$d}{$s}{$c}{$items[0]}}) {
                    foreach $item ( @items ) {
                        $item =~ /^\S+?\.(.*)/;
                        $ix = xml_tag($1);
                        $next = $data->{DATA}{$d}{$s}{$c}{$item}[$m];
                        $next = xml_data($next);
                        if ( $next =~ /\n/s ) {
                            print OUT "\n";
                        }
                        print OUT "\t\t\t<$ix i=\"$m\">";
                        print OUT "$next";
                        if ( $next =~ /\n/s ) {
                            print OUT "\t\t\t</$ix>\n";
                        }
                        else {
                            print OUT "</$ix>\n";
                        }
                    }
                }
                print OUT "\t\t</$cx>\n";
            }
            print OUT "\t</save_$sx>\n";
        }
        print OUT "</data_$dx>\n";
    }

    print STDERR "writing $file\n" if $log;

    close (OUT);
}


###########
# xml_tag #
###########

sub xml_tag {
    my $string = shift;
    $string =~ s/[^A-Za-z0-9_\.-]/_/g;
    $string =~ s/^(\d.*)/_$1/;
    return $string;
}


############
# xml_data #
############

sub xml_data {
    my $string = shift;
    $string =~ s/&/&amp;/gs;
    $string =~ s/</&lt;/gs;
    $string =~ s/>/&gt;/gs;
    $string =~ s/'/&apos;/gs;
    $string =~ s/"/&quot;/gs;
    return $string;
} 


1;
__END__


=head1 NAME

STAR::Writer - Perl extension for writing STAR::DataBlock objects 
as files.

=head2 Version

This documentation refers to version 0.01 of this module.

=head1 SYNOPSIS

  use STAR::Writer;
  
  STAR::Writer->write_cif( -dataref=>$data, -file=>$file );

=head1 DESCRIPTION

This module will provide several methods for writing STAR::DataBlocks 
as files in different format. Currently, there is a write_cif method, 
which writes a STAR::DataBlock or STAR::Dictionary object as a file 
in CIF (STAR) format.

=head1 CLASS METHODS

=head2 write_cif

  Usage:  STAR::Writer->write_cif( -dataref=>$data,
                                   -file=>$file [,
                                   -options=>$options ] );

Write the STAR::DataBlock object referenced by $data to the file specified
by $file. C<$options> are C<'l'> for logging activity (to STDERR) and 
C<'d'> for debugging. 

=head1 COMMENTS

Categories and items are currently written out in alphabetical
order. Obviously, this is of no importance to automated
parsing. However, it may not be desirable for visual inspection
of files.

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

