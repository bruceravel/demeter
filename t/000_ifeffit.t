#! /usr/bin/perl -w
# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

######################### We start with some black magic to print on failure.

# Change 1..1 below to 1..last_test_to_print .
# (It may become useful if the test is moved to ./t subdirectory.)

BEGIN { $| = 1; print "1..8$/"; }
END {print "not ok 1$/" unless $loaded;}
use Ifeffit;
$loaded = 1;
print "ok 1$/";

######################### End of black magic.

# Insert your test code below (better if it prints "ok 13"
# (correspondingly "not ok 13") depending on the success of chunk 13
# of the test code):

$test = 0; $pass = 0;
#----------------------------------------------------------------
# load ifeffit
$test++;
if ($@ ne "") {print "FAILED\n"; die;}

use Ifeffit qw(get_scalar get_string get_array);
use Ifeffit qw(put_scalar put_string put_array);
use Ifeffit qw(get_echo);
print "import methods:\nok 2$/";

$pass++;
#----------------------------------------------------------------
# call ifeffit
$test++;

$i = ifeffit( "x = 1.234500");
print STDERR "show: ";
if ($i eq 0) {
  ifeffit( "show x");
  print "ok 3$/";
} else {
  print "not ok 3$/";
}

$pass++;
#----------------------------------------------------------------
# here doc
$test++;

my ($file, $type, $kweight)  = ("a.xmu", "xmu", 1);
my $read_data =<<"END";
              set (kmin = 0., kweight = $kweight, rbkg = 1.2)
              read_data(file = $file,  prefix = my, type = $type)
END

$i = ifeffit($read_data);

print STDERR "show arrays: ";
if ($i eq 0) {
  ifeffit(" show  my.energy, my.xmu");
  print "ok 4$/";
} else {
  print "not ok 4$/";
}

$pass++;
#----------------------------------------------------------------
# get scalar
$test++;

my $x = get_scalar("x");
print STDERR "get_scalar: ";
print $x == 1.2345 ? "ok 5\n" :  "not ok 5\n";


$pass++;
#----------------------------------------------------------------
# put scalar
$test++;

my $phi = put_scalar("phi", 1.605);

print STDERR "put_scalar: ";
print get_scalar("phi") == 1.605 ? "ok 6\n" : "not ok 6\n";

$pass++;
#----------------------------------------------------------------
# put string
$test++;

print STDERR "put/get_string: ";
put_string("\$filename", "my.xmu");
print get_string("filename") eq "my.xmu" ? "ok 7\n" :  "not ok 7\n";

$pass++;
#----------------------------------------------------------------
# put array
$test++;

for ($i = 0; $i< 5; $i++ ) { $z[$i] = sin($i * 799 + 99.111);}
$i =  put_array("my.test", \@z);

@arr = get_array("my.test");
$ok = ( ($arr[0] + 0.988646491563589 < 0.001) and
	($arr[1] + 0.375094695653461 < 0.001) and
	($arr[2] - 0.605955984630199 < 0.001) and
	($arr[3] - 0.993321521104809 < 0.001) and
	($arr[4] - 0.40748067780344  < 0.001) );
print STDERR "put/get_array:";
print $ok ? "ok 8\n" :  "not ok 8\n";


$pass++;
