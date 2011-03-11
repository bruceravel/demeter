package Ifeffit;

## BEGIN {
##   push @INC, $ENV{IFEFFIT_DIR} if $ENV{IFEFFIT_DIR};
## }

use version;
require Exporter;
require DynaLoader;
@ISA = qw(Exporter DynaLoader);
@EXPORT = qw(ifeffit);
@EXPORT_OK = qw(get_scalar put_scalar get_string put_string
		get_array  put_array get_echo);

$VERSION   = version->new('3.0.1');
bootstrap Ifeffit $VERSION;
my $MAX_ARRAY_PTS = 16384;

sub ifeffit ($) {
    my @com = split(/\n/, $_[0]);
    my ($c, $ret) ;
    foreach $c (@com) {$ret = Ifeffit::iff_exec($c); };
    return $ret;
}

sub get_scalar ($) {
    my $ptr = new_Pdbl();
    my $val = undef;
    if (Ifeffit::iff_get_scalar($_[0],$ptr) == 0) {
	$val = Pdbl_value($ptr);
    }
    delete_Pdbl($ptr);
    return $val;
}

sub put_scalar ($$) {
    return (ifeffit("set $_[0] = $_[1]")) ? undef: $_[1];
}

sub get_string ($) {
    my $str = " "x512;
    my $len = Ifeffit::iff_get_string($_[0],$str);
    return ($len) ?  substr($str,0,$len) : " ";
}

sub put_string ($$) {
    my $inp = $_[0];
    $inp = "\$".$inp unless ($inp =~ /^(\$)/o);
    my $str = $_[1];
    $str = "\"" . $str . "\"" unless ($str =~ /^\".*\"$/);
    return ifeffit("set $inp =  $str");
}

sub get_array ($) {  # note the use of MAX_ARRAY_PTS !!!
    my ($ptr,$npts,$i);
    my @arr  = ();
    $ptr  = new_Parr($MAX_ARRAY_PTS);
    $npts = Ifeffit::iff_get_array($_[0],$ptr);
    if ($npts) {
	for ($i = 0; $i < $npts; $i++) { $arr[$i] = Parr_getitem($ptr,$i);}
    }
    delete_Parr($ptr);
    return @arr;
}

sub put_array ($$) {
    my $npts   = $#{$_[1]} + 1;
    my ($i,$x,$p_n,$ret,$ptr);
    if ($npts > $MAX_ARRAY_PTS) { $npts = $MAX_ARRAY_PTS;}
    $ptr    = new_Parr($npts);
    for ($i = 0; $i < $npts; $i++) { Parr_setitem($ptr, $i, ${$_[1]}[$i]); }
    $p_n    = new_Pint();
    Pint_assign($p_n, $npts);
    $ret = Ifeffit::iff_put_array($_[0], $p_n, $ptr);
    delete_Pint($p_n);
    delete_Parr($ptr);
    return $ret;
}

sub get_echo () {
    my $str = " "x512;
    my $len = Ifeffit::iff_get_echo($str);
    return ($len) ?  substr($str,0,$len) : " ";
}


# INITIALIZATION Code
# and get compiled-in parameters for max array size.
&ifeffit(" \n");
$MAX_ARRAY_PTS = get_scalar("&maxpts");

#

1;
__END__

=head1 NAME

Ifeffit - Perl interface to the IFEFFIT XAFS Analysis library.

=head1 SYNOPSIS

    use Ifeffit;
    use Ifeffit qw(put_scalar put_string put_array);
    use Ifeffit qw(get_scalar get_string get_array);

    my ($kmin, $my_file, $file_type ) = (0.01, "Cu.xmu", "xmu");
    put_scalar("rbkg", 1.1);
    put_scalar("kmin", $kmin);
    put_string("filename", $my_file);

    ifeffit(" read_data($my_file, prefix= my,");
    ifeffit("           type= $file_type)");
    ifeffit(" newplot (energy, xmu ) ");

    my $e0 = get_scalar("e0");
    print "e0 = $e0 , rbkg  = " ,get_scalar("rbkg"), "\n";

=head1 DESCRIPTION

The Ifeffit Perl Module gives access to the ifeffit library for XAFS
analysis.  The module provides seven perl functions - B<ifeffit>,
B<put_scalar>, B<get_scalar>, B<put_string>, B<get_string>, B<put_array>,
and B<get_array>.  The B<ifeffit> is always provided (ie, exported by the
"use Ifeffit;" pragma), but the other commands must be explicitly imported,
as shown above.

=head2 ifeffit

The ifeffit function provides the main interface to the ifeffit engine.
The character string argument is interpreted as an ifeffit command.
Ifeffit returns 0 if a valid command is sent and fully processed, -1 if a
partial command has been sent (so that it will be expecting the rest of the
command next), 1 if the "quit" command has been sent, and other non-zero
valuses on error.  The syntax for and meaning of command lines to ifeffit
is described in I<The Ifeffit Reference Manual> of the Ifeffit
distribution.  The syntax for the perl function is

C<$i = ifeffit("plot(my.x,  my.y)");>

=head2 put_scalar

This sets the value of a named scalar in the list of ifeffit data.
The set value is returned on successful execution.  The syntax is

C<$i = put_scalar("kweight", 2.0);>.

which is equivalent to

C<$i = ifeffit("kweight = 2.0");>

But having a choice seems like the perl way.

=head2 get_scalar

This returns the value of a named ifeffit scalar. The syntax is

C<$value = get_scalar("x");>

=head2 put_string

This sets the value of a named ifeffit string.  The value is returned
on successful execution.  The syntax is

C<$i = put_text("home", "the merry old land of oz");>.

The same effect could be achieved with the command

C<$i = ifeffit("set \$home = 'the merry old land of oz'");>.

but B<put_text> takes care of the icky leading dollar sign, and returns the
string instead of a simple exit status.

=head2 get_string

This returns the value of a named ifeffit string.  The syntax is

C<$bg = get_string("plot_bg");>

=head2 put_array

This copies a perl array of numeric values to an ifeffit array.
The syntax is

C<put_array("my.array",\@array);>

which creates (or overwrites) the ifeffit array I<my.array>, and fill it
with the values of the perl array I<@array>.  Note that the B<reference> to
the array is passed into B<put_array>, not the whole array itself!

=head2 get_array

This gets the values of an ifeffit array of numeric values. The syntax is

C<@array = get_array("my.array");>

which will fill the perl array B<@array> with the ifeffit array
I<my.array>.

=head1 REVISION HISTORY

=over 4

=item 1.3

Begin distributing with horae package.

=item 1.3 (1)

Force enclosure of string by double quotes in the put_string function.
(Bruce Ravel 18 Feb. 2003)

=back

=head1 AUTHOR

Matthew Newville  --  newville@cars.uchicago.edu

=head1 SEE ALSO

ifeffit, Ifeffit Reference Manual, perl(1)

PGPERL, PDL,  GNU ReadLine Library


=cut
